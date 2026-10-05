"""Race steering trip model (D-054, stage S0): src/trip.py, the exponent extra in
gavel_race_v2.live_chances, the generated post baseline and the parity fixtures."""

import copy
import inspect
import json
import math
import random
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

import gavel_race_v2 as m
import trip

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "sims"))

import steering  # noqa: E402

CFG = trip.CONFIG
DT = 1.0 / CFG["tickHz"]


def cfg_with(**changes):
    cfg = copy.deepcopy(CFG)
    for key, value in changes.items():
        node = cfg
        parts = key.split("__")
        for part in parts[:-1]:
            node = node[part]
        node[parts[-1]] = value
    return cfg


def play(st, ticks, live=None, intents=None, start=0):
    """Steps `ticks` ticks from tick `start`; intents = {tick: [(lane, dir), ...]}."""
    answers = {}
    for tick in range(start, start + ticks):
        answers[tick] = trip.step(st, live or st.live, (intents or {}).get(tick, []), tick * DT, DT)
    return answers


def phase_a_ticks(geo):
    ticks = 0
    while ticks * DT < trip.lock_time(geo) - trip.EPS:
        ticks += 1
    return ticks


def even(n=8):
    return [1.0 / n] * n


def lone(post, kind="manual", geo=None, n=1):
    """A field of n horses at posts post, post+1, ... (equal chances: everyone level)."""
    geo = geo or trip.phase_a("dirt", "Classic")
    posts = [post + k for k in range(n)]
    return trip.new_state(posts, even(n), [0.5] * (2 * n), geo, CFG, [kind] * n)


def in_band_gaps(st):
    out = []
    for i in range(st.n):
        for j in range(i + 1, st.n):
            if abs(st.x[i] - st.x[j]) < CFG["laneBand"]:
                out.append(abs(st.off[i] - st.off[j]))
    return out


# ---------------------------------------------------------------- live_chances extra

@pytest.mark.parametrize("seed", range(100))
def test_extra_none_and_zero_extra_are_bit_identical(seed):
    rng = random.Random(seed)
    cfg = m.Config(T=rng.choice([12, 14.4, 18, 22]), kappa=rng.choice([0.6, 1.0, 1.4]))
    q = m.base_chances([rng.uniform(30, 90) for _ in range(8)], cfg)
    R = m.skills([rng.uniform(0, 100) for _ in range(8)], cfg)
    plain = m.live_chances(q, R, cfg)
    assert m.live_chances(q, R, cfg, None) == plain
    assert m.live_chances(q, R, cfg, [0.0] * 8) == plain
    # scale = 0 (cosmetic steering) and steering switched off give exactly today's chances
    tau0 = trip.tau([rng.uniform(-0.1, 0.02) for _ in range(8)], list(range(1, 9)), [0.0] * 8, cfg_with(scale=0.0))
    off = trip.tau([rng.uniform(-0.1, 0.02) for _ in range(8)], list(range(1, 9)), [0.0] * 8, cfg_with(enabled=False))
    assert m.live_chances(q, R, cfg, tau0) == plain
    assert m.live_chances(q, R, cfg, off) == plain


@pytest.mark.parametrize("seed", range(50))
def test_extra_adds_to_the_exponent(seed):
    rng = random.Random(seed)
    cfg = m.Config(kappa=rng.choice([0.6, 1.0, 1.4]))
    q = m.base_chances([rng.uniform(30, 90) for _ in range(8)], cfg)
    R = m.skills([rng.uniform(0, 100) for _ in range(8)], cfg)
    extra = [rng.uniform(-0.02, 0.07) for _ in range(8)]
    w = [qi * math.exp(cfg.kappa * ri + e) for qi, ri, e in zip(q, R, extra)]
    assert m.live_chances(q, R, cfg, extra) == pytest.approx([x / sum(w) for x in w], abs=1e-15)
    # the same constant on every lane changes nothing (equal trips)
    shifted = m.live_chances(q, R, cfg, [0.013] * 8)
    assert shifted == pytest.approx(m.live_chances(q, R, cfg), abs=1e-12)


