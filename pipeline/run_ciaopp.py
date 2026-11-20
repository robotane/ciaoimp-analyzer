#!/usr/bin/env python3
"""CiaoPP gas bounds of contracts of dsl/, one contract at a time (one CiaoPP process at a
time, memory capped: ulimit -v 3000000, CIAOPP_COST_MAX_MB=2800, timeout 900 s).
Uses the gas package dsl/hotmoka_gas.pl as it is (generate it first with gen_model.py).
Writes <outdir>/<contract>.json (bound of each entry predicate) and <outdir>/bounds_raw.json.
Usage: run_ciaopp.py [--outdir DIR] [contract ...]      (default outdir: build/ciaopp)"""
import json
import os
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
DSL = ROOT / "dsl"
LIB = {"hotmoka", "hotmoka_gas", "hotmoka_tr"}

args = sys.argv[1:]
if "-h" in args or "--help" in args:
    print(__doc__)
    sys.exit(0)
OUT = ROOT / "build" / "ciaopp"
if "--outdir" in args:
    i = args.index("--outdir")
    OUT = Path(args[i + 1]).resolve()
    del args[i:i + 2]
names = args or sorted(p.stem for p in DSL.glob("*.pl") if p.stem not in LIB)
OUT.mkdir(parents=True, exist_ok=True)
env = dict(os.environ, CIAOPP_COST_MAX_MB=os.environ.get("CIAOPP_COST_MAX_MB", "2800"))
for n in names:
    subprocess.run(["bash", "-c", 'ulimit -v 3000000; timeout 900 "$0" "$1" "$2" "$3"',
                    sys.executable, str(HERE / "ciaopp_cost.py"), n, str(OUT)], cwd=ROOT, env=env)
    f = OUT / f"{n}.json"
    print(n, "ok" if f.exists() and json.loads(f.read_text())["ok"] else "PROBLEM", flush=True)
allb = {n: json.loads((OUT / f"{n}.json").read_text())["bounds"] for n in names if (OUT / f"{n}.json").exists()}
(OUT / "bounds_raw.json").write_text(json.dumps(allb, indent=1))
