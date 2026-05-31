#!/bin/bash

set -e

INPUT="/onpe/raw/actas_onpe_raw.jsonl"
OUTPUT="/onpe/clean/actas_resumen_tsv"

HADOOP_STREAMING_JAR=$(find /opt/hadoop/share/hadoop/tools/lib -name "hadoop-streaming*.jar" | head -n 1)

if [ -z "$HADOOP_STREAMING_JAR" ]; then
  echo "No se encontró hadoop-streaming.jar"
  exit 1
fi

hdfs dfs -rm -r -f "$OUTPUT"

hadoop jar "$HADOOP_STREAMING_JAR" \
  -D mapreduce.job.name="ONPE - Resumen por acta" \
  -files mapper_resumen.py,reducer_resumen.py \
  -mapper "python3 mapper_resumen.py" \
  -reducer "python3 reducer_resumen.py" \
  -input "$INPUT" \
  -output "$OUTPUT"

echo "Resumen generado:"
hdfs dfs -ls "$OUTPUT"
hdfs dfs -cat "$OUTPUT/part-00000" | head -20