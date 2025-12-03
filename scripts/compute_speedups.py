def compute_speedups(p95_A, p95_C, p95_B, RPS_A, RPS_C, RPS_B):
    # ---- p95-based speedups (main metric) ----
    S16_p95 = p95_A / p95_C
    S26_p95 = p95_A / p95_B

    # ---- RPS-based speedups (secondary metric) ----
    S16_rps = RPS_C / RPS_A
    S26_rps = RPS_B / RPS_A

    return {
        "S16_p95": round(S16_p95, 4),
        "S26_p95": round(S26_p95, 4),
        "S16_rps": round(S16_rps, 4),
        "S26_rps": round(S26_rps, 4),
    }

# Replace these with the actual values Martin sends you:

p95_A = 3800      # ms
p95_B = 180       # ms
p95_C = 150       # ms

RPS_A = 0.2606      # requests/sec
RPS_B = 95.1012
RPS_C = 95.4655

result = compute_speedups(p95_A, p95_C, p95_B, RPS_A, RPS_C, RPS_B)

print("\n=== Speedup Results ===")
print(f"S16 (p95-based): {result['S16_p95']}")
print(f"S26 (p95-based): {result['S26_p95']}")
print(f"S16 (RPS-based): {result['S16_rps']}")
print(f"S26 (RPS-based): {result['S26_rps']}")