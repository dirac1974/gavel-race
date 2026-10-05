import random
import statistics

import pytest

import stride

HALF = 0.08


class ListRng:
    def __init__(self, values):
        self.values, self.i = list(values), 0

    def random(self):
        v = self.values[self.i]
        self.i += 1
        return v


def rookie(rng, start=0.0):
    return stride.schedule(rng, start, 8, 0.60, 0.60, 0.0, False)


def champion(rng, start=0.0):
    return stride.schedule(rng, start, 8, 0.42, 0.48, 0.03, True)


def test_schedule_consumes_one_uniform_per_drifting_beat():
    rng = ListRng([0.5] * 8)
    beats = stride.schedule(rng, 10.0, 8, 0.4, 0.6, 0.03, False)
    assert rng.i == 8 and len(beats) == 8 and beats[0] == 10.0
    assert beats == pytest.approx([10.0 + 0.5 * k for k in range(8)])  # u = 0.5 means no drift


def test_rookie_tempo_is_steady():
    beats = rookie(random.Random(1))
    gaps = [b - a for a, b in zip(beats, beats[1:])]
    assert gaps == pytest.approx([0.6] * 7)


def test_champion_has_one_half_beat_lead_change():
    rng = ListRng([0.0] + [0.5] * 7)
    beats = stride.schedule(rng, 0.0, 8, 0.42, 0.48, 0.03, True)
    gaps = [b - a for a, b in zip(beats, beats[1:])]
    assert gaps[3] == pytest.approx(0.42 * 1.5)
    assert [g for i, g in enumerate(gaps) if i != 3] == pytest.approx([0.42] * 6)


@pytest.mark.parametrize("seed", range(20))
def test_beats_stay_far_enough_apart_for_unambiguous_windows(seed):
    beats = champion(random.Random(seed))
    assert min(b - a for a, b in zip(beats, beats[1:])) > 2 * HALF


def test_perfect_taps_score_100_and_no_taps_score_0():
    beats = rookie(random.Random(2))
    assert stride.score(beats, beats, HALF) == pytest.approx(100)
    assert stride.score(beats, [], HALF) == 0
    assert stride.score([], [1.0], HALF) == 0


def test_closeness_is_linear_and_window_edge_scores_nothing():
    beats = [0.0, 0.6]
    assert stride.score(beats, [0.04, 0.6], HALF) == pytest.approx(75)
    assert stride.score(beats, [0.08, 0.6], HALF) == pytest.approx(50)


def test_extra_taps_count_against_and_score_floors_at_zero():
    beats = rookie(random.Random(3))
    with_extra = list(beats) + [beats[0] + 0.3]
    assert stride.score(beats, with_extra, HALF) == pytest.approx(100 * 7 / 8)
    double_tap = list(beats) + [b + 0.02 for b in beats]  # the closer tap wins, the other is extra
    assert stride.score(beats, double_tap, HALF) == 0


def test_mashing_scores_zero():
    beats = rookie(random.Random(4))
    mash = [k * 0.05 for k in range(int(beats[-1] / 0.05) + 2)]
    assert stride.score(beats, mash, HALF) == 0


def test_fixed_rhythm_macro_scores_low_against_drifting_tempo():
    rng = random.Random(5)
    scores = []
    for _ in range(300):
        beats = champion(rng)
        macro = [beats[0] + k * 0.45 for k in range(len(beats))]
        scores.append(stride.score(beats, macro, HALF))
    assert statistics.mean(scores) < 25


def test_human_beats_macro_and_mash():
    rng = random.Random(6)
    human = []
    for _ in range(300):
        beats = champion(rng)
        human.append(stride.score(beats, [b + rng.gauss(-0.02, 0.03) for b in beats], HALF))
    assert statistics.mean(human) > 40


def test_gap_errors_zero_for_perfect_and_skip_missed_beats():
    beats = rookie(random.Random(7))
    assert stride.gap_errors(beats, beats, HALF) == pytest.approx([0.0] * 7)
    missing_third = [b for i, b in enumerate(beats) if i != 2]
    assert len(stride.gap_errors(beats, missing_third, HALF)) == 5


def test_gap_error_spread_separates_people_from_bots():
    rng = random.Random(8)

    def spread(sd):
        errs = []
        for _ in range(20):
            beats = champion(rng)
            errs += stride.gap_errors(beats, [b + rng.gauss(0, sd) for b in beats], HALF)
        return statistics.pstdev(errs)

    assert spread(0.030) > 0.030   # gap errors carry two taps' noise
    assert spread(0.005) < 0.012   # a beat-tracking bot falls under the D-022 threshold
