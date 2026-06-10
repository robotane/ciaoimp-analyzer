"""Strip ``state(...)``-like compound wrappers from CasLog-ready Prolog.

The CiaoMoka expansion represents object state as compound terms.  CasLog and
the downstream TNF tooling work better when those compounds are flattened into
ordinary predicate arguments.  This module detects which predicate argument
positions carry state wrappers, propagates that information through shared
variables, and rewrites heads/body calls consistently.
"""
from __future__ import annotations

import re
from pathlib import Path

from ...utils.prolog import (
    is_variable, split_top_level, strip_comments,
    split_clauses, split_head_body, parse_call, serialize_call, extract_vars,
)

WRAPPER_NAME_RE = re.compile(r"^(state|[a-z][A-Za-z0-9_]*_state)$")


def is_wrapper_name(name: str) -> bool:
    """Return whether ``name`` is considered a state wrapper functor."""
    return bool(WRAPPER_NAME_RE.match(name))


def is_anon(s: str) -> bool:
    """Return whether a textual argument is the anonymous variable ``_``."""
    return s.strip() == "_"


def parse_wrapper(arg: str) -> tuple[str, list[str]] | None:
    """If arg is `wrapperName(a1, ..., aK)` entirely, return (name, args)."""
    call = parse_call(arg)
    if call is None:
        return None
    name, args = call
    if not is_wrapper_name(name):
        return None
    return name, args


