#!/bin/bash

set -e

INPUT="/onpe/clean/actas_limpias_tsv"
OUTPUT="/onpe/output/votos_region"

HADOOP_STREAMING_JAR=$(find /opt/hadoop/share/hadoop/tools/lib -name "hadoop-streaming*.jar" | head -n 1)

hdfs dfs -rm -r -f "$OUTPUT"

hadoop jar "$HADOOP_STREAMING_JAR" \
  -D mapreduce.job.name="ONPE - Votos por region y agrupacion" \
  -files mapper_votos_region.py,reducer_suma.py \
  -mapper "python3 mapper_votos_region.py" \
  -reducer "python3 reducer_suma.py" \
  -input "$INPUT" \
  -output "$OUTPUT"

echo "Resultado votos por region:"
hdfs dfs -cat "$OUTPUT/part-00000" | head -50