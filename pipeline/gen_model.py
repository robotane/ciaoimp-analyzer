#!/usr/bin/env python3
"""Write dsl/hotmoka_gas.pl from dsl/hotmoka_gas.pl.in and a constants file.
Usage: gen_model.py [--constants FILE] [--out FILE]
Default constants: data/constants_moka_sur.json (safe constants: worst-case cost of the
Takamaka storage trees, see costmodel/tree/). Every @C_*@ placeholder of the .in must have a
value; the gas package holds integers (values rounded)."""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
D = ROOT / "dsl"


def opt(name, default):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else default


if "-h" in sys.argv or "--help" in sys.argv:
    print(__doc__)
    sys.exit(0)
C = json.loads(Path(opt("--constants", ROOT / "data" / "constants_moka_sur.json")).read_text())
OUT = Path(opt("--out", D / "hotmoka_gas.pl"))
s = (D / "hotmoka_gas.pl.in").read_text()
# constants files older than the remove constants: map_remove keeps the write constants
for r, w in (("C_TREER0", "C_TREEW0"), ("C_TREER1", "C_TREEW1")):
    C.setdefault(r, C[w])
missing = sorted(set(re.findall(r"@(\w+)@", s)) - set(C))
if missing:
    sys.exit(f"constants missing: {missing}")
s = re.sub(r"@(\w+)@", lambda m: str(round(C[m.group(1)])), s)
OUT.write_text(s)
print(OUT.relative_to(ROOT) if OUT.is_relative_to(ROOT) else OUT, "written:",
      {k: round(v) for k, v in C.items() if k != "C_TX"})
