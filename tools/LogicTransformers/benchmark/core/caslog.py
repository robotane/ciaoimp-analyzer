from __future__ import annotations

import re
import subprocess
from dataclasses import dataclass
from pathlib import Path

from core.project import CASLOG_RESULTS, PIPELINE_ROOT


@dataclass(frozen=True)
class CaslogTarget:
    contract: str
    predicate: str
    bindings: dict[int, int]


def parse_important_results(path: Path) -> dict[str, dict[str, str]]:
    content = path.read_text(encoding="utf-8") if path.exists() else ""
    current_contract: str | None = None
    results: dict[str, dict[str, str]] = {}

    for raw_line in content.splitlines():
        line = raw_line.strip()
        contract_match = re.match(r"--- CONTRAT : ([A-Z0-9_]+) ---", line)
        if contract_match:
            current_contract = contract_match.group(1).lower()
            results.setdefault(current_contract, {})
            continue

        pred_match = re.match(r"- ([\w\$]+)/(\d+) : Temps = (\[.*\])", line)
        if pred_match and current_contract:
            pred_name = pred_match.group(1)
            arity = pred_match.group(2)
            results[current_contract][f"{pred_name}/{arity}"] = pred_match.group(3)

    return results


def ensure_contract_results(contract_names: list[str]) -> dict[str, dict[str, str]]:
    requested = sorted(set(contract_names))
    cmd = ["python3", "pipeline.py", "--no-tnf", "--no-prolog-cafe"] + [f"{name}.pl" for name in requested]
    subprocess.run(cmd, cwd=PIPELINE_ROOT, check=True)
    return parse_important_results(CASLOG_RESULTS)


def resolve_targets(targets: dict[str, CaslogTarget]) -> dict[str, dict[str, object]]:
    parsed = ensure_contract_results([target.contract for target in targets.values()])
    resolved: dict[str, dict[str, object]] = {}
    for bench_name, target in targets.items():
        formula = parsed.get(target.contract, {}).get(target.predicate)
        if formula is None:
            available = ", ".join(sorted(parsed.get(target.contract, {}))) or "<none>"
            raise KeyError(
                f"Missing CasLog formula for {target.contract}:{target.predicate}. Available: {available}"
            )
        resolved[bench_name] = {
            "contract": target.contract,
            "predicate": target.predicate,
            "formula": formula,
            "bindings": target.bindings,
        }
    return resolved


def _replace_vars(formula: str, bindings: dict[int, int]) -> str:
    def repl(match: re.Match[str]) -> str:
        key = int(match.group(1))
        if key not in bindings:
            raise KeyError(f"Missing binding for ${key} in formula {formula}")
        return str(bindings[key])

    return re.sub(r"\$(\d+)", repl, formula)


def evaluate_formula(formula: str, bindings: dict[int, int]) -> float:
    inner = formula.strip()[1:-1].strip() if formula.startswith("[") and formula.endswith("]") else formula.strip()
    expr = _replace_vars(inner, bindings)
    expr = expr.replace("//", "/")
    if not re.fullmatch(r"[0-9+\-*/(). ]+", expr):
        raise ValueError(f"Unsafe CasLog expression: {expr}")
    return float(eval(expr, {"__builtins__": {}}, {}))
