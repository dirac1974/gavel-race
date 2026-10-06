"""Runs the Luau parity suite under Lune when Lune is installed; skips otherwise."""

import hashlib
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "tests" / "fixtures"
# What the generated fixtures depend on: make_fixtures.py, the modules it imports and the
# baseline table it reads. The stamp beside the generated files holds their hash, so an
# unchanged tree skips the regeneration (CI starts clean and always generates).
FIXTURE_INPUTS = [
    ROOT / "src" / "trip.py", ROOT / "src" / "gavel_race_v2.py", ROOT / "src" / "race_rating.py",
    ROOT / "src" / "stride.py", ROOT / "src" / "pace_meter.py", FIXTURES / "make_fixtures.py",
    FIXTURES / "trip_baseline.json", FIXTURES / "trip_baseline_d054.json",
]
FIXTURE_OUTPUTS = [FIXTURES / "race_math.json", FIXTURES / "trip.json", FIXTURES / "trip_d054.json",
                   FIXTURES / "trip_d057.json"]
STAMP = FIXTURES / ".fixtures.sha256"


def fixture_inputs_hash() -> str:
    h = hashlib.sha256()
    for path in FIXTURE_INPUTS:
        h.update(path.name.encode())
        h.update(path.read_bytes())
    return h.hexdigest()


def ensure_fixtures() -> None:
    digest = fixture_inputs_hash()
    current = all(p.exists() for p in FIXTURE_OUTPUTS) and STAMP.exists() and STAMP.read_text().strip() == digest
    if not current:
        subprocess.run([sys.executable, "tests/fixtures/make_fixtures.py", "--d057"], cwd=ROOT, check=True)
        STAMP.write_text(digest + "\n")


@pytest.mark.skipif(shutil.which("lune") is None, reason="lune not installed")
def test_luau_matches_python_reference():
    ensure_fixtures()
    out = subprocess.run(["lune", "run", "tests/luau/run_all"], cwd=ROOT, capture_output=True, text=True)
    assert out.returncode == 0, out.stdout + out.stderr


@pytest.mark.skipif(shutil.which("lune") is None, reason="lune not installed")
def test_all_luau_compiles():
    files = subprocess.run(["git", "ls-files", "*.luau"], cwd=ROOT, capture_output=True, text=True).stdout.split()
    files = [f for f in files if f] or [str(p.relative_to(ROOT)) for p in ROOT.rglob("*.luau")]
    out = subprocess.run(["lune", "run", "tests/luau/syntax_check", "--", *files], cwd=ROOT, capture_output=True, text=True)
    assert out.returncode == 0, out.stdout + out.stderr


def test_fixture_stamp_covers_the_generators_inputs():
    """Every module make_fixtures.py imports is in the stamp's inputs, so a change to any of them
    regenerates the fixtures."""
    text = (FIXTURES / "make_fixtures.py").read_text(encoding="utf-8")
    for module in ("gavel_race_v2", "race_rating", "stride", "pace_meter", "trip"):
        assert f"import {module}" in text
        assert ROOT / "src" / f"{module}.py" in FIXTURE_INPUTS
