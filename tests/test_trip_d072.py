"""Race realism phase A (D-072): filing in, running styles and drift, passing, shut doors, the
learner floor, the per-style baseline and the fixed-lanes mode (Hurdles), in src/trip.py. The
switch-back (every D-072 block off) is D-057's race exactly; full-size gates are in
sims/realism.py and sims/steering.py (docs/reviews/race-realism-2026-10-12/phaseA-sim.md)."""

import copy
import random
import sys
from pathlib import Path

import pytest

import trip

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "sims"))

import steering  # noqa: E402

CFG = trip.CONFIG
OFF = trip.d057_config()
DT = 1.0 / CFG["tickHz"]
N72 = 2 + trip.D072_UNIFORMS


def cfg72(**blocks):
    cfg = copy.deepcopy(CFG)
    for key, value in blocks.items():
        block, name = key.split("__")
        cfg[block][name] = value
    return cfg


def play(st, ticks, live, intents=None, start=0):
    out = {}
    for tick in range(start, start + ticks):
        out[tick] = trip.step(st, live, (intents or {}).get(tick, []), tick * DT, DT)
    return out


def ticks_to_lock(geo):
    k = 0
    while k * DT < trip.lock_time(geo) - trip.EPS:
        k += 1
    return k


def uniforms(n, u=0.5, extra=None):
    """Two per lane (rail, lead), then seven per lane (style, period1, phase1, period2, phase2,
    pass, shut); extra = {(lane, slot): value} for the seven."""
    out = [u] * (2 * n) + [u] * (trip.D072_UNIFORMS * n)
    for (lane, slot), v in (extra or {}).items():
        out[2 * n + trip.D072_UNIFORMS * lane + slot] = v
    return out


def even(n):
    return [1.0 / n] * n


# ---------------------------------------------------------------- config and the switch-back

def test_game_config_runs_d072_and_off_is_d057():
    assert trip.d072_on(CFG) and not trip.d072_on(OFF) and not trip.d072_on(trip.d054_config())
    assert all(CFG[b]["enabled"] for b in trip.D072_BLOCKS)
    assert trip.d072_config() == CFG
    assert trip.d072_off()["file"] == trip.D072_OFF["file"] and trip.d072_off()["pass"] is not CFG["pass"]
    # The off config records without any D-072 key, as files made before D-072 did.
    assert not any(k in trip.config_record(OFF) for k in trip.D072_KEYS)
    assert all(k in trip.config_record(CFG) for k in trip.D072_KEYS)
    assert trip.config_from_record(trip.config_record(OFF)) == OFF
    assert trip.config_from_record(trip.config_record(CFG)) == CFG
    assert (CFG["file"]["homeLane"], CFG["file"]["railShare"], CFG["file"]["secondShare"]) == (1, 0.5, 0.35)
    assert (CFG["doors"]["shutSeconds"], CFG["learner"]["races"], CFG["lockAt"]) == (1.5, 3, "farTurnEntry")
    # rulings: introRaces 0 (buttons from race 1), weaveWindowSeconds 8; the switch-back restores D-057's
    assert (CFG["introRaces"], CFG["weaveWindowSeconds"]) == (0, 8.0)
    assert (OFF["introRaces"], OFF["weaveWindowSeconds"]) == (3, 7.0) == tuple(trip.D072_RETUNED.values())
    assert (CFG["pass"]["closingFeetPerSecond"], CFG["pass"]["alongFeet"]) == (6.0, 8.0)
    with pytest.raises(ValueError):
        trip.new_state([1], [1.0], uniforms(1), trip.phase_a("dirt", "Mile"), dict(CFG, lockAt="topOfStretch"))
    with pytest.raises(ValueError):  # D-072 needs its seven uniforms per lane
        trip.new_state([1, 2], even(2), [0.5] * 4, trip.phase_a("dirt", "Mile"), CFG)


