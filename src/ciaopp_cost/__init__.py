"""Gas bounds of the contracts with CiaoPP's resource analysis (ciaopp_cost).

For each contract ``C`` that has a spec ``data/ciaopp_cost/specs/C.pl``:

1. ``assemble``: ``build/ciaopp_cost/C.pl`` = spec (module declaration
   loading the package ``gas_model``, entries, regtypes) + the clauses of
   ``build/executable/C.pl`` minus the blockchain primitives (and the
   generated loops only they use). The primitives live once in
   ``data/ciaopp_cost/blockchain.pl``; their gas costs, the resource and the
   table types live once in the package ``data/ciaopp_cost/gas_model.pl``.
   Both are copied next to ``C.pl``. Same layout as
   ``ciaopp_cost/examples/resources_blockchain`` (carthage.pl).
2. ``analyze``: ciaosh runs ``eterms, shfr, nf, det, resources`` and writes
   ``build/ciaopp_cost/C_co.pl`` (log in ``C.log``).
3. ``extract_bounds``: the ``cost(lb|ub, gas, _)`` of the entry predicates.

The cost model is changed in ``gas_model.pl`` only.
"""
from __future__ import annotations

import os
import re
import resource
import subprocess
import time
from dataclasses import dataclass, field
from pathlib import Path

ANALYSES = ("eterms", "shfr", "nf", "det", "resources")
EXPORTS_RE = re.compile(r"^:-\s*module\(\s*\w+\s*,\s*\[(.*?)\]", re.M | re.S)
AUX_RE = re.compile(r"\b((?:loop_aux|aux_cond|aux_disj)_\d+)\(")
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
    peak_mb: int = 0
    bounds: list[Bound] = field(default_factory=list)
    errors: list[str] = field(default_factory=list)


def _clauses(text: str) -> list[str]:
    """Split pretty-printed Prolog (one clause ends with a line ending in '.')."""
    out, cur = [], []
    for line in text.splitlines():
        if not line.strip() and not cur:
            continue
        cur.append(line)
        if line.rstrip().endswith("."):
            out.append("\n".join(cur))
            cur = []
    if cur:
        out.append("\n".join(cur))
    return out


def _name(clause: str) -> str:
    m = re.match(r"([a-z]\w*)", clause.lstrip())
    return m.group(1) if m else ""


def strip_primitives(text: str, primitives: set[str]) -> tuple[str, list[str]]:
    """Remove the primitives and the generated helpers used only by them."""
    clauses = _clauses(text)
    calls: dict[str, set[str]] = {}
    for c in clauses:
        calls.setdefault(_name(c), set()).update(AUX_RE.findall(c))

    def reach(roots: set[str]) -> set[str]:
        seen, todo = set(), list(roots)
        while todo:
            p = todo.pop()
            for q in calls.get(p, ()):
                if q not in seen:
                    seen.add(q)
                    todo.append(q)
        return seen

    defined = set(calls)
    from_prims = reach(primitives & defined)
    kept_roots = defined - primitives - from_prims
    still_used = reach(kept_roots)
    removed = (primitives & defined) | (from_prims - still_used)
    kept = [c for c in clauses if _name(c) not in removed]
    return "\n".join(kept) + "\n", sorted(removed)


def primitives_of(blockchain: Path) -> set[str]:
    """Names exported by blockchain.pl."""
    m = EXPORTS_RE.search(blockchain.read_text(encoding="utf-8"))
    return {x.strip().split("/")[0] for x in m.group(1).split(",")} if m else set()


def assemble(spec: Path, executable: Path, model_dir: Path, out: Path) -> list[str]:
    """Write the analyzable module; return its entry predicate names."""
    spec_text = spec.read_text(encoding="utf-8")
    if "gas_model" not in spec_text:
        raise ValueError(f"{spec}: the module declaration must load .(gas_model)")
    blockchain = model_dir / "blockchain.pl"
    body, removed = strip_primitives(executable.read_text(encoding="utf-8"),
                                     primitives_of(blockchain))
    parts = [
        f"% Generated from {spec.parent.name}/{spec.name} and {executable.parent.parent.name}/{executable.parent.name}/{executable.name}.\n",
        spec_text,
        f"\n% --- clauses of {executable.parent.parent.name}/{executable.parent.name}/{executable.name}, without the primitives\n"
        f"% imported from blockchain.pl: {', '.join(removed) or 'none'} ---\n\n",
        body,
    ]
    out.parent.mkdir(parents=True, exist_ok=True)
    for f in ("gas_model.pl", "blockchain.pl"):
        (out.parent / f).write_text((model_dir / f).read_text(encoding="utf-8"), encoding="utf-8")
    out.write_text("".join(parts), encoding="utf-8")
    return sorted(set(ENTRY_RE.findall(spec_text)))


