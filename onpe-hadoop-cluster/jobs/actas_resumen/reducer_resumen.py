#!/usr/bin/env python3
import sys

last_key = None
last_value = None

for line in sys.stdin:
    line = line.rstrip("\n")
    if not line:
        continue

    parts = line.split("\t", 1)
    if len(parts) != 2:
        continue

    key, value = parts

    if key != last_key and last_key is not None:
        print(last_value)

    last_key = key
    last_value = value

if last_key is not None:
    print(last_value)