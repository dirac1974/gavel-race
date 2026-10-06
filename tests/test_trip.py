"""Race steering trip model (D-054, stage S0): src/trip.py, the exponent extra in
gavel_race_v2.live_chances, the D-054 post baseline, the calibration targets and the parity
fixtures. Since N3 the game runs D-057's motion and press rules (tests/test_trip_d057.py);
these tests hold the D-054 config, trip.d054_config(), the switch-back, to everything D-054
promised. Full-size D-054 calibration runs live in sims/steering.py --profile d054 (--write
stores tests/fixtures/trip_baseline_d054.json and steering_report_d054.json); the tests here
assert that report and re-check it on small runs."""

import copy
import hashlib
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
sys.path.insert(0, str(ROOT / "tests" / "fixtures"))

import make_fixtures  # noqa: E402
import steering  # noqa: E402

CFG = trip.d054_config()  # D-054, the switch-back (N3 switched the game to D-057's motion)
RACE = trip.RACE
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


def play(st, ticks, live, intents=None, start=0):
    """Steps `ticks` ticks from tick `start`; intents = {tick: [(lane, dir), ...]}."""
    answers = {}
    for tick in range(start, start + ticks):
        answers[tick] = trip.step(st, live, (intents or {}).get(tick, []), tick * DT, DT)
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


# ---------------------------------------------------------------- guards

def test_bad_indexes_raise_like_luau():
    geo = trip.phase_a("dirt", "Classic")
    st = lone(3, n=2)
    for bad in (-1, 2, 7):
        with pytest.raises(IndexError):
            trip.accept_intent(st, bad, -1, 0.0)
        with pytest.raises(IndexError):
            trip.step(st, even(2), [(bad, -1)], 0.0, DT)
        with pytest.raises(IndexError):
            trip.lane_after(st, bad)
    for posts in ([0, 2], [1, 9], [-1, 3]):
        with pytest.raises(IndexError):
            trip.new_state(posts, even(2), [0.5] * 4, geo, CFG, ["bot", "bot"])
    with pytest.raises(IndexError):
        trip.tau([0.0, 0.0], [1, 9], [0.0] * 8)
    with pytest.raises(ValueError):
        trip.new_state([1, 2], even(2), [0.5] * 4, geo, cfg_with(maxQueued=2), ["bot", "bot"])
    with pytest.raises(ValueError):
        trip.new_state([1, 2], even(2), [0.5] * 4, geo, CFG, ["bot", "robot"])
    with pytest.raises(ValueError):
        trip.new_state([1, 2], even(2), [0.5] * 3, geo, CFG)


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


@pytest.mark.skipif(shutil.which("lune") is None, reason="lune not installed (run_all.luau checks it on CI)")
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


# ---------------------------------------------------------------- gap motion (RaceView, D-055)

def test_offsets_move_like_the_race_view():
    """A lone horse's offset follows RaceView's easing exactly: k = min(1, 2.5 dt), each step
    clamped to max(maxGapFeetPerSecond dt, |gap| dt / (toLine - catchUpMarginSeconds))."""
    geo = trip.phase_a("turf", "Marathon")
    st = trip.new_state([3, 6], [0.62, 0.38], [0.5] * 4, geo, CFG, ["manual", "manual"])
    off = [0.0, 0.0]
    k = min(1.0, DT * RACE["viewEasePerSecond"])
    biggest = 0.0
    for tick in range(phase_a_ticks(geo)):
        t = tick * DT
        live = [0.62, 0.38] if tick < 300 else [0.30, 0.70]  # a checkpoint swings the gap by 128 ft
        trip.step(st, live, [], t, DT)
        to_line = geo["length"] / RACE["speed"] - t
        for i in range(2):
            target = RACE["leadFeetPerShare"] * (live[i] - 0.5) * min(1.0, t / CFG["gapRampSeconds"])
            gap = target - off[i]
            limit = max(RACE["maxGapFeetPerSecond"] * DT, abs(gap) * DT / (to_line - RACE["catchUpMarginSeconds"]))
            step_ = max(-limit, min(limit, gap * k))
            biggest = max(biggest, abs(step_) / DT)
            off[i] += step_
        assert st.off == off
    assert biggest == pytest.approx(RACE["maxGapFeetPerSecond"], rel=0.02)  # the cap binds after the swing


# ---------------------------------------------------------------- lanes, holds, tuck-in

