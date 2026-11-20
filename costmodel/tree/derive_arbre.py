#!/usr/bin/env python3
"""Safe (worst-case) constants of the tree primitives, derived from the code (see arbre_pire_cas.md).

Steps (all light: one JVM -Xmx1g at a time):
 1. instrument io-takamaka-code-1.8.1.jar with Hotmoka's own instrumentation (moka jars instrument),
    javap -c -p the tree classes;
 2. wcet_gas.py: worst-case CPU+RAM gas of each method frame (BITLEN = 63: BigInteger keys < 2^63);
 3. worst_bytes.py: exact bytes, with Hotmoka's marshalling, of the worst-case updates of k new
    (persistent) or modified (mutable) nodes: A + B*k;
 4. structural bounds (black height bh <= log2(n+1)):
      persistent put (new or existing key): new nodes k <= 2bh+1, recursion levels <= 2bh+1
      mutable put:                          modified old nodes <= 2bh, levels <= 2bh+1
      persistent remove:                    levels L <= 2bh+1, new nodes <= 2L
      get / contains:                       loop iterations <= 2bh
 5. constants = max(derived, previous value) for the intercepts (the previous intercepts are
    upper envelopes of microbenchmarks that also hold the caller's work), derived slopes.
Writes build/constants_moka_sur.json (from data/constants_moka.json) and prints the derivation;
compare it with data/constants_moka_sur.json.
Usage: derive_arbre.py [--out FILE]"""
import json, os, re, subprocess, sys, tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
# HOTMOKA_MODULES: the modules/ directory of Hotmoka 1.12.3 (io-hotmoka-docker/modules of the Hotmoka
# sources, or /modules of the image hotmoka/mokamint-node:1.12.3); JAVA_HOME: a JDK 21
M = Path(os.environ.get("HOTMOKA_MODULES") or sys.exit("set HOTMOKA_MODULES (see costmodel/tree/README.md)"))
JDK = Path(os.environ.get("JAVA_HOME") or sys.exit("set JAVA_HOME to a JDK 21"))
GAS_PER_BYTE = 80          # StandardGasCostModel.storageCostOfByte
CALL = 8 + 32 + 8 * 4      # call site in the caller: invoke (8 CPU) + activation record 32 + 4 slots * 8 (RAM)
BITLEN = 63
CLASSES = ["io.takamaka.code.util.StorageTreeMap", "io.takamaka.code.util.StorageTreeMap$Node",
           "io.takamaka.code.util.SnapshottableStorageTreeMap", "io.takamaka.code.util.SnapshottableStorageTreeMap$Node",
           "io.takamaka.code.util.SnapshottableStorageTreeMap$RedNode", "io.takamaka.code.util.SnapshottableStorageTreeMap$BlackNode",
           "io.takamaka.code.util.StorageTreeSet", "io.takamaka.code.util.StorageTreeSet$Node",
           "io.takamaka.code.util.SnapshottableStorageTreeSet", "io.takamaka.code.util.SnapshottableStorageTreeSet$Node",
           "io.takamaka.code.util.SnapshottableStorageTreeSet$RedNode", "io.takamaka.code.util.SnapshottableStorageTreeSet$BlackNode",
           "io.takamaka.code.lang.StorageSupport", "io.takamaka.code.math.BigIntegerSupport", "io.takamaka.code.lang.Storage",
           "io.takamaka.code.lang.Takamaka"]


def sh(cmd, **kw):
    return subprocess.run(cmd, check=True, capture_output=True, text=True, **kw).stdout


