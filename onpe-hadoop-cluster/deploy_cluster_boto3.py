#!/usr/bin/env python3
import argparse
import os
import stat
import sys
from pathlib import Path
from urllib.request import urlopen

try:
    import boto3
    from botocore.exceptions import ClientError, NoCredentialsError
except ModuleNotFoundError:
    print("Falta boto3. Instala dependencias con: pip install -r requirements.txt", file=sys.stderr)
    raise SystemExit(1)


USER_DATA = """#!/bin/bash
apt-get update -y
apt-get install -y openjdk-11-jdk wget rsync net-tools

echo "export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64" >> /etc/profile
echo "export HADOOP_HOME=/opt/hadoop" >> /etc/profile
echo "export PATH=\\$PATH:\\$HADOOP_HOME/bin:\\$HADOOP_HOME/sbin" >> /etc/profile

cd /opt
wget -q https://downloads.apache.org/hadoop/common/hadoop-3.3.6/hadoop-3.3.6.tar.gz
tar -xzf hadoop-3.3.6.tar.gz
mv hadoop-3.3.6 hadoop
chown -R ubuntu:ubuntu /opt/hadoop

mkdir -p /home/ubuntu/hadoopdata/hdfs/namenode
mkdir -p /home/ubuntu/hadoopdata/hdfs/datanode
chown -R ubuntu:ubuntu /home/ubuntu/hadoopdata

echo "export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64" >> /opt/hadoop/etc/hadoop/hadoop-env.sh
"""


def parse_args():
    parser = argparse.ArgumentParser(
        description="Crea el cluster Hadoop ONPE en EC2 usando boto3."
    )
    parser.add_argument("--cluster-name", default="hadoop-onpe")
    parser.add_argument("--region", default=os.getenv("AWS_REGION") or os.getenv("AWS_DEFAULT_REGION") or "us-east-1")
    parser.add_argument("--master-instance-type", default="t3.medium")
    parser.add_argument("--worker-instance-type", default="t3.medium")
    parser.add_argument("--master-volume-size", type=int, default=60)
    parser.add_argument("--worker-volume-size", type=int, default=40)
    parser.add_argument("--worker-count", type=int, default=3)
    parser.add_argument("--allowed-cidr", help="CIDR autorizado para SSH y UIs web. Por defecto usa tu IP publica /32.")
    parser.add_argument("--output", default="cluster_ips.txt")
    return parser.parse_args()


def get_default_vpc_id(ec2):
    response = ec2.describe_vpcs(Filters=[{"Name": "isDefault", "Values": ["true"]}])
    vpcs = response.get("Vpcs", [])
    if not vpcs:
        raise RuntimeError("No se encontro una VPC default en la region seleccionada.")
    return vpcs[0]["VpcId"]


def get_ubuntu_ami(ssm):
    response = ssm.get_parameters(
        Names=["/aws/service/canonical/ubuntu/server/22.04/stable/current/amd64/hvm/ebs-gp2/ami-id"]
    )
    parameters = response.get("Parameters", [])
    if not parameters:
        raise RuntimeError("No se pudo resolver la AMI de Ubuntu 22.04 desde SSM.")
    return parameters[0]["Value"]


def get_public_cidr():
    with urlopen("https://checkip.amazonaws.com", timeout=10) as response:
        ip = response.read().decode("utf-8").strip()
    if not ip:
        raise RuntimeError("No se pudo detectar la IP publica local.")
    return f"{ip}/32"


def ensure_key_pair(ec2, key_name, key_path):
    try:
        ec2.describe_key_pairs(KeyNames=[key_name])
        if not key_path.exists():
            raise RuntimeError(
                f"El key pair {key_name} ya existe en AWS, pero falta {key_path}. "
                "EC2 no permite descargar otra vez la llave privada. Usa otra llave o elimina ese key pair si corresponde."
            )
        print(f"La llave {key_path} ya existe localmente y el key pair existe en AWS.")
        return
    except ClientError as exc:
        code = exc.response.get("Error", {}).get("Code")
        if code != "InvalidKeyPair.NotFound":
            raise

    if key_path.exists():
        raise RuntimeError(
            f"Existe {key_path}, pero no existe el key pair {key_name} en AWS. "
            "Renombra/elimina el archivo local o crea un key pair compatible."
        )

    print("Creando key pair...")
    response = ec2.create_key_pair(KeyName=key_name)
    key_path.write_text(response["KeyMaterial"], encoding="utf-8")
    try:
        key_path.chmod(stat.S_IRUSR)
    except OSError:
        print("Aviso: no se pudo aplicar chmod 400 a la llave local. Ajusta permisos si SSH lo requiere.")


def ensure_security_group(ec2, group_name, vpc_id):
    groups = ec2.describe_security_groups(
        Filters=[
            {"Name": "group-name", "Values": [group_name]},
            {"Name": "vpc-id", "Values": [vpc_id]},
        ]
    ).get("SecurityGroups", [])
    if groups:
        return groups[0]["GroupId"]

    print("Creando Security Group...")
    response = ec2.create_security_group(
        GroupName=group_name,
        Description="Security group para Hadoop ONPE",
        VpcId=vpc_id,
    )
    return response["GroupId"]


