import java.io.*;
import java.util.*;

/**
 * Java port of tnf.py - instruction-based TNF Prolog VM.
 *
 * Term representation:
 * - Variable: Var object (mutable cell with val, id, name)
 * - Pair: Object[2] = {left, right}
 * - Constant: String or Integer or Double
 *
 * Instructions: d, k, u, b, p (loaded from TNF ASM text files)
 */
public class Tnf {

    // Tag constants
    static final int VAR = 1, REF = 2, PAIR = 3, CONST = 4;

    // Interpreter opcodes
    static final int FAIL = 0, DONE = 1, DO = 2, UNDO = 3, CUT = 4;

    static int varCounter = 0;

    // ---------------------------------------------------------------
    // Variable cell
    // ---------------------------------------------------------------
    static class Var {
        Object val; // null = unbound
        int id;
        String name;

        Var(String name) {
            this.val = null;
            this.id = varCounter++;
            this.name = name;
        }

        @Override
        public String toString() {
            return name != null ? name : "_V" + id;
        }
    }

    // ---------------------------------------------------------------
    // Type checking
    // ---------------------------------------------------------------
    static int typeOf(Object x) {
        if (x instanceof Var) {
            return ((Var) x).val == null ? VAR : REF;
        } else if (x instanceof Object[]) {
            return PAIR;
        } else {
            return CONST;
        }
    }

    // ---------------------------------------------------------------
    // Dereferencing
    // ---------------------------------------------------------------
    static Object[] deref(Object x) {
        while (true) {
            int t = typeOf(x);
            if (t == REF) {
                x = ((Var) x).val;
            } else {
                return new Object[] { x, t };
            }
        }
    }

    // ---------------------------------------------------------------
    // Unification
    // ---------------------------------------------------------------
    static boolean unify(Object x, Object y, List<Var> trail, Set<Integer> vids) {
        Deque<Object> ustack = new ArrayDeque<>();
        ustack.push(y);
        ustack.push(x);
        while (!ustack.isEmpty()) {
            Object[] d1 = deref(ustack.pop());
            Object x1 = d1[0];
            int t1 = (int) d1[1];
            Object[] d2 = deref(ustack.pop());
            Object x2 = d2[0];
            int t2 = (int) d2[1];

            if (x1 == x2) {
                // same object
            } else if (t1 == VAR) {
                ((Var) x1).val = x2;
                if (!vids.contains(((Var) x1).id))
                    trail.add((Var) x1);
            } else if (t2 == VAR) {
                ((Var) x2).val = x1;
                if (!vids.contains(((Var) x2).id))
                    trail.add((Var) x2);
            } else if (t1 != t2) {
                return false;
            } else if (t1 == CONST) {
                if (!constEqual(x1, x2))
                    return false;
            } else {
                // PAIR
                Object[] p1 = (Object[]) x1;
                Object[] p2 = (Object[]) x2;
                if (p1.length != 2 || p2.length != 2)
                    return false;
                ustack.push(p2[1]);
                ustack.push(p1[1]);
                ustack.push(p2[0]);
                ustack.push(p1[0]);
            }
        }
        return true;
    }

    static boolean constEqual(Object a, Object b) {
        if (a == b)
            return true;
        if (a == null || b == null)
            return false;
        if (a instanceof Number && b instanceof Number) {
            return ((Number) a).doubleValue() == ((Number) b).doubleValue();
        }
        return a.equals(b);
    }

    // ---------------------------------------------------------------
    // Trail management
    // ---------------------------------------------------------------
    static void unwind(List<Var> trail, int ttop) {
        for (int i = trail.size() - 1; i >= ttop; i--) {
            trail.remove(i).val = null;
        }
    }

    // ---------------------------------------------------------------
    // Code loading
    // ---------------------------------------------------------------

