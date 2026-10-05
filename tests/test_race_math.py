"""Invariant, regression, and statistical tests for the v2 race model."""

import math
import random

import pytest

import gavel_race_v2 as m

REPO_Q = m.REPO_Q
REPO_S = m.REPO_S


def rand_field(rng, n=8):
    ratings = [rng.uniform(30, 90) for _ in range(n)]
    scores = [rng.uniform(0, 100) for _ in range(n)]
    return ratings, scores


# ---------------------------------------------------------------- invariants

@pytest.mark.parametrize("seed", range(200))
def test_live_chances_positive_and_sum_to_one(seed):
    rng = random.Random(seed)
    cfg = m.Config(T=rng.choice([12, 14.4, 18, 22]), kappa=rng.uniform(0.5, 1.5))
    ratings, scores = rand_field(rng)
    q = m.base_chances(ratings, cfg)
    p = m.live_chances(q, m.skills(scores, cfg), cfg)
    assert all(x > 0 for x in p)
    assert math.isclose(sum(p), 1.0, abs_tol=1e-12)


@pytest.mark.parametrize("seed", range(100))
def test_own_skill_never_lowers_own_chance(seed):
    rng = random.Random(seed)
    cfg = m.Config()
    ratings, scores = rand_field(rng)
    q = m.base_chances(ratings, cfg)
    i = rng.randrange(8)
    before = m.live_chances(q, m.skills(scores, cfg), cfg)[i]
    better = list(scores)
    better[i] = min(100.0, better[i] + rng.uniform(1, 40))
    after = m.live_chances(q, m.skills(better, cfg), cfg)[i]
    assert after >= before - 1e-12


@pytest.mark.parametrize("seed", range(100))
def test_a_rival_improving_never_raises_your_chance(seed):
    """Holds whenever no clamp binds (scores within ~25 points of the race average)."""
    rng = random.Random(seed)
    cfg = m.Config()
    scores = [rng.uniform(35, 65) for _ in range(8)]
    q = m.base_chances([rng.uniform(40, 80) for _ in range(8)], cfg)
    before = m.live_chances(q, m.skills(scores, cfg), cfg)[0]
    j = rng.randrange(1, 8)
    scores[j] += rng.uniform(1, 10)
    after = m.live_chances(q, m.skills(scores, cfg), cfg)[0]
    assert after <= before + 1e-12


def test_known_clamp_edge_case_is_tiny():
    """Documented edge case: if you sit at the R floor and a rival is capped at R = 1,
    that rival scoring higher raises the race average, lowers the other riders,
    and can nudge your chance up. Keep the effect small."""
    cfg = m.Config()
    q = [1 / 8] * 8
    base = [0, 100, 50, 50, 50, 50, 50, 50]
    raised = [0, 100, 60, 60, 60, 60, 60, 60]
    a = m.live_chances(q, m.skills(base, cfg), cfg)[0]
    b = m.live_chances(q, m.skills(raised, cfg), cfg)[0]
    assert b - a < 0.01


def test_equal_scores_return_base_chances_exactly():
    cfg = m.Config()
    q = m.base_chances([70, 67, 64, 62, 60, 58, 56, 52], cfg)
    for s in (0, 37.5, 50, 100):
        p = m.live_chances(q, m.skills([s] * 8, cfg), cfg)
        for a, b in zip(p, q):
            assert math.isclose(a, b, rel_tol=1e-12)


@pytest.mark.parametrize("seed", range(50))
def test_race_average_centering_is_shift_invariant_inside_clamp(seed):
    """Adding a constant to every score changes nothing while no clamp binds."""
    rng = random.Random(seed)
    cfg = m.Config()
    scores = [rng.uniform(40, 60) for _ in range(8)]
    q = m.base_chances([rng.uniform(40, 80) for _ in range(8)], cfg)
    a = m.live_chances(q, m.skills(scores, cfg), cfg)
    b = m.live_chances(q, m.skills([s + 17 for s in scores], cfg), cfg)
    for x, y in zip(a, b):
        assert math.isclose(x, y, rel_tol=1e-12)


def test_skill_clamped():
    cfg = m.Config()
    r = m.skills([100] + [0] * 7, cfg)
    assert r[0] == 1.0
    r = m.skills([0] + [100] * 7, cfg)
    assert r[0] == cfg.r_floor


