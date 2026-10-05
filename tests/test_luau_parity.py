"""Python–Luau parity. Skipped until a Luau runtime (lune) is installed.

Backlog item 1 in docs/memory/STATUS.md: install lune, write a small runner
that loads src/RaceMath.luau and evaluates tests/fixtures/race_cases.json,
then compare here to 1e-9.
"""
import json
import shutil
from pathlib import Path

import pytest

from gavel_race_v2 import Config, base_chances, lock_purses, skills, live_chances

FIXTURES = Path(__file__).parent / "fixtures" / "race_cases.json"


def test_fixtures_match_python_reference():
    cases = json.loads(FIXTURES.read_text())
    for c in cases:
        cfg = Config(**c["config"])
        q = base_chances(c["ratings"], cfg)
        R = skills(c["scores"], cfg)
        assert q == pytest.approx(c["expected"]["q"], abs=1e-12)
        assert lock_purses(q, cfg) == c["expected"]["purses"]
        assert R == pytest.approx(c["expected"]["R"], abs=1e-12)
        assert live_chances(q, R, cfg) == pytest.approx(c["expected"]["p"], abs=1e-12)


@pytest.mark.skipif(shutil.which("lune") is None, reason="lune not installed")
def test_luau_matches_python():
    pytest.skip("Luau runner not written yet (STATUS backlog item 1)")
