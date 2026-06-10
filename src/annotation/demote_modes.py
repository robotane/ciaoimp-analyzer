"""Iterative CasLog-driven mode demotion.

Usage:
    python -m src.annotation.demote_modes                  # fixpoint, all annotated files
    python -m src.annotation.demote_modes path/to/file.pl  # fixpoint, single file
    python -m src.annotation.demote_modes --once           # single pass, all files
"""
from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

_HERE = Path(__file__).resolve()
_PIPELINE_ROOT = _HERE.parents[2]
_STAGE_ROOT = _HERE.parents[5]      # stage/

ANN_DIR = _PIPELINE_ROOT / "build" / "annotated"
CASLOG = Path(os.environ.get(
    "CASLOG",
    str(_STAGE_ROOT / "tools" / "caslog" / "caslog.gprolog"),
))

INFIX_OPS = {"=:=", "=\\=", "\\==", "==", ">=", "=<", "is", ">", "<", "="}


def run_caslog(pl_file: Path) -> str:
    res = subprocess.run(
        [str(CASLOG), str(pl_file.resolve())],
        cwd=str(CASLOG.parent),
        capture_output=True,
        text=True,
        timeout=120,
    )
    return res.stdout + res.stderr


ERR_RE = re.compile(r"^\*\s*Caslog error:\s*unbound input variable:\s*(\S+)\s*$")
PRED_HDR_RE = re.compile(r"for predicate\s+([A-Za-z_][A-Za-z0-9_]*)/(\d+)")


def parse_errors(output: str) -> list[tuple[str, int, str, str]]:
    """Return list of (pred_name, arity, unbound_var, clause_text)."""
    errors = []
    pred_name, arity = None, None
    lines = output.splitlines()
    i = 0
    while i < len(lines):
        line = lines[i]
        m = PRED_HDR_RE.search(line)
        if m:
            pred_name = m.group(1)
            arity = int(m.group(2))
        m = ERR_RE.match(line.rstrip())
        if m and pred_name is not None:
            var = m.group(1)
            clause = lines[i + 1].strip() if i + 1 < len(lines) else ""
            errors.append((pred_name, arity, var, clause))
        i += 1
    return errors


def split_top(s: str, sep: str) -> list[str]:
    out, depth, buf = [], 0, []
    i, n = 0, len(s)
    while i < n:
        c = s[i]
        if c in "([":
            depth += 1
            buf.append(c)
        elif c in ")]":
            depth -= 1
            buf.append(c)
        elif depth == 0 and s.startswith(sep, i):
            out.append("".join(buf).strip())
            buf = []
            i += len(sep)
            continue
        else:
            buf.append(c)
        i += 1
    tail = "".join(buf).strip()
    if tail:
        out.append(tail)
    return out


def split_head_body(clause: str) -> tuple[str, str, str]:
    depth = 0
    for i, c in enumerate(clause):
        if c in "([":
            depth += 1
        elif c in ")]":
            depth -= 1
        elif depth == 0 and clause.startswith(":-", i):
            head = clause[:i].strip()
            body = clause[i + 2:].strip()
            return head, body, ""
    return clause.strip(), "", ""


def parse_head(head: str) -> tuple[str, list[str]]:
    m = re.match(r"^([a-z_][A-Za-z0-9_]*)\s*\((.*)\)\s*$", head, re.DOTALL)
    if not m:
        return head.strip(), []
    return m.group(1), split_top(m.group(2), ",")


def parse_body_calls(body: str) -> list[tuple[str, list[str]]]:
    calls = []
    for g in split_top(body, ","):
        g = g.strip()
        if not g or g == "!":
            continue
        m = re.match(r"^([a-z_][A-Za-z0-9_]*)\s*\((.*)\)\s*$", g, re.DOTALL)
        if not m:
            continue
        calls.append((m.group(1), split_top(m.group(2), ",")))
    return calls


def var_positions_at_depth0(args: list[str], var: str) -> list[int]:
    return [i for i, a in enumerate(args) if a.strip() == var]


MODE_LINE_RE = re.compile(
    r"^(:-\s*mode\(\s*([A-Za-z_][A-Za-z0-9_]*)\s*/\s*(\d+)\s*,\s*\[)([^\]]*)(\]\s*\)\s*\.)",
    re.MULTILINE,
)


def read_modes(text: str) -> dict[tuple[str, int], list[str]]:
    modes = {}
    for m in MODE_LINE_RE.finditer(text):
        name = m.group(2)
        arity = int(m.group(3))
        toks = [t.strip() for t in m.group(4).split(",")]
        modes[(name, arity)] = toks
    return modes


def write_modes(text: str, modes: dict[tuple[str, int], list[str]]) -> str:
    def repl(m: re.Match) -> str:
        prefix, name, arity_s, _body, suffix = (
            m.group(1), m.group(2), m.group(3), m.group(4), m.group(5),
        )
        key = (name, int(arity_s))
        if key not in modes:
            return m.group(0)
        return f"{prefix}{', '.join(modes[key])}{suffix}"
    return MODE_LINE_RE.sub(repl, text)