# ---------------------------------------------------------------- tau

@pytest.mark.parametrize("seed", range(200))
def test_tau_always_within_floor_and_ceiling(seed):
    rng = random.Random(seed)
    cfg = cfg_with(scale=rng.choice([0.5, 1.0, 2.0, 5.0]))
    trips = [rng.uniform(-0.15, 0.03) for _ in range(8)]
    posts = list(range(1, 9))
    rng.shuffle(posts)
    base = [rng.uniform(-0.05, 0.01) for _ in range(8)]
    for t in trip.tau(trips, posts, base, cfg):
        assert cfg["floor"] <= t <= cfg["ceiling"]


def test_equal_adjusted_trips_give_zero_tau():
    base = [0.001 * k for k in range(8)]
    trips = [0.004 - 0.01 + b for b in base]  # every horse exactly on its post's baseline + const
    assert trip.tau(trips, list(range(1, 9)), base) == pytest.approx([0.0] * 8, abs=1e-15)


def test_tau_is_relative_to_the_field_before_the_clamp():
    rng = random.Random(3)
    trips = [rng.uniform(-0.01, 0.01) for _ in range(8)]
    tau = trip.tau(trips, list(range(1, 9)), [0.0] * 8)
    assert sum(tau) == pytest.approx(0.0, abs=1e-15)  # no clamp binds for small trips


@pytest.mark.parametrize("seed", range(100))
def test_more_ground_saved_never_lowers_own_chance(seed):
    rng = random.Random(seed)
    cfg = m.Config(T=22)
    q = m.base_chances([rng.uniform(40, 60) for _ in range(8)], cfg)
    R = m.skills([rng.uniform(20, 100) for _ in range(8)], cfg)
    trips = [rng.uniform(-0.08, 0.016) for _ in range(8)]
    posts = list(range(1, 9))
    base = [rng.uniform(-0.03, 0.0) for _ in range(8)]
    i = rng.randrange(8)
    before_tau = trip.tau(trips, posts, base)
    better = list(trips)
    better[i] += rng.uniform(0.0, 0.05)  # less ground lost
    after_tau = trip.tau(better, posts, base)
    assert after_tau[i] >= before_tau[i]
    for j in range(8):
        if j != i:
            assert after_tau[j] <= before_tau[j] + 1e-15  # a rival's better trip never helps you
    p0 = m.live_chances(q, R, cfg, before_tau)
    p1 = m.live_chances(q, R, cfg, after_tau)
    assert p1[i] >= p0[i] - 1e-15


def test_trip_stars():
    assert [trip.trip_stars(t) for t in (0.04, 0.015, 0.0149, -0.005, -0.0051, -0.02)] == [3, 3, 2, 2, 1, 1]


# ---------------------------------------------------------------- geometry

def test_phase_a_geometry_from_track_layout():
    for course in trip.COURSE_ORDER:
        cfg = trip.COURSES[course]
        r1 = trip.lane_radius(cfg, 1)
        live_turns = {"Sprint": 0, "Mile": 1, "Classic": 1, "Marathon": 2}
        for distance in trip.DISTANCE_ORDER:
            geo = trip.phase_a(course, distance)
            segs = geo["segments"]
            assert geo["lockS"] == pytest.approx(geo["length"] - cfg["finishFromTop"] - math.pi * r1, abs=1e-9)
            s = 0.0
            for g in segs:
                assert g["start"] == pytest.approx(s, abs=1e-9)
                s += g["length"]
                if g["kind"] == "T":
                    assert g["length"] == pytest.approx(math.pi * r1, abs=1e-9)  # whole 180-degree turns
            assert s == pytest.approx(geo["lockS"], abs=1e-6)
            assert len(geo["turns"]) == live_turns[distance]
            assert all(a["kind"] != b["kind"] for a, b in zip(segs, segs[1:]))
    assert trip.phase_a("dirt", "Mile")["length"] == pytest.approx(5280, abs=1e-9)
    assert trip.phase_a("dirt", "Sprint")["lockS"] == pytest.approx(1320, abs=1e-9)  # the backstretch


