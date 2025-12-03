def solve_f_from_speedups(S16, S26):
    """
    Solve for f using two observed speedups:
    y_N = 1/S(N) = f + (1-f)/N
    """
    y16 = 1 / S16
    y26 = 1 / S26

    # Two equations:
    # y16 = f + (1-f)/16
    # y26 = f + (1-f)/26

    # Convert to form:
    # y = f + (1/N) - f*(1/N)
    # y = (1/N) + f*(1 - 1/N)

    # So:
    # y16 = (1/16) + f*(15/16)
    # y26 = (1/26) + f*(25/26)

    # Solve linear equation for f
    f = (y16 - 1/16) / (15/16)

    # OR (to be safe, solve both ways and average):
    f_alt = (y26 - 1/26) / (25/26)

    f_final = (f + f_alt) / 2

    return {
        "f": round(f_final, 6),
        "parallel_fraction": round(1 - f_final, 6),
        "S_max": round(1 / f_final, 4),
        "y16": round(y16, 6),
        "y26": round(y26, 6)
    }


# Replace these with your real measured speedups:
S16 = 25.3333
S26 = 21.1111

result = solve_f_from_speedups(S16, S26)

print("\n=== Solved Amdahl Parameters ===")
print(f"f (serial fraction):        {result['f']}")
print(f"(1 - f) parallel fraction:  {result['parallel_fraction']}")
print(f"Max theoretical speedup:    S_max = {result['S_max']}x")
print(f"y16 = 1/S16 = {result['y16']}")
print(f"y26 = 1/S26 = {result['y26']}")