"""D-071 tap preview report gates on a small seeded subset (the full 3,840-race run is in CI):
lune run tests/luau/tap_preview_report 6 boxed=3. Skips without Lune."""

import re
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]


@pytest.mark.skipif(shutil.which("lune") is None, reason="lune not installed")
def test_every_gate_passes_on_a_seeded_subset() -> None:
    out = subprocess.run(["lune", "run", "tests/luau/tap_preview_report", "6", "boxed=3"], cwd=ROOT,
                         capture_output=True, text=True)
    gates = {}
    for line in out.stdout.splitlines():
        m = re.match(r"gate (.+?)\s+(PASS|FAIL)  (.*)$", line)
        if m:
            gates[m.group(1).strip()] = (m.group(2) == "PASS", m.group(3))
    assert len(gates) == 16, out.stdout + out.stderr
    failed = {name: detail for name, (ok, detail) in gates.items() if not ok}
    assert not failed and out.returncode == 0, failed
