import csv, sys, math
from collections import defaultdict
rows = list(csv.DictReader(open(sys.argv[1])))
for r in rows:
    for k in ("n", "bh", "height", "levels", "touched", "bytes"): r[k] = int(r[k])
g = defaultdict(list)
for r in rows: g[(r["cls"], r["op"])].append(r)
for key, rs in sorted(g.items()):
    rs1 = [r for r in rs if r["n"] >= 1]
    print(key, "ops", len(rs))
    print("  max touched - 2bh:", max(r["touched"] - 2 * r["bh"] for r in rs1),
          " max touched/(bh):", round(max(r["touched"] / max(1, r["bh"]) for r in rs1), 2))
    print("  max levels - 2bh:", max(r["levels"] - 2 * r["bh"] for r in rs1), " max height-2log2(n+1):",
          round(max(r["height"] - 2 * math.log2(r["n"] + 1) for r in rs1), 2), " max bh-log2(n+1):", round(max(r["bh"] - math.log2(r["n"] + 1) for r in rs1), 2))
    # bytes vs touched : smallest S1 such that bytes <= S0 + S1*touched given S0 = max bytes at touched==1
    S0 = max((r["bytes"] for r in rs if r["touched"] <= 1), default=0)
    print("  bytes at touched<=1 max:", S0, " max (bytes-S0)/(touched-1):",
          round(max(((r["bytes"] - S0) / (r["touched"] - 1) for r in rs if r["touched"] > 1), default=0), 1))
    print("  max bytes/log2(n+1) slope over intercept 346:", round(max((r["bytes"] - 346) / math.log2(r["n"] + 1) for r in rs1), 1),
          " max bytes:", max(r["bytes"] for r in rs))
    worst = max(rs1, key=lambda r: r["touched"] - 2 * r["bh"])
    print("  worst touched case:", {k: worst[k] for k in ("order", "n", "bh", "height", "levels", "touched", "bytes")})
