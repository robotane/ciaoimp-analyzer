"""Entry point: python -m src.cleaning.destate <src.pl> <dst.pl>."""
from __future__ import annotations

import sys
from pathlib import Path

from .core import destate_file


def main(argv: list[str]) -> int:
    if len(argv) >= 2:
        stats = destate_file(Path(argv[0]), Path(argv[1]))
        print(f"{Path(argv[0]).name}: {stats['expansions']} expansions, wrappers={stats['wrappers']}")
        return 0

    print("Usage: python -m src.cleaning.destate <src.pl> <dst.pl>", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