    /**
     * A code template: each element is either a Var-skeleton [id, name] or a
     * constant.
     */
    static List<List<List<Object>>> tload(String fname) throws IOException {
        String txt;
        try (BufferedReader br = new BufferedReader(new FileReader(fname))) {
            StringBuilder sb = new StringBuilder();
            String line;
            while ((line = br.readLine()) != null) {
                sb.append(line).append('\n');
            }
            txt = sb.toString();
        }

        List<List<List<Object>>> code = new ArrayList<>();
        Map<String, int[]> vars = new HashMap<>();
        List<List<Object>> cs = new ArrayList<>();

        for (String l : txt.split("\n")) {
            String[] xs = l.split(" ");
            if (xs.length <= 1)
                continue;

            List<Object> instr = new ArrayList<>();
            for (String x : xs) {
                if (x.isEmpty())
                    continue;
                if (Character.isUpperCase(x.charAt(0))) {
                    // Variable template
                    int[] v;
                    if (vars.containsKey(x)) {
                        v = vars.get(x);
                    } else {
                        v = new int[] { vars.size(), x.hashCode() };
                        vars.put(x, v);
                    }
                    // Store as Object[]: {index, name}
                    instr.add(new Object[] { v[0], x });
                } else if (x.charAt(0) == '_') {
                    int[] v = new int[] { vars.size(), x.hashCode() };
                    vars.put(x, v);
                    instr.add(new Object[] { v[0], x });
                } else if ("[|]".equals(x)) {
                    instr.add(".");
                } else {
                    instr.add(toConst(x));
                }
            }
            cs.add(instr);
            if ("p".equals(instr.get(0))) {
                code.add(new ArrayList<>(cs));
                vars = new HashMap<>();
                cs = new ArrayList<>();
            }
        }
        return code;
    }

    static Object toConst(String x) {
        try {
            return Integer.parseInt(x);
        } catch (NumberFormatException e1) {
            try {
                return Double.parseDouble(x);
            } catch (NumberFormatException e2) {
                return x;
            }
        }
    }

    // ---------------------------------------------------------------
    // Activate: create real Var objects from templates
    // ---------------------------------------------------------------
    static List<Object> activate(List<Object> instr, List<Var> vars, Set<Integer> vids) {
        List<Object> result = new ArrayList<>();
        for (Object c : instr) {
            if (c instanceof Object[]) {
                Object[] tmpl = (Object[]) c;
                int n = (int) tmpl[0];
                String name = (String) tmpl[1];
                Var d;
                if (n < vars.size()) {
                    d = vars.get(n);
                } else {
                    d = new Var(name);
                    vids.add(d.id);
                    vars.add(d);
                }
                result.add(d);
            } else {
                result.add(c);
            }
        }
        return result;
    }

    // ---------------------------------------------------------------
    // Goal
    // ---------------------------------------------------------------
    static Object[] getGoal() {
        Var answer = new Var("Answer");
        Object cont = "true";
        Object[] G = new Object[] { answer, new Object[] { cont, "goal" } };
        return new Object[] { G, answer };
    }

    // ---------------------------------------------------------------
    // Built-in detection
    // ---------------------------------------------------------------
    static final Set<String> BUILTIN_NAMES = new HashSet<>(Arrays.asList(
            "is", "is_", ">", ">=", "<", "=<", "\\=", "\\==", "=", "$cut"));

    /** Returns {arg1, arg2/Kvar, cont/Cont, name} or null if not built-in. */
    static Object[] isBuiltIn(Object G) {
        Object[] d = deref(G);
        Object g = d[0];
        int t = (int) d[1];
        if (t != PAIR)
            return null;
        Object[] gp = (Object[]) g;

        Object[] d1 = deref(gp[1]);
        Object g1 = d1[0];
        int t1 = (int) d1[1];
        if (t1 != PAIR)
            return null;
        Object[] g1p = (Object[]) g1;

        Object[] di = deref(g1p[1]);
        Object inner = di[0];
        int tinner = (int) di[1];

        if (tinner == CONST && "$cut".equals(inner)) {
            // arg1=g[0], cont=g1[0], name=$cut
            // For $cut: {Kvar, Cont, null, "$cut"}
            return new Object[] { gp[0], g1p[0], null, "$cut" };
        }
        if (tinner != PAIR)
            return null;
        Object[] inp = (Object[]) inner;

        Object[] dn = deref(inp[1]);
        Object name = dn[0];
        int tn = (int) dn[1];
        if (tn != CONST)
            return null;
        if (!(name instanceof String))
            return null;
        if (!BUILTIN_NAMES.contains(name))
            return null;

        return new Object[] { gp[0], g1p[0], inp[0], name };
    }

