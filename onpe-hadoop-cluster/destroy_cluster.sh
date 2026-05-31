#!/bin/bash

set -e

CLUSTER_NAME="hadoop-onpe"

INSTANCE_IDS=$(aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=$CLUSTER_NAME" "Name=instance-state-name,Values=running,pending,stopped" \
  --query "Reservations[*].Instances[*].InstanceId" \
  --output text)

if [ -z "$INSTANCE_IDS" ]; then
  echo "No hay instancias del cluster para eliminar."
  exit 0
fi

echo "Terminando instancias:"
echo "$INSTANCE_IDS"

aws ec2 terminate-instances --instance-ids $INSTANCE_IDS

echo "Esperando eliminación..."
aws ec2 wait instance-terminated --instance-ids $INSTANCE_IDS

echo "Cluster eliminado."
