#!/bin/bash

echo "=== Ejecutando Job de Índice Invertido ==="
hdfs dfs -rm -r -f /onpe/output/indice_invertido

hadoop jar jobs/indice_invertido/indice_invertido.jar \
  /onpe/clean/actas_limpias.csv \
  /onpe/output/indice_invertido

echo "=== Resultado ==="
hdfs dfs -cat /onpe/output/indice_invertido/part-r-00000 | head -n 20
