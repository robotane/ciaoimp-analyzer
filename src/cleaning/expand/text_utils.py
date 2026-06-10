"""Text utility primitives for expand — CiaoPP-specific markers and bracket helpers."""
from __future__ import annotations

import re

# CiaoPP SSA markers
M_ASSIGN = "__ASSIGN__"
M_LOOP = "__LOOP__"
M_BEFORE = "__BEFORE__"
M_AFTER = "__AFTER__"


def skip_quoted(s: str, i: int) -> int:
    """Return index just AFTER the closing quote of the atom starting at s[i]."""
    i += 1
    while i < len(s):
        if s[i] == '\\' and i + 1 < len(s):
            i += 2
            continue
        if s[i] == "'":
            return i + 1
        i += 1
    return i


def find_close(s: str, start: int) -> int:
    """Index of the bracket matching s[start]. Returns -1 if unbalanced."""
    open_c = s[start]
    close_c = ')' if open_c == '(' else ']'
    depth = 0
    i = start
    while i < len(s):
        c = s[i]
        if c == "'":
            i = skip_quoted(s, i)
            continue
        if c == open_c:
            depth += 1
        elif c == close_c:
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return -1


def split_commas(s: str) -> list[str]:
    """Split at top-level commas, respecting brackets and quoted atoms."""
    parts, start, dp, db = [], 0, 0, 0
    i = 0
    while i < len(s):
        c = s[i]
        if c == "'":
            i = skip_quoted(s, i)
            continue
        if c == '(':
            dp += 1
        elif c == ')':
            dp -= 1
        elif c == '[':
            db += 1
        elif c == ']':
            db -= 1
        elif c == ',' and dp == 0 and db == 0:
            parts.append(s[start:i].strip())
            start = i + 1
        i += 1
    tail = s[start:].strip()
    if tail:
        parts.append(tail)
    return parts


def strip_outer_parens(s: str) -> str:
    """Remove redundant outer parentheses."""
    s = s.strip()
    while s.startswith('(') and find_close(s, 0) == len(s) - 1:
        s = s[1:-1].strip()
    return s


def extract_functor(s: str) -> tuple[str, list[str]]:
    """Return (functor, [args]) for 'f(a,b)'. Plain atoms return (s, [])."""
    s = s.strip()
    i = 0
    while i < len(s):
        if s[i] == "'":
            i = skip_quoted(s, i)
            continue
        if s[i] == '(':
            close = find_close(s, i)
            if close == -1:
                return (s, [])
            return (s[:i].strip(), split_commas(s[i + 1:close]))
        i += 1
    return (s, [])


def split_cons(val: str) -> tuple[str, str] | None:
    """For `[Head | Tail]` return (Head, Tail). Else None."""
    v = val.strip()
    if not (v.startswith('[') and v.endswith(']')):
        return None
    inner = v[1:-1]
    dp = db = 0
    i = 0
    while i < len(inner):
        c = inner[i]
        if c == "'":
            i = skip_quoted(inner, i)
            continue
        if c == '(':
            dp += 1
        elif c == ')':
            dp -= 1
        elif c == '[':
            db += 1
        elif c == ']':
            db -= 1
        elif c == '|' and dp == 0 and db == 0:
            return (inner[:i].strip(), inner[i + 1:].strip())
        i += 1
    return None
