"""Thread variables assigned inside CiaoPP-lifted ``$disj`` predicates.

CiaoPP lifts a top-level ``if`` into a ``$disj`` predicate before statevars
are resolved.  An assignment such as ``Acc := [X | Acc]`` inside that
predicate then has no way back to the caller, and the per-clause SSA pass
turns it into the cyclic ``Acc = [X | Acc]``.

This pass gives each such predicate one extra output argument per assigned
parameter, and re-assigns the variable after every call, so that the SSA
pass of the caller picks up the new version.
"""
from __future__ import annotations

from .normalize import find_assigns
from .parser import split_clause
from .text_utils import M_ASSIGN, extract_functor, find_close


def _assigned_params(sentences: list[str]) -> dict[str, list[int]]:
    """Map each ``$disj`` functor to the parameter positions it assigns."""
    out: dict[str, set[int]] = {}
    for s in sentences:
        head, body = split_clause(s)
        name, args = extract_functor(head)
        if '$disj' not in name or body is None:
            continue
        assigned = {v for v, _, _ in find_assigns(body)}
        for k, a in enumerate(args):
            if a.strip() in assigned:
                out.setdefault(name, set()).add(k)
    return {name: sorted(ks) for name, ks in out.items()}


def _bind_head_inputs(head_args: list[str], body: str, names: set[str]) -> tuple[list[str], str]:
    """Rename head inputs that get re-assigned, so SSA sees them as bound."""
    args = list(head_args)
    pre = []
    for k, a in enumerate(args):
        v = a.strip()
        if v in names:
            args[k] = f"{v}__in"
            pre.append(f"{M_ASSIGN}({v},{v}__in)")
    if pre:
        body = ','.join(pre) + ',\n    ' + body
    return args, body


def _rewrite_calls(body: str, outputs: dict[str, list[int]], counter: list[int]) -> tuple[str, set[str]]:
    """Add output arguments to calls and re-assign the variables after them."""
    reassigned: set[str] = set()
    for name, positions in outputs.items():
        pattern = name + '('
        i = 0
        while True:
            idx = body.find(pattern, i)
            if idx == -1:
                break
            open_ = idx + len(name)
            close = find_close(body, open_)
            if close == -1:
                break
            _, args = extract_functor(body[idx:close + 1])
            extra, after = [], []
            for k in positions:
                v = args[k].strip()
                counter[0] += 1
                fresh = f"{v}__D{counter[0]}" if v[:1].isupper() else f"_D{counter[0]}"
                extra.append(fresh)
                if v[:1].isupper() and v != '_':
                    after.append(f"{M_ASSIGN}({v},{fresh})")
                    reassigned.add(v)
            call = f"{name}({','.join(a.strip() for a in args + extra)})"
            if after:
                call += ',' + ','.join(after)
            body = body[:idx] + call + body[close + 1:]
            i = idx + len(call)
    return body, reassigned


def thread_disj_outputs(sentences: list[str]) -> list[str]:
    outputs = _assigned_params(sentences)
    if not outputs:
        return sentences
    counter = [0]
    result = []
    for s in sentences:
        if s.lstrip().startswith(':-'):
            result.append(s)
            continue
        head, body = split_clause(s)
        name, args = extract_functor(head)
        extra = []
        to_bind: set[str] = set()
        post = []
        if name in outputs:
            assigned = {v for v, _, _ in find_assigns(body)} if body is not None else set()
            for k in outputs[name]:
                v = args[k].strip()
                if v in assigned:
                    extra.append(f"{v}__out")
                    to_bind.add(v)
                    post.append(f"({v}__out = {v})")
                else:
                    extra.append(v)
        if body is not None:
            body, reassigned = _rewrite_calls(body, outputs, counter)
            to_bind |= reassigned & {a.strip() for a in args}
            if post:
                body = body + ',\n    ' + ','.join(post)
            args, body = _bind_head_inputs(args, body, to_bind)
        if args or extra:
            head = f"{name}({','.join(a.strip() for a in args + extra)})"
        result.append(head + '.' if body is None else f"{head} :-\n    {body}.")
    return result
