from __future__ import annotations

import math
import subprocess
import re
from pathlib import Path

from core.project import PLCAFE_JAR, PROLOG_CAFE_WORK


def measure_pc(
    pl_file: Path,
    nwarmup: int = 10000,
    nruns: int = 2000,
) -> dict:
    """Compile Prolog to Java via Prolog Cafe and measure execution time.

    Timing par-call : nanoTime() autour de chaque appel a `control.once`.
    Important : *ne pas* batcher la mesure (boucle serree sans barriere
    memoire) car HotSpot C2 inline et optimise alors la boucle au point
    de faire chuter le temps mesure a presque zero pour les predicats
    triviaux (`len_list/2`, `init/5`, etc.). Le delimitter chaque appel
    par nanoTime() conserve la barriere qui empeche ces optimisations.
    """
    name = f"{pl_file.parent.parent.name}_{pl_file.parent.name}"
    src_dir = PROLOG_CAFE_WORK / name / "src"
    am_dir = PROLOG_CAFE_WORK / name / "am"
    classes_dir = PROLOG_CAFE_WORK / name / "classes"

    src_dir.mkdir(parents=True, exist_ok=True)
    am_dir.mkdir(parents=True, exist_ok=True)
    classes_dir.mkdir(parents=True, exist_ok=True)

    try:
        # 1. Translate Prolog to Java Source
        subprocess.run(
            [
                "java", "-cp", str(PLCAFE_JAR),
                "com.googlecode.prolog_cafe.compiler.Compiler",
                "-s", str(src_dir.resolve()),
                "-am", str(am_dir.resolve()),
                pl_file.name
            ],
            cwd=pl_file.parent,
            check=True,
            capture_output=True,
            text=True
        )

        # 2. Write Java Harness
        harness_path = src_dir / "PrologCafeBench.java"
        harness_content = f"""
import com.googlecode.prolog_cafe.lang.BufferingPrologControl;
import com.googlecode.prolog_cafe.lang.Term;
import com.googlecode.prolog_cafe.lang.VariableTerm;

public class PrologCafeBench {{
    private static Term[] makeArguments() {{
        return new Term[] {{ new VariableTerm() }};
    }}

    public static void main(String[] args) {{
        BufferingPrologControl control = new BufferingPrologControl();
        control.setReductionLimit(10000000L);
        control.initialize("user");
        Term[] pArgs = makeArguments();

        int nwarmup = {nwarmup};
        int nruns   = {nruns};

        // --- Warmup
        int sink = 0;
        for (int i = 0; i < nwarmup; i++) {{
            Object r = control.once("user", "goal", pArgs[0]);
            if (r != null) sink++;
        }}

        // --- Mini-batch timing : K calls par mesure pour amortir l'overhead
        // de nanoTime (~50 ns) sans permettre au JIT C2 d'eliminer / fusionner
        // toute la boucle (ce qui se produit avec des batches plus grandes).
        // On accumule egalement un `sink` derive du resultat pour bloquer le
        // dead-code elimination.
        final int K = 10;
        double[] timesMs = new double[nruns];
        for (int i = 0; i < nruns; i++) {{
            long t0 = System.nanoTime();
            for (int k = 0; k < K; k++) {{
                Object r = control.once("user", "goal", pArgs[0]);
                if (r != null) sink++;
            }}
            timesMs[i] = (System.nanoTime() - t0) / 1_000_000.0 / K;
        }}
        if (sink == Integer.MIN_VALUE) System.out.println("impossible");

        double sum = 0, minMs = Double.MAX_VALUE, maxMs = 0;
        for (double t : timesMs) {{
            sum += t;
            if (t < minMs) minMs = t;
            if (t > maxMs) maxMs = t;
        }}
        double meanMs = sum / nruns;
        double sumSq = 0;
        for (double t : timesMs) sumSq += (t - meanMs) * (t - meanMs);
        double stdMs = nruns > 1 ? Math.sqrt(sumSq / (nruns - 1)) : 0.0;

        System.out.println("TIME_MS:" + meanMs);
        System.out.println("STD_MS:" + stdMs);
        System.out.println("MIN_MS:" + minMs);
        System.out.println("MAX_MS:" + maxMs);
        System.out.println("NRUNS:" + nruns);
    }}
}}
"""
        harness_path.write_text(harness_content, encoding="utf-8")

        # 3. Compile Java to Bytecode
        java_files = [str(f.resolve()) for f in src_dir.rglob("*.java")]
        subprocess.run(
            [
                "javac", "-source", "1.8", "-target", "1.8",
                "-classpath", str(PLCAFE_JAR),
                "-d", str(classes_dir.resolve())
            ] + java_files,
            check=True,
            capture_output=True,
            text=True
        )

        # 4. Execute Java Harness
        result = subprocess.run(
            ["java", "-cp", f"{classes_dir.resolve()}:{PLCAFE_JAR}", "PrologCafeBench"],
            check=True,
            capture_output=True,
            text=True,
            timeout=600
        )

        mean_m = re.search(r"TIME_MS:([\d\.]+)", result.stdout)
        std_m  = re.search(r"STD_MS:([\d\.]+)",  result.stdout)
        min_m  = re.search(r"MIN_MS:([\d\.]+)",  result.stdout)
        max_m  = re.search(r"MAX_MS:([\d\.]+)",  result.stdout)
        if mean_m:
            return {
                "mean": float(mean_m.group(1)),
                "std":  float(std_m.group(1)) if std_m else 0.0,
                "min":  float(min_m.group(1)) if min_m else 0.0,
                "max":  float(max_m.group(1)) if max_m else 0.0,
                "n":    nruns,
            }
        print(f"  [PC ERROR] TIME_MS non trouve dans la sortie standard.")
        return {"mean": 0.0, "std": 0.0, "min": 0.0, "max": 0.0, "n": 0}
    except subprocess.CalledProcessError as e:
        print(f"  [PC ERROR] {e.cmd} a echoue (code {e.returncode})")
        if e.stdout:
            print(f"  [STDOUT] {e.stdout.strip()}")
        if e.stderr:
            print(f"  [STDERR] {e.stderr.strip()}")
        return {"mean": 0.0, "std": 0.0, "min": 0.0, "max": 0.0, "n": 0}
    except subprocess.TimeoutExpired:
        print("  [PC ERROR] Timeout expire (600s)")
        return {"mean": 0.0, "std": 0.0, "min": 0.0, "max": 0.0, "n": 0}
    except Exception as e:
        print(f"  [PC ERROR] Exception inattendue : {e}")
        return {"mean": 0.0, "std": 0.0, "min": 0.0, "max": 0.0, "n": 0}