def prepare(work):
    jar = work / "takamaka-instr.jar"
    sh([str(JDK / "bin/java"), "-Xmx1g", "--module-path", str(M / "explicit_or_automatic"), "--class-path", f"{M}/unnamed/*",
        "--add-modules", "org.glassfish.tyrus.container.grizzly.server,org.glassfish.tyrus.container.grizzly.client",
        "--module", "io.hotmoka.moka/io.hotmoka.moka.Moka", "jars", "instrument",
        str(M / "explicit_or_automatic/io-takamaka-code-1.8.1.jar"), str(jar), "--init"])
    (work / "javap").mkdir()
    for c in CLASSES:
        (work / "javap" / f"{c}.txt").write_text(sh([str(JDK / "bin/javap"), "-c", "-p", "-cp", str(jar), c]))
    (work / "harness").mkdir()
    sh([str(JDK / "bin/javac"), "-cp", f"{M}/explicit_or_automatic/*:{M}/unnamed/*", "-d", str(work / "harness"), str(HERE / "UpdSize.java")])


def wc(work, spec, excl=""):
    out = sh([sys.executable, str(HERE / "wcet_gas.py"), str(work / "javap"), spec],
             env=dict(os.environ, BITLEN=str(BITLEN), EXCL=excl))
    return int(re.search(r"total=(\d+)", out).group(1))


