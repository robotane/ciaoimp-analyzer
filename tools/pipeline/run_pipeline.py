#!/usr/bin/env python3
"""Pipeline unique : 14 contrats Hotmoka -> un tableau (CSV + Markdown).

Pour chaque contrat (ou la liste passee en argument) :
  a. regenere data/contracts_hotmoka/hotmoka_gas.pl depuis hotmoka_gas.pl.in et les constantes
     moka (hotmoka-bench/costmodel/gen_model.py) ;
  b. CiaoPP : borne de gaz, un contrat a la fois (rerun_ciaopp_moka.py : ulimit -v 3000000,
     CIAOPP_COST_MAX_MB=2800, timeout 900) ;
  c. CasLog : classe de complexite (tools/caslog_prep/run.sh) ;
  d. bornes des operations mesurees (costmodel/direct_ops.json, meme logique que
     final_bounds.py / compare_moka.py) comparees au gaz mesure (results/bench_moka.csv) ;
  e. ecriture dans <sortie>/<horodatage>/ (jamais d'ecrasement, rien n'est supprime) de
     tableau.csv et tableau.md, plus les sorties brutes (ciaopp/, caslog/).

Usage : tools/pipeline/run_pipeline.py [options] [contrat ...]
  --out DIR          dossier parent des sorties (defaut build/pipeline)
  --moka CSV         gaz mesure (defaut $HOTMOKA_BENCH/results/bench_moka.csv)
  --constants JSON   constantes (defaut $HOTMOKA_BENCH/costmodel/constants_moka_sur.json : constantes
                     sures, cout de l'arbre au pire cas)
  --reference JSON   bounds.json de reference (defaut tools/pipeline/reference_bounds.json : bornes
                     CiaoPP des 14 contrats et de tontine avec ces constantes) ; ecarts signales
  --skip-caslog      ne lance pas CasLog
  --remesurer        relance d'abord moka/mesurer.sh (docker --memory=2g, JVM -Xmx1g) dans un
                     nouveau CSV <sortie>/<horodatage>/bench_moka.csv utilise a la place de --moka.
                     DESACTIVE par defaut (long : docker + JVM).
Variables : HOTMOKA_BENCH (defaut ../hotmoka-bench relatif a ciaoimp-analyzer), CASLOG.
Un seul CiaoPP/ciaosh/CasLog a la fois : avant chaque lancement, attente (sleep 30) qu'aucun
autre processus d'analyse ne tourne sur la machine.
"""
import csv, datetime, json, os, re, subprocess, sys, time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]            # checkout (ou worktree) de ciaoimp-analyzer


def _default_bench():
    """../hotmoka-bench relatif a ciaoimp-analyzer ; depuis un worktree, relatif au depot principal."""
    if (ROOT.parent / "hotmoka-bench").is_dir():
        return ROOT.parent / "hotmoka-bench"
    common = subprocess.run(["git", "-C", str(ROOT), "rev-parse", "--path-format=absolute", "--git-common-dir"],
                            capture_output=True, text=True).stdout.strip()
    return Path(common).parent.parent / "hotmoka-bench"


BENCH = Path(os.environ.get("HOTMOKA_BENCH") or _default_bench()).resolve()
SRC = ROOT / "data" / "contracts_hotmoka"
LIB = {"hotmoka", "hotmoka_gas", "hotmoka_tr"}
ENV = dict(os.environ, CIAOIMP_ROOT=str(ROOT))


def opt(name, default=None, flag=False):
    if name not in sys.argv:
        return False if flag else default
    i = sys.argv.index(name)
    if flag:
        del sys.argv[i]; return True
    v = sys.argv[i + 1]; del sys.argv[i:i + 2]; return v


if "-h" in sys.argv or "--help" in sys.argv:
    print(__doc__); sys.exit(0)
OUTBASE = Path(opt("--out", ROOT / "build" / "pipeline"))
MOKA = Path(opt("--moka", BENCH / "results" / "bench_moka.csv"))
CONSTS = Path(opt("--constants", BENCH / "costmodel" / "constants_moka_sur.json"))
REF = Path(opt("--reference", ROOT / "tools" / "pipeline" / "reference_bounds.json"))
SKIP_CASLOG = opt("--skip-caslog", flag=True)
REMESURER = opt("--remesurer", flag=True)
names = sys.argv[1:] or sorted(p.stem for p in SRC.glob("*.pl") if p.stem not in LIB)

