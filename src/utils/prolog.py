"""Shared low-level Prolog text utilities.

Used by cleaning (destate, fix_dlist) and annotation modules.
Convention for skip_quoted: returns index OF the closing quote (caller
increments past it in its own loop).
"""
from __future__ import annotations

import re

VAR_RE = re.compile(r"^(?:_[A-Za-z0-9_]+|[A-Z][A-Za-z0-9_]*)$")
CALL_START_RE = re.compile(r"([a-z][A-Za-z0-9_]*)\s*\(")


def is_variable(s: str) -> bool:
    return bool(VAR_RE.match(s.strip()))


def skip_quoted(s: str, i: int) -> int:
    """Return index OF the closing quote. Caller increments past it."""
    j = i + 1
    while j < len(s):
        if s[j] == "\\":
            j += 2
            continue
        if s[j] == "'":
            return j
        j += 1
    return len(s) - 1


def find_matching(s: str, open_idx: int, open_c: str = "(", close_c: str = ")") -> int:
    """Return index of the bracket closing s[open_idx]. Raises ValueError if unbalanced."""
    depth = 0
    i = open_idx
    while i < len(s):
        c = s[i]
        if c == open_c:
            depth += 1
        elif c == close_c:
            depth -= 1
            if depth == 0:
                return i
        elif c == "'":
            i = skip_quoted(s, i)
        i += 1
    raise ValueError(f"unmatched {open_c!r} at {open_idx}")


def strip_comments(src: str) -> str:
    """Remove % comments, respecting single-quoted atoms."""
    out = []
    for line in src.split("\n"):
        buf = []
        i = 0
        in_q = False
        while i < len(line):
            c = line[i]
            if c == "'":
                in_q = not in_q
                buf.append(c)
            elif c == "%" and not in_q:
                break
            else:
                buf.append(c)
            i += 1
        out.append("".join(buf))
    return "\n".join(out)


def split_top_level(s: str, sep: str = ",") -> list[str]:
    """Split s on sep at paren/bracket depth 0, respecting quoted atoms."""
    parts: list[str] = []
    depth_p = depth_b = 0
    start = 0
    i = 0
    while i < len(s):
        c = s[i]
        if c == "(":
            depth_p += 1
        elif c == ")":
            depth_p -= 1
        elif c == "[":
            depth_b += 1
        elif c == "]":
            depth_b -= 1
        elif c == "'":
            i = skip_quoted(s, i)
        elif c == sep and depth_p == 0 and depth_b == 0:
            parts.append(s[start:i])
            start = i + 1
        i += 1
    parts.append(s[start:])
    return parts


def split_clauses(src: str) -> list[str]:
    """Split Prolog source text into individual clause strings."""
    src = strip_comments(src)
    clauses: list[str] = []
    depth_p = depth_b = 0
    start = 0
    i = 0
    while i < len(src):
        c = src[i]
        if c == "(":
            depth_p += 1
        elif c == ")":
            depth_p -= 1
        elif c == "[":
            depth_b += 1
        elif c == "]":
            depth_b -= 1
        elif c == "'":
            i = skip_quoted(src, i)
        elif c == "." and depth_p == 0 and depth_b == 0:
            piece = src[start:i + 1]
            if piece.strip():
                clauses.append(piece)
            start = i + 1
        i += 1
    tail = src[start:]
    if tail.strip():
        clauses.append(tail)
    return clauses


def split_head_body(clause: str) -> tuple[str, list[str] | None]:
    """Return (head, body_goals) or (clause, None) for facts/directives."""
    clause = clause.strip()
    if clause.endswith("."):
        clause = clause[:-1].rstrip()
    depth_p = depth_b = 0
    i = 0
    n = len(clause)
    while i < n - 1:
        c = clause[i]
        if c == "(":
            depth_p += 1
        elif c == ")":
            depth_p -= 1
        elif c == "[":
            depth_b += 1
        elif c == "]":
            depth_b -= 1
        elif c == "'":
            i = skip_quoted(clause, i)
        elif (
            c == ":"
            and i + 1 < n
            and clause[i + 1] == "-"
            and depth_p == 0
            and depth_b == 0
        ):
            head = clause[:i].rstrip()
            body = clause[i + 2:].lstrip()
            goals = [g.strip() for g in split_top_level(body)]
            return head, goals
        i += 1
    return clause, None


def parse_call(goal: str) -> tuple[str, list[str]] | None:
    """Parse `name(a1, ..., aN)` into (name, [a1, ..., aN]), or None."""
    g = goal.strip()
    m = CALL_START_RE.match(g)
    if not m:
        return None
    name = m.group(1)
    open_idx = m.end() - 1
    try:
        close_idx = find_matching(g, open_idx)
    except ValueError:
        return None
    if close_idx != len(g) - 1:
        return None
    inner = g[open_idx + 1:close_idx]
    args = [a.strip() for a in split_top_level(inner)]
    return name, args


def serialize_call(name: str, args: list[str]) -> str:
    return f"{name}({', '.join(args)})"


def extract_vars(text: str) -> set[str]:
    """Collect all Prolog variable names occurring in text."""
    return set(re.findall(r"\b(?:_[A-Za-z0-9_]+|[A-Z][A-Za-z0-9_]*)\b", text))


def fresh_var(base: str, used: set[str]) -> str:
    """Return a fresh variable name derived from base, not in used."""
    cand = base
    k = 0
    while cand in used:
        k += 1
        cand = f"{base}_{k}"
    used.add(cand)
    return cand


def rename_var_in_term(term: str, mapping: dict[str, str]) -> str:
    """Rename variables in term according to mapping."""
    if not mapping:
        return term
    pattern = r"\b(?:_[A-Za-z0-9_]+|[A-Z][A-Za-z0-9_]*)\b"
    return re.sub(pattern, lambda m: mapping.get(m.group(0), m.group(0)), term)
