"""Canonical list loops and dead arguments.

Ciao 1.25 expands ``for (X in list(L)) { ... }`` (package loops) into a pair
of clauses with a cut and a catch-all base case that returns the rest of the
list in an extra argument:

    p(A, B, [X|T], R, G) :- !, ..., p(A1, B, T, R, G).
    p(A, A, L, L, _).

The rest ``R`` is always ``[]`` for a proper list, and the callers pass a
fresh variable for it. For a mode inference this is an input position bound
to an unbound variable (CasLog: "unbound input variable"); for a cost
analysis the two clauses are only exclusive through the cut. The older
expansion (``loop_aux_*``) had the canonical shape instead:

    p(A, B, [X|T], G) :- ..., p(A1, B, T, G).
    p(A, A, [], _).

``canonical_loops`` rewrites the first shape into the second: the base case
gets ``[]``, the cut (now useless: ``[]`` and ``[X|T]`` do not unify) is
removed, and the rest argument is dropped from the clauses and from the
calls. ``drop_dead_arguments`` then removes the argument positions that no
clause uses (a variable occurring once in the clause), which the expansion
leaves in the wrappers of the loops. Only the helpers are rewritten: the
predicates called by goal/1 and the predicates nothing calls (operations) keep
their arguments.

Nothing here depends on a contract: only on the shape of the clauses.
"""
from __future__ import annotations

import re
import sys
from collections import Counter
from pathlib import Path

from ...utils.prolog import (is_variable, parse_call, serialize_call,
                             split_clauses, split_head_body, split_top_level)

VAR_RE = re.compile(r"\b(?:_[A-Za-z0-9_]*|[A-Z][A-Za-z0-9_]*)\b")


def _vars(text: str) -> Counter:
    text = re.sub(r"'(?:[^'\\]|\\.)*'", "", text)
    return Counter(v for v in VAR_RE.findall(text))


def _cons(arg: str) -> tuple[str, str] | None:
    """[H|T] with T a variable -> (H, T)."""
    a = arg.strip()
    if not (a.startswith("[") and a.endswith("]")):
        return None
    parts = split_top_level(a[1:-1], "|")
    if len(parts) != 2 or not is_variable(parts[1].strip()):
        return None
    if len(split_top_level(parts[0], ",")) != 1:
        return None
    return parts[0].strip(), parts[1].strip()


class Program:
    def __init__(self, text: str):
        self.items: list[dict] = []
        for raw in split_clauses(text):
            if raw.lstrip().startswith(":-"):
                self.items.append({"directive": raw.strip()})
                continue
            head, body = split_head_body(raw)
            call = parse_call(head)
            if call is None:          # atom head (no arguments)
                call = (head.strip(), [])
            self.items.append({"name": call[0], "args": call[1], "body": body})

    def clauses(self, key=None):
        for c in self.items:
            if "name" in c and (key is None or (c["name"], len(c["args"])) == key):
                yield c

    def text(self) -> str:
        out = []
        for c in self.items:
            if "directive" in c:
                out.append(c["directive"])
                continue
            head = serialize_call(c["name"], c["args"]) if c["args"] else c["name"]
            if c["body"]:
                out.append(head + " :-\n    " + ",\n    ".join(c["body"]) + ".")
            else:
                out.append(head + ".")
        return "\n".join(out) + "\n"

    def calls(self):
        """(clause, index in body, name, args) of every top-level body goal."""
        for c in self.clauses():
            for i, g in enumerate(c["body"] or []):
                call = parse_call(g)
                if call:
                    yield c, i, call[0], call[1]

    def protected(self) -> set[tuple[str, int]]:
        """goal/1, the predicates it calls, and the predicates nothing calls."""
        keys = {(c["name"], len(c["args"])) for c in self.clauses()}
        called = {(n, len(a)) for _, _, n, a in self.calls()}
        goal_calls = {(n, len(a)) for c, _, n, a in self.calls() if c["name"] == "goal"}
        return {("goal", 1)} | goal_calls | (keys - called)

    def nested_use(self, name: str, n: int) -> bool:
        """Is name/n used anywhere but as a top-level body goal (inside a
        control construct, a directive, a meta-call)?"""
        top = sum(1 for _, _, m, a in self.calls() if m == name and len(a) == n)
        pat = re.compile(rf"(?<![\w']){re.escape(name)}\(")
        total = sum(len(pat.findall(g)) for c in self.clauses() for g in (c["body"] or []))
        total += sum(len(pat.findall(c["directive"])) for c in self.items if "directive" in c)
        return total != top

    def fresh_at_calls(self, name: str, n: int, j: int) -> bool:
        """Does every call of name/n pass a fresh variable at argument j?"""
        for c, _, m, args in self.calls():
            if m != name or len(args) != n:
                continue
            a = args[j]
            counts = _vars(serialize_call(c["name"], c["args"]) + " " + " ".join(c["body"] or []))
            if not (a == "_" or (is_variable(a) and counts[a] == 1)):
                return False
        return True

    def drop_position(self, name: str, n: int, j: int, bind_nil: bool) -> None:
        """Remove argument j of name/n from its clauses and calls. With
        ``bind_nil``, a call passing a term that is not a fresh variable gets
        ``Term = []`` after it (the value of the dropped output)."""
        for c in self.clauses((name, n)):
            del c["args"][j]
        for c in self.clauses():
            body = c["body"] or []
            new = []
            counts = _vars(serialize_call(c["name"], c["args"]) + " " + " ".join(body))
            for g in body:
                call = parse_call(g)
                if call and call[0] == name and len(call[1]) == n:
                    args = list(call[1])
                    passed = args.pop(j)
                    new.append(serialize_call(name, args))
                    fresh = passed == "_" or (is_variable(passed) and counts[passed] == 1)
                    if bind_nil and not fresh:
                        new.append(f"{passed} = []")
                else:
                    new.append(g)
            if c["body"] is not None:
                c["body"] = new


