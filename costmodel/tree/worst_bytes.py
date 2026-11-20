#!/usr/bin/env python3
"""Exact bytes (Hotmoka marshalling, via UpdSize) of worst-case update sets:
 persistent: k new nodes forming a chain (connected subtree containing the root, as in any
   path copy), every key/value/external child an old object of a distinct transaction, every
   progressive >= 252 (3-byte encoding), size >= 254 (3-byte compact int), both RedNode and
   BlackNode classes present, root update of the map object (old object).
 mutable (insertion): k modified old nodes, each with every field an insertion can change
   (color, size, left, right; key and value never change in an insertion) changed, left/right to
   old objects of distinct transactions, + the new node, + root update of the map.
Prints bytes(k) for k = 1..K and the per-node increment."""
import subprocess, os, sys
# HARNESS: directory holding the compiled UpdSize.class (derive_arbre.py compiles it)
HARNESS = os.environ.get("HARNESS", "")
M = os.environ.get("HOTMOKA_MODULES") or sys.exit("set HOTMOKA_MODULES (see README.md)")
JAVA = os.path.join(os.environ.get("JAVA_HOME") or sys.exit("set JAVA_HOME to a JDK 21"), "bin", "java")
CP = f"{HARNESS}:{M}/explicit_or_automatic/*:{M}/unnamed/*"
SN = "io.takamaka.code.util.SnapshottableStorageTreeMap"; MU = "io.takamaka.code.util.StorageTreeMap"
O = "java.lang.Object"; P = int(os.environ.get("P", "40000")); SZ = int(os.environ.get("SZ", "100000"))

def persistent(k):
    N = SN + "$Node"; u = []
    for i in range(k):
        me = f"cur:{P + i}"
        u += [f"CT {me} {SN}${'RedNode' if i % 2 else 'BlackNode'} tk",
              f"ST {me} {N} key {O} key{i}:{P}", f"ST {me} {N} value {O} val{i}:{P}", f"IN {me} {N} size {SZ}",
              f"ST {me} {N} left {N} old{i}:{P}",
              (f"ST {me} {N} right {N} cur:{P + i + 1}" if i < k - 1 else f"ST {me} {N} right {N} oldr:{P}")]
    u.append(f"ST map:{P} {SN} root {N} cur:{P}")
    u.append(f"NU nul:{P} {N} left {N}")       # first-time cost of an UpdateToNull (same field signature)
    return u

def mutable(k):
    N = MU + "$Node"; u = []
    for i in range(k):
        me = f"node{i}:{P}"
        u += [f"BO {me} {N} color {'true' if i % 2 else 'false'}", f"IN {me} {N} size {SZ}",
              f"ST {me} {N} left {N} l{i}:{P}", f"ST {me} {N} right {N} r{i}:{P}"]
    me = f"cur:{P}"
    u += [f"CT {me} {N} tk", f"BO {me} {N} color false", f"ST {me} {N} key {O} keyn:{P}", f"ST {me} {N} value {O} valn:{P}",
          f"IN {me} {N} size 1", f"NU {me} {N} left {N}", f"NU {me} {N} right {N}", f"ST map:{P} {MU} root {N} node0:{P}"]
    return u

def sizes(gen, K):
    inp = "".join("\n".join(gen(k)) + "\nEND\n" for k in range(1, K + 1))
    out = subprocess.run([JAVA, "-cp", CP, "UpdSize"], input=inp, capture_output=True, text=True, check=True).stdout.split()  # nosemgrep: dangerous-subprocess-use-tainted-env-args (argument list, no shell, local JDK)
    return [int(x) for x in out[0::2]]

if __name__ == "__main__":
    for name, gen in (("persistent", persistent), ("mutable", mutable)):
        b = sizes(gen, 40)
        inc = sorted(set(b[i + 1] - b[i] for i in range(len(b) - 1)))
        print(name, "bytes(1..5):", b[:5], "bytes(40):", b[-1], "increments:", inc, "A =", b[0] - inc[-1])