@pytest.mark.skipif(shutil.which("lune") is None, reason="lune not installed")
def test_gate_plan_matches_track_layout_luau():
    out = subprocess.run(["lune", "run", "tests/luau/track_plan"], cwd=ROOT, capture_output=True, text=True)
    assert out.returncode == 0, out.stderr
    luau = json.loads(out.stdout)
    for course in trip.COURSE_ORDER:
        for distance in trip.DISTANCE_ORDER:
            py = trip.gate_plan(trip.COURSES[course], trip.DISTANCES[distance])
            lu = luau[course][distance]
            assert py["straight"] == lu["straight"] and py["laps"] == lu["laps"]
            assert py["offset"] == pytest.approx(lu["offset"], abs=1e-9)
            assert py["length"] == pytest.approx(lu["length"], abs=1e-9)
            assert trip.lane_radius(trip.COURSES[course], 1) == lu["r1"]


# ---------------------------------------------------------------- lanes, holds, tuck-in

def test_one_lane_glides_in_lane_seconds_and_starts_on_the_same_tick():
    st = lone(5)
    answers = play(st, 1, intents={0: [(0, -1)]})
    assert answers[0] == ["accepted"] and st.tgt[0] == 4 and 4.0 < st.x[0] < 5.0
    play(st, 4, start=1)
    assert st.x[0] != 4.0
    play(st, 1, start=5)
    assert st.x[0] == 4.0  # six ticks = 0.6 s


def test_rate_limit_queue_and_bounds():
    st = lone(5)
    answers = play(st, 1, intents={0: [(0, -1), (0, -1), (0, -1)]})
    assert answers[0] == ["accepted", "queued", "rate"]
    play(st, 20, start=1)
    assert st.x[0] == 3.0
    st = lone(2)
    answers = play(st, 1, intents={0: [(0, -1), (0, -1)]})
    assert answers[0] == ["accepted", "bounds"]
    st = lone(8)
    assert play(st, 1, intents={0: [(0, 1)]})[0] == ["bounds"]
    st = lone(5)
    assert play(st, 1, intents={0: [(0, 0), (0, 2)]})[0] == ["invalid", "invalid"]


def test_no_queue_when_max_queued_is_zero():
    geo = trip.phase_a("dirt", "Classic")
    st = trip.new_state([5], even(1), [0.5, 0.5], geo, cfg_with(maxQueued=0), ["manual"])
    assert play(st, 1, intents={0: [(0, -1), (0, -1)]})[0] == ["accepted", "rate"]


def test_opposite_press_cancels_the_waiting_one():
    st = lone(5)
    answers = play(st, 1, intents={0: [(0, -1), (0, -1), (0, 1)]})
    assert answers[0] == ["accepted", "queued", "cancelled"]
    play(st, 20, start=1)
    assert st.x[0] == 4.0


def test_blocked_outward_move_cancels_after_a_second():
    st = lone(4, n=2)  # level horses in lanes 4 and 5
    play(st, 100)  # let the gap ramp settle (both level)
    answers = play(st, 1, intents={100: [(0, 1)]}, start=100)
    assert answers[100] == ["accepted"] and st.want[0] == 1 and st.tgt[0] == 4
    play(st, 9, start=101)
    assert st.want[0] == 1
    play(st, 2, start=110)
    assert st.want[0] == 0 and st.x[0] == 4.0


def test_tuck_in_eases_back_and_slots_in_behind():
    st = lone(2, n=2)  # level horses in lanes 2 and 3
    play(st, 100)
    before = st.off[1]
    lowest = before
    play(st, 1, intents={100: [(1, -1)]}, start=100)
    for tick in range(101, 131):
        play(st, 1, start=tick)
        lowest = min(lowest, st.off[1])
        assert min(in_band_gaps(st) or [99]) >= CFG["holdGap"] - 1e-9
    assert st.x[1] == 2.0  # in within 3 s
    assert before - lowest <= CFG["tuckBackMax"] + 1e-9
    assert st.off[0] - st.off[1] == pytest.approx(CFG["holdGap"], abs=1e-6)  # tucked in behind
    assert st.drafting[1]


