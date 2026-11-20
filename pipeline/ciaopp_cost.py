#!/usr/bin/env python3
"""Gas bound of one contract of dsl/, computed by CiaoPP's resource analysis.

The contracts are written in the imperative Ciao DSL (fsyntax, statevars, loops) and load
the package dsl/hotmoka_gas.pl (gas of the Hotmoka primitives of dsl/hotmoka.pl, implicit
costs added by dsl/hotmoka_tr.pl), so CiaoPP analyses the source itself.

Steps:
  1. copy hotmoka.pl, hotmoka_gas.pl, hotmoka_tr.pl and the contract into <outdir>/work;
  2. ``ciaosh -f`` runs ``eterms, shfr, nf, det, resources`` and writes <contract>_co.pl,
     under an address-space cap (CIAOPP_COST_MAX_MB, default 3000) and a timeout;
  3. the ``cost(ub, gas, _)`` of the ``:- entry`` predicates are written to
     <outdir>/<contract>.json as {"ok", "errors", "bounds": {pred: ub}}.

Usage: ciaopp_cost.py <contract> <outdir>      (ciaosh on the PATH)
"""
from __future__ import annotations

import json
import os
import re
import resource
import shutil
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DSL = ROOT / "dsl"
LIBRARY = ("hotmoka.pl", "hotmoka_gas.pl", "hotmoka_tr.pl")
ANALYSES = ("eterms", "shfr", "nf", "det", "resources")
ENTRY_RE = re.compile(r"^:-\s*entry\s+([a-z]\w*)\(", re.M)


@dataclass
class Bound:
    pred: str
    call: str          # the call part of the assertion (entry types)
    lb: str | None = None
    ub: str | None = None


@dataclass
class CostResult:
    name: str
    ok: bool
    bounds: list[Bound] = field(default_factory=list)
    errors: list[str] = field(default_factory=list)


def _max_mb() -> int:
    """Memory cap of one analysis (MB), CIAOPP_COST_MAX_MB, default 3000."""
    try:
        return int(os.environ.get("CIAOPP_COST_MAX_MB", "3000"))
    except ValueError:
        return 3000


def analyze(ciaosh: str, module: Path, timeout: int = 600) -> tuple[Path, str]:
    """Run the analyses in ciaosh; return (output file, log).

    ciaosh runs with an address-space cap and a timeout, so that an analysis that
    blows up stops alone instead of filling the RAM and the swap.
    """
    co = module.with_name(module.stem + "_co.pl")
    co.unlink(missing_ok=True)
    goals = ", ".join(f"analyze({a})" for a in ANALYSES)
    script = (
        "use_module(ciaopp(ciaopp)).\n"
        f"module('{module.name}').\n"
        f"{goals}.\n"
        f"output('{co.name}').\n"
        "halt.\n"
    )
    cap = _max_mb() * 1024 * 1024

    def limit() -> None:
        resource.setrlimit(resource.RLIMIT_AS, (cap, cap))

    log_path = module.with_suffix(".log")
    note = ""
    with log_path.open("w", encoding="utf-8") as log_f:
        proc = subprocess.Popen([ciaosh, "-f"], stdin=subprocess.PIPE, stdout=log_f,
                                stderr=subprocess.STDOUT, text=True, cwd=str(module.parent),
                                preexec_fn=limit)
        proc.stdin.write(script)
        proc.stdin.close()
        try:
            proc.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()
            note = f"\nERROR: analysis killed after {timeout} s (timeout)\n"
    log = log_path.read_text(encoding="utf-8", errors="replace") + note
    if proc.returncode and not co.exists() and not note:
        log += (f"\nERROR: ciaosh exited with code {proc.returncode} "
                f"(memory cap {_max_mb()} MB reached?)\n")
    log_path.write_text(log, encoding="utf-8")
    return co, log


def _assertions(text: str) -> list[str]:
    """Split a CiaoPP output into its ``:- true pred`` assertions."""
    out, cur = [], None
    for line in text.splitlines():
        if line.startswith(":- true pred"):
            cur = [line]
        elif cur is not None:
            cur.append(line)
        if cur is not None and line.rstrip().endswith("."):
            out.append("\n".join(cur))
            cur = None
    return out


def _cost(assertion: str, kind: str) -> str | None:
    """Return the expression of cost(kind, gas, Expr), balancing parentheses."""
    key = f"cost({kind},gas,"
    i = assertion.find(key)
    if i < 0:
        return None
    j, depth = i + len(key), 0
    for k in range(j, len(assertion)):
        c = assertion[k]
        if c == "(":
            depth += 1
        elif c == ")":
            if depth == 0:
                return " ".join(assertion[j:k].split())
            depth -= 1
    return None


def extract_bounds(co: Path, entries: list[str]) -> list[Bound]:
    """Gas bounds of the entry predicates, one row per call pattern."""
    rows: dict[tuple[str, str], Bound] = {}
    for a in _assertions(co.read_text(encoding="utf-8", errors="replace")):
        m = re.match(r":- true pred (\w+)\(", a)
        if not m or m.group(1) not in entries or "gas," not in a:
            continue
        call = re.search(r"\n\s*:\s*\((.*?)\)\s*\n\s*=>", a, re.S)
        call_s = " ".join(call.group(1).split()) if call else ""
        b = rows.setdefault((m.group(1), call_s), Bound(m.group(1), call_s))
        for kind in ("lb", "ub"):
            new = _cost(a, kind)
            old = getattr(b, kind)
            if new is not None and old is not None and new != old:
                raise ValueError(f"{co}: two {kind} gas bounds for {m.group(1)} "
                                 f"with the same call pattern: {old} / {new}")
            if new is not None:
                setattr(b, kind, new)
    return sorted(rows.values(), key=lambda b: entries.index(b.pred))


def errors_of(log: str) -> list[str]:
    return [line.strip() for line in log.splitlines() if "ERROR" in line]


def run(name: str, out: Path, src: Path = DSL, ciaosh: str = "ciaosh") -> CostResult:
    """Analyse the contract ``name`` of ``src`` in ``out``."""
    out.mkdir(parents=True, exist_ok=True)
    for lib in LIBRARY:
        shutil.copy(src / lib, out / lib)
    module = out / f"{name}.pl"
    shutil.copy(src / f"{name}.pl", module)
    entries = sorted(set(ENTRY_RE.findall(module.read_text(encoding="utf-8"))))
    co, log = analyze(ciaosh, module)
    res = CostResult(name, ok=co.exists(), errors=errors_of(log))
    if res.ok:
        res.bounds = extract_bounds(co, entries)
    return res


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(__doc__)
        return 2
    name, outdir = argv[0], Path(argv[1])
    r = run(name, outdir / "work")
    res = {"ok": r.ok, "errors": list(r.errors), "bounds": {}}
    for b in r.bounds:
        res["bounds"].setdefault(b.pred, b.ub)
    (outdir / f"{name}.json").write_text(json.dumps(res, indent=1))
    return 0 if r.ok and not r.errors else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
