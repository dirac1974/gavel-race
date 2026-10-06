"""Natural steering, boxed in and brushes (D-057): src/trip.py with D-057 on, the D-057 sims in
sims/steering.py and the trip_d057.json parity runs for the Luau port. Since N5 the game runs
D-057 in full, brushes included (trip.CONFIG, the "live" profile: its baseline is
TripBaseline.luau's; trip.d057_config() is the same config). Full-size runs live in
`python sims/steering.py --write` (tests/fixtures/trip_baseline.json, steering_report.json) and
`--profile d057 --write` (trip_baseline_d057.json, steering_report_d057.json); these tests
assert both and re-check the rules on small runs. The D-054 switch-back is test_trip.py's."""

import copy
import math
import random
import sys
from pathlib import Path

import pytest

import trip

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "sims"))
sys.path.insert(0, str(ROOT / "tests" / "fixtures"))

import make_fixtures  # noqa: E402
import steering  # noqa: E402

CFG = trip.d057_config()
DT = 1.0 / CFG["tickHz"]
LANE_FT = 6.0


def cfg57(**changes):
    cfg = copy.deepcopy(CFG)
    cfg.update(changes)
    return cfg


def play(st, ticks, live, intents=None, start=0):
    answers = {}
    for tick in range(start, start + ticks):
        answers[tick] = trip.step(st, live, (intents or {}).get(tick, []), tick * DT, DT)
    return answers


def phase_a_ticks(geo):
    ticks = 0
    while ticks * DT < trip.lock_time(geo) - trip.EPS:
        ticks += 1
    return ticks


def field(posts, live, kinds=None, cfg=None, course="dirt", distance="Classic"):
    n = len(posts)
    return trip.new_state(posts, list(live), [0.5] * (2 * n), trip.phase_a(course, distance), cfg or CFG,
                          kinds or ["manual"] * n)


@pytest.fixture(scope="module")
def fx25():
    """The generated D-057 parity fixture's runs 0, 3 and 8-24 (every override once) and its
    edge runs, built once for the module."""
    return make_fixtures.trip_d057_fixture(only=[0, 3] + list(range(8, 25)))


@pytest.fixture(scope="module")
def edges(fx25):
    return {e["name"]: e for e in fx25["edges"]}


def pressing_race(seed, cfg=CFG):
    """A race with a masher, a ditherer, a casual rider and a double-presser among bots, with
    every tick's state: (tick, x, v, tgt, off, arrived_at, last_change, answers)."""
    course, distance = steering.cells()[seed % 8]
    geo = trip.phase_a(course, distance)
    setup = steering.race_setup(steering.race_seed(57, seed, 0), distance)
    rng = random.Random(seed)
    roles = list(range(8))
    rng.shuffle(roles)
    masher, ditherer, casual, double = roles[:4]
    kinds = ["bot"] * 8
    for i in (masher, ditherer, casual, double):
        kinds[i] = "smart" if i != casual else "manual"
    st = trip.new_state(steering.posts(), setup["q"], setup["uniforms"], geo, cfg, kinds)
    later = {}
    frames = []
    flip = 1
    for tick in range(phase_a_ticks(geo)):
        intents = list(later.pop(tick, []))
        if rng.random() < 0.4:
            intents.append((masher, rng.choice((-1, 1))))
        if tick % 2 == 0:
            flip = -flip
            intents.append((ditherer, flip))
        if rng.random() < 0.03:
            intents.append((casual, -1 if rng.random() < 0.7 else 1))
        if rng.random() < 0.04:
            d = rng.choice((-1, 1))
            intents.append((double, d))
            later.setdefault(tick + rng.randint(2, 19), []).append((double, d))
        answers = trip.step(st, setup["q"] if tick < 200 else setup["p1"], intents, tick * DT, DT)
        frames.append((tick, list(st.x), list(st.v), list(st.tgt), list(st.off), list(st.arrived_at),
                       list(st.last_change), list(zip(intents, answers))))
    return st, frames, kinds


@pytest.fixture(scope="module")
def races():
    return [pressing_race(seed) for seed in range(8)]


# ---------------------------------------------------------------- config

def test_d057_config_turns_on_every_rule_and_records_it():
    assert CFG["glide"] == "eased" and CFG["blockedPress"] == "wait" and CFG["brush"] == "repeat"
    assert (CFG["laneSpeedMax"], CFG["laneAccel"], CFG["chainWindow"]) == (1.5, 4.5, 0.3)
    assert (CFG["reverseGapSeconds"], CFG["weaveGapSeconds"], CFG["weaveWindowSeconds"]) == (0.5, 2.5, 7.0)
    assert (CFG["pressBounceSeconds"], CFG["glideReserveFeet"], CFG["gapWaitSeconds"],
            CFG["gapWaitInSeconds"]) == (0.2, 6.0, 1.5, 0.0)
    assert (CFG["brushCost"], CFG["brushFree"], CFG["brushMaxCharged"], CFG["brushPays"]) == (0.002, 1, 3, "mover")
    assert (CFG["brushAlongFeet"], CFG["brushGraceSeconds"], CFG["brushRepeatSeconds"]) == (8.0, 0.3, 2.0)
    assert (CFG["brushCheckFeet"], CFG["brushRecoverPerSecond"], CFG["steadySeconds"]) == (4.0, 2.0, 1.0)
    assert trip.config_record(CFG) == CFG  # anything switched on records the whole config
    assert trip.d057_config(trip.d054_config()) == CFG  # brushes on top of any base
    with pytest.raises(ValueError):
        field([1], [1.0], cfg=cfg57(glide="curvy"))
    with pytest.raises(ValueError):
        field([1], [1.0], cfg=cfg57(laneAccel=0.0))


