"""Measure inference for CasLog annotations."""
from __future__ import annotations

import re
from collections import defaultdict

from .modes import VAR_RE, INT_RE, LIST_RE


def _collect_evidence(
    name: str, arity: int, clauses: list[tuple[str, list[str], str]]
) -> list[set[str]]:
    evidence: list[set[str]] = [set() for _ in range(arity)]
    for nm, args, body in clauses:
        if nm != name:
            continue
        sibling_text = " ".join(raw for raw in args)
        scan_text = sibling_text + " " + body
        for i, raw in enumerate(args):
            if i >= arity:
                break
            a = raw.strip()
            if a == "[]" or LIST_RE.match(a):
                evidence[i].add("length")
            if INT_RE.match(a):
                evidence[i].add("int")
            if VAR_RE.match(a) and a != "_":
                v = re.escape(a)
                if (
                    re.search(rf"\b{v}\s+is\b", scan_text)
                    or re.search(rf"\bis\b[^,]*\b{v}\b", scan_text)
                    or re.search(rf"\b{v}\s*(?:>=|=<|=:=|<|>)", scan_text)
                    or re.search(rf"(?:>=|=<|=:=|<|>)\s*{v}\b", scan_text)
                    or re.search(rf"\b{v}\s*(?:\+|-|\*|//)\s*[-0-9A-Za-z_]", scan_text)
                    or re.search(rf"[-0-9A-Za-z_]\s*(?:\+|-|\*|//)\s*{v}\b", scan_text)
                ):
                    evidence[i].add("int")
                if re.search(rf"\[[^\]]*\|\s*{v}\s*\]", scan_text) or re.search(
                    rf"\|\s*{v}\s*\]", scan_text
                ):
                    evidence[i].add("length")
    return evidence


def _share_by_variable(
    name: str, arity: int, clauses: list[tuple[str, list[str], str]],
    evidence: list[set[str]],
) -> list[set[str]]:
    """Merge evidence for arg positions that share the same variable in any head."""
    for nm, args, _ in clauses:
        if nm != name:
            continue
        by_var: dict[str, list[int]] = defaultdict(list)
        for i, raw in enumerate(args):
            if i >= arity:
                break
            a = raw.strip()
            if VAR_RE.match(a) and a != "_":
                by_var[a].append(i)
        for positions in by_var.values():
            if len(positions) < 2:
                continue
            merged: set[str] = set()
            for p in positions:
                merged |= evidence[p]
            for p in positions:
                evidence[p] = set(merged)
    return evidence


def _finalize_measures(name: str, evidence: list[set[str]]) -> list[str]:
    out: list[str] = []
    for ev in evidence:
        if "length" in ev:
            out.append("length")
        elif "int" in ev:
            out.append("int")
        else:
            out.append("void")

    if name.startswith("loop_aux_") and out and out[0] == "length":
        out = ["length"] + [m if m == "length" else "void" for m in out[1:]]

    if name.startswith("aux_cond_"):
        out = [m if m == "length" else "void" for m in out]
    return out


def infer_measures(
    name: str, arity: int, clauses: list[tuple[str, list[str], str]]
) -> list[str]:
    evidence = _collect_evidence(name, arity, clauses)
    evidence = _share_by_variable(name, arity, clauses, evidence)
    return _finalize_measures(name, evidence)
