#!/usr/bin/env python3
"""Simulator of the Takamaka trees (io-takamaka-code 1.8.1) and of the Hotmoka updates of one
transaction, to check the structural bounds used in arbre_pire_cas.md and to obtain the exact
storage bytes (via the Java harness UpdSize, which marshals the updates with Hotmoka's code).

 - SnapshottableStorageTreeMap: persistent left-leaning red-black tree (path copying, Red/Black
   node classes). Port of put/remove/removeMin/balance/moveRed* of the Java source.
 - StorageTreeMap: mutable LLRB (same algorithms, in place).
For each operation it emits the updates that UpdatesExtractor would produce:
 - new object reachable from the map: ClassTag + every field (null -> UpdateToNull);
 - old object: one update per field whose value changed.
Keys and values are old storage objects of distinct transactions (worst case for sharing);
the value written by put is either a new object of the current transaction or an old one.
"""
import random, sys, math, json, subprocess, os
from pathlib import Path

SN = "io.takamaka.code.util.SnapshottableStorageTreeMap"
MU = "io.takamaka.code.util.StorageTreeMap"
OBJ = "java.lang.Object"

class Ctx:
    """objects created during the current transaction get progressive numbers"""
    def __init__(self, tx):
        self.tx, self.prog = tx, 0
    def ref(self):
        self.prog += 1
        return f"{self.tx}:{self.prog}"

# ---------------- persistent (Snapshottable) ----------------
class PN:
    __slots__ = ("red", "key", "value", "size", "left", "right", "ref")
    def __init__(s, ctx, red, key, value, size, left, right):
        s.red, s.key, s.value, s.size, s.left, s.right = red, key, value, size, left, right
        s.ref = ctx.ref()

def isRed(x): return x is not None and x.red
def isBlack(x): return x is None or not x.red
def size(x): return 0 if x is None else x.size