def test_one_lane_glides_in_lane_seconds_and_starts_on_the_same_tick():
    st = lone(5)
    answers = play(st, 1, even(1), intents={0: [(0, -1)]})
    assert answers[0] == ["accepted"] and st.tgt[0] == 4 and 4.0 < st.x[0] < 5.0
    play(st, 4, even(1), start=1)
    assert st.x[0] != 4.0
    play(st, 1, even(1), start=5)
    assert st.x[0] == 4.0  # six ticks = 0.6 s


def test_rate_limit_queue_and_bounds():
    st = lone(5)
    answers = play(st, 1, even(1), intents={0: [(0, -1), (0, -1), (0, -1)]})
    assert answers[0] == ["accepted", "queued", "rate"]
    play(st, 20, even(1), start=1)
    assert st.x[0] == 3.0
    st = lone(2)
    assert play(st, 1, even(1), intents={0: [(0, -1), (0, -1)]})[0] == ["accepted", "bounds"]
    st = lone(8)
    assert play(st, 1, even(1), intents={0: [(0, 1)]})[0] == ["bounds"]
    st = lone(5)
    assert play(st, 1, even(1), intents={0: [(0, 0), (0, 2)]})[0] == ["invalid", "invalid"]


def test_no_queue_when_max_queued_is_zero():
    geo = trip.phase_a("dirt", "Classic")
    st = trip.new_state([5], even(1), [0.5, 0.5], geo, cfg_with(maxQueued=0), ["manual"])
    assert play(st, 1, even(1), intents={0: [(0, -1), (0, -1)]})[0] == ["accepted", "rate"]


def test_opposite_press_cancels_the_waiting_one():
    st = lone(5)
    answers = play(st, 1, even(1), intents={0: [(0, -1), (0, -1), (0, 1)]})
    assert answers[0] == ["accepted", "queued", "cancelled"]
    play(st, 20, even(1), start=1)
    assert st.x[0] == 4.0


def test_blocked_outward_move_cancels_after_a_second():
    st = lone(4, n=2)  # level horses in lanes 4 and 5
    play(st, 100, even(2))
    answers = play(st, 1, even(2), intents={100: [(0, 1)]}, start=100)
    assert answers[100] == ["accepted"] and st.want[0] == 1 and st.tgt[0] == 4
    play(st, 9, even(2), start=101)
    assert st.want[0] == 1
    play(st, 2, even(2), start=110)
    assert st.want[0] == 0 and st.x[0] == 4.0


def test_tuck_in_eases_back_and_slots_in_behind():
    st = lone(2, n=2)  # level horses in lanes 2 and 3
    play(st, 100, even(2))
    before = st.off[1]
    lowest = before
    play(st, 1, even(2), intents={100: [(1, -1)]}, start=100)
    for tick in range(101, 131):
        play(st, 1, even(2), start=tick)
        lowest = min(lowest, st.off[1])
        # it moves in once clearFeet behind, then settles back to holdGap (no hop)
        assert min(in_band_gaps(st) or [99]) >= CFG["clearFeet"] - 1e-9
    assert st.x[1] == 2.0  # in within 3 s
    assert before - lowest <= CFG["tuckBackMax"] + 1e-9
    assert st.off[0] - st.off[1] == pytest.approx(CFG["holdGap"], abs=1e-6)  # tucked in behind
    assert st.drafting[1]


def test_the_mover_never_pushes_the_horse_behind():
    """A horse 9 ft ahead of the horse in the lane it wants (inside clearFeet's 8 ft in front,
    but within holdGap behind) must slot in behind it, not cut in and push it back."""
    geo = trip.phase_a("dirt", "Classic")
    live = [0.5 - 9 / 640, 0.5 + 9 / 640]  # settles 9 ft apart: A (lane 2) behind B (lane 3)
    st = trip.new_state([2, 3], live, [0.5] * 4, geo, CFG, ["manual", "manual"])
    play(st, 200, live)
    assert st.off[1] - st.off[0] == pytest.approx(9.0, abs=1e-6)
    a_before = st.off[0]
    play(st, 1, live, intents={200: [(1, -1)]}, start=200)
    for tick in range(201, 300):
        play(st, 1, live, start=tick)
        assert st.off[0] == pytest.approx(a_before, abs=1e-9)  # A is never moved
    assert st.x[1] == 2.0 and st.off[0] - st.off[1] == pytest.approx(CFG["holdGap"], abs=1e-6)


