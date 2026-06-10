"""Filesystem contract for the portable pipeline.

All path decisions are centralized here so transformation code does not bake in
relative paths.  The public build layout is intentionally small:

``build/executable``
    Prolog generated after all executable-program transformations.
``build/normalized``
    Input shared by TNF and CasLog annotation.
``build/annotated``
    CasLog-only input with inferred directives.
``build/tnf_asm``
    TNF assembly emitted by ``tools/LogicTransformers/tnf.pro``.
``build/bnf_asm``
    BNF assembly emitted by the ``basm`` predicate in ``tnf.pro``.
"""
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class PipelinePaths:
    """Derived paths for a pipeline checkout.

    Parameters
    ----------
    root:
        Absolute or relative path to ``ciaoimp_pipeline_portable``.
    """

    root: Path

    @property
    def source_dir(self) -> Path:
        return self.root / "data" / "source"

    @property
    def build_dir(self) -> Path:
        return self.root / "build"

    @property
    def results_dir(self) -> Path:
        return self.root / "results"

    @property
    def logs_dir(self) -> Path:
        return self.results_dir / "logs"

    @property
    def executable_dir(self) -> Path:
        return self.build_dir / "executable"

    @property
    def normalized_dir(self) -> Path:
        return self.build_dir / "normalized"

    @property
    def annotated_dir(self) -> Path:
        return self.build_dir / "annotated"

    @property
    def tnf_asm_dir(self) -> Path:
        return self.build_dir / "tnf_asm"

    @property
    def bnf_asm_dir(self) -> Path:
        return self.build_dir / "bnf_asm"

    @property
    def caslog_full_results(self) -> Path:
        return self.results_dir / "caslog_full_results.txt"

    @property
    def caslog_important_results(self) -> Path:
        return self.results_dir / "caslog_important_results.txt"

    @property
    def stage_diffs(self) -> Path:
        return self.results_dir / "stage_diffs.txt"

    @property
    def tnf_results(self) -> Path:
        return self.results_dir / "tnf_results.txt"

    @property
    def tnf_important_results(self) -> Path:
        return self.results_dir / "tnf_important_results.txt"

    @property
    def bnf_results(self) -> Path:
        return self.results_dir / "bnf_results.txt"

    @property
    def bnf_important_results(self) -> Path:
        return self.results_dir / "bnf_important_results.txt"

    @property
    def prolog_cafe_src_dir(self) -> Path:
        return self.build_dir / "prolog_cafe_src"

    @property
    def prolog_cafe_am_dir(self) -> Path:
        return self.build_dir / "prolog_cafe_am"

    @property
    def prolog_cafe_classes_dir(self) -> Path:
        return self.build_dir / "prolog_cafe_classes"

    @property
    def prolog_cafe_results(self) -> Path:
        return self.results_dir / "prolog_cafe_results.txt"

    @property
    def plcafe_jar(self) -> Path:
        return self.root / "tools" / "prolog_cafe" / "plcafe.jar"

    @property
    def caslog_bin(self) -> Path:
        return self.root / "tools" / "caslog" / "caslog.gprolog"

    @property
    def plcafe_main_template(self) -> Path:
        return self.root / "tools" / "prolog_cafe" / "PrologCafeMain.template.java"

    @property
    def tnf_pro(self) -> Path:
        return self.root / "tools" / "LogicTransformers" / "tnf.pro"

    @property
    def bnf_java_dir(self) -> Path:
        return self.root / "tools" / "LogicTransformers" / "java"

    @property
    def transform_pl(self) -> Path:
        return self.root / "src" / "transforms" / "caslog_transform.pl"

    def ensure_dirs(self) -> None:
        """Create all generated-output directories used by the pipeline."""
        for directory in (
            self.executable_dir,
            self.normalized_dir,
            self.annotated_dir,
            self.tnf_asm_dir,
            self.bnf_asm_dir,
            self.prolog_cafe_src_dir,
            self.prolog_cafe_am_dir,
            self.prolog_cafe_classes_dir,
            self.logs_dir,
        ):
            directory.mkdir(parents=True, exist_ok=True)
