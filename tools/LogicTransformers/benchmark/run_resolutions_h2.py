"""Campagne CF-1 (resolutions) et CF-4 (fidelite H2) sur le catalogue de benchmarks.

CF-1 : chaque scenario P_n du catalogue est execute sur une copie de P_n
instrumentee (un compteur incremente apres chaque unification de tete
reussie). Le compte est fait sur Prolog Cafe et sur SWI-Prolog, puis compare
a la borne CasLog evaluee aux tailles reelles des arguments d'entree.

CF-4 : chaque scenario xsyntax est execute sous Ciao. Les arguments de
l'appel sont aplatis comme le fait destate (state(V1..Vk) -> V1..Vk) ; on en
deduit l'appel P_n sur les memes entrees, execute sur Prolog Cafe et sur
SWI-Prolog, et on compare les sorties et le nombre de solutions.

Usage :
    python3 run_resolutions_h2.py [--only nom_benchmark ...] [--no-plcafe]

Sorties : results/raw/resolutions.csv, results/raw/h2_fidelity.csv,
results/raw/res_h2_details.json.
"""
from __future__ import annotations

import argparse
import csv
import json
import re
import subprocess
from pathlib import Path

from benchmarks.catalog import ALL_BENCHMARKS, BenchmarkSpec
from core.caslog import evaluate_formula, parse_important_results
from core.project import (
    CASLOG_RESULTS,
    NORMALIZED_DIR,
    PIPELINE_ROOT,
    PLCAFE_JAR,
    RAW_DIR,
    WORK_DIR,
    XSYNTAX_SOURCE_DIR,
)
from core.scenario import read_source_without_goal, read_xsyntax_source_without_goal

HERE = Path(__file__).resolve().parent
SUPPORT = HERE / "core" / "res_h2"
ANNOTATED_DIR = PIPELINE_ROOT / "build" / "annotated"
RES_WORK = WORK_DIR / "res_h2"


# --- Extraction ------------------------------------------------------------

def goal_body(scenario_text: str) -> str:
    """Corps du dernier goal/1 du fichier de scenario."""
    start = scenario_text.rfind("\ngoal(")
    clause = scenario_text[start:].strip()
    body = clause.split(":-", 1)[1].strip()
    return body[:-1].strip() if body.endswith(".") else body


def body_target_functor(body: str) -> str:
    """Nom du dernier appel du corps (appel cible)."""
    depth = 0
    last_start = 0
    for i, ch in enumerate(body):
        if ch in "([":
            depth += 1
        elif ch in ")]":
            depth -= 1
        elif ch == "," and depth == 0:
            last_start = i + 1
    m = re.match(r"\s*([a-z][A-Za-z0-9_]*)", body[last_start:])
    return m.group(1) if m else ""


def modes_measures(contract: str, predicate: str) -> tuple[list[str], list[str]]:
    text = (ANNOTATED_DIR / f"{contract}.pl").read_text(encoding="utf-8")
    pred = re.escape(predicate)
    mode = re.search(rf":- mode\({pred}, \[([^\]]*)\]\)", text)
    meas = re.search(rf":- measure\({pred}, \[([^\]]*)\]\)", text)
    if not mode or not meas:
        raise KeyError(f"mode/measure absents pour {contract}:{predicate}")
    split = lambda s: [x.strip() for x in s.split(",")]
    return split(mode.group(1)), split(meas.group(1))


# --- Moteurs ---------------------------------------------------------------

def run_swi(pl_file: Path, goal: str) -> str:
    res = subprocess.run(
        ["swipl", "-q", "-g", goal, "-t", "halt", str(pl_file)],
        capture_output=True, text=True, timeout=600,
    )
    return res.stdout