    // ---------------------------------------------------------------
    // Built-in handling
    // ---------------------------------------------------------------
    static boolean handleBuiltIn(Object[] builtIn, List<Var> trail, Set<Integer> vids) {
        Object arg1 = builtIn[0], arg2 = builtIn[1], cont = builtIn[2];
        String name = (String) builtIn[3];

        switch (name) {
            case "is":
            case "is_":
                try {
                    Object expr = pp(arg2);
                    Object val = evaluate(expr);
                    return unify(arg1, val, trail, vids);
                } catch (Exception e) {
                    return false;
                }
            case ">":
                try {
                    double v1 = toNum(evaluate(pp(arg1)));
                    double v2 = toNum(evaluate(pp(arg2)));
                    return v1 > v2;
                } catch (Exception e) {
                    return false;
                }
            case ">=":
                try {
                    double v1 = toNum(evaluate(pp(arg1)));
                    double v2 = toNum(evaluate(pp(arg2)));
                    return v1 >= v2;
                } catch (Exception e) {
                    return false;
                }
            case "<":
                try {
                    double v1 = toNum(evaluate(pp(arg1)));
                    double v2 = toNum(evaluate(pp(arg2)));
                    return v1 < v2;
                } catch (Exception e) {
                    return false;
                }
            case "=<":
                try {
                    double v1 = toNum(evaluate(pp(arg1)));
                    double v2 = toNum(evaluate(pp(arg2)));
                    return v1 <= v2;
                } catch (Exception e) {
                    return false;
                }
            case "\\=":
            case "\\==":
                return !unify(arg1, arg2, new ArrayList<>(), new HashSet<>());
            case "=":
                return unify(arg1, arg2, trail, vids);
        }
        return false;
    }

    static double toNum(Object o) {
        if (o instanceof Number)
            return ((Number) o).doubleValue();
        throw new RuntimeException("not a number: " + o);
    }

    // ---------------------------------------------------------------
    // Arithmetic evaluation
    // ---------------------------------------------------------------
    static Object evaluate(Object expr) {
        if (expr instanceof Integer || expr instanceof Double)
            return expr;
        if (expr instanceof List) {
            List<?> lst = (List<?>) expr;
            if (lst.size() > 1) {
                Object op = lst.get(0);
                List<Object> args = new ArrayList<>();
                for (int i = 1; i < lst.size(); i++) {
                    args.add(evaluate(lst.get(i)));
                }
                if ("+".equals(op)) {
                    double s = 0;
                    for (Object a : args)
                        s += toNum(a);
                    return toIntIfPossible(s);
                }
                if (args.size() >= 2) {
                    double a0 = toNum(args.get(0));
                    double a1 = toNum(args.get(1));
                    if ("-".equals(op))
                        return toIntIfPossible(a0 - a1);
                    if ("*".equals(op))
                        return toIntIfPossible(a0 * a1);
                    if ("/".equals(op))
                        return toIntIfPossible(a0 / a1);
                    if ("//".equals(op))
                        return (int) (a0 / a1);
                }
            }
        }
        return expr;
    }

    static Object toIntIfPossible(double v) {
        if (v == Math.floor(v) && !Double.isInfinite(v))
            return (int) v;
        return v;
    }

    // ---------------------------------------------------------------
    // Pretty printing: to_pterm + dot2list equivalent = pp()
    // ---------------------------------------------------------------
    static Object toPterm(Object x) {
        Object[] d = deref(x);
        Object xd = d[0];
        int t = (int) d[1];
        if (t == VAR)
            return xd;
        if (t == CONST)
            return xd;
        assert t == PAIR;
        Object[] p = (Object[]) xd;
        List<Object> args = new ArrayList<>();
        args.add(null); // placeholder for functor
        args.add(toPterm(p[0]));
        Object b = p[1];
        while (true) {
            Object[] db = deref(b);
            Object bd = db[0];
            int bt = (int) db[1];
            if (bt == PAIR) {
                Object[] bp = (Object[]) bd;
                args.add(toPterm(bp[0]));
                b = bp[1];
            } else {
                args.set(0, toPterm(bd));
                return args;
            }
        }
    }

    /** Convert dot-lists to Java Lists (like Python's dot2list). */
    @SuppressWarnings("unchecked")
    static Object dot2list(Object a) {
        if (isDotList(a)) {
            List<Object> result = new ArrayList<>();
            Object x = a;
            while (isDotList(x)) {
                List<Object> lst = (List<Object>) x;
                result.add(dot2list(lst.get(1)));
                x = lst.get(2);
            }
            if ("[]".equals(x)) {
                return result;
            } else {
                // Non-proper list: return as-is with mapped elements
                List<Object> mapped = new ArrayList<>();
                for (Object e : result)
                    mapped.add(e);
                mapped.add(dot2list(x));
                return mapped;
            }
        } else if (a instanceof Var) {
            return a;
        } else if (a instanceof List) {
            List<Object> lst = (List<Object>) a;
            List<Object> mapped = new ArrayList<>();
            for (Object e : lst)
                mapped.add(dot2list(e));
            return mapped;
        } else {
            return a;
        }
    }

    @SuppressWarnings("unchecked")
    static boolean isDotList(Object a) {
        return a instanceof List && ((List<?>) a).size() > 0 && ".".equals(((List<Object>) a).get(0));
    }

