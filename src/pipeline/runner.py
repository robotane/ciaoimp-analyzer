"""Orchestrator for the compact portable CiaoImp pipeline.

The runner is the only component that knows the full end-to-end workflow.  It
combines pure-Python transformations with external tools while keeping only
three public per-contract stages:

1. ``build/executable``: executable/analyzable Prolog after CiaoPP expansion,
   native translation, CasLog pre-cleaning and semantic transformation.
2. ``build/normalized``: normalized Prolog after state-wrapper removal and
   difference-list rewriting.
3. ``build/annotated``: CasLog input with inferred modes/measures and optional
   mode demotion driven by CasLog feedback.

All other intermediate files are created in temporary directories and removed
before the stage completes.
"""
from __future__ import annotations

import os
import sys
import tempfile
import contextlib
import io
from dataclasses import dataclass
from pathlib import Path

from src.annotation import demote_modes
from src.annotation.annotate.__main__ import annotate, apply_mode_overrides_to_file
from src.cleaning.expand.__main__ import process_file as expand_native
from src.cleaning.normalize.__main__ import normalize
from src.pipeline.commands import find_executable, run_capture, run_checked
from src.pipeline.paths import PipelinePaths
from src.results.extract import extract_important_results
from src.results.extract_tnf import extract_tnf_results
from src.results.stage_diff import generate as generate_stage_diff
from src.transforms.caslog_clean import preclean_file


@dataclass
class PipelineOptions:
    """Feature flags selected by CLI options."""

    run_caslog: bool = True
    run_tnf: bool = True
    run_prolog_cafe: bool = True


