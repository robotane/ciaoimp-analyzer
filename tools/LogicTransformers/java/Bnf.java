import java.io.*;
import java.util.*;

/**
 * Java port of bnf.py — a heap-based Prolog-like unification engine
 * and clause interpreter.
 *
 * Term representation:  int[2] = { value, tag }
 *   tag: PAIR=1, CONST=2, VAR=3
 *
 * The heap is a flat ArrayList<int[]> where pairs occupy two
 * consecutive slots (left at p, right at p+1).
 */
public class Bnf {

    // ----------------------------------------------------------------
    // Tag constants
    // ----------------------------------------------------------------
    static final int PAIR  = 1;
    static final int CONST = 2;
    static final int VAR   = 3;

    // Interpreter opcodes
    static final int FAIL = 0;
    static final int DO   = 1;
    static final int DONE = 2;
    static final int UNDO = 3;

    // ----------------------------------------------------------------
    // Global state (mirrors the Python module-level globals)
    // ----------------------------------------------------------------
    static List<int[]> heap = new ArrayList<>();

    static Map<String, Integer> syms = new HashMap<>();
    static List<String> sids = new ArrayList<>();

    // ----------------------------------------------------------------
    // Symbol table
    // ----------------------------------------------------------------

    /** Intern a symbol string, returning its integer id. */
    static int sym(String s) {
        Integer id = syms.get(s);
        if (id != null) return id;
        int i = sids.size();
        syms.put(s, i);
        sids.add(s);
        return i;
    }

    /** Create a CONST term for an atom. */
    static int[] atom(String s) {
        return new int[]{sym(s), CONST};
    }

    // ----------------------------------------------------------------
    // Heap / pair construction
    // ----------------------------------------------------------------

    /** Allocate a pair on the heap; returns {heapIndex, PAIR}. */
    static int[] pair(int[] x, int[] y) {
        int h = heap.size();
        heap.add(x);
        heap.add(y);
        return new int[]{h, PAIR};
    }

    static int[] left(int p) {
        return heap.get(p);
    }

    static int[] right(int p) {
        return heap.get(p + 1);
    }

    // ----------------------------------------------------------------
    // Clause wrapper
    // ----------------------------------------------------------------

    static class Cls {
        int[] c;      // the clause term (pair tag)
        int begin;    // heap range start
        int end;      // heap range end

        Cls(int[] c, int begin, int end) {
            this.c = c;
            this.begin = begin;
            this.end = end;
        }

        @Override
        public String toString() {
            return "cls(" + Arrays.toString(c) + "\t" + begin + ":" + end + ")";
        }
    }

    // ----------------------------------------------------------------
    // Loading ILTP format
    // ----------------------------------------------------------------

    static List<Cls> loadIltp(String fname) throws IOException {
        List<Cls> ts = new ArrayList<>();
        try (BufferedReader br = new BufferedReader(new FileReader(fname))) {
            String line;
            while ((line = br.readLine()) != null) {
                line = line.trim();
                if (line.isEmpty()) continue;
                int begin = heap.size();
                String[] toks = line.split("\\s+");
                int[] tree = stack2tree(toks);
                int end = heap.size();
                Cls clause = new Cls(tree, begin, end);

                System.out.println("CLS: " + p(tree));
                System.out.println("LINE: " + line);

                ts.add(clause);

                // Fixup variable indices so that each variable is
                // self-referencing at the earliest heap position.
                Map<Integer, Integer> vids = new HashMap<>();
                for (int h = begin; h < end; h++) {
                    int[] cell = heap.get(h);
                    int x = cell[0];
                    int t = cell[1];
                    if (VAR == t) {
                        if (vids.containsKey(x)) {
                            int y = vids.get(x);
                            heap.set(h, new int[]{y, VAR});
                        } else {
                            heap.set(h, new int[]{h, VAR});
                            vids.put(x, h);
                        }
                    }
                }
            }
        }
        return ts;
    }

    // ----------------------------------------------------------------
    // Postfix → tree builder
    // ----------------------------------------------------------------

    static int[] stack2tree(String[] postfix) {
        Deque<int[]> stack = new ArrayDeque<>();
        Map<String, Integer> vars = new HashMap<>();

        for (String x : postfix) {
            if ("$".equals(x)) {
                int[] t2 = stack.pop();
                int[] t1 = stack.pop();
                stack.push(pair(t1, t2));
            } else if (":-".equals(x)) {
                // skip
            } else {
                stack.push(toVar(x, vars));
            }
        }
        return stack.pop();
    }

    private static int[] toVar(String x, Map<String, Integer> vars) {
        if (Character.isUpperCase(x.charAt(0))) {
            if (vars.containsKey(x)) {
                return new int[]{vars.get(x), VAR};
            } else {
                int v = vars.size();
                vars.put(x, v);
                return new int[]{v, VAR};
            }
        } else {
            return atom(x);
        }
    }

    // ----------------------------------------------------------------
    // Heap access helpers
    // ----------------------------------------------------------------

    static int[] getVal(int v) {
        return heap.get(v);
    }

    static void setVal(int v, int[] t) {
        heap.set(v, t);
    }

