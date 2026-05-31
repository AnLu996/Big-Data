# Big Data ONPE con Hadoop, HDFS y MapReduce en AWS

Este proyecto implementa una arquitectura Big Data para procesar datos electorales de la ONPE usando un clúster Hadoop de 4 nodos en AWS EC2.

El objetivo es automatizar el levantamiento del clúster, cargar datos de actas electorales en HDFS y ejecutar consultas distribuidas mediante trabajos MapReduce.

---

## 1. Estructura del Proyecto

Todos los integrantes deben tener la siguiente estructura de carpetas:

```text
bigdata-onpe-hadoop/
│
├── deploy_cluster.sh
├── deploy_cluster_boto3.py
├── destroy_cluster.sh
├── destroy_cluster_boto3.py
├── setup_hadoop_cluster.sh
├── requirements.txt
├── upload_data.sh
│
├── scripts/                   
│   ├── run_limpieza.sh
│   ├── run_votos_nacional.sh
│   ├── run_votos_region.sh
│   └── run_indice.sh
│
├── jobs/                      
│   ├── limpieza/
│   ├── votos_nacional/
│   ├── votos_region/
│   └── indice_invertido/
│
└── README.md
```

---

## 2. Guía de Replicación para AWS Academy con boto3

Sigue estos pasos para levantar toda la infraestructura desde cero y cargar los 23GB de datos JSON de la ONPE en HDFS. Por defecto el Master se crea con **60GB**, los Workers con **40GB** y HDFS usa **factor de replicación 1**.

### Paso 0: Clonar el Repositorio
Para comenzar, clona este repositorio en tu computadora o en una VM desde donde controlarás AWS. No necesitas CloudShell, pero sí debes tener Python, `boto3`, credenciales AWS Academy activas y comandos SSH/SCP disponibles.

En tu terminal, ejecuta:
```bash
git clone https://github.com/jflma/onpe-hadoop-cluster.git
cd onpe-hadoop-cluster
pip install -r requirements.txt
```

Configura tus credenciales AWS. En AWS Academy normalmente necesitas `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` y `AWS_SESSION_TOKEN`:
```bash
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_SESSION_TOKEN="..."
export AWS_DEFAULT_REGION="us-east-1"
```

En PowerShell usa:
```powershell
$env:AWS_ACCESS_KEY_ID="..."
$env:AWS_SECRET_ACCESS_KEY="..."
$env:AWS_SESSION_TOKEN="..."
$env:AWS_DEFAULT_REGION="us-east-1"
```

### Paso 1: Desplegar el Clúster
Estando dentro de la carpeta clonada, ejecuta:
```bash
python deploy_cluster_boto3.py
```
Esto creará 1 nodo Master y 3 nodos Worker en EC2, usando `t3.medium` por defecto, discos EBS gp3 y el Security Group del clúster. También generará `hadoop-onpe-key.pem` y `cluster_ips.txt`.

Puedes ajustar la región, tipo de instancia o CIDR autorizado:
```bash
python deploy_cluster_boto3.py --region us-east-1 --worker-count 3 --allowed-cidr TU_IP/32
```

### Paso 2: Configurar Hadoop
Una vez las instancias estén corriendo, instala y configura Hadoop automáticamente ejecutando:
```bash
bash setup_hadoop_cluster.sh
```

### Paso 3: Validar el Clúster
Conéctate por SSH al nodo Master:
```bash
ssh -i hadoop-onpe-key.pem ubuntu@<IP_PÚBLICA_MASTER>
```
Valida que Hadoop esté corriendo en el **Master**:
```bash
jps
# Debe mostrar: NameNode, SecondaryNameNode, ResourceManager, JobHistoryServer
```
Valida que los **Workers** estén funcionando:
```bash
for worker in worker1 worker2 worker3; do
  echo "===== $worker ====="
  ssh $worker jps
  # Debe mostrar: DataNode, NodeManager
done
```

### Paso 4: Carga de Datos y Estructura HDFS (¡IMPORTANTE!)
**⚠️ ADVERTENCIA:** NO ejecutes estos scripts en AWS CloudShell ni en tu computadora local. **Deben ejecutarse estrictamente dentro del nodo Master.**

**Nota sobre recursos:** Las instancias `t3.medium` tienen 4GB RAM. Manejar 23GB de JSONs exige memoria y el Master podría desconectarse si bajas a `t2.micro`. Si solo puedes usar `t2.micro`, ten paciencia si el SSH se desconecta y simplemente vuelve a entrar.

Asegúrate de estar dentro del nodo Master (el prompt debe decir `ubuntu@ip-...`). Si no lo estás, conéctate y clona el repositorio allí:

```bash
# 1. Conéctate al Master (reemplaza por tu IP pública)
ssh -i hadoop-onpe-key.pem ubuntu@<IP_PÚBLICA_MASTER>

# 2. Clona el repo DENTRO del Master
git clone https://github.com/jflma/onpe-hadoop-cluster.git
cd onpe-hadoop-cluster
```

Debido al tamaño masivo de los datos (23GB), hemos dividido el proceso en dos partes:

**Parte 1: Descarga y Extracción**
Ejecuta el primer script. Este instalará las dependencias necesarias, descargará el archivo de 1GB desde Google Drive y lo extraerá a 23GB.
```bash
bash 1_download_data.sh
```

**Parte 2: Subida a HDFS**
Una vez extraídos los datos, ejecuta el segundo script. Este creará toda la estructura de carpetas en HDFS (`/onpe/raw`, etc.) y moverá los 23GB de JSONs hacia el almacenamiento distribuido.
```bash
bash 2_upload_hdfs.sh
```

*Nota: La Parte 2 tomará bastante tiempo (15 a 30 minutos). Si tu conexión SSH se cae por falta de memoria RAM, puedes volver a entrar e intentar reanudar.*

### Paso 5: Ejecución de Jobs MapReduce 
Una vez desarrollados y compilados los archivos `.jar` en la carpeta `jobs/`, puedes ejecutarlos desde el Master usando los scripts en la carpeta `scripts/`.

Por ejemplo, para ejecutar la limpieza:
```bash
bash scripts/run_limpieza.sh
```

---

## 3. Destruir el Clúster
Para no consumir créditos de más cuando termines de trabajar:
```bash
python destroy_cluster_boto3.py
```

Los scripts Bash `deploy_cluster.sh` y `destroy_cluster.sh` se mantienen como alternativa compatible con `aws-cli`, pero el flujo principal del proyecto usa `boto3`.