def test_no_tuck_past_a_long_line_of_horses():
    geo = trip.phase_a("dirt", "Classic")
    st = trip.new_state([2, 2, 2, 2, 3], even(5), [0.5] * 10, geo, CFG, ["manual"] * 5)
    play(st, 100, even(5))
    assert sorted(st.off[:4], reverse=True) == pytest.approx([0.0, -10.0, -20.0, -30.0], abs=1e-6)
    start = st.off[4]
    play(st, 30, even(5), intents={100: [(4, -1)]}, start=100)
    assert st.x[4] == 3.0 and st.want[4] == -1  # waits for room
    assert st.off[4] == pytest.approx(start, abs=1e-6)  # the slot is past tuckBackMax: no ease-back


def test_horses_never_overlap_and_never_hop_back():
    """Random presses among Smart Steer, manual and bot horses. Horses sharing a lane never
    overlap (never closer than 6 ft of an 8 ft horse). A horse arriving a little close (a lane
    change needs clearFeet ahead; the hold keeps holdGap) settles into its place within 8 ticks
    instead of snapping (400 such races: closest 8.8 ft within half a lane, settled within 5).
    Nobody moves back faster than holdPullPerSecond (no hop on screen)."""
    for seed in range(12):
        rng = random.Random(seed)
        course, distance = steering.cells()[seed % 8]
        geo = trip.phase_a(course, distance)
        setup = steering.race_setup(steering.race_seed(7, seed, 0), distance)
        st = trip.new_state(list(range(1, 9)), setup["q"], setup["uniforms"], geo, CFG,
                            ["smart", "manual", "bot", "bot", "smart", "bot", "manual", "bot"])
        close_for = {}
        for tick in range(phase_a_ticks(geo)):
            intents = [(i, rng.choice((-1, 1))) for i in (0, 1, 4, 6) if rng.random() < 0.08]
            before = list(st.off)
            trip.step(st, setup["q"] if tick < 200 else setup["p1"], intents, tick * DT, DT)
            assert all(1.0 <= x <= 8.0 for x in st.x)
            assert all(before[i] - st.off[i] <= CFG["holdPullPerSecond"] * DT + 1e-9 for i in range(st.n))
            for i in range(st.n):
                for j in range(i + 1, st.n):
                    dx, gap = abs(st.x[i] - st.x[j]), abs(st.off[i] - st.off[j])
                    if dx < CFG["laneBand"]:
                        assert gap >= 6.0
                        close_for[(i, j)] = close_for.get((i, j), 0) + 1 if gap < CFG["holdGap"] - 1e-9 else 0
                        assert close_for[(i, j)] <= 8


def test_a_hold_settles_a_close_arrival_instead_of_snapping():
    """Horse A sits 9 ft behind B, one lane out, and is catching up (its skill target is ahead
    of B's) when it moves into B's lane: it arrives inside holdGap. With an instant hold
    (the rule before the hop fix) it hops back several feet in one tick; now it eases back at
    no more than holdPullPerSecond and settles at holdGap."""
    geo = trip.phase_a("dirt", "Classic")

    def ride(cfg):
        live = [0.5 - 9 / 640, 0.5 + 9 / 640]  # A (lane 3) settles 9 ft behind B (lane 2)
        st = trip.new_state([3, 2], live, [0.5] * 4, geo, cfg, ["manual", "manual"])
        play(st, 200, live)
        chase = [0.5 + 20 / 640, 0.5 - 20 / 640]  # now A's place is 20 ft ahead of B's
        play(st, 1, chase, intents={200: [(0, -1)]}, start=200)
        worst, gaps = 0.0, []
        for tick in range(201, 240):
            before = st.off[0]
            play(st, 1, chase, start=tick)
            worst = max(worst, before - st.off[0])
            if abs(st.x[0] - st.x[1]) < CFG["laneBand"]:
                gaps.append(st.off[1] - st.off[0])
        return st, worst, gaps

    _, old_worst, _ = ride(cfg_with(holdPullPerSecond=1e9))
    st, worst, gaps = ride(CFG)
    assert old_worst > 20 * DT  # the hop: over 20 ft/s backwards on screen
    assert st.x[0] == 2.0
    assert worst <= CFG["holdPullPerSecond"] * DT + 1e-9  # no hop now
    assert min(gaps) >= CFG["clearFeet"] - 1e-9 and gaps[-1] == pytest.approx(CFG["holdGap"], abs=1e-6)  # settled behind B


