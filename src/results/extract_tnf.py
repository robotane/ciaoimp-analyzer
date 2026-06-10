"""Extract compact answers from TNF Python VM output."""
from __future__ import annotations

import re
import sys
from pathlib import Path


HEADER_RE = re.compile(r"^===\s+(.+?)\s+===$")
ANSWER_RE = re.compile(r"^ANSWER\s+\d+:\s+(.+)$")
TOTAL_RE = re.compile(r"^TNF\s*:\s*(.+)$")


def extract_tnf_results(input_file: str | Path, output_file: str | Path) -> None:
    current: str | None = None
    rows: list[tuple[str, str]] = []
    total = ""

    for raw in Path(input_file).read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        m = HEADER_RE.match(line)
        if m:
            current = m.group(1)
            continue
        m = ANSWER_RE.match(line)
        if m and current:
            rows.append((current, m.group(1)))
            continue
        m = TOTAL_RE.match(line)
        if m:
            total = m.group(1)

    with Path(output_file).open("w", encoding="utf-8") as out:
        if rows:
            width = max(len(name) for name, _ in rows)
            for name, answer in rows:
                out.write(f"{name:<{width}} : {answer}\n")
        else:
            out.write("(Aucune reponse TNF extraite)\n")
        if total:
            out.write(f"\nTNF : {total}\n")


def main() -> int:
    pipeline_root = Path(__file__).resolve().parents[2]
    input_txt = (
        Path(sys.argv[1])
        if len(sys.argv) > 1
        else pipeline_root / "results" / "tnf_results.txt"
    )
    output_txt = (
        Path(sys.argv[2])
        if len(sys.argv) > 2
        else pipeline_root / "results" / "tnf_important_results.txt"
    )
    extract_tnf_results(input_txt, output_txt)
    print(f"Extraction TNF terminee. Resultats sauvegardes dans {output_txt}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
