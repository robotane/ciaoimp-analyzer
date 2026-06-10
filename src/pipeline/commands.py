"""Subprocess helpers used by the pipeline runner.

The pipeline invokes several external tools: CiaoPP, SWI-Prolog, CasLog and the
TNF Python VM.  These helpers keep subprocess behavior consistent and make the
runner code read as orchestration rather than low-level process management.
"""
from __future__ import annotations

import os
import shutil
import subprocess
from pathlib import Path


def find_executable(name: str, env_name: str | None = None) -> str:
    """Return an executable path from an override environment variable or PATH.

    ``env_name`` wins over PATH lookup.  An empty string is returned instead of
    raising so callers can produce domain-specific error messages.
    """
    if env_name and os.environ.get(env_name):
        return os.environ[env_name]
    return shutil.which(name) or ""


def run_checked(
    argv: list[str],
    *,
    cwd: Path | None = None,
    env: dict[str, str] | None = None,
    input_text: str | None = None,
    timeout: int | None = None,
    quiet: bool = True,
) -> subprocess.CompletedProcess[str]:
    """Run a command that must succeed.

    Raises ``subprocess.CalledProcessError`` on non-zero exit.  By default,
    stdout/stderr are suppressed because the pipeline prints stage-level status
    and writes detailed tool output to result files where appropriate.
    """
    stdout = subprocess.DEVNULL if quiet else subprocess.PIPE
    stderr = subprocess.DEVNULL if quiet else subprocess.PIPE
    return subprocess.run(
        argv,
        cwd=str(cwd) if cwd else None,
        env=env,
        input=input_text,
        text=True,
        stdout=stdout,
        stderr=stderr,
        timeout=timeout,
        check=True,
    )


def run_capture(
    argv: list[str],
    *,
    cwd: Path | None = None,
    env: dict[str, str] | None = None,
    timeout: int | None = None,
) -> str:
    """Run a command and return combined stdout/stderr without raising."""
    res = subprocess.run(
        argv,
        cwd=str(cwd) if cwd else None,
        env=env,
        capture_output=True,
        text=True,
        timeout=timeout,
        check=False,
    )
    return res.stdout + res.stderr
