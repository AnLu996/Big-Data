#!/bin/bash

set -e

CLUSTER_NAME="hadoop-onpe"
KEY_NAME="${CLUSTER_NAME}-key.pem"

if [ ! -f cluster_ips.txt ]; then
  echo "No existe cluster_ips.txt. Ejecuta primero deploy_cluster_boto3.py o deploy_cluster.sh"
  exit 1
fi

MASTER_PUBLIC=$(grep "master" cluster_ips.txt | awk '{print $4}')
MASTER_PRIVATE=$(grep "master" cluster_ips.txt | awk '{print $3}')

echo "Master público: $MASTER_PUBLIC"
echo "Master privado: $MASTER_PRIVATE"


# CREAR ARCHIVO HOSTS
cat > hosts_hadoop <<EOF
$MASTER_PRIVATE master
EOF

grep "worker" cluster_ips.txt | awk '{alias=$1; sub(/^.*-worker/, "worker", alias); print $3" "alias}' >> hosts_hadoop


# CREAR SCRIPT REMOTO
cat > configure_node.sh <<'EOF'
#!/bin/bash

set -e

sudo bash -c 'cat /home/ubuntu/hosts_hadoop >> /etc/hosts'

echo "export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64" >> ~/.bashrc
echo "export HADOOP_HOME=/opt/hadoop" >> ~/.bashrc
echo "export PATH=\$PATH:\$HADOOP_HOME/bin:\$HADOOP_HOME/sbin" >> ~/.bashrc

source ~/.bashrc

mkdir -p ~/hadoopdata/hdfs/namenode
mkdir -p ~/hadoopdata/hdfs/datanode

cat > /opt/hadoop/etc/hadoop/core-site.xml <<XML
<configuration>
    <property>
        <name>fs.defaultFS</name>
        <value>hdfs://master:9000</value>
    </property>
</configuration>
XML

cat > /opt/hadoop/etc/hadoop/hdfs-site.xml <<XML
<configuration>
    <property>
        <name>dfs.replication</name>
        <value>1</value>
    </property>

    <property>
        <name>dfs.namenode.name.dir</name>
        <value>file:///home/ubuntu/hadoopdata/hdfs/namenode</value>
    </property>

    <property>
        <name>dfs.datanode.data.dir</name>
        <value>file:///home/ubuntu/hadoopdata/hdfs/datanode</value>
    </property>
</configuration>
XML

cat > /opt/hadoop/etc/hadoop/yarn-site.xml <<XML
<configuration>
    <property>
        <name>yarn.resourcemanager.hostname</name>
        <value>master</value>
    </property>

    <property>
        <name>yarn.nodemanager.aux-services</name>
        <value>mapreduce_shuffle</value>
    </property>

    <property>
        <name>yarn.nodemanager.resource.memory-mb</name>
        <value>1536</value>
    </property>

    <property>
        <name>yarn.scheduler.maximum-allocation-mb</name>
        <value>1536</value>
    </property>

    <property>
        <name>yarn.scheduler.minimum-allocation-mb</name>
        <value>128</value>
    </property>

    <property>
        <name>yarn.nodemanager.vmem-check-enabled</name>
        <value>false</value>
    </property>
</configuration>
XML

cat > /opt/hadoop/etc/hadoop/mapred-site.xml <<XML
<configuration>
    <property>
        <name>mapreduce.framework.name</name>
        <value>yarn</value>
    </property>

    <property>
        <name>mapreduce.application.classpath</name>
        <value>\$HADOOP_MAPRED_HOME/share/hadoop/mapreduce/*:\$HADOOP_MAPRED_HOME/share/hadoop/mapreduce/lib/*</value>
    </property>

    <property>
        <name>mapreduce.map.memory.mb</name>
        <value>256</value>
    </property>

    <property>
        <name>mapreduce.reduce.memory.mb</name>
        <value>256</value>
    </property>
</configuration>
XML
EOF


# COPIAR A TODOS LOS NODOS
for HOST in $MASTER_PUBLIC $(grep "worker" cluster_ips.txt | awk '{print $4}'); do
  echo "Configurando nodo $HOST"

  scp -o StrictHostKeyChecking=no -i "$KEY_NAME" hosts_hadoop ubuntu@$HOST:/home/ubuntu/hosts_hadoop
  scp -o StrictHostKeyChecking=no -i "$KEY_NAME" configure_node.sh ubuntu@$HOST:/home/ubuntu/configure_node.sh

  ssh -o StrictHostKeyChecking=no -i "$KEY_NAME" ubuntu@$HOST "chmod +x configure_node.sh && ./configure_node.sh"
done


# CONFIGURAR SSH INTERNO DESDE MASTER
echo "Copiando llave al master..."

scp -o StrictHostKeyChecking=no -i "$KEY_NAME" "$KEY_NAME" ubuntu@$MASTER_PUBLIC:/home/ubuntu/.ssh/hadoop.pem

ssh -o StrictHostKeyChecking=no -i "$KEY_NAME" ubuntu@$MASTER_PUBLIC <<EOF
chmod 400 ~/.ssh/hadoop.pem


MASTER_HOSTNAME=\$(hostname)

cat > ~/.ssh/config <<SSHCONF
Host master
    HostName master
    User ubuntu
    IdentityFile ~/.ssh/hadoop.pem
    StrictHostKeyChecking no

Host \$MASTER_HOSTNAME
    HostName master
    User ubuntu
    IdentityFile ~/.ssh/hadoop.pem
    StrictHostKeyChecking no
SSHCONF

awk '\$2 ~ /^worker/ {
  print "";
  print "Host " \$2;
  print "    HostName " \$2;
  print "    User ubuntu";
  print "    IdentityFile ~/.ssh/hadoop.pem";
  print "    StrictHostKeyChecking no";
}' /home/ubuntu/hosts_hadoop >> ~/.ssh/config

chmod 600 ~/.ssh/config

awk '\$2 ~ /^worker/ {print \$2}' /home/ubuntu/hosts_hadoop > /opt/hadoop/etc/hadoop/workers

source ~/.bashrc

hdfs namenode -format -force

start-dfs.sh
start-yarn.sh
mapred --daemon start historyserver

jps
EOF

echo ""
echo "Cluster Hadoop configurado."
echo ""
echo "Interfaces web:"
echo "HDFS NameNode: http://$MASTER_PUBLIC:9870"
echo "YARN ResourceManager: http://$MASTER_PUBLIC:8088"
