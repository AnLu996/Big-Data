#!/usr/bin/env python3
import sys
import json
import re


def clean_text(value):
    if value is None:
        return ""
    value = str(value)
    value = value.replace("\t", " ")
    value = value.replace("\n", " ")
    value = value.replace("\r", " ")
    value = re.sub(r"\s+", " ", value)
    return value.strip().upper()


def safe_int(value):
    try:
        if value is None or value == "":
            return 0
        return int(float(value))
    except Exception:
        return 0


def get_region_from_ubigeo(id_ubigeo):
    ubigeo = str(id_ubigeo or "").zfill(6)

    departamentos = {
        "01": "AMAZONAS",
        "02": "ANCASH",
        "03": "APURIMAC",
        "04": "AREQUIPA",
        "05": "AYACUCHO",
        "06": "CAJAMARCA",
        "07": "CALLAO",
        "08": "CUSCO",
        "09": "HUANCAVELICA",
        "10": "HUANUCO",
        "11": "ICA",
        "12": "JUNIN",
        "13": "LA LIBERTAD",
        "14": "LAMBAYEQUE",
        "15": "LIMA",
        "16": "LORETO",
        "17": "MADRE DE DIOS",
        "18": "MOQUEGUA",
        "19": "PASCO",
        "20": "PIURA",
        "21": "PUNO",
        "22": "SAN MARTIN",
        "23": "TACNA",
        "24": "TUMBES",
        "25": "UCAYALI",
    }

    codigo_dep = ubigeo[:2]
    return departamentos.get(codigo_dep, "DESCONOCIDO")


def emit_clean_row(acta, detalle):
    codigo_mesa = clean_text(acta.get("codigoMesa"))
    id_eleccion = safe_int(acta.get("idEleccion"))
    id_ubigeo = clean_text(acta.get("idUbigeo"))
    region = get_region_from_ubigeo(id_ubigeo)

    nombre_local = clean_text(acta.get("nombreLocalVotacion"))
    codigo_local = clean_text(acta.get("codigoLocalVotacion"))

    total_electores = safe_int(acta.get("totalElectoresHabiles"))
    total_emitidos = safe_int(acta.get("totalVotosEmitidos"))
    total_validos = safe_int(acta.get("totalVotosValidos"))
    total_asistentes = safe_int(acta.get("totalAsistentes"))

    estado_acta = clean_text(acta.get("estadoActa"))
    estado_computo = clean_text(acta.get("estadoComputo"))
    codigo_estado = clean_text(acta.get("codigoEstadoActa"))
    descripcion_estado = clean_text(acta.get("descripcionEstadoActa"))

    ad_codigo = clean_text(detalle.get("adCodigo"))
    ad_descripcion = clean_text(detalle.get("adDescripcion"))
    ad_votos = safe_int(detalle.get("adVotos"))

    # TSV: separar por tabuladores evita problemas con comas en nombres.
    fields = [
        codigo_mesa,
        str(id_eleccion),
        id_ubigeo,
        region,
        nombre_local,
        codigo_local,
        str(total_electores),
        str(total_emitidos),
        str(total_validos),
        str(total_asistentes),
        estado_acta,
        estado_computo,
        codigo_estado,
        descripcion_estado,
        ad_codigo,
        ad_descripcion,
        str(ad_votos),
    ]

    print("\t".join(fields))


def process_line(line):
    line = line.strip()
    if not line:
        return

    try:
        obj = json.loads(line)
    except Exception:
        return

    data = obj.get("data", [])

    if not isinstance(data, list) or len(data) == 0:
        return

    for acta in data:
        if not isinstance(acta, dict):
            continue

        detalle = acta.get("detalle", [])

        if not isinstance(detalle, list) or len(detalle) == 0:
            continue

        for d in detalle:
            if isinstance(d, dict):
                emit_clean_row(acta, d)


for line in sys.stdin:
    process_line(line)