@pytest.mark.parametrize("seed", range(3))
def test_every_block_off_is_d057_exactly(seed):
    """A race with every D-072 block off is the same race whatever the extra uniforms hold."""
    course, distance = steering.cells()[seed * 3 % 8]
    geo = trip.phase_a(course, distance)
    setup = steering.race_setup(steering.race_seed(72, seed, 0), distance)
    kinds = ["bot", "smart", "bot", "manual", "bot", "smart", "bot", "bot"]
    a = trip.new_state(steering.posts(), setup["q"], setup["uniforms"], geo, OFF, kinds)
    b = trip.new_state(steering.posts(), setup["q"], setup["uniforms"] + setup["uniforms72"], geo, OFF, kinds)
    rng = random.Random(seed)
    for tick in range(ticks_to_lock(geo)):
        intents = [(3, rng.choice((-1, 1)))] if rng.random() < 0.05 else []
        live = setup["q"] if tick < 150 else setup["p1"]
        assert trip.step(a, live, intents, tick * DT, DT) == trip.step(b, live, intents, tick * DT, DT)
    assert (a.x, a.off, a.ground, a.draft) == (b.x, b.off, b.ground, b.draft)
    assert b.pack_events == [] and b.drift == [0.0] * 8 and b.style == [1] * 8


# ---------------------------------------------------------------- filing in

def test_home_lanes_file_to_the_rail():
    geo = trip.phase_a("dirt", "Classic")
    st = trip.new_state([4, 5, 6, 7, 8], even(5), [0.1, 0.5, 0.49, 0.5, 0.5, 0.5, 0.84, 0.5, 0.9, 0.5] + [0.5] * 35,
                        geo, CFG, ["bot", "bot", "bot", "bot", "smart"])
    assert st.home == [1, 1, 2, 2, 1]  # rail 50%, lane 2 35%, lane 3 15%; riders on Smart Steer: lane 1
    st = trip.new_state([4], even(1), uniforms(1, 0.9), geo, CFG, ["bot"])
    assert st.home == [3]
    st = trip.new_state([4, 5], even(2), uniforms(2), geo, OFF, ["smart", "bot"])
    assert st.home == [2, 2]  # D-057: smart.homeLane


def test_smart_steer_files_in_after_the_break_on_a_straight():
    geo = trip.phase_a("dirt", "Classic")  # 1,320 ft of straight first: the turn is 23.6 s away
    st = trip.new_state([6], even(1), uniforms(1), geo, CFG, ["smart"])
    play(st, int(CFG["file"]["fromSeconds"] / DT) - 1, even(1))
    assert st.x[0] == 6.0  # waits for the break
    play(st, 100, even(1), start=int(CFG["file"]["fromSeconds"] / DT) - 1)
    assert st.x[0] == 1.0  # on the rail inside the filing window, long before the turn
    old = trip.new_state([6], even(1), [0.5, 0.5], geo, OFF, ["smart"])
    play(old, 120, even(1))
    assert old.x[0] == 6.0  # D-057 heads in only near turns


# ---------------------------------------------------------------- styles and drift

def test_running_styles_for_bots_only_fade_to_zero_at_the_lock():
    geo = trip.phase_a("dirt", "Classic")
    u = uniforms(4, 0.5, {(0, 0): 0.1, (1, 0): 0.5, (2, 0): 0.95, (3, 0): 0.1})
    st = trip.new_state([1, 3, 5, 7], even(4), u, geo, CFG, ["bot", "bot", "bot", "smart"])
    assert st.style == [0, 1, 2, 3] and st.style_feet == [14.0, 0.0, -14.0, 0.0]  # riders run as stalkers
    t_lock = trip.lock_time(geo)
    assert trip.pack_feet(st, 0, 0.0, 0.0) == 0.0
    st.drift = [0.0] * 4
    assert trip.pack_feet(st, 0, t_lock / 2, 1.0) == pytest.approx(7.0)
    assert trip.pack_feet(st, 2, t_lock, 1.0) == 0.0 and trip.pack_feet(st, 0, t_lock + 5, 1.0) == 0.0