def test_no_tuck_past_a_line_of_horses():
    geo = trip.phase_a("dirt", "Classic")
    st = trip.new_state([2, 2, 2, 3], even(4), [0.5] * 8, geo, CFG, ["manual"] * 4)
    play(st, 100)
    assert sorted(st.off[:3], reverse=True) == pytest.approx([0.0, -10.0, -20.0], abs=1e-6)
    start = st.off[3]
    play(st, 30, intents={100: [(3, -1)]}, start=100)
    assert st.x[3] == 3.0 and st.want[3] == -1  # waits for room
    assert st.off[3] == pytest.approx(start, abs=1e-6)  # the slot is too far back: no ease-back


def test_horses_never_overlap():
    for seed in range(6):
        rng = random.Random(seed)
        course, distance = steering.cells()[seed % 8]
        geo = trip.phase_a(course, distance)
        setup = steering.race_setup(steering.race_seed(7, seed, 0), distance)
        st = trip.new_state(list(range(1, 9)), setup["q"], setup["uniforms"], geo, CFG,
                            ["smart", "manual", "bot", "bot", "smart", "bot", "manual", "bot"])
        for tick in range(phase_a_ticks(geo)):
            intents = [(i, rng.choice((-1, 1))) for i in (0, 1, 4, 6) if rng.random() < 0.08]
            trip.step(st, setup["q"] if tick < 200 else setup["p1"], intents, tick * DT, DT)
            assert min(in_band_gaps(st) or [99]) >= CFG["holdGap"] - 1e-9
            assert all(1.0 <= x <= 8.0 for x in st.x)


# ---------------------------------------------------------------- Smart Steer

def test_smart_steer_heads_in_before_the_turn_and_never_out():
    geo = trip.phase_a("dirt", "Classic")  # 1,320 ft straight, then the clubhouse turn
    turn_t = 1320 / trip.RACE["speed"]
    st = trip.new_state([5, 1], even(2), [0.5] * 4, geo, CFG, ["smart", "smart"])
    early = int((turn_t - CFG["smart"]["turnLeadSeconds"]) / DT) - 1
    play(st, early)
    assert st.x == [5.0, 1.0]  # straight, more than 8 s out: holds its lane
    play(st, phase_a_ticks(geo) - early, start=early)
    assert st.x == [2.0, 1.0]  # one off the rail; the rail horse never moves out


def test_any_press_pauses_smart_steer_and_resume_never_moves_out():
    geo = trip.phase_a("dirt", "Classic")
    ticks = phase_a_ticks(geo)
    # took the rail by hand: Smart Steer (home lane 2) resumes but keeps it there
    st = trip.new_state([3], even(1), [0.5, 0.5], geo, CFG, ["smart"])
    play(st, ticks, intents={10: [(0, -1)], 20: [(0, -1)]})
    assert st.x[0] == 1.0
    # moved out on the straight: nothing moves until the turn's lead, then it heads back in
    st = trip.new_state([2], even(1), [0.5, 0.5], geo, CFG, ["smart"])
    play(st, 140, intents={10: [(0, 1)], 20: [(0, 1)]})
    assert st.x[0] == 4.0
    play(st, ticks - 140, start=140)
    assert st.x[0] == 2.0
    # a press just before the lead window pauses it for resumeSeconds, into the window
    st = trip.new_state([6], even(1), [0.5, 0.5], geo, CFG, ["smart"])
    press = int((1320 / trip.RACE["speed"] - CFG["smart"]["turnLeadSeconds"] - 0.5) / DT)
    resume = press + int(round(CFG["smart"]["resumeSeconds"] / DT))
    play(st, resume, intents={press: [(0, 1)]})
    assert st.x[0] == 7.0  # Smart Steer would have headed in 0.5 s after the press
    play(st, 1, start=resume)
    assert st.x[0] < 7.0
    play(st, ticks - resume - 1, start=resume + 1)
    assert st.x[0] == 2.0


