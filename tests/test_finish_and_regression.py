"""Finish-order sampling and regression numbers recorded in docs/V2_PROPOSAL.md."""
import random

import pytest

from gavel_race_v2 import (
    Config, REPO_Q, REPO_S, RATINGS, PLACE_PRIZES,
    base_chances, lock_purses, skills, live_chances,
    draw_finish, pick_winner, place_probs, v1_adjust, round_tier,
)

CFG = Config()


def test_draw_finish_is_a_permutation():
    rng = random.Random(1)
    for _ in range(500):
        order = draw_finish(REPO_Q, rng)
        assert sorted(order) == list(range(8))


def test_sampled_win_and_place_frequencies_match_harville():
    # 60k draws: standard error of a 25% frequency is ~0.18 points,
    # so a 1-point tolerance is ~5 sigma and stable across platforms.
    rng = random.Random(42)
    n = 60_000
    counts = [[0] * 4 for _ in REPO_Q]
    for _ in range(n):
        for pos, lane in enumerate(draw_finish(REPO_Q, rng)[:4]):
            counts[lane][pos] += 1
    exact = place_probs(REPO_Q)
    for lane in range(8):
        for pos in range(4):
            assert counts[lane][pos] / n == pytest.approx(exact[lane][pos], abs=0.01)


def test_place_probs_rows_and_columns():
    pp = place_probs(REPO_Q)
    for pos in range(4):
        assert sum(r[pos] for r in pp) == pytest.approx(1.0, abs=1e-12)
    for lane, row in enumerate(pp):
        assert row[0] == pytest.approx(REPO_Q[lane], abs=1e-12)
        assert sum(row) <= 1.0 + 1e-12


def test_pick_winner_matches_p():
    rng = random.Random(3)
    n = 60_000
    hits = [0] * 8
    for _ in range(n):
        hits[pick_winner(REPO_Q, rng)] += 1
    for h, q in zip(hits, REPO_Q):
        assert h / n == pytest.approx(q, abs=0.01)


# ---- regression: numbers quoted in docs/V2_PROPOSAL.md

def test_lobby_example_base_chances():
    q = base_chances(RATINGS, CFG)
    assert q[0] == pytest.approx(0.215, abs=0.001)   # "favorite 21.5%"
    assert q[-1] == pytest.approx(0.062, abs=0.001)  # "longshot 6.2%"
    assert lock_purses(q, CFG) == [464, 572, 704, 809, 930, 1068, 1228, 1621]


def test_repo_example_field_live_chances():
    p = live_chances(REPO_Q, skills(REPO_S, CFG), CFG)
    expected = [0.394, 0.229, 0.135, 0.089, 0.063, 0.044, 0.029, 0.018]
    for a, b in zip(p, expected):
        assert a == pytest.approx(b, abs=0.001)
    # live chance strictly in skill order relative to base
    ratios = [pi / qi for pi, qi in zip(p, REPO_Q)]
    assert ratios == sorted(ratios, reverse=True)


def test_expected_cash_per_entry_range():
    pp = place_probs(REPO_Q)
    per_entry = [1 + sum(w * r[j + 1] for j, w in enumerate(PLACE_PRIZES)) for r in pp]
    assert per_entry[0] == pytest.approx(1.46, abs=0.01)
    assert per_entry[-1] == pytest.approx(1.13, abs=0.01)


def test_collusion_bound():
    q = [1 / 8] * 8
    p = live_chances(q, skills([100] + [0] * 7, CFG), CFG)
    assert p[0] == pytest.approx(0.333, abs=0.001)  # x2.66


def test_v1_defect_still_reproduced():
    # Documents why v1 was replaced; v1 code itself is frozen.
    o = [round_tier(1 / (qi * 1.07)) for qi in REPO_Q]
    p = v1_adjust(REPO_Q, [(s - 50) / 50 for s in REPO_S], o)
    assert p[-1] == pytest.approx(0.0795, abs=0.0005)
