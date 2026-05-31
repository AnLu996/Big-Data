#!/bin/bash

echo "=== Ejecutando Job de Limpieza ==="
# Eliminar la salida anterior si existe
hdfs dfs -rm -r -f /onpe/clean

# Ejecutar el MapReduce de limpieza (asumiendo que el jar está en la carpeta jobs)
hadoop jar jobs/limpieza/limpieza.jar \
  /onpe/raw \
  /onpe/clean

echo "=== Resultado ==="
hdfs dfs -ls /onpe/clean
