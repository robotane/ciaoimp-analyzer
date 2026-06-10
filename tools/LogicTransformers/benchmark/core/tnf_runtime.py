from __future__ import annotations

import subprocess
import re
from pathlib import Path

from core.project import TNF_PRO, TNF_JAVA_DIR, TNF_WORK


def compile_to_asm(pl_file: Path, asm_file: Path) -> None:
    cmd = f"swipl -q -s {TNF_PRO} -g \"to_tasm('{pl_file}', '{asm_file}'),halt\""
    subprocess.run(cmd, shell=True, check=True)


def measure(pl_file: Path, asm_file: Path, nwarmup: int = 1000, nruns: int = 200) -> dict:
    compile_to_asm(pl_file, asm_file)

    name = pl_file.parent.name
    bench_name = pl_file.parent.parent.name
    src_dir = TNF_WORK / bench_name / name / "src"
    src_dir.mkdir(parents=True, exist_ok=True)

    # On garde nwarmup et nruns constants quelque soit N : reduire l'echantillon
    # pour les grands N detruisait le warmup JIT et augmentait massivement la
    # variance, produisant les pics aberrants observes dans le PDF d'annexe.
    actual_nwarmup = nwarmup
    actual_nruns = nruns

    # Write Java Harness
    harness_path = src_dir / "TnfBench.java"
    harness_content = f"""
import java.io.PrintStream;
import java.io.OutputStream;
import java.util.List;

public class TnfBench {{
    public static void main(String[] args) throws Exception {{
        String fname = args[0];
        int nwarmup = Integer.parseInt(args[1]);
        int nruns = Integer.parseInt(args[2]);

        List<List<List<Object>>> code = Tnf.tload(fname);

        PrintStream silentOut = new PrintStream(new OutputStream() {{
            public void write(int b) {{}}
        }});

        long warmupDeadline = System.nanoTime() + 10_000_000_000L; // 10 s max
        for (int i = 0; i < nwarmup && System.nanoTime() < warmupDeadline; i++) {{
            Tnf.answerCount = 0;
            Tnf.interp(code, silentOut);
        }}

        double[] timesMs = new double[nruns];
        for (int i = 0; i < nruns; i++) {{
            Tnf.answerCount = 0;
            long t0 = System.nanoTime();
            Tnf.interp(code, silentOut);
            timesMs[i] = (System.nanoTime() - t0) / 1_000_000.0;
        }}

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
    }}
}}
"""
    harness_path.write_text(harness_content, encoding="utf-8")

    try:
        # Compile Java harness
        subprocess.run(
            ["javac", "-cp", str(TNF_JAVA_DIR), str(harness_path.resolve())],
            check=True,
            capture_output=True,
            text=True
        )

        # Run Java harness
        classpath = f"{TNF_JAVA_DIR}:{src_dir.resolve()}"
        res = subprocess.run(
            [
                "java",
                "-cp",
                classpath,
                "TnfBench",
                str(asm_file.resolve()),
                str(actual_nwarmup),
                str(actual_nruns)
            ],
            check=True,
            capture_output=True,
            text=True,
            timeout=600
        )

        # Parse output
        mean_m = re.search(r"TIME_MS:([0-9.]+)", res.stdout)
        std_m  = re.search(r"STD_MS:([0-9.]+)",  res.stdout)
        min_m  = re.search(r"MIN_MS:([0-9.]+)",  res.stdout)
        max_m  = re.search(r"MAX_MS:([0-9.]+)",  res.stdout)
        if mean_m:
            return {
                "mean": float(mean_m.group(1)),
                "std":  float(std_m.group(1))  if std_m  else 0.0,
                "min":  float(min_m.group(1))  if min_m  else 0.0,
                "max":  float(max_m.group(1))  if max_m  else 0.0,
                "n":    actual_nruns,
            }
        print(f"  [TNF ERROR] Sortie inattendue:\n{{res.stdout}}")
        return {"mean": 0.0, "std": 0.0, "min": 0.0, "max": 0.0, "n": actual_nruns}

    except subprocess.CalledProcessError as e:
        print(f"  [TNF ERROR] {{e.cmd}} a echoue (code {{e.returncode}})")
        if e.stdout:
            print(f"  [STDOUT] {{e.stdout.strip()}}")
        if e.stderr:
            print(f"  [STDERR] {{e.stderr.strip()}}")
        return {"mean": 0.0, "std": 0.0, "min": 0.0, "max": 0.0, "n": actual_nruns}
    except subprocess.TimeoutExpired:
        print("  [TNF ERROR] Timeout expire (600s)")
        return {"mean": 0.0, "std": 0.0, "min": 0.0, "max": 0.0, "n": actual_nruns}
    except Exception as e:
        print(f"  [TNF ERROR] Exception inattendue : {{e}}")
        return {"mean": 0.0, "std": 0.0, "min": 0.0, "max": 0.0, "n": actual_nruns}
