"""Generated CiaoPP cost specs: module declaration, regtypes and entries.

The hand-written specs of data/ciaopp_cost/specs* give, for each contract, the
operations to analyse and the types of their arguments. This module derives
both from the contract itself, with no per-contract knowledge:

1. ``collect_calls.pl`` runs the body of ``goal/1`` (the test scenario every
   contract has) one goal at a time and records the shape of the arguments of
   each call (var, int, atm, list of shapes, struct of shapes).
2. The operations are the predicates called by ``goal/1`` that are neither
   builtins nor primitives of the cost model (``blockchain.pl``).
3. The shapes of all the calls of an operation are generalised (least upper
   bound) into regular types: one regtype per functor, one list regtype per
   element type. A list type equal to (or included in) a table type of the
   cost model (e.g. ``balances``) takes its name, so the trusted costs of the
   primitives apply. Arguments unbound at the call are ``var``; calls with
   different unbound arguments give separate entries.

Usage: python3 -m src.ciaopp_cost.genspec CONTRACT.pl MODEL_DIR OUT.pl [EXECUTABLE.pl]
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

from src.ciaopp_cost import primitives_of

HERE = Path(__file__).resolve().parent
COLLECT = HERE / "collect_calls.pl"
SCALARS = {"int", "flt", "atm"}
# Order of the scalar lattice: int, flt < num; num, atm < gnd < term.
_SCALAR_LUB = {frozenset({"int", "flt"}): "num"}


# --- Shapes and their least upper bound ---------------------------------

def norm(s):
    """JSON shape -> internal type: scalar str, ('list', T|None), ('struct', F, [T])."""
    if isinstance(s, str):
        return s
    if "list" in s:
        elem = None
        for e in s["list"]:
            elem = lub(elem, norm(e))
        return ("list", elem)
    return ("struct", s["struct"], [norm(a) for a in s["args"]])


def ground(t) -> bool:
    if t is None:
        return True
    if isinstance(t, str):
        return t not in ("var", "term")
    if t[0] == "list":
        return ground(t[1])
    return all(ground(a) for a in t[2])


def lub(a, b):
    """Least upper bound; None and "var" (an unbound place: nothing observed)
    are the bottom."""
    if a is None or a == "var":
        return b
    if b is None or b == "var" or a == b:
        return a
    if isinstance(a, str) and isinstance(b, str):
        if "term" in (a, b):
            return "term"
        if a in ("num", "flt", "int") and b in ("num", "flt", "int"):
            return "num"
        return "gnd"
    if not isinstance(a, str) and not isinstance(b, str):
        if a[0] == b[0] == "list":
            return ("list", lub(a[1], b[1]))
        if a[0] == b[0] == "struct" and a[1] == b[1] and len(a[2]) == len(b[2]):
            return ("struct", a[1], [lub(x, y) for x, y in zip(a[2], b[2])])
    return "gnd" if ground(a) and ground(b) else "term"


# --- Table types of the cost model --------------------------------------

LIST_RE = re.compile(r"^(\w+)\(\[(\w+)\|(\w+)\]\)\s*:-\s*(\w+)\(\2\),\s*\1\(\3\)\.", re.M)
ELEM_RE = re.compile(r"^(\w+)\((\w+)\(([^)]*)\)\)\s*:-\s*([^.]*)\.", re.M)


def library_tables(gas_model: Path) -> list[tuple[str, tuple]]:
    """[(list regtype name, ('struct', F, [types]))] of the cost model package."""
    text = gas_model.read_text(encoding="utf-8")
    elems = {}
    for name, functor, args, body in ELEM_RE.findall(text):
        vars_ = [a.strip() for a in args.split(",")]
        types = {v: t for t, v in re.findall(r"(\w+)\((\w+)\)", body)}
        if all(v in types for v in vars_):
            elems[name] = ("struct", functor, [types[v] for v in vars_])
    return [(lst, elems[el]) for lst, el, _ in
            [(m[0], m[3], m[1]) for m in LIST_RE.findall(text)] if el in elems]


def included(t, lib) -> bool:
    """Is the type t included in the library type lib (scalars int < num < gnd...)?"""
    if t is None:
        return True
    if isinstance(lib, str):
        if lib == t or lib == "term":
            return True
        if lib == "gnd":
            return ground(t)
        if lib == "num":
            return t in ("int", "flt", "num")
        return False
    if isinstance(t, str):
        return False
    if t[0] != lib[0]:
        return False
    if t[0] == "list":
        return included(t[1], lib[1])
    return t[1] == lib[1] and len(t[2]) == len(lib[2]) and all(
        included(x, y) for x, y in zip(t[2], lib[2]))


# --- Spec writer ---------------------------------------------------------

class Spec:
    def __init__(self, tables, taken: set[str]):
        self.tables = tables
        self.taken = set(taken)
        self.structs: dict[tuple[str, int], tuple] = {}   # (F, N) -> lub type
        self.names: dict = {}                              # key -> regtype name
        self.defs: list[str] = []

    def gather(self, t):
        """First pass: one lub per functor, over every occurrence."""
        if t is None or isinstance(t, str):
            return
        if t[0] == "list":
            self.gather(t[1])
            return
        key = (t[1], len(t[2]))
        self.structs[key] = lub(self.structs.get(key), t)
        for a in t[2]:
            self.gather(a)

    def resolve(self, t):
        """Replace each struct by the lub of its functor."""
        if t is None or isinstance(t, str):
            return t
        if t[0] == "list":
            return ("list", self.resolve(t[1]))
        full = self.structs[(t[1], len(t[2]))]
        return ("struct", full[1], [self.resolve(a) if not isinstance(a, str) else a
                                    for a in full[2]])

    def fresh(self, base: str) -> str:
        name, i = base, 2
        while name in self.taken:
            name, i = f"{base}{i}", i + 1
        self.taken.add(name)
        return name

    def prop(self, t) -> str:
        """Name of the unary property of type t (defining regtypes on the way)."""
        if t is None or t == "var":
            return "term"
        if isinstance(t, str):
            return {"flt": "flt", "int": "int", "atm": "atm"}.get(t, t)
        key = repr(t)
        if key in self.names:
            return self.names[key]
        if t[0] == "list":
            if t[1] is None or t[1] == "var":
                # a table that stays empty in the scenario: ground data
                t = ("list", "gnd")
                key = repr(t)
                if key in self.names:
                    return self.names[key]
            for lib, elem in self.tables:
                if included(t[1], elem):
                    self.names[key] = lib
                    return lib
            elem = self.prop(t[1])
            name = self.fresh(f"{elem}_list")
            self.names[key] = name
            self.defs += [f":- regtype {name}/1.", f"{name}([]).",
                          f"{name}([X|T]) :- {elem}(X), {name}(T).", ""]
            return name
        name = self.fresh(f"{t[1]}_t")
        self.names[key] = name
        vs = [f"A{i}" for i in range(1, len(t[2]) + 1)]
        props = [self.prop(a) for a in t[2]]
        body = ", ".join(f"{p}({v})" for p, v in zip(props, vs)) or "true"
        head = f"{t[1]}({', '.join(vs)})" if vs else t[1]
        self.defs += [f":- regtype {name}/1.", f"{name}({head}) :- {body}.", ""]
        return name


def defined_unary(contract: Path) -> set[str]:
    return set(re.findall(r"^([a-z]\w*)\([^(),]*\)\s*(?::-|\.)", contract.read_text(encoding="utf-8"), re.M))


def collect(contract: Path) -> list[dict]:
    with tempfile.TemporaryDirectory() as tmp:
        out = Path(tmp) / "calls.json"
        subprocess.run(["swipl", "-q", str(COLLECT), "--", str(contract), str(out)],
                       check=True, timeout=60, capture_output=True, text=True)
        return json.loads(out.read_text(encoding="utf-8"))


def families(calls: list[dict]) -> dict[tuple[str, int], object]:
    """Type of each argument position (pred, i): lub of the values seen there,
    before and after the calls, and at every position linked to it by a
    variable of goal/1 (the output of a call passed to a later call). An empty
    table at the first call thus gets the type of its later contents."""
    parent: dict = {}

    def find(x):
        parent.setdefault(x, x)
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    by_var: dict[int, tuple] = {}
    for c in calls:
        for i, v in enumerate(c["vars"]):
            key = (c["pred"], i)
            find(key)
            if v >= 0:
                if v in by_var:
                    parent[find(key)] = find(by_var[v])
                else:
                    by_var[v] = key
    types: dict = {}
    for c in calls:
        for i, (pre, post) in enumerate(zip(c["args"], c["post"])):
            root = find((c["pred"], i))
            for s in (pre, post):
                t = norm(s)
                if t != "var":
                    types[root] = lub(types.get(root), t)
    return {k: types.get(find(k)) for k in parent}


def head_arities(contract: Path) -> dict[str, set[int]]:
    """Arities of the predicates defined in a plain Prolog file."""
    from src.utils.prolog import split_clauses, split_head_body, parse_call
    out: dict[str, set[int]] = {}
    for c in split_clauses(contract.read_text(encoding="utf-8")):
        if c.lstrip().startswith(":-"):
            continue
        call = parse_call(split_head_body(c)[0])
        if call:
            out.setdefault(call[0], set()).add(len(call[1]))
    return out


def unexercised(contract: Path) -> list[str]:
    """Predicates of the contract that nothing calls and goal/1 does not reach:
    operations the scenario never runs (no types can be observed for them)."""
    from src.utils.prolog import split_clauses, split_head_body, parse_call
    calls: dict[str, set[str]] = {}
    for c in split_clauses(contract.read_text(encoding="utf-8")):
        if c.lstrip().startswith(":-"):
            continue
        head, body = split_head_body(c)
        call = parse_call(head)
        if call:
            calls.setdefault(call[0], set()).update(re.findall(r"\b([a-z]\w*)\(", " ".join(map(str, body or [])) if not isinstance(body, str) else body))
    called = set().union(*calls.values()) if calls else set()
    return sorted(p for p in calls if p != "goal" and p not in called)


def signatures(calls: list[dict], prims: set[str], spec: "Spec", unwrap: bool):
    """{(pred, arity): {mask: [type]}} of the operations. With ``unwrap``, an
    argument whose type is a state wrapper (state(...), *_state(...), the
    convention of the destate stage) is replaced by its fields, as destate
    does to go from build/executable to build/normalized."""
    from src.cleaning.destate.core import is_wrapper_name
    fam = families(calls)
    for k in fam:
        spec.gather(fam[k])
    ops: dict = {}
    for c in calls:
        if c["pred"] in prims:
            continue
        mask, types = [], []
        for i, a in enumerate(c["args"]):
            t = spec.resolve(fam[(c["pred"], i)])
            if unwrap and isinstance(t, tuple) and t[0] == "struct" and is_wrapper_name(t[1]):
                fields = a["args"] if isinstance(a, dict) and "args" in a else [a] * len(t[2])
                mask += [f == "var" for f in fields]
                types += t[2]
            else:
                mask.append(a == "var")
                types.append(t)
        ops.setdefault((c["pred"], len(types)), {})[tuple(mask)] = types
    return ops


def generate(contract: Path, model_dir: Path, typed_from: Path | None = None) -> str:
    """Spec of ``contract``. ``typed_from``: the same contract before destate
    (build/executable), run instead of ``contract`` so that the state wrapper
    gathers every value of each field (an empty table at the first call gets
    the type of its later contents); its operations are unwrapped and must
    match the arities of ``contract``, otherwise ``contract`` itself is run."""
    prims = primitives_of(model_dir / "blockchain.pl")
    tables = library_tables(model_dir / "gas_model.pl")
    builtin = {"int", "atm", "num", "flt", "gnd", "term", "list", "var", "nnegint"}
    taken = defined_unary(contract) | builtin | {lib for lib, _ in tables}
    arities = head_arities(contract)
    ops = None
    if typed_from is not None:
        spec = Spec(tables, taken)
        ops = signatures(collect(typed_from), prims, spec, unwrap=True)
        if any(n not in arities.get(p, ()) for p, n in ops):
            ops = None
    if ops is None:
        spec = Spec(tables, taken)
        ops = signatures(collect(contract), prims, spec, unwrap=False)

    missing = unexercised(contract)
    if missing:
        print(f"  WARN {contract.stem}: not called by goal/1, no entry: {', '.join(missing)}",
              file=sys.stderr)
    entries = [f"% Not called by goal/1 (no entry, types unknown): {', '.join(missing)}"] if missing else []
    for (pred, n), pats in ops.items():
        for mask in sorted(pats):
            vs = [f"A{i}" for i in range(1, n + 1)]
            props = ["var" if m else spec.prop(t) for m, t in zip(mask, pats[mask])]
            entries.append(f":- entry {pred}({', '.join(vs)}) :\n    ("
                           + ", ".join(f"{p}({v})" for p, v in zip(props, vs)) + ").")
    exports = ", ".join(f"{p}/{n}" for p, n in ops) + ", goal/1"
    src = contract.name + (f" (types from {typed_from.parent.name}/{typed_from.name})" if typed_from else "")
    head = [f"% Generated by src/ciaopp_cost/genspec.py from {src}, calls of goal/1.", "",
            f":- module(_, [{exports}],",
            "          [assertions, nativeprops, regtypes, resdefs, .(gas_model)]).", ""]
    return "\n".join(head + spec.defs + entries + [":- entry goal(R) : var(R).", ""])


def main(argv: list[str]) -> int:
    contract, model_dir, out = map(Path, argv[:3])
    typed_from = Path(argv[3]) if len(argv) > 3 else None
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(generate(contract, model_dir, typed_from), encoding="utf-8")
    print(out)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
