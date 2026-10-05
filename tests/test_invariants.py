"""Invariants of the v2 race model (docs/V2_PROPOSAL.md). Deterministic seeds."""
import math
import random

import pytest

from gavel_race_v2 import (
    Config, base_chances, lock_purses, window_score, skills, live_chances,
)

CFG = Config()
SEEDS = range(200)


def random_field(rng, n=8):
    ratings = [rng.uniform(30, 90) for _ in range(n)]
    scores = [rng.uniform(0, 100) for _ in range(n)]
    return ratings, scores


@pytest.mark.parametrize("seed", SEEDS)
def test_chances_positive_and_sum_to_one(seed):
    rng = random.Random(seed)
    ratings, scores = random_field(rng)
    q = base_chances(ratings, CFG)
    p = live_chances(q, skills(scores, CFG), CFG)
    for dist in (q, p):
        assert all(x > 0 for x in dist)
        assert math.isclose(sum(dist), 1.0, abs_tol=1e-12)


@pytest.mark.parametrize("seed", SEEDS)
def test_raising_own_score_never_lowers_own_chance(seed):
    rng = random.Random(seed)
    ratings, scores = random_field(rng)
    q = base_chances(ratings, CFG)
    lane = rng.randrange(8)
    before = live_chances(q, skills(scores, CFG), CFG)[lane]
    scores[lane] = min(100.0, scores[lane] + rng.uniform(0.1, 30))
    after = live_chances(q, skills(scores, CFG), CFG)[lane]
    assert after >= before - 1e-12


@pytest.mark.parametrize("score", [0, 37.5, 50, 100])
def test_equal_scores_return_base_chances_exactly(score):
    q = base_chances([70, 67, 64, 62, 60, 58, 56, 52], CFG)
    p = live_chances(q, skills([score] * 8, CFG), CFG)
    for a, b in zip(p, q):
        assert math.isclose(a, b, rel_tol=1e-12)


@pytest.mark.parametrize("seed", range(50))
def test_race_average_centering_is_shift_invariant_inside_clamps(seed):
    # Shift every score by the same amount: chances must not change
    # as long as no lane hits a clamp edge.
    rng = random.Random(seed)
    scores = [rng.uniform(40, 60) for _ in range(8)]
    q = [1 / 8] * 8
    a = live_chances(q, skills(scores, CFG), CFG)
    b = live_chances(q, skills([s + 15 for s in scores], CFG), CFG)
    for x, y in zip(a, b):
        assert math.isclose(x, y, rel_tol=1e-12)


def test_skill_clamps():
    # mean 12.5: top lane (100) clamps at +1; the zeros sit at -0.25, inside the floor
    R = skills([100] + [0] * 7, CFG)
    assert R[0] == 1.0
    assert all(r == pytest.approx(-0.25) for r in R[1:])
    # mean 87.5: bottom lane (0) clamps at the floor
    R = skills([0] + [100] * 7, CFG)
    assert R[0] == CFG.r_floor
    assert all(r == pytest.approx(0.25) for r in R[1:])


def test_q_floor_applied_before_renormalizing():
    # Spec: floor each q at 2.5%, then renormalize, so a floored lane ends
    # slightly below 2.5% (here 2.44%). Guard that it stays above 2%.
    raw = [100, 100, 100, 100, 100, 100, 100, 0]
    q = base_chances(raw, CFG)
    assert q[-1] < CFG.q_floor
    assert q[-1] > 0.02


@pytest.mark.parametrize("seed", range(100))
def test_purse_expected_value_equals_B_within_tolerance(seed):
    rng = random.Random(seed)
    ratings = [rng.uniform(40, 80) for _ in range(8)]
    for B in (20, 50, 120, 300, 750):
        cfg = Config(B=B)
        q = base_chances(ratings, cfg)
        for qi, purse in zip(q, lock_purses(q, cfg)):
            # Rounding to whole cash moves q * purse by at most 0.5 q (D-017).
            # As a share of B that is 0.5 q / B: up to ~1% for a strong favorite
            # in Rookie (B 20), under 0.2% from Silver up. See V2_PROPOSAL step 2.
            assert abs(qi * purse - B) <= 0.5 * qi + 1e-9


def test_window_score_bounds():
    assert window_score(0) == 100
    assert window_score(1) == 0
    assert window_score(-0.5) == 100
    assert window_score(3) == 0
    assert window_score(0.5) == 50


def test_tilt_has_no_negative_or_nan_at_extremes():
    q = base_chances([90, 10, 10, 10, 10, 10, 10, 10], CFG)
    for scores in ([100] + [0] * 7, [0] + [100] * 7):
        p = live_chances(q, skills(scores, CFG), CFG)
        assert all(x > 0 and not math.isnan(x) for x in p)
