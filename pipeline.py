#!/usr/bin/env python3
"""Unified command-line entrypoint for the portable CiaoImp pipeline.

This script acts as the single launcher for all stages of the portable pipeline,
including running the full pipeline, running only the TNF stage, or running
a compiled ASM file directly.

Typical usage:
    # Run the full pipeline (default)
    python3 pipeline.py run blind_auction.pl
    # Or simply (defaulting to 'run'):
    python3 pipeline.py blind_auction.pl

    # Run only the TNF stage on normalized files
    python3 pipeline.py run-tnf simple_ponzi.pl

    # Execute a compiled ASM file directly through the TNF VM interpreter
    python3 pipeline.py run-asm data/source/auction_asm.txt
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse command-line arguments supporting subcommands with a default 'run' fallback."""
    parser = argparse.ArgumentParser(description="Unified CLI for the CiaoImp pipeline.")
    
    # Create subparsers
    subparsers = parser.add_subparsers(dest="subcommand", help="Subcommand to run")
    
    # Subcommand: run (the full pipeline)
    run_parser = subparsers.add_parser("run", help="Run the full pipeline (default)")
    run_parser.add_argument("inputs", nargs="*", help="Source .pl files or names under data/source")
    run_parser.add_argument("--no-caslog", action="store_true", help="Skip CasLog annotation and execution")
    run_parser.add_argument("--no-tnf", action="store_true", help="Skip BNF/ASM compilation and Java VM execution")
    run_parser.add_argument("--no-prolog-cafe", action="store_true", help="Skip Prolog Cafe Java translation and execution")
    
    # Subcommand: run-tnf
    tnf_parser = subparsers.add_parser("run-tnf", help="Run only the TNF stage on normalized files")
    tnf_parser.add_argument("inputs", nargs="*", help="Normalized .pl files or contract names")
    
    # Subcommand: run-asm
    asm_parser = subparsers.add_parser("run-asm", help="Execute a compiled ASM .txt file directly")
    asm_parser.add_argument("asm_file", help="Path to the compiled ASM .txt file")
    
    # Inject default 'run' subcommand if no subcommand is provided
    if not argv:
        argv = ["run"]
    elif argv[0] not in ("run", "run-tnf", "run-asm", "-h", "--help"):
        argv = ["run"] + argv
        
    return parser.parse_args(argv)


def run_asm_interpreter(root: Path, asm_file_path: str) -> int:
    """Execute a compiled ASM file using the tnf.py engine in tools/LogicTransformers/."""
    tnf_py = root / "tools/LogicTransformers/tnf.py"
    if not tnf_py.exists():
        print(f"Error: tnf.py not found at {tnf_py}", file=sys.stderr)
        return 1
        
    asm_file = Path(asm_file_path)
    if not asm_file.exists():
        print(f"Error: ASM file not found: {asm_file}", file=sys.stderr)
        return 1
        
    # Read tnf.py without the top-level interactive go() call
    try:
        lines = tnf_py.read_text(encoding="utf-8").rstrip().split('\n')
    except Exception as e:
        print(f"Error reading {tnf_py}: {e}", file=sys.stderr)
        return 1
        
    while lines and lines[-1].strip() in ('go()', '#utest()', '#gc.disable()', '#import gc', ''):
        lines.pop()
    src = '\n'.join(lines)
    
    ns: dict[str, any] = {}
    try:
        exec(compile(src, str(tnf_py), 'exec'), ns)
    except Exception as e:
        print(f"Error compiling/executing tnf.py: {e}", file=sys.stderr)
        return 1
        
    tload = ns.get('tload')
    interp = ns.get('interp')
    pp = ns.get('pp')
    
    if not (tload and interp and pp):
        print("Error: essential tnf.py functions (tload, interp, pp) not found.", file=sys.stderr)
        return 1
        
    try:
        code = tload(str(asm_file))
        ctr = 0
        for a, mtr, mtd in interp(code):
            ctr += 1
            print(f'ANSWER {ctr}: {pp(a)}')
        print(f'TOTAL ANSWERS: {ctr}')
    except Exception as e:
        print(f"Error executing ASM code: {e}", file=sys.stderr)
        return 1
    return 0


def run_tnf_stage(root: Path, inputs: list[str]) -> int:
    """Run only the TNF stage on normalized files."""
    from src.pipeline.paths import PipelinePaths
    from src.pipeline.runner import PipelineOptions, PipelineRunner
    
    paths = PipelinePaths(root)
    paths.ensure_dirs()
    
    # Resolve inputs to normalized name bases
    if not inputs:
        names = sorted(path.stem for path in paths.normalized_dir.glob("*.pl"))
    else:
        names = []
        for arg in inputs:
            path = Path(arg)
            base = path.stem
            if path.is_file() or (paths.normalized_dir / f"{base}.pl").is_file():
                names.append(base)
            else:
                print(f"  WARN: TNF input not found: {arg}", file=sys.stderr)
                
    if not names:
        print("No TNF input files found.", file=sys.stderr)
        return 1
        
    runner = PipelineRunner(paths, PipelineOptions(run_caslog=False, run_tnf=True))
    return runner.run_tnf_results(names)


def main(argv: list[str]) -> int:
    """Run the selected command and return exit code."""
    ns = parse_args(argv)
    root = Path(__file__).resolve().parent
    
    if ns.subcommand == "run-asm":
        return run_asm_interpreter(root, ns.asm_file)
        
    elif ns.subcommand == "run-tnf":
        return run_tnf_stage(root, ns.inputs)
        
    else: # ns.subcommand == "run"
        from src.pipeline.paths import PipelinePaths
        from src.pipeline.runner import PipelineOptions, PipelineRunner
        options = PipelineOptions(
            run_caslog=not ns.no_caslog,
            run_tnf=not ns.no_tnf,
            run_prolog_cafe=not ns.no_prolog_cafe
        )
        return PipelineRunner(PipelinePaths(root), options).run(ns.inputs)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

