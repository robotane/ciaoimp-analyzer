#!/usr/bin/env python3
"""
generate_plots.py
Génère toutes les figures d'annexe depuis les CSV de benchmark.
Sortie : images/plots_annexe/ dans le répertoire du rapport.
"""

import os
import pandas as pd
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec
from matplotlib.ticker import MaxNLocator

# ── Chemins ──────────────────────────────────────────────────────────────────
BASE      = os.path.dirname(__file__)
RAW_DIR   = os.path.join(BASE, "results", "raw")
CSV_ALL   = os.path.join(RAW_DIR, "all_benchmarks.csv")
CSV_FIT   = os.path.join(RAW_DIR, "fitting_results.csv")
OUT_DIR   = os.path.join(
    "/home/robotane/Projects/stage/overleaf/rapport_stage_M2_info_overleaf_stopslop",
    "images", "plots_annexe"
)
PRESENTATION_OUT_DIR = os.path.join(
    "/home/robotane/Projects/stage/overleaf/presentation_M2_info_revised",
    "graphics", "plots_annexe"
)
os.makedirs(OUT_DIR, exist_ok=True)
os.makedirs(PRESENTATION_OUT_DIR, exist_ok=True)

# ── Style global ─────────────────────────────────────────────────────────────
COLORS = {
    "vm":     "#1f77b4",   # bleu — LogicTransformers
    "pc":     "#ff7f0e",   # orange — Prolog Cafe
    "ciao":   "#2ca02c",   # vert — Ciao / CiaoPP
    "caslog": "#d62728",   # rouge — CasLog
}
MARKERS = {"vm": "o", "pc": "s", "ciao": "D", "caslog": "^"}
LINESTYLES = {"vm": "-", "pc": "-", "ciao": "-", "caslog": "--"}

plt.rcParams.update({
    "font.family":     "serif",
    "font.size":       9,
    "axes.titlesize":  9,
    "axes.labelsize":  8,
    "legend.fontsize": 7,
    "xtick.labelsize": 7,
    "ytick.labelsize": 7,
    "figure.dpi":      150,
    "axes.grid":       True,
    "grid.alpha":      0.3,
    "grid.linestyle":  ":",
})

# ── Chargement des données ────────────────────────────────────────────────────
df  = pd.read_csv(CSV_ALL)
fit = pd.read_csv(CSV_FIT)

# Nettoyage colonnes
df.columns = df.columns.str.strip()
fit.columns = fit.columns.str.strip()

# Prédicats non-O(1) uniquement (pour les courbes)
df_non_const = df[df["complexity_label"] != "O(1)"].copy()

# ─────────────────────────────────────────────────────────────────────────────
# FIGURE 1 : Distribution des classes de complexité CasLog
# ─────────────────────────────────────────────────────────────────────────────
def fig_complexity_distribution():
    # Compter par benchmark unique (une ligne par (contract, predicate))
    uniq = df.drop_duplicates(subset=["contract", "predicate"])[["contract", "predicate", "complexity_label"]]
    counts = uniq["complexity_label"].value_counts()
    order  = ["O(1)", "O(N)", "O(N²)"]
    counts = counts.reindex([l for l in order if l in counts.index], fill_value=0)

    palette = ["#4878d0", "#ee854a", "#d65f5f"]

    fig, axes = plt.subplots(1, 2, figsize=(8, 3.2))

    # Camembert
    ax = axes[0]
    wedges, texts, autotexts = ax.pie(
        counts.values,
        labels=counts.index,
        autopct="%1.0f%%",
        colors=palette[:len(counts)],
        startangle=90,
        wedgeprops={"edgecolor": "white", "linewidth": 1.2},
    )
    for at in autotexts:
        at.set_fontsize(9)
    ax.set_title("Répartition par classe CasLog\n(prédicats uniques)", pad=8)

    # Barre — par contrat
    ax2 = axes[1]
    contracts = df.drop_duplicates(subset=["contract", "predicate"]).groupby(
        ["contract", "complexity_label"]
    ).size().unstack(fill_value=0)
    contracts = contracts.reindex(columns=[l for l in order if l in contracts.columns], fill_value=0)
    contracts.plot(
        kind="bar", ax=ax2, color=palette[:len(contracts.columns)],
        edgecolor="white", linewidth=0.5, width=0.65,
    )
    ax2.set_title("Classes de complexité par contrat", pad=8)
    ax2.set_xlabel("")
    ax2.set_ylabel("Nombre de prédicats")
    ax2.tick_params(axis="x", rotation=45)
    ax2.legend(title="Classe", framealpha=0.8)
    ax2.yaxis.set_major_locator(MaxNLocator(integer=True))

    fig.tight_layout(pad=1.5)
    path = os.path.join(OUT_DIR, "fig_complexity_distribution.pdf")
    fig.savefig(path, bbox_inches="tight")
    plt.close(fig)
    print(f"  ✓ {path}")


