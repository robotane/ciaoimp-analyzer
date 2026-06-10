from __future__ import annotations

import argparse
import math

import matplotlib.pyplot as plt
from scipy.stats import t as t_dist

from benchmarks.catalog import ALL_BENCHMARKS, FOCUSED_BENCHMARKS, BenchmarkSpec
from core.artifacts import scenario_files
from core.caslog import evaluate_formula, resolve_targets
from core.project import PLOTS_DIR, RAW_DIR, ensure_layout
from core.report import write_csv, write_json
from core.tnf_runtime import measure
from core.prolog_cafe_runtime import measure_pc
from core.ciao_runtime import measure_ciao



def ic95(mean: float, std: float, n: int) -> tuple[float, float]:
    if n < 2 or std == 0.0:
        return mean, mean
    t_crit = t_dist.ppf(0.975, df=n - 1)
    margin = t_crit * std / math.sqrt(n)
    return round(mean - margin, 6), round(mean + margin, 6)


def format_formula(formula: str) -> str:
    return formula.replace("$", "N$")


def run_specs(specs: list[BenchmarkSpec]) -> tuple[dict[str, dict[str, object]], list[dict[str, object]]]:
    ensure_layout()
    caslog_meta = resolve_targets({spec.name: spec.caslog_target for spec in specs})
    all_results: dict[str, dict[str, object]] = {}
    raw_rows: list[dict[str, object]] = []

    for spec in specs:
        print(f"\n>>> Benchmark de : {spec.name} <<<")
        times: list[tuple[int, float, float, float]] = []
        for n in spec.ns:
            pl_file = spec.build_source(n, spec.name)
            _, asm_file = scenario_files(spec.name, n)
            # Ciao a sa propre source si build_ciao_source est defini (variante xsyntax).
            if spec.build_ciao_source is not None:
                ciao_pl_file = spec.build_ciao_source(n, spec.name)
                ciao_is_xsyntax = True
            else:
                ciao_pl_file = pl_file
                ciao_is_xsyntax = False
            try:
                vm = measure(pl_file, asm_file)
                pc = measure_pc(pl_file)
                ciao = measure_ciao(ciao_pl_file, xsyntax=ciao_is_xsyntax)
                bindings = {key: n for key in spec.caslog_bindings}
                caslog_value = evaluate_formula(caslog_meta[spec.name]["formula"], bindings)
                vm_ic_low, vm_ic_high = ic95(vm["mean"], vm["std"], vm["n"])
                pc_ic_low, pc_ic_high = ic95(pc["mean"], pc["std"], pc["n"])
                ciao_ic_low, ciao_ic_high = ic95(ciao["mean"], ciao["std"], ciao["n"])
                raw_rows.append({
                    "benchmark": spec.name,
                    "contract": spec.contract,
                    "predicate": spec.predicate,
                    "n": n,
                    "vm_ms": vm["mean"],
                    "vm_std_ms": vm["std"],
                    "vm_ic_low": vm_ic_low,
                    "vm_ic_high": vm_ic_high,
                    "pc_ms": pc["mean"],
                    "pc_std_ms": pc["std"],
                    "pc_ic_low": pc_ic_low,
                    "pc_ic_high": pc_ic_high,
                    "ciao_ms": ciao["mean"],
                    "ciao_std_ms": ciao["std"],
                    "ciao_ic_low": ciao_ic_low,
                    "ciao_ic_high": ciao_ic_high,
                    "caslog_formula": caslog_meta[spec.name]["formula"],
                    "caslog_value": caslog_value,
                    "complexity_label": spec.complexity_label,
                })
                times.append((n, vm["mean"], pc["mean"], ciao["mean"]))
                print(f"  N={n}: VM={vm['mean']:.4f}±{vm['std']:.4f} ms, PrologCafe={pc['mean']:.4f}±{pc['std']:.4f} ms, Ciao={ciao['mean']:.4f}±{ciao['std']:.4f} ms")
            except Exception as exc:
                print(f"  N={n}: ERREUR ({exc})")
                times.append((n, 0.0, 0.0, 0.0))

        all_results[spec.name] = {
            "spec": spec,
            "times": times,
            "formula": caslog_meta[spec.name]["formula"],
        }
    return all_results, raw_rows