# ---------------------------------------------------------------- Smart Steer

def test_smart_steer_heads_in_before_the_turn_and_never_out():
    geo = trip.phase_a("dirt", "Classic")  # 1,320 ft straight, then the clubhouse turn
    turn_t = 1320 / RACE["speed"]
    st = trip.new_state([5, 1], even(2), [0.5] * 4, geo, CFG, ["smart", "smart"])
    early = int((turn_t - CFG["smart"]["turnLeadSeconds"]) / DT) - 1
    play(st, early, even(2))
    assert st.x == [5.0, 1.0]  # straight, more than 8 s out: holds its lane
    play(st, phase_a_ticks(geo) - early, even(2), start=early)
    assert st.x == [2.0, 1.0]  # one off the rail; the rail horse never moves out


def test_any_press_pauses_smart_steer_and_resume_never_moves_out():
    geo = trip.phase_a("dirt", "Classic")
    ticks = phase_a_ticks(geo)
    one = even(1)
    # took the rail by hand: Smart Steer (home lane 2) resumes but keeps it there
    st = trip.new_state([3], one, [0.5, 0.5], geo, CFG, ["smart"])
    play(st, ticks, one, intents={10: [(0, -1)], 20: [(0, -1)]})
    assert st.x[0] == 1.0
    # moved out on the straight: nothing moves until the turn's lead, then it heads back in
    st = trip.new_state([2], one, [0.5, 0.5], geo, CFG, ["smart"])
    play(st, 140, one, intents={10: [(0, 1)], 20: [(0, 1)]})
    assert st.x[0] == 4.0
    play(st, ticks - 140, one, start=140)
    assert st.x[0] == 2.0
    # a press just before the lead window pauses it for resumeSeconds, into the window
    st = trip.new_state([6], one, [0.5, 0.5], geo, CFG, ["smart"])
    press = int((1320 / RACE["speed"] - CFG["smart"]["turnLeadSeconds"] - 0.5) / DT)
    resume = press + int(round(CFG["smart"]["resumeSeconds"] / DT))
    play(st, resume, one, intents={press: [(0, 1)]})
    assert st.x[0] == 7.0  # Smart Steer would have headed in 0.5 s after the press
    play(st, 1, one, start=resume)
    assert st.x[0] < 7.0
    play(st, ticks - resume - 1, one, start=resume + 1)
    assert st.x[0] == 2.0


def test_set_smart_takes_over_for_a_disconnect():
    geo = trip.phase_a("dirt", "Mile")  # turn right after the gate
    st = trip.new_state([6], even(1), [0.5, 0.5], geo, CFG, ["manual"])
    play(st, 30, even(1))
    assert st.x[0] == 6.0
    trip.set_smart(st, 0, True)
    play(st, 60, even(1), start=30)
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
        play(st, phase_a_ticks(geo), even(1))
        trip.lock(st)
        assert st.ground[0] == pytest.approx(turns * 3 * CFG["groundPerLaneTurn"], abs=1e-12)


def test_draft_is_capped_and_stops_at_the_lock():
    geo = trip.phase_a("dirt", "Sprint")
    st = trip.new_state([1, 1], even(2), [0.5] * 4, geo, CFG, ["manual", "manual"])  # one lane: the second is held
    play(st, phase_a_ticks(geo), even(2))
    assert st.draft == [0.0, CFG["draftCap"]]
    short = dict(geo, lockS=RACE["speed"] * 5.05)
    st = trip.new_state([1, 1], even(2), [0.5] * 4, short, CFG, ["manual", "manual"])
    play(st, phase_a_ticks(short), even(2))
    # The two start level; the second settles back into its hold at holdPullPerSecond and is
    # tucked in (draftNear or more behind) from tick `first` on. The last tick is clipped.
    first = next(k for k in range(20) if (k + 1) * CFG["holdPullPerSecond"] * DT >= CFG["draftNear"])
    drafted = CFG["draftPerSecond"] * (5.05 - first * DT)
    assert first == 2 and st.draft[1] == pytest.approx(drafted, abs=1e-12)
    play(st, 20, even(2), start=phase_a_ticks(short))  # stepping past the lock adds nothing
    assert st.draft[1] == pytest.approx(drafted, abs=1e-12)