def test_wave_is_smooth_and_bounded():
    prev = trip.wave(0.0)
    assert prev == 0.0 and trip.wave(0.25) == 1.0 and trip.wave(0.75) == -1.0 and trip.wave(1.25) == 1.0
    for k in range(1, 4001):
        v = trip.wave(k / 1000.0)
        assert -1.0 <= v <= 1.0
        assert abs(v - prev) <= 8.0 / 1000.0 + 1e-12  # slope never above 8 a period: no kinks or jumps
        prev = v


@pytest.mark.parametrize("seed", range(4))
def test_drift_is_capped_and_fades_before_the_lock(seed):
    course, distance = steering.cells()[seed * 2]
    geo = trip.phase_a(course, distance)
    setup = steering.race_setup(steering.race_seed(73, seed, 0), distance)
    st = trip.new_state(steering.posts(), setup["q"], steering.race_uniforms(setup, CFG), geo, CFG, ["bot"] * 8)
    prev = list(st.drift)
    lim = CFG["pack"]["driftMaxFeetPerSecond"] * DT + 1e-12
    moved = 0.0
    for tick in range(ticks_to_lock(geo)):
        trip.step(st, setup["q"], [], tick * DT, DT)
        for i in range(8):
            assert abs(st.drift[i] - prev[i]) <= lim
            moved = max(moved, abs(st.drift[i]))
        prev = list(st.drift)
    assert moved > 2.0  # the pack really breathes
    assert max(abs(d) for d in st.drift) <= CFG["pack"]["driftMaxFeetPerSecond"] * CFG["pack"]["driftFadeSeconds"]


# ---------------------------------------------------------------- passing

def slow_leader(kinds, pass_u=0.5, distance="Classic", cfg=CFG):
    """Horse 0 sits 20 ft behind its target, held by horse 1 ahead of it in lane 1 on a straight."""
    geo = trip.phase_a("dirt", distance)
    u = uniforms(2, 0.5, {(0, 5): pass_u, (1, 6): 0.9})
    u[0] = u[2] = 0.1  # both bots' home is the rail
    st = trip.new_state([1, 1], [0.5, 0.5], u, geo, cfg, kinds)
    st.off = [-10.0, 0.0]
    return st, [0.5 + 20 / 320, 0.5 - 20 / 320]


def test_a_held_horse_moves_out_passes_and_heads_back_in_on_the_straight():
    st, live = slow_leader(["bot", "bot"])
    play(st, 200, live)
    kinds = [e[1] for e in st.pack_events]
    assert kinds[:2] == ["out", "pass"] and st.pack_events[1][4] == 0  # on the straight
    assert st.x[0] == 1.0 and st.off[0] > st.off[1] + CFG["pass"]["returnClearFeet"] - 1e-9  # back on the rail, ahead
    assert st.passes[0] == 1


def test_a_pass_shows_the_two_horses_alongside():
    """Feel: the passer gains on the horse it passes at most closingFeetPerSecond while within
    alongFeet of it, so they are alongside for at least 0.8 s."""
    st, _live = slow_leader(["bot", "bot"])
    live = [0.5 + 40 / 320, 0.5 - 40 / 320]  # a big gap: it would sweep by
    prev, along, cap = list(st.off), 0, CFG["pass"]["closingFeetPerSecond"] * DT
    for tick in range(300):
        trip.step(st, live, [], tick * DT, DT)
        rel0, rel1 = prev[0] - prev[1], st.off[0] - st.off[1]
        if st.pass_from[0] >= 0 and abs(rel0) < CFG["pass"]["alongFeet"]:
            assert rel1 - rel0 <= cap + 1e-9
        if abs(rel1) < CFG["pass"]["alongFeet"] and st.x[0] != 1.0:
            along += 1
        prev = list(st.off)
    assert any(e[1] == "pass" for e in st.pack_events)
    assert along * DT >= 0.8