def test_set_smart_takes_over_for_a_disconnect():
    geo = trip.phase_a("dirt", "Mile")  # turn right after the gate
    st = trip.new_state([6], even(1), [0.5, 0.5], geo, CFG, ["manual"])
    play(st, 30)
    assert st.x[0] == 6.0
    trip.set_smart(st, 0, True)
    play(st, 60, start=30)
    assert st.x[0] == 2.0


def test_bot_variety_from_uniforms():
    geo = trip.phase_a("dirt", "Classic")
    st = trip.new_state([1, 2, 3], even(3), [0.1, 0.0, 0.5, 1.0, 0.9, 0.5], geo, CFG, ["bot"] * 3)
    assert st.home == [1, 2, 3]
    assert st.turn_lead == [4.0, 12.0, 8.0]
    st = trip.new_state([1, 2], even(2), [0.1, 0.0, 0.9, 1.0], geo, CFG, ["smart", "manual"])
    assert st.home == [2, 2] and st.smart == [True, False] and st.turn_lead == [8.0, 8.0]


# ---------------------------------------------------------------- accrual and the lock

@pytest.mark.parametrize("distance,turns", [("Sprint", 1), ("Mile", 2), ("Classic", 2), ("Marathon", 3)])
def test_ground_per_lane_per_turn(distance, turns):
    for course in trip.COURSE_ORDER:
        geo = trip.phase_a(course, distance)
        st = trip.new_state([4], even(1), [0.5, 0.5], geo, CFG, ["manual"])
        play(st, phase_a_ticks(geo))
        trip.lock(st)
        assert st.ground[0] == pytest.approx(turns * 3 * CFG["groundPerLaneTurn"], abs=1e-12)


def test_draft_is_capped_and_stops_at_the_lock():
    geo = trip.phase_a("dirt", "Sprint")
    st = trip.new_state([1, 1], even(2), [0.5] * 4, geo, CFG, ["manual", "manual"])  # one lane: the second is held
    play(st, phase_a_ticks(geo))
    assert st.draft == [0.0, CFG["draftCap"]]
    short = dict(geo, lockS=trip.RACE["speed"] * 5.05)
    st = trip.new_state([1, 1], even(2), [0.5] * 4, short, CFG, ["manual", "manual"])
    play(st, phase_a_ticks(short))
    assert st.draft[1] == pytest.approx(CFG["draftPerSecond"] * 5.05, abs=1e-12)  # the last tick is clipped
    play(st, 20, start=phase_a_ticks(short))  # stepping past the lock adds nothing
    assert st.draft[1] == pytest.approx(CFG["draftPerSecond"] * 5.05, abs=1e-12)


def test_nothing_changes_after_the_lock():
    geo = trip.phase_a("turf", "Mile")
    setup = steering.race_setup(steering.race_seed(5, 1, 0), "Mile")
    st = trip.new_state(list(range(1, 9)), setup["q"], setup["uniforms"], geo, CFG, ["smart"] * 8)
    play(st, phase_a_ticks(geo))
    trip.lock(st)
    frozen = copy.deepcopy(st.__dict__)
    assert trip.accept_intent(st, 0, -1, 99.0) == "locked"
    assert trip.step(st, setup["p1"], [(0, -1), (3, 1)], 99.0, DT) == ["locked", "locked"]
    trip.lock(st)  # a second bell books nothing
    assert st.__dict__ == frozen


def test_the_trip_takes_no_luck():
    for fn in (trip.new_state, trip.step, trip.lock, trip.trip_values, trip.tau, trip.accept_intent):
        assert "luck" not in inspect.signature(fn).parameters
    geo = trip.phase_a("dirt", "Marathon")
    setup = steering.race_setup(steering.race_seed(5, 3, 1), "Marathon")
    out = []
    for luck_seed in (1, 2):
        random.seed(luck_seed)  # anything else drawn in the process must not matter
        res = steering.run_race(geo, setup, ["rail", "bot", "bot", "never", "bot", "bot", "scripted", "bot"])
        out.append(res["trip"])
    assert out[0] == out[1]
    # p after the lock: identical whatever the luck numbers, which only order the finish
    tau = trip.tau(out[0], list(range(1, 9)), [0.0] * 8)
    cfg = m.Config(T=18)
    p = m.live_chances(setup["q"], [0.0] * 8, cfg, tau)
    for luck_seed in (1, 2):
        rng = random.Random(luck_seed)
        _luck = [-math.log(1 - rng.random()) for _ in range(8)]
        assert m.live_chances(setup["q"], [0.0] * 8, cfg, tau) == p