def destate_file(src_path: Path, out_path: Path) -> dict:
    """Rewrite a Prolog file by expanding wrapper argument positions.

    Returns a dictionary with expansion counts and wrapper-position metadata
    used by callers for reporting.
    """
    src = src_path.read_text()
    clauses_raw = split_clauses(src)

    parsed: list[dict] = []
    for clause in clauses_raw:
        if clause.lstrip().startswith(":-"):
            parsed.append({"kind": "directive", "raw": clause})
            continue
        head, body = split_head_body(clause)
        head_call = parse_call(head)
        parsed.append({
            "kind": "clause",
            "raw": clause,
            "head_str": head,
            "head_call": head_call,
            "body": body,
        })

    pred_keys: set[tuple[str, int]] = set()
    for c in parsed:
        if c["kind"] == "clause" and c["head_call"]:
            n, a = c["head_call"]
            pred_keys.add((n, len(a)))

    for c in parsed:
        if c["kind"] != "clause":
            continue
        c["body_calls"] = []
        if c["body"] is None:
            continue
        for idx, g in enumerate(c["body"]):
            call = parse_call(g)
            if call and (call[0], len(call[1])) in pred_keys:
                c["body_calls"].append((idx, call[0], list(call[1])))

    def calls_of(c) -> list[tuple[tuple[str, int], list[str]]]:
        out = []
        if c["head_call"] and (c["head_call"][0], len(c["head_call"][1])) in pred_keys:
            n, a = c["head_call"]
            out.append(((n, len(a)), a))
        for _, n, a in c.get("body_calls", []):
            out.append(((n, len(a)), a))
        return out

    # Pass 1: direct wrapper positions
    wrapper_pos: dict[tuple[str, int], set[int]] = {k: set() for k in pred_keys}
    for c in parsed:
        if c["kind"] != "clause":
            continue
        for key, args in calls_of(c):
            for i, a in enumerate(args):
                if parse_wrapper(a) is not None:
                    wrapper_pos[key].add(i)

    # Pass 2: fixpoint propagation through shared variables
    changed = True
    while changed:
        changed = False
        for c in parsed:
            if c["kind"] != "clause":
                continue
            state_vars: set[str] = set()
            for key, args in calls_of(c):
                for i in wrapper_pos.get(key, set()):
                    if i < len(args):
                        a = args[i].strip()
                        if is_variable(a):
                            state_vars.add(a)
            if not state_vars:
                continue
            for key, args in calls_of(c):
                for i, a in enumerate(args):
                    s = a.strip()
                    if is_variable(s) and s in state_vars and i not in wrapper_pos[key]:
                        wrapper_pos[key].add(i)
                        changed = True

    # Pass 3: determine arity per wrapper position + propagate via vars
    pos_arity: dict[tuple[tuple[str, int], int], int] = {}
    for c in parsed:
        if c["kind"] != "clause":
            continue
        for key, args in calls_of(c):
            for i in wrapper_pos.get(key, set()):
                if i < len(args):
                    w = parse_wrapper(args[i])
                    if w is not None:
                        pos_arity[(key, i)] = len(w[1])

    changed = True
    while changed:
        changed = False
        for c in parsed:
            if c["kind"] != "clause":
                continue
            var_arity: dict[str, int] = {}
            for key, args in calls_of(c):
                for i in wrapper_pos.get(key, set()):
                    if i < len(args) and (key, i) in pos_arity:
                        a = args[i].strip()
                        if is_variable(a):
                            var_arity[a] = pos_arity[(key, i)]
            for key, args in calls_of(c):
                for i in wrapper_pos.get(key, set()):
                    if (key, i) in pos_arity or i >= len(args):
                        continue
                    a = args[i].strip()
                    if is_variable(a) and a in var_arity:
                        pos_arity[(key, i)] = var_arity[a]
                        changed = True

    # Pass 4: rewrite clauses
    wrappers_seen: set[str] = set()
    expansions = 0
    rewritten: list[str] = []

    for c in parsed:
        if c["kind"] == "directive":
            rewritten.append(c["raw"].strip())
            continue

        texts = [c["head_str"]]
        if c["body"]:
            texts.extend(c["body"])
        clause_vars: set[str] = set()
        for t in texts:
            clause_vars |= extract_vars(t)

        var_expand: dict[str, list[str]] = {}
        for key, args in calls_of(c):
            for i in wrapper_pos.get(key, set()):
                if i >= len(args):
                    continue
                a = args[i].strip()
                if is_variable(a) and a not in var_expand:
                    arity = pos_arity.get((key, i))
                    if arity is None:
                        continue
                    fresh = []
                    for k in range(1, arity + 1):
                        cand = f"{a}_{k}"
                        extra = 0
                        while cand in clause_vars:
                            extra += 1
                            cand = f"{a}_{k}_{extra}"
                        clause_vars.add(cand)
                        fresh.append(cand)
                    var_expand[a] = fresh

        def expand(key: tuple[str, int], args: list[str]) -> list[str]:
            nonlocal expansions
            wp = wrapper_pos.get(key, set())
            out: list[str] = []
            for i, a in enumerate(args):
                a = a.strip()
                if i not in wp:
                    out.append(a)
                    continue
                arity = pos_arity.get((key, i))
                if arity is None:
                    out.append(a)
                    continue
                w = parse_wrapper(a)
                if w is not None:
                    wrappers_seen.add(w[0])
                    out.extend(w[1])
                    expansions += 1
                elif is_anon(a):
                    out.extend(["_"] * arity)
                elif is_variable(a) and a in var_expand:
                    out.extend(var_expand[a])
                else:
                    out.append(a)
            return out

        new_head = c["head_str"]
        if c["head_call"] and (c["head_call"][0], len(c["head_call"][1])) in pred_keys:
            n, a = c["head_call"]
            new_args = expand((n, len(a)), a)
            new_head = serialize_call(n, new_args)

        if c["body"] is None:
            rewritten.append(f"{new_head}.")
            continue

        new_body = list(c["body"])
        for idx, n, a in c["body_calls"]:
            new_args = expand((n, len(a)), a)
            new_body[idx] = serialize_call(n, new_args)
        body_text = ",\n    ".join(new_body)
        rewritten.append(f"{new_head} :-\n    {body_text}.")

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text("\n".join(rewritten) + "\n")

    return {
        "expansions": expansions,
        "wrappers": sorted(wrappers_seen),
        "wrapper_positions": {
            f"{k[0]}/{k[1]}": sorted(v) for k, v in wrapper_pos.items() if v
        },
    }