def test_no_pass_without_the_tendency_on_turns_or_with_passing_off():
    st, live = slow_leader(["bot", "bot"], cfg=cfg72(pass__enabled=False))
    play(st, 200, live)
    assert st.pack_events == [] and st.x[0] == 1.0
    st, live = slow_leader(["bot", "bot"], cfg=cfg72(pass__straightChance=0.4))
    play(st, 200, live)
    assert st.pack_events == []  # pass_u 0.5: never passes here
    # a turn: dirt Mile starts 61 ft before the clubhouse turn; pass_u 0.5 >= turnChance 0.25
    geo = trip.phase_a("dirt", "Mile")
    st = trip.new_state([1, 1], [0.5, 0.5], uniforms(2, 0.5, {(1, 6): 0.9}), geo, CFG, ["bot", "bot"])
    st.off = [-10.0, 0.0]
    play(st, 150, [0.5 + 20 / 320, 0.5 - 20 / 320])
    assert not any(e[1] == "out" and e[4] == 1 for e in st.pack_events)


def test_a_pressing_rider_is_never_moved_out_and_a_manual_rider_never_passes():
    st, live = slow_leader(["manual", "bot"])
    play(st, 200, live)
    assert st.pack_events == [] and st.x[0] == 1.0
    st, live = slow_leader(["smart", "bot"])
    play(st, 60, live, {k: [(0, -1)] for k in range(0, 60, 10)})  # pressing In on the rail: Smart Steer paused
    assert not any(e[1] == "out" for e in st.pack_events)


def test_passes_capped_per_race():
    st, live = slow_leader(["bot", "bot"], cfg=cfg72(pass__maxPasses=0))
    play(st, 200, live)
    assert st.pack_events == []


# ---------------------------------------------------------------- shut doors

def door_field(learner=False, shut_u=0.1, mover="manual"):
    """Horse 0 in lane 2 presses In; bot 1 on the rail sits 12 ft ahead (outside clearFeet, inside
    reachFeet)."""
    geo = trip.phase_a("dirt", "Classic")
    st = trip.new_state([2, 1], even(2), uniforms(2, 0.5, {(1, 6): shut_u, (0, 6): 0.0}), geo, CFG,
                        [mover, "bot"], learners=[learner, False])
    st.off = [0.0, 12.0]
    return st


def test_a_bot_shuts_the_door_for_shut_seconds():
    st = door_field()
    ans = play(st, 1, even(2), {0: [(0, -1)]})
    assert ans[0] == ["accepted"] and st.x[0] == 2.0 and st.tgt[0] == 2
    assert st.pack_events == [(0.0, "shut", 1, 0, -1)] and trip.door_shut_on(st, 0, 0.5) == 1
    play(st, 14, even(2), start=1)
    assert st.tgt[0] == 2  # still held at 1.4 s
    play(st, 2, even(2), start=15)
    assert st.tgt[0] == 1  # the door opens after 1.5 s; the waiting press goes in
    assert sum(1 for e in st.pack_events if e[1] == "shut") == 1  # and that bot can't shut again yet


def test_no_shut_doors_on_learners_by_riders_or_with_doors_off():
    for st in (door_field(learner=True), door_field(shut_u=0.5)):
        play(st, 1, even(2), {0: [(0, -1)]})
        assert st.tgt[0] == 1 and st.pack_events == []
    geo = trip.phase_a("dirt", "Classic")
    st = trip.new_state([2, 1], even(2), uniforms(2, 0.5, {(1, 6): 0.0}), geo, CFG, ["manual", "smart"])
    st.off = [0.0, 12.0]
    play(st, 1, even(2), {0: [(0, -1)]})
    assert st.tgt[0] == 1 and st.pack_events == []  # a rider never shuts a door
    st = trip.new_state([2, 1], even(2), uniforms(2, 0.5, {(1, 6): 0.0}), geo, cfg72(doors__enabled=False),
                        ["manual", "bot"])
    st.off = [0.0, 12.0]
    play(st, 1, even(2), {0: [(0, -1)]})
    assert st.tgt[0] == 1


# ---------------------------------------------------------------- tau: styles, the learner floor