class Persistent:
    def __init__(s):
        s.root = None
    # Node methods (each returns a NEW node, as in the Java code)
    def mk(s, red, k, v, n, l, r): return PN(s.ctx, red, k, v, n, l, r)
    def fixSize(s, h): return s.mk(h.red, h.key, h.value, size(h.left) + size(h.right) + 1, h.left, h.right)
    def flipColor(s, h): return s.mk(not h.red, h.key, h.value, h.size, h.left, h.right)
    def rotateLeft(s, h):
        x = h.right
        nt = s.mk(True, h.key, h.value, size(x.left) + size(h.left) + 1, h.left, x.left)
        return s.mk(h.red, x.key, x.value, h.size, nt, x.right)
    def rotateRight(s, h):
        x = h.left
        nt = s.mk(True, h.key, h.value, size(x.right) + size(h.right) + 1, x.right, h.right)
        return s.mk(h.red, x.key, x.value, h.size, x.left, nt)
    def setLeft(s, h, l): return s.mk(h.red, h.key, h.value, h.size, l, h.right)
    def setRight(s, h, r): return s.mk(h.red, h.key, h.value, h.size, h.left, r)
    def setValue(s, h, v): return s.mk(h.red, h.key, v, h.size, h.left, h.right)
    def flipColors(s, h): return s.mk(not h.red, h.key, h.value, h.size, s.flipColor(h.left), s.flipColor(h.right))
    def moveRedLeft(s, h):
        h = s.flipColors(h)
        return s.flipColors(s.rotateLeft(s.setRight(h, s.rotateRight(h.right)))) if isRed(h.right.left) else h
    def moveRedRight(s, h):
        h = s.flipColors(h)
        return s.flipColors(s.rotateRight(h)) if isRed(h.left.left) else h
    def balance(s, h):
        if isRed(h.right) and isBlack(h.left): h = s.rotateLeft(h)
        if isRed(h.left) and isRed(h.left.left): h = s.rotateRight(h)
        if isRed(h.left) and isRed(h.right): h = s.flipColors(h)
        return s.fixSize(h)
    def mkRootBlack(s):
        if isRed(s.root): s.root = s.mk(False, s.root.key, s.root.value, s.root.size, s.root.left, s.root.right)
    def mkRootRed(s):
        if isBlack(s.root): s.root = s.mk(True, s.root.key, s.root.value, s.root.size, s.root.left, s.root.right)
    def put(s, key, value):
        s.levels = 0
        s.root = s._put(s.root, key, value); s.mkRootBlack()
    def _put(s, h, key, value):
        s.levels += 1
        if h is None: return s.mk(True, key, value, 1, None, None)
        if key[0] < h.key[0]: h = s.setLeft(h, s._put(h.left, key, value))
        elif key[0] > h.key[0]: h = s.setRight(h, s._put(h.right, key, value))
        else: h = s.setValue(h, value)
        if isRed(h.right) and isBlack(h.left): h = s.rotateLeft(h)
        if isRed(h.left) and isRed(h.left.left): h = s.rotateRight(h)
        if isRed(h.left) and isRed(h.right): h = s.flipColors(h)
        return s.fixSize(h)
    def contains(s, key):
        x = s.root
        while x is not None:
            if key[0] < x.key[0]: x = x.left
            elif key[0] > x.key[0]: x = x.right
            else: return True
        return False
    def remove(s, key):
        s.levels = 0
        if s.contains(key):
            if isBlack(s.root.left) and isBlack(s.root.right): s.mkRootRed()
            s.root = s._remove(s.root, key)
            if s.root is not None: s.mkRootBlack()
    def _min(s, x):
        while x.left is not None: x = x.left
        return x
    def _removeMin(s, h):
        s.levels += 1
        if h.left is None: return None
        if isBlack(h.left) and isBlack(h.left.left): h = s.moveRedLeft(h)
        return s.balance(s.setLeft(h, s._removeMin(h.left)))
    def _remove(s, h, key):
        s.levels += 1
        if key[0] < h.key[0]:
            if isBlack(h.left) and isBlack(h.left.left): h = s.moveRedLeft(h)
            h = s.setLeft(h, s._remove(h.left, key))
        else:
            if isRed(h.left): h = s.rotateRight(h)
            if key[0] == h.key[0] and h.right is None: return None
            if isBlack(h.right) and isBlack(h.right.left): h = s.moveRedRight(h)
            if key[0] == h.key[0]:
                x = s._min(h.right)
                h = s.mk(h.red, x.key, x.value, h.size, h.left, s._removeMin(h.right))
            else:
                h = s.setRight(h, s._remove(h.right, key))
        return s.balance(h)
    # updates of the transaction
    def updates(s, old_refs, mapref):
        ups, seen, stack = [], set(), [s.root] if s.root is not None else []
        N = SN + "$Node"
        while stack:
            x = stack.pop()
            if x.ref in seen or x.ref in old_refs: continue
            seen.add(x.ref)
            ups.append(f"CT {x.ref} {SN}${'RedNode' if x.red else 'BlackNode'} tk")
            ups.append(f"ST {x.ref} {N} key {OBJ} {x.key[1]}")
            ups.append(f"ST {x.ref} {N} value {OBJ} {x.value}")
            ups.append(f"IN {x.ref} {N} size {x.size}")
            for f in ("left", "right"):
                c = getattr(x, f)
                if c is None: ups.append(f"NU {x.ref} {N} {f} {N}")
                else:
                    ups.append(f"ST {x.ref} {N} {f} {N} {c.ref}"); stack.append(c)
        return ups, len(seen)
    def begin(s, ctx):
        s.ctx = ctx
        s.old_root = s.root
        s.old = set()
        st = [s.root] if s.root else []
        while st:
            x = st.pop(); s.old.add(x.ref)
            st += [c for c in (x.left, x.right) if c]
    def end(s, mapref):
        ups, k = s.updates(s.old, mapref)
        if s.root is not s.old_root:
            ups.append(f"ST {mapref} {SN} root {SN}$Node {s.root.ref}" if s.root else f"NU {mapref} {SN} root {SN}$Node")
        return ups, k

# ---------------- mutable StorageTreeMap ----------------
class MN:
    __slots__ = ("red", "key", "value", "size", "left", "right", "ref", "snap")
    def __init__(s, ctx, key, value):
        s.red, s.key, s.value, s.size, s.left, s.right = True, key, value, 1, None, None
        s.ref, s.snap = ctx.ref(), None