# ─────────────────────────────────────────────────────────────────────────────
# FIGURE 2 : Heatmaps R² individuelles par backend
# ─────────────────────────────────────────────────────────────────────────────
def fig_r2_heatmap():
    # Filtrer O(1) — R² = 0 par définition, pas informatif
    fit_non1 = fit[fit["caslog_model"] != "O(1)"].copy()
    fit_non1["label"] = fit_non1["contract"] + "\n" + fit_non1["predicate"]

    for backend_col, backend_name, fname in [
        ("LogicTransformers", "LogicTransformers (TNF)", "fig_r2_heatmap_vm.pdf"),
        ("PrologCafe",        "Prolog Cafe",              "fig_r2_heatmap_pc.pdf"),
        ("Ciao",              "Ciao / CiaoPP",            "fig_r2_heatmap_ciao.pdf"),
    ]:
        sub = fit_non1[fit_non1["backend"] == backend_col][["label", "r2"]].set_index("label")
        sub = sub.sort_index()

        n = len(sub)
        fig, ax = plt.subplots(figsize=(3.2, max(4, n * 0.38)))
        vals = sub["r2"].values.reshape(-1, 1)
        im = ax.imshow(vals, cmap="RdYlGn", vmin=0, vmax=1, aspect="auto")
        ax.set_xticks([])
        ax.set_yticks(range(n))
        ax.set_yticklabels(sub.index, fontsize=7)
        for i, v in enumerate(sub["r2"].values):
            color = "black" if 0.3 < v < 0.85 else "white"
            ax.text(0, i, f"{v:.2f}", ha="center", va="center",
                    fontsize=7.5, color=color, fontweight="bold")
        fig.colorbar(im, ax=ax, label="R²", fraction=0.08, pad=0.04)
        ax.set_title(f"R² — {backend_name}\n(prédicats non O(1))", pad=6)
        fig.tight_layout(pad=1.2)
        path = os.path.join(OUT_DIR, fname)
        fig.savefig(path, bbox_inches="tight")
        plt.close(fig)
        print(f"  ✓ {path}")


