#!/bin/bash

set -euo pipefail

# =================================================================
# SCRIPT 2: SUBIDA REANUDABLE DE DATOS A HDFS
# =================================================================

LOCAL_DATA_DIR="data"
HDFS_RAW_DIR="/onpe/raw"
HDFS_CLEAN_DIR="/onpe/clean"
HDFS_OUTPUT_DIR="/onpe/output"

BATCH_SIZE=300
LOG_FILE="upload_hdfs.log"

echo "=== SUBIDA DE DATOS ONPE A HDFS ===" | tee -a "$LOG_FILE"


# 1. Validar carpeta local

if [ ! -d "$LOCAL_DATA_DIR" ]; then
  echo "ERROR: No existe la carpeta local '$LOCAL_DATA_DIR'." | tee -a "$LOG_FILE"
  echo "Asegúrate de haber ejecutado primero 1_download_data.sh." | tee -a "$LOG_FILE"
  exit 1
fi

LOCAL_COUNT=$(find "$LOCAL_DATA_DIR" -type f -name "*.json" | wc -l)

echo "Archivos JSON locales encontrados: $LOCAL_COUNT" | tee -a "$LOG_FILE"

if [ "$LOCAL_COUNT" -eq 0 ]; then
  echo "ERROR: No hay archivos JSON en '$LOCAL_DATA_DIR'." | tee -a "$LOG_FILE"
  exit 1
fi


# 2. Preparar estructura HDFS

echo "=== 1. Preparando estructura en HDFS ===" | tee -a "$LOG_FILE"

hdfs dfs -mkdir -p "$HDFS_RAW_DIR"
hdfs dfs -mkdir -p "$HDFS_CLEAN_DIR"
hdfs dfs -mkdir -p "$HDFS_OUTPUT_DIR"
hdfs dfs -mkdir -p "$HDFS_OUTPUT_DIR/conteo_lineas"
hdfs dfs -mkdir -p "$HDFS_OUTPUT_DIR/votos_nacional"
hdfs dfs -mkdir -p "$HDFS_OUTPUT_DIR/votos_region"
hdfs dfs -mkdir -p "$HDFS_OUTPUT_DIR/votos_especiales"
hdfs dfs -mkdir -p "$HDFS_OUTPUT_DIR/actas_estado"
hdfs dfs -mkdir -p "$HDFS_OUTPUT_DIR/indice_invertido"


# 3. Subir archivos en lotes

echo "=== 2. Subiendo datos a HDFS en lotes de $BATCH_SIZE archivos ===" | tee -a "$LOG_FILE"
echo "Destino HDFS: $HDFS_RAW_DIR" | tee -a "$LOG_FILE"

find "$LOCAL_DATA_DIR" -type f -name "*.json" -print0 | \
xargs -0 -n "$BATCH_SIZE" bash -c '
  HDFS_RAW_DIR="$1"
  shift

  echo "Subiendo lote de $# archivos..."
  hdfs dfs -put -f "$@" "$HDFS_RAW_DIR/"
' _ "$HDFS_RAW_DIR"

# 4. Verificación

echo "=== 3. Verificación de carga ===" | tee -a "$LOG_FILE"

HDFS_COUNT=$(hdfs dfs -ls "$HDFS_RAW_DIR" | grep ".json" | wc -l)

echo "Archivos locales: $LOCAL_COUNT" | tee -a "$LOG_FILE"
echo "Archivos en HDFS: $HDFS_COUNT" | tee -a "$LOG_FILE"

if [ "$HDFS_COUNT" -eq 0 ]; then
  echo "ERROR: No se subieron archivos a HDFS." | tee -a "$LOG_FILE"
  exit 1
fi

if [ "$HDFS_COUNT" -lt "$LOCAL_COUNT" ]; then
  echo "ADVERTENCIA: Hay menos archivos en HDFS que en local." | tee -a "$LOG_FILE"
  echo "Puedes volver a ejecutar este script para reintentar la subida." | tee -a "$LOG_FILE"
  exit 1
fi

echo "=== 4. Tamaño ocupado en HDFS ===" | tee -a "$LOG_FILE"
hdfs dfs -du -h "$HDFS_RAW_DIR" | tail -10 | tee -a "$LOG_FILE"

echo "=== 5. Muestra de archivos en HDFS ===" | tee -a "$LOG_FILE"
hdfs dfs -ls "$HDFS_RAW_DIR" | head | tee -a "$LOG_FILE"

echo "¡Subida a HDFS completada exitosamente!" | tee -a "$LOG_FILE"
echo "La carpeta local '$LOCAL_DATA_DIR' NO fue eliminada por seguridad." | tee -a "$LOG_FILE"
echo "Cuando confirmes que todo está bien, puedes borrarla manualmente con:" | tee -a "$LOG_FILE"
echo "rm -rf $LOCAL_DATA_DIR" | tee -a "$LOG_FILE"
