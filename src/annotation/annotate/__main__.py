"""Infer CasLog annotations for normalized Prolog contracts.

This module produces ``build/annotated`` files by prepending CasLog
``mode/2`` and ``measure/2`` directives to normalized Prolog.  It removes
execution-only predicates such as ``goal/1`` and ``main/0`` because those are
used by TNF execution scenarios, not by CasLog analysis.

The main pipeline passes d-list rewrite hints in memory.  No sidecar JSON file
is required.
"""
from __future__ import annotations

import sys
from collections import defaultdict
from pathlib import Path
import re

from .parser import parse_clauses
from .modes import infer_modes, VAR_RE
from .measures import _collect_evidence, _share_by_variable, _finalize_measures
from .propagate import _find_body_calls, _vars_in
from ..demote_modes import demote_fixpoint


def _split_source_clauses(text: str) -> list[str]:
    """Split a Prolog source into top-level clauses, preserving clause text."""
    clauses: list[str] = []
    start = 0
    depth = 0
    quote: str | None = None
    escape = False
    in_line_comment = False

    i = 0
    while i < len(text):
        c = text[i]

        if in_line_comment:
            if c == "\n":
                in_line_comment = False
            i += 1
            continue

        if quote is not None:
            if escape:
                escape = False
            elif c == "\\":
                escape = True
            elif c == quote:
                quote = None
            i += 1
            continue

        if c == "%":
            in_line_comment = True
            i += 1
            continue
        if c in ("'", '"'):
            quote = c
            i += 1
            continue
        if c in "([":
            depth += 1
        elif c in ")]":
            depth = max(0, depth - 1)
        elif c == "." and depth == 0 and (i + 1 == len(text) or text[i + 1] in " \t\r\n"):
            clauses.append(text[start:i + 1])
            start = i + 1
        i += 1

    if start < len(text):
        tail = text[start:]
        if tail.strip():
            clauses.append(tail)
    return clauses


def _is_goal_clause(clause: str) -> bool:
    parsed = parse_clauses(clause)
    return len(parsed) == 1 and parsed[0][0] == "goal" and len(parsed[0][1]) == 1


def _is_main_clause(clause: str) -> bool:
    parsed = parse_clauses(clause)
    return len(parsed) == 1 and parsed[0][0] == "main" and len(parsed[0][1]) == 0


def remove_execution_predicates(text: str) -> str:
    """Remove execution-only predicates before CasLog annotation.

    Step 6 is the CasLog input. It deliberately excludes:
    - goal/1, used as an execution scenario for TNF
    - main/0, when present as a local test harness
    """
    return "".join(
        clause for clause in _split_source_clauses(text)
        if not _is_goal_clause(clause) and not _is_main_clause(clause)
    ).lstrip()


def _normalize_hints(hints: dict | None) -> tuple[
    dict[tuple[str, int], set[int]],
    dict[tuple[str, int], set[int]],
]:
    if not hints:
        return {}, {}
    return (
        hints.get("output_positions") or hints.get("hints") or {},
        hints.get("length_positions") or {},
    )


from src.utils.prolog import split_top_level

COLLECT_MODES = Path(__file__).resolve().parents[1] / "collect_modes.pl"


def observed_modes(src: Path) -> dict[tuple[str, int], list[str]]:
    """Modes seen when goal/1 runs (collect_modes.pl): ``+`` for an argument
    ground at every call, or unbound at every call and every exit (ignored by
    the predicate); ``-`` otherwise. Predicates goal/1 never calls are absent
    (their modes are inferred from the clauses)."""
    import json
    import subprocess
    import tempfile
    with tempfile.TemporaryDirectory() as tmp:
        out = Path(tmp) / "modes.json"
        try:
            subprocess.run(["swipl", "-q", str(COLLECT_MODES), "--", str(src), str(out)],
                           check=True, timeout=120, capture_output=True, text=True)
            data = json.loads(out.read_text(encoding="utf-8"))
        except (subprocess.SubprocessError, OSError, ValueError):
            return {}
    modes = {}
    for key, args in data.items():
        name, arity = key.rsplit("/", 1)
        if not any(a["ground"] + a["var"] + a["partial"] for a in args):
            continue
        def mode(a):
            if a["var"] == 0 and a["partial"] == 0:
                return "+"
            if a["partial"] == 0 and a["ground"] == 0 and a["exits"] and a["var_exit"] == a["exits"]:
                return "+"
            return "-"
        modes[(name, int(arity))] = [mode(a) for a in args]
    return modes