def test_nothing_changes_after_the_lock():
    geo = trip.phase_a("turf", "Mile")
    setup = steering.race_setup(steering.race_seed(5, 1, 0), "Mile")
    st = trip.new_state(list(range(1, 9)), setup["q"], setup["uniforms"], geo, CFG, ["smart"] * 8)
    play(st, phase_a_ticks(geo), setup["q"])
    trip.lock(st)
    frozen = copy.deepcopy(st.__dict__)
    assert trip.accept_intent(st, 0, -1, 99.0) == "locked"
    assert trip.step(st, setup["p1"], [(0, -1), (3, 1)], 99.0, DT) == ["locked", "locked"]
    trip.lock(st)  # a second bell books nothing
    assert st.__dict__ == frozen


def test_swapping_luck_leaves_tau_and_chances_unchanged():
    """The trip never sees luck: swap the luck vector and tau and the live chances after the
    lock stay exactly the same; only the finish order (sorted by luck / p) changes."""
    for trip_fn in (trip.new_state, trip.step, trip.lock, trip.trip_values, trip.tau, trip.accept_intent):
        assert "luck" not in inspect.signature(trip_fn).parameters
    geo = trip.phase_a("dirt", "Marathon")
    setup = steering.race_setup(steering.race_seed(5, 3, 1), "Marathon")
    pols = ["rail", "bot", "bot", "never", "bot", "bot", "scripted", "bot"]
    row = steering.load_baseline("d054")["baseline"]["dirt"]["Marathon"]
    mcfg = m.Config(T=18)
    R = m.skills(setup["s1"], mcfg)
    luck_rng = random.Random(11)
    luck = [-math.log(1 - luck_rng.random()) for _ in range(8)]
    swapped = luck[::-1]
    results = []
    for luck_vector, noise_seed in ((luck, 1), (swapped, 2)):
        random.seed(noise_seed)  # anything else drawn in the process must not matter either
        res = steering.run_race(geo, setup, pols, CFG)
        tau = trip.tau(res["trip"], list(range(1, 9)), row, CFG)
        p = m.live_chances(setup["q"], R, mcfg, tau)
        finish = sorted(range(8), key=lambda i: (luck_vector[i] / p[i], i))
        results.append((tau, p, finish))
    assert results[0][0] == results[1][0] and results[0][1] == results[1][1]
    assert results[0][2] != results[1][2]  # the luck did change the finish


def test_same_inputs_same_outputs():
    geo = trip.phase_a("turf", "Classic")
    setup = steering.race_setup(steering.race_seed(5, 6, 2), "Classic")
    pols = ["wanderer", "bot", "smart", "bot", "rail", "bot", "never", "scripted"]
    assert steering.run_race(geo, setup, pols) == steering.run_race(geo, setup, pols)


# ---------------------------------------------------------------- calibration targets

@pytest.fixture(scope="module")
def report():
    return steering.load_report("d054")


def test_stored_report_is_current_and_meets_every_target(report):
    """sims/steering.py --profile d054 --write stores the full D-054 run (600 races per course x
    distance). It must be made with the D-054 config and baseline and pass every acceptance
    target in every cell."""
    data = steering.load_baseline("d054")
    assert report["config"] == trip.config_record(CFG)
    assert report["baselineSeed"] == data["seed"] and report["baselineRaces"] == data["races"]
    assert report["mixWeight"] == data["mixWeight"] == steering.MIX_WEIGHT
    assert report["races"] >= 600
    s = report["summary"]
    assert len(s["rows"]) == 8
    t = steering.TARGETS
    for r in s["rows"]:
        cell = (r["course"], r["distance"])
        assert t["rail_vs_smart"][0] <= r["rail_vs_smart"] <= t["rail_vs_smart"][1], cell
        assert t["never"][0] <= r["never"] <= t["never"][1], cell
        assert r["reach3s"] >= t["reach3s"], cell
        assert r["draft_share"] <= t["draft_share"], cell
        assert max(abs(v) for v in r["smart_post"]) < t["post_bias"], cell
        assert max(abs(v) for v in r["allsmart_post"]) < t["post_bias"], cell
        assert abs(r["smart_among_bots"]) <= t["smart_mean"], cell
        assert abs(r["allsmart_mean"]) <= t["smart_mean"], cell
    assert all(s["checks"].values())
    assert s["checks"] == steering.check_targets(s)