def run_plcafe(pl_file: Path, goal: str) -> str:
    root = pl_file.parent / f"plcafe_{pl_file.stem}"
    src, am, classes = root / "src", root / "am", root / "classes"
    for d in (src, am, classes):
        d.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["java", "-cp", str(PLCAFE_JAR), "com.googlecode.prolog_cafe.compiler.Compiler",
         "-s", str(src.resolve()), "-am", str(am.resolve()), pl_file.name],
        cwd=pl_file.parent, check=True, capture_output=True, text=True,
    )
    (src / "ResH2Main.java").write_text(f"""
import com.googlecode.prolog_cafe.lang.BufferingPrologControl;

public class ResH2Main {{
    public static void main(String[] args) {{
        BufferingPrologControl c = new BufferingPrologControl();
        c.setReductionLimit(Long.MAX_VALUE);
        c.configureUserIO(System.in, System.out, System.err);
        c.initialize("user");
        boolean ok = c.execute("user", "{goal}");
        System.out.flush();
        System.out.println("PLCAFE_OK:" + ok);
    }}
}}
""", encoding="utf-8")
    java_files = [str(f.resolve()) for f in src.rglob("*.java")]
    comp = subprocess.run(
        ["javac", "-nowarn", "-source", "1.8", "-target", "1.8",
         "-classpath", str(PLCAFE_JAR), "-d", str(classes.resolve())] + java_files,
        capture_output=True, text=True,
    )
    if comp.returncode != 0:
        errors = [l for l in comp.stderr.splitlines() if "error:" in l]
        raise RuntimeError("javac: " + " | ".join(errors[:3]))
    res = subprocess.run(
        ["java", "-Xss512m", "-cp", f"{classes.resolve()}:{PLCAFE_JAR}", "ResH2Main"],
        capture_output=True, text=True, timeout=600,
    )
    return res.stdout + res.stderr


def run_ciao_x(work: Path, xsyntax_base: Path, facts: Path) -> str:
    harness = work / "h2_x_harness.pl"
    harness.write_text(f""":- module(h2_x_harness, [main/0]).
:- use_package([fsyntax, statevars, hiord, loops]).
:- use_module(library(aggregates)).
:- use_module(library(lists)).
:- use_module(library(write)).
:- include('{xsyntax_base.resolve().as_posix()}').
:- include('{(SUPPORT / "h2_common.pl").as_posix()}').
:- include('{(SUPPORT / "h2_x_runner.pl").as_posix()}').
:- include('{facts.resolve().as_posix()}').
main :- h2_main.
""", encoding="utf-8")
    exe = work / "h2_x_harness"
    comp = subprocess.run(["ciaoc", "-o", str(exe), str(harness)],
                          capture_output=True, text=True)
    if comp.returncode != 0:
        return "CIAO_COMPILE_ERROR\n" + comp.stdout + comp.stderr
    res = subprocess.run([str(exe)], capture_output=True, text=True, timeout=600)
    return res.stdout + res.stderr


# --- Termes imprimes par h2_pt ---------------------------------------------

_TOKEN_RE = re.compile(r"""
    (?P<q>'(?:[^'\\]|''|\\.)*')
  | (?P<num>-?\d+(?:\.\d+(?:[eE][+-]?\d+)?)?)
  | (?P<name>[a-z][A-Za-z0-9_]*)
  | (?P<var>_)
  | (?P<sym>[+\-*/\\^<>=~:.?@#&$]+)
  | (?P<punct>\[\]|\{\}|[()\[\],|])
  | (?P<ws>\s+)
""", re.VERBOSE)


def tokenize(text: str) -> list[tuple[str, str]]:
    out, pos = [], 0
    while pos < len(text):
        m = _TOKEN_RE.match(text, pos)
        if not m:
            raise ValueError(f"token illisible a {pos}: {text[pos:pos + 30]!r}")
        pos = m.end()
        kind = m.lastgroup
        if kind != "ws":
            out.append((kind, m.group()))
    return out


def parse_term(text: str):
    toks = tokenize(text)
    pos = 0

    def term():
        nonlocal pos
        kind, val = toks[pos]
        pos += 1
        if kind == "var":
            return ("var",)
        if kind == "num":
            return ("atom", val)
        if val == "[":
            items, tail = [term()], None
            while toks[pos][1] == ",":
                pos += 1
                items.append(term())
            if toks[pos][1] == "|":
                pos += 1
                tail = term()
            pos += 1  # ']'
            return ("list", items, tail)
        if val == "[]":
            return ("list", [], None)
        if pos < len(toks) and toks[pos][1] == "(":
            pos += 1
            args = [term()]
            while toks[pos][1] == ",":
                pos += 1
                args.append(term())
            pos += 1  # ')'
            return ("cmp", val, args)
        return ("atom", val)

    t = term()
    if pos != len(toks):
        raise ValueError(f"reste non lu dans {text[:60]!r}")
    return t


