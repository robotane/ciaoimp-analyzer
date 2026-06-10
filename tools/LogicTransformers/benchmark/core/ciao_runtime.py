from __future__ import annotations

import subprocess
import re
import math
from pathlib import Path

from core.project import WORK_DIR

CIAO_WORK = WORK_DIR / "ciao"

# Cible: chaque batch dure au moins MIN_BATCH_MS pour que le timer Ciao
# (resolution = 1 ms entier via statistics(runtime,_)) introduise au plus
# ~1/MIN_BATCH_MS d'erreur. 200 ms -> ~0.5%.
MIN_BATCH_MS = 200
# Nombre de batches independantes pour estimer mean+std.
NBATCHES = 5
# Cap absolu sur le nombre de runs par batch (eviter de bloquer si la
# fonction est ultra rapide, par ex. predicat O(1) trivial).
MAX_RUNS_PER_BATCH = 2_000_000


def measure_ciao(pl_file: Path, nwarmup: int = 200, xsyntax: bool = False) -> dict:
    """Compile Prolog scenario to Ciao executable and measure execution time.

    Strategie:
      1. Warmup: nwarmup iterations.
      2. Calibration: doubler le nombre d'iterations par batch jusqu'a
         atteindre MIN_BATCH_MS de duree totale (timer 1 ms entier).
      3. Mesure: NBATCHES batches independantes -> mean + std.

    Si `xsyntax=True`, le fichier inclus contient des constructions xsyntax
    (fsyntax, statevars, hiord, loops) qu'on doit activer dans le harness.
    """
    name = f"{pl_file.parent.parent.name}_{pl_file.parent.name}"
    src_dir = CIAO_WORK / name
    src_dir.mkdir(parents=True, exist_ok=True)

    harness_path = src_dir / "ciao_harness.pl"
    pl_file_abs = pl_file.resolve().as_posix()

    xsyntax_packages = (
        ":- use_package([fsyntax, statevars, hiord, loops]).\n"
        if xsyntax
        else ""
    )

    harness_content = f""":- module(ciao_harness, [main/1]).
:- use_module(library(format)).
{xsyntax_packages}
% Include the actual scenario file
:- include('{pl_file_abs}').

% --- Boucles de mesure ------------------------------------------------------

run_batch(0) :- !.
run_batch(N) :-
    ( once(goal(_)) -> true ; true ),
    N1 is N - 1,
    run_batch(N1).

run_warmup(N) :- run_batch(N).

% Calibration: double NPerBatch jusqu'a ce qu'une batch dure >= MinMs.
% Renvoie le NPerBatch calibre.
calibrate(NPerBatch, MinMs, MaxRuns, NCalib) :-
    statistics(runtime, [_, _]),
    run_batch(NPerBatch),
    statistics(runtime, [_, T]),
    ( T >= MinMs ->
        NCalib = NPerBatch
    ; NPerBatch >= MaxRuns ->
        NCalib = NPerBatch    % cap atteint, on reste a cette valeur
    ; N2 is NPerBatch * 2,
      calibrate(N2, MinMs, MaxRuns, NCalib)
    ).

% Effectuer NBatches batches de NPerBatch runs, imprimer le temps de chaque batch.
run_batches(0, _) :- !.
run_batches(K, NPerBatch) :-
    statistics(runtime, [_, _]),
    run_batch(NPerBatch),
    statistics(runtime, [_, T]),
    format('BATCH_MS:~d~n', [T]),
    K1 is K - 1,
    run_batches(K1, NPerBatch).

main(Args) :-
    ( Args = [WarmupAtom, MinMsAtom, NBatchesAtom, MaxRunsAtom] ->
        atom_number(WarmupAtom, Warmup),
        atom_number(MinMsAtom, MinMs),
        atom_number(NBatchesAtom, NBatches),
        atom_number(MaxRunsAtom, MaxRuns)
    ; Warmup   = {nwarmup},
      MinMs    = {MIN_BATCH_MS},
      NBatches = {NBATCHES},
      MaxRuns  = {MAX_RUNS_PER_BATCH}
    ),
    run_warmup(Warmup),
    calibrate(50, MinMs, MaxRuns, NPerBatch),
    format('NRUNS_PER_BATCH:~d~n', [NPerBatch]),
    format('NBATCHES:~d~n', [NBatches]),
    run_batches(NBatches, NPerBatch).
"""

    harness_path.write_text(harness_content, encoding="utf-8")

    try:
        exec_path = src_dir / "ciao_harness"
        subprocess.run(
            ["ciaoc", "-o", str(exec_path.resolve()), str(harness_path.resolve())],
            check=True,
            capture_output=True,
            text=True
        )

        res = subprocess.run(
            [
                str(exec_path.resolve()),
                str(nwarmup),
                str(MIN_BATCH_MS),
                str(NBATCHES),
                str(MAX_RUNS_PER_BATCH),
            ],
            check=True,
            capture_output=True,
            text=True,
            timeout=600
        )

        n_per_batch_m = re.search(r"NRUNS_PER_BATCH:(\d+)", res.stdout)
        if not n_per_batch_m:
            print(f"  [Ciao ERROR] NRUNS_PER_BATCH absent. Sortie:\n{res.stdout}")
            return {"mean": 0.0, "std": 0.0, "min": 0.0, "max": 0.0, "n": 0}

        n_per_batch = int(n_per_batch_m.group(1))
        batch_ms = [int(m.group(1)) for m in re.finditer(r"BATCH_MS:(\d+)", res.stdout)]
        if not batch_ms:
            print(f"  [Ciao ERROR] Aucune BATCH_MS dans la sortie:\n{res.stdout}")
            return {"mean": 0.0, "std": 0.0, "min": 0.0, "max": 0.0, "n": 0}

        # Moyenne par run (ms) sur chaque batch, puis stats inter-batch.
        per_run = [t / n_per_batch for t in batch_ms]
        mean = sum(per_run) / len(per_run)
        if len(per_run) > 1:
            sq = sum((t - mean) ** 2 for t in per_run)
            std = math.sqrt(sq / (len(per_run) - 1))
        else:
            std = 0.0

        return {
            "mean": mean,
            "std": std,
            "min": min(per_run),
            "max": max(per_run),
            "n": len(per_run),
            "runs_per_batch": n_per_batch,
        }

    except subprocess.CalledProcessError as e:
        print(f"  [Ciao ERROR] {e.cmd} a echoue (code {e.returncode})")
        if e.stdout:
            print(f"  [STDOUT] {e.stdout.strip()}")
        if e.stderr:
            print(f"  [STDERR] {e.stderr.strip()}")
        return {"mean": 0.0, "std": 0.0, "min": 0.0, "max": 0.0, "n": 0}
    except subprocess.TimeoutExpired:
        print("  [Ciao ERROR] Timeout expire (600s)")
        return {"mean": 0.0, "std": 0.0, "min": 0.0, "max": 0.0, "n": 0}
    except Exception as e:
        print(f"  [Ciao ERROR] Exception inattendue : {e}")
        return {"mean": 0.0, "std": 0.0, "min": 0.0, "max": 0.0, "n": 0}
