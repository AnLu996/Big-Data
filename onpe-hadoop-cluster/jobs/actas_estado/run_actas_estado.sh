#!/bin/bash

set -e

INPUT="/onpe/clean/actas_resumen_tsv"
OUTPUT="/onpe/output/actas_estado"

HADOOP_STREAMING_JAR=$(find /opt/hadoop/share/hadoop/tools/lib -name "hadoop-streaming*.jar" | head -n 1)

hdfs dfs -rm -r -f "$OUTPUT"

hadoop jar "$HADOOP_STREAMING_JAR" \
  -D mapreduce.job.name="ONPE - Actas por estado" \
  -files mapper_actas_estado.py,reducer_suma.py \
  -mapper "python3 mapper_actas_estado.py" \
  -reducer "python3 reducer_suma.py" \
  -input "$INPUT" \
  -output "$OUTPUT"

echo "Resultado actas por estado:"
hdfs dfs -cat "$OUTPUT/part-00000"