    static Object pp(Object x) {
        return dot2list(toPterm(x));
    }

    /** iron(): return a fully-dereferenced nested structure. */
    static Object iron(Object a, int size) {
        if (size <= 0)
            return ".?.";
        Object[] d = deref(a);
        Object x = d[0];
        int t = (int) d[1];
        if (t == PAIR) {
            Object[] p = (Object[]) x;
            return new Object[] { iron(p[0], size - 1), iron(p[1], size - 1) };
        } else {
            return x;
        }
    }

    static Object iron(Object a) {
        return iron(a, 200);
    }

    // ---------------------------------------------------------------
    // Interpreter frame
    // ---------------------------------------------------------------
    static class Frame {
        int op;
        Object g1, g2; // For DO: (NewG, OldG). For others: G or null.
        int ttop, i, K;

        Frame(int op, Object g1, Object g2, int ttop, int i, int K) {
            this.op = op;
            this.g1 = g1;
            this.g2 = g2;
            this.ttop = ttop;
            this.i = i;
            this.K = K;
        }
    }

    // ---------------------------------------------------------------
    // step
    // ---------------------------------------------------------------
    static Frame step(Object G, int i, List<List<List<Object>>> code,
            List<Var> trail, int K) {

        Object[] dG = deref(G);
        Object Gd = dG[0];
        int tg = (int) dG[1];
        if ("true".equals(Gd) && tg == CONST) {
            return new Frame(DONE, G, null, trail.size(), code.size(), K);
        }

        // Check built-in
        Object[] builtIn = isBuiltIn(G);
        if (builtIn != null) {
            if (i > 0) {
                return new Frame(FAIL, null, null, trail.size(), i, K);
            }
            String name = (String) builtIn[3];
            if ("$cut".equals(name)) {
                Object Kvar = builtIn[0], Cont = builtIn[1];
                Object[] dk = deref(Kvar);
                int Kval = toNum(dk[0]) == (int) toNum(dk[0]) ? (int) toNum(dk[0]) : 0;
                return new Frame(CUT, Cont, G, trail.size(), code.size(), Kval);
            }

            Set<Integer> vids = new HashSet<>();
            if (handleBuiltIn(builtIn, trail, vids)) {
                Object[] dc = deref(builtIn[2]);
                Object cont = dc[0];
                int ct = (int) dc[1];
                if ("true".equals(cont) && ct == CONST) {
                    return new Frame(DONE, G, null, trail.size(), code.size(), K);
                }
                return new Frame(DO, cont, G, trail.size(), code.size(), K);
            } else {
                return new Frame(FAIL, null, null, trail.size(), code.size(), K);
            }
        }

        int ttop = trail.size();
        while (i < code.size()) {
            unwind(trail, ttop);
            List<List<Object>> clause = code.get(i);
            i++;
            List<Var> vars = new ArrayList<>();
            Set<Integer> vids = new HashSet<>();
            boolean broke = false;

            for (List<Object> rawInstr : clause) {
                List<Object> c = activate(rawInstr, vars, vids);
                String op = (String) c.get(0);

                switch (op) {
                    case "u": {
                        Object[] dold = deref(c.get(3));
                        Object old = dold[0];
                        int oldt = (int) dold[1];
                        if (oldt == VAR) {
                            ((Var) old).val = new Object[] { c.get(1), c.get(2) };
                        } else {
                            assert oldt == PAIR;
                            Object[] oldp = (Object[]) old;
                            if (!(unify(c.get(1), oldp[0], trail, vids) &&
                                    unify(c.get(2), oldp[1], trail, vids))) {
                                broke = true;
                            }
                        }
                        break;
                    }
                    case "b": {
                        Object[] dold = deref(c.get(3));
                        Object old = dold[0];
                        ((Var) old).val = new Object[] { c.get(1), c.get(2) };
                        break;
                    }
                    case "d": {
                        assert typeOf(c.get(1)) == VAR;
                        ((Var) c.get(1)).val = G;
                        break;
                    }
                    case "k": {
                        assert typeOf(c.get(1)) == VAR;
                        ((Var) c.get(1)).val = K;
                        break;
                    }
                    case "p": {
                        Object[] dcg = deref(c.get(1));
                        Object currentG = dcg[0];
                        int ctg = (int) dcg[1];
                        if ("true".equals(currentG) && ctg == CONST) {
                            return new Frame(DONE, G, null, ttop, i, K);
                        } else {
                            assert ctg == PAIR;
                            return new Frame(DO, currentG, G, ttop, i, K);
                        }
                    }
                }
                if (broke)
                    break;
            }
        }
        return new Frame(FAIL, null, null, ttop, i, K);
    }

