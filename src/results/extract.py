"""Extract important predicate results from CasLog full output."""
from __future__ import annotations

import re
import sys
from pathlib import Path

IGNORE_PREFIXES = (
    "aux_", "loop_", "get_", "set_", "add_votes",
    "add_weight", "find_", "check_and_give", "update_", "append_",
    "clean_", "remove_", "shares_on_sale_of", "distribute_loop",
    "distribute_range", "process_",
)

_IGNORE_EXACT = {"transfer", "neq", "append"}


def is_important(pred_name: str) -> bool:
    if pred_name in _IGNORE_EXACT:
        return False
    return not any(pred_name.startswith(p) for p in IGNORE_PREFIXES)


def extract_important_results(input_file: str | Path, output_file: str | Path) -> None:
    content = Path(input_file).read_text(encoding="utf-8")

    with open(output_file, "w", encoding="utf-8") as out:
        out.write("CasLog — contrats annotés : RESULTATS DES PREDICATS IMPORTANTS\n")
        out.write("==============================================================\n\n")

        contracts = re.split(
            r"========================================================\n\s*CONTRAT :\s*(\w+)\n========================================================",
            content,
        )

        for i in range(1, len(contracts), 2):
            contract_name = contracts[i]
            contract_content = contracts[i + 1]
            out.write(f"--- CONTRAT : {contract_name.upper()} ---\n")

            predicates = re.split(
                r"\*+\n\s+([\w\$]+)/(\d+)\s+\n\*+", contract_content
            )

            found_important = False
            for j in range(1, len(predicates), 3):
                pred_name = predicates[j]
                arity = predicates[j + 1]
                pred_content = predicates[j + 2]

                if is_important(pred_name):
                    time_match = re.search(
                        r"\* Time functions for predicate "
                        + re.escape(pred_name)
                        + r"/\d+ :\n\n(\[.*?\])",
                        pred_content,
                        re.DOTALL,
                    )
                    if time_match:
                        time_result = time_match.group(1).replace("\n", "").strip()
                        out.write(f"  - {pred_name}/{arity} : Temps = {time_result}\n")
                        found_important = True

            if not found_important:
                out.write("  (Aucun prédicat important ou timeout)\n")
            out.write("\n")


def main() -> int:
    pipeline_root = Path(__file__).resolve().parents[2]
    input_txt = sys.argv[1] if len(sys.argv) > 1 else str(pipeline_root / "results" / "caslog_full_results.txt")
    output_txt = sys.argv[2] if len(sys.argv) > 2 else str(pipeline_root / "results" / "caslog_important_results.txt")
    extract_important_results(input_txt, output_txt)
    print(f"Extraction terminée. Résultats sauvegardés dans {output_txt}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
