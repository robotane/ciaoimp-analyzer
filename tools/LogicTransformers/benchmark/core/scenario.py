from __future__ import annotations

import re
from pathlib import Path


def strip_goal(source_text: str) -> str:
    lines = source_text.splitlines(keepends=True)
    kept: list[str] = []
    in_goal = False
    for line in lines:
        if line.startswith("goal("):
            in_goal = True
        if not in_goal:
            kept.append(line)
        if in_goal and "." in line:
            in_goal = False
    return "".join(kept)


def read_source_without_goal(source_file: Path) -> str:
    return strip_goal(source_file.read_text(encoding="utf-8"))


# --- Source xsyntax (data/source/<contrat>.pl) -----------------------------
# Format : ":- module(_, [...], [fsyntax, statevars, hiord, loops]).", puis
# prédicats métier en syntaxe impérative, puis un goal/1 natif fixe.
# Pour qu'on puisse l'inclure depuis un harness, on retire :
#   1. la déclaration de module ":- module(...)."
#   2. le goal/1 natif (qu'on remplace par notre goal paramétré)
#
# Les directives `use_package` éventuelles sont conservées.


_MODULE_DECL_RE = re.compile(r"^\s*:-\s*module\([^.]*?\)\s*\.\s*\n?", re.DOTALL | re.MULTILINE)


def strip_module_decl(source_text: str) -> str:
    """Retire la première ":- module(...)." du source xsyntax."""
    return _MODULE_DECL_RE.sub("", source_text, count=1)


def read_xsyntax_source_without_goal(source_file: Path) -> str:
    """Lit un source xsyntax et renvoie le code sans déclaration de module
    ni goal/1 natif, prêt à être inclus depuis un harness.
    """
    text = source_file.read_text(encoding="utf-8")
    text = strip_module_decl(text)
    return strip_goal(text)