sys.path.insert(0, str(BENCH / "analysis")); sys.path.insert(0, str(BENCH / "costmodel"))
import numpy as np                       # noqa: E402
from analyse import load, choose         # noqa: E402  (gaz mesure, forme de croissance)
from compare import evaluate             # noqa: E402  (evaluation d'une borne CiaoPP)

STAMP = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
OUT = OUTBASE / STAMP
OUT.mkdir(parents=True, exist_ok=False)  # jamais d'ecrasement


def log(*a):
    print(time.strftime("[%H:%M:%S]"), *a, flush=True)


def analysis_procs():
    """Processus d'analyse (CiaoPP/ciaosh/CasLog) hors kate et hors ce pipeline."""
    mine = {os.getpid(), os.getppid()}
    out = subprocess.run(["pgrep", "-af", r"bin/ciaopp|ciaosh|caslog"], capture_output=True, text=True).stdout
    return [l for l in out.splitlines() if "kate" not in l and "pgrep" not in l
            and int(l.split()[0]) not in mine]


def wait_idle():
    while analysis_procs():
        log("attente : un autre processus d'analyse tourne")
        time.sleep(30)


# ---- a. modele de gaz ------------------------------------------------------------------------
log("a. generation de hotmoka_gas.pl")
subprocess.run([sys.executable, str(BENCH / "costmodel" / "gen_model.py"), "--constants", str(CONSTS)],  # nosemgrep: dangerous-subprocess-use-tainted-env-args (liste d'arguments, sans shell, outil local)
               env=ENV, check=True)

# ---- (option) remesure ---------------------------------------------------------------------
if REMESURER:
    MOKA = OUT / "bench_moka.csv"
    log("remesure moka ->", MOKA)
    subprocess.run([str(BENCH / "moka" / "mesurer.sh"), "--contracts", ",".join(names), "--out", str(MOKA)],  # nosemgrep: dangerous-subprocess-use-tainted-env-args (liste d'arguments, sans shell, outil local)
                   check=True)