def plot_by_contract(all_results: dict[str, dict[str, object]], raw_rows: list[dict[str, object]]) -> None:
    contracts: dict[str, list[dict[str, object]]] = {}
    for data in all_results.values():
        spec: BenchmarkSpec = data["spec"]
        contracts.setdefault(spec.contract, []).append(data)

    vm_colors = ["#1f77b4", "#4f8fd3", "#7aa6e6", "#a4bdf2"]
    caslog_colors = ["#d62728", "#e25555", "#ec7d7d", "#f3aaaa"]
    for contract, entries in contracts.items():
        # --- TNF VS CasLog (multi-predicates) ---
        fig, ax1 = plt.subplots(figsize=(8, 6))
        ax2 = ax1.twinx()
        lines = []
        labels = []

        for idx, data in enumerate(sorted(entries, key=lambda item: item["spec"].predicate)):
            spec: BenchmarkSpec = data["spec"]
            ns = [n for n, _, _, _ in data["times"]]
            vm_vals = [v for _, v, _, _ in data["times"]]
            caslog_vals = [row["caslog_value"] for row in raw_rows if row["benchmark"] == spec.name]
            vm_color = vm_colors[idx % len(vm_colors)]
            caslog_color = caslog_colors[idx % len(caslog_colors)]
            line_vm = ax1.plot(ns, vm_vals, marker="o", color=vm_color, label=f"VM {spec.predicate}")[0]
            line_caslog = ax2.plot(ns, caslog_vals, linestyle="--", marker="x", color=caslog_color, label=f"CasLog {spec.predicate}")[0]
            lines.extend([line_vm, line_caslog])
            labels.extend([line_vm.get_label(), line_caslog.get_label()])

        first_spec: BenchmarkSpec = entries[0]["spec"]
        ax1.set_title(f"Performance : {contract.upper()} (predicats metier) - TNF vs CasLog")
        ax1.set_xlabel(first_spec.x_label)
        ax1.set_ylabel("Temps d'execution VM TNF (ms)", color="black")
        ax2.set_ylabel("Etapes abstraites CasLog", color="black")
        ax1.set_ylim(bottom=0)
        ax2.set_ylim(bottom=0)
        ax1.set_xticks(ns)
        ax1.set_xticklabels([str(int(n)) for n in ns])
        ax1.grid(True)
        ax1.legend(lines, labels, loc="upper left")
        formula_lines = [f"{data['spec'].predicate} : {format_formula(data['formula'])}" for data in sorted(entries, key=lambda item: item["spec"].predicate)]
        ax1.text(
            0.02,
            0.72,
            "Formules CasLog\n" + "\n".join(formula_lines),
            transform=ax1.transAxes,
            fontsize=8,
            verticalalignment="top",
            bbox={"boxstyle": "round", "facecolor": "white", "alpha": 0.85},
        )
        fig.tight_layout()
        contract_dir = PLOTS_DIR / contract
        contract_dir.mkdir(parents=True, exist_ok=True)
        out_tnf = contract_dir / "tnf_predicats.pdf"
        plt.savefig(out_tnf)
        plt.close(fig)
        print(f"Graphique comparatif multi-predicats genere : {out_tnf}")

        # --- Prolog Cafe VS CasLog (multi-predicates) ---
        fig, ax1 = plt.subplots(figsize=(8, 6))
        ax2 = ax1.twinx()
        lines = []
        labels = []

        for idx, data in enumerate(sorted(entries, key=lambda item: item["spec"].predicate)):
            spec: BenchmarkSpec = data["spec"]
            ns = [n for n, _, _, _ in data["times"]]
            pc_vals = [p if p > 0 else float('nan') for _, _, p, _ in data["times"]]
            caslog_vals = [row["caslog_value"] for row in raw_rows if row["benchmark"] == spec.name]
            pc_color = vm_colors[idx % len(vm_colors)] # Reuse vm_colors
            caslog_color = caslog_colors[idx % len(caslog_colors)]
            line_pc = ax1.plot(ns, pc_vals, marker="^", color=pc_color, label=f"PrologCafe {spec.predicate}")[0]
            line_caslog = ax2.plot(ns, caslog_vals, linestyle="--", marker="x", color=caslog_color, label=f"CasLog {spec.predicate}")[0]
            lines.extend([line_pc, line_caslog])
            labels.extend([line_pc.get_label(), line_caslog.get_label()])

        ax1.set_title(f"Performance : {contract.upper()} (predicats metier) - PrologCafe vs CasLog")
        ax1.set_xlabel(first_spec.x_label)
        ax1.set_ylabel("Temps d'execution PrologCafe (ms)", color="black")
        ax2.set_ylabel("Etapes abstraites CasLog", color="black")
        ax1.set_ylim(bottom=0)
        ax2.set_ylim(bottom=0)
        ax1.set_xticks(ns)
        ax1.set_xticklabels([str(int(n)) for n in ns])
        ax1.grid(True)
        ax1.legend(lines, labels, loc="upper left")
        ax1.text(
            0.02,
            0.72,
            "Formules CasLog\n" + "\n".join(formula_lines),
            transform=ax1.transAxes,
            fontsize=8,
            verticalalignment="top",
            bbox={"boxstyle": "round", "facecolor": "white", "alpha": 0.85},
        )
        fig.tight_layout()
        out_pc = contract_dir / "pc_predicats.pdf"
        plt.savefig(out_pc)
        plt.close(fig)
        print(f"Graphique comparatif multi-predicats genere : {out_pc}")

        # --- Individual plots ---
        for data in sorted(entries, key=lambda item: item["spec"].predicate):
            spec = data["spec"]
            ns = [n for n, _, _, _ in data["times"]]
            vm_vals = [v for _, v, _, _ in data["times"]]
            pc_vals = [p if p > 0 else float('nan') for _, _, p, _ in data["times"]]
            caslog_vals = [row["caslog_value"] for row in raw_rows if row["benchmark"] == spec.name]
            formula = format_formula(data["formula"])

            # Individual TNF
            fig, ax1 = plt.subplots(figsize=(8, 6))
            ax2 = ax1.twinx()
            vm_line = ax1.plot(ns, vm_vals, marker="o", color="blue", label=f"VM {spec.predicate}")[0]
            caslog_line = ax2.plot(ns, caslog_vals, linestyle="--", marker="x", color="red", label=f"CasLog {spec.predicate}")[0]
            ax1.set_title(f"Performance TNF : {contract.upper()} ({spec.predicate})")
            ax1.set_xlabel(spec.x_label)
            ax1.set_ylabel("Temps d'execution VM TNF (ms)", color="black")
            ax2.set_ylabel("Etapes abstraites CasLog", color="black")
            ax1.set_ylim(bottom=0)
            ax2.set_ylim(bottom=0)
            ax1.set_xticks(ns)
            ax1.set_xticklabels([str(int(n)) for n in ns])
            ax1.grid(True)
            ax1.legend([vm_line, caslog_line], [vm_line.get_label(), caslog_line.get_label()], loc="upper left")
            ax1.text(
                0.02,
                0.78,
                f"Formule CasLog : {formula}",
                transform=ax1.transAxes,
                fontsize=9,
                verticalalignment="top",
                bbox={"boxstyle": "round", "facecolor": "white", "alpha": 0.85},
            )
            fig.tight_layout()
            pred_out_tnf = contract_dir / f"{spec.predicate_label}_tnf.pdf"
            plt.savefig(pred_out_tnf)
            plt.close(fig)
            print(f"Graphique par predicat genere : {pred_out_tnf}")

            # Individual Prolog Cafe
            fig, ax1 = plt.subplots(figsize=(8, 6))
            ax2 = ax1.twinx()
            pc_line = ax1.plot(ns, pc_vals, marker="^", color="green", label=f"PrologCafe {spec.predicate}")[0]
            caslog_line = ax2.plot(ns, caslog_vals, linestyle="--", marker="x", color="red", label=f"CasLog {spec.predicate}")[0]
            ax1.set_title(f"Performance PrologCafe : {contract.upper()} ({spec.predicate})")
            ax1.set_xlabel(spec.x_label)
            ax1.set_ylabel("Temps d'execution PrologCafe (ms)", color="black")
            ax2.set_ylabel("Etapes abstraites CasLog", color="black")
            ax1.set_ylim(bottom=0)
            ax2.set_ylim(bottom=0)
            ax1.set_xticks(ns)
            ax1.set_xticklabels([str(int(n)) for n in ns])
            ax1.grid(True)
            ax1.legend([pc_line, caslog_line], [pc_line.get_label(), caslog_line.get_label()], loc="upper left")
            ax1.text(
                0.02,
                0.78,
                f"Formule CasLog : {formula}",
                transform=ax1.transAxes,
                fontsize=9,
                verticalalignment="top",
                bbox={"boxstyle": "round", "facecolor": "white", "alpha": 0.85},
            )
            fig.tight_layout()
            pred_out_pc = contract_dir / f"{spec.predicate_label}_pc.pdf"
            plt.savefig(pred_out_pc)
            plt.close(fig)
            print(f"Graphique par predicat genere : {pred_out_pc}")


def plot_all(all_results: dict[str, dict[str, object]], raw_rows: list[dict[str, object]]) -> None:
    plot_by_contract(all_results, raw_rows)


def export_rows(name: str, rows: list[dict[str, object]]) -> None:
    write_csv(RAW_DIR / f"{name}.csv", rows)
    write_json(RAW_DIR / f"{name}.json", rows)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Execute les benchmarks CasLog vs VM TNF.")
    parser.add_argument(
        "--suite",
        choices=("focused", "all"),
        default="all",
        help="Selectionne soit les benchmarks focalises, soit la campagne complete.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.suite == "focused":
        print("Execution sur la VM a partir de build/normalized...")
        all_results, rows = run_specs(FOCUSED_BENCHMARKS)
        plot_by_contract(all_results, rows)
        export_rows("focused_benchmarks", rows)
        return 0

    print(f"Lancement de tous les benchmarks pour les {len(ALL_BENCHMARKS)} contrats...")
    all_results, rows = run_specs(ALL_BENCHMARKS)
    plot_all(all_results, rows)
    export_rows("all_benchmarks", rows)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
