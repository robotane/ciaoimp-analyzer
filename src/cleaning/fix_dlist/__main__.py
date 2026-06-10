"""Entry point: python -m src.cleaning.fix_dlist <src.pl> <dst.pl>"""
from __future__ import annotations

import sys
from pathlib import Path

from .rewrite import process_file


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print("Usage: python -m src.cleaning.fix_dlist <src.pl> <dst.pl>", file=sys.stderr)
        return 2
    src = Path(argv[0])
    dst = Path(argv[1])
    stats = process_file(src, dst)
    if stats["rewrites"]:
        parts = [f"{n}/{a}(p{p},q{q})" for (n, a, p, q) in stats["rewrites"]]
        print(f"{src.name}: rewrote {parts}")
    else:
        print(f"{src.name}: no dlist pattern")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
