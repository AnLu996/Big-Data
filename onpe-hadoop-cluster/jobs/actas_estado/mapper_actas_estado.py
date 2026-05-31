#!/usr/bin/env python3
import sys

# Índices actas_resumen_tsv:
# 0 codigoMesa
# 1 idEleccion
# 2 idUbigeo
# 3 region
# 4 nombreLocal
# 5 codigoLocal
# 6 totalElectores
# 7 totalEmitidos
# 8 totalValidos
# 9 totalAsistentes
# 10 estadoActa
# 11 estadoComputo
# 12 codigoEstadoActa
# 13 descripcionEstadoActa

for line in sys.stdin:
    line = line.rstrip("\n")
    if not line:
        continue

    cols = line.split("\t")

    if len(cols) < 14:
        continue

    region = cols[3] if cols[3] else "DESCONOCIDO"
    descripcion_estado = cols[13] if cols[13] else "SIN_ESTADO"

    print(f"{descripcion_estado}\t1")
    print(f"{region}|{descripcion_estado}\t1")