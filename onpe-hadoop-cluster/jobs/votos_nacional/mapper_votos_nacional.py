#!/usr/bin/env python3
import sys

# Índices del TSV limpio:
# 0 codigoMesa
# 1 idEleccion
# 2 idUbigeo
# 3 region
# 4 nombreLocalVotacion
# 5 codigoLocalVotacion
# 6 totalElectoresHabiles
# 7 totalVotosEmitidos
# 8 totalVotosValidos
# 9 totalAsistentes
# 10 estadoActa
# 11 estadoComputo
# 12 codigoEstadoActa
# 13 descripcionEstadoActa
# 14 adCodigo
# 15 adDescripcion
# 16 adVotos

for line in sys.stdin:
    line = line.rstrip("\n")
    if not line:
        continue

    cols = line.split("\t")

    if len(cols) < 17:
        continue

    descripcion_estado = cols[13]
    agrupacion = cols[15]

    try:
        votos = int(cols[16])
    except Exception:
        votos = 0

    if descripcion_estado != "CONTABILIZADA":
        continue

    if not agrupacion:
        continue

    print(f"{agrupacion}\t{votos}")