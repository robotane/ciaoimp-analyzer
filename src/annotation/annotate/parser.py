"""Annotation-specific Prolog parser (no quote-char handling in depth scanner)."""
from __future__ import annotations

import re


def strip_comments(text: str) -> str:
    return re.sub(r"%[^\n]*", "", text)


def split_top_level(s: str, sep: str) -> list[str]:
    """Split s on sep at paren/bracket depth 0. Does not handle quoted atoms."""
    parts, buf, depth = [], [], 0
    i = 0
    while i < len(s):
        c = s[i]
        if c in "([":
            depth += 1
            buf.append(c)
        elif c in ")]":
            depth -= 1
            buf.append(c)
        elif depth == 0 and s[i:i + len(sep)] == sep:
            parts.append("".join(buf).strip())
            buf = []
            i += len(sep)
            continue
        else:
            buf.append(c)
        i += 1
    tail = "".join(buf).strip()
    if tail:
        parts.append(tail)
    return parts


def tokenize_args(arg_str: str) -> list[str]:
    return split_top_level(arg_str, ",")


def parse_clauses(text: str) -> list[tuple[str, list[str], str]]:
    """Return list of (head_name, head_args, body) for every clause."""
    text = strip_comments(text)
    clauses, buf, depth = [], [], 0
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        if c in "([":
            depth += 1
            buf.append(c)
        elif c in ")]":
            depth -= 1
            buf.append(c)
        elif c == "." and depth == 0 and (i + 1 >= n or text[i + 1] in " \t\n\r"):
            clauses.append("".join(buf).strip())
            buf = []
        else:
            buf.append(c)
        i += 1
    tail = "".join(buf).strip()
    if tail:
        clauses.append(tail)

    out = []
    for cl in clauses:
        if not cl:
            continue
        parts = split_top_level(cl, ":-")
        if len(parts) == 1:
            head, body = parts[0], ""
        else:
            head, body = parts[0], ":-".join(parts[1:])
        m = re.match(r"^([a-z_][A-Za-z0-9_]*)\s*\((.*)\)\s*$", head, re.DOTALL)
        if m:
            name = m.group(1)
            args = tokenize_args(m.group(2))
        else:
            m0 = re.match(r"^([a-z_][A-Za-z0-9_]*)\s*$", head)
            if not m0:
                continue
            name, args = m0.group(1), []
        out.append((name, args, body.strip()))
    return out
