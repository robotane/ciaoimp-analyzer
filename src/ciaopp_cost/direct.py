"""Gas bounds of the contracts of data/contracts_hotmoka, analysed directly by CiaoPP.

These contracts are written in ciaomoka style (fsyntax, statevars) so that CiaoPP
can analyse the source itself: no expansion or normalization stage of the
pipeline is involved. Each contract loads the package hotmoka_gas.pl (gas of the
Hotmoka primitives of hotmoka.pl) and declares its own entries.

Usage (from the ciaoimp-analyzer root, Ciao on the PATH):
    python3 -m src.ciaopp_cost.direct [contract ...]
Writes build/ciaopp_direct/ and results/ciaopp_direct_results.txt.
"""
from __future__ import annotations

import re
import shutil
import sys
from pathlib import Path

from src.ciaopp_cost import (CostResult, analyze, errors_of, extract_bounds,
                             format_results)

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "data" / "contracts_hotmoka"
OUT = ROOT / "build" / "ciaopp_direct"
RESULTS = ROOT / "results" / "ciaopp_direct_results.txt"
LIBRARY = {"hotmoka.pl", "hotmoka_gas.pl", "hotmoka_tr.pl"}
ENTRY_RE = re.compile(r"^:-\s*entry\s+([a-z]\w*)\(", re.M)


def run(names: list[str], ciaosh: str = "ciaosh", src: Path = SRC, out: Path = OUT,
        gas_package: Path | None = None) -> list[CostResult]:
    """Analyse the contracts ``names`` of ``src`` in ``out``; ``gas_package`` replaces
    hotmoka_gas.pl (another set of constants)."""
    out.mkdir(parents=True, exist_ok=True)
    for lib in LIBRARY:
        shutil.copy(src / lib, out / lib)
    if gas_package is not None:
        shutil.copy(gas_package, out / "hotmoka_gas.pl")
    results = []
    for name in names:
        module = out / f"{name}.pl"
        shutil.copy(src / f"{name}.pl", module)
        entries = sorted(set(ENTRY_RE.findall(module.read_text(encoding="utf-8"))))
        co, seconds, log, peak_mb = analyze(ciaosh, module)
        res = CostResult(name, ok=co.exists(), seconds=seconds, peak_mb=peak_mb,
                         errors=errors_of(log))
        if res.ok:
            res.bounds = extract_bounds(co, entries)
        print(f"  {name}: {'OK' if res.ok and not res.errors else 'PROBLEM'} "
              f"({len(res.bounds)} bound(s))", flush=True)
        results.append(res)
    return results


def main(argv: list[str]) -> int:
    names = argv or sorted(p.stem for p in SRC.glob("*.pl") if p.name not in LIBRARY)
    results = run(names)
    RESULTS.parent.mkdir(parents=True, exist_ok=True)
    old = RESULTS.read_text(encoding="utf-8") if argv and RESULTS.exists() else ""
    text = format_results(results, [], source="data/contracts_hotmoka (direct)")
    if old:  # partial run: keep the other contracts of the previous run
        keep = [blk for blk in re.split(r"(?m)^(?==== )", old)
                if blk.startswith("=== ") and blk.split()[1] not in names]
        head, _, body = text.partition("\n=== ")
        text = head + "\n" + "".join(keep) + ("=== " + body if body else "")
    RESULTS.write_text(text, encoding="utf-8")
    print(f"Results: {RESULTS}")
    return 0 if all(r.ok and not r.errors for r in results) else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
