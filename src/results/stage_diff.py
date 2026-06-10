"""Generate a textual report comparing generated pipeline stages.

The compact portable pipeline materializes only the public stages under
``build/``:

``executable``
    Prolog program after CiaoPP expansion, native translation, textual
    CasLog pre-cleaning, and semantic CasLog transformation.
``normalized``
    Analysis-ready program after destate and difference-list normalization.
``annotated``
    CasLog input with inferred ``mode`` and ``measure`` directives.

This module is intentionally read-only: it never drives transformations, it
only compares files already produced by ``pipeline.py``.
"""
from __future__ import annotations

import difflib
import hashlib
import os
import sys
from pathlib import Path


STAGES = [
    ("source", "data/source"),
    ("executable", "build/executable"),
    ("normalized", "build/normalized"),
    ("annotated", "build/annotated"),
]


def _selected_stages() -> list[tuple[str, str]]:
    last = os.environ.get("STAGE_DIFF_LAST_STAGE")
    if not last:
        return STAGES
    try:
        max_idx = int(last)
    except ValueError:
        return STAGES
    return STAGES[: max(1, min(len(STAGES), max_idx + 1))]


def _read(path: Path) -> list[str]:
    try:
        return path.read_text(encoding="utf-8").splitlines(keepends=True)
    except UnicodeDecodeError:
        return path.read_text(errors="replace").splitlines(keepends=True)


def _sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()[:16]


def _stats(path: Path) -> str:
    if not path.exists():
        return "missing"
    lines = _read(path)
    size = path.stat().st_size
    return f"{len(lines)} lines, {size} bytes, sha256={_sha256(path)}"


def _diff(a: Path, b: Path, max_lines: int) -> tuple[list[str], bool]:
    if not a.exists() or not b.exists():
        return [], False
    left = _read(a)
    right = _read(b)
    if left == right:
        return [], False
    diff = list(difflib.unified_diff(
        left,
        right,
        fromfile=str(a),
        tofile=str(b),
        lineterm="",
    ))
    truncated = max_lines > 0 and len(diff) > max_lines
    if truncated:
        diff = diff[:max_lines]
    return diff, truncated


def generate(pipeline_root: Path, names: list[str], out_path: Path) -> None:
    max_lines = int(os.environ.get("STAGE_DIFF_MAX_LINES", "400"))
    out_path.parent.mkdir(parents=True, exist_ok=True)

    with out_path.open("w", encoding="utf-8") as out:
        out.write("CiaoImp pipeline - rapport automatique des differences entre etapes\n")
        out.write("=" * 78 + "\n\n")
        out.write(f"Contrats analyses: {len(names)}\n")
        out.write(
            "Limite de diff par transition: "
            + ("aucune" if max_lines <= 0 else f"{max_lines} lignes")
            + "\n"
        )
        out.write("Configurer avec STAGE_DIFF_MAX_LINES=0 pour un diff complet.\n\n")

        for name in names:
            out.write("#" * 78 + "\n")
            out.write(f"CONTRAT: {name}\n")
            out.write("#" * 78 + "\n\n")

            files = [
                (stage_name, pipeline_root / rel / f"{name}.pl")
                for stage_name, rel in _selected_stages()
            ]

            out.write("Statistiques par etape\n")
            out.write("-" * 78 + "\n")
            for stage_name, path in files:
                out.write(f"{stage_name:16s} {_stats(path)}\n")
            out.write("\n")

            for (stage_a, path_a), (stage_b, path_b) in zip(files, files[1:]):
                out.write(f"Transition {stage_a} -> {stage_b}\n")
                out.write("-" * 78 + "\n")
                diff, truncated = _diff(path_a, path_b, max_lines)
                if not path_a.exists() or not path_b.exists():
                    out.write("Diff indisponible: fichier manquant.\n\n")
                    continue
                if not diff:
                    out.write("Aucune difference textuelle.\n\n")
                    continue
                for line in diff:
                    out.write(line)
                    if not line.endswith("\n"):
                        out.write("\n")
                if truncated:
                    out.write(
                        f"\n[DIFF TRONQUE: limite {max_lines} lignes. "
                        "Relancer avec STAGE_DIFF_MAX_LINES=0 pour tout voir.]\n"
                    )
                out.write("\n")


def main(argv: list[str]) -> int:
    pipeline_root = Path(__file__).resolve().parents[2]
    if argv:
        names = [Path(a).stem for a in argv]
    else:
        names = sorted(p.stem for p in (pipeline_root / "data/source").glob("*.pl"))
    out = pipeline_root / "results" / "stage_diffs.txt"
    generate(pipeline_root, names, out)
    print(f"Stage diff report: {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
