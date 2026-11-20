#!/usr/bin/env python3
"""Runs the tree simulator (llrb_sim.py) on several key orders and collects, per operation:
n, black height and height of the old tree, recursion levels, new/modified nodes, and the exact
bytes of the updates (Java harness UpdSize = Hotmoka's own marshalling). Writes a CSV.
Usage: experiment.py N SEEDS out.csv"""
import random, sys, subprocess, csv, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from llrb_sim import *

# HARNESS: directory holding the compiled UpdSize.class (derive_arbre.py compiles it)
HARNESS = os.environ.get("HARNESS", "")
M = os.environ.get("HOTMOKA_MODULES") or sys.exit("set HOTMOKA_MODULES (see README.md)")
JAVA = os.path.join(os.environ.get("JAVA_HOME") or sys.exit("set JAVA_HOME to a JDK 21"), "bin", "java")
CP = f"{HARNESS}:{M}/explicit_or_automatic/*:{M}/unnamed/*"

def orders(N, seed):
    r = random.Random(seed)
    yield "random", [r.random() for _ in range(N)]
    if seed == 0:
        yield "asc", list(range(N))
        yield "desc", list(range(N, 0, -1))
        zz, lo, hi = [], 0, N
        while lo < hi:
            zz.append(lo); lo += 1
            if lo < hi: zz.append(hi); hi -= 1
        yield "zigzag", zz
        b = max(1, (N - 1).bit_length())
        yield "bitrev", sorted(range(N), key=lambda i: int(bin(i)[2:].zfill(b)[::-1], 2))

def run(N, seeds, outcsv):
    rows, specs = [], []
    for seed in seeds:
        for name, keys in orders(N, seed):
            for cls in (Persistent, Mutable):
                t, live, tag = cls(), [], f"{name}{seed}{cls.__name__[0]}"
                def op_(op, key, i):
                    n, bh, hn = len(live), black_height(t.root), height_nodes(t.root)
                    t.begin(Ctx(f"{tag}t{i}{op}"))
                    if op == "remove": t.remove(key)
                    else: t.put(key, f"{tag}v{i}{op}:0")      # value: old object of a distinct tx
                    ups, touched = t.end(f"{tag}map:1")
                    specs.append(ups)
                    rows.append(dict(order=name, seed=seed, cls=cls.__name__, op=op, n=n, bh=bh, height=hn,
                                     levels=t.levels, touched=touched))
                for i, kv in enumerate(keys):
                    key = (kv, f"{tag}k{i}:0")                # key: old object of a distinct tx
                    op_("insert", key, i); live.append(key)
                    op_("update", live[(i * 7919) % len(live)], i)
                    if cls is Mutable:
                        continue    # StorageTreeMap.removeMin drops the result of balance(): see arbre_pire_cas.md
                    k = live[(i * 104729) % len(live)]
                    op_("remove", k, i); live.remove(k)
                    op_("insert", k, i); live.append(k)         # reinsert: n keeps growing
    inp = "\n".join("\n".join(u) + "\nEND" for u in specs) + "\n"
    out = subprocess.run([JAVA, "-Xmx512m", "-cp", CP, "UpdSize"], input=inp, capture_output=True, text=True, check=True).stdout.split("\n")  # nosemgrep: dangerous-subprocess-use-tainted-env-args (argument list, no shell, local JDK)
    for r, line in zip(rows, out):
        r["bytes"] = int(line.split()[0])
    with open(outcsv, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0])); w.writeheader(); w.writerows(rows)
    return rows

if __name__ == "__main__":
    run(int(sys.argv[1]), list(range(int(sys.argv[2]))), sys.argv[3])