# ---------------------------------------------------------------- the glide

def test_free_glides_take_the_decision_times():
    """One lane 1.0 s from press to landing, then 1.6, 2.3 and 3.0 s for two to four chained
    lanes (the plan: one lane in <= 1.0 s, two in <= 1.7 s). D-054: 0.6 s a lane."""
    assert [steering.glide_seconds(CFG, n) for n in (1, 2, 3, 4)] == [1.0, 1.6, 2.3, 3.0]
    assert steering.glide_seconds(trip.d054_config(), 1) == 0.6 and steering.glide_seconds(trip.CONFIG, 1) == 1.0
    alt = cfg57(laneSpeedMax=1.667, laneAccel=5.56)  # the 0.8 s playtest switch
    assert [steering.glide_seconds(alt, n) for n in (1, 2)] == [0.8, 1.4]


def test_the_s_curve_starts_and_lands_softly():
    st = field([5], [1.0])
    xs = []
    for tick in range(12):
        trip.step(st, [1.0], [(0, -1)] if tick == 0 else [], tick * DT, DT)
        xs.append(st.x[0])
    assert xs[0] == pytest.approx(5 - 0.045)  # 0.05 lane in the first 0.1 s: a round trip hides in the ease-in
    assert xs[9] == 4.0 and st.v[0] == 0.0 and st.arrived_at[0] == pytest.approx(1.0)
    speeds = [(a - b) / DT for a, b in zip([5.0] + xs, xs)]
    assert max(speeds) == pytest.approx(1.5)  # 9 ft/s
    assert speeds[0] < speeds[1] < speeds[2] and speeds[6] > speeds[7] > speeds[8]


def test_glides_never_reverse_and_speed_changes_stay_under_the_cap(races):
    """Every horse, every tick, in pressing races: once a glide starts its target only moves
    further the same way (chains), the sideways speed never flips sign, Trip's speed changes by
    at most laneAccel a second (27 ft/s^2) and the drawn finite-difference acceleration stays
    within 30.5 ft/s^2 (the landing snap; D-057 quotes 30)."""
    for _st, frames, _k in races:
        prev = frames[0]
        for fr in frames[1:]:
            _t, x, v, tgt, _o, _a, _lc, _ans = fr
            for i in range(8):
                px, pv, ptgt = prev[1][i], prev[2][i], prev[3][i]
                if px != ptgt and tgt[i] != ptgt:
                    assert (tgt[i] - ptgt) * (ptgt - px) > 0  # a chain, never a turn-back
                assert v[i] * pv >= 0
                if not (v[i] == 0 and x[i] == tgt[i]):
                    assert abs(v[i] - pv) <= CFG["laneAccel"] * DT + 1e-12
                if px != ptgt:
                    assert (x[i] - px) * (ptgt - px) >= 0  # always toward its lane
            prev = fr
        fd_max = 0.0
        for a, b, c in zip(frames, frames[1:], frames[2:]):
            for i in range(8):
                v1 = (b[1][i] - a[1][i]) * LANE_FT / DT
                v2 = (c[1][i] - b[1][i]) * LANE_FT / DT
                fd_max = max(fd_max, abs(v2 - v1) / DT)
                assert abs(v2) <= 9.0 + 1e-9
        assert fd_max <= 30.5


def test_reverse_and_weave_gaps(races):
    """No change opposite to the last one starts within 0.5 s of landing, or within 2.5 s when
    it is a second reversal within weaveWindowSeconds (7 s); reversals are at least 3.5 s apart."""
    checked = 0
    for _st, frames, _k in races:
        for i in range(8):
            last_dir, last_rev, prev_tgt, arrived_before = 0, -1e9, frames[0][3][i], frames[0][5][i]
            reversals = []
            for t, _x, _v, tgt, _o, arrived, _lc, _ans in frames[1:]:
                if tgt[i] != prev_tgt:
                    d = 1 if tgt[i] > prev_tgt else -1
                    if last_dir != 0 and d != last_dir:
                        gap = CFG["weaveGapSeconds"] if (t * DT) - last_rev < CFG["weaveWindowSeconds"] - 1e-9 \
                            else CFG["reverseGapSeconds"]
                        assert t * DT - arrived_before >= gap - 1e-9
                        last_rev = t * DT
                        reversals.append(t * DT)
                        checked += 1
                    last_dir = d
                prev_tgt = tgt[i]
                arrived_before = arrived[i]
            assert all(b - a >= 3.5 - 1e-9 for a, b in zip(reversals, reversals[1:]))
    assert checked > 50