def render(t) -> str:
    kind = t[0]
    if kind == "var":
        return "_"
    if kind == "atom":
        return t[1]
    if kind == "cmp":
        return f"{t[1]}({','.join(render(a) for a in t[2])})"
    items = ",".join(render(a) for a in t[1])
    if t[2] is not None:
        return f"[{items}|{render(t[2])}]"
    return f"[{items}]"


def canon_assoc(t):
    """Trie les listes d'association (elements f(Cle, ...) de meme foncteur)."""
    kind = t[0]
    if kind == "cmp":
        return ("cmp", t[1], [canon_assoc(a) for a in t[2]])
    if kind == "list":
        items = [canon_assoc(a) for a in t[1]]
        tail = canon_assoc(t[2]) if t[2] is not None else None
        heads = {(a[1], len(a[2])) for a in items if a[0] == "cmp"}
        if tail is None and items and all(a[0] == "cmp" for a in items) \
                and len(heads) == 1 and next(iter(heads))[1] >= 2:
            items = sorted(items, key=render)
        return ("list", items, tail)
    return t


# --- CF-1 ------------------------------------------------------------------

def parse_res_lines(text: str) -> dict[int, dict]:
    rows = {}
    for line in text.splitlines():
        if not line.startswith("RES|"):
            continue
        parts = line.split("|", 6)
        n = int(parts[1])
        if parts[2] == "PREFAIL":
            rows[n] = {"prefail": True}
            continue
        sizes = {}
        for k, v in re.findall(r"(\d+)-(-?\d+)", parts[6]):
            sizes[int(k)] = int(v)
        rows[n] = {
            "prefail": False, "success": int(parts[2]), "res_first": int(parts[3]),
            "nsols": int(parts[4]), "res_all": int(parts[5]), "sizes": sizes,
        }
    return rows


def run_cf1(spec: BenchmarkSpec, formula: str, use_plcafe: bool) -> list[dict]:
    work = RES_WORK / spec.name
    work.mkdir(parents=True, exist_ok=True)
    base = work / "pn_base.pl"
    base.write_text(read_source_without_goal(NORMALIZED_DIR / f"{spec.contract}.pl"), encoding="utf-8")
    inst = work / "pn_inst.pl"
    subprocess.run(["swipl", str(SUPPORT / "instrument.pl"), "--", str(base), str(inst)],
                   check=True, capture_output=True, text=True)
    modes, measures = modes_measures(spec.contract, spec.predicate)

    facts = [f"res_modes([{', '.join(modes)}]).", f"res_measures([{', '.join(measures)}])."]
    for n in spec.ns:
        body = goal_body(spec.build_source(n, spec.name).read_text(encoding="utf-8"))
        facts.append(f"res_scen({n}, ({body})).")
    facts.append("run_res :- res_main, flush_output(user_output).")
    prog = work / "res_prog.pl"
    prog.write_text(inst.read_text(encoding="utf-8") + "\n"
                    + (SUPPORT / "res_runner.pl").read_text(encoding="utf-8") + "\n"
                    + "\n".join(facts) + "\n", encoding="utf-8")

    engines = {"swi": parse_res_lines(run_swi(prog, "run_res"))}
    if use_plcafe:
        engines["plcafe"] = parse_res_lines(run_plcafe(prog, "run_res"))

    rows = []
    for n in spec.ns:
        row = {"benchmark": spec.name, "contract": spec.contract, "predicate": spec.predicate,
               "n": n, "caslog_formula": formula}
        row["caslog_value_n"] = evaluate_formula(formula, {k: n for k in spec.caslog_bindings})
        for eng, data in engines.items():
            r = data.get(n)
            if r is None or r["prefail"]:
                row[f"{eng}_status"] = "missing" if r is None else "prefail"
                continue
            row[f"{eng}_status"] = "ok" if r["success"] else "fail"
            row[f"{eng}_res_first"] = r["res_first"]
            row[f"{eng}_res_all"] = r["res_all"]
            row[f"{eng}_nsols"] = r["nsols"]
            if eng == "swi":
                row["input_sizes"] = json.dumps(r["sizes"])
                try:
                    row["caslog_value_sizes"] = evaluate_formula(formula, r["sizes"])
                except KeyError as e:
                    row["caslog_value_sizes"] = None
                    row["bound_note"] = str(e)
        b = row.get("caslog_value_sizes")
        for eng in engines:
            c = row.get(f"{eng}_res_all")
            if b is not None and c is not None:
                row[f"{eng}_within_bound"] = c <= b
        rows.append(row)
    return rows


