"""Measured gas and bound evaluation, used by run_pipeline.py.

- load(files): measured gas of the CSV files written by bench/mesurer.sh
  (columns contract, operation, size_var, n, run, gas_cpu, gas_ram, gas_storage, gas_total, time_us);
- choose(x, y): simplest growth model (const, log, lin, quad) the data support;
- evaluate(expr, lengths, n): value of a CiaoPP gas bound at size n.
"""
import collections
import csv
import math
import re

import numpy as np

FORMS = ["const", "log", "lin", "quad"]


def load(files):
    """{(contract, operation, size_var): {n: {"gas": [...], "time": [...]}}} of the CSV files."""
    rows = []
    for f in files:
        with open(f, newline="") as fh:
            rows += list(csv.DictReader(fh))
    data = collections.defaultdict(lambda: collections.defaultdict(lambda: {"gas": [], "time": []}))
    for r in rows:
        d = data[(r["contract"], r["operation"], r["size_var"])][int(r["n"])]
        d["gas"].append(float(r["gas_total"]))
        d["time"].append(float(r["time_us"]) / 1000.0)  # ms
    return data


def design(form, x):
    one = np.ones_like(x)
    if form == "const":
        return one[:, None]
    if form == "log":
        return np.column_stack([one, np.log(x + 1)])
    if form == "lin":
        return np.column_stack([one, x])
    return np.column_stack([one, x, x * x])


def fit(form, x, y):
    A = design(form, x)
    coef, *_ = np.linalg.lstsq(A, y, rcond=None)
    pred = A @ coef
    ss_res = float(np.sum((y - pred) ** 2))
    ss_tot = float(np.sum((y - y.mean()) ** 2))
    r2 = 1.0 - ss_res / ss_tot if ss_tot > 0 else 1.0
    return coef, r2, pred


def choose(x, y):
    """Simplest model the data support, fitted without the smallest n (the first call
    usually creates the structure and is not representative):
    - constant if the best two-parameter model changes by less than 3% of the mean
      over the whole range;
    - otherwise the better of log and linear (both two parameters, compared by R^2),
      unless the quadratic model improves R^2 by at least 0.01 and its square term
      accounts for at least 10% of the value at the largest n."""
    if len(x) > 3:
        x, y = x[1:], y[1:]
    fits = {f: fit(f, x, y) for f in FORMS}
    best2 = "log" if fits["log"][1] > fits["lin"][1] else "lin"
    span = design(best2, np.array([x.min(), x.max()])) @ fits[best2][0]
    if len(x) < 3 or abs(span[1] - span[0]) / abs(y.mean()) < 0.03:
        return "const", fits
    cq, r2q, _ = fits["quad"]
    xm = x.max()
    quad_share = abs(cq[2] * xm * xm) / max(abs(cq[0] + cq[1] * xm + cq[2] * xm * xm), 1e-9)
    if cq[2] > 0 and r2q - fits[best2][1] >= 0.01 and quad_share >= 0.10:
        return "quad", fits
    return best2, fits


def prod_(lo, hi, f):
    return math.prod(f(i) for i in range(int(lo), int(hi) + 1))


def evaluate(expr, lengths, n):
    """Value of the CiaoPP bound ``expr`` when every ``length(V)`` is ``lengths[V](n)``;
    None for ``inf``."""
    if expr == "inf":
        return None
    e = expr.replace("$(i)", "i")
    e = re.sub(r"prod\(i,", "prod_(", e)
    # prod_(lo,hi,body) -> prod_(lo,hi,lambda i: body)
    e = re.sub(r"prod_\(([^,]+),([^,]+),", r"prod_(\1,\2,lambda i: ", e)
    e = re.sub(r"log\(2,", "log2(", e)
    for v, f in lengths.items():
        e = e.replace(f"length({v})", str(f(n)))
    if "length(" in e:
        raise ValueError(f"unassigned size in {expr}")
    return eval(e, {"log2": math.log2, "prod_": prod_, "math": math})  # nosemgrep: eval-detected (CiaoPP output, local tool)