def test_reverse_weave_timing(edges):
    """In at 10.0 s (lands 11.0), Out pressed mid-glide starts at 11.5; In, a second reversal
    within the weave window, starts 2.5 s after landing (15.0); the next Out waits 2.5 s again
    (18.5)."""
    run = edges["reverse-weave"]
    starts = []
    prev = None
    for snap in run["snapshots"]:
        if prev is not None and snap["tgt"] != prev:
            starts.append(snap["tick"])
        prev = snap["tgt"]
    assert starts == [100, 115, 150, 185]
    assert run["answers"] == ["accepted", "queued", "queued", "queued"]


def test_press_bounce(edges):
    run = edges["bounce"]
    assert run["answers"] == ["accepted", "bounce", "bounce", "queued", "queued", "bounce", "accepted", "queued",
                              "queued"]
    # a bounce doesn't pause Smart Steer again
    st = field([4], [1.0], kinds=["smart"])
    trip.step(st, [1.0], [(0, 1)], 1.0, DT)
    assert trip.step(st, [1.0], [(0, 1)], 1.1, DT) == ["bounce"] and st.manual_at[0] == 1.0
    assert trip.step(st, [1.0], [(0, -1)], 1.2, DT) == ["queued"] and st.manual_at[0] == pytest.approx(1.2)
    # D-054 (the switch-back): two presses on one tick are a press and a queued press
    st = field([5], [1.0], cfg=trip.d054_config())
    assert trip.step(st, [1.0], [(0, -1), (0, -1)], 0.0, DT) == ["accepted", "queued"]


# ---------------------------------------------------------------- room, waiting, boxed in

def test_glide_reserve(edges):
    """Horse 2 presses In 12 ft behind horse 1, which is gliding into that lane: no room while
    it glides (14 ft ahead with the 6 ft reserve), room the tick it lands. Without the reserve
    horse 2 would have moved at once."""
    run = edges["reserve"]
    by_tick = {s["tick"]: s for s in run["snapshots"]}
    assert by_tick[102]["sides"][1][0] == "tuck" and by_tick[109]["tgt"][1] == 4
    assert by_tick[108]["x"][0] != 3.0 and by_tick[109]["x"][0] == 3.0  # horse 1 lands on tick 109...
    assert by_tick[110]["tgt"] == [3, 3]  # ...and horse 2 moves on the next
    st = field([2, 4], [0.5, 0.5 - 12 / 320], cfg=cfg57(glideReserveFeet=0.0))
    play(st, 100, [0.5, 0.5 - 12 / 320])
    play(st, 3, [0.5, 0.5 - 12 / 320], {100: [(0, 1)], 102: [(1, -1)]}, start=100)
    assert st.tgt == [3, 3]


def test_boxed_in_both_sides(edges):
    """Horse 2 in lane 3: a horse 11 ft ahead in its lane and horses alongside in lanes 2 and 4.
    Out: no room ("blocked", the arrow greys); In: "tuck" (tuck-back can help, the arrow stays
    lit). Out waits 1.5 s and drops; In tucks back at once and slips in behind; a second In
    while tucking never brushes."""
    run = edges["boxed-both-sides"]
    by_tick = {s["tick"]: s for s in run["snapshots"]}
    s = by_tick[110]
    assert s["sides"][1] == ["tuck", "blocked"] and s["boxed"][1] and not s["boxedNoTuck"][1]
    assert not s["noTuckInside"][1]  # the In arrow stays lit: tuck-back can help
    assert by_tick[124]["want"][1] == 1 and by_tick[125]["want"][1] == 0  # dropped at 1.5 s
    assert by_tick[130]["tucking"][1] and run["answers"] == ["accepted", "accepted", "queued"]
    assert by_tick[145]["tgt"][1] <= 2 and run["events"] == [] and run["charged"] == [0, 0, 0, 0]


def test_no_tuck_inside_waits_for_room_and_drops_only_when_told(edges):
    """An inward press with no tuck slot within tuckBackMax (no_tuck_inside: the grey In arrow,
    D-057's "trapped") waits until room (gapWaitInSeconds 0, as D-054) and drops after
    gapWaitInSeconds otherwise; Smart Steer in that spot never drops."""
    cap = edges["trapped-brush-cap"]
    s = {x["tick"]: x for x in cap["snapshots"]}[110]
    assert s["sides"][1] == ["blocked", "blocked"] and s["boxed"][1] and s["noTuckInside"][1] and s["boxedNoTuck"][1]
    window = {x["tick"]: x for x in edges["brush-window"]["snapshots"]}
    assert window[130]["want"][1] == -1  # pressed at 11.0 s, still waiting 2 s later (outward would drop at 1.5 s)
    drop = {x["tick"]: x for x in edges["trapped-drop"]["snapshots"]}
    assert drop[129]["want"][0] == -1 and drop[130]["want"][0] == 0
    smart = edges["smart-trapped"]
    tail = smart["snapshots"][-1]
    assert tail["tgt"][0] == 3 and tail["sides"][0][0] == "blocked" and smart["events"] == []


