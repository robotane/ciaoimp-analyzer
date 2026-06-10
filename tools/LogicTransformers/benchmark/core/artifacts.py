from __future__ import annotations

from pathlib import Path

from core.project import WORK_DIR


def scenario_dir(bench_name: str, n: int) -> Path:
    return WORK_DIR / bench_name / f"n_{n}"


def scenario_files(bench_name: str, n: int) -> tuple[Path, Path]:
    root = scenario_dir(bench_name, n)
    root.mkdir(parents=True, exist_ok=True)
    return root / "scenario.pro", root / "scenario_asm.txt"


def xsyntax_scenario_file(bench_name: str, n: int) -> Path:
    """Scenario xsyntax (data/source) avec goal parametre sur N.
    Utilise par Ciao pour mesurer la version imperative native.
    """
    root = scenario_dir(bench_name, n)
    root.mkdir(parents=True, exist_ok=True)
    return root / "scenario_xsyntax.pl"
