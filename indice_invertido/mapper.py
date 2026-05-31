import sys
import re
import os
import socket

node = socket.gethostname()

for line in sys.stdin:
    file_path = os.environ.get("mapreduce_map_input_file", "documento_desconocido")
    doc_name = os.path.basename(file_path)

    line = line.lower()

    words = re.findall(r"[a-záéíóúñü0-9]+", line)

    for word in words:
        # palabra    documento    nodo
        print(f"{word}\t{doc_name}\t{node}")


        