def test_small_run_meets_the_targets_on_every_course():
    """A fresh small run on both courses (Sprint and Classic, 16 races each, the same race
    replayed per policy): rail rider beats Smart Steer by +0.01 to +0.03, never-steer sits
    between -0.02 and -0.01, a casual rider's inward presses reach their lane within 3 s at
    least 70% of the time, and draft is at most 40% of the positive trip (pooled; per cell in
    the stored full report)."""
    table = steering.load_baseline("d054")["baseline"]
    pos_d = pos_g = 0.0
    for course in trip.COURSE_ORDER:
        for distance in ("Sprint", "Classic"):
            cell = steering.cells().index((course, distance))
            geo = trip.phase_a(course, distance)
            row = trip.baseline_row(table, course, distance)
            diff, never, ok, n = [], [], 0, 0
            bots = []
            for k in range(16):
                setup = steering.race_setup(steering.race_seed(4242, cell, k), distance)
                f = setup["focal"]
                taus = {}
                for pol in ("smart", "rail", "never", "scripted"):
                    pols = ["bot"] * 8
                    pols[f] = pol
                    res = steering.run_race(geo, setup, pols, CFG)
                    taus[pol] = trip.tau(res["trip"], steering.posts(), row, CFG)[f]
                    if pol == "scripted":
                        ok += res["reach"][0]
                        n += res["reach"][1]
                diff.append(taus["rail"] - taus["smart"])
                never.append(taus["never"])
                res = steering.run_race(geo, setup, ["bot"] * 8, CFG)
                bots.append((trip.tau(res["trip"], steering.posts(), row, CFG), res["draft"], res["ground"]))
            assert 0.01 <= sum(diff) / len(diff) <= 0.03, (course, distance, sum(diff) / len(diff))
            assert -0.02 <= sum(never) / len(never) <= -0.01, (course, distance, sum(never) / len(never))
            assert ok / n >= 0.70, (course, distance, ok / n)
            dmean = [sum(b[1][p] for b in bots) / len(bots) for p in range(8)]
            gmean = [sum(b[2][p] for b in bots) / len(bots) for p in range(8)]
            for tau, draft, ground in bots:
                dadj = [draft[p] - dmean[p] for p in range(8)]
                gadj = [gmean[p] - ground[p] for p in range(8)]
                dm, gm = sum(dadj) / 8, sum(gadj) / 8
                for p in range(8):
                    if tau[p] > 0:
                        pos_d += max(0.0, dadj[p] - dm)
                        pos_g += max(0.0, gadj[p] - gm)
    assert pos_d / (pos_d + pos_g) <= 0.40


def test_small_run_smart_kid_among_bots_matches_the_stored_report(report):
    """A Smart Steer kid at every post among bots (dirt Sprint, 20 races, 160 samples) agrees
    with the stored full-run mean, which the report test holds to 0 +- 0.003 in every cell."""
    table = steering.load_baseline("d054")["baseline"]
    stored = {(r["course"], r["distance"]): r for r in report["summary"]["rows"]}
    course, distance = "dirt", "Sprint"
    cell = steering.cells().index((course, distance))
    geo = trip.phase_a(course, distance)
    row = trip.baseline_row(table, course, distance)
    taus = []
    for k in range(20):
        setup = steering.race_setup(steering.race_seed(4343, cell, k), distance)
        for p in range(8):
            res = steering.run_race(geo, setup, steering.smart_at(p), CFG)
            taus.append(trip.tau(res["trip"], steering.posts(), row, CFG)[p])
    mu = sum(taus) / len(taus)
    se = math.sqrt(sum((t - mu) ** 2 for t in taus) / (len(taus) - 1) / len(taus))
    assert abs(mu - stored[(course, distance)]["smart_among_bots"]) <= 4 * se + 0.0005


# ---------------------------------------------------------------- generated baseline files

def test_baseline_files_are_current():
    """The D-054 baseline (the switch-back's: a live --write with the D-054 config reproduces
    it). The game's table is tests/test_trip_d057.py's."""
    data = steering.load_baseline("d054")
    assert data["config"] == trip.config_record(CFG), (
        "the D-054 config changed: run python sims/steering.py --profile d054 --write")
    assert data["race"] == trip.RACE
    assert data["races"] >= 2000 and data["calibrationPasses"] == steering.CALIBRATION_PASSES
    for course in trip.COURSE_ORDER:
        for distance in trip.DISTANCE_ORDER:
            assert len(data["baseline"][course][distance]) == 8


