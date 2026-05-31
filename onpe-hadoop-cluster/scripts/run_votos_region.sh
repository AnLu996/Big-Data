#!/bin/bash

echo "=== Ejecutando Job de Votos por Región ==="
hdfs dfs -rm -r -f /onpe/output/votos_region

hadoop jar jobs/votos_region/votos_region.jar \
  /onpe/clean/actas_limpias.csv \
  /onpe/output/votos_region

echo "=== Resultado ==="
hdfs dfs -cat /onpe/output/votos_region/part-r-00000 | head -n 20
