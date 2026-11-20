#!/usr/bin/env python3
"""Worst-case CPU+RAM gas of methods of the INSTRUMENTED Takamaka jar (javap -c -p output).

Hotmoka instrumentation (io-hotmoka-instrumentation AddGasUpdates) inserts, at the start of
each basic block, Runtime.chargeN() / Runtime.charge(int) (CPU), and before each invoke/new,
Runtime.chargeForRAMN() / chargeForRAM(int) (RAM). The gas of an execution is the sum of these
charges along the executed path, plus the charges of the callees.

wc(method) = max over acyclic paths of the method (exception edges ignored: an exception aborts
the transaction) of (own charges + wc(callee) for each call). Virtual calls to an abstract
method take the max over the implementations given in IMPLS. Recursive calls (same method)
contribute 0 and are counted, so that wc gives the cost of ONE recursion level.
Takamaka.charge(long) adds its argument, which is a BigInteger.bitLength(): bounded by BITLEN.
Calls outside the analysed classes (java.*, Runtime.*) cost nothing beyond the call-site charges
(Runtime is not instrumented; java.* code is not charged).
Usage: wcet_gas.py <javap dir> [method ...]"""
import re, sys
from functools import lru_cache
from pathlib import Path

import os
BITLEN = int(os.environ.get("BITLEN", "256"))
# calls to these methods cost 0 (frame-only cost of recursive procedures); counted in rec
EXCL = set(filter(None, os.environ.get("EXCL", "").split(",")))
D = Path(sys.argv[1])
METH = re.compile(r"^  (?:[\w$<>\[\].,]+ )*?([\w$<>§.]+)\((.*?)\)(?: throws .*)?;$")
INS = re.compile(r"^\s+(\d+): (\w+)\s*(.*)$")
methods = {}          # (cls, name) -> list of variants (each: list of (off, op, arg))
for f in sorted(D.glob("*.txt")):
    cls = f.stem.replace(".", "/")
    cur = None
    for line in f.read_text().splitlines():
        m = METH.match(line)
        if m and "Code" not in line:
            cur = []
            nm = m.group(1)
            if nm.replace(".", "/") == cls or nm == cls.replace("/", "."):
                nm = "<init>"
            methods.setdefault((cls, nm), []).append((m.group(2), cur))
            continue
        i = INS.match(line)
        if i and cur is not None:
            cur.append((int(i.group(1)), i.group(2), i.group(3)))

BR = re.compile(r"^(if\w*|goto|goto_w)$")
CALL = re.compile(r"// (?:Interface)?Method (?:([\w/$]+)\.)?(\"?[\w$<>§]+\"?):\((.*?)\)")

def charges(op, arg, prev):
    m = re.search(r"Runtime\.charge(ForRAM)?(\d*):\((.?)\)", arg)
    if op == "invokestatic" and m:
        val = int(m.group(2)) if m.group(2) else int(prev)
        return (0, val) if m.group(1) else (val, 0)
    return None

PRIM = dict(Z="boolean", B="byte", C="char", S="short", I="int", J="long", F="float", D="double", V="void")
def jvm2src(d):
    out, i = [], 0
    while i < len(d):
        dims = 0
        while d[i] == "[":
            dims += 1; i += 1
        if d[i] == "L":
            j = d.index(";", i); t = d[i + 1:j].replace("/", "."); i = j + 1
        else:
            t = PRIM[d[i]]; i += 1
        out.append(t + "[]" * dims)
    return ", ".join(out)

def impls(cls, name, desc):
    """methods with code reachable by a call cls.name(desc): the method itself if concrete,
    plus the overriding methods of the classes of the same family (outer class and its nested ones)"""
    fam = cls.split("$")[0]
    out = []
    for (c, n), vs in methods.items():
        if n == name and (c == fam or c.startswith(fam + "$")) and any(d == desc and code for d, code in vs):
            if c == cls or (c, n) != (cls, n):
                out.append(c)
    return out

def ev(cls, name, desc_hint=None, stack=()):
    best = (0, 0, 0)
    for desc, code in methods.get((cls, name), []):
        if desc_hint is not None and desc != desc_hint:
            continue
        r = path_cost(cls, name, desc, stack)
        best = max(best, r, key=lambda t: t[0] + t[1])
    return best

@lru_cache(maxsize=None)
def path_cost(cls, name, desc, stack=()):
    code = dict((d, c) for d, c in methods[(cls, name)])[desc]
    offs = [o for o, _, _ in code]
    idx = {o: k for k, o in enumerate(offs)}
    memo = {}
    def go(k, seen):
        if k >= len(code):
            return (0, 0, 0)
        if k in memo:
            return memo[k]
        off, op, arg = code[k]
        cpu = ram = rec = 0
        prevval = code[k - 1][2].split()[0] if k and code[k - 1][1] in ("bipush", "sipush", "ldc", "ldc_w") else (
            code[k - 1][1].split("_")[-1] if k and code[k - 1][1].startswith("iconst_") else "0")
        c = charges(op, arg, prevval if prevval.lstrip("-").isdigit() else "0")
        if c:
            cpu, ram = c
        elif op.startswith("invoke"):
            m = CALL.search(arg)
            if m:
                ccls = m.group(1) or cls
                cname = m.group(2).strip('"')
                cdesc = m.group(3)
                if ccls == "io/takamaka/code/lang/Takamaka" and cname == "charge":
                    cpu += 1 + BITLEN
                else:
                    sdesc = jvm2src(cdesc)
                    if op in ("invokespecial", "invokestatic"):
                        cands = [ccls] if any(d == sdesc and cc for d, cc in methods.get((ccls, cname), [])) else []
                    else:
                        cands = impls(ccls, cname, sdesc)
                    if (ccls, cname, sdesc) == (cls, name, desc) or cname in EXCL:
                        rec = 1
                    elif cands:
                        sub = max((path_cost(c2, cname, sdesc) for c2 in cands), key=lambda t: t[0] + t[1])
                        cpu += sub[0]; ram += sub[1]
        succ = []
        if op in ("ireturn", "areturn", "return", "lreturn", "athrow", "dreturn", "freturn"):
            succ = []
        elif BR.match(op):
            tgt = int(arg.split()[0])
            succ = [idx[tgt]] + ([] if op.startswith("goto") else [k + 1])
        elif op in ("tableswitch", "lookupswitch"):
            raise SystemExit("switch not handled")
        else:
            succ = [k + 1]
        best = (0, 0, 0)
        for s in succ:
            if s <= k:     # back edge: loops are handled by hand (per-iteration cost)
                continue
            r = go(s, seen)
            if r[0] + r[1] > best[0] + best[1]:
                best = r
        res = (cpu + best[0], ram + best[1], rec + best[2])
        memo[k] = res
        return res
    return go(0, frozenset())

if __name__ == "__main__":
    for spec in sys.argv[2:]:
        spec0, _, d0 = spec.partition("|")
        cls, name = spec0.rsplit(".", 1)
        name = name + ("|" + d0 if d0 else "")
        name, _, desc = name.partition("|")
        cls = cls.replace(".", "/")
        descs = [d for d, c in methods[(cls, name)] if c and (not desc or d == desc)]
        for d in descs:
            r = path_cost(cls, name, d)
            print(f"{spec} ({d}): cpu={r[0]} ram={r[1]} total={r[0]+r[1]} recursive_calls_on_path={r[2]}")
        continue
        print(f"{spec}: cpu={r[0]} ram={r[1]} total={r[0]+r[1]} recursive_calls_on_path={r[2]}")
