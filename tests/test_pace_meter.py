import random
import statistics

import pytest

import pace_meter as pm

# D-026 settings (GameConfig.pace): drift 0.15, target within +-0.6, moves every 2-3 passes.
DRIFT, CRANGE, SMIN, SMAX = 0.15, 0.6, 2, 3


class ListRng:
    def __init__(self, values):
        self.values, self.i = list(values), 0

    def random(self):
        v = self.values[self.i]
        self.i += 1
        return v


def race(rng, sweep=2.4, duration=36.0):
    return pm.schedule(rng, 0.0, duration, sweep, DRIFT, SMIN, SMAX, CRANGE)


def test_passes_are_back_to_back_with_no_pauses():
    passes = race(random.Random(1))
    assert passes[0].t0 == 0.0
    for a, b in zip(passes, passes[1:]):
        assert b.t0 == pytest.approx(a.t1)
        assert b.dir == -a.dir
    assert passes[-1].t1 >= 36.0


def test_pass_length_and_target_stay_in_range():
    for p in race(random.Random(2), sweep=1.6):
        assert 0.8 * (1 - DRIFT) - 1e-9 <= p.t1 - p.t0 <= 0.8 * (1 + DRIFT) + 1e-9
        assert abs(p.center) <= CRANGE + 1e-12


def test_target_moves_every_two_or_three_passes():
    passes = race(random.Random(3))
    runs, run = [], 1
    for a, b in zip(passes, passes[1:]):
        if b.center == a.center:
            run += 1
        else:
            runs.append(run)
            run = 1
    assert runs and set(runs) <= {2, 3}


def test_uniform_consumption_order():
    rng = ListRng([0.75, 0.0, 0.5, 0.5, 0.5, 0.5])  # centre, run length (2), then speeds
    passes = pm.schedule(rng, 10.0, 2.4, 2.4, DRIFT, SMIN, SMAX, CRANGE)
    assert passes[0].center == pytest.approx(0.3) and passes[1].center == pytest.approx(0.3)
    assert passes[0].t1 - passes[0].t0 == pytest.approx(1.2)
    assert rng.i == 4


def test_position_and_ideal_time():
    p = pm.Pass(0.0, 1.0, 1, 0.5)
    assert pm.position(p, 0.0) == -1 and pm.position(p, 1.0) == 1
    assert pm.position(p, pm.ideal_time(p)) == pytest.approx(0.5)
    back = pm.Pass(0.0, 1.0, -1, 0.5)
    assert pm.position(back, pm.ideal_time(back)) == pytest.approx(0.5)
    assert pm.tap_score(p, pm.ideal_time(p)) == pytest.approx(100)


def test_one_tap_per_pass_missed_and_doubled_score_zero():
    passes = race(random.Random(4))
    perfect = [pm.ideal_time(p) for p in passes]
    assert pm.score(passes, perfect)[0] == pytest.approx(100)
    assert pm.score(passes, [])[0] == 0
    doubled = perfect + [p.t0 + 0.01 for p in passes]
    assert pm.score(passes, doubled)[0] == 0
    half_missed = perfect[::2]
    assert pm.score(passes, half_missed)[0] == pytest.approx(100 * len(half_missed) / len(passes))


def test_errors_are_relative_to_the_target_crossing():
    passes = race(random.Random(5))
    _, errors, single = pm.score(passes, [pm.ideal_time(p) + 0.03 for p in passes])
    assert single == len(passes) and errors == pytest.approx([0.03] * len(passes))


def test_skill_beats_mashing_random_and_fixed_interval_macros():
    rng = random.Random(6)
    good, kid, mash, macro = [], [], [], []
    for _ in range(200):
        passes = race(rng)
        good.append(pm.score(passes, [pm.ideal_time(p) + rng.gauss(-0.02, 0.05) for p in passes])[0])
        kid.append(pm.score(passes, [pm.ideal_time(p) + rng.gauss(-0.03, 0.12) for p in passes if rng.random() > 0.1])[0])
        mash.append(pm.score(passes, [k / 8 for k in range(36 * 8)])[0])
        iv, t0 = 1.2, pm.ideal_time(passes[0])
        macro.append(pm.score(passes, [t0 + k * iv for k in range(int(36 / iv))])[0])
    assert statistics.mean(good) > 88
    assert statistics.mean(mash) < 2
    assert statistics.mean(macro) < statistics.mean(kid) - 10  # a synced macro does worse than an average kid