def test_same_inputs_same_outputs():
    geo = trip.phase_a("turf", "Classic")
    setup = steering.race_setup(steering.race_seed(5, 6, 2), "Classic")
    pols = ["wanderer", "bot", "smart", "bot", "rail", "bot", "never", "scripted"]
    a = steering.run_race(geo, setup, pols)
    b = steering.run_race(geo, setup, pols)
    assert a == b


# ---------------------------------------------------------------- calibration (fixed seeds)

def test_residual_post_bias_below_target():
    table = steering.load_baseline()["baseline"]
    for course, distance in (("dirt", "Mile"), ("turf", "Marathon")):
        geo = trip.phase_a(course, distance)
        row = trip.baseline_row(table, course, distance)
        cell = steering.cells().index((course, distance))
        sums = [0.0] * 8
        races = 150
        for k in range(races):
            setup = steering.race_setup(steering.race_seed(777, cell, k), distance)
            res = steering.run_race(geo, setup, ["bot"] * 8)
            for p, t in enumerate(trip.tau(res["trip"], list(range(1, 9)), row)):
                sums[p] += t
        by_post = [s / races for s in sums]
        shift = sum(by_post) / 8
        assert max(abs(v - shift) for v in by_post) < 0.005, (course, distance, by_post)


def test_smart_steer_field_mean_is_zero():
    table = steering.load_baseline()["baseline"]
    for cell, (course, distance) in enumerate(steering.cells()):
        geo = trip.phase_a(course, distance)
        row = trip.baseline_row(table, course, distance)
        taus = []
        for k in range(20):
            setup = steering.race_setup(steering.race_seed(778, cell, k), distance)
            res = steering.run_race(geo, setup, ["smart"] * 8)
            taus.extend(trip.tau(res["trip"], list(range(1, 9)), row))
        assert abs(sum(taus) / len(taus)) <= 0.003, (course, distance)


def test_policies_order_rail_over_smart_over_never():
    table = steering.load_baseline()["baseline"]
    course, distance = "dirt", "Classic"
    geo = trip.phase_a(course, distance)
    row = trip.baseline_row(table, course, distance)
    cell = steering.cells().index((course, distance))
    got = {p: [] for p in ("rail", "smart", "never")}
    for k in range(60):
        setup = steering.race_setup(steering.race_seed(779, cell, k), distance)
        for pol in got:
            pols = ["bot"] * 8
            pols[setup["focal"]] = pol
            res = steering.run_race(geo, setup, pols)
            got[pol].append(trip.tau(res["trip"], list(range(1, 9)), row)[setup["focal"]])
    mean = {p: sum(v) / len(v) for p, v in got.items()}
    assert 0.01 <= mean["rail"] - mean["smart"] <= 0.03
    assert -0.02 <= mean["never"] <= -0.01
    assert abs(mean["smart"]) <= 0.006


# ---------------------------------------------------------------- generated baseline files

def test_baseline_files_are_current():
    data = steering.load_baseline()
    assert data["config"] == trip.CONFIG, "GameConfig.steering mirror changed: run python sims/steering.py --write"
    assert data["race"] == trip.RACE
    assert data["races"] >= 2000 and data["calibrationPasses"] == steering.CALIBRATION_PASSES
    for course in trip.COURSE_ORDER:
        for distance in trip.DISTANCE_ORDER:
            assert len(data["baseline"][course][distance]) == 8
    assert steering.BASELINE_LUAU.read_text() == steering.render_luau(data)