def test_side_state_matches_trips_clearance(races):
    """side_state is Trip's own rule: "free" exactly when _slot finds room, "tuck" only inward
    with a slot within tuckBackMax, "blocked" at the rail and the outer edge."""
    st, _frames, _k = races[0]
    for i in range(8):
        for d in (-1, 1):
            lane = st.tgt[i] + d
            state = trip.side_state(st, i, d)
            if lane < 1 or lane > 8:
                assert state == "blocked"
                continue
            slot, blocked = trip._slot(st, i, lane)
            assert (state == "free") == (not blocked)
            if state == "tuck":
                assert d < 0 and st.off[i] - slot <= CFG["tuckBackMax"] + trip.EPS
    st = field([1, 8], [0.5, 0.5])
    assert trip.side_state(st, 0, -1) == "blocked" and trip.side_state(st, 1, 1) == "blocked"
    assert not trip.boxed_in(st, 0) and not trip.no_tuck_inside(st, 0) and not trip.boxed_no_tuck(st, 0)


# ---------------------------------------------------------------- brushes

def test_brush_cap_steady_and_mover_pays(edges):
    """Horse 2 (no tuck slot inside) presses In twice within 2 s: a brush (the first free), then
    2, 3, 4 (charged, up to the cap: 0.006); a fifth second press just queues; presses while
    steadying answer "steady". Only the mover pays; the horse it brushes (lane 2's leader) never
    does. After the bell: nothing."""
    run = edges["trapped-brush-cap"]
    assert run["answers"] == ["accepted", "brush", "steady", "accepted", "brush", "accepted", "brush", "accepted",
                              "brush", "accepted", "queued", "cancelled", "cancelled"]
    assert run["events"] == [[115, 2, 3, -1], [135, 2, 3, -1], [152, 2, 3, -1], [172, 2, 3, -1]]
    assert run["brushes"] == [0, 4, 0, 0, 0, 0, 0] and run["charged"] == [0, 4, 0, 0, 0, 0, 0]
    assert run["charges"][1] == pytest.approx(0.006, abs=1e-15) and run["charges"].count(0.0) == 6
    assert run["afterLockAnswers"] == ["locked"] * 3
    by_tick = {s["tick"]: s for s in run["snapshots"]}
    assert by_tick[115]["check"][1] == pytest.approx(4.0 - 0.2)  # steadies back 4 ft, recovering 2 ft/s
    assert by_tick[115]["want"][1] == 0  # its waiting press cleared
    assert all(s["check"][2] == 0 for s in run["snapshots"])  # the other horse never steadies


def test_brush_window_expires_after_two_seconds(edges):
    """Before any cap: a second In 2.1 s after the first is a new try (it queues, no brush); a
    fresh pair 1.8 s apart brushes."""
    run = edges["brush-window"]
    assert run["answers"] == ["accepted", "queued", "cancelled", "cancelled", "accepted", "brush"]
    assert run["events"] == [[158, 2, 3, -1]] and run["brushes"][1] == 1


def test_brush_window_starts_when_the_waiting_press_was_made(edges):
    """The 2 s window runs from the press now waiting, even when it was queued behind a glide or
    a reverse gap (N1's call; the plan timed it from the last accepted press). Horse 1's Out,
    queued mid-glide at 10.5 s, waits for the reverse gap and a horse alongside; its second Out
    at 12.2 s brushes: 1.7 s after the queued press, 2.2 s after the accepted In."""
    run = edges["brush-window-queued"]
    assert run["answers"] == ["accepted", "queued", "brush"]
    accepted, queued, brushed = (i[0] for i in run["intents"])
    assert brushed - queued <= 20 < brushed - accepted
    snap = {s["tick"]: s for s in run["snapshots"]}[brushed - 1]
    assert snap["firstPressAt"][0] == pytest.approx(queued * DT) and snap["want"][0] == 1
    assert snap["alongSince"][0][1] <= (brushed - 3) * DT + 1e-9  # alongside for brushGraceSeconds
    assert run["events"] == [[brushed, 1, 2, 1]]


def test_smart_steer_wait_clock_only_counts_an_unbroken_wait(edges):
    """smart_block_at starts when Smart Steer's move first meets no room and clears on any tick
    it doesn't try and fail (here: a press pauses it), so a later block starts a fresh wait."""
    st = field([3, 2, 2, 2, 2], [0.2] * 5, kinds=["smart"] + ["manual"] * 4)
    play(st, 170, [0.2] * 5)  # Smart Steer heads in from 15.6 s and finds no room
    assert st.smart_block_at[0] == pytest.approx(15.6, abs=0.15)
    play(st, 1, [0.2] * 5, {170: [(0, 1)]}, start=170)  # a press pauses it: nothing tried
    assert st.smart_block_at[0] == trip.LONG_AGO


def test_brush_needs_the_grace_and_a_second_press(edges):
    """Out into a horse closing from behind: the first press waits (never a brush); a second
    press the tick after the horse comes alongside is inside brushGraceSeconds and queues; a
    third, 0.4 s after it came alongside, brushes."""
    assert edges["grace"]["answers"] == ["accepted", "queued", "brush"]
    assert edges["grace"]["charged"] == [1, 0]


def test_brush_pays_bumped_switch(edges):
    """brushPays = "bumped" (sims only) charges and steadies the other horse; D-057 ships "mover"."""
    run = edges["brush-out-bumped-pays"]
    assert run["answers"] == ["accepted", "brush", "steady"] and run["charged"] == [0, 1]


