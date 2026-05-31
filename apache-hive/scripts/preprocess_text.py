import os
import re
import unicodedata
from pathlib import Path

RAW_DIR = Path("data/raw_text")
OUT_DIR = Path("data/processed_text")
OUT_DIR.mkdir(parents=True, exist_ok=True)

def limpiar_texto(texto):
    texto = texto.lower()

    texto = unicodedata.normalize("NFD", texto)
    texto = texto.encode("ascii", "ignore").decode("utf-8")

    texto = re.sub(r"[^a-z0-9\s]", " ", texto)
    texto = re.sub(r"\s+", " ", texto)

    return texto.strip()

for archivo in RAW_DIR.glob("*.txt"):
    with open(archivo, "r", encoding="utf-8", errors="ignore") as f:
        texto = f.read()

    texto_limpio = limpiar_texto(texto)

    salida = OUT_DIR / archivo.name
    with open(salida, "w", encoding="utf-8") as f:
        f.write(texto_limpio)

    print(f"Procesado: {archivo.name} -> {salida}")