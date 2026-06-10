# LogicTransformers Local Fork

This directory is the active, modified LogicTransformers fork used by the
CiaoMoka stage project. It is not a clean upstream copy.

Upstream repository:

- https://github.com/ptarau/LogicTransformers

## Purpose

LogicTransformers compiles Horn-clause Prolog programs to lightweight assembler
forms, then executes the generated code on small VMs. In this fork, the Python
TNF VM is used to run smart-contract programs produced by the CiaoMoka pipeline
and to compare practical execution behavior with CasLog complexity results.

The usual flow is:

```text
contract Prolog source -> tnf.pro -> out/*_asm.txt -> tnf.py VM
```

## Main Local Changes

Compared with the upstream `ptarau/LogicTransformers` repository, this fork
adds project-specific smart contract programs, generated assembler outputs,
benchmark tooling, and runtime support needed by the contract examples.

- `tnf.pro` now rewrites Prolog cuts (`!`) into `'$cut'(K)`, emits
  `p_dispatch/2`, and writes a `k` assembler instruction so the VM can track
  cut scopes.
- `tnf.py` now supports `CUT` in the trampoline, choicepoint pruning through
  saved continuation indexes, and additional built-ins: `is`, `is_`, `>`,
  `>=`, `<`, `=<`, `\=`, `\==`, and `=`.
- `progs/` contains CiaoMoka-derived contracts such as `simple_ponzi.pro`,
  `auction.pro`, `ballot.pro`, `distributor.pro`, and `tictactoe.pro`, plus
  focused runtime tests like `test_cut.pro` and `test_lists.pro`.
- `benchmark/` contains SWI-Prolog and Python benchmark harnesses for O(1),
  O(N), and fixed-size contract scenarios.
- `out/` contains generated assembler outputs for both original examples and
  smart-contract inputs. Treat these as generated artifacts.
- `simplify_set_bal.py` is a helper script for simplifying selected source
  contract patterns before transformation.

## `tnf.pro` Changes

The local `tnf.pro` changes are concentrated on making the generated TNF code
usable for smart-contract execution, not only for pure Horn-clause examples.

- Cut preprocessing was added with `preprocess_cut/3`, `contains_cut/1`,
  `replace_cuts/3`, `body_to_list/2`, and `list_to_body/2`. A source cut
  such as `!` is rewritten to `'$cut'(K)` before TNF generation.
- `cls2tnf/2` now emits clauses headed by `p_dispatch(K, V)` instead of the
  original one-argument `p(V)`. The extra `K` argument carries the cut scope.
- The generated Prolog runtime now includes `p(A) :-
  prolog_current_choice(K), p_dispatch(K, A)`, so each dispatch captures the
  current choicepoint before trying alternative clauses.
- `tcompile/2` emits special `p_dispatch/2` clauses for built-ins used by the
  contract programs: arithmetic evaluation with `is`, comparisons (`>`, `>=`,
  `<`, `=<`), disequality (`\=`, `\==`), unification (`=`), and cut via
  `prolog_cut_to/1`.
- `to_tasm1/2` and `to_tasm/2` now serialize the extra cut variable by writing
  a `k` instruction after the existing `d` instruction. The Python VM consumes
  this instruction to restore the correct continuation boundary.
- `call_tnf/1` was adapted to the new `p_dispatch(_, _V)` clause shape so
  direct Prolog-side TNF calls still work with the modified representation.

## Directory Overview

- `tnf.pro`: SWI-Prolog transformer from source clauses to TNF and assembler.
- `tnf.py`: Python VM/interpreter for `out/tnf_asm.txt` and other assembler
  files.
- `progs/`: source Prolog programs consumed by the transformer.
- `out/`: generated `*_asm.pro` and `*_asm.txt` files.
- `benchmark/`: benchmark harnesses and plotting helpers.
- `rapport_tarau/`: notes and report material about the transformation theory.
- Upstream reference: `https://github.com/ptarau/LogicTransformers`

## Usage

Run from this directory:

```bash
./go simple_ponzi
```

This removes the previous `out/tnf_asm.*`, compiles
`progs/simple_ponzi.pro` through `tnf.pro`, then runs the generated assembler
with `python3 -O tnf.py`.

To run another program, pass the base name without `.pro`:

```bash
./go test_cut
./go ballot
```

To benchmark the contract suite:

```bash
cd benchmark
bash run_bench.sh
python3 bench_py_tnf.py
```

## Maintenance Notes

Do not overwrite this directory with a fresh upstream checkout without
reviewing the local changes first: modifications in `tnf.pro`, `tnf.py`,
`progs/`, and `benchmark/` are required by the stage project.

Before committing changes, check whether files in `out/`, `__pycache__/`, and
large logs such as `execution_results.log` are intended artifacts or local run
outputs. Prefer documenting reproducible commands over committing transient
benchmark output.