class Mutable:
    def __init__(s):
        s.root = None
    def begin(s, ctx):
        s.ctx = ctx; s.old_root = s.root; s.nodes = []; s.created = []
        st = [s.root] if s.root else []
        while st:
            x = st.pop(); s.nodes.append(x)
            x.snap = (x.red, x.key, x.value, x.size, x.left, x.right)
            st += [c for c in (x.left, x.right) if c]
        s.oldset = set(id(x) for x in s.nodes)
    def rotateRight(s, h):
        x = h.left; h.left = x.right; x.right = h; x.red = h.red; h.red = True; x.size = h.size
        h.size = size(h.left) + size(h.right) + 1; return x
    def rotateLeft(s, h):
        x = h.right; h.right = x.left; x.left = h; x.red = h.red; h.red = True; x.size = h.size
        h.size = size(h.left) + size(h.right) + 1; return x
    def flipColors(s, h):
        h.red = not h.red; h.left.red = not h.left.red; h.right.red = not h.right.red
    def fixSize(s, h): h.size = size(h.left) + size(h.right) + 1
    def moveRedLeft(s, h):
        s.flipColors(h)
        if isRed(h.right.left):
            h.right = s.rotateRight(h.right); r = s.rotateLeft(h); s.flipColors(r); return r
        return h
    def moveRedRight(s, h):
        s.flipColors(h)
        if isRed(h.left.left):
            r = s.rotateRight(h); s.flipColors(r); return r
        return h
    def balance(s, h):
        if isRed(h.right) and isBlack(h.left): h = s.rotateLeft(h)
        if isRed(h.left) and isRed(h.left.left): h = s.rotateRight(h)
        if isRed(h.left) and isRed(h.right): s.flipColors(h)
        s.fixSize(h); return h
    def put(s, key, value):
        s.levels = 0
        s.root = s._put(s.root, key, value); s.root.red = False
    def _put(s, h, key, value):
        s.levels += 1
        if h is None:
            n = MN(s.ctx, key, value); s.created.append(n); return n
        if key[0] < h.key[0]: h.left = s._put(h.left, key, value)
        elif key[0] > h.key[0]: h.right = s._put(h.right, key, value)
        else: h.value = value
        if isRed(h.right) and isBlack(h.left): h = s.rotateLeft(h)
        if isRed(h.left) and isRed(h.left.left): h = s.rotateRight(h)
        if isRed(h.left) and isRed(h.right): s.flipColors(h)
        s.fixSize(h); return h
    def contains(s, key):
        x = s.root
        while x is not None:
            if key[0] < x.key[0]: x = x.left
            elif key[0] > x.key[0]: x = x.right
            else: return True
        return False
    def remove(s, key):
        s.levels = 0
        if s.contains(key):
            if isBlack(s.root.left) and isBlack(s.root.right): s.root.red = True
            s.root = s._remove(s.root, key)
            if s.root is not None: s.root.red = False
    def _removeMin(s, h):
        s.levels += 1
        if h.left is None: return None
        if isBlack(h.left) and isBlack(h.left.left): h = s.moveRedLeft(h)
        h.left = s._removeMin(h.left); s.balance(h); return h
    def _remove(s, h, key):
        s.levels += 1
        if key[0] < h.key[0]:
            if isBlack(h.left) and isBlack(h.left.left): h = s.moveRedLeft(h)
            h.left = s._remove(h.left, key)
        else:
            if isRed(h.left): h = s.rotateRight(h)
            if key[0] == h.key[0] and h.right is None: return None
            if isBlack(h.right) and isBlack(h.right.left): h = s.moveRedRight(h)
            if key[0] == h.key[0]:
                x = h.right
                while x.left is not None: x = x.left
                h.key, h.value = x.key, x.value
                h.right = s._removeMin(h.right)
            else:
                h.right = s._remove(h.right, key)
        return s.balance(h)
    def end(s, mapref):
        N = MU + "$Node"; ups = []; touched = 0
        reach = set(); st = [s.root] if s.root else []
        while st:
            x = st.pop(); reach.add(id(x)); st += [c for c in (x.left, x.right) if c]
        for x in s.created:
            if id(x) not in reach: continue
            touched += 1
            ups += [f"CT {x.ref} {N} tk", f"BO {x.ref} {N} color {str(not x.red).lower()}",
                    f"ST {x.ref} {N} key {OBJ} {x.key[1]}", f"ST {x.ref} {N} value {OBJ} {x.value}",
                    f"IN {x.ref} {N} size {x.size}"]
            for f in ("left", "right"):
                c = getattr(x, f)
                ups.append(f"NU {x.ref} {N} {f} {N}" if c is None else f"ST {x.ref} {N} {f} {N} {c.ref}")
        for x in s.nodes:
            o = x.snap; ch = False
            if x.red != o[0]: ups.append(f"BO {x.ref} {N} color {str(not x.red).lower()}"); ch = True
            if x.key != o[1]: ups.append(f"ST {x.ref} {N} key {OBJ} {x.key[1]}"); ch = True
            if x.value != o[2]: ups.append(f"ST {x.ref} {N} value {OBJ} {x.value}"); ch = True
            if x.size != o[3]: ups.append(f"IN {x.ref} {N} size {x.size}"); ch = True
            for i, f in ((4, "left"), (5, "right")):
                c = getattr(x, f)
                if c is not o[i]:
                    ups.append(f"NU {x.ref} {N} {f} {N}" if c is None else f"ST {x.ref} {N} {f} {N} {c.ref}"); ch = True
            touched += ch
        if s.root is not s.old_root:
            ups.append(f"ST {mapref} {MU} root {N} {s.root.ref}" if s.root else f"NU {mapref} {MU} root {N}")
        return ups, touched

def black_height(root):
    h, x = 0, root
    while x is not None:
        h += (not x.red); x = x.left
    return h

def height_nodes(root):
    def go(x): return 0 if x is None else 1 + max(go(x.left), go(x.right))
    return go(root)
