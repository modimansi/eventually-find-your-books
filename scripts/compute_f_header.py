import re
import statistics

def parse_phase_file(path):
    """Parse header timings from a raw output text file."""
    with open(path, "r") as f:
        text = f.read()

    # Extract numeric fields
    parse_vals = list(map(int, re.findall(r"X-Phase-Parse:\s*(\d+)", text)))
    fanout_vals = list(map(int, re.findall(r"X-Phase-Fanout:\s*(\d+)", text)))
    agg_vals = list(map(int, re.findall(r"X-Phase-Aggregate:\s*(\d+)", text)))
    total_vals = list(map(int, re.findall(r"X-Phase-Total:\s*(\d+)", text)))

    def avg(lst):
        return round(statistics.mean(lst), 2) if lst else 0

    avg_parse = avg(parse_vals)
    avg_fanout = avg(fanout_vals)
    avg_aggregate = avg(agg_vals)
    avg_total = avg(total_vals)

    # f_header = (parse + aggregate) / total
    f_header = round((avg_parse + avg_aggregate) / avg_total, 4) if avg_total > 0 else None

    return {
        "avg_parse": avg_parse,
        "avg_fanout": avg_fanout,
        "avg_aggregate": avg_aggregate,
        "avg_total": avg_total,
        "count": len(total_vals),
        "f_header": f_header
    }

# -----------------------------------------------------------
# Format: (ArchName, N, filePath)
# -----------------------------------------------------------
experiments = [
    ("B1", 26, "n26_B1.txt"),
    ("B2", 52, "n52_B2.txt"),
    ("C", 16, "n16_C.txt"),
]

# Parse all experiments
results = []
for arch, n, path in experiments:
    r = parse_phase_file(path)
    r["arch"] = arch
    r["n"] = n
    results.append(r)

# -----------------------------------------------------------
# Pretty print the result table
# -----------------------------------------------------------
print("\n=== Phase Timing Summary ===")
print("""
| Arch | N  | Parse(ms) | Fanout(ms) | Aggregate(ms) | Total(ms) | f_header |
|------|----|-----------|------------|----------------|-----------|----------|
""")

for r in results:
    print(f"| {r['arch']} | {r['n']} | {r['avg_parse']} | {r['avg_fanout']} | {r['avg_aggregate']} | {r['avg_total']} | {r['f_header']} |")

print()