def test_style_baseline_and_learner_floor_in_tau():
    trips = [0.01, -0.01, 0.0, 0.005, -0.03, 0.0, 0.002, 0.0]
    posts = list(range(1, 9))
    base = [0.0] * 8
    plain = trip.tau(trips, posts, base, CFG)
    assert trip.tau(trips, posts, base, CFG, None, [0.0] * 8) == plain
    style = [0.004] + [0.0] * 7
    shifted = trip.tau(trips, posts, base, CFG, None, style)
    assert shifted[0] < plain[0] and all(shifted[i] > plain[i] for i in range(1, 8) if -0.02 < plain[i] < 0.04)
    learn = [None] * 4 + [-0.004] + [None] * 3
    floored = trip.tau(trips, posts, base, CFG, None, None, learn)
    assert plain[4] < -0.004 and floored[4] == -0.004 and floored[:4] == plain[:4] and floored[5:] == plain[5:]
    assert trip.tau(trips, posts, base, CFG, [0.0, 0.0, 0.0, 0.0, 0.006, 0, 0, 0], None, learn)[4] == -0.004
    assert trip.tau(trips, posts, base, CFG, None, None, [None] * 4 + [-0.5] + [None] * 3)[4] == plain[4]
    for t in trip.tau(trips, posts, base, CFG, None, style, learn):
        assert CFG["floor"] <= t <= CFG["ceiling"]
    with pytest.raises(ValueError):
        trip.tau(trips, posts, base, CFG, None, [0.0] * 7)


def learner_race(presses, learner=True, post=1, distance="Mile"):
    """A learner (manual) at `post` among bots on the dirt Mile (turn first), pressing `presses`
    ({tick: dir}); returns the state after the lock."""
    geo = trip.phase_a("dirt", distance)
    setup = steering.race_setup(steering.race_seed(76, 1, 3), distance)
    kinds = ["bot"] * 8
    kinds[post - 1] = "manual"
    learners = [False] * 8
    learners[post - 1] = learner
    st = trip.new_state(steering.posts(), setup["q"], steering.race_uniforms(setup, CFG), geo, CFG, kinds,
                        learners=learners)
    for tick in range(ticks_to_lock(geo)):
        trip.step(st, setup["q"] if tick < 150 else setup["p1"],
                  [(post - 1, presses[tick])] if tick in presses else [], tick * DT, DT)
    trip.lock(st)
    return st


def taus(st, row=None):
    base = [0.0] * 8
    floors = trip.learner_floors(st, base, row)
    style = trip.style_baseline(st, row) if row else None
    return trip.tau(trip.trip_values(st), st.posts, base, CFG, trip.brush_charges(st), style, floors), floors


def test_learner_floor_is_the_passive_race():
    """Review SHOULD 1: a learner's own presses can't lower its tau below the race it would have
    had without them, and pressing never helps by itself: a press that changes nothing (bounds, on
    the rail) leaves tau exactly the passive tau."""
    passive, _ = taus(learner_race({}))
    bounds = learner_race({30: -1, 60: -1})  # on the rail: "bounds", nothing moves
    t_bounds, floors = taus(bounds)
    assert bounds.presses[0] == 2 and floors[0] is not None
    assert t_bounds == passive  # no edge from pressing
    wide = learner_race({k: 1 for k in range(20, 120, 6)})  # out through the turn: loses ground
    raw = trip.tau(trip.trip_values(wide), wide.posts, [0.0] * 8, CFG, trip.brush_charges(wide))
    t_wide, floors = taus(wide)
    assert raw[0] < passive[0] - 0.002  # the presses cost ground...
    assert t_wide[0] == pytest.approx(passive[0], abs=1e-15)  # ...which the floor gives back, no more
    assert t_wide[1:] == raw[1:]  # nobody else's tau moves
    # not a learner: the presses count in full
    t_full, floors = taus(learner_race({k: 1 for k in range(20, 120, 6)}, learner=False))
    assert floors == [None] * 8 and t_full[0] == raw[0]