@pytest.mark.parametrize("course,distance", [("dirt", "Sprint"), ("turf", "Mile"), ("dirt", "Marathon")])
def test_regenerating_the_baseline_matches(course, distance):
    """The generator's whole pipeline (eight Smart-at-a-post fields and an all-Smart field per
    race, the mix and the calibration passes) on the first races of a cell reproduces the
    stored probe exactly, so python sims/steering.py --write reproduces the checked-in files.
    The other cells' probes are checked by the same code (stored for all eight)."""
    data = steering.load_baseline("d054")
    assert steering.probe_cell(course, distance, CFG) == data["probe"]["baseline"][course][distance]


# ---------------------------------------------------------------- parity fixtures

@pytest.fixture(scope="module")
def race_math():
    return make_fixtures.race_math_data()


def test_existing_race_math_fixtures_unchanged_by_the_extra(race_math):
    assert len(race_math["cases"]) == 300
    for case in race_math["cases"]:
        c = case["cfg"]
        cfg = m.Config(T=c["T"], q_floor=c["qFloor"], kappa=c["kappa"], r_floor=c["rFloor"], B=c["B"])
        n = len(case["q"])
        assert m.live_chances(case["q"], case["R"], cfg) == case["p"]
        assert m.live_chances(case["q"], case["R"], cfg, [0.0] * n) == case["p"]


def test_extra_cases_fixture(race_math):
    cases = race_math["extraCases"]
    assert len(cases) == 100
    for k, case in enumerate(cases):
        c = case["cfg"]
        cfg = m.Config(T=c["T"], q_floor=c["qFloor"], kappa=c["kappa"], r_floor=c["rFloor"], B=c["B"])
        assert m.live_chances(case["q"], case["R"], cfg) == case["p0"]
        assert m.live_chances(case["q"], case["R"], cfg, case["extra"]) == case["p"]
        if k % 10 == 0:
            assert case["p"] == case["p0"]


def test_trip_fixture_replays_exactly():
    picks = [0, 9, 25, 50, 75, 100, 151, 199]  # 9: steering off (k >= 8 cycles the overrides)
    fx = make_fixtures.trip_fixture(only=picks)
    assert fx["cfg"] == trip.config_record(trip.CONFIG) and len(fx["runs"]) == len(picks)
    assert fx["runs"][1]["cfg"]["enabled"] is False
    for run in fx["runs"]:
        cfg = trip.config_from_record(run.get("cfg", fx["cfg"]))
        geo = trip.phase_a(run["course"], run["distance"])
        by_tick = {}
        for tick, lane, d in run["intents"]:
            by_tick.setdefault(tick, []).append((lane - 1, d))
        st = trip.new_state(run["posts"], run["q"], run["uniforms"], geo, cfg, run["kinds"])
        answers, snaps = [], []
        for tick in range(run["ticks"]):
            answers.extend(trip.step(st, run["q"] if tick < run["switchTick"] else run["p1"], by_tick.get(tick, []),
                                     tick * DT, DT))
            if tick % make_fixtures.SNAPSHOT_EVERY == 0 or tick == run["ticks"] - 1:
                snaps.append({"tick": tick, "x": list(st.x), "off": list(st.off), "tgt": list(st.tgt)})
        assert answers == run["answers"] and snaps == run["snapshots"]
        trip.lock(st)
        late = trip.step(st, run["p1"], [(lane - 1, d) for lane, d in run["afterLock"]], run["ticks"] * DT, DT)
        assert late == run["afterLockAnswers"] == ["locked"] * len(run["afterLock"])
        tr = trip.trip_values(st)
        assert tr == run["trip"]
        assert trip.tau(tr, run["posts"], fx["baseline"][run["course"]][run["distance"]], cfg, trip.brush_charges(st)) == run["tau"]
    assert {r["course"] for r in fx["runs"]} == {"dirt", "turf"}
    assert fx["geometry"]["dirt"]["Mile"]["gate"] == {"straight": "home", "offset": pytest.approx(1258.5707, abs=1e-3),
                                                      "laps": 0}


# ---------------------------------------------------------------- the switch-back: D-054 bit for bit

