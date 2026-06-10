"""Cross-predicate dataflow propagation for mode/measure fixpoints."""
from __future__ import annotations

import re

from .parser import tokenize_args, split_top_level
from .modes import VAR_RE

VAR_NAME_RE = re.compile(r"[A-Z_][A-Za-z0-9_]*")

BUILTIN_MODES: dict[tuple[str, int], list[str]] = {
    ("!", 0): [],
    ("true", 0): [],
    ("fail", 0): [],
    ("=:=", 2): ["+", "+"],
    ("=\\=", 2): ["+", "+"],
    ("<", 2): ["+", "+"],
    (">", 2): ["+", "+"],
    ("=<", 2): ["+", "+"],
    (">=", 2): ["+", "+"],
    ("==", 2): ["+", "+"],
    ("\\==", 2): ["+", "+"],
    ("is", 2): ["-", "+"],
}

_INFIX_OPS_SORTED = ["=:=", "=\\=", "\\==", "==", ">=", "=<", "is", ">", "<", "="]


def _vars_in(term: str) -> set[str]:
    return {v for v in VAR_NAME_RE.findall(term) if v != "_"}


def _find_body_calls(
    body: str, known: set[tuple[str, int]]
) -> list[tuple[str, list[str]]]:
    """Find every name(args) call in body whose (name, arity) is in known."""
    calls: list[tuple[str, list[str]]] = []
    n = len(body)
    i = 0
    while i < n:
        c = body[i]
        if c in ('"', "'"):
            i += 1
            while i < n and body[i] != c:
                i += 2 if body[i] == "\\" else 1
            i += 1
            continue
        m = re.match(r"([a-z_][A-Za-z0-9_]*)\s*\(", body[i:])
        if not m:
            i += 1
            continue
        name = m.group(1)
        open_pos = i + m.end() - 1
        depth = 1
        j = open_pos + 1
        while j < n and depth > 0:
            ch = body[j]
            if ch in ('"', "'"):
                j += 1
                while j < n and body[j] != ch:
                    j += 2 if body[j] == "\\" else 1
                j += 1
                continue
            if ch == "(":
                depth += 1
            elif ch == ")":
                depth -= 1
            j += 1
        if depth != 0:
            break
        args_str = body[open_pos + 1:j - 1]
        args = tokenize_args(args_str)
        if (name, len(args)) in known:
            calls.append((name, args))
        i = open_pos + 1
    return calls


def _is_word_char(c: str) -> bool:
    return c.isalnum() or c == "_"


def _parse_infix_goal(g: str) -> tuple[str, list[str]] | None:
    depth = 0
    i = 0
    n = len(g)
    while i < n:
        c = g[i]
        if c in "([":
            depth += 1
        elif c in ")]":
            depth -= 1
        elif depth == 0:
            for op in _INFIX_OPS_SORTED:
                end = i + len(op)
                if end > n or g[i:end] != op:
                    continue
                if op == "is":
                    if i > 0 and _is_word_char(g[i - 1]):
                        continue
                    if end < n and _is_word_char(g[end]):
                        continue
                lhs = g[:i].strip()
                rhs = g[end:].strip()
                if not lhs or not rhs:
                    continue
                return (op, [lhs, rhs])
        i += 1
    return None


def parse_body_goals(body: str) -> list[tuple[str, list[str]]]:
    """Parse a clause body into an ordered list of (name, args) goals."""
    out: list[tuple[str, list[str]]] = []
    if not body.strip():
        return out
    for g in split_top_level(body, ","):
        g = g.strip()
        if not g:
            continue
        if g == "!":
            out.append(("!", []))
            continue
        parsed = _parse_infix_goal(g)
        if parsed:
            out.append(parsed)
            continue
        m = re.match(r"^([a-z_][A-Za-z0-9_]*)\s*\((.*)\)\s*$", g, re.DOTALL)
        if m:
            out.append((m.group(1), tokenize_args(m.group(2))))
            continue
        m2 = re.match(r"^([a-z_][A-Za-z0-9_]*)\s*$", g)
        if m2:
            out.append((m2.group(1), []))
    return out


def forward_dataflow_step(
    grouped: dict[tuple[str, int], list[tuple[str, list[str], str]]],
    order: list[tuple[str, int]],
    modes_map: dict[tuple[str, int], list[str]],
) -> bool:
    """One L→R pass over every clause body. Returns True on any change."""
    changed = False
    for key in order:
        name, arity = key
        for nm, args, body in grouped[key]:
            if nm != name:
                continue
            bound: set[str] = set()
            for i, raw in enumerate(args):
                if i >= arity:
                    break
                if modes_map[key][i] == "+":
                    bound |= _vars_in(raw)
            for gname, gargs in parse_body_goals(body):
                gkey = (gname, len(gargs))
                builtin = BUILTIN_MODES.get(gkey)
                gmodes = builtin if builtin is not None else modes_map.get(gkey)
                if gmodes is None:
                    for a in gargs:
                        bound |= _vars_in(a)
                    continue
                for i, raw in enumerate(gargs):
                    if i >= len(gmodes) or gmodes[i] != "+":
                        continue
                    vs = _vars_in(raw)
                    if not vs or vs.issubset(bound):
                        continue
                    if builtin is not None:
                        continue
                    if modes_map[gkey][i] != "-":
                        modes_map[gkey][i] = "-"
                        changed = True
                for a in gargs:
                    bound |= _vars_in(a)
    return changed