    // ---------------------------------------------------------------
    // ensure_undo
    // ---------------------------------------------------------------
    static void ensureUndo(Object G, List<Frame> todo, int ttop, int i, int l, int K) {
        Frame instr = new Frame(UNDO, G, null, ttop, i, K);
        if (!todo.isEmpty()) {
            Frame top = todo.get(todo.size() - 1);
            if (top.op == UNDO && top.i == i && top.g1 == G && ttop >= top.ttop) {
                return;
            }
        }
        todo.add(instr);
    }

    // ---------------------------------------------------------------
    // interp - main trampoline loop
    // ---------------------------------------------------------------
    static void interp(List<List<List<Object>>> code, PrintStream out) {
        Object[] goalPair = getGoal();
        Object[] G0 = (Object[]) goalPair[0];
        Var answer = (Var) goalPair[1];

        int l = code.size();
        List<Frame> todo = new ArrayList<>();
        todo.add(new Frame(DO, G0, null, 0, l, 0));

        int ctr = 0, maxctr = 500000;
        int maxTrail = 0, maxTodo = 0;
        List<Var> trail = new ArrayList<>();

        while (ctr < maxctr && !todo.isEmpty()) {
            ctr++;
            maxTrail = Math.max(maxTrail, trail.size());
            maxTodo = Math.max(maxTodo, todo.size());
            Frame f = todo.remove(todo.size() - 1);

            switch (f.op) {
                case DO: {
                    Object newG = f.g1, oldG = f.g2;
                    if (f.i < l)
                        ensureUndo(oldG, todo, f.ttop, f.i, l, f.K);
                    int Knew = todo.size();
                    todo.add(step(newG, 0, code, trail, Knew));
                    break;
                }
                case DONE: {
                    Object result = iron(answer);
                    out.println("ANSWER " + (++answerCount) + ": " + formatResult(pp(answer)));
                    if (f.i < l)
                        ensureUndo(f.g1, todo, f.ttop, f.i, l, f.K);
                    break;
                }
                case UNDO: {
                    unwind(trail, f.ttop);
                    if (f.i < l)
                        todo.add(step(f.g1, f.i, code, trail, f.K));
                    break;
                }
                case CUT: {
                    Object newG = f.g1, oldG = f.g2;
                    // Trim todo stack
                    while (todo.size() > f.K)
                        todo.remove(todo.size() - 1);
                    Object[] dng = deref(newG);
                    if ("true".equals(dng[0]) && (int) dng[1] == CONST) {
                        out.println("ANSWER " + (++answerCount) + ": " + formatResult(pp(answer)));
                    } else {
                        int Knew = todo.size();
                        todo.add(step(newG, 0, code, trail, Knew));
                    }
                    break;
                }
                default: // FAIL
                    break;
            }
        }
        if (ctr == maxctr) {
            out.println("*** TOO MANY STEPS? " + ctr);
        }
        out.println("max_trail= " + maxTrail + " max_todo= " + maxTodo);
    }

    static int answerCount = 0;

    // ---------------------------------------------------------------
    // Result formatting
    // ---------------------------------------------------------------
    @SuppressWarnings("unchecked")
    static String formatResult(Object o) {
        return formatResult(o, false);
    }

    @SuppressWarnings("unchecked")
    static String formatResult(Object o, boolean insideList) {
        if (o == null)
            return "null";
        if (o instanceof Var)
            return ((Var) o).toString();
        if (o instanceof List) {
            List<Object> lst = (List<Object>) o;
            StringBuilder sb = new StringBuilder("[");
            for (int i = 0; i < lst.size(); i++) {
                if (i > 0)
                    sb.append(", ");
                sb.append(formatResult(lst.get(i), true));
            }
            sb.append("]");
            return sb.toString();
        }
        if (o instanceof Object[]) {
            Object[] arr = (Object[]) o;
            if (arr.length == 2) {
                return "(" + formatResult(arr[0], insideList) + ", " + formatResult(arr[1], insideList) + ")";
            }
            return Arrays.deepToString(arr);
        }
        if (insideList && o instanceof String) {
            return "'" + o + "'";
        }
        return o.toString();
    }

    // ---------------------------------------------------------------
    // Entry point
    // ---------------------------------------------------------------
    public static void main(String[] args) throws IOException {
        String fname;
        if (args.length < 1) {
            fname = "out/tnf_asm.txt";
        } else {
            fname = args[0];
        }
        List<List<List<Object>>> code = tload(fname);
        answerCount = 0;
        interp(code, System.out);
        System.out.println("TOTAL ANSWERS: " + answerCount);
    }
}
