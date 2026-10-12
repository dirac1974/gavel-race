"""Final Burst meter (src/burst_meter.py, mirror of BurstMeter.luau): scoring and arming (D-066)."""

import random
import re
from pathlib import Path

import pytest

import burst_meter as bm

FIXED = {"sweepSeconds": 2.0, "targetDrift": 0.0, "twoTargets": False, "phase": 0.0}


def test_marker_and_score_match_the_luau_reference_points():
    assert bm.position(0, 2.0) == pytest.approx(-1)
    assert bm.position(0.5, 2.0) == pytest.approx(0)
    assert bm.position(1.0, 2.0) == pytest.approx(1)
    assert bm.score(0.5, FIXED) == pytest.approx(100)
    assert bm.score(0.0, FIXED) == pytest.approx(0)


def test_a_tap_before_arming_is_ignored_not_scored():
    assert bm.tap_score(0.49, FIXED, 0.5) is None
    assert bm.tap_score(0.5, FIXED, 0.5) == pytest.approx(100)
    assert bm.tap_score(0.0, FIXED, 0.0) == pytest.approx(0)  # arm 0: before D-066, every tap counts


def test_arming_only_delays_input_the_marker_keeps_its_random_start():
    spec = dict(FIXED, phase=0.37)
    for t in (0.6, 1.1, 2.3):
        assert bm.tap_score(t, spec, 0.5) == pytest.approx(bm.score(t, spec))


def test_a_fixed_delay_macro_after_arming_still_scores_like_random():
    rng = random.Random(66)
    for delay in (0.5, 0.75, 1.0, 1.4):
        total = 0.0
        n = 4000
        for _ in range(n):
            spec = dict(FIXED, phase=rng.random())
            total += bm.tap_score(delay, spec, 0.5)
        assert total / n == pytest.approx(50, abs=2.5)


def test_the_default_arm_matches_game_config():
    config = (Path(__file__).resolve().parents[1] / "game" / "src" / "shared" / "GameConfig.luau").read_text(encoding="utf-8")
    m = re.search(r"^GameConfig\.burstArmSeconds = ([0-9.]+)", config, re.M)
    assert m, "GameConfig.burstArmSeconds not found"
    assert float(m.group(1)) == bm.BURST_ARM_SECONDS
    assert bm.tap_score(0.4, FIXED) is None  # the default is armed at 0.5 s, like the game
