#!/bin/bash

echo "=== Ejecutando Job de Votos a Nivel Nacional ==="
hdfs dfs -rm -r -f /onpe/output/votos_nacional

hadoop jar jobs/votos_nacional/votos_nacional.jar \
  /onpe/clean/actas_limpias.csv \
  /onpe/output/votos_nacional

echo "=== Resultado ==="
hdfs dfs -cat /onpe/output/votos_nacional/part-r-00000 | head -n 20