def _void_loop_accumulators(grouped, modes_map, measures_map) -> None:
    """In a loop over a list (a clause [X|T] at k whose last goal is the
    recursive call with T at k), an integer input that changes from one
    iteration to the next (a value accumulator: sum, found value) gets the
    measure void instead of int: with a size of its own the time is a
    recurrence in two sizes, which CasLog does not solve. Lists threaded
    through the loop (a table updated at each step) keep their length: their
    size does not grow, and the cost of the steps depends on it. (List
    accumulators that grow were already made structural.)"""
    from src.cleaning.loops.rewrite import _cons
    from src.utils.prolog import parse_call
    for key, preds in grouped.items():
        name, arity = key
        for _, args, body in preds:
            goals = [g.strip() for g in split_top_level(body)] if isinstance(body, str) and body.strip() else []
            if not goals:
                continue
            last = parse_call(goals[-1])
            if not last or last[0] != name or len(last[1]) != arity:
                continue
            ks = [k for k in range(arity) if (c := _cons(args[k])) and last[1][k] == c[1]]
            if not ks:
                continue
            for j in range(arity):
                if j in ks or modes_map[key][j] != "+":
                    continue
                if last[1][j].strip() != args[j].strip() and measures_map[key][j] == "int":
                    measures_map[key][j] = "void"


def _keep_exercised(text: str, observed: dict) -> tuple[str, list[str]]:
    """Keep the predicates goal/1 runs (when modes were observed at all): the
    others have no observed modes, and a wrong guess stops CasLog on the whole
    file. They are listed in a comment of the annotated file."""
    if not observed:
        return text, []
    from src.utils.prolog import parse_call, split_head_body
    kept, dropped = [], set()
    for clause in _split_source_clauses(text):
        head, _ = split_head_body(clause)
        call = parse_call(head.strip())
        key = (call[0], len(call[1])) if call else (head.strip(), 0)
        if not clause.strip() or clause.lstrip().startswith(":-") or key in observed:
            kept.append(clause)
        else:
            dropped.add(f"{key[0]}/{key[1]}")
    return "".join(kept).lstrip(), sorted(dropped)


