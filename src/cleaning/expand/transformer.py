"""Per-clause CiaoPP→Prolog transformer with loop expansion and SSA threading."""
from __future__ import annotations

import re

from .text_utils import (
    M_ASSIGN, M_LOOP, M_BEFORE, M_AFTER,
    find_close, split_commas, strip_outer_parens, extract_functor, split_cons,
    skip_quoted,
)
from .normalize import (
    rewrite_ops, flatten_conj, find_assigns, convert_remaining_assigns,
)
from .parser import split_clause


class Transformer:
    """Transforms one clause at a time. Collects helper predicates in self.helpers."""

    def __init__(self):
        self.helpers: list[str] = []
        self.loop_idx = 0

    def transform(self, clause_text: str) -> str:
        head, body = split_clause(clause_text)
        if body is None:
            return clause_text

        body = strip_outer_parens(flatten_conj(strip_outer_parens(body)))
        head_vars = self._head_vars(head)

        defaults: dict[str, str | None] = {}
        body = self._extract_defaults(body, head_vars, defaults)
        state_vars = self._state_vars(body)
        body = self._expand_loops(body, head_vars)
        state_vars |= self._state_vars(body)
        body, _ = self._ssa_pass(body, state_vars, defaults)

        leftover = [(iv, ov) for iv, ov in defaults.items() if ov is not None]
        if leftover:
            wiring = ', '.join(f"({ov} = {iv})" for iv, ov in leftover)
            body = wiring + ', ' + body

        body = rewrite_ops(body)
        body = flatten_conj(body)
        body = self._cleanup(body)
        return f"{head} :-\n    {body}."

    # --- Head helpers ---

    def _head_vars(self, head: str) -> set[str]:
        _, args = extract_functor(head)
        return {a.strip() for a in args
                if re.match(r'^[A-Z_][A-Za-z0-9_]*$', a.strip())}

    def _state_vars(self, body: str) -> set[str]:
        b4 = set(re.findall(re.escape(M_BEFORE) + r'\(([A-Z_][A-Za-z0-9_]*)\)', body))
        af = set(re.findall(re.escape(M_AFTER) + r'\(([A-Z_][A-Za-z0-9_]*)\)', body))
        return b4 & af

    # --- Default extraction ---

    def _extract_defaults(self, body: str, head_vars: set[str],
                          defaults: dict) -> str:
        parts = split_commas(body)
        kept = []
        consumed = False
        for part in parts:
            if consumed:
                kept.append(part)
                continue
            stripped = strip_outer_parens(part)
            m = re.match(r'^([A-Z_][A-Za-z0-9_]*)\s*=\s*([A-Z_][A-Za-z0-9_]*)$', stripped)
            if m:
                out_v, in_v = m.group(1), m.group(2)
                if out_v in head_vars and in_v in head_vars and out_v != in_v:
                    defaults[in_v] = out_v
                    continue
            m2 = re.match(
                r'^_OP_UNIFY_\(\s*([A-Z_][A-Za-z0-9_]*)\s*,\s*([A-Z_][A-Za-z0-9_]*)\s*\)$',
                stripped)
            if m2:
                out_v, in_v = m2.group(1), m2.group(2)
                if out_v in head_vars and in_v in head_vars and out_v != in_v:
                    defaults[in_v] = out_v
                    continue
            inner_parts = split_commas(stripped)
            if len(inner_parts) > 1:
                recursed = self._extract_defaults(stripped, head_vars, defaults)
                kept.append(recursed)
                consumed = True
                continue
            kept.append(part)
            consumed = True
        return ', '.join(kept)

    # --- Loop expansion ---

    def _expand_loops(self, body: str, head_vars: set[str]) -> str:
        while M_LOOP in body:
            body = self._expand_one_loop(body, head_vars)
        return body

    def _expand_one_loop(self, body: str, head_vars: set[str]) -> str:
        idx = body.find(M_LOOP)
        j = idx + len(M_LOOP)
        while j < len(body) and body[j] in ' \t\n':
            j += 1
        if j >= len(body) or body[j] != '(':
            return body.replace(M_LOOP, "true", 1)
        close = find_close(body, j)
        if close == -1:
            return body

        args = split_commas(body[j + 1:close])
        if len(args) < 5:
            return body

        entry_var = args[0].strip()
        init_str = args[1].strip()
        cond_str = args[2].strip()
        step_str = args[3].strip()
        body_str = ','.join(args[4:]).strip()
        iter_var, list_source = self._parse_loop_init(init_str)
        numeric_loop = self._parse_numeric_loop(entry_var, init_str, cond_str, step_str)

        text_before = body[:idx]
        pre_assigns = {v: val for v, val, _ in find_assigns(text_before)}

        accumulators = []
        accu_inits = {}
        body_updates = {v for v, _, _ in find_assigns(body_str)}
        for v, val in pre_assigns.items():
            if v == iter_var:
                continue
            used = re.search(r'(?<![A-Za-z0-9_])' + re.escape(v)
                             + r'(?![A-Za-z0-9_])', body_str)
            if v in body_updates or used:
                accumulators.append(v)
                accu_inits[v] = val

        before_in = set(re.findall(
            re.escape(M_BEFORE) + r'\(([A-Z_][A-Za-z0-9_]*)\)', body_str))
        after_in = set(re.findall(
            re.escape(M_AFTER) + r'\(([A-Z_][A-Za-z0-9_]*)\)', body_str))
        state_accus = before_in & after_in
        for sv in sorted(state_accus):
            if sv not in accumulators and sv != iter_var:
                accumulators.append(sv)
                accu_inits[sv] = sv

        markers = {M_ASSIGN, M_LOOP, M_BEFORE, M_AFTER}
        body_vars = set(re.findall(r'(?<![A-Za-z0-9_])([A-Z][A-Za-z0-9_]*)(?![A-Za-z0-9_])',
                                   body_str))
        body_vars |= set(re.findall(r'(?<![A-Za-z0-9_])(_[A-Za-z0-9_]+)(?![A-Za-z0-9_])',
                                    body_str))
        body_vars -= markers
        before_vars = set(re.findall(r'(?<![A-Za-z0-9_])([A-Z][A-Za-z0-9_]*)(?![A-Za-z0-9_])',
                                     text_before))
        before_vars |= set(re.findall(r'(?<![A-Za-z0-9_])(_[A-Za-z0-9_]+)(?![A-Za-z0-9_])',
                                      text_before))
        before_vars -= markers
        scope_vars = head_vars | before_vars
        external = sorted((body_vars - set(accumulators) - {entry_var, iter_var})
                          & scope_vars)

        list_acc = self._pick_list_cons_acc(accumulators, accu_inits, body_str)
        scalar_accs = [a for a in accumulators if a != list_acc]

        self.loop_idx += 1
        name = f"loop_aux_{self.loop_idx}"

        if numeric_loop is not None:
            helper = self._gen_numeric_helper(
                name, entry_var, numeric_loop, external, scalar_accs,
                state_accus, body_str
            )
        else:
            helper = self._gen_helper(
                name, entry_var, external, scalar_accs, state_accus, body_str,
                list_acc=list_acc)
        self.helpers.append(helper)

        init_vals, out_vals = [], []
        for a in accumulators:
            if a in state_accus:
                init_vals.append(f"{M_BEFORE}({a})")
                out_vals.append(f"{M_AFTER}({a})")
            else:
                init_vals.append(accu_inits.get(a, a))
                out_vals.append(a)

        if numeric_loop is not None:
            start_expr = numeric_loop["start_expr"]
            bound_expr = numeric_loop["bound_expr"]
            call_args = [start_expr, bound_expr] + external + init_vals + out_vals
        elif list_acc is not None:
            args_out = []
            for a in accumulators:
                if a == list_acc:
                    args_out.append(a)
                else:
                    if a in state_accus:
                        args_out.append(f"{M_AFTER}({a})")
                    else:
                        args_out.append(a)
            call_args = [list_source] + external
            for a in scalar_accs:
                if a in state_accus:
                    call_args.append(f"{M_BEFORE}({a})")
                else:
                    call_args.append(accu_inits.get(a, a))
            call_args.append(list_acc)
            for a in scalar_accs:
                if a in state_accus:
                    call_args.append(f"{M_AFTER}({a})")
                else:
                    call_args.append(a)
        else:
            call_args = [list_source] + external + init_vals + out_vals

        call_text = f"{name}({', '.join(call_args)})"

        new_before = text_before
        for v in accumulators:
            new_before = self._remove_assign(new_before, v)
        if iter_var:
            new_before = self._remove_assign(new_before, iter_var)

        trimmed = new_before.rstrip().rstrip(',').rstrip()
        needs_comma = bool(trimmed) and not trimmed.endswith(('->', ';', '(', ':-'))
        return trimmed + (', ' if needs_comma else '') + call_text + body[close + 1:]

    def _parse_loop_init(self, init_str: str) -> tuple[str | None, str | None]:
        s = init_str.strip()
        if s.startswith(M_ASSIGN):
            _, args = extract_functor(s)
            if len(args) == 2:
                return (args[0].strip(), args[1].strip())
        s = strip_outer_parens(s)
        m = re.match(r'^([A-Z_][A-Za-z0-9_]*)\s*=\s*(.+)$', s)
        if m:
            return (m.group(1), m.group(2).strip())
        return (None, None)

    def _parse_numeric_loop(self, entry_var: str, init_str: str,
                            cond_str: str, step_str: str) -> dict | None:
        init_parts = split_commas(strip_outer_parens(init_str))
        cond_parts = split_commas(strip_outer_parens(cond_str))

        init_eq: dict[str, str] = {}
        for part in init_parts:
            m = re.match(r'^([A-Z_][A-Za-z0-9_]*)\s*=\s*(.+)$', part)
            if m:
                init_eq[m.group(1)] = m.group(2).strip()

        init_assigns = {v: val for v, val, _ in find_assigns(init_str)}
        if len(init_assigns) != 1:
            return None

        current_var, start_expr = next(iter(init_assigns.items()))

        bound_ref = None
        for part in cond_parts:
            m_eq = re.match(
                r'^([A-Z_][A-Za-z0-9_]*)\s*=\s*([A-Z_][A-Za-z0-9_]*)$', part
            )
            if m_eq:
                left, right = m_eq.group(1), m_eq.group(2)
                if left == entry_var and right == current_var:
                    continue
                if right == entry_var and left == current_var:
                    continue

            m_cmp = re.match(
                r'^([A-Z_][A-Za-z0-9_]*)\s*=<\s*([A-Z_][A-Za-z0-9_]*)$', part
            )
            if m_cmp:
                left, right = m_cmp.group(1), m_cmp.group(2)
                if left == current_var:
                    bound_ref = right
                    break

        if bound_ref is None:
            return None

        bound_expr = init_eq.get(bound_ref, bound_ref)

        step_assigns = {v: val for v, val, _ in find_assigns(step_str)}
        step_is: dict[str, str] = {}
        for lhs, rhs in re.findall(
            r'([A-Z_][A-Za-z0-9_]*)\s+is\s+([^,()]+(?:\([^)]*\))?[^,()]*)', step_str
        ):
            step_is[lhs] = rhs.strip()

        def resolve_step(expr: str, seen: set[str] | None = None) -> str:
            seen = set() if seen is None else seen
            atom = expr.strip()
            if not re.match(r'^[A-Z_][A-Za-z0-9_]*$', atom):
                return atom
            if atom in seen:
                return atom
            seen.add(atom)
            if atom in step_assigns:
                return resolve_step(step_assigns[atom], seen)
            if atom in step_is:
                return resolve_step(step_is[atom], seen)
            return atom

        next_expr = resolve_step(step_assigns.get(current_var, current_var))
        if next_expr == current_var:
            return None

        next_expr = re.sub(
            r'(?<![A-Za-z0-9_])' + re.escape(current_var) + r'(?![A-Za-z0-9_])',
            entry_var,
            next_expr,
        )
        return {
            "current_var": current_var,
            "start_expr": start_expr,
            "bound_expr": bound_expr,
            "next_expr": next_expr,
        }

    def _remove_assign(self, text: str, var: str) -> str:
        out = text
        while True:
            hit = None
            for v, _val, span in find_assigns(out):
                if v == var:
                    hit = span
                    break
            if hit is None:
                return out
            start, end = hit
            while start > 0 and out[start - 1] in ' \t':
                start -= 1
            if start > 0 and out[start - 1] == ',':
                start -= 1
            out = out[:start] + out[end:]

    # --- Accumulator classification ---

    def _pick_list_cons_acc(self, accumulators: list[str],
                            inits: dict[str, str], body_str: str) -> str | None:
        candidates = []
        for acc in accumulators:
            init = inits.get(acc, '').strip()
            if init != '[]':
                continue
            assigns_to_acc = [(v, val, sp) for v, val, sp in find_assigns(body_str)
                              if v == acc]
            if not assigns_to_acc:
                continue
            ok = True
            for _, val, _ in assigns_to_acc:
                pair = split_cons(val)
                if pair is None or pair[1] != acc:
                    ok = False
                    break
            if not ok:
                continue
            body_scrub = body_str
            for _, val, sp in assigns_to_acc:
                body_scrub = body_scrub[:sp[0]] + (' ' * (sp[1] - sp[0])) + body_scrub[sp[1]:]
            if re.search(r'(?<![A-Za-z0-9_])' + re.escape(acc) + r'(?![A-Za-z0-9_])',
                         body_scrub):
                continue
            candidates.append(acc)
        return candidates[0] if len(candidates) == 1 else None

    # --- Helper generation ---

    def _gen_helper(self, name: str, entry_var: str, ext_params: list[str],
                    scalar_accs: list[str], state_accus: set[str],
                    body_str: str, list_acc: str | None = None) -> str:
        s_in = [f"{a}_In" for a in scalar_accs]
        s_out = [f"{a}_Out" for a in scalar_accs]

        list_base = ['[]'] if list_acc else []
        list_rec = ['___Out'] if list_acc else []
        list_call = ['___RestOut'] if list_acc else []

        base_ext = ['_' + e for e in ext_params]
        base_params = base_ext + s_in + list_base + s_out
        base_unifs = [f"{s_out[i]} = {s_in[i]}" for i in range(len(scalar_accs))]
        if base_params:
            sig = f"{name}([], {', '.join(base_params)})"
            base = (f"{sig} :-\n    {', '.join(base_unifs)}."
                    if base_unifs else f"{sig}.")
        else:
            base = f"{name}([])."

        rec_params = ext_params + s_in + list_rec + s_out
        rec_head = f"{name}([{entry_var}|___Rest], {', '.join(rec_params)})"

        body = self._prepare_body(body_str, scalar_accs, state_accus, list_acc)

        rec_scalar = [f"{a}_Mid" if f"{a}_Mid" in body else f"{a}_In"
                      for a in scalar_accs]
        rec_call = (f"{name}(___Rest, "
                    + ', '.join(ext_params + rec_scalar + list_call + s_out)
                    + ")")
        return f"{base}\n{rec_head} :-\n    {body},\n    {rec_call}."

    def _gen_numeric_helper(self, name: str, entry_var: str, numeric_loop: dict,
                            ext_params: list[str], scalar_accs: list[str],
                            state_accus: set[str], body_str: str) -> str:
        bound_var = "___Bound"
        s_in = [f"{a}_In" for a in scalar_accs]
        s_out = [f"{a}_Out" for a in scalar_accs]

        rec_params = [bound_var] + ext_params + s_in + s_out
        rec_head = f"{name}({entry_var}, {', '.join(rec_params)})"
        base_head = f"{name}({entry_var}, {', '.join(rec_params)})"

        base_unifs = [f"{s_out[i]} = {s_in[i]}" for i in range(len(scalar_accs))]
        base_guard = f"{entry_var} > {bound_var}"
        if base_unifs:
            base = f"{base_head} :-\n    {base_guard},\n    {', '.join(base_unifs)}."
        else:
            base = f"{base_head} :-\n    {entry_var} > {bound_var}."

        body = self._prepare_body(body_str, scalar_accs, state_accus)
        body_call = f"({body})" if ('->' in body or ';' in body) else body
        rec_scalar = [f"{a}_Mid" if f"{a}_Mid" in body else f"{a}_In"
                      for a in scalar_accs]
        next_expr = numeric_loop["next_expr"]
        rec_call = (
            f"{name}(___Next, "
            + ', '.join([bound_var] + ext_params + rec_scalar + s_out)
            + ")"
        )
        rec = (
            f"{rec_head} :-\n"
            f"    {entry_var} =< {bound_var},\n"
            f"    {body_call},\n"
            f"    ___Next is {next_expr},\n"
            f"    {rec_call}."
        )
        return f"{base}\n{rec}"

    # --- Body preparation ---

    def _prepare_body(self, body_str: str, scalar_accs: list[str],
                      state_accus: set[str], list_acc: str | None = None) -> str:
        body = strip_outer_parens(body_str)
        pure_scalars = [a for a in scalar_accs if a not in state_accus]

        if list_acc:
            spans = [(sp, val) for v, val, sp in find_assigns(body) if v == list_acc]
            for (start, end), val in sorted(spans, reverse=True):
                pair = split_cons(val)
                head_elem = pair[0] if pair else val
                body = body[:start] + f"(___Out = [{head_elem}|___RestOut])" + body[end:]

        for acc in pure_scalars:
            body = self._replace_acc_assign(body, acc, f"{acc}_Mid")

        if state_accus:
            initial_current = {a: f"{a}_In" for a in state_accus}
            body, final_current = self._ssa_pass(
                body, state_vars=set(state_accus), defaults={},
                initial_current=initial_current)
            for a in state_accus:
                present = re.findall(
                    r'(?<![A-Za-z0-9_])' + re.escape(a) + r'_s(\d+)(?![A-Za-z0-9_])',
                    body)
                if present:
                    max_n = max(int(x) for x in present)
                    body = re.sub(
                        r'(?<![A-Za-z0-9_])' + re.escape(a)
                        + r'_s' + str(max_n) + r'(?![A-Za-z0-9_])',
                        f"{a}_Mid", body)

        for acc in pure_scalars:
            body = re.sub(
                r'(?<![A-Za-z0-9_])' + re.escape(acc)
                + r'(?![A-Za-z0-9_])(\s*)=(?![=<\\])',
                f"{acc}_Mid\\1=", body)
        for acc in pure_scalars:
            body = re.sub(
                r'(?<![A-Za-z0-9_])' + re.escape(acc) + r'(?![A-Za-z0-9_])',
                f"{acc}_In", body)
        for acc in pure_scalars:
            body = body.replace(f"{acc}_In_Mid", f"{acc}_Mid")

        body = rewrite_ops(body)

        pairs = [(f"{a}_Mid", f"{a}_In") for a in pure_scalars]
        for a in state_accus:
            pairs.append((f"{a}_Mid", f"{a}_In"))
        if list_acc:
            pairs.append(("___Out", "___RestOut"))
        body = self._fix_else_fallbacks(body, pairs)
        body = convert_remaining_assigns(body)
        body = self._isolate_top_level_if(body)
        return body

    def _isolate_top_level_if(self, text: str) -> str:
        def find_top_level_if(s: str) -> tuple[int, int] | None:
            dp = db = 0
            i = 0
            arrow = semi = -1
            while i < len(s):
                c = s[i]
                if c == "'":
                    i = skip_quoted(s, i)
                    continue
                if c == '(':
                    dp += 1
                elif c == ')':
                    dp -= 1
                elif c == '[':
                    db += 1
                elif c == ']':
                    db -= 1
                elif s.startswith('->', i) and dp == 0 and db == 0 and arrow == -1:
                    arrow = i
                    i += 2
                    continue
                elif c == ';' and dp == 0 and db == 0 and arrow != -1:
                    semi = i
                    break
                i += 1
            if arrow != -1 and semi != -1:
                return (arrow, semi)
            return None

        span = find_top_level_if(text)
        if span is None:
            return text

        arrow, semi = span
        antecedent = text[:arrow].strip()
        then_part = text[arrow + 2:semi].strip()
        else_part = text[semi + 1:].strip()

        ante_parts = split_commas(antecedent)
        if len(ante_parts) > 1:
            prefix = ', '.join(ante_parts[:-1]).strip()
            ante_core = ante_parts[-1].strip()
            return f"{prefix}, (({ante_core} -> {then_part} ; {else_part}))"
        return f"(({antecedent} -> {then_part} ; {else_part}))"

    def _replace_acc_assign(self, text: str, acc: str, new_name: str) -> str:
        spans = [(sp, val) for v, val, sp in find_assigns(text) if v == acc]
        for (start, end), val in sorted(spans, reverse=True):
            text = text[:start] + f"({new_name} = {val})" + text[end:]
        return text

    def _fix_else_fallbacks(self, text: str,
                             pairs: list[tuple[str, str]]) -> str:
        i = 0
        while i < len(text):
            if text[i] == ';':
                j = i + 1
                while j < len(text) and text[j] in ' \t\n':
                    j += 1
                if (text[j:j + 4] == 'true'
                        and (j + 4 >= len(text) or text[j + 4] in ') \t\n,')):
                    fb = ', '.join(f"({nv} = {ov})" for nv, ov in pairs)
                    text = text[:j] + fb + text[j + 4:]
                    i = j + len(fb)
                    continue
                if text[j] == '(':
                    close = find_close(text, j)
                    if close != -1:
                        else_content = text[j + 1:close]
                        missing = [f"({nv} = {ov})" for nv, ov in pairs
                                   if nv not in else_content]
                        if missing:
                            ins = ', ' + ', '.join(missing)
                            text = text[:close] + ins + text[close:]
                            i = close + len(ins) + 1
                            continue
            i += 1
        return text

    # --- SSA pass ---

    def _ssa_pass(self, body: str, state_vars: set[str], defaults: dict,
                  initial_current: dict | None = None) -> tuple[str, dict]:
        versions: dict[str, int] = {}
        current = dict(initial_current) if initial_current else {}
        bound: set[str] = set()
        for v, val in current.items():
            if val != v:
                bound.add(v)
                versions[v] = 0
        branch_stack: list[dict] = []
        paren_depth = 0

        def cur(v: str) -> str:
            return current.get(v, v)

        def fresh(v: str) -> str:
            versions[v] = versions.get(v, 0) + 1
            sfx = 's' if v in state_vars else 'v'
            nm = f"{v}_{sfx}{versions[v]}"
            current[v] = nm
            bound.add(nm)
            return nm

        def subst(text: str) -> str:
            for v in sorted(current.keys(), key=len, reverse=True):
                if current[v] != v:
                    text = re.sub(
                        r'(?<![A-Za-z0-9_])' + re.escape(v) + r'(?![A-Za-z0-9_])',
                        current[v], text)
            return text

        out: list[str] = []
        i = 0
        n = len(body)
        while i < n:
            if body.startswith(M_ASSIGN, i):
                j = i + len(M_ASSIGN)
                while j < n and body[j] in ' \t\n':
                    j += 1
                if j < n and body[j] == '(':
                    close = find_close(body, j)
                    if close != -1:
                        args = split_commas(body[j + 1:close])
                        if len(args) >= 2:
                            v = args[0].strip()
                            val = subst(','.join(args[1:]).strip())
                            if v in defaults and defaults[v] is not None:
                                out.append(f"({defaults[v]} = {val})")
                                defaults[v] = None
                            elif v in bound:
                                nv = fresh(v)
                                out.append(f"({nv} = {val})")
                            else:
                                out.append(f"({v} = {val})")
                                bound.add(v)
                                current[v] = v
                                versions[v] = 0
                            i = close + 1
                            continue

            if body.startswith(M_BEFORE, i):
                j = i + len(M_BEFORE)
                if j < n and body[j] == '(':
                    close = find_close(body, j)
                    if close != -1:
                        sv = body[j + 1:close].strip()
                        out.append(cur(sv))
                        i = close + 1
                        continue

            if body.startswith(M_AFTER, i):
                j = i + len(M_AFTER)
                if j < n and body[j] == '(':
                    close = find_close(body, j)
                    if close != -1:
                        sv = body[j + 1:close].strip()
                        out.append(fresh(sv))
                        i = close + 1
                        continue

            if body[i] == '(':
                paren_depth += 1
                out.append('(')
                i += 1
                continue

            if body[i] == ')':
                if (branch_stack
                        and branch_stack[-1].get('kind') == 'ELSE'
                        and branch_stack[-1].get('depth') == paren_depth):
                    frame = branch_stack.pop()
                    sv_cur = frame['sv_cur']
                    then_cur = frame['then_cur']
                    then_def = frame['then_def']
                    sv_def = frame['sv_def']
                    semi_pos = frame['semi_pos']
                    then_wiring: list[str] = []
                    else_wiring: list[str] = []
                    keys = set(then_cur) | set(current) | set(sv_cur)
                    for v in keys:
                        orig = sv_cur.get(v, v)
                        t = then_cur.get(v, orig)
                        e = current.get(v, orig)
                        if t == e:
                            continue
                        merged = fresh(v)
                        then_wiring.append(f", ({merged} = {t})")
                        else_wiring.append(f", ({merged} = {e})")
                    for iv, orig_out in sv_def.items():
                        if orig_out is None:
                            continue
                        t_consumed = then_def.get(iv) is None
                        e_consumed = defaults.get(iv) is None
                        if t_consumed and not e_consumed:
                            else_wiring.append(f", ({orig_out} = {iv})")
                            defaults[iv] = None
                        elif e_consumed and not t_consumed:
                            then_wiring.append(f", ({orig_out} = {iv})")
                    if then_wiring:
                        out.insert(semi_pos, ''.join(then_wiring))
                    if else_wiring:
                        out.append(''.join(else_wiring))
                paren_depth -= 1
                out.append(')')
                i += 1
                continue

            if body[i:i + 2] == '->':
                branch_stack.append({
                    'kind': 'THEN',
                    'sv_ver': dict(versions),
                    'sv_cur': dict(current),
                    'sv_bnd': set(bound),
                    'sv_def': dict(defaults),
                    'depth': paren_depth,
                })
                out.append('->')
                i += 2
                continue

            if body[i] == ';':
                if (branch_stack
                        and branch_stack[-1].get('kind') == 'THEN'
                        and branch_stack[-1].get('depth') == paren_depth):
                    frame = branch_stack.pop()
                    sv_ver = frame['sv_ver']
                    sv_cur = frame['sv_cur']
                    sv_bnd = frame['sv_bnd']
                    sv_def = frame['sv_def']
                    then_cur = dict(current)
                    then_def = dict(defaults)
                    j = i + 1
                    while j < n and body[j] in ' \t\n':
                        j += 1
                    if (body[j:j + 4] == 'true'
                            and (j + 4 >= n or body[j + 4] in ') \t\n,')):
                        fb = []
                        for v in then_cur:
                            tn = then_cur[v]
                            orig = sv_cur.get(v, v)
                            if tn != orig:
                                fb.append(f"({tn} = {orig})")
                        for iv in sv_def:
                            if sv_def[iv] is not None and then_def.get(iv) is None:
                                fb.append(f"({sv_def[iv]} = {iv})")
                        out.append('; ' + (', '.join(fb) if fb else 'true'))
                        i = j + 4
                        continue
                    current.clear()
                    current.update(sv_cur)
                    bound.clear()
                    bound.update(sv_bnd)
                    defaults.clear()
                    defaults.update(sv_def)
                    semi_pos = len(out)
                    out.append(';')
                    branch_stack.append({
                        'kind': 'ELSE',
                        'sv_ver': sv_ver,
                        'sv_cur': sv_cur,
                        'sv_bnd': sv_bnd,
                        'sv_def': sv_def,
                        'then_cur': then_cur,
                        'then_def': then_def,
                        'semi_pos': semi_pos,
                        'depth': paren_depth,
                    })
                    i += 1
                    continue
                out.append(';')
                i += 1
                continue

            m = re.match(r'loop_aux_\d+\(', body[i:])
            if m:
                pp = i + m.end() - 1
                close = find_close(body, pp)
                if close != -1:
                    for a in split_commas(body[pp + 1:close]):
                        a = a.strip()
                        if re.match(r'^[A-Z_][A-Za-z0-9_]*$', a):
                            bound.add(a)
                            if a not in current:
                                current[a] = a
                                versions[a] = 0

            matched = False
            for v in sorted(current.keys(), key=len, reverse=True):
                if current[v] != v and body.startswith(v, i):
                    end = i + len(v)
                    before_ok = (i == 0 or not (body[i - 1].isalnum() or body[i - 1] == '_'))
                    after_ok = (end >= n or not (body[end].isalnum() or body[end] == '_'))
                    if before_ok and after_ok:
                        out.append(current[v])
                        i = end
                        matched = True
                        break
            if matched:
                continue

            out.append(body[i])
            i += 1

        body = ''.join(out)

        tail_wiring: list[str] = []
        for sv in state_vars:
            if sv in defaults and defaults[sv] is not None:
                final = cur(sv)
                if final != sv:
                    tail_wiring.append(f"({defaults[sv]} = {final})")
                    defaults[sv] = None
        if tail_wiring:
            if '->' in body or ';' in body:
                body = f"({body})"
            for w in tail_wiring:
                body += f", {w}"
        return body, current

    # --- Cleanup ---

    def _cleanup(self, body: str) -> str:
        body = re.sub(r',\s*,', ',', body)
        body = re.sub(r'^\s*,\s*', '', body)
        body = re.sub(r',\s*$', '', body)
        body = re.sub(r'\(true,\s*', '(', body)
        body = re.sub(r',\s*true\)', ')', body)
        body = re.sub(
            r'\(\(([A-Z_][A-Za-z0-9_]*)\s*(=|is|==|\\==|>|<|>=|=<)\s*([^()]+)\)\)',
            r'(\1 \2 \3)', body)
        body = re.sub(r"'([a-z_][a-z_0-9]*)'", r'\1', body)
        return body.strip()