def main():
    out = Path(sys.argv[sys.argv.index("--out") + 1]) if "--out" in sys.argv else ROOT / "build" / "constants_moka_sur.json"
    work = Path(tempfile.mkdtemp(prefix="arbre."))
    prepare(work)
    U, SN, MU, ST = "io.takamaka.code.util.", "SnapshottableStorageTreeMap", "StorageTreeMap", "StorageTreeSet"
    O, OO = "java.lang.Object", "java.lang.Object, java.lang.Object"
    d = {}
    d["compare"] = wc(work, "io.takamaka.code.lang.StorageSupport.compare")
    # get / contains: one loop iteration (= helper acyclic path) and public method (entry + 1 iteration)
    d["iter"] = max(wc(work, f"{U}{c}.getOrDefault|io.takamaka.code.util.{c}$Node, {OO}") for c in (SN, MU))
    d["get_pub"] = max(wc(work, f"{U}{c}.{m}|{a}") for c in (SN, MU) for m, a in
                       (("get", O), ("getOrDefault", OO), ("containsKey", O)))
    # persistent put: frame without the fix-ups + max(rotateLeft, rotateRight + flipColors)
    nb = f"{U}{SN}$BlackNode"
    d["put_base"] = wc(work, f"{U}{SN}.put|{U}{SN}$Node, {OO}", "rotateLeft,rotateRight,flipColors,put")
    d["rotL"] = max(wc(work, f"{U}{SN}${k}.rotateLeft") for k in ("RedNode", "BlackNode"))
    d["rotR"] = max(wc(work, f"{U}{SN}${k}.rotateRight") for k in ("RedNode", "BlackNode"))
    d["flip"] = max(wc(work, f"{U}{SN}${k}.flipColors") for k in ("RedNode", "BlackNode"))
    d["W_put"] = d["put_base"] + max(d["rotL"], d["rotR"] + d["flip"], d["flip"])
    d["put_pub"] = wc(work, f"{U}{SN}.put|{OO}", "put")
    # mutable put
    d["mput_base"] = wc(work, f"{U}{MU}.put|{U}{MU}$Node, {OO}", "rotateLeft,rotateRight,flipColors,put")
    d["mW_put"] = d["mput_base"] + max(wc(work, f"{U}{MU}$Node.rotateLeft"),
                                       wc(work, f"{U}{MU}$Node.rotateRight") + wc(work, f"{U}{MU}$Node.flipColors"))
    d["mput_pub"] = wc(work, f"{U}{MU}.put|{OO}", "put")
    # persistent remove: frame of remove / removeMin (+ min) without recursion
    d["W_rm"] = max(wc(work, f"{U}{SN}.remove|{U}{SN}$Node, {O}", "remove,removeMin,min"),
                    wc(work, f"{U}{SN}.removeMin|{U}{SN}$Node", "removeMin") + wc(work, f"{U}{SN}.min|{U}{SN}$Node", "min"))
    d["rm_pub"] = wc(work, f"{U}{SN}.remove|{O}", "remove,containsKey")
    d["contains_pub"] = wc(work, f"{U}{SN}.containsKey|{O}")
    # temporary mutable StorageTreeSet (never stored): add and contains
    d["sW_add"] = wc(work, f"{U}{ST}.put|{U}{ST}$Node, {O}", "rotateLeft,rotateRight,flipColors,put") + max(
        wc(work, f"{U}{ST}$Node.rotateLeft"), wc(work, f"{U}{ST}$Node.rotateRight") + wc(work, f"{U}{ST}$Node.flipColors"))
    d["s_add_pub"] = wc(work, f"{U}{ST}.add|{O}", "put")
    d["s_contains_pub"] = wc(work, f"{U}{ST}.contains|{O}")
    d["s_iter"] = wc(work, f"{U}{ST}.contains|{U}{ST}$Node, {O}")
    # bytes: A + B*k
    env = dict(os.environ, HARNESS=str(work / "harness"))
    wb = sh([sys.executable, str(HERE / "worst_bytes.py")], env=env)
    for name in ("persistent", "mutable"):
        m = re.search(name + r" bytes\(1\.\.5\): \[(\d+), (\d+), (\d+)[^\]]*\].*increments: \[([\d, ]+)\]", wb)
        b1, b2, b3 = int(m.group(1)), int(m.group(2)), int(m.group(3))
        inc = int(m.group(4).split(",")[0])
        B = inc
        A = max(b1 - B, b2 - 2 * B, b3 - 3 * B)        # bytes(k) <= A + B*k for every k (checked on 1..40)
        d[f"{name}_A"], d[f"{name}_B"] = A, B
    Ap, Bp, Am, Bm = d["persistent_A"], d["persistent_B"], d["mutable_A"], d["mutable_B"]
    g = GAS_PER_BYTE
    # bounds a + b*log2(n+1)  (bh <= log2(n+1))
    get = (d["get_pub"] + CALL, 2 * d["iter"])
    put = (d["put_pub"] + CALL + d["W_put"] + g * (Ap + Bp), 2 * d["W_put"] + g * 2 * Bp)
    mput = (d["mput_pub"] + CALL + d["mW_put"] + g * Am, 2 * d["mW_put"] + g * 2 * Bm)
    rem = (d["rm_pub"] + d["contains_pub"] + CALL + d["W_rm"] + g * (Ap + 2 * Bp), 2 * d["iter"] + 2 * d["W_rm"] + g * 4 * Bp)
    tmp = (max(d["s_add_pub"] + CALL + d["sW_add"], d["s_contains_pub"] + CALL), max(2 * d["sW_add"], 2 * d["s_iter"]))
    assert mput[0] <= put[0] and mput[1] <= put[1], "the mutable StorageTreeMap put must be below the persistent one"
    C0 = json.loads((ROOT / "data" / "constants_moka.json").read_text())
    C = dict(C0)
    C["C_TREE0"], C["C_TREE1"] = max(get[0], C0["C_TREE0"]), get[1]
    C["C_TREEW0"], C["C_TREEW1"] = max(put[0] - C0["C_NEW"], C0["C_TREEW0"]), put[1]   # map_put ub adds C_NEW
    C["C_TREER0"], C["C_TREER1"] = max(rem[0], C0["C_TREEW0"]), rem[1]
    C["C_TMP0"], C["C_TMP1"] = max(tmp[0], C0["C_TMP0"]), tmp[1]
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(C, indent=1) + "\n")
    print(json.dumps(d, indent=1))
    print("get     ", get, "\nput     ", put, "(mutable", mput, ")\nremove  ", rem, "\ntmp     ", tmp)
    for k in ("C_TREE0", "C_TREE1", "C_TREEW0", "C_TREEW1", "C_TREER0", "C_TREER1", "C_TMP0", "C_TMP1"):
        print(f"{k}: {C0.get(k, '-')} -> {C[k]}")
    print("written", out, "; work dir", work)


if __name__ == "__main__":
    main()