# --- CF-4 ------------------------------------------------------------------

def run_cf4(spec: BenchmarkSpec, use_plcafe: bool) -> list[dict]:
    rows = []
    if spec.build_ciao_source is None:
        return [{"benchmark": spec.name, "n": n, "status": "no_xsyntax_scenario"} for n in spec.ns]
    work = RES_WORK / spec.name
    work.mkdir(parents=True, exist_ok=True)
    pred_name, pn_arity = spec.predicate.split("/")[0], int(spec.predicate.split("/")[1])

    xbase = work / "x_base.pl"
    xbase.write_text(read_xsyntax_source_without_goal(XSYNTAX_SOURCE_DIR / f"{spec.contract}.pl"),
                     encoding="utf-8")
    xfacts, x_targets = [], {}
    for n in spec.ns:
        body = goal_body(spec.build_ciao_source(n, spec.name).read_text(encoding="utf-8"))
        x_targets[n] = body_target_functor(body)
        xfacts.append(f"h2_xscen({n}, ({body})).")
    xf = work / "x_facts.pl"
    xf.write_text("\n".join(xfacts) + "\n", encoding="utf-8")
    xout = run_ciao_x(work, xbase, xf)
    (work / "x_out.txt").write_text(xout, encoding="utf-8")

    x_res: dict[int, dict] = {}
    for line in xout.splitlines():
        if not line.startswith("H2X|"):
            continue
        parts = line.split("|", 4)
        n = int(parts[1])
        if parts[2] == "PREFAIL":
            x_res[n] = {"prefail": True}
        else:
            x_res[n] = {"prefail": False, "nsols": int(parts[2]), "functor": parts[3],
                        "tagged": parse_term(parts[4])}

    pcalls: dict[int, tuple[str, list[int], list]] = {}
    for n in spec.ns:
        row = {"benchmark": spec.name, "contract": spec.contract, "predicate": spec.predicate, "n": n}
        rows.append(row)
        if x_targets[n] != pred_name:
            row["status"] = f"x_calls_{x_targets[n]}_not_{pred_name}"
            continue
        xr = x_res.get(n)
        if xr is None:
            row["status"] = "x_no_output" if "CIAO_COMPILE_ERROR" not in xout else "x_compile_error"
            continue
        if xr["prefail"]:
            row["status"] = "x_prefail"
            continue
        row["x_nsols"] = xr["nsols"]
        if xr["nsols"] == 0:
            row["status"] = "x_fails"
            continue
        args, out_pos, out_vals = [], [], []
        for entry in xr["tagged"][1]:
            tag, flat = entry[1], entry[2][0][1]
            for v in flat:
                if tag == "out":
                    out_pos.append(len(args))
                    out_vals.append(v)
                    args.append("_")
                else:
                    args.append(render(v))
        row["flat_arity"] = len(args)
        if len(args) != pn_arity:
            row["status"] = f"arity_mismatch_{len(args)}_vs_{pn_arity}"
            continue
        pcalls[n] = (f"{pred_name}({', '.join(args)})", out_pos, out_vals)

    if pcalls:
        pfacts = [f"h2_pscen({n}, {call})." for n, (call, _, _) in pcalls.items()]
        pfacts.append("run_h2p :- h2p_main, flush_output(user_output).")
        prog = work / "h2_pn_prog.pl"
        prog.write_text(read_source_without_goal(NORMALIZED_DIR / f"{spec.contract}.pl") + "\n"
                        + (SUPPORT / "h2_common.pl").read_text(encoding="utf-8") + "\n"
                        + (SUPPORT / "h2_p_runner.pl").read_text(encoding="utf-8") + "\n"
                        + "\n".join(pfacts) + "\n", encoding="utf-8")
        engines = {"swi": run_swi(prog, "run_h2p")}
        if use_plcafe:
            engines["plcafe"] = run_plcafe(prog, "run_h2p")
        for eng, out in engines.items():
            (work / f"h2_pn_out_{eng}.txt").write_text(out, encoding="utf-8")
            p_res = {}
            for line in out.splitlines():
                if line.startswith("H2P|"):
                    parts = line.split("|", 3)
                    p_res[int(parts[1])] = (int(parts[2]), parse_term(parts[3]))
            for row in rows:
                n = row["n"]
                if n not in pcalls:
                    continue
                _, out_pos, out_vals = pcalls[n]
                if n not in p_res:
                    row[f"{eng}_verdict"] = "no_output"
                    continue
                nsols, pargs = p_res[n]
                row[f"{eng}_nsols"] = nsols
                if nsols == 0:
                    row[f"{eng}_verdict"] = "pn_fails"
                    continue
                pvals = [pargs[1][i] for i in out_pos]
                exact = all(render(a) == render(b) for a, b in zip(pvals, out_vals))
                assoc = all(render(canon_assoc(a)) == render(canon_assoc(b))
                            for a, b in zip(pvals, out_vals))
                verdict = "equal" if exact else ("equal_up_to_assoc_order" if assoc else "different")
                if nsols != row["x_nsols"]:
                    verdict += "_nsols_differ"
                row[f"{eng}_verdict"] = verdict
                if not exact:
                    row[f"{eng}_diff"] = [
                        {"pos": i + 1, "xsyntax": render(b), "pn": render(a)}
                        for i, a, b in zip(out_pos, pvals, out_vals) if render(a) != render(b)
                    ][:4]
            for row in rows:
                if row["n"] in pcalls:
                    row["status"] = "compared"
    return rows


