#!/bin/bash

# =================================================================
# SCRIPT 1: DESCARGA Y EXTRACCIÓN DE DATOS
# =================================================================

DRIVE_ID="1HxNfJxIrVPCL8UE83IAQrZ0kjgwdzFkh"
FILE_NAME="data.zip"

echo "=== 0. Instalando dependencias base ==="
sudo apt update
sudo apt install -y python3-pip python3-venv unzip

echo "=== 1. Instalando gdown ==="
python3 -m pip install --user gdown
export PATH="$HOME/.local/bin:$PATH"

echo "=== 2. Descargando archivo data.zip desde Google Drive ==="
python3 -m gdown "$DRIVE_ID" -O "$FILE_NAME"

if [ ! -f "$FILE_NAME" ]; then
    echo "Error: No se pudo descargar el archivo $FILE_NAME."
    exit 1
fi

echo "=== 3. Descomprimiendo archivo ZIP (Paciencia, 23GB) ==="
unzip -o "$FILE_NAME"

echo "=== 4. Borrando el ZIP para liberar espacio ==="
rm "$FILE_NAME"

echo "¡Descarga y extracción completadas! Ahora corre bash upload_hdfs.sh"
