from __future__ import annotations

import numpy as np
import pandas as pd
from scipy.optimize import curve_fit
from pathlib import Path

RAW_DIR = Path(__file__).parent / "results" / "raw"


def model_const(x, a):
    return np.full_like(x, a, dtype=float)


def model_linear(x, a, b):
    return a * x + b


def model_quadratic(x, a, b, c):
    return a * x ** 2 + b * x + c


MODELS = {
    "O(1)":   (model_const,     1),
    "O(N)":   (model_linear,    2),
    "O(N^2)": (model_quadratic, 3),
}


COMPLEXITY_TO_MODEL = {
    "O(1)":   "O(1)",
    "O(N)":   "O(N)",
    "O(N^2)": "O(N^2)",
    "O(N²)":  "O(N^2)",
    "O(NM)":  "O(N^2)",
}


def _drop_first_call_outliers(x: np.ndarray, y: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Retire les points "pic puis chute" (artefact JIT C2 / class loading
    sur le tout premier scenario Prolog Cafe, qui n'est pas absorbe par le
    warmup pour des predicats triviaux). Heuristique : si y[i] >= 5 * y[i+1],
    le point i est rejete.
    """
    keep = np.ones_like(y, dtype=bool)
    for i in range(len(y) - 1):
        if y[i + 1] > 0 and y[i] >= 5.0 * y[i + 1]:
            keep[i] = False
    return x[keep], y[keep]


def r2_for_model(x: np.ndarray, y: np.ndarray, model_name: str) -> float | None:
    entry = MODELS.get(model_name)
    if entry is None:
        return None
    fn, nparams = entry
    # On filtre les outliers "first-call" avant de fitter.
    x, y = _drop_first_call_outliers(x, y)
    if len(x) <= nparams:
        return None
    try:
        popt, _ = curve_fit(fn, x, y, maxfev=10000)
        y_pred = fn(x, *popt)
        ss_res = np.sum((y - y_pred) ** 2)
        ss_tot = np.sum((y - np.mean(y)) ** 2)
        return round(1.0 - ss_res / ss_tot if ss_tot > 0 else 1.0, 4)
    except Exception:
        return None


def main() -> int:
    csv_path = RAW_DIR / "all_benchmarks.csv"
    if not csv_path.exists():
        print(f"Fichier introuvable : {csv_path}")
        return 1

    df = pd.read_csv(csv_path)
    results = []

    for (contract, predicate), group in df.groupby(["contract", "predicate"]):
        group = group.sort_values("n")
        x = group["n"].values.astype(float)
        complexity_label = group["complexity_label"].iloc[0]
        expected_model = COMPLEXITY_TO_MODEL.get(complexity_label, "O(N)")

        for backend, col in [("LogicTransformers", "vm_ms"), ("PrologCafe", "pc_ms"), ("Ciao", "ciao_ms")]:
            if col not in df.columns:
                continue
            y = group[col].values.astype(float)
            if np.all(y == 0):
                continue
            r2 = r2_for_model(x, y, expected_model)
            results.append({
                "contract":        contract,
                "predicate":       predicate,
                "backend":         backend,
                "caslog_model":    complexity_label,
                "fitted_model":    expected_model,
                "r2":              r2,
            })
            print(f"  {contract}/{predicate} [{backend}] CasLog={complexity_label} → R²={r2}")

    out_path = RAW_DIR / "fitting_results.csv"
    pd.DataFrame(results).to_csv(out_path, index=False)
    print(f"\nRésultats enregistrés dans {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