# --- Main ------------------------------------------------------------------

def write_csv(path: Path, rows: list[dict]) -> None:
    keys: list[str] = []
    for r in rows:
        for k in r:
            if k not in keys:
                keys.append(k)
    with path.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=keys)
        w.writeheader()
        for r in rows:
            w.writerow({k: (json.dumps(v) if isinstance(v, (list, dict)) else v) for k, v in r.items()})


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", nargs="*")
    ap.add_argument("--no-plcafe", action="store_true")
    ap.add_argument("--skip-cf1", action="store_true")
    ap.add_argument("--skip-cf4", action="store_true")
    args = ap.parse_args()

    formulas = parse_important_results(CASLOG_RESULTS)
    specs = [s for s in ALL_BENCHMARKS if not args.only or s.name in args.only]
    res_rows, h2_rows = [], []
    for spec in specs:
        print(f">>> {spec.name}", flush=True)
        formula = formulas[spec.contract][spec.predicate]
        if not args.skip_cf1:
            try:
                res_rows += run_cf1(spec, formula, not args.no_plcafe)
            except Exception as e:  # noqa: BLE001
                print(f"  [CF-1 ERREUR] {e}")
                res_rows.append({"benchmark": spec.name, "error": str(e)})
        if not args.skip_cf4:
            try:
                h2_rows += run_cf4(spec, not args.no_plcafe)
            except Exception as e:  # noqa: BLE001
                print(f"  [CF-4 ERREUR] {e}")
                h2_rows.append({"benchmark": spec.name, "error": str(e)})

    RAW_DIR.mkdir(parents=True, exist_ok=True)
    suffix = "" if not args.only else "_partial"
    if res_rows:
        write_csv(RAW_DIR / f"resolutions{suffix}.csv", res_rows)
    if h2_rows:
        write_csv(RAW_DIR / f"h2_fidelity{suffix}.csv", h2_rows)
    (RAW_DIR / f"res_h2_details{suffix}.json").write_text(
        json.dumps({"resolutions": res_rows, "h2": h2_rows}, indent=1, default=str), encoding="utf-8")


if __name__ == "__main__":
    main()
