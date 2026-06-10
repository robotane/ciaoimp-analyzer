"""Mode inference for CasLog annotations."""
from __future__ import annotations

import re
from collections import defaultdict

VAR_RE = re.compile(r"^[A-Z_][A-Za-z0-9_]*$")
INT_RE = re.compile(r"^-?\d+$")
LIST_RE = re.compile(r"^\[.*\]$", re.DOTALL)


def _is_fact(clauses: list[tuple[str, list[str], str]], name: str) -> bool:
    return all(nm != name or not body for nm, _, body in clauses)


def _is_compound(val: str) -> bool:
    v = val.strip()
    if not v or v == "_":
        return False
    if VAR_RE.match(v) or INT_RE.match(v):
        return False
    return "(" in v or "[" in v


def _detect_output_positions(
    name: str, arity: int, clauses: list[tuple[str, list[str], str]]
) -> set[int]:
    """Detect output positions (those that should have mode `-`)."""
    out: set[int] = set()
    compound_positions: set[int] = set()
    anon_positions: set[int] = set()
    preds_args: list[tuple[list[str], str]] = []
    for nm, args, body in clauses:
        if nm != name:
            continue
        preds_args.append((args, body))
        for i, raw in enumerate(args):
            if i >= arity:
                break
            a = raw.strip()
            if _is_compound(raw):
                compound_positions.add(i)
            if a == "_":
                anon_positions.add(i)

    for args, _ in preds_args:
        var_at: dict[str, list[int]] = defaultdict(list)
        for i, raw in enumerate(args):
            if i >= arity:
                break
            a = raw.strip()
            if VAR_RE.match(a) and a != "_":
                var_at[a].append(i)
        for positions in var_at.values():
            if len(positions) < 2:
                continue
            compound_hits = [p for p in positions if p in compound_positions]
            if compound_hits:
                out.update(compound_hits)
                continue
            non_anon = [p for p in positions if p not in anon_positions]
            anon_hits = [p for p in positions if p in anon_positions]
            if non_anon and anon_hits:
                out.update(non_anon)
                continue

    validated: set[int] = set()
    for p in out:
        ok = True
        for args, body in preds_args:
            if p >= len(args):
                ok = False
                break
            a = args[p].strip()
            if a == "_":
                ok = False
                break
            if VAR_RE.match(a):
                shared = any(
                    j != p and j < arity and args[j].strip() == a
                    for j in range(len(args))
                )
                if shared:
                    continue
                if re.search(rf"\b{re.escape(a)}\b", body):
                    continue
                ok = False
                break
        if ok:
            validated.add(p)
    return validated


def _detect_literal_output_positions(
    name: str, arity: int, clauses: list[tuple[str, list[str], str]]
) -> set[int]:
    """Detect output positions materialized as literal tags in helper heads.

    This is mainly needed for lifted disjunction helpers such as aux_disj_N/Arity,
    where the result is encoded by head literals (for example 1/2/0) instead of
    by a shared variable reused in the body.
    """
    literal_positions: set[int] = set()
    preds_args = [args for nm, args, _ in clauses if nm == name]
    for i in range(arity):
        literals: set[str] = set()
        for args in preds_args:
            if i >= len(args):
                break
            a = args[i].strip()
            if a != "_" and not VAR_RE.match(a):
                literals.add(a)
        # Treat a position as a helper output only when several distinct
        # literal tags are used there (for example 1/2/0). A lone literal test
        # such as aux_disj_10(_, 0, _) in ballot is a guard, not an output.
        if len(literals) > 1:
            literal_positions.add(i)
    return literal_positions


def infer_modes(
    name: str, arity: int, clauses: list[tuple[str, list[str], str]]
) -> list[str]:
    """Infer mode list for predicate (name/arity)."""
    if arity == 0:
        return []
    if name == "neq" and arity == 2:
        return ["+", "+"]
    if _is_fact(clauses, name):
        per_pos_vals: list[list[str]] = [[] for _ in range(arity)]
        for nm, args, _ in clauses:
            if nm != name:
                continue
            for i in range(arity):
                if i < len(args):
                    per_pos_vals[i].append(args[i].strip())

        def has_compound(v: str) -> bool:
            return v != "_" and not VAR_RE.match(v) and not INT_RE.match(v)

        if any(any(has_compound(v) for v in vals) for vals in per_pos_vals):
            return ["+"] * (arity - 1) + ["-"]

        modes: list[str] = []
        for vals in per_pos_vals:
            is_output = any(v != "_" and (INT_RE.match(v) or not VAR_RE.match(v)) for v in vals)
            modes.append("-" if is_output else "+")
        return modes

    out_positions = _detect_output_positions(name, arity, clauses)
    if out_positions:
        modes_ = ["+"] * arity
        for i in out_positions:
            modes_[i] = "-"
        return modes_

    if name.startswith("aux_disj_"):
        literal_outputs = _detect_literal_output_positions(name, arity, clauses)
        if literal_outputs:
            modes_ = ["+"] * arity
            for i in literal_outputs:
                modes_[i] = "-"
            return modes_
        return ["+"] * arity

    if name.startswith("aux_cond_"):
        return ["+"] * arity

    preds_args = [(args, body) for nm, args, body in clauses if nm == name]
    last = arity - 1
    last_bound = True
    for args, body in preds_args:
        if last >= len(args):
            last_bound = False
            break
        a = args[last].strip()
        if a == "_":
            last_bound = False
            break
        if VAR_RE.match(a):
            shared = any(
                j != last and j < arity and args[j].strip() == a
                for j in range(len(args))
            )
            if shared:
                continue
            if re.search(rf"\b{re.escape(a)}\b", body):
                continue
            last_bound = False
            break
    if last_bound:
        return ["+"] * (arity - 1) + ["-"]
    return ["+"] * arity