def annotate(src: Path, dst: Path, hints: dict | None = None) -> list[str]:
    """Annotate ``src`` into ``dst`` and return generated directive strings.

    The list accumulators of the loops are first made structural
    (src/annotation/accumulators.py: same sizes and costs, CasLog input only),
    then the modes are observed on goal/1."""
    import tempfile
    from src.annotation.accumulators import process_file as structural_accumulators
    with tempfile.TemporaryDirectory() as tmp:
        prepared = Path(tmp) / src.name
        structural_accumulators(src, prepared)
        observed = observed_modes(prepared)
        text = remove_execution_predicates(prepared.read_text())
    text, unexercised = _keep_exercised(text, observed)
    parsed = parse_clauses(text)
    forced_outputs, forced_lengths = _normalize_hints(hints)

    grouped: dict[tuple[str, int], list[tuple[str, list[str], str]]] = defaultdict(list)
    order: list[tuple[str, int]] = []
    seen: set[tuple[str, int]] = set()
    for nm, args, body in parsed:
        key = (nm, len(args))
        grouped[key].append((nm, args, body))
        if key not in seen:
            seen.add(key)
            order.append(key)

    known = set(grouped.keys())

    modes_map: dict[tuple[str, int], list[str]] = {}
    evidence_map: dict[tuple[str, int], list[set[str]]] = {}
    for key in order:
        name, arity = key
        preds = grouped[key]
        modes = infer_modes(name, arity, preds)
        for p in forced_outputs.get(key, ()):
            if 0 <= p < arity:
                modes[p] = "-"
        modes_map[key] = modes
        ev = _collect_evidence(name, arity, preds)
        ev = _share_by_variable(name, arity, preds, ev)
        evidence_map[key] = ev

    # modes observed on the scenario replace the syntactic guess
    for key, modes in observed.items():
        if key in modes_map and len(modes) == len(modes_map[key]):
            modes_map[key] = list(modes)

    measures_map: dict[tuple[str, int], list[str]] = {
        key: _finalize_measures(key[0], evidence_map[key]) for key in order
    }

    # Mode backward propagation fixpoint
    for _ in range(20):
        changed = False
        for key in order:
            name, arity = key
            if key in observed:
                continue
            preds = grouped[key]
            for nm, args, body in preds:
                if nm != name:
                    continue
                var_pos: dict[str, list[int]] = defaultdict(list)
                for i, raw in enumerate(args):
                    if i >= arity:
                        break
                    a = raw.strip()
                    if VAR_RE.match(a) and a != "_":
                        var_pos[a].append(i)
                for cname, cargs in _find_body_calls(body, known):
                    cm = modes_map.get((cname, len(cargs)))
                    if cm is None:
                        continue
                    for i, raw in enumerate(cargs):
                        if i >= len(cm):
                            break
                        a = raw.strip()
                        if not (VAR_RE.match(a) and a != "_"):
                            continue
                        if cm[i] != "-":
                            continue
                        for hp in var_pos.get(a, []):
                            if modes_map[key][hp] != "-":
                                modes_map[key][hp] = "-"
                                changed = True
        if not changed:
            break

    # Seed forced length hints before measure fixpoint
    for key, positions in forced_lengths.items():
        if key not in evidence_map:
            continue
        for p in positions:
            if 0 <= p < len(evidence_map[key]):
                evidence_map[key][p].add("length")
    measures_map = {
        key: _finalize_measures(key[0], evidence_map[key]) for key in order
    }

    # Measure fixpoint: propagate callee measures to caller head positions
    for _ in range(20):
        changed = False
        for key in order:
            name, arity = key
            preds = grouped[key]
            for nm, args, body in preds:
                if nm != name:
                    continue
                var_pos: dict[str, list[int]] = defaultdict(list)
                for i, raw in enumerate(args):
                    if i >= arity:
                        break
                    for v in _vars_in(raw):
                        var_pos[v].append(i)
                for cname, cargs in _find_body_calls(body, known):
                    cm = measures_map.get((cname, len(cargs)))
                    if cm is None:
                        continue
                    for i, raw in enumerate(cargs):
                        if i >= len(cm):
                            break
                        a = raw.strip()
                        if not (VAR_RE.match(a) and a != "_"):
                            continue
                        positions = var_pos.get(a)
                        if not positions:
                            continue
                        m = cm[i]
                        if m == "void":
                            continue
                        for hp in positions:
                            if m not in evidence_map[key][hp]:
                                evidence_map[key][hp].add(m)
                                changed = True
            new_m = _finalize_measures(name, evidence_map[key])
            if new_m != measures_map[key]:
                measures_map[key] = new_m
                changed = True
        if not changed:
            break

    # Apply forced length hints after fixpoint (override _finalize_measures blanking)
    for key, positions in forced_lengths.items():
        if key not in measures_map:
            continue
        for p in positions:
            if 0 <= p < len(measures_map[key]):
                measures_map[key][p] = "length"

    _void_loop_accumulators(grouped, modes_map, measures_map)

    directives: list[str] = []
    for key in order:
        name, arity = key
        modes = modes_map[key]
        measures = measures_map[key]
        directives.append(
            f":- mode({name}/{arity}, [{', '.join(modes)}]).\n"
            f":- measure({name}/{arity}, [{', '.join(measures)}]).\n"
        )

    note = (f"% Not run by goal/1, not analysed: {', '.join(unexercised)}\n\n"
            if unexercised else "")
    out = note + "\n".join(directives) + "\n\n" + text
    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_text(out)
    return directives


def _run_defaults() -> None:
    """Annotate all files from ``build/normalized`` into ``build/annotated``."""
    pipeline_root = Path(__file__).resolve().parents[3]
    src_dir = pipeline_root / "build" / "normalized"
    out_dir = pipeline_root / "build" / "annotated"
    sources = sorted(src_dir.glob("*.pl"))
    if not sources:
        print(f"[ERR] no .pl files found in {src_dir}")
        return
    for src in sources:
        dst = out_dir / src.name
        directives = annotate(src, dst)
        demote_fixpoint(dst)
        print(f"[OK] {src.name}  ({len(directives)} directives)  -> {dst}")


def main() -> int:
    """CLI wrapper for manual annotation/debugging."""
    argv = sys.argv[1:]
    if not argv:
        _run_defaults()
        return 0
    if len(argv) == 2:
        src, dst = Path(argv[0]), Path(argv[1])
        annotate(src, dst)
        demote_fixpoint(dst)
        return 0
    print("Usage: python -m src.annotation.annotate [<in.pl> <out.pl>]")
    return 1


if __name__ == "__main__":
    sys.exit(main())
