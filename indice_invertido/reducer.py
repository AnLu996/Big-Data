import sys

current_word = None
documents = set()
nodes = set()

for line in sys.stdin:
    line = line.strip()

    if not line:
        continue

    try:
        word, doc, node = line.split("\t", 2)
    except ValueError:
        continue

    if current_word == word:
        documents.add(doc)
        nodes.add(node)
    else:
        if current_word is not None:
            docs_output = ", ".join(sorted(documents))
            nodes_output = ", ".join(sorted(nodes))
            print(f"{current_word}\t{docs_output}\t{nodes_output}")

        current_word = word
        documents = {doc}
        nodes = {node}

# Última palabra
if current_word is not None:
    docs_output = ", ".join(sorted(documents))
    nodes_output = ", ".join(sorted(nodes))
    print(f"{current_word}\t{docs_output}\t{nodes_output}")