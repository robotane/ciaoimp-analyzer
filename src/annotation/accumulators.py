"""List accumulators -> structural recursion (CasLog input only).

The loops of Ciao 1.25 build a list with an accumulator: in canonical form
(src/cleaning/loops)

    p(Acc, Out, [X|T], ...) :- ..., s(..., Acc, ..., Acc1), p(Acc1, Out, T, ...).
    p(A, A, [], ...).

where every clause of the step s returns ``Acc1 = [E|Acc]``. The size of Acc
grows while the size of the list decreases: a recurrence in two sizes, which
CasLog does not solve (inf). The older Ciao built the list structurally. This
pass rewrites the loop into

    p(Acc, [E|R], [X|T], ...) :- ..., s_elem(..., E), p(Acc, R, T, ...).
    p(A, A, [], ...).

with s_elem the step returning the element only. The output has the same
length (length of the list + length of the initial Acc) and every goal is run
the same number of times, so sizes and costs are unchanged; only the order of
the elements of the output differs (the accumulator reversed it). The pass is
therefore applied to the CasLog input only, not to build/normalized.
"""
from __future__ import annotations

import sys
from pathlib import Path

from src.cleaning.loops.rewrite import Program, _cons, _vars
from src.utils.prolog import is_variable, parse_call, serialize_call


def _step_positions(prog: Program, name: str, n: int) -> list[tuple[int, int]]:
    """(acc position, out position) pairs where every clause of name/n has
    out = [E|V] with V the variable at acc (and V nowhere else in the head)."""
    cls = list(prog.clauses((name, n)))
    if not cls:
        return []
    pairs = None
    for c in cls:
        found = set()
        for o, a in enumerate(c["args"]):
            cons = _cons(a)
            if not cons:
                continue
            counts = _vars(serialize_call(c["name"], c["args"]) + " " + " ".join(c["body"] or []))
            for i, b in enumerate(c["args"]):
                if i != o and b == cons[1] and counts[b] == 2:
                    found.add((i, o))
        pairs = found if pairs is None else pairs & found
    return sorted(pairs or [])


def rewrite(prog: Program) -> list[str]:
    done = []
    keys = sorted({(c["name"], len(c["args"])) for c in prog.clauses()})
    existing = {k[0] for k in keys}
    for name, n in keys:
        cls = list(prog.clauses((name, n)))
        if len(cls) != 2 or (name, n) in prog.protected() or prog.nested_use(name, n):
            continue
        rec, base = [c for c in cls if c["body"]], [c for c in cls if not c["body"]]
        if len(rec) != 1 or len(base) != 1:
            continue
        rec, base = rec[0], base[0]
        last = parse_call(rec["body"][-1])
        if not last or last[0] != name or len(last[1]) != n:
            continue
        hit = None
        for k in range(n):
            cons = _cons(rec["args"][k])
            if not cons or last[1][k] != cons[1] or base["args"][k] != "[]":
                continue
            for i in range(n):
                v = base["args"][i]
                outs = [o for o in range(n) if o != i and base["args"][o] == v]
                if not is_variable(v) or v == "_" or len(outs) != 1:
                    continue
                o = outs[0]
                acc, out = rec["args"][i], rec["args"][o]
                if not (is_variable(acc) and is_variable(out) and last[1][o] == out):
                    continue
                acc1 = last[1][i]
                # the goal of the body that turns acc into acc1
                for gi, g in enumerate(rec["body"][:-1]):
                    call = parse_call(g)
                    if not call or acc1 not in call[1] or acc not in call[1]:
                        continue
                    si, so = call[1].index(acc), call[1].index(acc1)
                    if (si, so) not in _step_positions(prog, call[0], len(call[1])):
                        continue
                    counts = _vars(serialize_call(name, rec["args"]) + " " + " ".join(rec["body"]))
                    # acc: head, step, nowhere else; acc1: step, recursive call
                    if counts[acc] != 2 or counts[acc1] != 2:
                        continue
                    hit = (k, i, o, gi, call, si, so)
                    break
                if hit:
                    break
            if hit:
                break
        if not hit:
            continue
        k, i, o, gi, (sname, sargs), si, so = hit
        # step returning the element only
        elem = f"{sname}_elem"
        while elem in existing:
            elem += "_"
        existing.add(elem)
        new_step = []
        for c in prog.clauses((sname, len(sargs))):
            e, _ = _cons(c["args"][so])
            args = [a for j, a in enumerate(c["args"]) if j not in (si, so)] + [e]
            new_step.append({"name": elem, "args": args,
                             "body": list(c["body"]) if c["body"] else None})
        used = _vars(serialize_call(name, rec["args"]) + " " + " ".join(rec["body"]))
        ev, rv = "Elem", "Rest"
        while ev in used:
            ev += "_"
        while rv in used:
            rv += "_"
        acc = rec["args"][i]
        step_args = [a for j, a in enumerate(sargs) if j not in (si, so)] + [ev]
        rec["body"][gi] = serialize_call(elem, step_args)
        rargs = list(last[1])
        rargs[i] = acc
        rargs[o] = rv
        rec["body"][-1] = serialize_call(name, rargs)
        rec["args"][o] = f"[{ev}|{rv}]"
        # keep the new predicate next to the loop
        at = prog.items.index(base) + 1
        prog.items[at:at] = new_step
        if not any(m == sname and len(a) == len(sargs) for _, _, m, a in prog.calls()):
            prog.items = [c for c in prog.items
                          if not ("name" in c and (c["name"], len(c["args"])) == (sname, len(sargs)))]
        done.append(f"{name}/{n}: accumulator at argument {i + 1} -> output {o + 1} built "
                    f"structurally (step {sname}/{len(sargs)} -> {elem}/{len(step_args)})")
    return done


def process_file(src: Path, dst: Path) -> list[str]:
    prog = Program(src.read_text(encoding="utf-8"))
    done = rewrite(prog)
    dst.write_text(prog.text(), encoding="utf-8")
    return done


if __name__ == "__main__":
    for line in process_file(Path(sys.argv[1]), Path(sys.argv[2])):
        print(line)
