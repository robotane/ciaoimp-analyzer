"""Sentence-level Prolog parser for CiaoPP-expanded sources."""
from __future__ import annotations

import re

from .text_utils import skip_quoted, find_close


def _sentence_complete(s: str) -> bool:
    s = s.rstrip()
    if not s or s[-1] != '.':
        return False
    dp = db = 0
    in_q = in_dq = False
    last_dot = -1
    i = 0
    while i < len(s):
        c = s[i]
        if in_q:
            if c == '\\' and i + 1 < len(s):
                i += 2
                continue
            if c == "'":
                in_q = False
        elif in_dq:
            if c == '\\' and i + 1 < len(s):
                i += 2
                continue
            if c == '"':
                in_dq = False
        else:
            if c == "'":
                in_q = True
            elif c == '"':
                in_dq = True
            elif c == '(':
                dp += 1
            elif c == ')':
                dp -= 1
            elif c == '[':
                db += 1
            elif c == ']':
                db -= 1
            elif c == '.' and dp == 0 and db == 0:
                last_dot = i
        i += 1
    return last_dot == len(s) - 1


def parse_sentences(text: str) -> list[str]:
    """Split source into complete Prolog sentences."""
    sentences, buf = [], []
    for line in text.split('\n'):
        if not line.strip() and not buf:
            continue
        buf.append(line)
        joined = '\n'.join(buf)
        if _sentence_complete(joined):
            sentences.append(joined)
            buf = []
    if buf and '\n'.join(buf).strip():
        sentences.append('\n'.join(buf))
    return sentences


def split_clause(text: str) -> tuple[str, str | None]:
    """Return (head, body_text) or (head, None) for a fact."""
    t = text.strip()
    if t.endswith('.'):
        t = t[:-1].rstrip()
    i = 0
    while i < len(t):
        c = t[i]
        if c == "'":
            i = skip_quoted(t, i)
            continue
        if c in '([':
            m = find_close(t, i)
            i = (m + 1) if m != -1 else (i + 1)
            continue
        if t[i:i + 2] == ':-':
            return (t[:i].rstrip(), t[i + 2:].strip())
        i += 1
    return (t, None)


def is_noise(sentence: str) -> bool:
    """True for directives, CiaoPP regtypes, and orphan term/1 lines."""
    t = sentence.strip()
    if not t:
        return True
    if t.startswith(':-'):
        return 'use_module(library(format))' not in t
    if re.match(r"^'?rt\d+", t):
        return True
    if re.match(r'^term\([A-Z_]', t) and ':-' not in t:
        return True
    return False
