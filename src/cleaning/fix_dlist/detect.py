"""Detect difference-list accumulator patterns."""
from __future__ import annotations

from ...utils.prolog import is_variable, split_top_level, skip_quoted


def parse_list_cons(arg: str) -> tuple[str, str] | None:
    """If arg is `[Elem|Tail]` with a single element before the bar, return (Elem, Tail)."""
    s = arg.strip()
    if not (s.startswith("[") and s.endswith("]")):
        return None
    inner = s[1:-1]
    depth_p = depth_b = 0
    bar_idx = -1
    i = 0
    while i < len(inner):
        c = inner[i]
        if c == "(":
            depth_p += 1
        elif c == ")":
            depth_p -= 1
        elif c == "[":
            depth_b += 1
        elif c == "]":
            depth_b -= 1
        elif c == "'":
            i = skip_quoted(inner, i) + 1
            continue
        elif c == "|" and depth_p == 0 and depth_b == 0:
            bar_idx = i
            break
        i += 1
    if bar_idx < 0:
        return None
    elem = inner[:bar_idx].strip()
    tail = inner[bar_idx + 1:].strip()
    if len(split_top_level(elem)) != 1:
        return None
    if not is_variable(tail):
        return None
    return elem, tail


def detect_dlist_pattern(clauses: list[dict], name: str, arity: int):
    """Check if predicate (name, arity) matches the difference-list pattern.

    Returns (pos_P, pos_Q) if all clauses share the pattern where some var
    Tail appears as tail of `[Elem|Tail]` at pos_P and bare at pos_Q.
    Returns None otherwise.
    """
    defs = [
        c for c in clauses
        if c["kind"] == "clause" and c["head_call"]
        and c["head_call"][0] == name and len(c["head_call"][1]) == arity
    ]
    if not defs:
        return None

    candidates: set[tuple[int, int]] | None = None
    for c in defs:
        args = c["head_call"][1]
        pairs: set[tuple[int, int]] = set()
        for p, a in enumerate(args):
            lc = parse_list_cons(a)
            if lc is None:
                continue
            elem, tail = lc
            for q, b in enumerate(args):
                if q == p:
                    continue
                if is_variable(b) and b.strip() == tail:
                    pairs.add((p, q))
        if candidates is None:
            candidates = pairs
        else:
            candidates &= pairs
        if not candidates:
            return None
    if candidates:
        return sorted(candidates)[0]
    return None
