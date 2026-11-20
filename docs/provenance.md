# Provenance of the data files

## Cost-model constants

`data/constants_moka_sur.json` is the default of the pipeline. Its constants, in Hotmoka gas
units, are used by `pipeline/gen_model.py` to instantiate `dsl/hotmoka_gas.pl.in`:

| Constant | Meaning | Origin |
|---|---|---|
| `C_TX` | fixed cost of a transaction (added to every bound) | micro-benchmarks, + 320 for the 4-byte chain id of a moka node |
| `C_PAY`, `C_NEW` | payable call, new storage object | micro-benchmarks, + 2560 (32-byte transaction hash of a distinct account) |
| `C_FIELD`, `C_STORE`, `C_LOAD`, `C_EVENT`, `C_ARR`, `C_ARRR`, `C_STEP` | field write, store, first read of an object, event, arrays, pure step | upper envelopes of micro-benchmarks |
| `C_TREE0/1`, `C_TREEW0/1`, `C_TREER0/1`, `C_TMP0/1` | get, put, remove on a storage tree map, temporary tree set: `a + b*log2(n+1)` | derived from the instrumented Takamaka code, worst case over key orders (`costmodel/tree/`) |

`data/constants_moka.json` is the previous set, kept because it is the input of
`costmodel/tree/derive_arbre.py`: same non-tree constants, but tree constants taken from
micro-benchmarks and one slope (`C_TREEW1`) fitted on a single run of the moka node. The
micro-benchmark and recalibration scripts that produced it belong to an earlier version of this
work and are not part of this repository (they are kept, unpublished, in the authors' original
repositories); the non-tree constants are therefore provided as
fixed data (limit R8 in the README).

## Measured gas

`data/bench_moka.csv` (14 contracts, 36 operations, n = 1..100, 3 runs, 10,044 rows) and
`data/bench_tontine.csv` (witness contract, 4 operations, 393 rows) were measured with
`bench/mesurer.sh` on a node started from the Docker image `hotmoka/mokamint-node:1.12.3`.
Columns: `contract, operation, size_var, n, run, gas_cpu, gas_ram, gas_storage, gas_total,
time_us` (`time_us` is not used).

## Reference bounds

`pipeline/reference_bounds.json` holds the CiaoPP upper bounds of every entry of the 15 DSL
contracts with `data/constants_moka_sur.json`. The pipeline reports any difference.
The bounds of `simple_ponzi.invest` and `gradual_ponzi.invest` come from the BigInteger size model
(README, section "BigInteger gas by size"): the constants of that model are not calibrated on
measurements, they are the rule of `io.takamaka.code.math.BigIntegerSupport` (takamaka-code
1.8.1), read in the class file.

## BigInteger sizes

`data/bigint_ops.json` gives, for the two operations whose bound contains terms `log(2, int(X)+1)`,
the value of `X` at each measured point: the amounts of the `simple_ponzi` scenario of
`bench/` (1000, then each amount is the previous one times 11/10, plus 1) and the constant
amount of the `gradual_ponzi` scenario (1000).