def test_brushes_in_pressing_races(races):
    """A brush is always a rider's second press the same way within brushRepeatSeconds of an
    accepted or queued first press; bots and Smart Steer never brush (no press, no brush); the
    mover pays and nobody else; at most brushFree + brushMaxCharged a race."""
    total = 0
    for st, frames, kinds in races:
        presses = {}
        for tick, *_rest, answered in frames:
            for (i, d), ans in answered:
                if ans == "brush":
                    total += 1
                    assert kinds[i] != "bot"
                    assert any(d2 == d and a2 in ("accepted", "queued") and tick - t2 <= 20 for t2, d2, a2 in presses[i])
                presses.setdefault(i, []).append((tick, d, ans))
        assert st.charged == st.brushes
        assert all(b <= CFG["brushFree"] + CFG["brushMaxCharged"] for b in st.brushes)
        movers = {e[2] for e in st.events}
        assert all(kinds[i] != "bot" for i in movers)
    assert total > 5


def test_bots_and_smart_steer_never_brush():
    for seed in range(3):
        course, distance = steering.cells()[seed]
        setup = steering.race_setup(steering.race_seed(58, seed, 0), distance)
        for kinds in (["bot"] * 8, ["smart"] * 8):
            st = trip.new_state(steering.posts(), setup["q"], setup["uniforms"], trip.phase_a(course, distance), CFG, kinds)
            play(st, phase_a_ticks(trip.phase_a(course, distance)), setup["q"])
            assert st.events == [] and st.charged == [0] * 8


def test_brush_term_sits_after_the_field_mean_and_inside_the_clamp():
    rng = random.Random(5)
    trips = [rng.uniform(-0.01, 0.01) for _ in range(8)]
    base = [0.0] * 8
    posts = list(range(1, 9))
    plain = trip.tau(trips, posts, base, CFG)
    assert trip.tau(trips, posts, base, CFG, [0.0] * 8) == plain
    charged = [0.0, 0.004, 0.0, 0.0, 0.0, 0.0, 0.0, 0.006]
    with_brush = trip.tau(trips, posts, base, CFG, charged)
    for i in range(8):
        assert with_brush[i] == pytest.approx(plain[i] - charged[i], abs=1e-15)  # nobody else moves
    near_floor = [-0.10] + [0.0] * 7
    floored = trip.tau(near_floor, posts, base, CFG, [0.006] + [0.0] * 7)
    assert floored[0] == CFG["floor"]  # inside the clamp: never below the floor
    assert trip.tau(trips, posts, base, cfg57(scale=0.0), charged) == [0.0] * 8
    assert trip.tau(trips, posts, base, cfg57(enabled=False), charged) == [0.0] * 8
    with pytest.raises(ValueError):
        trip.tau(trips, posts, base, CFG, [0.0] * 7)


def test_nothing_changes_after_the_lock():
    st = field([3, 3, 2, 2, 2, 2, 4], [1 / 7 + 11 / 320] + [1 / 7] * 6)
    play(st, 120, [1 / 7 + 11 / 320] + [1 / 7] * 6, {110: [(1, -1)], 115: [(1, -1)]})
    assert st.brushes[1] == 1
    trip.lock(st)
    frozen = copy.deepcopy(st.__dict__)
    assert trip.accept_intent(st, 1, -1, 12.5) == "locked"
    assert trip.step(st, [1 / 7] * 7, [(1, -1), (1, -1)], 12.6, DT) == ["locked", "locked"]
    trip.lock(st)
    assert st.__dict__ == frozen and trip.brush_charge(st, 1) == 0.0


def test_no_overlaps_or_hops_in_pressing_races(races):
    """No two horses within half a lane and 6 ft, and no horse falls back faster than
    holdPullPerSecond, in pressing races (the sim's stress run: 4,000 races, stored)."""
    for _st, frames, _k in races:
        prev_off = frames[0][4]
        for _t, x, _v, _tg, off, *_rest in frames[1:]:
            for i in range(8):
                assert prev_off[i] - off[i] <= CFG["holdPullPerSecond"] * DT + 1e-9
                for j in range(i + 1, 8):
                    assert not (abs(x[i] - x[j]) < 0.5 and abs(off[i] - off[j]) < 6.0)
            prev_off = off


# ---------------------------------------------------------------- parity fixture (N2)

