"""Gas bounds of the contracts with CiaoPP's resource analysis (ciaopp_cost).

For each contract ``C`` that has a spec ``data/ciaopp_cost/specs/C.pl``:

1. ``assemble``: ``build/ciaopp_cost/C.pl`` = spec (module, entries, regtypes)
   + the cost-model prelude named in the spec + the clauses of
   ``build/executable/C.pl``, unchanged.
2. ``analyze``: ciaosh runs ``eterms, shfr, nf, det, resources`` and writes
   ``build/ciaopp_cost/C_co.pl`` (log in ``C.log``).
3. ``extract_bounds``: the ``cost(lb|ub, gas, _)`` of the entry predicates.

A spec names its prelude with a line ``%! prelude: NAME``, which includes
``data/ciaopp_cost/preludes/NAME.pl``.
"""
from __future__ import annotations

import re
import subprocess
import time
from dataclasses import dataclass, field
from pathlib import Path

ANALYSES = ("eterms", "shfr", "nf", "det", "resources")
PRELUDE_RE = re.compile(r"^%!\s*prelude:\s*(\w+)\s*$", re.M)
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
    seconds: float = 0.0
    bounds: list[Bound] = field(default_factory=list)
    errors: list[str] = field(default_factory=list)


def assemble(spec: Path, executable: Path, prelude_dir: Path, out: Path) -> list[str]:
    """Write the analyzable module; return its entry predicate names."""
    spec_text = spec.read_text(encoding="utf-8")
    parts = [f"% Generated from {spec.name} and build/executable/{executable.name}.\n",
             spec_text]
    for name in PRELUDE_RE.findall(spec_text):
        prelude = prelude_dir / f"{name}.pl"
        parts.append(f"\n% --- prelude {name} ---\n")
        parts.append(prelude.read_text(encoding="utf-8"))
    parts.append(f"\n% --- clauses of build/executable/{executable.name} (unchanged) ---\n\n")
    parts.append(executable.read_text(encoding="utf-8"))
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("".join(parts), encoding="utf-8")
    return sorted(set(ENTRY_RE.findall(spec_text)))


def analyze(ciaosh: str, module: Path, timeout: int = 600) -> tuple[Path, float, str]:
    """Run the analyses in ciaosh; return (output file, seconds, log)."""
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
    start = time.monotonic()
    res = subprocess.run([ciaosh, "-f"], input=script, cwd=str(module.parent),
                         capture_output=True, text=True, timeout=timeout, check=False)
    seconds = time.monotonic() - start
    log = res.stdout + res.stderr
    module.with_suffix(".log").write_text(log, encoding="utf-8")
    return co, seconds, log


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
        b.lb = _cost(a, "lb") or b.lb
        b.ub = _cost(a, "ub") or b.ub
    return sorted(rows.values(), key=lambda b: entries.index(b.pred))


def errors_of(log: str) -> list[str]:
    return [l.strip() for l in log.splitlines() if "ERROR" in l]


def run_one(name: str, spec: Path, executable: Path, prelude_dir: Path,
            out_dir: Path, ciaosh: str) -> CostResult:
    module = out_dir / f"{name}.pl"
    entries = assemble(spec, executable, prelude_dir, module)
    co, seconds, log = analyze(ciaosh, module)
    res = CostResult(name, ok=co.exists(), seconds=seconds, errors=errors_of(log))
    if res.ok:
        res.bounds = extract_bounds(co, entries)
    return res


def format_results(results: list[CostResult], missing: list[str]) -> str:
    lines = ["CiaoPP resource analysis (ciaopp_cost): gas bounds of the entries",
             f"Analyses: {', '.join(ANALYSES)}", ""]
    for r in results:
        status = "OK" if r.ok else "FAILED"
        lines.append(f"=== {r.name} ({status}, {r.seconds:.1f} s) ===")
        for b in r.bounds:
            lines.append(f"  {b.pred:<22} lb = {b.lb or '?'}")
            lines.append(f"  {'':<22} ub = {b.ub or '?'}")
            if b.call:
                lines.append(f"  {'':<22} call: {b.call}")
        for e in r.errors:
            lines.append(f"  {e}")
        lines.append("")
    if missing:
        lines.append("No spec yet (data/ciaopp_cost/specs/): " + ", ".join(missing))
    return "\n".join(lines) + "\n"