# ─────────────────────────────────────────────────────────────────────────────
# FIGURE 3 : Heatmap R² combinée (vm vs pc vs ciao côte à côte dans une seule figure)
# ─────────────────────────────────────────────────────────────────────────────
def fig_r2_heatmap_combined():
    fit_non1 = fit[fit["caslog_model"] != "O(1)"].copy()
    fit_non1["label"] = fit_non1["contract"] + "\n" + fit_non1["predicate"]

    vm_sub = fit_non1[fit_non1["backend"] == "LogicTransformers"].set_index("label")["r2"]
    pc_sub = fit_non1[fit_non1["backend"] == "PrologCafe"].set_index("label")["r2"]
    ciao_sub = fit_non1[fit_non1["backend"] == "Ciao"].set_index("label")["r2"]
    
    labels = sorted(set(vm_sub.index) | set(pc_sub.index) | set(ciao_sub.index))
    vm_vals = np.array([vm_sub.get(l, np.nan) for l in labels])
    pc_vals = np.array([pc_sub.get(l, np.nan) for l in labels])
    ciao_vals = np.array([ciao_sub.get(l, np.nan) for l in labels])
    data = np.column_stack([vm_vals, pc_vals, ciao_vals])

    n = len(labels)
    fig, ax = plt.subplots(figsize=(5.5, max(5, n * 0.38)))
    im = ax.imshow(data, cmap="RdYlGn", vmin=0, vmax=1, aspect="auto")
    ax.set_xticks([0, 1, 2])
    ax.set_xticklabels(["LogicTransformers", "Prolog Cafe", "Ciao / CiaoPP"], fontsize=8)
    ax.set_yticks(range(n))
    ax.set_yticklabels(labels, fontsize=7)
    for i in range(n):
        for j, v in enumerate(data[i]):
            if not np.isnan(v):
                color = "black" if 0.3 < v < 0.85 else "white"
                ax.text(j, i, f"{v:.2f}", ha="center", va="center",
                        fontsize=7, color=color, fontweight="bold")
    fig.colorbar(im, ax=ax, label="R²", fraction=0.05, pad=0.04)
    ax.set_title("Coefficient R² par prédicat et par backend\n(prédicats non O(1))", pad=8)
    fig.tight_layout(pad=1.2)
    path = os.path.join(OUT_DIR, "fig_r2_heatmap_combined.pdf")
    fig.savefig(path, bbox_inches="tight")
    plt.close(fig)
    print(f"  ✓ {path}")


# ─────────────────────────────────────────────────────────────────────────────
# FIGURE 4 : Boxplot R² par backend d'exécution
# ─────────────────────────────────────────────────────────────────────────────
def fig_r2_boxplot():
    fig, ax = plt.subplots(figsize=(5.5, 3.2))
    order = ["LogicTransformers", "PrologCafe", "Ciao"]
    data_by_backend = [
        fit[(fit["backend"] == b) & (fit["r2"] > 0)]["r2"].values
        for b in order
    ]
    bp = ax.boxplot(
        data_by_backend,
        labels=["LogicTransformers", "Prolog Cafe", "Ciao / CiaoPP"],
        patch_artist=True,
        medianprops={"color": "black", "linewidth": 1.5},
        widths=0.4,
    )
    colors = [COLORS["vm"], COLORS["pc"], COLORS["ciao"]]
    for patch, color in zip(bp["boxes"], colors):
        patch.set_facecolor(color)
        patch.set_alpha(0.65)

    # Scatter des points individuels
    for i, (vals, cls) in enumerate(zip(data_by_backend, order), start=1):
        x = np.random.normal(i, 0.04, size=len(vals))
        ax.scatter(x, vals, alpha=0.6, s=18, color=colors[i - 1], zorder=3)

    ax.set_ylabel("R²")
    ax.set_title("Distribution du R² par backend d'exécution\n(prédicats dont CasLog produit une borne non O(1))")
    ax.axhline(0.95, color="gray", linestyle="--", linewidth=0.8, label="Seuil R²=0,95")
    ax.legend(framealpha=0.8)
    ax.set_ylim(-0.05, 1.05)
    fig.tight_layout(pad=1.2)
    path = os.path.join(OUT_DIR, "fig_r2_boxplot.pdf")
    fig.savefig(path, bbox_inches="tight")
    plt.close(fig)
    print(f"  ✓ {path}")