def test_d057_fixture_replays_exactly(fx25):
    """trip_d057.json (make_fixtures.py --d057; tests/luau loads it in N2): a replay of recorded
    presses reproduces answers, snapshots, events, charges and tau with the brush term."""
    fx = fx25
    assert fx["cfg"] == CFG and fx["defaults"] == trip.CONFIG
    assert fx["cfgExact"]["laneAccel"] == "4.5" and fx["defaultsExact"]["glide"] == "eased"
    runs = [fx["runs"][k] for k in (0, 1, 2, 3, 7, 15)] + fx["edges"]  # runs 0, 3, 8, 9, 13, 21
    styles = set()
    for run in runs:
        cfg = run.get("cfg", fx["cfg"])
        styles.update(s for _i, s in run.get("styles", []))
        by_tick = {}
        for tick, lane, d in run["intents"]:
            by_tick.setdefault(tick, []).append((lane - 1, d))
        st = trip.new_state(run["posts"], run["q"], run["uniforms"], trip.phase_a(run["course"], run["distance"]), cfg,
                            run["kinds"])
        answers, snaps, events = [], [], []
        for tick in range(run["ticks"]):
            before = len(st.events)
            answers.extend(trip.step(st, run["q"] if tick < run["switchTick"] else run["p1"], by_tick.get(tick, []),
                                     tick * DT, DT))
            events.extend([tick, e[2] + 1, e[3] + 1, e[4]] for e in st.events[before:])
            if tick % run["snapEvery"] == 0 or tick == run["ticks"] - 1:
                snaps.append(make_fixtures._d057_snapshot(st, tick))
        assert answers == run["answers"] and snaps == run["snapshots"]
        trip.lock(st)
        late = trip.step(st, run["p1"], [(lane - 1, d) for lane, d in run["afterLock"]], run["ticks"] * DT, DT)
        assert late == ["locked"] * len(run["afterLock"])
        charges = trip.brush_charges(st)
        assert charges == run["charges"] and events == run["events"]
        row = trip.baseline_row(fx["baseline"], run["course"], run["distance"])
        assert trip.tau(trip.trip_values(st), run["posts"], row, cfg, charges) == run["tau"]
    assert {"masher", "ditherer", "double", "bounce"} <= styles


def test_d057_fixture_covers_every_rule(fx25):
    """The generated fixture's runs 0, 3 and 8-24 (every override once) and the edge runs
    exercise every answer, the brush cap, every side state and both sides of each switch."""
    fx = fx25
    answers = {a for r in fx["runs"] + fx["edges"] for a in r["answers"]}
    assert {"accepted", "queued", "cancelled", "bounds", "rate", "invalid", "bounce", "steady", "brush"} <= answers
    assert sum(len(r["events"]) for r in fx["runs"]) > 50
    assert any(max(r["charged"]) >= 4 for r in fx["runs"])  # the cap
    assert {"free", "tuck", "blocked"} <= {s for r in fx["runs"] for snap in r["snapshots"] for pair in snap["sides"]
                                          for s in pair}
    overridden = {k for r in fx["runs"] if "cfg" in r for k in r["cfg"] if r["cfg"][k] != fx["cfg"][k]}
    assert {"glide", "brush", "blockedPress", "brushPays", "chainWindow", "glideReserveFeet", "pressBounceSeconds",
            "weaveGapSeconds", "gapWaitInSeconds", "tuckAfterSeconds"} <= overridden
    # The whole switch-back is one of the generated runs (the Luau port replays it too).
    full = make_fixtures.trip_d057_fixture(only=[25])["runs"][0]
    assert all(full["cfg"][k] == trip.D057_OFF[k] for k in trip.D057_KEYS)


# ---------------------------------------------------------------- the game's config (N3)

LIVE = trip.CONFIG


def test_game_config_runs_d057_in_full():
    """N3 switched D-057's motion and press rules on in CONFIG (GameConfig.steering mirrors it), and
    N5 the brushes, with only the mover paying. The switch-back is trip.d054_config()."""
    for key, value in trip.D057.items():
        assert LIVE[key] == value, key
    assert LIVE["brush"] == "repeat" and LIVE["brushPays"] == "mover"
    assert trip.d057_on(LIVE) and trip.d057_config() == LIVE == trip.d057_config(trip.d054_config())
    back = trip.d054_config()
    assert all(back[k] == trip.D057_OFF[k] for k in trip.D057_KEYS)
    assert (trip.D057_OFF["glide"], trip.D057_OFF["chainWindow"], trip.D057_OFF["reverseGapSeconds"],
            trip.D057_OFF["weaveGapSeconds"], trip.D057_OFF["pressBounceSeconds"], trip.D057_OFF["glideReserveFeet"],
            trip.D057_OFF["blockedPress"]) == ("linear", 0.0, 0.0, 0.0, 0.0, 0.0, "d054")  # REVIEW_QUEUE's switch-back


def test_game_baseline_files_are_current():
    """TripBaseline.luau and trip_baseline.json come from the game's config (python
    sims/steering.py --write); the stored probes reproduce exactly."""
    data = steering.load_baseline("live")
    assert data["config"] == trip.config_record(LIVE), "the config changed: run python sims/steering.py --write"
    assert data["race"] == trip.RACE and data["races"] >= 2000
    assert data["calibrationPasses"] == steering.CALIBRATION_PASSES
    assert steering.BASELINE_LUAU.read_text() == steering.render_luau(data)
    for course, distance in (("dirt", "Sprint"), ("turf", "Mile"), ("dirt", "Marathon")):
        assert steering.probe_cell(course, distance, LIVE) == data["probe"]["baseline"][course][distance]


@pytest.fixture(scope="module")
def report_live():
    return steering.load_report("live")


