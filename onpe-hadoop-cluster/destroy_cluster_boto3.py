#!/usr/bin/env python3
import argparse
import os
import sys

try:
    import boto3
    from botocore.exceptions import NoCredentialsError
except ModuleNotFoundError:
    print("Falta boto3. Instala dependencias con: pip install -r requirements.txt", file=sys.stderr)
    raise SystemExit(1)


def parse_args():
    parser = argparse.ArgumentParser(
        description="Termina las instancias EC2 del cluster Hadoop ONPE usando boto3."
    )
    parser.add_argument("--cluster-name", default="hadoop-onpe")
    parser.add_argument("--region", default=os.getenv("AWS_REGION") or os.getenv("AWS_DEFAULT_REGION") or "us-east-1")
    return parser.parse_args()


def main():
    args = parse_args()

    try:
        session = boto3.Session(region_name=args.region)
        ec2 = session.client("ec2")

        response = ec2.describe_instances(
            Filters=[
                {"Name": "tag:Project", "Values": [args.cluster_name]},
                {"Name": "instance-state-name", "Values": ["running", "pending", "stopped"]},
            ]
        )
        instance_ids = [
            instance["InstanceId"]
            for reservation in response["Reservations"]
            for instance in reservation["Instances"]
        ]

        if not instance_ids:
            print("No hay instancias del cluster para eliminar.")
            return 0

        print("Terminando instancias:")
        print(" ".join(instance_ids))

        ec2.terminate_instances(InstanceIds=instance_ids)

        print("Esperando eliminacion...")
        ec2.get_waiter("instance_terminated").wait(InstanceIds=instance_ids)

        print("Cluster eliminado.")
    except NoCredentialsError:
        print("No se encontraron credenciales AWS. Configura AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY/AWS_SESSION_TOKEN o un perfil AWS.", file=sys.stderr)
        return 1
    except Exception as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
