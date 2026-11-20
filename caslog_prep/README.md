# caslog_prep: Hotmoka contract (imperative Ciao DSL) to CasLog input

A single Ciao Prolog driver, `caslog_prep.pl`, loaded in `ciaopp -T`. It loads the contract,
runs `analyze(shfr)` and `analyze(eterms)` (no cost analysis), then writes a file ready for
CasLog:

1. the primitives of `hotmoka_caslog_prims.pl` (fixed file: `dsl/hotmoka.pl` rewritten with
   cuts instead of `->`, with hand-written `mode`/`measure`);
2. `:- mode` and `:- measure` of every predicate of the contract, inferred by CiaoPP;
3. the expanded clauses, where the unifications `X = Y` are removed by binding when this is safe.

`require(Cond)` / `require(Cond, Message)` is unfolded into `Cond` by `dsl/hotmoka_tr.pl`
before the analysis; `strip/2` unfolds a `require` left in a clause in the same way, so it
costs no extra CasLog step. Regtypes and props (`balances/1`, `addrs/1`, ...), `goal/N` and
`goal_chain/N` are left out.

## Command

From the repository root (after `pipeline/gen_model.py`, which writes `dsl/hotmoka_gas.pl`):

```sh
CASLOG=/path/to/caslog/caslog.gprolog caslog_prep/run.sh gradual_ponzi
```

The script runs `ciaopp -T` with `caslog_prep.pl` on `dsl/gradual_ponzi.pl`, then CasLog, and
prints the time functions. It writes to `build/caslog_prep/` (ignored by git):
`gradual_ponzi_caslog.pl` (CasLog input) and `gradual_ponzi_caslog.out` (full CasLog output).
A second argument changes the output directory. One process at a time, memory capped at 2 GB,
timeout 180 s per tool. The generated file starts with `% entry: f/N` comments (public methods)
and ends with `% unifications kept` / `% undefined predicates` when problems remain.

`caslog_prep/2` takes the primitives file as second argument (`run.sh` passes it explicitly).

## How mode and measure are inferred

- **mode**: for every predicate, all versions of `complete/7` of the shfr domain
  (`get_completes/4` of `ciaopp/src/infer/infer.pl`, then `asub_to_info/5` of `plai/domains`).
  An argument is `-` if it is free (`var/1`) in at least one version, `+` otherwise. A constant
  argument in the call (coming from `goal/1`) is not taken as evidence.
- **measure**: eterms types (`get_info(regtypes, pred, ...)`) translated by `type2measure/3`
  (`infer.pl`: list -> `length`, number -> `int`, otherwise `void`). Call type for `+`, success
  type for `-`, the other one as fallback. A measure still `void` is completed from the clauses:
  list/integer head argument, or variable passed to a callee of known measure (fixpoint). A
  counter (`I1 is I+1` passed to the recursive call) is set to `void`: CasLog cannot bound its size.
- **unifications**: `X = Y` is removed by binding X and Y if (a) it is the first goal, or (b) no
  cut precedes it and no previous goal compares the variable (`==`, `\==`), or (c) a cut precedes
  it but the variable is local (or a free head argument) and does not appear before. Otherwise it
  is kept and reported. Assumption: pure clauses (the effects `store/emit/load` are not linked to
  the variables).

## Known limits

- Functions `[inf]`: the pipeline prints the list. Causes: `ballot.delegate` (an accumulator grows
  while the list shrinks: a two-variable recurrence beyond CasLog), `blind_auction.bid` and
  `blind_auction.reveal` (a value read from a map is a list whose size is linked to no argument), `crowdfunding.contribute` (list
  extracted from a field of a term extracted from a list: CasLog does not track field sizes),
  `tontine.rembourser_tous`.
- CasLog counts maps as lists (linear in their size) where the gas model of CiaoPP counts
  `log` of their size, and counts one step per type test of the helpers (`atom/1`, `integer/1`).

## `big_*` primitives (BigInteger gas by size)

`hotmoka_caslog_prims.pl` defines `big_add/3` ... `big_pay/2` as the arithmetic itself (one step
each). The log(amount) term of the CiaoPP gas model therefore does not appear in the CasLog time
function, which changes only by a constant (`simple_ponzi`: `8*$7+14` becomes `8*$7+19`).
Reason: a loop that counts bits (`bl(N) :- N > 1, N1 is N // 2, bl(N1)`) gets `[inf]` whatever the
way the division is written (`//`, `/`, `* 0.5`); the size analysis of CasLog follows `N-1`, not
`N/2`, whereas `N-1` does give `$1+1`. Also, `C is A // B` with two variable integer arguments
crashes its analysis (`type_error(evaluable,($)/2)`): `big_div` is modelled by `C is A` (the
quotient is bounded by the dividend) and `big_mod` by `C is B`.
