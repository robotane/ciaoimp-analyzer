"""Textual pre-cleaning before the CasLog semantic transform.

This pass runs before the SWI-Prolog transformer in ``tools/transform.pl``.
It performs transformations that are safer on raw text than through a Prolog
reader:

* drop one-line directives that are not meaningful for CasLog input;
* rename quoted atoms containing ``/`` or ``$disj`` to plain auxiliary names.

The rename is deterministic within a file, so repeated runs on the same input
produce stable output.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path


QUOTED_ATOM_RE = re.compile(r"'((?:\\.|[^'\\])*)'")


def find_quoted_atoms_to_rename(source: str) -> dict[str, str]:
    """Return a deterministic mapping for quoted atoms unsupported by CasLog."""
    seen = set()
    for match in QUOTED_ATOM_RE.finditer(source):
        content = match.group(1)
        if "/" in content or "$disj" in content:
            seen.add(content)
    return {name: f"aux_disj_{i}" for i, name in enumerate(sorted(seen), 1)}


def rename_quoted_atoms(source: str, mapping: dict[str, str]) -> str:
    """Replace mapped quoted atoms with their unquoted auxiliary names."""
    def repl(match: re.Match[str]) -> str:
        content = match.group(1)
        return mapping.get(content, match.group(0))

    return QUOTED_ATOM_RE.sub(repl, source)


def strip_directives(source: str) -> str:
    """Remove single-line Prolog directives from source text."""
    return "".join(
        line for line in source.splitlines(keepends=True)
        if not line.lstrip().startswith(":-")
    )


def preclean(source: str) -> tuple[str, dict[str, str]]:
    """Apply all textual pre-cleaning transformations to ``source``."""
    stripped = strip_directives(source)
    mapping = find_quoted_atoms_to_rename(stripped)
    return rename_quoted_atoms(stripped, mapping), mapping


def preclean_file(src: Path, dst: Path) -> dict[str, str]:
    """Pre-clean ``src`` into ``dst`` and return the quoted-atom mapping."""
    cleaned, mapping = preclean(src.read_text(encoding="utf-8"))
    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_text(cleaned, encoding="utf-8")
    return mapping


def main(argv: list[str]) -> int:
    """CLI wrapper for manual pre-cleaning/debugging."""
    if len(argv) != 2:
        print("usage: python -m src.transforms.caslog_clean <input.pl> <output.pl>", file=sys.stderr)
        return 2
    mapping = preclean_file(Path(argv[0]), Path(argv[1]))
    if mapping:
        print(f"[preclean] {Path(argv[0]).name}: {len(mapping)} quoted atoms renamed", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
