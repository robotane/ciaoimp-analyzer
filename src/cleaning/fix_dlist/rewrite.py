"""Rewrite difference-list accumulator patterns for CasLog.

Some loop helpers generated earlier use a pair of arguments that together form
a difference list.  CasLog's mode/measure inference is more stable when those
pairs are collapsed into a single list element position.  This module detects
that shape in auxiliary predicates, rewrites helper clauses and callers, and
returns in-memory annotation hints consumed by ``src.annotation.annotate``.
"""
from __future__ import annotations

from pathlib import Path

from ...utils.prolog import (
    is_variable, split_clauses, split_head_body, parse_call,
    serialize_call, extract_vars, fresh_var, rename_var_in_term,
)
from .detect import detect_dlist_pattern, parse_list_cons


def rewrite_helper_clauses(clauses: list[dict], name: str, arity: int,
                            pos_p: int, pos_q: int) -> int:
    """Rewrite defining clauses of (name/arity): strip tail at pos_p, drop pos_q.

    Returns the new pos_p after dropping pos_q (shifted left if pos_p > pos_q).
    """
    for c in clauses:
        if c["kind"] != "clause" or not c["head_call"]:
            continue
        hn, hargs = c["head_call"]
        if hn != name or len(hargs) != arity:
            continue
        new_args = list(hargs)
        lc = parse_list_cons(new_args[pos_p])
        if lc is None:
            continue
        elem, _ = lc
        new_args[pos_p] = elem
        new_args = [a for i, a in enumerate(new_args) if i != pos_q]
        c["head_call"] = (hn, new_args)
        c["head_str"] = serialize_call(hn, new_args)
    return pos_p if pos_p < pos_q else pos_p - 1


def rewrite_callers(clauses: list[dict], name: str, arity: int,
                    pos_p: int, pos_q: int) -> tuple[int, dict[tuple[str, int], set[int]]]:
    """Rewrite all body calls to name/arity across the clause set.

    Returns (n_rewritten, splice_positions).
    """
    rewritten = 0
    splice_positions: dict[tuple[str, int], set[int]] = {}
    for c in clauses:
        if c["kind"] != "clause" or c["body"] is None:
            continue
        new_body = list(c["body"])
        local_rename: dict[str, str] = {}
        used = extract_vars(c["head_str"])
        for g in c["body"]:
            used |= extract_vars(g)

        caller_head_updates: list[tuple[str, str]] = []

        for idx, goal in enumerate(c["body"]):
            call = parse_call(goal)
            if call is None:
                continue
            cname, cargs = call
            if cname != name or len(cargs) != arity:
                continue

            arg_p = cargs[pos_p].strip()
            arg_q = cargs[pos_q].strip()

            if not (is_variable(arg_p) and is_variable(arg_q)):
                continue

            elem_var = fresh_var(f"Elem_{rewritten+1}", used)

            new_args = list(cargs)
            new_args[pos_p] = elem_var
            new_args = [a for i, a in enumerate(new_args) if i != pos_q]
            new_body[idx] = serialize_call(cname, new_args)

            if arg_q != arg_p:
                local_rename[arg_q] = arg_p

            caller_head_updates.append((arg_p, elem_var))
            rewritten += 1

        if not caller_head_updates and not local_rename:
            continue

        if local_rename:
            new_body = [rename_var_in_term(g, local_rename) for g in new_body]
            c["head_str"] = rename_var_in_term(c["head_str"], local_rename)
            new_head_call = parse_call(c["head_str"])
            if new_head_call is not None:
                c["head_call"] = (new_head_call[0], list(new_head_call[1]))

        if c["head_call"]:
            hn, hargs = c["head_call"]
            new_hargs = list(hargs)
            for old_var, elem_var in caller_head_updates:
                old_var_renamed = local_rename.get(old_var, old_var)
                for i, a in enumerate(new_hargs):
                    if a.strip() == old_var_renamed:
                        new_hargs[i] = f"[{elem_var}|{old_var_renamed}]"
                        splice_positions.setdefault(
                            (hn, len(new_hargs)), set()
                        ).add(i)
                        break
            c["head_call"] = (hn, new_hargs)
            c["head_str"] = serialize_call(hn, new_hargs)

        c["body"] = new_body

    return rewritten, splice_positions


def process_file(src: Path, dst: Path) -> dict:
    """Rewrite recognized d-list patterns from ``src`` into ``dst``.

    The returned dictionary contains:

    ``rewrites``
        List of helper predicates whose signature was simplified.
    ``output_positions``
        Forced output-mode positions for annotation.
    ``length_positions``
        Positions that should use CasLog's ``length`` measure.
    """
    text = src.read_text()
    raw = split_clauses(text)

    clauses: list[dict] = []
    for r in raw:
        if r.lstrip().startswith(":-"):
            clauses.append({"kind": "directive", "raw": r})
            continue
        head, body = split_head_body(r)
        hc = parse_call(head)
        clauses.append({
            "kind": "clause",
            "raw": r,
            "head_str": head,
            "head_call": (hc[0], list(hc[1])) if hc else None,
            "body": body,
        })

    preds: set[tuple[str, int]] = set()
    for c in clauses:
        if c["kind"] == "clause" and c["head_call"]:
            preds.add((c["head_call"][0], len(c["head_call"][1])))

    rewrites: list[tuple[str, int, int, int]] = []
    hints: dict[tuple[str, int], set[int]] = {}
    length_hints: dict[tuple[str, int], set[int]] = {}
    for name, arity in sorted(preds):
        if not name.startswith(("aux_cond_", "loop_aux_")):
            continue
        pair = detect_dlist_pattern(clauses, name, arity)
        if pair is None:
            continue
        pos_p, pos_q = pair
        n_callers, splice_positions = rewrite_callers(clauses, name, arity, pos_p, pos_q)
        if n_callers == 0:
            continue
        new_pos_p = rewrite_helper_clauses(clauses, name, arity, pos_p, pos_q)
        rewrites.append((name, arity, pos_p, pos_q))
        new_arity = arity - 1
        hints.setdefault((name, new_arity), set()).add(new_pos_p)
        for (cn, ca), positions in splice_positions.items():
            hints.setdefault((cn, ca), set()).update(positions)
            length_hints.setdefault((cn, ca), set()).update(positions)

    out_lines: list[str] = []
    for c in clauses:
        if c["kind"] == "directive":
            out_lines.append(c["raw"].strip())
            continue
        head = c["head_str"]
        if c["body"] is None:
            out_lines.append(f"{head}.")
        else:
            body_text = ",\n    ".join(c["body"])
            out_lines.append(f"{head} :-\n    {body_text}.")

    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_text("\n".join(out_lines) + "\n")

    return {
        "rewrites": rewrites,
        "output_positions": hints,
        "length_positions": length_hints,
    }
