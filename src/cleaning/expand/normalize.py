"""CiaoPP syntax normalization: module prefixes, operators, assignments."""
from __future__ import annotations

import re

from .text_utils import (
    M_ASSIGN, M_LOOP, M_BEFORE, M_AFTER,
    find_close, split_commas,
)

_OP_TOKENS = {
    "'term_basic:='":        "_OP_UNIFY_",
    "'term_compare:=='":     "_OP_EQ_",
    "'term_compare:\\\\=='": "_OP_NEQ_",
    "'arithmetic:is'":       "_OP_IS_",
    "'arithmetic:>'":        "_OP_GT_",
    "'arithmetic:<'":        "_OP_LT_",
    "'arithmetic:>='":       "_OP_GE_",
    "'arithmetic:=<'":       "_OP_LE_",
}

_OP_INFIX = {
    "_OP_UNIFY_": "=",
    "_OP_EQ_":    "==",
    "_OP_NEQ_":   "\\==",
    "_OP_IS_":    "is",
    "_OP_GT_":    ">",
    "_OP_LT_":    "<",
    "_OP_GE_":    ">=",
    "_OP_LE_":    "=<",
}


def normalize_syntax(text: str) -> str:
    """Replace CiaoPP-specific syntax with markers and plain Prolog."""
    for prefix in ("'xcontrol_rt:", "'"):
        text = text.replace(prefix + "\\006\\assign'", M_ASSIGN)
        text = text.replace(prefix + "\\006\\loop'",   M_LOOP)
        text = text.replace(prefix + "\\006\\before'", M_BEFORE)
        text = text.replace(prefix + "\\006\\after'",  M_AFTER)
    text = text.replace("'basiccontrol:,'", "','")
    for src, tok in _OP_TOKENS.items():
        text = text.replace(src, tok)
    text = text.replace("'is'", "_OP_IS_")
    text = text.replace("'lists:length'", "length")
    text = text.replace("'lists:append'", "append")
    text = text.replace("'lists:nth'", "nth")
    text = re.sub(r"'[a-z_][a-z_0-9]*:([^']+)'", r"\1", text)
    text = text.replace("basiccontrol:", "")
    return text


def flatten_conj(text: str) -> str:
    """Replace CiaoPP's ','(A, B) with (A, B)."""
    while "','(" in text:
        idx = text.find("','(")
        close = find_close(text, idx + 3)
        if close == -1:
            break
        text = text[:idx] + "(" + text[idx + 4:close] + ")" + text[close + 1:]
    return text


def rewrite_ops(text: str) -> str:
    """Rewrite `_OP_FOO_(A, B)` → `(A op B)` for every operator token."""
    for tok, op in _OP_INFIX.items():
        while tok in text:
            idx = text.find(tok)
            j = idx + len(tok)
            while j < len(text) and text[j] in ' \t\n':
                j += 1
            if j >= len(text) or text[j] != '(':
                text = text[:idx] + op + text[idx + len(tok):]
                continue
            close = find_close(text, j)
            if close == -1:
                text = text[:idx] + op + text[idx + len(tok):]
                continue
            args = split_commas(text[j + 1:close])
            if len(args) == 2:
                text = (text[:idx]
                        + f"({args[0].strip()} {op} {args[1].strip()})"
                        + text[close + 1:])
            else:
                text = (text[:idx] + op + "(" + text[j + 1:close] + ")"
                        + text[close + 1:])
    return text


def find_assigns(text: str):
    """Yield (var, value, (start, end)) for every M_ASSIGN(var, value)."""
    i = 0
    while True:
        idx = text.find(M_ASSIGN, i)
        if idx == -1:
            return
        j = idx + len(M_ASSIGN)
        while j < len(text) and text[j] in ' \t\n':
            j += 1
        if j >= len(text) or text[j] != '(':
            i = j
            continue
        close = find_close(text, j)
        if close == -1:
            return
        args = split_commas(text[j + 1:close])
        if len(args) >= 2:
            yield args[0].strip(), ','.join(args[1:]).strip(), (idx, close + 1)
        i = close + 1


def convert_remaining_assigns(text: str) -> str:
    """Rewrite leftover M_ASSIGN(V, Val) → (V = Val)."""
    while M_ASSIGN in text:
        idx = text.find(M_ASSIGN)
        j = idx + len(M_ASSIGN)
        while j < len(text) and text[j] in ' \t\n':
            j += 1
        if j >= len(text) or text[j] != '(':
            text = text[:idx] + text[j:]
            continue
        close = find_close(text, j)
        if close == -1:
            break
        args = split_commas(text[j + 1:close])
        if len(args) >= 2:
            repl = f"({args[0]} = {','.join(args[1:])})"
        else:
            repl = f"({text[j + 1:close]})"
        text = text[:idx] + repl + text[close + 1:]
    return text