def test_base_chance_floor():
    cfg = m.Config()
    q = m.base_chances([100, 100, 100, 100, 100, 100, 100, 0], cfg)
    assert math.isclose(sum(q), 1.0, abs_tol=1e-12)
    assert q[-1] >= cfg.q_floor * 0.95  # renormalization can dip slightly below


def test_temperature_doubles_per_ten_points():
    cfg = m.Config(T=10 / math.log(2), q_floor=0.0)
    q = m.base_chances([60, 50], cfg)
    assert math.isclose(q[0] / q[1], 2.0, rel_tol=1e-9)


@pytest.mark.parametrize("B", [20, 50, 100, 120, 300, 750])
def test_purse_expected_value_equals_B(B):
    cfg = m.Config(B=B)
    q = m.base_chances([70, 67, 64, 62, 60, 58, 56, 52], cfg)
    purses = m.lock_purses(q, cfg)
    for qi, pu in zip(q, purses):
        # whole-cash rounding moves q * purse by at most 0.5 q
        assert abs(qi * pu - B) <= qi * 0.5 + 1e-9


def test_window_score_bounds():
    assert m.window_score(0) == 100
    assert m.window_score(1) == 0
    assert m.window_score(2) == 0
    assert m.window_score(-1) == 100
    assert m.window_score(0.25) == 75


# ---------------------------------------------------------------- regression

def test_repo_example_matches_proposal():
    cfg = m.Config()
    p = m.live_chances(REPO_Q, m.skills(REPO_S, cfg), cfg)
    expected = [0.394, 0.229, 0.135, 0.089, 0.063, 0.044, 0.029, 0.018]
    for got, want in zip(p, expected):
        assert abs(got - want) < 0.0015


def test_lobby_example_matches_proposal():
    cfg = m.Config()
    q = m.base_chances([70, 67, 64, 62, 60, 58, 56, 52], cfg)
    expected = [0.215, 0.175, 0.142, 0.124, 0.108, 0.094, 0.081, 0.062]
    for got, want in zip(q, expected):
        assert abs(got - want) < 0.0015


def test_collusion_number():
    cfg = m.Config()
    p = m.live_chances([1 / 8] * 8, m.skills([100] + [0] * 7, cfg), cfg)
    assert abs(p[0] - 0.333) < 0.001


# ---------------------------------------------------------------- statistics

def test_finish_draw_win_frequencies_match_p():
    rng = random.Random(123)
    p = [0.3, 0.2, 0.15, 0.1, 0.1, 0.07, 0.05, 0.03]
    n = 40000
    wins = [0] * 8
    for _ in range(n):
        order = m.draw_finish(p, rng)
        assert sorted(order) == list(range(8))
        wins[order[0]] += 1
    for i in range(8):
        sd = math.sqrt(p[i] * (1 - p[i]) / n)
        assert abs(wins[i] / n - p[i]) < 5 * sd


def test_finish_draw_second_place_matches_harville():
    rng = random.Random(7)
    p = [0.4, 0.3, 0.2, 0.1]
    exact = m.place_probs(p, depth=2)
    n = 40000
    second = [0] * 4
    for _ in range(n):
        second[m.draw_finish(p, rng)[1]] += 1
    for i in range(4):
        pi = exact[i][1]
        assert abs(second[i] / n - pi) < 5 * math.sqrt(pi * (1 - pi) / n)


def test_place_probs_rows_and_columns_sum():
    pp = m.place_probs([0.25, 0.2, 0.15, 0.12, 0.1, 0.08, 0.06, 0.04])
    for pos in range(4):
        assert math.isclose(sum(r[pos] for r in pp), 1.0, abs_tol=1e-12)


def test_skill_premium_kappa_one_top_decile():
    """P90 rider (S ~ 69) earns roughly +35% win cash vs. B (V2_PROPOSAL)."""
    rng = random.Random(5)
    cfg = m.Config()
    q = [1 / 8] * 8
    n = 20000
    tot = 0.0
    for _ in range(n):
        s = [69.2] + [rng.gauss(50, 15) for _ in range(7)]
        tot += m.live_chances(q, m.skills(s, cfg), cfg)[0] / q[0]
    assert 0.30 < tot / n - 1 < 0.40
