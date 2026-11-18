"""Normalize executable Prolog into the analysis-ready representation.

The public pipeline exposes a single ``build/normalized`` stage.  Internally,
that stage chains three transformations:

``loops``
    Puts the list loops of the Ciao loops package in canonical form (base
    case ``[]``, no cut, no rest argument) and drops unused helper arguments.
``destate``
    Expands state wrapper arguments such as ``state(A, B, C)`` into plain
    predicate arguments.
``fix_dlist``
    Rewrites specific difference-list accumulator patterns that otherwise
    confuse CasLog mode/measure inference.

The intermediate destated file is temporary and intentionally not part of the
public build layout.
"""
from __future__ import annotations

import sys
import tempfile
from pathlib import Path

from ..destate.core import destate_file
from ..loops.rewrite import process_file as loops_file
from ..fix_dlist.rewrite import process_file as fix_dlist_file


def normalize(src: Path, dst: Path) -> dict:
    """Normalize ``src`` into ``dst`` and return stats for both subpasses."""
    dst.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(suffix=".pl", delete=False) as tmp:
        loops_path = Path(tmp.name)
    with tempfile.NamedTemporaryFile(suffix=".pl", delete=False) as tmp:
        tmp_path = Path(tmp.name)
    try:
        loops_stats = loops_file(src, loops_path)
        destate_stats = destate_file(loops_path, tmp_path)
        fix_stats = fix_dlist_file(tmp_path, dst)
    finally:
        tmp_path.unlink(missing_ok=True)
        loops_path.unlink(missing_ok=True)
    return {"loops": loops_stats, "destate": destate_stats, "fix_dlist": fix_stats}


def main(argv: list[str]) -> int:
    """CLI wrapper; with no args normalizes all files in ``build/executable``."""
    if len(argv) >= 2:
        stats = normalize(Path(argv[0]), Path(argv[1]))
        d = stats["destate"]
        f = stats["fix_dlist"]
        print(
            f"{Path(argv[0]).name}: "
            f"destate={d['expansions']} expansions, "
            f"fix_dlist={len(f['rewrites'])} rewrites"
        )
        return 0

    pipeline_root = Path(__file__).resolve().parents[4]
    src_dir = pipeline_root / "build" / "executable"
    out_dir = pipeline_root / "build" / "normalized"
    out_dir.mkdir(parents=True, exist_ok=True)
    for src in sorted(src_dir.glob("*.pl")):
        dst = out_dir / src.name
        stats = normalize(src, dst)
        d = stats["destate"]
        f = stats["fix_dlist"]
        print(
            f"{src.name}: "
            f"destate={d['expansions']}, "
            f"fix_dlist={len(f['rewrites'])} rewrites"
        )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
