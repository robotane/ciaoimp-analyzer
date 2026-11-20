#!/usr/bin/env python3
"""Compare les lignes CHECK du pilote Java et de la CLI moka (gaz cpu, ram, storage)."""
import re, sys

def lire(p):
    d = {}
    for l in open(p):
        m = re.match(r"CHECK (\S+) cpu=(\d+) ram=(\d+) storage=(\d+)", l)
        if m:
            d[m.group(1)] = tuple(int(m.group(i)) for i in (2, 3, 4))
    return d

a, b = lire(sys.argv[1]), lire(sys.argv[2])
ok = True
print("%-16s %-24s %-24s %s" % ("transaction", "CLI moka (cpu/ram/stor)", "pilote Java", "egal"))
for k in b:
    if k.startswith("account"):
        continue
    x, y = a.get(k), b.get(k)
    eg = x == y
    ok &= eg
    print("%-16s %-24s %-24s %s" % (k, "/".join(map(str, y)) if y else "-", "/".join(map(str, x)) if x else "-", "oui" if eg else "NON"))
print("RESULTAT :", "identique" if ok and set(k for k in b if not k.startswith("account")) == set(a) else "DIFFERENT")
sys.exit(0 if ok else 1)