def demote_once(pl_file: Path) -> tuple[int, int, int]:
    """Run CasLog, parse errors, apply demotions.
    Returns (n_errors_before, n_demotions_applied, n_errors_after).
    """
    text = pl_file.read_text()
    modes = read_modes(text)
    output = run_caslog(pl_file)
    errs = parse_errors(output)
    n_before = len(errs)
    bounded_before = output.count("Time functions for predicate")
    demotions: set[tuple[str, int, int]] = set()

    for pred_name, arity, var, clause in errs:
        head, body, _ = split_head_body(clause)
        hname, hargs = parse_head(head)

        if body:
            for cname, cargs in parse_body_calls(body):
                key = (cname, len(cargs))
                cmodes = modes.get(key)
                if cmodes is None:
                    continue
                for i in var_positions_at_depth0(cargs, var):
                    if i < len(cmodes) and cmodes[i] == "+":
                        demotions.add((cname, len(cargs), i))

        if hname:
            hkey = (hname, len(hargs))
            hmodes = modes.get(hkey)
            if hmodes is not None:
                for i in var_positions_at_depth0(hargs, var):
                    if i < len(hmodes) and hmodes[i] == "+":
                        demotions.add((hname, len(hargs), i))

    if not demotions:
        return n_before, 0, n_before

    modes_batch = {k: list(v) for k, v in modes.items()}
    for (name, arity, i) in demotions:
        m = modes_batch[(name, arity)]
        if i < len(m) and m[i] == "+":
            m[i] = "-"
    pl_file.write_text(write_modes(text, modes_batch))
    out_b = run_caslog(pl_file)
    errs_b = parse_errors(out_b)
    bnd_b = out_b.count("Time functions for predicate")
    all_aux = all(n.startswith(("aux_", "loop_aux_")) for n, _, _ in demotions)
    if all_aux or bnd_b >= bounded_before:
        return n_before, len(demotions), len(errs_b)

    pl_file.write_text(text)
    current_text = text
    current_bnd = bounded_before
    current_errs = n_before
    kept = 0
    for (name, arity, i) in sorted(demotions):
        trial_modes = read_modes(current_text)
        key = (name, arity)
        if key not in trial_modes:
            continue
        m = trial_modes[key]
        if not (i < len(m) and m[i] == "+"):
            continue
        m[i] = "-"
        trial_text = write_modes(current_text, trial_modes)
        pl_file.write_text(trial_text)
        out_t = run_caslog(pl_file)
        bnd_t = out_t.count("Time functions for predicate")
        errs_t = len(parse_errors(out_t))
        is_aux = name.startswith(("aux_", "loop_aux_"))
        if is_aux or bnd_t >= current_bnd:
            current_text = trial_text
            current_bnd = bnd_t
            current_errs = errs_t
            kept += 1
        else:
            pl_file.write_text(current_text)
    return n_before, kept, current_errs


def demote_fixpoint(pl_file: Path, max_iters: int = 10) -> dict:
    start = run_caslog(pl_file)
    errs0 = parse_errors(start)
    bounded0 = start.count("Time functions for predicate")
    hist = []
    for it in range(max_iters):
        n_before, n_dem, n_after = demote_once(pl_file)
        hist.append((it, n_before, n_dem, n_after))
        if n_dem == 0:
            break

    end = run_caslog(pl_file)
    bounded1 = end.count("Time functions for predicate")
    return {
        "file": pl_file.name,
        "bounded_before": bounded0,
        "errors_before": len(errs0),
        "bounded_after": bounded1,
        "errors_after": len(parse_errors(end)),
        "iterations": hist,
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--once", action="store_true")
    ap.add_argument("file_pos", nargs="?", metavar="FILE")
    args = ap.parse_args()

    files = [Path(args.file_pos)] if args.file_pos else sorted(ANN_DIR.glob("*.pl"))
    total_bound_before = total_bound_after = 0
    total_err_before = total_err_after = 0
    for pl in files:
        if args.once:
            n_before, n_dem, n_after = demote_once(pl)
            print(f"{pl.name:30s}  errs {n_before} -> {n_after} (demoted {n_dem})")
        else:
            r = demote_fixpoint(pl)
            print(
                f"{r['file']:30s}  bounded {r['bounded_before']}->{r['bounded_after']}  "
                f"errs {r['errors_before']}->{r['errors_after']}  "
                f"iters={len(r['iterations'])}"
            )
            total_bound_before += r["bounded_before"]
            total_bound_after += r["bounded_after"]
            total_err_before += r["errors_before"]
            total_err_after += r["errors_after"]
    if not args.once:
        print(
            f"\nTOTAL  bounded {total_bound_before}->{total_bound_after}  "
            f"errors {total_err_before}->{total_err_after}"
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