def test_stored_game_report_meets_every_target(report_live):
    """The full run on the game's config (2,000 baseline races per cell and post, 600 report
    races per cell, 200 griefing races per cell, 4,000 stress races): every D-054 tau target per
    course x distance, reach per intent >= 70% per cell, and every D-057 target, brushes on (N5):
    casual riders charged in <= 5% of races per cell, only the mover ever pays, and the griefing
    bound holds."""
    data = steering.load_baseline("live")
    assert report_live["config"] == trip.config_record(LIVE) and report_live["profile"] == "live"
    assert report_live["baselineSeed"] == data["seed"] and report_live["baselineRaces"] == data["races"]
    assert report_live["races"] >= 600 and report_live["griefRaces"] >= 200 and report_live["stressRaces"] * 8 >= 4000
    s = report_live["summary"]
    t, t57 = steering.TARGETS, steering.TARGETS_D057
    for r in s["rows"]:
        cell = (r["course"], r["distance"])
        assert t["rail_vs_smart"][0] <= r["rail_vs_smart"] <= t["rail_vs_smart"][1], cell
        assert t["never"][0] <= r["never"] <= t["never"][1], cell
        assert r["intent3s"] >= t57["intent3s"], cell
        assert r["draft_share"] <= t["draft_share"], cell
        assert max(abs(v) for v in r["smart_post"]) < t["post_bias"], cell
        assert max(abs(v) for v in r["allsmart_post"]) < t["post_bias"], cell
        assert abs(r["smart_among_bots"]) <= t["smart_mean"], cell
        assert abs(r["allsmart_mean"]) <= t["smart_mean"], cell
        assert r["masher_reversals_per_min"] <= t57["masher_reversals_per_min"], cell
        assert r["scripted_charged_races"] <= t57["casual_charged_share"], cell
        assert all(r[pol + "_others_charged"] == 0 for pol in steering.FOCAL_D057), cell  # only the mover pays
    assert s["stress"]["overlap_frames"] == 0 and s["stress"]["back_max"] <= t57["stress_fallback_ftps"]
    assert s["stress"]["brushes"] > 0
    assert s["glides"] == {"1": 1.0, "2": 1.6, "3": 2.3, "4": 3.0}
    assert all(s["checks"].values()), [k for k, v in s["checks"].items() if not v]
    assert s["checks"] == steering.check_targets(s)


def test_stored_game_report_probes_replay_exactly(report_live):
    """The probe races stored with the game's report replay exactly (a stale report fails)."""
    assert steering.probe_races(LIVE) == report_live["probes"]
    assert sum(report_live["probes"]["masher"]["brushes"]) > 0 and sum(report_live["probes"]["bumper"]["brushes"]) > 0


def test_grief_bound_holds_in_the_stored_game_report(report_live):
    """With brushes on (N5): strangers who target a kid gain nothing over riding for the rail, and
    the kid is only ever charged for its own brushes (a Smart Steer kid never)."""
    g = report_live["summary"]["griefing"]
    for kid in steering.GRIEF_KIDS:
        for target, control in steering.GRIEF_PAIRS:
            assert g[kid]["pooled"][target + "_minus_" + control] >= steering.TARGETS_D057["griefing"], (kid, target)
        for name in steering.GRIEF:
            assert g[kid]["pooled"][name]["kid_charged_not_own"] == 0
    assert all(g["smart"]["pooled"][name]["kid_charged_per_race"] == 0 for name in steering.GRIEF)


# ---------------------------------------------------------------- calibration with D-057 in full (brushes on)

@pytest.fixture(scope="module")
def report57():
    return steering.load_report("d057")


def test_d057_baseline_file_is_current():
    data = steering.load_baseline("d057")
    assert data["config"] == trip.config_record(CFG)
    assert data["race"] == trip.RACE and data["races"] >= 2000
    assert data["calibrationPasses"] == steering.CALIBRATION_PASSES
    assert steering.probe_cell("dirt", "Sprint", CFG) == data["probe"]["baseline"]["dirt"]["Sprint"]


def test_stored_d057_report_meets_every_target(report57):
    """The full D-057 run (2,000 baseline races per cell and post, 600 report races per cell,
    200 griefing races per cell, 4,000 stress races): every D-054 tau target per course x
    distance, reach per intent >= 70% per cell (it replaces D-054's per-press figure, which
    stays in the report), and every new D-057 target."""
    data = steering.load_baseline("d057")
    assert report57["config"] == trip.config_record(CFG) and report57["profile"] == "d057"
    assert report57["baselineSeed"] == data["seed"] and report57["baselineRaces"] == data["races"]
    assert report57["races"] >= 600 and report57["griefRaces"] >= 200 and report57["stressRaces"] * 8 >= 4000
    s = report57["summary"]
    t, t57 = steering.TARGETS, steering.TARGETS_D057
    for r in s["rows"]:
        cell = (r["course"], r["distance"])
        assert t["rail_vs_smart"][0] <= r["rail_vs_smart"] <= t["rail_vs_smart"][1], cell
        assert t["never"][0] <= r["never"] <= t["never"][1], cell
        assert r["intent3s"] >= t57["intent3s"], cell
        assert r["draft_share"] <= t["draft_share"], cell
        assert max(abs(v) for v in r["smart_post"]) < t["post_bias"], cell
        assert max(abs(v) for v in r["allsmart_post"]) < t["post_bias"], cell
        assert abs(r["smart_among_bots"]) <= t["smart_mean"], cell
        assert abs(r["allsmart_mean"]) <= t["smart_mean"], cell
        assert r["scripted_charged_races"] <= t57["casual_charged_share"], cell
    assert s["stress"]["overlap_frames"] == 0 and s["stress"]["back_max"] <= t57["stress_fallback_ftps"]
    assert s["glides"] == {"1": 1.0, "2": 1.6, "3": 2.3, "4": 3.0}
    assert all(s["checks"].values()), [k for k, v in s["checks"].items() if not v]
    assert s["checks"] == steering.check_targets(s)