    // ----------------------------------------------------------------
    // Dereferencing
    // ----------------------------------------------------------------

    static int[] deref(int[] o) {
        while (true) {
            int x = o[0];
            int t = o[1];
            if (t == VAR) {
                int[] val = getVal(x);
                int v  = val[0];
                int tv = val[1];
                if (v == x) {
                    assert tv == VAR;
                    return o;
                }
                if (tv == VAR && v > x) {
                    System.out.println("DEREF: " + v + " > " + x);
                    assert v < x;
                }
                o = val;
            } else {
                return o;
            }
        }
    }

    // ----------------------------------------------------------------
    // Unification
    // ----------------------------------------------------------------

    static boolean unify(int[] x, int[] y, List<Integer> trail, int htop) {
        Deque<int[]> ustack = new ArrayDeque<>();
        ustack.push(y);
        ustack.push(x);
        while (!ustack.isEmpty()) {
            int[] d1 = deref(ustack.pop());
            int x1 = d1[0], t1 = d1[1];
            int[] d2 = deref(ustack.pop());
            int x2 = d2[0], t2 = d2[1];

            if (x1 == x2 && t1 == t2) {
                // already equal
            } else if (VAR == t1 && VAR == t2) {
                if (x1 > x2) {
                    setVal(x1, new int[]{x2, t2});
                    if (x1 < htop) trail.add(x1);
                } else {
                    setVal(x2, new int[]{x1, t1});
                    if (x2 < htop) trail.add(x2);
                }
            } else if (VAR == t1) {
                setVal(x1, new int[]{x2, t2});
                if (x1 < htop) trail.add(x1);
            } else if (VAR == t2) {
                setVal(x2, new int[]{x1, t1});
                if (x2 < htop) trail.add(x2);
            } else if (t1 != t2) {
                return false;
            } else if (t1 == CONST) {
                if (x1 != x2) return false;
            } else {
                assert t1 == PAIR;
                assert t2 == PAIR;
                int[] a1 = left(x1), b1 = right(x1);
                int[] a2 = left(x2), b2 = right(x2);
                ustack.push(b2);
                ustack.push(b1);
                ustack.push(a2);
                ustack.push(a1);
            }
        }
        return true;
    }

    // ----------------------------------------------------------------
    // Trail & heap management
    // ----------------------------------------------------------------

    static void unwind(List<Integer> trail, int ttop) {
        for (int i = trail.size() - 1; i >= ttop; i--) {
            int v = trail.remove(i);
            setVal(v, new int[]{v, VAR});
        }
    }

    static void trimHeap(int htop) {
        while (heap.size() > htop) {
            heap.remove(heap.size() - 1);
        }
    }

    // ----------------------------------------------------------------
    // Goal construction
    // ----------------------------------------------------------------

    static int[] getGoal() {
        int[] goal = atom("goal");
        int[] cont = new int[]{heap.size(), VAR};
        int[] p = pair(cont, goal);
        int[] answer = new int[]{heap.size(), VAR};
        return pair(answer, p);
    }

    // ----------------------------------------------------------------
    // Clause activation (copy + offset)
    // ----------------------------------------------------------------

    static int[] activate(int[] G, Cls clause, List<Integer> trail, int ttop, int htop) {
        int hb   = clause.c[0];
        int ctag = clause.c[1];

        boolean ok = unify(left(hb), G, trail, htop);
        unwind(trail, ttop);
        if (!ok) return null;

        int begin = clause.begin;
        int end   = clause.end;
        int h     = htop - begin;

        for (int j = begin; j < end; j++) {
            int[] cell = heap.get(j);
            int cx = cell[0];
            int ct = cell[1];
            if (CONST == ct) {
                heap.add(new int[]{cx, ct});
            } else {
                heap.add(new int[]{cx + h, ct});
            }
        }
        return new int[]{h + hb, ctag};
    }

    // ----------------------------------------------------------------
    // Interpreter step
    // ----------------------------------------------------------------

    /**
     * Represents a single state‐machine frame.
     * Fields mirror the Python tuple (op, G, ttop, htop, i).
     * For DO: g1=NewG, g2=OldG.
     * For DONE/UNDO: g1=G, g2=null.
     * For FAIL: g1=g2=null.
     */
    static class Frame {
        int op;
        int[] g1;
        int[] g2;
        int ttop;
        int htop;
        int i;

        Frame(int op, int[] g1, int[] g2, int ttop, int htop, int i) {
            this.op   = op;
            this.g1   = g1;
            this.g2   = g2;
            this.ttop = ttop;
            this.htop = htop;
            this.i    = i;
        }
    }

