#!/usr/bin/env python3
"""Single pipeline: Hotmoka contracts of dsl/ -> one table (CSV + Markdown).

For every contract (all of dsl/, or the ones given as arguments):
  a. regenerate dsl/hotmoka_gas.pl from dsl/hotmoka_gas.pl.in and the constants (gen_model.py);
  b. CiaoPP: gas bound of every entry, one contract at a time (run_ciaopp.py: ulimit -v 3000000,
     CIAOPP_COST_MAX_MB=2800, timeout 900);
  c. CasLog: complexity function and class of every entry (caslog_prep/run.sh);
  d. the bounds of the measured operations (data/direct_ops.json) are evaluated at the measured
     sizes and compared with the maximal measured gas (data/bench_*.csv);
  e. everything is written to <out>/<timestamp>/ (never overwritten): tableau.csv, tableau.md,
     bounds.json and the raw outputs (ciaopp/, caslog/).

Usage: pipeline/run_pipeline.py [options] [contract ...]
  --out DIR          parent directory of the outputs (default build/pipeline)
  --moka CSV[,CSV]   measured gas (default data/bench_moka.csv,data/bench_tontine.csv)
  --constants JSON   cost-model constants (default data/constants_moka_sur.json: safe constants,
                     worst-case cost of the storage trees)
  --reference JSON   reference bounds.json (default pipeline/reference_bounds.json); differences
                     are reported
  --skip-caslog      do not run CasLog
  The bounds of the contracts that use the big_* primitives contain terms log(2, int(X)+1) (gas of
  the BigInteger operations by size): data/bigint_ops.json gives X for every measured point.
  --remesurer        first re-measure the gas with bench/mesurer.sh (docker --memory=2g, JVM -Xmx1g)
                     into <out>/<timestamp>/bench_moka.csv, used instead of --moka.
                     OFF by default (long: docker + JVM).
Environment: CASLOG (CasLog executable caslog.gprolog), ciaopp and ciaosh on the PATH.
Only one CiaoPP/ciaosh/CasLog at a time: before each run, the script waits (30 s steps) until
no other analysis process runs on the machine.
"""
import csv
import datetime
import json
import os
import re
import statistics
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
DSL = ROOT / "dsl"
DATA = ROOT / "data"
LIB = {"hotmoka", "hotmoka_gas", "hotmoka_tr"}
WITNESS = {"tontine"}          # written after the cost model was fixed: reported separately


def opt(name, default=None, flag=False):
    if name not in sys.argv:
        return False if flag else default
    i = sys.argv.index(name)
    if flag:
        del sys.argv[i]
        return True
    v = sys.argv[i + 1]
    del sys.argv[i:i + 2]
    return v


def rel(p):
    p = Path(p).resolve()
    return str(p.relative_to(ROOT)) if p.is_relative_to(ROOT) else str(p)


if "-h" in sys.argv or "--help" in sys.argv:
    print(__doc__)
    sys.exit(0)
OUTBASE = Path(opt("--out", ROOT / "build" / "pipeline")).resolve()
MOKA = [Path(x).resolve() for x in
        opt("--moka", f"{DATA / 'bench_moka.csv'},{DATA / 'bench_tontine.csv'}").split(",")]
CONSTS = Path(opt("--constants", DATA / "constants_moka_sur.json")).resolve()
REF = Path(opt("--reference", HERE / "reference_bounds.json")).resolve()
SKIP_CASLOG = opt("--skip-caslog", flag=True)
REMESURER = opt("--remesurer", flag=True)
names = sys.argv[1:] or sorted(p.stem for p in DSL.glob("*.pl") if p.stem not in LIB)

sys.path.insert(0, str(HERE))
import numpy as np                                # noqa: E402
from gas_data import load, choose, evaluate      # noqa: E402

STAMP = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
OUT = OUTBASE / STAMP
OUT.mkdir(parents=True, exist_ok=False)  # never overwrite


def log(*a):
    print(time.strftime("[%H:%M:%S]"), *a, flush=True)


ANALYSERS = ("ciaopp", "ciaosh", "gprolog")


def analysis_procs():
    """Other analysis processes (CiaoPP, ciaosh, CasLog) running on the machine."""
    mine = {os.getpid(), os.getppid()}
    out = subprocess.run(["pgrep", "-af", r"ciaopp|ciaosh|caslog|gprolog"],
                         capture_output=True, text=True).stdout
    procs = []
    for line in out.splitlines():
        pid, _, cmd = line.partition(" ")
        argv = cmd.split()
        if not argv or int(pid) in mine:
            continue
        exe = os.path.basename(argv[0])
        script = os.path.basename(argv[1]) if len(argv) > 1 else ""
        if exe.startswith(ANALYSERS) or (exe in ("sh", "bash", "dash") and "caslog" in script):
            procs.append(line)
    return procs


def wait_idle():
    while analysis_procs():
        log("waiting: another analysis process is running")
        time.sleep(30)


