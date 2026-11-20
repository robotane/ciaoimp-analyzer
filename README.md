# hotmoka-gas-bounds

Static upper bounds on the gas consumed by [Hotmoka](https://github.com/Hotmoka/hotmoka)
smart contracts, checked against the gas measured on a real Hotmoka node.

Each Java (Takamaka) contract is modelled in a small imperative DSL embedded in Ciao Prolog.
A Ciao package charges every Hotmoka primitive (storage tree access, field write, object
creation, event, payable call, ...) its gas cost, and adds the costs that the Java code does
not show (first read of a storage object, field writes, payable transfers). Then:

1. **CiaoPP** (resource analysis) infers, for every public method, an upper bound on its gas
   as a closed-form function of the sizes of the contract state (e.g.
   `32986*log(2,length(Bids0)+1)+139460`);
2. **CasLog** infers the asymptotic complexity class (O(1), O(n), O(n^2), ...) of the same
   methods from the same source;
3. the bounds are evaluated at the sizes used by a benchmark and compared with the gas measured
   for the corresponding Java methods on a Hotmoka 1.12.3 node: a bound is valid if no measured
   point lies above it.

```
dsl/<contract>.pl ──┬── CiaoPP (eterms, shfr, nf, det, resources) ──> gas bound ub(n) ─┐
 + hotmoka_gas.pl   │                                                                   ├─> tableau.csv / .md
   (gen_model.py)   └── caslog_prep (ciaopp -T) ──> CasLog ──────────> O() class ───────┤
                                                                                        │
bench/ (Java contracts, moka node) ──> data/bench_*.csv (measured gas) ─────────────────┘
```

## Repository layout

```
pipeline/            single command and its modules
  run_pipeline.py    the whole pipeline (gas model, CiaoPP, CasLog, comparison, table)
  gen_model.py       constants -> dsl/hotmoka_gas.pl
  run_ciaopp.py      CiaoPP, one contract at a time, memory capped
  ciaopp_cost.py     one CiaoPP resource analysis, extraction of the gas bounds
  gas_data.py        measured gas (CSV), growth class, evaluation of a bound
  reference_bounds.json   expected CiaoPP bounds (15 contracts)
dsl/                 the DSL and the contracts
  hotmoka.pl         executable semantics of the Hotmoka primitives
  hotmoka_tr.pl      translation: implicit costs (load, store, payable), require, field syntax
  hotmoka_gas.pl.in  gas cost model of the primitives (template, constants @C_*@)
  *.pl               14 benchmark contracts + tontine.pl (witness contract)
caslog_prep/         DSL contract -> CasLog input (mode/measure inferred by CiaoPP)
data/                constants, operation map, measured gas
  constants_moka_sur.json   cost-model constants (default; safe tree constants)
  constants_moka.json       previous constants, input of the tree derivation
  bigint_ops.json           integer sizes in the bounds of the contracts that use big_* (see below)
  direct_ops.json           measured operation -> DSL predicate and argument sizes as functions of n
  bench_moka.csv            gas measured for the 14 contracts (36 operations, 3312 sizes)
  bench_tontine.csv         gas measured for the witness contract (4 operations, 131 sizes)
costmodel/tree/      derivation of the worst-case constants of the storage trees
bench/               (optional) Java contracts, moka driver and script to re-measure the gas
docs/provenance.md   origin of the data files
```

## Requirements

To reproduce the bounds and the comparison (no Java or Docker needed):

- **Ciao Prolog with CiaoPP and its resource analysis**, version 1.25 (development). The results
  were obtained with the development trees of Ciao (`v1.25.0-m1-325-g18d409bb`, 2026-10-27),
  `ciaopp` (`0e55764`), `ciaopp_cost` (`a358def`), `ciaomath` (`7dd2820`) and `typeslib`
  (`8d14f23`). `ciaopp` and `ciaosh` must be on the `PATH`.
  **Warning:** the resource-analysis component `ciaopp_cost` currently comes from the IMDEA
  development repository of Ciao and is not yet publicly distributed; `ciao get ciaopp` does not
  provide it. Until it is released, the CiaoPP step cannot be reproduced with public packages
  only (the CasLog step and the comparison with `pipeline/reference_bounds.json` can).
- **CasLog** (Debray and Lin), GNU Prolog port, compiled with its `gprolog.install` script, and
  **GNU Prolog 1.5.0**. CasLog is not included in this repository (no license file in the copy
  used); ask its authors for a copy. Set `CASLOG` to the path of its `caslog.gprolog` script.
- **Python >= 3.10** with **numpy** (`pip install -r requirements.txt`). Tested with Python 3.14
  and numpy 2.5. matplotlib is not needed.

Only to re-measure the gas (`--remesurer`, see `bench/README.md`) or re-derive the tree constants
(`costmodel/tree/README.md`): JDK 21, Maven, Docker and the image
`hotmoka/mokamint-node:1.12.3` (Hotmoka 1.12.3, Takamaka 1.8.1).

## Installation

```sh
git clone https://github.com/robotane/ciaoimp-analyzer.git hotmoka-gas-bounds && cd hotmoka-gas-bounds
python3 -m pip install -r requirements.txt
export PATH="/path/to/ciao/build/bin:$PATH"        # ciaopp, ciaosh (with ciaopp_cost)
export CASLOG=/path/to/caslog/caslog.gprolog        # CasLog compiled for GNU Prolog
```

## Reproducing the results

One command, from the repository root:

```sh
pipeline/run_pipeline.py
```

It regenerates `dsl/hotmoka_gas.pl` from `data/constants_moka_sur.json`, analyses the 15
contracts one at a time with CiaoPP (memory capped: `ulimit -v 3000000`,
`CIAOPP_COST_MAX_MB=2800`, timeout) and CasLog (`ulimit -v 2000000`, timeout), compares the
bounds with `data/bench_moka.csv` and `data/bench_tontine.csv`, and writes
`build/pipeline/<timestamp>/` (`tableau.csv`, `tableau.md`, `bounds.json`, `caslog.json`, raw
outputs). The script never runs two analyses at the same time and waits if another
CiaoPP/ciaosh/CasLog process is running. It exits with a non-zero status if a measured point is
above a bound or if a bound differs from `pipeline/reference_bounds.json`.

Other uses:

```sh
pipeline/run_pipeline.py simple_ponzi example_coin   # a subset of the contracts
pipeline/run_pipeline.py --skip-caslog               # CiaoPP and comparison only
pipeline/run_pipeline.py --help                      # options (--out, --moka, --constants, --reference)
pipeline/run_pipeline.py --remesurer                 # re-measure first (Docker + JDK 21 + Maven)
```

### Expected results

```
benchmark contracts: 36 operations ; points above the bound: 0/3312 ; median of the per-operation median ratios bound/measured: 2.108
witness contract: 4 operations ; points above the bound: 0/131 ; median of the per-operation median ratios bound/measured: 3.726
CasLog functions [inf]: ['ballot.delegate', 'blind_auction.bid', 'blind_auction.reveal', 'crowdfunding.contribute', 'tontine.rembourser_tous']
bound differences vs reference: none
```

- **Benchmark contracts** (14 contracts, 36 measured operations, 3312 measured sizes): every
  CiaoPP bound is finite and no measured point is above its bound; the median over the
  operations of the median ratio bound/measured gas is 2.11.
- **Witness contract** `tontine` (written after the cost model was fixed): 4 operations, 131
  measured sizes, 0 above the bound.
- `bounds.json` is identical to `pipeline/reference_bounds.json`.
- CasLog gives a finite complexity function for every public method of the 14 benchmark
  contracts except four (`ballot.delegate`, `blind_auction.bid`, `blind_auction.reveal`,
  `crowdfunding.contribute`), plus `tontine.rembourser_tous` (see Limitations).

### Reading the output

`tableau.md` (and `tableau.csv`) has one row per measured operation and size variable, e.g.
`simple_shared_entity | place_offer.F` is the operation `place_offer` with the number of offers
`F` growing. Columns:

| column | meaning |
|---|---|
| `ciaopp_bound` | gas upper bound inferred by CiaoPP, as a function of the sizes of the state (`length(L)`, `int(X)`) |
| `ciaopp_class` | growth class of that bound in the size variable of the row |
| `caslog_function`, `caslog_class` | time function and complexity class inferred by CasLog (`[inf]`: no finite bound) |
| `measured_class` | growth class fitted on the measured gas |
| `points`, `above_bound` | number of measured sizes, and how many have a measured gas above the bound (must be 0) |
| `median_ratio`, `max_ratio` | bound / measured gas over the points (1 = exact, larger = looser) |
| `verdict` | `OK (bound holds)`, `VIOLATION`, `UNBOUNDED (inf)`, `NOT MEASURED` or an error |
| `same_as_reference` | whether the bound equals the one in `pipeline/reference_bounds.json` |

`bounds.json` holds the raw CiaoPP bounds of every public method, `caslog.json` the CasLog
results, `ciaopp/` and `caslog/` the raw outputs of the tools.

Re-measuring on a fresh node changes the gas slightly (random account addresses change the shape
of the storage trees); see `bench/README.md`.

## BigInteger gas by size

By default, arithmetic on amounts costs a constant. A contract can ask for the cost that the
Takamaka runtime charges according to the size of the numbers: the directive `:- bigint_cost.`
and the primitives `big_add/3`, `big_sub/3`, `big_mul/3`, `big_div/3`, `big_mod/3`, `big_gt/2`,
`big_ge/2` and `big_pay/2` of `dsl/hotmoka.pl` (a payable method then also starts with the
`big_pay` of the amount received). Only `simple_ponzi` and `gradual_ponzi` use them.

The model (`dsl/hotmoka_gas.pl.in`) follows the rule of `io.takamaka.code.math.BigIntegerSupport`
(takamaka-code 1.8.1), read in the class file, with `bl(x)` the bit length of `x`:

- `add`, `subtract`, `multiply`, `divide`, `mod`: `bl(a)+bl(b)` units of CPU gas and as many of RAM
  gas, in addition to the constant cost of the call (already in the constants): `2*(bl(a)+bl(b))`;
- `compareTo`, `equals`: `bl(a)+bl(b)` units of CPU gas;
- `Contract.pay` (`compareTo` and `subtract` on the payer balance, `add` on the payee balance):
  `3*bl(payer balance) + 2*bl(payee balance) + 5*bl(amount)`.

The size of an integer is its value and `bl(x) <= log2(x+1)+1`, so the bounds contain terms
`log(2, int(X)+1)`; `data/bigint_ops.json` gives the value of `X` at each measured point, and the
pipeline reads the class of such a bound on the formula (`O(log m)` for `simple_ponzi.invest`,
`O(l*log m)` for `gradual_ponzi.invest`, `m` being the amount).

Hypotheses:

- the balance of the payer, written in the contract, is bounded by what the contract holds (the
  first investment plus the amount received for `simple_ponzi`; the amount received plus division
  remainders, below the amount, for `gradual_ponzi`);
- the balances of the payee and of a payer that is a user account are those of the calibration of
  `C_PAY` (accounts of 10^15);
- the storage gas of a `BigInteger`, which grows with its size in bytes, is not modelled: it is
  absorbed by the safety margin of the constants for amounts up to about 400 bits, not beyond.

CasLog limit: the `big_*` primitives are one step each for CasLog (`caslog_prep/`), which cannot
count the bit length of the operands. The log(amount) term therefore does not appear in its time
function, and the class it gives is that of the constant-cost model.

## Adding a contract

1. Write `dsl/<name>.pl` in the DSL, following an existing contract (e.g. `dsl/simple_ponzi.pl`):
   module declaration loading the package `.(hotmoka_gas)`, one `:- entry` assertion per public
   method (types of the arguments, state given as lists/maps), the methods written with
   state variables (`!S`, `X := V`), `require(Cond)`, `if`/`for`, `Obj[f]` and the primitives of
   `dsl/hotmoka.pl`; `:- payable(m)` for `@Payable` methods.
2. Run `pipeline/run_pipeline.py --skip-caslog <name>` to get its CiaoPP bounds, then without
   `--skip-caslog` for CasLog. Add its bounds to `pipeline/reference_bounds.json` once checked.
3. To compare with measured gas: add the Java contract and a scenario under `bench/`
   (`bench/README.md`), measure it, and add its operations to `data/direct_ops.json`
   (`"<contract>.<operation>.<size variable>": {"pred": ..., "lengths": {argument: expression in n}}`).

## Limitations

The DSL and its translation have the following known restrictions:

- **R1** No `while`, `break` or `return`; failed transactions are not costed.
- **R2** `for` is reserved to storage lists (it adds a `load` per element).
- **R3** One contract (`tictactoe`) keeps explicit `is` arithmetic.
- **R4** Some type annotations are needed (`trust` assertions in `blind_auction` and `ballot`);
  without the one of `blind_auction`, the bound of `reveal` is infinite.
- **R5** One auxiliary predicate (`best/3` of `ballot`) still contains hand-written `load`s.
- **R6** Four methods get `[inf]` from CasLog (accumulators growing while a list shrinks, sizes of
  values read from maps or from fields of list elements).
- **R7** Pure Java computation (arithmetic, comparisons, hashing) costs 0 in the model; only the
  primitives cost gas. `map_set`/`list_set` (object mutated in place) cost 0 and assume a closed
  state.
- **R8** The non-tree constants are upper envelopes of micro-benchmarks, not derived from the
  code (`docs/provenance.md`).
- **R9** (fixed) The first read of an object is now determined per branch of an `if`.
- **R10** A `store` is counted at each assignment, also for repeated writes of one field: an
  over-approximation, harmless for an upper bound.
- **R11** Object creation, events and insertions are written by the author as primitive calls:
  the completeness of the cost with respect to the Java code relies on the author.

Other limits: the bounds can be loose (worst-case tree height and bytes; very large ratios when a
tree constant multiplies a size, e.g. `simple_shared_entity.accept.F` and `ballot.delegate.L`); the
`lb` bounds of the tree primitives are not safe lower bounds and are not checked.

## Earlier version

Until November 2026 this repository held an earlier pipeline (contracts in an imperative Prolog
syntax translated to CasLog, the TNF assembler and Prolog Cafe). It is no longer maintained; its
last state is kept in the history under the tag `archive/ancien-pipeline-2026-11-19`
(`git checkout archive/ancien-pipeline-2026-11-19`).

## License

Apache License 2.0, see `LICENSE`. The Java contracts derived from the Hotmoka examples keep
their original Apache-2.0 headers; see `NOTICE`. Citation metadata: `CITATION.cff`.
