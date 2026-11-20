# Re-measuring the gas on a Hotmoka node (optional)

The measured gas used by the pipeline is already in `data/bench_moka.csv` (14 contracts,
36 operations) and `data/bench_tontine.csv` (witness contract, 4 operations). This directory
is only needed to measure it again.

`mesurer.sh` replays the benchmark scenarios through a real Hotmoka node started with the
official `moka` CLI, as recommended by the Hotmoka authors:

* the node is started with `moka nodes disk init` in the Docker image
  `hotmoka/mokamint-node:1.12.3` (chain id `wtsc`);
* the Java driver (`moka-driver/`, class `wtsc.MokaBench`) is a plain client of the node
  (local WebSocket, `RemoteNodes.of`);
* every account is created by its own transaction (faucet of the gamete, as
  `moka accounts create faucet`);
* the gas limit per transaction is 10,000,000 (maximum accepted by the node).

Only gas values are recorded (CPU, RAM, storage, total); the `time_us` column is kept for
format compatibility.

## Contents

| Path | Role |
|---|---|
| `contracts/` | Java (Takamaka) sources of the benchmark contracts, Maven project `wtsc-contracts`. The classes of `io.hotmoka.examples.*` other than `tontine` and `micro`, and those of `io.hotmoka.tutorial.examples.*`, are derived from the Hotmoka examples (Apache-2.0, original headers kept, see `NOTICE`). `tontine/` is the witness contract; `micro/` holds micro-benchmark helpers. |
| `moka-driver/` | Java driver replaying the scenarios (`MokaBench.java`) |
| `mesurer.sh` | starts a fresh node, installs the jar, runs the driver, stops the node |
| `verifier_cli.sh`, `comparer_verifier.py` | cross-check: the same transactions sent by the moka CLI and by the driver must cost the same gas |

## Requirements

* Docker and the image `hotmoka/mokamint-node:1.12.3` (`docker pull hotmoka/mokamint-node:1.12.3`);
* JDK 21 (`JDK21` or `JAVA_HOME`);
* Maven, run offline (`-o`) once the Hotmoka 1.12.3 artifacts and
  `maven-dependency-plugin:3.7.0` are in the local repository (drop `-o` the first time);
* the contracts jar, absent from a fresh clone, built under JDK 21:
  `cd bench/contracts && JAVA_HOME=/path/to/jdk-21 MAVEN_OPTS=-Xmx1g mvn -o -T1 package`
  (`mesurer.sh` builds the driver itself, but not this jar);
* python3; at least 4 GB of available memory (the script refuses to start otherwise,
  `MOKA_IGNORE_MEM=1` overrides).

Memory: the node runs with `--memory=2g` and `-Xmx1536m`, the client `moka` containers with
1 GB, the driver with `-Xmx1g`, Maven with `-T1` and `-Xmx1g`.

## Commands

From the repository root:

    bench/mesurer.sh                                    # everything: 36 operations, n = 1..100, 3 runs
    bench/mesurer.sh --contracts tontine --n 50         # witness contract (as data/bench_tontine.csv)
    bench/mesurer.sh --contracts simple_ponzi,example_coin --n 20 --runs 1 --out build/moka/try.csv
    bench/mesurer.sh --verifier                         # cross-check driver / moka CLI
    bench/mesurer.sh --stop                             # stop the container wtsc-moka-node

or, through the pipeline, `pipeline/run_pipeline.py --remesurer [contract ...]`.

Contract names: gradual_ponzi, simple_pyramid, simple_ponzi, distributor, simple_auction,
blind_auction, crowdfunding, ballot, example_coin, crypto_buddy, example_erc721, crypto_shark,
simple_shared_entity, tictactoe, tontine. Other options: `--n`, `--runs`, `--warmup` (unrecorded
warm-up runs, 0 by default: the gas is deterministic for a given node), `--out` (default
`build/moka/bench_moka-<date>.csv`; the driver never overwrites a file), `--jar`, `--gas`,
`--keep-node`. Environment: `MOKA_IMAGE`, `MOKA_PORT` (8001), `MOKA_CONTAINER`
(`wtsc-moka-node`), `MOKA_WORK` (`bench/work`, ignored by git: chain, throw-away `.pem` keys,
Takamaka jar extracted from the image).

The script (1) stops a previous container with its own exact name, (2) starts a fresh node,
(3) creates a payer account, (4) installs the jar, (5) runs the driver, (6) stops and removes
its container on exit (also after Ctrl-C).

## Reproducibility of the gas

The gas is not identical from one node to another: account addresses come from random keys,
which changes the shape of the red-black storage trees. A full re-measurement gives the same
operations and growth classes but not the same values (about 40 % identical points, median
difference 0.5 %). With the safe tree constants (`data/constants_moka_sur.json`, derived in
`costmodel/tree/`) no point of the control re-measurement made when these constants were
derived went above a bound; with the earlier, empirically fitted constants
(`data/constants_moka.json`) 3 points out of 3312 did (`example_coin.mint`).

## Adding a contract or an operation

1. Add the class under `contracts/src` and rebuild the jar.
2. In `moka-driver/src/main/java/wtsc/MokaBench.java`, add a block protected by
   `if (want("contract_name"))`, with `create(...)`, `call(account, signature, receiver, args)`
   and `record(contract, operation, size_variable, n, run, measure)`; call a new scenario method
   from `run()`.
3. Add the operation to `data/direct_ops.json` (entry predicate of the DSL contract and lengths
   of its list/map arguments as a function of `n`) so that the pipeline compares it with the bound.

## Troubleshooting

* The node stops right after starting: `docker run -d` needs `-i` (already in the script).
* `the balance must be between 0 and 0 inclusive` when creating an account: the faucet cap is 0
  by default; the script binds the gamete key (`moka keys bind`) then calls `moka nodes faucet`.
* `The gas limit of the request is larger than the maximum allowed`: the limit is 10 M per
  transaction on a moka node.
* Port 8001 busy: `bench/mesurer.sh --stop`, or `MOKA_PORT=8002`.
* Use `bash` for moka scripts (word splitting differs in zsh).