def canonical_loops(prog: Program) -> list[str]:
    done = []
    keys = sorted({(c["name"], len(c["args"])) for c in prog.clauses()})
    for name, n in keys:
        cls = list(prog.clauses((name, n)))
        if len(cls) != 2 or (name, n) in prog.protected() or prog.nested_use(name, n):
            continue
        rec, base = cls
        body = rec["body"] or []
        if not body or body[0] != "!" or base["body"] not in (None, ["true"]):
            continue
        last = parse_call(body[-1])
        if not last or last[0] != name or len(last[1]) != n:
            continue
        for k in range(n):
            cons = _cons(rec["args"][k])
            if not cons or last[1][k] != cons[1]:
                continue
            v = base["args"][k]
            if not is_variable(v) or v == "_":
                continue
            base_vars = _vars(serialize_call(name, base["args"]))
            js = [j for j in range(n) if j != k and base["args"][j] == v]
            if base_vars[v] != 2 or len(js) != 1:
                continue
            j = js[0]
            w = rec["args"][j]
            rec_vars = _vars(serialize_call(name, rec["args"]) + " " + " ".join(body))
            # the rest is passed through the recursion and used nowhere else
            if not is_variable(w) or last[1][j] != w or rec_vars[w] != 2:
                continue
            base["args"][k] = "[]"
            base["args"][j] = "[]"
            rec["body"] = body[1:]
            prog.drop_position(name, n, j, bind_nil=True)
            done.append(f"{name}/{n}: base case [] at argument {k + 1}, rest argument {j + 1} dropped")
            break
    return done


def drop_dead_arguments(prog: Program) -> list[str]:
    done = []
    changed = True
    while changed:
        changed = False
        keys = sorted({(c["name"], len(c["args"])) for c in prog.clauses()})
        prot = prog.protected()
        for name, n in keys:
            if (name, n) in prot or (name, n - 1) in keys or prog.nested_use(name, n):
                continue
            cls = list(prog.clauses((name, n)))
            for j in range(n):
                dead, nil_goals = True, []
                fresh_calls = prog.fresh_at_calls(name, n, j)
                for c in cls:
                    a = c["args"][j]
                    counts = _vars(serialize_call(c["name"], c["args"]) + " " + " ".join(c["body"] or []))
                    if a == "_" or (is_variable(a) and counts[a] == 1):
                        continue
                    # an output that only gets [] (left by canonical_loops),
                    # which no caller reads
                    nils = [g for g in (c["body"] or []) if g == f"{a} = []"]
                    if fresh_calls and is_variable(a) and nils and counts[a] == 1 + len(nils):
                        nil_goals.append((c, nils))
                        continue
                    dead = False
                    break
                if dead:
                    for c, nils in nil_goals:
                        c["body"] = [g for g in c["body"] if g not in nils] or None
                    prog.drop_position(name, n, j, bind_nil=False)
                    done.append(f"{name}/{n}: unused argument {j + 1} dropped")
                    changed = True
                    break
            if changed:
                break
    return done


def process_file(src: Path, dst: Path) -> dict:
    prog = Program(src.read_text(encoding="utf-8"))
    loops = canonical_loops(prog)
    dead = drop_dead_arguments(prog)
    dst.write_text(prog.text(), encoding="utf-8")
    return {"loops": loops, "dead_arguments": dead}


def main(argv: list[str]) -> int:
    stats = process_file(Path(argv[0]), Path(argv[1]))
    for line in stats["loops"] + stats["dead_arguments"]:
        print(line)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
