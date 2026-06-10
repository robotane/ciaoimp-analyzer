import sys
import os
from pathlib import Path
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

# Add current directory to path
sys.path.append(str(Path(__file__).parent))

from benchmarks.catalog import BenchmarkSpec, build_distributor_len_list, build_distributor_len_list_xsyntax
from run_all_benchmarks import run_specs

# Définition du benchmark à grande échelle (jusqu'à N=1000)
spec = BenchmarkSpec(
    "distributor_len_list_large",
    "distributor",
    "len_list/2",
    "O(N)",
    [10, 100, 200, 400, 600, 800, 1000],
    {1: 0},
    build_distributor_len_list,
    "N (Nombre de bénéficiaires)",
    build_ciao_source=build_distributor_len_list_xsyntax
)

print("Exécution du benchmark pour distributor_len_list (N=10 à 1000)...")
results, raw_rows = run_specs([spec])

# Création du répertoire tmp s'il n'existe pas
os.makedirs("tmp", exist_ok=True)

# Conversion en DataFrame pour réutiliser la même logique de tracé et normalisation
df_sub = pd.DataFrame(raw_rows)

def _drop_first_call_outliers(values):
    arr = np.array(values, dtype=float)
    for i in range(len(arr) - 1):
        if np.isnan(arr[i]) or np.isnan(arr[i + 1]):
            continue
        if arr[i + 1] > 0 and arr[i] >= 5.0 * arr[i + 1]:
            arr[i] = np.nan
    return arr

def _normalize(series):
    s = series.replace(0, np.nan)
    s = pd.Series(_drop_first_call_outliers(s.values), index=s.index)
    m = s.max(skipna=True)
    if not np.isfinite(m) or m <= 0:
        return s
    return s / m

# Tracé avec normalisation de 0 à 1 (comme dans le rapport)
COLORS = {
    "vm":     "#1f77b4",   # bleu
    "pc":     "#ff7f0e",   # orange
    "ciao":   "#2ca02c",   # vert
    "caslog": "#d62728",   # rouge
}
MARKERS = {"vm": "o", "pc": "s", "ciao": "D", "caslog": "^"}
LINESTYLES = {"vm": "-", "pc": "-", "ciao": "-", "caslog": "--"}

fig, ax = plt.subplots(figsize=(4.0, 2.8))
ns = df_sub["n"].values.astype(float)

for key, col, label in [
    ("vm",     "vm_ms",       "LT"),
    ("pc",     "pc_ms",       "PC"),
    ("ciao",   "ciao_ms",     "Ciao"),
    ("caslog", "caslog_value", "CasLog"),
]:
    if col not in df_sub.columns:
        continue
    vals = df_sub[col].values.astype(float)
    norm = _normalize(pd.Series(vals)).values
    ax.plot(ns, norm,
            color=COLORS[key], marker=MARKERS[key],
            linestyle=LINESTYLES[key],
            linewidth=1.0, markersize=2.7, label=label)

ax.set_title("distributor — len_list/2 (Normalisé)", fontsize=6.7, pad=2)
ax.set_ylim(-0.05, 1.15)
ax.set_xlabel("N", fontsize=6.5, labelpad=1)
ax.set_ylabel("Norm.", fontsize=6.5, labelpad=1)
ax.set_xticks(ns)
ax.set_xticklabels([str(int(n)) for n in ns])
ax.tick_params(axis="both", labelsize=6, pad=1)
ax.legend(framealpha=0.8, fontsize=7)

plot_path = "tmp/distributor_len_list_large.pdf"
fig.tight_layout(pad=1.0)
fig.savefig(plot_path, bbox_inches="tight")
print(f"\nGraphique normalisé généré dans : {plot_path}")