class PipelineRunner:
    """Coordinate contract transformations and aggregate analyses."""

    def __init__(self, paths: PipelinePaths, options: PipelineOptions) -> None:
        """Initialize tool paths and environment overrides.

        The constructor resolves CiaoPP and CasLog once, then updates
        ``demote_modes.CASLOG`` so annotation demotion uses the same CasLog
        binary as the aggregate CasLog stage.
        """
        self.paths = paths
        self.options = options
        self.ciaopp = find_executable("ciaopp", "CIAOPP")
        self.caslog = os.environ.get("CASLOG") or (
            str(paths.caslog_bin) if paths.caslog_bin.exists() else find_executable("caslog.gprolog")
        )
        self.env = os.environ.copy()
        self.env["PYTHONPATH"] = str(paths.root)
        if self.caslog:
            self.env["CASLOG"] = self.caslog
            demote_modes.CASLOG = Path(self.caslog)

    def resolve_inputs(self, args: list[str]) -> list[Path]:
        """Resolve CLI input arguments to source ``.pl`` files."""
        if not args:
            return sorted(self.paths.source_dir.glob("*.pl"))

        inputs: list[Path] = []
        for arg in args:
            path = Path(arg)
            if path.is_file():
                inputs.append(path.resolve())
                continue
            candidate = self.paths.source_dir / arg
            if candidate.is_file():
                inputs.append(candidate)
                continue
            print(f"  WARN: input not found: {arg}", file=sys.stderr)
        return inputs

    def check_tools(self) -> int:
        """Validate required external tools for the selected pipeline options."""
        if not self.ciaopp:
            print("CiaoPP not found. Set CIAOPP or add ciaopp to PATH.", file=sys.stderr)
            return 1
        if self.options.run_caslog and not self.caslog:
            print(
                "CasLog not found. Set CASLOG or place caslog.gprolog in PATH or under ./tools/caslog/.",
                file=sys.stderr,
            )
            return 1
        if self.options.run_tnf:
            import shutil
            if not shutil.which("java"):
                print("Java (JRE) not found. Install java or add it to PATH.", file=sys.stderr)
                return 1
            tnf_class = self.paths.bnf_java_dir / "Tnf.class"
            if not tnf_class.exists():
                print(
                    f"Tnf.class not found at {tnf_class}.\n"
                    f"Run: javac {self.paths.bnf_java_dir / 'Tnf.java'}",
                    file=sys.stderr,
                )
        if self.options.run_prolog_cafe:
            import shutil
            if not shutil.which("java"):
                print("Java (JRE) not found. Install java or add it to PATH.", file=sys.stderr)
                return 1
            if not shutil.which("javac"):
                print("Java Compiler (javac) not found. Install javac or add it to PATH.", file=sys.stderr)
                return 1
            if not self.paths.plcafe_jar.exists():
                print(f"Prolog Cafe JAR not found at {self.paths.plcafe_jar}", file=sys.stderr)
                return 1
        return 0

    def print_header(self, inputs: list[Path]) -> None:
        """Print a concise execution header for user-facing runs."""
        print("=== CiaoImp Pipeline for CasLog v2 ===")
        print(f"Pipeline directory: {self.paths.root}")
        print(f"Build directory:    {self.paths.build_dir}")
        print(f"Inputs: {len(inputs)} file(s)")
        print(f"CiaoPP: {self.ciaopp}")
        print(f"CasLog: {self.caslog if self.options.run_caslog else 'skipped (--no-caslog)'}")
        if self.options.run_tnf:
            print(f"TNF Java VM: {self.paths.bnf_java_dir / 'Tnf.class'}")
        else:
            print("TNF Java VM: skipped (--no-tnf)")
        if self.options.run_prolog_cafe:
            print(f"Prolog Cafe: {self.paths.plcafe_jar}")
        else:
            print("Prolog Cafe: skipped (--no-prolog-cafe)")
        print()

    def process_file(self, src: Path) -> bool:
        """Run all per-contract stages for one source file.

        Returns ``True`` on success.  Failures are reported locally and do not
        abort processing of other contracts.
        """
        name = src.stem
        print(f">>> Processing: {name}")

        try:
            print("  [1/3] Build executable Prolog...")
            executable = self.paths.executable_dir / f"{name}.pl"
            executable.unlink(missing_ok=True)
            with tempfile.TemporaryDirectory(prefix=f"{name}_", dir=self.paths.build_dir) as tmp:
                tmp_dir = Path(tmp)
                expanded = tmp_dir / "expanded.pl"
                native = tmp_dir / "native.pl"
                cleaned = tmp_dir / "caslog_clean.pl"
                query = f"module('{src}'). output('{expanded}'). halt."
                run_checked([self.ciaopp, "-T"], input_text=query, timeout=60)
                if not expanded.exists() or expanded.stat().st_size == 0:
                    raise RuntimeError("empty CiaoPP output")
                with contextlib.redirect_stdout(io.StringIO()):
                    expand_native(str(expanded), str(native))
                preclean_file(native, cleaned)
                run_checked(
                    [
                        "swipl",
                        "-q",
                        "-g",
                        f"consult('{self.paths.transform_pl}'), main, halt",
                        "--",
                        str(cleaned),
                        str(executable),
                    ],
                    timeout=120,
                )

            print("  [2/3] Normalize (destate + fix_dlist)...")
            normalize_stats = normalize(executable, self.paths.normalized_dir / f"{name}.pl")

            if self.options.run_caslog:
                print("  [3/3] Annotate + mode demotion...")
                annotated = self.paths.annotated_dir / f"{name}.pl"
                annotate(
                    self.paths.normalized_dir / f"{name}.pl",
                    annotated,
                    normalize_stats["fix_dlist"],
                )
                demote_modes.demote_fixpoint(annotated)
                apply_mode_overrides_to_file(annotated)
            else:
                print("  [3/3] Annotate + mode demotion... skipped (--no-caslog)")

        except Exception as exc:
            print(f"  FAILED: {exc}", file=sys.stderr)
            return False

        print(f"  SUCCESS: {name}")
        return True

    def write_stage_diff(self, names: list[str]) -> None:
        """Write a stage-by-stage diff report for successfully processed names."""
        last_stage = 3 if self.options.run_caslog else 2
        old = os.environ.get("STAGE_DIFF_LAST_STAGE")
        os.environ["STAGE_DIFF_LAST_STAGE"] = str(last_stage)
        try:
            generate_stage_diff(self.paths.root, names, self.paths.stage_diffs)
        except Exception as exc:
            print(f"  WARN: stage difference report failed: {exc}", file=sys.stderr)
        finally:
            if old is None:
                os.environ.pop("STAGE_DIFF_LAST_STAGE", None)
            else:
                os.environ["STAGE_DIFF_LAST_STAGE"] = old

    def run_caslog_results(self, names: list[str]) -> None:
        """Run CasLog on annotated contracts and extract compact results."""
        if not self.options.run_caslog:
            print("=== Stage: CasLog Run + Results Extraction ===")
            print("Skipped (--no-caslog)")
            print()
            return

        print("=== Stage: CasLog Run + Results Extraction ===")
        with self.paths.caslog_full_results.open("w", encoding="utf-8") as out:
            out.write("CasLog - contrats annotes (ciaoimp_pipeline)\n")
            out.write("=" * 64 + "\n")
            for name in names:
                out.write("========================================================\n")
                out.write(f"  CONTRAT : {name}\n")
                out.write("========================================================\n")
                out.write(
                    run_capture(
                        [self.caslog, str(self.paths.annotated_dir / f"{name}.pl")],
                        cwd=Path(self.caslog).parent,
                        timeout=120,
                    )
                )

        extract_important_results(self.paths.caslog_full_results, self.paths.caslog_important_results)
        print()
        print("=== CasLog Important Results ===")
        print(self.paths.caslog_important_results.read_text(encoding="utf-8"))

    def run_tnf_results(self, names: list[str]) -> int:
        """Compile normalized contracts to TNF ASM and run the Java VM (Tnf.java)."""
        if not self.options.run_tnf:
            print("=== Stage: TNF Compilation + Java VM Execution ===")
            print("Skipped (--no-tnf)")
            print()
            return 0

        print("=== Stage: TNF Compilation + Java VM Execution ===")
        ok = 0
        fail = 0
        java_dir = self.paths.bnf_java_dir
        with self.paths.tnf_results.open("w", encoding="utf-8") as out:
            for index, name in enumerate(names):
                if index:
                    out.write("\n")
                out.write(f"=== {name} ===\n")
                asm_out = self.paths.tnf_asm_dir / f"{name}_asm.txt"
                asm_out.unlink(missing_ok=True)
                compile_out = run_capture(
                    [
                        "swipl",
                        "-q",
                        "-g",
                        f"consult('{self.paths.tnf_pro}')",
                        "-g",
                        f"to_tasm('{self.paths.normalized_dir / f'{name}.pl'}','{asm_out}')",
                        "-g",
                        "halt",
                    ]
                )
                if compile_out:
                    out.write(compile_out)
                if not asm_out.exists() or asm_out.stat().st_size == 0:
                    out.write("  [ERREUR] compilation TNF echouee\n")
                    fail += 1
                    continue
                execution = run_capture(
                    ["java", "-cp", str(java_dir), "Tnf", str(asm_out)],
                    timeout=60,
                )
                out.write(execution)
                if "Exception" in execution or "Error" in execution:
                    fail += 1
                else:
                    ok += 1
            out.write(f"\nTNF : {ok} OK, {fail} ERREURS\n")

        extract_tnf_results(self.paths.tnf_results, self.paths.tnf_important_results)
        print()
        print("=== TNF Java VM Results ===")
        print(self.paths.tnf_important_results.read_text(encoding="utf-8"))
        return 0 if fail == 0 else 1

    def run_prolog_cafe_results(self, names: list[str]) -> int:
        """Translate Prolog to Java via Prolog Cafe and execute."""
        if not self.options.run_prolog_cafe:
            print("=== Stage: Prolog Cafe Translation + Java Execution ===")
            print("Skipped (--no-prolog-cafe)")
            print()
            return 0

        print("=== Stage: Prolog Cafe Translation + Java Execution ===")
        ok = 0
        fail = 0
        with self.paths.prolog_cafe_results.open("w", encoding="utf-8") as out:
            for index, name in enumerate(names):
                if index:
                    out.write("\n")
                out.write(f"=== {name} ===\n")
                
                input_pl = self.paths.normalized_dir / f"{name}.pl"
                src_dir = self.paths.prolog_cafe_src_dir / name
                am_dir = self.paths.prolog_cafe_am_dir / name
                classes_dir = self.paths.prolog_cafe_classes_dir / name
                
                src_dir.mkdir(parents=True, exist_ok=True)
                am_dir.mkdir(parents=True, exist_ok=True)
                classes_dir.mkdir(parents=True, exist_ok=True)

                # 1. Compile Prolog to Java
                plcafe_compile = run_capture(
                    ["java", "-cp", str(self.paths.plcafe_jar), "com.googlecode.prolog_cafe.compiler.Compiler", "-s", str(src_dir), "-am", str(am_dir), f"{name}.pl"],
                    cwd=self.paths.normalized_dir
                )
                if plcafe_compile and ("Exception" in plcafe_compile or "Error" in plcafe_compile):
                    out.write("  [ERREUR] Prolog Cafe compilation echouee\n")
                    out.write(plcafe_compile + "\n")
                    fail += 1
                    continue
                
                # 2. Generate Harness
                harness_path = src_dir / "PrologCafeMain.java"
                harness_content = self.paths.plcafe_main_template.read_text(encoding="utf-8")
                harness_path.write_text(harness_content, encoding="utf-8")

                # 3. Compile Java to Bytecode
                java_files = [str(f) for f in src_dir.rglob("*.java")]
                javac_out = run_capture(
                    ["javac", "-source", "1.8", "-target", "1.8", "-classpath", str(self.paths.plcafe_jar), "-d", str(classes_dir)] + java_files
                )
                if javac_out and ("error" in javac_out.lower() or "exception" in javac_out.lower()):
                    out.write("  [ERREUR] Java compilation echouee\n")
                    out.write(javac_out + "\n")
                    fail += 1
                    continue
                
                # 4. Execute JVM
                execution = run_capture(
                    ["java", "-cp", f"{classes_dir}{os.pathsep}{self.paths.plcafe_jar}", "PrologCafeMain"],
                    timeout=60,
                )
                out.write(execution)
                if "Exception" in execution or "Error" in execution:
                    fail += 1
                else:
                    ok += 1

            out.write(f"\nProlog Cafe : {ok} OK, {fail} ERREURS\n")
        
        print()
        print("=== Prolog Cafe Java Execution Results ===")
        print(self.paths.prolog_cafe_results.read_text(encoding="utf-8"))
        return 0 if fail == 0 else 1

    def run(self, args: list[str]) -> int:
        """Execute the selected pipeline and return a process-style exit code."""
        self.paths.ensure_dirs()
        inputs = self.resolve_inputs(args)
        if not inputs:
            print("No input files.", file=sys.stderr)
            return 1

        tool_status = self.check_tools()
        if tool_status:
            return tool_status

        self.print_header(inputs)
        success: list[str] = []
        fail = 0
        for src in inputs:
            if self.process_file(src):
                success.append(src.stem)
            else:
                fail += 1

        print()
        print("=== Summary (pipeline stages) ===")
        print(f"Successful: {len(success)}")
        print(f"Failed:     {fail}")
        print(f"Total:      {len(success) + fail}")
        print()

        if not success:
            print("No successful file; skipping aggregate stages.")
            return 1

        self.write_stage_diff(success)
        self.run_caslog_results(success)
        tnf_status = self.run_tnf_results(success)
        prolog_cafe_status = self.run_prolog_cafe_results(success)

        print("=== Generated Files ===")
        print(f"Stage diffs:              {self.paths.stage_diffs.relative_to(self.paths.root)}")
        if self.options.run_tnf:
            print(f"Contracts sent to TNF:    {self.paths.normalized_dir.relative_to(self.paths.root)}")
            print(f"TNF ASM:                  {self.paths.tnf_asm_dir.relative_to(self.paths.root)}")
            print(f"TNF full results:         {self.paths.tnf_results.relative_to(self.paths.root)}")
            print(f"TNF compact results:      {self.paths.tnf_important_results.relative_to(self.paths.root)}")
        if self.options.run_caslog:
            print(f"Contracts sent to CasLog: {self.paths.annotated_dir.relative_to(self.paths.root)}")
            print(f"CasLog full results:      {self.paths.caslog_full_results.relative_to(self.paths.root)}")
            print(f"CasLog important results: {self.paths.caslog_important_results.relative_to(self.paths.root)}")
        if self.options.run_prolog_cafe:
            print(f"Prolog Cafe classes:      {self.paths.prolog_cafe_classes_dir.relative_to(self.paths.root)}")
            print(f"Prolog Cafe results:      {self.paths.prolog_cafe_results.relative_to(self.paths.root)}")
        print("Done.")
        if fail:
            return 1
        return tnf_status or prolog_cafe_status