# ---- a. gas model --------------------------------------------------------------------------
log("a. generating dsl/hotmoka_gas.pl")
subprocess.run([sys.executable, str(HERE / "gen_model.py"), "--constants", str(CONSTS)], check=True)

# ---- (option) re-measure --------------------------------------------------------------------
if REMESURER:
    MOKA = [OUT / "bench_moka.csv"]
    log("re-measuring on a moka node ->", rel(MOKA[0]))
    subprocess.run([str(ROOT / "bench" / "mesurer.sh"), "--contracts", ",".join(names),
                    "--out", str(MOKA[0])], check=True)

# ---- b. CiaoPP, c. CasLog, one contract at a time -------------------------------------------
bounds, caslog = {}, {}
for n in names:
    wait_idle()
    log("b. CiaoPP", n)
    d = OUT / "ciaopp" / n
    subprocess.run([sys.executable, str(HERE / "run_ciaopp.py"), "--outdir", str(d), n], cwd=ROOT)
    f = d / f"{n}.json"
    r = json.loads(f.read_text()) if f.exists() else {"ok": False, "bounds": {}, "errors": ["no output"]}
    bounds[n] = r["bounds"]
    if not r["ok"]:
        log("   CiaoPP: PROBLEM", r["errors"][:2])
    if SKIP_CASLOG:
        continue
    wait_idle()
    log("c. CasLog", n)
    subprocess.run([str(ROOT / "caslog_prep" / "run.sh"), n, str(OUT / "caslog")],
                   cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    pl, o = OUT / "caslog" / f"{n}_caslog.pl", OUT / "caslog" / f"{n}_caslog.out"
    if pl.exists() and o.exists():
        entries = set(re.findall(r"^% entry: (\S+)/(\d+)", pl.read_text(), re.M))
        txt = o.read_text()
        for m in re.finditer(r"Time functions for predicate ([^/\s]+)/(\d+) :\s*\n\s*(\[[^\n]*\])", txt):
            if (m.group(1), m.group(2)) in entries:
                caslog.setdefault(n, {})[m.group(1)] = m.group(3)
(OUT / "bounds.json").write_text(json.dumps(bounds, indent=1))
(OUT / "caslog.json").write_text(json.dumps(caslog, indent=1))


# ---- d. comparison with the measured gas ------------------------------------------------------
def shape_of(xs, ys):
    xs, ys = np.array(xs, float), np.array(ys, float)
    if len(xs) < 3 or np.ptp(ys) == 0 or ys.mean() == 0:
        return "const" if len(xs) >= 1 else "-"
    return choose(xs, ys)[0]


def caslog_class(f):
    """Class of a CasLog time function. CasLog writes a power exp(Base, Exponent):
    exp($5,2) is a square (polynomial), exp(2,$5) an exponential."""
    if f is None:
        return "-"
    if "inf" in f:
        return "inf"
    if re.search(r"exp\(\s*[^,()]*\$\d+[^,()]*,\s*[^,()]*\$\d+", f) or \
            re.search(r"exp\(\s*\d+\s*,\s*[^)]*\$\d+", f):
        return "exp"
    degs = [int(k) for k in re.findall(r"exp\(\s*[^,()]*\$\d+[^,()]*,\s*(\d+)\s*\)", f)]
    if re.search(r"\$\d+\s*\*\s*\(?\s*\$\d+|\^|\*\*", f):
        degs.append(2)
    if degs and max(degs) >= 2:
        return "quad" if max(degs) == 2 else f"poly{max(degs)}"
    if "log" in f:
        return "log"
    args = re.findall(r"\$\d+", f)
    return "lin" if args else "const"


BIGINT = json.loads((DATA / "bigint_ops.json").read_text())
BIGINT.pop("_comment", None)


def amount(k):
    """k-th amount of the moka bench (simple_ponzi): 1000, then x11/10 + 1."""
    a = 1000
    for _ in range(k):
        a = a * 11 // 10 + 1
    return a


def formula_class(ub):
    """Class read on the formula when it depends on the size of an integer (term log(2, int(X)+1)),
    None otherwise (the class is then given by the shape of the curve)."""
    if not re.search(r"int\((?!length)[A-Za-z_]\w*\)", ub):
        return None
    if re.search(r"length\(\w+\)\*log\(|log\([^()]*(?:\([^()]*\)[^()]*)*\)\*length\(", ub):
        return "O(l*log m)"
    return "O(l+log m)" if "length(" in ub else "O(log m)"


C = json.loads(CONSTS.read_text())
ops = json.loads((DATA / "direct_ops.json").read_text())
data = load(MOKA)
ref = json.loads(REF.read_text()) if REF.exists() else {}
rows = []
for key, spec in ops.items():
    contract, op, var = key.split(".")
    if contract not in names:
        continue
    ub = bounds.get(contract, {}).get(spec["pred"])
    cf = caslog.get(contract, {}).get(spec["pred"])
    d = data.get((contract, op, var))
    row = dict(contract=contract, operation=f"{op}.{var}", ciaopp_bound=ub or "missing",
               ciaopp_class="-", caslog_function=cf or ("-" if SKIP_CASLOG else "missing"),
               caslog_class=caslog_class(cf), measured_class="-", points=0, above_bound="-",
               median_ratio="-", max_ratio="-", verdict="", same_as_reference="-")
    if ref:
        row["same_as_reference"] = "yes" if ref.get(contract, {}).get(spec["pred"]) == ub else "NO"
    if d:
        ns = sorted(d)
        row["points"] = len(ns)                       # one point per measured size n
        row["measured_class"] = shape_of(ns, [float(np.median(d[k]["gas"])) for k in ns])
    if ub is None:
        row["verdict"] = "CiaoPP ERROR (no bound)"
    elif ub == "inf":
        row["ciaopp_class"] = "inf"
        row["verdict"] = "UNBOUNDED (inf)"
    elif not d:
        row["verdict"] = "NOT MEASURED"
    else:
        lengths = {v: (lambda e: (lambda m: max(0, eval(e, {"n": m}))))(e)  # nosemgrep: eval-detected (local data file)
                   for v, e in spec["lengths"].items()}
        ints = BIGINT.get(key, {})

        def with_ints(n, ub=ub, ints=ints):
            e = ub
            for v, x in ints.items():                    # int(Value) -> integer size at point n
                e = e.replace(f"int({v})", str(eval(x, {"amount": amount, "n": n})))  # nosemgrep: eval-detected (local data file)
            return e
        try:
            ps = [evaluate(with_ints(k), lengths, k) for k in ns]
        except Exception as e:                           # noqa: BLE001
            ps = [None]
            row["verdict"] = f"evaluation ERROR ({e})"
        if None in ps:
            row["ciaopp_class"] = "inf"
            row["verdict"] = row["verdict"] or "UNBOUNDED (inf)"
        else:
            bd = [round(p + C["C_TX"]) for p in ps]
            gm = [max(d[k]["gas"]) for k in ns]                        # maximal gas over the runs
            ratios = [b / g for b, g in zip(bd, gm)]
            row["ciaopp_class"] = formula_class(ub) or shape_of(ns, bd)
            row["above_bound"] = sum(b < g for b, g in zip(bd, gm))
            row["median_ratio"] = round(float(np.median(ratios)), 3)
            row["max_ratio"] = round(max(ratios), 3)
            row["verdict"] = "OK (bound holds)" if row["above_bound"] == 0 else "VIOLATION"
    rows.append(row)

cols = list(rows[0])
with open(OUT / "tableau.csv", "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=cols)
    w.writeheader()
    w.writerows(rows)
with open(OUT / "tableau.md", "w") as f:
    f.write(f"# Pipeline {STAMP}\n\nContracts: {', '.join(names)}  \n"
            f"Measured gas: {', '.join(f'`{rel(m)}`' for m in MOKA)}  \n"
            f"Constants: `{rel(CONSTS)}`  \nReference: `{rel(REF)}`\n\n")
    f.write("| " + " | ".join(cols) + " |\n|" + "---|" * len(cols) + "\n")
    for r in rows:
        f.write("| " + " | ".join(str(r[c]).replace("|", "\\|") for c in cols) + " |\n")


# ---- e. summary ---------------------------------------------------------------------------------
def summary(label, rs):
    checked = [r for r in rs if r["above_bound"] != "-"]
    tot = sum(r["points"] for r in checked)
    above = sum(r["above_bound"] for r in checked)
    med = statistics.median(r["median_ratio"] for r in checked) if checked else float("nan")
    unb = [r["contract"] + "." + r["operation"] for r in rs if not r["verdict"].startswith("OK")]
    log(f"{label}: {len(rs)} operations ; points above the bound: {above}/{tot} ; "
        f"median of the per-operation median ratios bound/measured: {med:.3f} ; not checked: {unb or 'none'}")


log(f"table: {rel(OUT / 'tableau.csv')}  and  {rel(OUT / 'tableau.md')}")
summary("benchmark contracts", [r for r in rows if r["contract"] not in WITNESS])
if any(r["contract"] in WITNESS for r in rows):
    summary("witness contract", [r for r in rows if r["contract"] in WITNESS])
inf_caslog = sorted(f"{c}.{p}" for c, fs in caslog.items() for p, fn in fs.items() if "inf" in fn)
if not SKIP_CASLOG:
    log("CasLog functions [inf]:", inf_caslog or "none")
diff = [f"{r['contract']}.{r['operation']}" for r in rows if r["same_as_reference"] == "NO"]
log("bound differences vs reference:", diff or "none")
sys.exit(1 if diff or any(r["verdict"] == "VIOLATION" for r in rows) else 0)