@pytest.mark.parametrize("course,distance", steering.cells())
def test_regenerating_the_baseline_matches(course, distance):
    """The generator's whole pipeline on the first races of each cell reproduces the stored
    probe exactly, so a full regeneration (python sims/steering.py --write) reproduces the
    checked-in files."""
    data = steering.load_baseline()
    assert steering.probe_cell(course, distance) == data["probe"]["baseline"][course][distance]


def test_baseline_agrees_with_a_reduced_regeneration():
    data = steering.load_baseline()
    for course, distance in (("dirt", "Sprint"), ("turf", "Mile")):
        cell = steering.cells().index((course, distance))
        rows = steering._baseline_chunk((cell, 0, 200, trip.CONFIG))
        quick = steering.calibrate(rows, trip.CONFIG)
        for p in range(8):
            vals = [r[p][0] for r in rows]
            mu = sum(vals) / len(vals)
            se = math.sqrt(sum((v - mu) ** 2 for v in vals) / (len(vals) - 1) / len(vals))
            assert abs(quick[p] - data["baseline"][course][distance][p]) <= 4 * se + 0.0005, (course, distance, p)


# ---------------------------------------------------------------- parity fixtures

@pytest.fixture(scope="module")
def fixtures():
    subprocess.run([sys.executable, "tests/fixtures/make_fixtures.py"], cwd=ROOT, check=True, capture_output=True)
    race_math = json.loads((ROOT / "tests" / "fixtures" / "race_math.json").read_text())
    trip_fx = json.loads((ROOT / "tests" / "fixtures" / "trip.json").read_text())
    return race_math, trip_fx


def test_existing_race_math_fixtures_unchanged_by_the_extra(fixtures):
    race_math, _ = fixtures
    assert len(race_math["cases"]) == 300
    for case in race_math["cases"]:
        c = case["cfg"]
        cfg = m.Config(T=c["T"], q_floor=c["qFloor"], kappa=c["kappa"], r_floor=c["rFloor"], B=c["B"])
        n = len(case["q"])
        assert m.live_chances(case["q"], case["R"], cfg) == case["p"]
        assert m.live_chances(case["q"], case["R"], cfg, [0.0] * n) == case["p"]


def test_extra_cases_fixture(fixtures):
    race_math, _ = fixtures
    cases = race_math["extraCases"]
    assert len(cases) == 100
    for k, case in enumerate(cases):
        c = case["cfg"]
        cfg = m.Config(T=c["T"], q_floor=c["qFloor"], kappa=c["kappa"], r_floor=c["rFloor"], B=c["B"])
        assert m.live_chances(case["q"], case["R"], cfg) == case["p0"]
        assert m.live_chances(case["q"], case["R"], cfg, case["extra"]) == case["p"]
        if k % 10 == 0:
            assert case["p"] == case["p0"]


def test_trip_fixture_replays_exactly(fixtures):
    _, fx = fixtures
    assert len(fx["runs"]) == 200 and fx["cfg"] == trip.CONFIG
    assert {r.get("cfg", {}).get("enabled", True) for r in fx["runs"]} == {True, False}
    for run in fx["runs"][:: 25]:
        cfg = run.get("cfg", fx["cfg"])
        geo = trip.phase_a(run["course"], run["distance"])
        by_tick = {}
        for tick, lane, d in run["intents"]:
            by_tick.setdefault(tick, []).append((lane - 1, d))
        st = trip.new_state(run["posts"], run["q"], run["uniforms"], geo, cfg, run["kinds"])
        answers, snaps = [], []
        for tick in range(run["ticks"]):
            answers.extend(trip.step(st, run["q"] if tick < run["switchTick"] else run["p1"], by_tick.get(tick, []),
                                     tick * DT, DT))
            if tick % 50 == 0 or tick == run["ticks"] - 1:
                snaps.append({"tick": tick, "x": list(st.x), "off": list(st.off), "tgt": list(st.tgt)})
        assert answers == run["answers"] and snaps == run["snapshots"]
        trip.lock(st)
        tr = trip.trip_values(st)
        assert tr == run["trip"]
        assert trip.tau(tr, run["posts"], fx["baseline"][run["course"]][run["distance"]], cfg) == run["tau"]