def _max_mb() -> int:
    """Memory cap of one analysis (MB), CIAOPP_COST_MAX_MB, default 3000."""
    try:
        return int(os.environ.get("CIAOPP_COST_MAX_MB", "3000"))
    except ValueError:
        return 3000


def analyze(ciaosh: str, module: Path, timeout: int = 600) -> tuple[Path, float, str, int]:
    """Run the analyses in ciaosh; return (output file, seconds, log, peak MB).

    ciaosh runs with an address-space cap (CIAOPP_COST_MAX_MB) and a timeout,
    so that an analysis that blows up stops alone instead of filling the RAM
    and the swap (systemd-oomd then kills the whole terminal).
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
    start = time.monotonic()
    peak_kb, note = 0, ""
    with log_path.open("w", encoding="utf-8") as log_f:
        proc = subprocess.Popen([ciaosh, "-f"], stdin=subprocess.PIPE, stdout=log_f,
                                stderr=subprocess.STDOUT, text=True, cwd=str(module.parent),
                                preexec_fn=limit)
        proc.stdin.write(script)
        proc.stdin.close()
        while True:
            pid, status, usage = os.wait4(proc.pid, os.WNOHANG)
            if pid:
                proc.returncode = os.waitstatus_to_exitcode(status)
                peak_kb = usage.ru_maxrss
                break
            if time.monotonic() - start > timeout:
                proc.kill()
                _, status, usage = os.wait4(proc.pid, 0)
                proc.returncode = os.waitstatus_to_exitcode(status)
                peak_kb = usage.ru_maxrss
                note = f"\nERROR: analysis killed after {timeout} s (timeout)\n"
                break
            time.sleep(0.2)
    seconds = time.monotonic() - start
    log = log_path.read_text(encoding="utf-8", errors="replace") + note
    if proc.returncode and not co.exists() and not note:
        note = (f"\nERROR: ciaosh exited with code {proc.returncode} "
                f"(memory cap {_max_mb()} MB reached?)\n")
        log += note
    log_path.write_text(log, encoding="utf-8")
    return co, seconds, log, peak_kb // 1024


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


def run_one(name: str, spec: Path, executable: Path, model_dir: Path,
            out_dir: Path, ciaosh: str) -> CostResult:
    module = out_dir / f"{name}.pl"
    entries = assemble(spec, executable, model_dir, module)
    co, seconds, log, peak_mb = analyze(ciaosh, module)
    res = CostResult(name, ok=co.exists(), seconds=seconds, peak_mb=peak_mb,
                     errors=errors_of(log))
    if res.ok:
        res.bounds = extract_bounds(co, entries)
    return res


def format_results(results: list[CostResult], missing: list[str],
                   source: str = "build/executable") -> str:
    lines = [f"CiaoPP resource analysis (ciaopp_cost): gas bounds of the entries, input {source}",
             f"Analyses: {', '.join(ANALYSES)}", ""]
    for r in results:
        status = "OK" if r.ok else "FAILED"
        lines.append(f"=== {r.name} ({status}, {r.seconds:.1f} s, {r.peak_mb} MB) ===")
        for b in r.bounds:
            lines.append(f"  {b.pred:<22} lb = {b.lb or '?'}")
            lines.append(f"  {'':<22} ub = {b.ub or '?'}")
            if b.call:
                lines.append(f"  {'':<22} call: {b.call}")
        for e in r.errors:
            lines.append(f"  {e}")
        lines.append("")
    if missing:
        lines.append("No spec yet: " + ", ".join(missing))
    return "\n".join(lines) + "\n"
