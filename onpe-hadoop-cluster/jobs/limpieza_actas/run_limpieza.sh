#!/bin/bash

set -e

INPUT="/onpe/raw/actas_onpe_raw.jsonl"
OUTPUT="/onpe/clean/actas_limpias_tsv"

HADOOP_STREAMING_JAR=$(find /opt/hadoop/share/hadoop/tools/lib -name "hadoop-streaming*.jar" | head -n 1)

if [ -z "$HADOOP_STREAMING_JAR" ]; then
  echo "No se encontró hadoop-streaming.jar"
  exit 1
fi

echo "Eliminando salida anterior..."
hdfs dfs -rm -r -f "$OUTPUT"

echo "Ejecutando limpieza distribuida..."
hadoop jar "$HADOOP_STREAMING_JAR" \
  -D mapreduce.job.name="ONPE - Limpieza distribuida de actas" \
  -files mapper_limpieza.py,reducer_limpieza.py \
  -mapper "python3 mapper_limpieza.py" \
  -reducer "python3 reducer_limpieza.py" \
  -input "$INPUT" \
  -output "$OUTPUT"

echo "Limpieza terminada."
echo "Resultado:"
hdfs dfs -ls "$OUTPUT"
hdfs dfs -cat "$OUTPUT/part-00000" | head -20