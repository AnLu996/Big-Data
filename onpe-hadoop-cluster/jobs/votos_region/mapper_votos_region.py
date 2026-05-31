#!/usr/bin/env python3
import sys

for line in sys.stdin:
    line = line.rstrip("\n")
    if not line:
        continue

    cols = line.split("\t")

    if len(cols) < 17:
        continue

    region = cols[3]
    descripcion_estado = cols[13]
    agrupacion = cols[15]

    try:
        votos = int(cols[16])
    except Exception:
        votos = 0

    if descripcion_estado != "CONTABILIZADA":
        continue

    if not region:
        region = "DESCONOCIDO"

    if not agrupacion:
        continue

    key = f"{region}|{agrupacion}"
    print(f"{key}\t{votos}")