def test_d054_config_switches_every_d057_rule_off():
    """trip.d054_config() is CONFIG with every D-057 key at its D-054 value (D057_OFF): the
    switch-back. Files made with it record the config without the D-057 keys
    (trip.config_record), as every file made before D-057 did."""
    off = {"glide": "linear", "chainWindow": 0.0, "reverseGapSeconds": 0.0, "weaveGapSeconds": 0.0,
           "pressBounceSeconds": 0.0, "glideReserveFeet": 0.0, "blockedPress": "d054", "brush": "off"}
    for key, value in off.items():
        assert CFG[key] == value, key
    assert set(trip.D057) == set(off)
    assert all(CFG[k] == trip.D057_OFF[k] for k in trip.D057_KEYS) and not trip.d057_on(CFG)
    assert all(CFG[k] == trip.CONFIG[k] for k in CFG if k not in trip.D057_KEYS)
    record = trip.config_record(CFG)
    assert list(record) == [k for k in CFG if k not in trip.D057_KEYS]
    assert record == steering.load_baseline("d054")["config"] == steering.load_report("d054")["config"]
    assert trip.config_from_record(record) == CFG
    assert trip.d054_config()["smart"] is not trip.CONFIG["smart"]  # a copy: changing it never touches CONFIG


def test_records_survive_the_n3_flip():
    """D057_OFF is a literal of the D-054 values, not read from CONFIG. With D-057 on in CONFIG
    (N3, and the brushes since N5), a D-057 config records every D-057 key, and a record made before
    D-057 (no D-057 keys) still reads back as D-054, never as "eased"."""
    old_record = trip.config_record(CFG)
    assert trip.D057_OFF["glide"] == "linear" and trip.D057_OFF["blockedPress"] == "d054"
    flipped = trip.config_record(trip.CONFIG)
    assert all(k in flipped for k in trip.D057_KEYS) and flipped["glide"] == "eased" and flipped["brush"] == "repeat"
    back = trip.config_from_record(old_record)
    assert all(back[k] == trip.D057_OFF[k] for k in trip.D057_KEYS) and back["glide"] == "linear"
    assert trip.config_record(back) == old_record


def test_d054_trip_fixture_runs_are_byte_identical_to_before_d057():
    """The D-054 parity runs regenerate byte for byte as they did before N1: the hash of eight
    runs' JSON (with the D-054 config and baseline, the switch-back) and of the recorded config,
    taken from trip.json made at main 7abfa27, before any D-057 code."""
    picks = [0, 9, 25, 50, 75, 100, 151, 199]
    fx = make_fixtures.trip_fixture(only=picks, base=CFG, baseline=steering.load_baseline("d054")["baseline"])
    h = hashlib.sha256()
    for run in fx["runs"]:
        h.update(json.dumps(run).encode())
    assert h.hexdigest() == "00308033c56e108b42077696d30bbe17b182e0e7c94e81751658ddbc2519ee9f"
    cfg_hash = hashlib.sha256(json.dumps(fx["cfg"]).encode()).hexdigest()
    assert cfg_hash == "92644721342ce41db521740efcc806dcb20f1973aea3445a99ffbd01db8e40ed"


def test_d054_config_never_takes_a_d057_path():
    """With the D-054 config (the switch-back) a race never bounces, steadies, brushes or
    reverses late, and the D-057 state stays at rest: no sideways speed, no brushes, no
    steadying back."""
    for seed in range(4):
        rng = random.Random(seed)
        course, distance = steering.cells()[seed * 2]
        geo = trip.phase_a(course, distance)
        setup = steering.race_setup(steering.race_seed(9, seed, 0), distance)
        st = trip.new_state(list(range(1, 9)), setup["q"], setup["uniforms"], geo, CFG,
                            ["manual", "smart", "bot", "manual", "smart", "bot", "manual", "bot"])
        answers = set()
        for tick in range(phase_a_ticks(geo)):
            intents = [(i, rng.choice((-1, 1))) for i in (0, 1, 3, 4, 6) if rng.random() < 0.3]
            answers.update(trip.step(st, setup["q"] if tick < 150 else setup["p1"], intents, tick * DT, DT))
            assert st.v == [0.0] * 8 and st.check == [0.0] * 8
        assert not answers & {"bounce", "steady", "brush"}
        assert st.events == [] and st.brushes == [0] * 8 and trip.brush_charges(st) == [0.0] * 8