# ─────────────────────────────────────────────────────────────────────────────
# FIGURE 5 : Scatter vm_ms/pc_ms vs ciao_ms (surcoût par rapport à Ciao natif)
# ─────────────────────────────────────────────────────────────────────────────
def fig_scatter_vm_pc():
    d = df_non_const.copy()
    fig, ax = plt.subplots(figsize=(5.5, 4.2))

    ax.scatter(
        d["ciao_ms"], d["vm_ms"],
        label="LogicTransformers vs Ciao", color=COLORS["vm"], alpha=0.65, s=22, marker="o"
    )
    ax.scatter(
        d["ciao_ms"], d["pc_ms"],
        label="Prolog Cafe vs Ciao", color=COLORS["pc"], alpha=0.65, s=22, marker="s"
    )

    # Droite y = x pour référence
    lim_min = min(d["ciao_ms"].min(), d["vm_ms"].min(), d["pc_ms"].min())
    lim_max = max(d["ciao_ms"].max(), d["vm_ms"].max(), d["pc_ms"].max())
    ax.plot([lim_min, lim_max], [lim_min, lim_max], "k--", linewidth=0.8, alpha=0.5, label="y = x (vitesse native)")

    ax.set_xlabel("Temps Ciao / CiaoPP natif (ms)")
    ax.set_ylabel("Temps des backends alternatifs (ms)")
    ax.set_title("Surcoût d'exécution des backends alternatifs\npar rapport à Ciao Prolog natif (log-log)")
    ax.set_xscale("log"); ax.set_yscale("log")
    ax.legend(framealpha=0.8)
    fig.tight_layout(pad=1.2)
    path = os.path.join(OUT_DIR, "fig_scatter_vm_pc.pdf")
    fig.savefig(path, bbox_inches="tight")
    plt.close(fig)
    print(f"  ✓ {path}")


# ─────────────────────────────────────────────────────────────────────────────
# FIGURE 6 : Courbes normalisées — grille globale tous contrats (non-O(1))
# ─────────────────────────────────────────────────────────────────────────────
def _drop_first_call_outliers(values):
    """Marque les outliers "pic puis chute" comme NaN.

    Sur Prolog Cafe en particulier, la toute premiere mesure d'un scenario
    inclut parfois la compilation JIT C2 / class loading, ce qui produit
    une valeur ~100x plus grande que les suivantes. Le warmup ne suffit
    pas a amortir cela pour des predicats triviaux (len_list, etc.).
    Heuristique : si values[i] >= 5 * values[i+1], values[i] est un
    artefact de mesure -> NaN.
    """
    arr = np.array(values, dtype=float)
    for i in range(len(arr) - 1):
        if np.isnan(arr[i]) or np.isnan(arr[i + 1]):
            continue
        if arr[i + 1] > 0 and arr[i] >= 5.0 * arr[i + 1]:
            arr[i] = np.nan
    return arr


def _normalize(series):
    """Normalise par le max apres avoir traite zeros et outliers comme manquants.

    Les zeros viennent d'echecs de mesure (timer sous le seuil de precision).
    Les outliers "pic puis chute" viennent du class loading / JIT C2 sur le
    tout premier scenario Prolog Cafe.
    """
    s = series.replace(0, np.nan)
    s = pd.Series(_drop_first_call_outliers(s.values), index=s.index)
    m = s.max(skipna=True)
    if not np.isfinite(m) or m <= 0:
        return s
    return s / m

def _plot_one_curve(ax, sub, title, *, title_size=6.7, label_size=6.5,
                    tick_size=6, line_width=1.0, marker_size=2.7,
                    ylabel="Norm."):
    """Trace vm / pc / ciao / caslog normalisés sur un axe."""
    ns = sub["n"].values.astype(float)
    for key, col, label in [
        ("vm",     "vm_ms",       "LT"),
        ("pc",     "pc_ms",       "PC"),
        ("ciao",   "ciao_ms",     "Ciao"),
        ("caslog", "caslog_value","CasLog"),
    ]:
        if col not in sub.columns:
            continue
        vals = sub[col].values.astype(float)
        norm = _normalize(pd.Series(vals)).values
        ax.plot(ns, norm,
                color=COLORS[key], marker=MARKERS[key],
                linestyle=LINESTYLES[key],
                linewidth=line_width, markersize=marker_size, label=label)
    ax.set_title(title, fontsize=title_size, pad=3)
    ax.set_ylim(-0.05, 1.15)
    ax.set_xlabel("N", fontsize=label_size, labelpad=1)
    ax.set_ylabel(ylabel, fontsize=label_size, labelpad=1)
    ax.set_xticks(ns)
    ax.set_xticklabels([str(int(n)) for n in ns])
    ax.tick_params(axis="both", labelsize=tick_size, pad=1)


