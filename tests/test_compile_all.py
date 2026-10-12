"""Every Luau file under game/src compiles, tracked in git or not (code review N9: a new module or a
Studio-only script that fails to compile is otherwise only caught in Studio), and RaceController
keeps room under Luau's 200 top-level locals for Phase 4's HUD restyle."""
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
# Files expected to fail for now, each with who is fixing it. Keep empty unless a fix is in flight.
EXPECTED_BROKEN: set[str] = set()


@pytest.mark.skipif(shutil.which("lune") is None, reason="lune not installed")
def test_every_game_luau_compiles():
    files = sorted(str(p.relative_to(ROOT)).replace("\\", "/") for p in (ROOT / "game" / "src").rglob("*.luau"))
    assert files
    out = subprocess.run(["lune", "run", "tests/luau/syntax_check", "--", *files], cwd=ROOT, capture_output=True, text=True)
    failed = {line.split()[1] for line in out.stdout.splitlines() if line.startswith("FAIL ")}
    assert failed <= EXPECTED_BROKEN, out.stdout + out.stderr
    assert not (EXPECTED_BROKEN - set(files)), "EXPECTED_BROKEN names a file that no longer exists"


@pytest.mark.skipif(shutil.which("lune") is None, reason="lune not installed")
def test_race_controller_has_room_for_more_locals():
    out = subprocess.run(["lune", "run", "tests/luau/local_headroom", "--", "game/src/client/RaceController.client.luau", "30"],
                         cwd=ROOT, capture_output=True, text=True)
    assert out.returncode == 0, out.stdout + out.stderr