def test_small_run_d057_meets_the_targets():
    """A fresh small run with D-057 on (dirt Sprint and turf Classic, 10 races each, the same
    race replayed per policy, against the D-057 baseline): rail rider beats Smart Steer by +0.01
    to +0.03, never-steer sits between -0.02 and -0.01, and a casual rider's inward presses
    reach their lane within 3 s per intent at least 70% of the time (pooled)."""
    table = steering.load_baseline("d057")["baseline"]
    ok = n = 0
    for course, distance in (("dirt", "Sprint"), ("turf", "Classic")):
        cell = steering.cells().index((course, distance))
        geo = trip.phase_a(course, distance)
        row = trip.baseline_row(table, course, distance)
        diff, never = [], []
        for k in range(10):
            setup = steering.race_setup(steering.race_seed(5757, cell, k), distance)
            f = setup["focal"]
            taus = {}
            for pol in ("smart", "rail", "never", "scripted"):
                pols = ["bot"] * 8
                pols[f] = pol
                res = steering.run_race(geo, setup, pols, CFG)
                taus[pol] = trip.tau(res["trip"], steering.posts(), row, CFG, res["brush_cost"])[f]
                if pol == "scripted":
                    ok += res["intent"][0]
                    n += res["intent"][1]
            diff.append(taus["rail"] - taus["smart"])
            never.append(taus["never"])
        assert 0.01 <= sum(diff) / len(diff) <= 0.03, (course, distance, sum(diff) / len(diff))
        assert -0.02 <= sum(never) / len(never) <= -0.01, (course, distance, sum(never) / len(never))
    assert ok / n >= 0.70, ok / n


def test_griefing_small_run():
    """Strangers who tapped exactly like a Smart Steer kid and target it (a shadow on its inside,
    a bumper pressing into it) change its own trip (ground + draft) by no more than the same
    strangers riding for the rail without targeting anyone: targeted minus untargeted >= -0.001
    (pooled; the stored full run checks each scenario over 1,600 races). The kid never pays for
    a brush. One cell; the stored run checks all eight."""
    cfg = CFG
    shadow, bumper = [], []
    for cell in (1,):  # dirt Mile
        course, distance = steering.cells()[cell]
        geo = trip.phase_a(course, distance)
        for k in range(10):
            setup = steering.race_setup(steering.race_seed(steering.GRIEF_SEED + 1, cell, k), distance)
            kid = setup["focal"]
            others = [i for i in range(8) if i != kid]
            random.Random(setup["press_seed"] ^ 0x5EED).shuffle(others)
            own = {}
            for name in ("shadow", "bumper", "rail1"):
                pols = ["bot"] * 8
                pols[kid] = "smart"
                pols[others[0]] = steering.GRIEF[name][0][0]
                res = steering.run_race(geo, setup, pols, cfg, match={others[0]: 0.0}, focal=kid)
                assert res["charged"][kid] == 0
                own[name] = res["trip"][kid] - res["brush_cost"][kid]
            shadow.append(own["shadow"] - own["rail1"])
            bumper.append(own["bumper"] - own["rail1"])
    assert sum(shadow) / len(shadow) >= steering.TARGETS_D057["griefing"]
    assert sum(bumper) / len(bumper) >= steering.TARGETS_D057["griefing"]


def test_stored_d057_report_probes_replay_exactly(report57):
    """Exact races stored with the report (a masher, a casual rider, a bumper against a Smart
    Steer kid, a stress field): any change to the press, brush, bounce, weave or glide rules
    changes them, so the report can't go stale while the tests stay green. Rerun
    python sims/steering.py --profile d057 --write after such a change."""
    assert steering.probe_races(CFG) == report57["probes"]
    assert sum(report57["probes"]["masher"]["brushes"]) > 0 and sum(report57["probes"]["bumper"]["brushes"]) > 0


def test_grief_bound_holds_in_the_stored_report(report57):
    g = report57["summary"]["griefing"]
    for kid in steering.GRIEF_KIDS:
        for target, control in steering.GRIEF_PAIRS:
            assert g[kid]["pooled"][target + "_minus_" + control] >= steering.TARGETS_D057["griefing"], (kid, target)
        for name in steering.GRIEF:
            assert g[kid]["pooled"][name]["kid_charged_not_own"] == 0
    assert all(g["smart"]["pooled"][name]["kid_charged_per_race"] == 0 for name in steering.GRIEF)
    assert math.isfinite(g["smart"]["pooled"]["bumper"]["stranger_charged_per_race"])