def _presentation_handles():
    return [
        plt.Line2D([0], [0], color=COLORS["vm"], marker=MARKERS["vm"], linestyle="-", label="LogicTransformers"),
        plt.Line2D([0], [0], color=COLORS["pc"], marker=MARKERS["pc"], linestyle="-", label="Prolog Cafe"),
        plt.Line2D([0], [0], color=COLORS["ciao"], marker=MARKERS["ciao"], linestyle="-", label="Ciao / CiaoPP"),
        plt.Line2D([0], [0], color=COLORS["caslog"], marker=MARKERS["caslog"], linestyle="--", label="CasLog bound"),
    ]


def fig_presentation_selected_curves():
    """Figure 3x2 lisible pour la soutenance, sans relancer les benchmarks.

    Les donnees viennent uniquement de results/raw/all_benchmarks.csv. La figure
    remplace les six graphiques individuels dans le Beamer : titres plus grands,
    legende commune, axes homogenes.
    """
    selected = [
        ("simple_auction", "auction_end/11"),
        ("tictactoe", "check_winner/2"),
        ("gradual_ponzi", "invest/6"),
        ("distributor", "distribute/8"),
        ("crypto_shark", "approve/15"),
        ("crowdfunding", "new_campaign/5"),
    ]

    fig, axes = plt.subplots(3, 2, figsize=(8.6, 6.6), sharey=True)
    axes = axes.ravel()

    for ax, (contract, predicate) in zip(axes, selected):
        sub = df_non_const[
            (df_non_const["contract"] == contract)
            & (df_non_const["predicate"] == predicate)
        ].sort_values("n")
        if sub.empty:
            ax.set_visible(False)
            continue
        title = f"{contract.replace('_', ' ')} · {predicate}"
        _plot_one_curve(
            ax, sub, title,
            title_size=10,
            label_size=8.5,
            tick_size=7.5,
            line_width=1.5,
            marker_size=4.0,
            ylabel="normalised"
        )

    fig.legend(
        handles=_presentation_handles(),
        loc="lower center",
        ncol=4,
        fontsize=9,
        framealpha=0.95,
        bbox_to_anchor=(0.5, 0.005),
        handlelength=2.0,
        columnspacing=1.4,
    )
    fig.subplots_adjust(left=0.07, right=0.99, top=0.98, bottom=0.11, hspace=0.42, wspace=0.22)

    pdf_path = os.path.join(PRESENTATION_OUT_DIR, "fig_presentation_selected_curves.pdf")
    png_path = os.path.join(PRESENTATION_OUT_DIR, "fig_presentation_selected_curves.png")
    fig.savefig(pdf_path, bbox_inches="tight", pad_inches=0.03)
    fig.savefig(png_path, bbox_inches="tight", pad_inches=0.03, dpi=220)
    plt.close(fig)
    print(f"  ✓ {pdf_path}")
    print(f"  ✓ {png_path}")


