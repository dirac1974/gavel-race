"""Runs the Luau parity suite under Lune when Lune is installed; skips otherwise."""

import shutil
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]


@pytest.mark.skipif(shutil.which("lune") is None, reason="lune not installed")
def test_luau_matches_python_reference():
    subprocess.run([sys.executable, "tests/fixtures/make_fixtures.py"], cwd=ROOT, check=True)
    out = subprocess.run(["lune", "run", "tests/luau/run_all"], cwd=ROOT, capture_output=True, text=True)
    assert out.returncode == 0, out.stdout + out.stderr


@pytest.mark.skipif(shutil.which("lune") is None, reason="lune not installed")
def test_all_luau_compiles():
    files = subprocess.run(["git", "ls-files", "*.luau"], cwd=ROOT, capture_output=True, text=True).stdout.split()
    files = [f for f in files if f] or [str(p.relative_to(ROOT)) for p in ROOT.rglob("*.luau")]
    out = subprocess.run(["lune", "run", "tests/luau/syntax_check", "--", *files], cwd=ROOT, capture_output=True, text=True)
    assert out.returncode == 0, out.stdout + out.stderr
