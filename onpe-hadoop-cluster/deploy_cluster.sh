#!/bin/bash

set -e

# CONFIGURACIÓN GENERAL
CLUSTER_NAME="hadoop-onpe"
KEY_NAME="${CLUSTER_NAME}-key"
SG_NAME="${CLUSTER_NAME}-sg"
MASTER_INSTANCE_TYPE="t3.medium"
WORKER_INSTANCE_TYPE="t3.medium"
MASTER_VOLUME_SIZE=60
WORKER_VOLUME_SIZE=40
WORKER_COUNT=3
REGION=$(aws configure get region || true)

if [ -z "$REGION" ]; then
  REGION="us-east-1"
fi

echo "Región usada: $REGION"


# OBTENER AMI UBUNTU 22.04
AMI_ID=$(aws ssm get-parameters \
  --names /aws/service/canonical/ubuntu/server/22.04/stable/current/amd64/hvm/ebs-gp2/ami-id \
  --query "Parameters[0].Value" \
  --output text)

echo "AMI Ubuntu encontrada: $AMI_ID"


# CREAR KEY PAIR
if [ ! -f "${KEY_NAME}.pem" ]; then
  echo "Creando key pair..."
  aws ec2 create-key-pair \
    --key-name "$KEY_NAME" \
    --query "KeyMaterial" \
    --output text > "${KEY_NAME}.pem"

  chmod 400 "${KEY_NAME}.pem"
else
  echo "La llave ${KEY_NAME}.pem ya existe localmente."
fi


# CREAR SECURITY GROUP
VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=isDefault,Values=true" \
  --query "Vpcs[0].VpcId" \
  --output text)

echo "VPC usada: $VPC_ID"

SG_ID=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=$SG_NAME" \
  --query "SecurityGroups[0].GroupId" \
  --output text 2>/dev/null || true)

if [ "$SG_ID" == "None" ] || [ -z "$SG_ID" ]; then
  echo "Creando Security Group..."
  SG_ID=$(aws ec2 create-security-group \
    --group-name "$SG_NAME" \
    --description "Security group para Hadoop ONPE" \
    --vpc-id "$VPC_ID" \
    --query "GroupId" \
    --output text)
fi

echo "Security Group: $SG_ID"

# IP pública actual de CloudShell
MY_IP=$(curl -s https://checkip.amazonaws.com)/32

echo "Permitiremos SSH desde: $MY_IP"

# Reglas externas mínimas
aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" \
  --protocol tcp \
  --port 22 \
  --cidr "$MY_IP" 2>/dev/null || true

aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" \
  --protocol tcp \
  --port 9870 \
  --cidr "$MY_IP" 2>/dev/null || true

aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" \
  --protocol tcp \
  --port 8088 \
  --cidr "$MY_IP" 2>/dev/null || true

aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" \
  --protocol tcp \
  --port 19888 \
  --cidr "$MY_IP" 2>/dev/null || true


# Permitir comunicación interna total entre nodos del mismo SG
aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" \
  --protocol -1 \
  --source-group "$SG_ID" 2>/dev/null || true


# USER DATA BASE
cat > user_data.sh <<'EOF'
#!/bin/bash
apt-get update -y
apt-get install -y openjdk-11-jdk wget rsync net-tools

echo "export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64" >> /etc/profile
echo "export HADOOP_HOME=/opt/hadoop" >> /etc/profile
echo "export PATH=\$PATH:\$HADOOP_HOME/bin:\$HADOOP_HOME/sbin" >> /etc/profile

cd /opt
wget -q https://downloads.apache.org/hadoop/common/hadoop-3.3.6/hadoop-3.3.6.tar.gz
tar -xzf hadoop-3.3.6.tar.gz
mv hadoop-3.3.6 hadoop
chown -R ubuntu:ubuntu /opt/hadoop

mkdir -p /home/ubuntu/hadoopdata/hdfs/namenode
mkdir -p /home/ubuntu/hadoopdata/hdfs/datanode
chown -R ubuntu:ubuntu /home/ubuntu/hadoopdata

echo "export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64" >> /opt/hadoop/etc/hadoop/hadoop-env.sh
EOF

# LANZAR MASTER
echo "Lanzando nodo master..."

MASTER_ID=$(aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --instance-type "$MASTER_INSTANCE_TYPE" \
  --count 1 \
  --key-name "$KEY_NAME" \
  --security-group-ids "$SG_ID" \
  --block-device-mappings "[{\"DeviceName\":\"/dev/sda1\",\"Ebs\":{\"VolumeSize\":${MASTER_VOLUME_SIZE},\"VolumeType\":\"gp3\",\"DeleteOnTermination\":true}}]" \
  --user-data file://user_data.sh \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Project,Value=${CLUSTER_NAME}},{Key=Role,Value=master},{Key=Name,Value=${CLUSTER_NAME}-master}]" \
  --query "Instances[0].InstanceId" \
  --output text)

echo "Master creado: $MASTER_ID"


# LANZAR WORKERS
echo "Lanzando $WORKER_COUNT workers..."

WORKER_IDS=$(aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --instance-type "$WORKER_INSTANCE_TYPE" \
  --count "$WORKER_COUNT" \
  --key-name "$KEY_NAME" \
  --security-group-ids "$SG_ID" \
  --block-device-mappings "[{\"DeviceName\":\"/dev/sda1\",\"Ebs\":{\"VolumeSize\":${WORKER_VOLUME_SIZE},\"VolumeType\":\"gp3\",\"DeleteOnTermination\":true}}]" \
  --user-data file://user_data.sh \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Project,Value=${CLUSTER_NAME}},{Key=Role,Value=worker}]" \
  --query "Instances[*].InstanceId" \
  --output text)

echo "Workers creados:"
echo "$WORKER_IDS"

INSTANCE_IDS="$MASTER_ID $WORKER_IDS"

echo "Instancias creadas:"
echo "$INSTANCE_IDS"

echo "Esperando a que las instancias estén running..."
aws ec2 wait instance-running --instance-ids $INSTANCE_IDS


# ASIGNAR NOMBRES
aws ec2 create-tags \
  --resources "$MASTER_ID" \
  --tags Key=Name,Value="${CLUSTER_NAME}-master"

i=1
for ID in $WORKER_IDS; do
  aws ec2 create-tags \
    --resources "$ID" \
    --tags Key=Name,Value="${CLUSTER_NAME}-worker$i"

  i=$((i+1))
done

echo "Esperando estado OK..."
aws ec2 wait instance-status-ok --instance-ids $INSTANCE_IDS


# GUARDAR IPS
aws ec2 describe-instances \
  --instance-ids $INSTANCE_IDS \
  --query "Reservations[*].Instances[*].[Tags[?Key=='Name'].Value|[0],InstanceId,PrivateIpAddress,PublicIpAddress]" \
  --output text > cluster_ips.txt

echo ""
echo "Cluster creado:"
cat cluster_ips.txt

echo ""
echo "Ahora ejecuta:"
echo "bash setup_hadoop_cluster.sh"