def fig_presentation_validation_curves():
    """Figure 2x1 pour la diapo Experimental Validation.

    Meme style que fig_presentation_selected_curves : courbes normalisees,
    axes homogenes et legende commune.
    """
    selected = [
        ("simple_pyramid", "invest/8"),
        ("simple_ponzi", "invest/8"),
    ]

    fig, axes = plt.subplots(2, 1, figsize=(4.8, 5.4), sharey=True)

    for ax, (contract, predicate) in zip(axes, selected):
        sub = df_non_const[
            (df_non_const["contract"] == contract)
            & (df_non_const["predicate"] == predicate)
        ].sort_values("n")
        if sub.empty:
            ax.set_visible(False)
            continue
        title = f"{contract.replace('_', ' ')} · {predicate}"
        _plot_one_curve(
            ax, sub, title,
            title_size=10,
            label_size=8.5,
            tick_size=7.5,
            line_width=1.5,
            marker_size=4.0,
            ylabel="normalised"
        )

    fig.legend(
        handles=_presentation_handles(),
        loc="lower center",
        ncol=2,
        fontsize=8,
        framealpha=0.95,
        bbox_to_anchor=(0.5, 0.005),
        handlelength=1.8,
        columnspacing=1.0,
    )
    fig.subplots_adjust(left=0.14, right=0.99, top=0.98, bottom=0.16, hspace=0.42)

    pdf_path = os.path.join(PRESENTATION_OUT_DIR, "fig_presentation_validation_curves.pdf")
    png_path = os.path.join(PRESENTATION_OUT_DIR, "fig_presentation_validation_curves.png")
    fig.savefig(pdf_path, bbox_inches="tight", pad_inches=0.03)
    fig.savefig(png_path, bbox_inches="tight", pad_inches=0.03, dpi=220)
    plt.close(fig)
    print(f"  ✓ {pdf_path}")
    print(f"  ✓ {png_path}")


def _compute_alignment_scores():
    """Score d'alignement par (contract, predicate) = min des R^2 backends.

    Renvoie un dict (contract, predicate) -> (min_r2, dict_par_backend).
    Predicat absent du fit (par ex. O(1)) => non present dans le dict.
    """
    fit_non1 = fit[fit["caslog_model"] != "O(1)"].copy()
    scores = {}
    for (c, p), grp in fit_non1.groupby(["contract", "predicate"]):
        per_backend = {row["backend"]: row["r2"] for _, row in grp.iterrows()}
        valid = [v for v in per_backend.values() if pd.notna(v)]
        min_r2 = min(valid) if valid else float("nan")
        scores[(c, p)] = (min_r2, per_backend)
    return scores


# Seuil R^2 minimal pour considerer qu'une courbe suit la borne CasLog
R2_ALIGNED_THRESHOLD = 0.97


