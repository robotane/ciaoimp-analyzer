"""Hand-written vs generated specs: CiaoPP gas bounds of the entries.

Usage: python3 -m src.ciaopp_cost.compare_specs [--normalized] [contract ...]
Writes build/ciaopp_cost{,_normalized}_gen/ (generated specs and analyses) and
results/specs_generated_vs_hand{,_normalized}.txt.
"""
from __future__ import annotations

import sys
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path

from src import ciaopp_cost
from src.ciaopp_cost.genspec import generate
from src.pipeline.paths import PipelinePaths

ROOT = Path(__file__).resolve().parents[2]


def one(args):
    name, normalized = args
    paths = PipelinePaths(ROOT)
    input_dir, specs_dir, out_dir, _ = paths.ciaopp_cost_variant(normalized)
    model = paths.ciaopp_cost_model_dir
    gen_dir = out_dir.with_name(out_dir.name + "_gen")
    spec = gen_dir / "specs" / f"{name}.pl"
    spec.parent.mkdir(parents=True, exist_ok=True)
    typed_from = paths.executable_dir / f"{name}.pl" if normalized else None
    spec.write_text(generate(input_dir / f"{name}.pl", model, typed_from), encoding="utf-8")
    gen = ciaopp_cost.run_one(name, spec, input_dir / f"{name}.pl", model, gen_dir, "ciaosh")
    return name, gen, spec


import re

ENTRY_HEAD = re.compile(r"^:-\s*entry\s+(\w+)\(([^)]*)\)", re.M)


def positional(expr, names):
    """Rename the argument variables of a bound to #1, #2, ... (their positions)."""
    if expr is None:
        return None
    return re.sub(r"\b[A-Z_]\w*\b", lambda m: f"#{names.index(m.group(0)) + 1}"
                  if m.group(0) in names else m.group(0), expr)


def heads(spec: Path) -> dict[str, list[str]]:
    out = {}
    for pred, args in ENTRY_HEAD.findall(spec.read_text(encoding="utf-8")):
        out.setdefault(pred, [a.strip() for a in args.split(",")])
    return out


def bounds(res, spec: Path):
    h = heads(spec) if spec.exists() else {}
    return {b.pred: (positional(b.lb, h.get(b.pred, [])), positional(b.ub, h.get(b.pred, [])))
            for b in res.bounds} if res else {}


def parse_hand(results_file: Path) -> dict[str, dict[str, tuple]]:
    out, cur, pred = {}, None, None
    for line in results_file.read_text(encoding="utf-8").splitlines():
        if line.startswith("=== "):
            cur = out.setdefault(line.split()[1], {})
        elif cur is not None and "lb =" in line:
            pred = line.split()[0]
            cur[pred] = [line.split("lb =")[1].strip(), None]
        elif cur is not None and "ub =" in line and pred:
            cur[pred][1] = line.split("ub =")[1].strip()
            cur[pred] = tuple(cur[pred])
    return out


def main(argv):
    normalized = "--normalized" in argv
    names = [a for a in argv if not a.startswith("--")]
    paths = PipelinePaths(ROOT)
    input_dir, _, _, hand_file = paths.ciaopp_cost_variant(normalized)
    names = names or sorted(p.stem for p in input_dir.glob("*.pl"))
    hand = parse_hand(hand_file)
    specs_dir = paths.ciaopp_cost_variant(normalized)[1]
    for name, preds in hand.items():
        h = heads(specs_dir / f"{name}.pl") if (specs_dir / f"{name}.pl").exists() else {}
        for pred, (lb, ub) in preds.items():
            preds[pred] = (positional(lb, h.get(pred, [])), positional(ub, h.get(pred, [])))
    lines, same, diff = [], 0, 0
    with ProcessPoolExecutor(max_workers=3) as ex:
        for name, gen, spec in ex.map(one, [(n, normalized) for n in names]):
            g = bounds(gen, spec)
            h = hand.get(name, {})
            lines.append(f"=== {name} ({ciaopp_cost.status_of(gen)}) ===")
            for pred in sorted(set(g) | set(h)):
                hb, gb = h.get(pred), g.get(pred)
                tag = "same" if hb == gb else "DIFF"
                same += tag == "same"
                diff += tag == "DIFF"
                lines.append(f"  {tag} {pred:<20} hand lb={hb[0] if hb else '-'} ub={hb[1] if hb else '-'}")
                lines.append(f"       {'':<20} gen  lb={gb[0] if gb else '-'} ub={gb[1] if gb else '-'}")
            for e in gen.errors:
                lines.append(f"  {e}")
            print("\n".join(lines[-1 - 2 * len(set(g) | set(h)) - len(gen.errors):]), flush=True)
    lines.append(f"\n{same} identical bound pairs, {diff} different")
    out = ROOT / "results" / f"specs_generated_vs_hand{'_normalized' if normalized else ''}.txt"
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(lines[-1], out)


if __name__ == "__main__":
    main(sys.argv[1:])