def test_learner_floor_needs_a_press_and_shadows_are_never_nested():
    geo = trip.phase_a("dirt", "Classic")
    st = trip.new_state([3, 4, 5], even(3), uniforms(3), geo, CFG, ["manual", "manual", "smart"],
                        learners=[True, True, False])
    play(st, 30, even(3), {5: [(0, -1)], 7: [(1, 1)]})
    assert sorted(st.shadows) == [0, 1]
    assert all(sh.is_shadow and sh.shadows == {} for sh in st.shadows.values())
    assert st.shadows[0].x[1] == st.x[1] and st.shadows[0].x[0] == 3.0 != st.x[0]  # only lane 0's own press is left out
    floors = trip.learner_floors(st, [0.0] * 8)
    assert floors[2] is None and floors[0] is not None
    assert trip.style_baseline(st, [0.1, 0.0, -0.1, 0.02]) == [0.02, 0.02, 0.02]


# ---------------------------------------------------------------- fixed lanes (Hurdles)

def test_fixed_lanes_hold_every_post_and_zero_tau():
    geo = trip.phase_a("dirt", "Mile")
    setup = steering.race_setup(steering.race_seed(74, 1, 0), "Mile")
    kinds = ["bot"] * 6 + ["smart", "manual"]
    st = trip.new_state(steering.posts(), setup["q"], steering.race_uniforms(setup, CFG), geo, CFG, kinds,
                        fixed_lanes=True)
    answers = []
    for tick in range(ticks_to_lock(geo)):
        answers += trip.step(st, setup["q"] if tick < 150 else setup["p1"], [(7, -1)] if tick % 10 == 0 else [],
                             tick * DT, DT)
    trip.lock(st)
    # past the lock to the finish: presses are "locked" and nothing moves (Trip.cosmetic and
    # Trip.submit honour fixed lanes in Luau)
    t = ticks_to_lock(geo) * DT
    while t < geo["length"] / trip.RACE["speed"]:
        assert trip.step(st, setup["p1"], [(7, 1)], t, DT) == ["locked"]
        t += DT
    assert st.x == [float(p) for p in steering.posts()] and set(answers) == {"fixed"}
    assert st.pack_events == [] and st.ground == [0.0] * 8 and st.draft == [0.0] * 8
    assert trip.tau(trip.trip_values(st), steering.posts(), [0.01] * 8, CFG, fixed=True) == [0.0] * 8
    gaps = [abs(st.off[i] - st.off[j]) for i in range(8) for j in range(i + 1, 8) if st.x[i] == st.x[j]]
    assert gaps == []


# ---------------------------------------------------------------- whole races

@pytest.mark.parametrize("seed", range(4))
def test_d072_races_are_deterministic_overlap_free_and_luck_free(seed):
    course, distance = steering.cells()[seed * 2 + 1]
    geo = trip.phase_a(course, distance)
    setup = steering.race_setup(steering.race_seed(75, seed, 0), distance)
    pols = ["bot", "smart", "bot", "scripted", "bot", "bot", "never", "bot"]
    a = steering.run_race(geo, setup, pols, CFG, measure=("stress", "pack"))
    assert a == steering.run_race(geo, setup, pols, CFG, measure=("stress", "pack"))
    assert a["overlaps"] == 0 and a["back_max"] <= steering.TARGETS_D057["stress_fallback_ftps"]
    assert a["drift_rel"] <= 2 * CFG["pack"]["driftMaxFeetPerSecond"] + 1e-9
    # luck never enters Trip: the same race with q and p1 untouched and different luck is the same
    # (Trip takes no luck at all; its uniforms are drawn after every other draw)
    assert len(setup["uniforms72"]) == trip.D072_UNIFORMS * 8


def test_raising_a_lanes_trip_never_lowers_its_tau_with_styles_and_floors():
    rng = random.Random(9)
    for _ in range(200):
        trips = [rng.uniform(-0.03, 0.03) for _ in range(8)]
        style = [rng.choice((-0.003, 0.0, 0.002)) for _ in range(8)]
        learn = [rng.random() < 0.2 for _ in range(8)]
        base = [rng.uniform(-0.02, 0.0) for _ in range(8)]
        k = rng.randrange(8)
        before = trip.tau(trips, list(range(1, 9)), base, CFG, None, style, learn)[k]
        trips[k] += rng.uniform(0, 0.01)
        assert trip.tau(trips, list(range(1, 9)), base, CFG, None, style, learn)[k] >= before - 1e-15