def _render_grid(entries, out_filename, is_anomaly=False):
    """Trace une grille 2 colonnes sans titre global, avec une légende commune.

    Chaque sous-figure montre les courbes normalisées avec le R² min en titre.
    Les anomalies (is_anomaly=True) reçoivent un cadre rouge.
    """
    if not entries:
        return None

    ncols = 3
    n_plots = len(entries)
    nrows = (n_plots + ncols - 1) // ncols

    fig = plt.figure(figsize=(ncols * 5.0, nrows * 3.2 + 0.7))
    gs  = gridspec.GridSpec(nrows, ncols, figure=fig, hspace=0.55, wspace=0.28)

    for idx, ((contract, predicate), sub, _min_r2) in enumerate(entries):
        r, c = idx // ncols, idx % ncols
        ax = fig.add_subplot(gs[r, c])
        _plot_one_curve(ax, sub.sort_values("n"), "")
        r2_str = f"  [R²={_min_r2:.3f}]" if pd.notna(_min_r2) else ""
        ax.set_title(f"{contract} · {predicate}{r2_str}", fontsize=8, pad=3)
        if is_anomaly:
            for spine in ax.spines.values():
                spine.set_edgecolor("#d62728")
                spine.set_linewidth(2.0)

    for idx in range(n_plots, nrows * ncols):
        fig.add_subplot(gs[idx // ncols, idx % ncols]).set_visible(False)

    handles = [
        plt.Line2D([0], [0], color=COLORS["vm"],     marker=MARKERS["vm"],     linestyle="-",  label="LogicTransformers"),
        plt.Line2D([0], [0], color=COLORS["pc"],     marker=MARKERS["pc"],     linestyle="-",  label="Prolog Cafe"),
        plt.Line2D([0], [0], color=COLORS["ciao"],   marker=MARKERS["ciao"],   linestyle="-",  label="Ciao / CiaoPP"),
        plt.Line2D([0], [0], color=COLORS["caslog"], marker=MARKERS["caslog"], linestyle="--", label="CasLog (borne)"),
    ]
    fig.legend(handles=handles, loc="lower center", ncol=4,
               fontsize=8, framealpha=0.9, bbox_to_anchor=(0.5, 0.002),
               borderaxespad=0.2, handlelength=1.8, columnspacing=1.4)

    fig.subplots_adjust(left=0.06, right=0.995, top=0.99, bottom=0.05)
    path = os.path.join(OUT_DIR, out_filename)
    fig.savefig(path, bbox_inches="tight", pad_inches=0.04)
    plt.close(fig)
    return path


def fig_grid_all():
    """Génère trois PDF distincts : deux moitiés de courbes alignées + anomalies.

    Critère : min des R² backends (LogicTransformers, Prolog Cafe, Ciao)
    >= R2_ALIGNED_THRESHOLD => alignée, sinon anomalie.
    Les courbes alignées sont réparties en deux figures (part1, part2) pour
    que chaque page reste lisible. Les anomalies ont un cadre rouge.
    """
    import shutil
    scores = _compute_alignment_scores()
    groups = list(df_non_const.groupby(["contract", "predicate"]))

    aligned, anomalies = [], []
    for key, sub in groups:
        min_r2, _ = scores.get(key, (float("nan"), {}))
        entry = (key, sub, min_r2)
        if pd.notna(min_r2) and min_r2 >= R2_ALIGNED_THRESHOLD:
            aligned.append(entry)
        else:
            anomalies.append(entry)

    aligned.sort(key=lambda x: -x[2] if pd.notna(x[2]) else 0)
    anomalies.sort(key=lambda x: (x[2] if pd.notna(x[2]) else -1))

    # Diviser les alignées en deux moitiés égales
    mid = (len(aligned) + 1) // 2
    part1, part2 = aligned[:mid], aligned[mid:]

    p1 = _render_grid(part1, "fig_grid_aligned_curves_1.pdf")
    p2 = _render_grid(part2, "fig_grid_aligned_curves_2.pdf")
    p3 = _render_grid(anomalies, "fig_grid_anomalies_curves.pdf", is_anomaly=True)

    if p1:
        shutil.copy(p1, os.path.join(OUT_DIR, "fig_grid_aligned_curves.pdf"))
        print(f"  ✓ {p1}  ({len(part1)} courbes)")
    if p2:
        print(f"  ✓ {p2}  ({len(part2)} courbes)")
    if p3:
        print(f"  ✓ {p3}  ({len(anomalies)} anomalies — cadre rouge)")
    else:
        anom_path = os.path.join(OUT_DIR, "fig_grid_anomalies_curves.pdf")
        if os.path.exists(anom_path):
            os.remove(anom_path)
            print(f"  ✓ Supprimé {anom_path} (aucune anomalie)")

    legacy = os.path.join(OUT_DIR, "fig_grid_all_curves.pdf")
    if os.path.exists(legacy):
        os.remove(legacy)


# ─────────────────────────────────────────────────────────────────────────────
# FIGURE 7 : Courbes normalisées individuelles (une par (contrat, prédicat))
# ─────────────────────────────────────────────────────────────────────────────
def fig_individual_curves():
    indiv_dir = os.path.join(OUT_DIR, "individual")
    os.makedirs(indiv_dir, exist_ok=True)

    groups = list(df_non_const.groupby(["contract", "predicate"]))
    for (contract, predicate), sub in groups:
        sub = sub.sort_values("n")
        fig, ax = plt.subplots(figsize=(4.0, 2.8))
        title = f"{contract} — {predicate}"
        _plot_one_curve(ax, sub, title)
        ax.legend(framealpha=0.8, fontsize=7)

        # Nom de fichier : contract_predicate (slash → _)
        fname = f"{contract}_{predicate.replace('/', '_').replace(' ', '')}.pdf"
        path = os.path.join(indiv_dir, fname)
        fig.tight_layout(pad=1.0)
        fig.savefig(path, bbox_inches="tight")
        plt.close(fig)
    print(f"  ✓ {len(groups)} courbes individuelles → {indiv_dir}/")


# ─────────────────────────────────────────────────────────────────────────────
# FIGURE 8 : Tableau R² sous forme de barres horizontales (récap lisible)
# ─────────────────────────────────────────────────────────────────────────────
def fig_r2_bars():
    fit_non1 = fit[fit["caslog_model"] != "O(1)"].copy()
    fit_non1["label"] = fit_non1["contract"] + " · " + fit_non1["predicate"]

    vm_data = fit_non1[fit_non1["backend"] == "LogicTransformers"].set_index("label")["r2"].sort_index()
    pc_data = fit_non1[fit_non1["backend"] == "PrologCafe"].set_index("label")["r2"].reindex(vm_data.index)
    ciao_data = fit_non1[fit_non1["backend"] == "Ciao"].set_index("label")["r2"].reindex(vm_data.index)

    labels = list(vm_data.index)
    n = len(labels)
    y = np.arange(n)
    h = 0.26

    fig, ax = plt.subplots(figsize=(7.5, max(5, n * 0.45)))
    bars1 = ax.barh(y + h, vm_data.values, height=h,
                    color=COLORS["vm"], alpha=0.75, label="LogicTransformers")
    bars2 = ax.barh(y, pc_data.values, height=h,
                    color=COLORS["pc"], alpha=0.75, label="Prolog Cafe")
    bars3 = ax.barh(y - h, ciao_data.values, height=h,
                    color=COLORS["ciao"], alpha=0.75, label="Ciao / CiaoPP")

    ax.axvline(0.95, color="gray", linestyle="--", linewidth=0.9, alpha=0.7, label="R²=0,95")
    ax.set_yticks(y)
    ax.set_yticklabels(labels, fontsize=7)
    ax.set_xlabel("R²")
    ax.set_xlim(0, 1.08)
    ax.set_title("Coefficient R² par prédicat (prédicats non O(1))", pad=8)
    ax.legend(framealpha=0.8, fontsize=8)
    fig.tight_layout(pad=1.2)
    path = os.path.join(OUT_DIR, "fig_r2_bars.pdf")
    fig.savefig(path, bbox_inches="tight")
    plt.close(fig)
    print(f"  ✓ {path}")


# ─────────────────────────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    print(f"\nGénération des figures → {OUT_DIR}\n")
    print("Fig 1 — Distribution des classes de complexité...")
    fig_complexity_distribution()
    print("Fig 2 — Heatmaps R² individuelles...")
    fig_r2_heatmap()
    print("Fig 3 — Heatmap R² combinée...")
    fig_r2_heatmap_combined()
    print("Fig 4 — Boxplot R² par backend...")
    fig_r2_boxplot()
    print("Fig 5 — Scatter vs Ciao...")
    fig_scatter_vm_pc()
    print("Fig 6 — Grille globale toutes courbes...")
    fig_grid_all()
    print("Fig 7 — Courbes individuelles...")
    fig_individual_curves()
    print("Fig 8 — Barres horizontales R²...")
    fig_r2_bars()
    print("Fig 9 — Courbes sélectionnées pour la soutenance...")
    fig_presentation_selected_curves()
    print("Fig 10 — Courbes validation pour la soutenance...")
    fig_presentation_validation_curves()
    print(f"\nTerminé. Tous les fichiers PDF sont dans :\n  {OUT_DIR}\n")
