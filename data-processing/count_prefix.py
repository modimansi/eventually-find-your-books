import json
import sys
from collections import Counter

if len(sys.argv) < 2:
    print("Usage: python3 count_prefix.py <jsonl-file>")
    sys.exit(1)

filename = sys.argv[1]
prefixes = Counter()

with open(filename, "r", encoding="utf-8") as f:
    for line in f:
        if not line.strip():
            continue
        book = json.loads(line)
        pref = book.get("title_prefix", "0")
        prefixes[pref] += 1

total = sum(prefixes.values())
print(f"Total books: {total}")
print("\nPrefix distribution:")

for p in sorted(prefixes):
    count = prefixes[p]
    pct = count / total * 100
    print(f"{p}: {count:5d}  ({pct:5.2f}%)")