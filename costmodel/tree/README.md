# Worst-case gas of the Takamaka storage trees

These scripts derive the tree constants of `data/constants_moka_sur.json`
(`C_TREE0/1` get, `C_TREEW0/1` put, `C_TREER0/1` remove, `C_TMP0/1` temporary set) from the
code of Takamaka 1.8.1 as instrumented by Hotmoka 1.12.3, so that the bounds hold whatever the
order of the keys (account addresses are random from one node to another). The full derivation
(gas model, structural bounds of left-leaning red-black trees, bytes of the updates, results)
is written up, in French, in `arbre_pire_cas.md`.

| File | Role |
|---|---|
| `derive_arbre.py` | main script: instruments the Takamaka jar with `moka jars instrument`, runs `wcet_gas.py` and `worst_bytes.py`, writes `build/constants_moka_sur.json` from `data/constants_moka.json` |
| `wcet_gas.py` | worst-case CPU + RAM gas of a method of the instrumented code (`javap -c -p`) |
| `worst_bytes.py`, `UpdSize.java` | exact storage bytes of worst-case update sets, marshalled by Hotmoka's own code |
| `llrb_sim.py`, `experiment.py`, `analyse_sim.py` | simulator of the trees used to check the structural bounds (`HARNESS=<work dir of derive_arbre.py>/harness experiment.py 1500 3 sim.csv`, then `analyse_sim.py sim.csv`) |

Requirements: a JDK 21 (`JAVA_HOME`) and the module directory of Hotmoka 1.12.3
(`HOTMOKA_MODULES`, with `explicit_or_automatic/` and `unnamed/`; it is `io-hotmoka-docker/modules`
in the Hotmoka sources, or `/modules` inside the image `hotmoka/mokamint-node:1.12.3`).

    HOTMOKA_MODULES=/path/to/modules JAVA_HOME=/path/to/jdk-21 python3 costmodel/tree/derive_arbre.py
    diff <(python3 -m json.tool build/constants_moka_sur.json) <(python3 -m json.tool data/constants_moka_sur.json)

`data/constants_moka.json` is the input of the derivation: its non-tree constants are upper
envelopes of micro-benchmarks, recalibrated on gas measured through a moka node (see
`docs/provenance.md`); only the tree constants are replaced by derived values.
