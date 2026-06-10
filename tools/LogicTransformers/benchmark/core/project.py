from __future__ import annotations

from pathlib import Path


BENCH_DIR = Path(__file__).resolve().parents[1]
LOGIC_DIR = BENCH_DIR.parent
PIPELINE_ROOT = BENCH_DIR.parents[2]
NORMALIZED_DIR = PIPELINE_ROOT / "build" / "normalized"
XSYNTAX_SOURCE_DIR = PIPELINE_ROOT / "data" / "source"
RESULTS_DIR = BENCH_DIR / "results"
PLOTS_DIR = RESULTS_DIR / "plots"
RAW_DIR = RESULTS_DIR / "raw"
WORK_DIR = BENCH_DIR / "work"
TNF_PRO = LOGIC_DIR / "tnf.pro"
TNF_PY = LOGIC_DIR / "tnf.py"
TNF_JAVA_DIR = LOGIC_DIR / "java"
CASLOG_RESULTS = PIPELINE_ROOT / "results" / "caslog_important_results.txt"
PLCAFE_JAR = PIPELINE_ROOT / "tools" / "prolog_cafe" / "plcafe.jar"
PROLOG_CAFE_WORK = WORK_DIR / "prolog_cafe"
TNF_WORK = WORK_DIR / "tnf"
CIAO_WORK = WORK_DIR / "ciao"


def ensure_layout() -> None:
    for path in (RESULTS_DIR, PLOTS_DIR, RAW_DIR, WORK_DIR, PROLOG_CAFE_WORK, TNF_WORK, CIAO_WORK):
        path.mkdir(parents=True, exist_ok=True)