def authorize_ingress(ec2, sg_id, allowed_cidr):
    rules = [
        {
            "IpProtocol": "tcp",
            "FromPort": port,
            "ToPort": port,
            "IpRanges": [{"CidrIp": allowed_cidr}],
        }
        for port in (22, 9870, 8088, 19888)
    ]
    rules.append(
        {
            "IpProtocol": "-1",
            "UserIdGroupPairs": [{"GroupId": sg_id}],
        }
    )

    for rule in rules:
        try:
            ec2.authorize_security_group_ingress(GroupId=sg_id, IpPermissions=[rule])
        except ClientError as exc:
            code = exc.response.get("Error", {}).get("Code")
            if code != "InvalidPermission.Duplicate":
                raise


def run_instances(ec2, *, ami_id, instance_type, count, key_name, sg_id, volume_size, tags):
    response = ec2.run_instances(
        ImageId=ami_id,
        InstanceType=instance_type,
        MinCount=count,
        MaxCount=count,
        KeyName=key_name,
        SecurityGroupIds=[sg_id],
        BlockDeviceMappings=[
            {
                "DeviceName": "/dev/sda1",
                "Ebs": {
                    "VolumeSize": volume_size,
                    "VolumeType": "gp3",
                    "DeleteOnTermination": True,
                },
            }
        ],
        UserData=USER_DATA,
        TagSpecifications=[
            {
                "ResourceType": "instance",
                "Tags": [{"Key": key, "Value": value} for key, value in tags.items()],
            }
        ],
    )
    return [instance["InstanceId"] for instance in response["Instances"]]


def tag_workers(ec2, cluster_name, worker_ids):
    for index, instance_id in enumerate(worker_ids, start=1):
        ec2.create_tags(
            Resources=[instance_id],
            Tags=[{"Key": "Name", "Value": f"{cluster_name}-worker{index}"}],
        )


def get_cluster_rows(ec2, instance_ids):
    response = ec2.describe_instances(InstanceIds=instance_ids)
    rows = []
    for reservation in response["Reservations"]:
        for instance in reservation["Instances"]:
            tags = {tag["Key"]: tag["Value"] for tag in instance.get("Tags", [])}
            rows.append(
                {
                    "name": tags.get("Name", ""),
                    "instance_id": instance["InstanceId"],
                    "private_ip": instance.get("PrivateIpAddress", ""),
                    "public_ip": instance.get("PublicIpAddress", ""),
                }
            )

    def sort_key(row):
        if row["name"].endswith("-master"):
            return (0, row["name"])
        return (1, row["name"])

    return sorted(rows, key=sort_key)


def write_cluster_ips(path, rows):
    content = "\n".join(
        f"{row['name']}\t{row['instance_id']}\t{row['private_ip']}\t{row['public_ip']}"
        for row in rows
    )
    Path(path).write_text(content + "\n", encoding="utf-8")


def main():
    args = parse_args()
    key_name = f"{args.cluster_name}-key"
    sg_name = f"{args.cluster_name}-sg"
    key_path = Path(f"{key_name}.pem")

    try:
        session = boto3.Session(region_name=args.region)
        ec2 = session.client("ec2")
        ssm = session.client("ssm")

        print(f"Region usada: {args.region}")
        ami_id = get_ubuntu_ami(ssm)
        print(f"AMI Ubuntu encontrada: {ami_id}")

        ensure_key_pair(ec2, key_name, key_path)

        vpc_id = get_default_vpc_id(ec2)
        print(f"VPC usada: {vpc_id}")

        sg_id = ensure_security_group(ec2, sg_name, vpc_id)
        print(f"Security Group: {sg_id}")

        allowed_cidr = args.allowed_cidr or get_public_cidr()
        print(f"Permitiremos SSH y UIs web desde: {allowed_cidr}")
        authorize_ingress(ec2, sg_id, allowed_cidr)

        print("Lanzando nodo master...")
        master_ids = run_instances(
            ec2,
            ami_id=ami_id,
            instance_type=args.master_instance_type,
            count=1,
            key_name=key_name,
            sg_id=sg_id,
            volume_size=args.master_volume_size,
            tags={
                "Project": args.cluster_name,
                "Role": "master",
                "Name": f"{args.cluster_name}-master",
            },
        )
        master_id = master_ids[0]
        print(f"Master creado: {master_id}")

        print(f"Lanzando {args.worker_count} workers...")
        worker_ids = run_instances(
            ec2,
            ami_id=ami_id,
            instance_type=args.worker_instance_type,
            count=args.worker_count,
            key_name=key_name,
            sg_id=sg_id,
            volume_size=args.worker_volume_size,
            tags={"Project": args.cluster_name, "Role": "worker"},
        )
        tag_workers(ec2, args.cluster_name, worker_ids)
        print("Workers creados:")
        print(" ".join(worker_ids))

        instance_ids = [master_id, *worker_ids]
        print("Esperando a que las instancias esten running...")
        ec2.get_waiter("instance_running").wait(InstanceIds=instance_ids)

        print("Esperando estado OK...")
        ec2.get_waiter("instance_status_ok").wait(InstanceIds=instance_ids)

        rows = get_cluster_rows(ec2, instance_ids)
        write_cluster_ips(args.output, rows)

        print("")
        print("Cluster creado:")
        for row in rows:
            print(f"{row['name']}\t{row['instance_id']}\t{row['private_ip']}\t{row['public_ip']}")

        print("")
        print("Ahora ejecuta:")
        print("bash setup_hadoop_cluster.sh")
    except NoCredentialsError:
        print("No se encontraron credenciales AWS. Configura AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY/AWS_SESSION_TOKEN o un perfil AWS.", file=sys.stderr)
        return 1
    except Exception as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