# ---- b. CiaoPP, c. CasLog, un contrat a la fois ----------------------------------------------
bounds, caslog = {}, {}
for n in names:
    wait_idle()
    log("b. CiaoPP", n)
    d = OUT / "ciaopp" / n
    subprocess.run([sys.executable, str(BENCH / "costmodel" / "rerun_ciaopp_moka.py"), "--outdir", str(d), n],  # nosemgrep: dangerous-subprocess-use-tainted-env-args (liste d'arguments, sans shell, outil local)
                   env=ENV, cwd=ROOT)
    f = d / f"{n}.json"
    r = json.loads(f.read_text()) if f.exists() else {"ok": False, "bounds": {}, "errors": ["pas de sortie"]}
    bounds[n] = r["bounds"]
    if not r["ok"]:
        log("   CiaoPP : PROBLEME", r["errors"][:2])
    if SKIP_CASLOG:
        continue
    wait_idle()
    log("c. CasLog", n)
    subprocess.run([str(ROOT / "tools" / "caslog_prep" / "run.sh"), n, str(OUT / "caslog")],
                   env=ENV, cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    pl, o = OUT / "caslog" / f"{n}_caslog.pl", OUT / "caslog" / f"{n}_caslog.out"
    if pl.exists() and o.exists():
        entries = set(re.findall(r"^% entry: (\S+)/(\d+)", pl.read_text(), re.M))
        txt = o.read_text()
        for m in re.finditer(r"Time functions for predicate ([^/\s]+)/(\d+) :\s*\n\s*(\[[^\n]*\])", txt):
            if (m.group(1), m.group(2)) in entries:
                caslog.setdefault(n, {})[m.group(1)] = m.group(3)
(OUT / "bounds.json").write_text(json.dumps(bounds, indent=1))


# ---- d. comparaison au gaz mesure --------------------------------------------------------------
def shape_of(xs, ys):
    xs, ys = np.array(xs, float), np.array(ys, float)
    if len(xs) < 3 or np.ptp(ys) == 0 or ys.mean() == 0:
        return "const" if len(xs) >= 1 else "-"
    return choose(xs, ys)[0]


def caslog_class(f):
    """Classe d'une fonction de temps CasLog. CasLog ecrit une puissance exp(Base, Exposant) :
    exp($5,2) est un carre (polynome), exp(2,$5) une exponentielle."""
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


C = json.loads(CONSTS.read_text())
ops = json.loads((BENCH / "costmodel" / "direct_ops.json").read_text())
data = load([MOKA])
ref = json.loads(REF.read_text()) if REF.exists() else {}
rows = []
for key, spec in ops.items():
    contract, op, var = key.split(".")
    if contract not in names:
        continue
    ub = bounds.get(contract, {}).get(spec["pred"])
    cf = caslog.get(contract, {}).get(spec["pred"])
    d = data.get((contract, op, var))
    row = dict(contrat=contract, operation=f"{op}.{var}", borne_ciaopp=ub or "absente",
               classe_ciaopp="-", caslog_fonction=cf or ("-" if SKIP_CASLOG else "absente"),
               classe_caslog=caslog_class(cf), classe_mesuree="-", points=0, au_dessus="-",
               ratio_median="-", ratio_max="-", verdict="", egal_reference="-")
    if ref:
        row["egal_reference"] = "oui" if ref.get(contract, {}).get(spec["pred"]) == ub else "NON"
    if d:
        ns = sorted(d)
        row["points"] = len(ns)
        row["classe_mesuree"] = shape_of(ns, [float(np.median(d[n]["gas"])) for n in ns])
    if ub is None:
        row["verdict"] = "ERREUR CiaoPP (pas de borne)"
    elif ub == "inf":
        row["classe_ciaopp"] = "inf"
        row["verdict"] = "NON BORNE (inf)"
    elif not d:
        row["verdict"] = "SANS MESURE"
    else:
        lengths = {v: (lambda e: (lambda m: max(0, eval(e, {"n": m}))))(e) for v, e in spec["lengths"].items()}
        try:
            ps = [evaluate(ub, lengths, n) for n in ns]
        except Exception as e:                           # noqa: BLE001
            ps = [None]; row["verdict"] = f"ERREUR evaluation ({e})"
        if None in ps:
            row["classe_ciaopp"] = "inf"
            row["verdict"] = row["verdict"] or "NON BORNE (inf)"
        else:
            bd = [round(p + C["C_TX"]) for p in ps]
            gm = [max(d[n]["gas"]) for n in ns]
            ratios = [b / g for b, g in zip(bd, gm)]
            row["classe_ciaopp"] = shape_of(ns, bd)
            row["au_dessus"] = sum(b < g for b, g in zip(bd, gm))
            row["ratio_median"] = round(float(np.median(ratios)), 3)
            row["ratio_max"] = round(max(ratios), 3)
            row["verdict"] = "OK (borne valide)" if row["au_dessus"] == 0 else "VIOLATION"
    rows.append(row)

cols = list(rows[0])
with open(OUT / "tableau.csv", "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=cols); w.writeheader(); w.writerows(rows)
with open(OUT / "tableau.md", "w") as f:
    f.write(f"# Pipeline {STAMP}\n\nContrats : {', '.join(names)}  \nMesures : `{MOKA}`  \n"
            f"Constantes : `{CONSTS}`  \nReference : `{REF}`\n\n")
    f.write("| " + " | ".join(cols) + " |\n|" + "---|" * len(cols) + "\n")
    for r in rows:
        f.write("| " + " | ".join(str(r[c]).replace("|", "\\|") for c in cols) + " |\n")

# ---- e. resume ---------------------------------------------------------------------------------
tot = sum(r["points"] for r in rows if r["au_dessus"] != "-")
above = sum(r["au_dessus"] for r in rows if r["au_dessus"] != "-")
log(f"tableau : {OUT / 'tableau.csv'}  et  {OUT / 'tableau.md'}")
log(f"operations : {len(rows)} ; points au-dessus de la borne : {above}/{tot} ; "
    f"non bornees : {[r['contrat'] + '.' + r['operation'] for r in rows if r['verdict'].startswith('NON')]}")
diff = [f"{r['contrat']}.{r['operation']}" for r in rows if r["egal_reference"] == "NON"]
log("ecarts de borne vs reference :", diff or "aucun")