    static Frame step(int[] G, List<Cls> code, List<Integer> trail,
                      int[] goal, int i) {
        int l    = code.size();
        int htop = heap.size();
        int ttop = trail.size();
        G = deref(G);
        assert G[0] < htop;

        while (i < l) {
            unwind(trail, ttop);
            trimHeap(htop);
            int[] clause = activate(G, code.get(i), trail, ttop, htop);
            i++;
            if (clause != null) {
                int hb  = clause[0];
                int thb = clause[1];
                assert PAIR == thb;
                int[] H = left(hb);
                assert H[0] >= htop;
                assert G[0] < htop;
                unify(G, H, trail, htop);
                int[] dr = deref(right(hb));
                int b  = dr[0];
                int tb = dr[1];
                if (VAR == tb) {
                    System.out.println(p(left(goal[0])));
                    return new Frame(DONE, G, null, ttop, htop, i);
                } else {
                    int[] newG = new int[]{b, tb};
                    assert b < heap.size();
                    return new Frame(DO, newG, G, ttop, htop, i);
                }
            }
        }
        return new Frame(FAIL, null, null, ttop, htop, i);
    }

    // ----------------------------------------------------------------
    // Ensure UNDO deduplication
    // ----------------------------------------------------------------

    static void ensureUndo(int[] G, Deque<Frame> todo, int ttop,
                           int htop, int i, int l) {
        Frame instr = new Frame(UNDO, G, null, ttop, htop, i);
        if (!todo.isEmpty()) {
            Frame top = todo.peek();
            if (top.op == UNDO && top.i == i && top.g1 == G && ttop >= top.ttop) {
                return;
            }
        }
        todo.push(instr);
    }

    // ----------------------------------------------------------------
    // Main interpreter loop (trampoline)
    // ----------------------------------------------------------------

    static void interp(String fname) throws IOException {
        int[] goal = getGoal();
        List<Cls> code = loadIltp(fname);
        int l = code.size();
        List<Integer> trail = new ArrayList<>();

        Deque<Frame> todo = new ArrayDeque<>();
        todo.push(new Frame(DO, goal, null, 0, heap.size(), l));

        while (!todo.isEmpty()) {
            Frame f = todo.pop();
            int op = f.op;

            if (DO == op) {
                int[] newG = f.g1;
                int[] oldG = f.g2;
                if (f.i < l) {
                    ensureUndo(oldG, todo, f.ttop, f.htop, f.i, l);
                }
                todo.push(step(newG, code, trail, goal, 0));

            } else if (DONE == op) {
                if (f.i < l) {
                    ensureUndo(f.g1, todo, f.ttop, f.htop, f.i, l);
                }

            } else if (UNDO == op) {
                unwind(trail, f.ttop);
                trimHeap(f.htop);
                if (f.i < l) {
                    todo.push(step(f.g1, code, trail, goal, f.i));
                }

            } else {
                // FAIL — nothing to do
            }
        }
    }

    // ----------------------------------------------------------------
    // Pretty-printing helpers
    // ----------------------------------------------------------------

    /** Human-readable term representation. */
    static String p(int[] o) {
        int[] d = deref(o);
        int x = d[0], t = d[1];
        if (VAR == t) {
            return "_" + x;
        } else if (CONST == t) {
            return sids.get(x);
        } else {
            assert PAIR == t;
            int[] a = heap.get(x);
            int[] b = heap.get(x + 1);
            return "(" + p(a) + "=>" + p(b) + ")";
        }
    }

    static void pp(int[] o) {
        System.out.println(p(o));
    }

    static void ph(int begin, int end) {
        if (end == 0) end = heap.size();
        System.out.println("HEAP: " + begin + " --> " + end);
        assert end > 0;
        for (int i = begin; i < end; i++) {
            System.out.print(i + ": ");
            pp(heap.get(i));
        }
        System.out.println("----------");
    }

    static void pt(List<Integer> trail, int begin, int end) {
        if (end == 0) end = trail.size();
        System.out.println("TRAIL: " + begin + " --> " + end);
        for (int i = begin; i < end; i++) {
            System.out.print(i + ": ");
            pp(new int[]{trail.get(i), VAR});
        }
        System.out.println("----------");
    }

    static String phb(int[] c) {
        int hb = c[0], tg = c[1];
        assert PAIR == tg;
        int[] h = left(hb);
        int[] b = right(hb);
        return p(h) + " :- " + p(b);
    }

    static void pc(List<Cls> code) {
        System.out.println("CLAUSES:");
        for (int i = 0; i < code.size(); i++) {
            Cls clause = code.get(i);
            String s = phb(clause.c);
            System.out.println(i + ": " + s + "\t" + clause.begin + ":" + clause.end);
        }
        System.out.println("----------");
    }

    /** Deep-print with size limit. */
    static Object iron(int[] a, int size) {
        if (size <= 0) return ".?.";
        int[] d = deref(a);
        int x = d[0], t = d[1];
        if (t == PAIR) {
            int[] u = left(x);
            int[] v = right(x);
            return new Object[]{iron(u, size - 1), iron(v, size - 1)};
        } else if (t == CONST) {
            return sids.get(x);
        } else {
            return "_" + x;
        }
    }

    static Object iron(int[] a) {
        return iron(a, 200);
    }

    // ----------------------------------------------------------------
    // Entry point
    // ----------------------------------------------------------------

    public static void main(String[] args) throws IOException {
        String fname;
        if (args.length < 1) {
            fname = "out/bnf_asm.txt";
        } else {
            fname = args[0];
        }
        interp(fname);
    }
}
