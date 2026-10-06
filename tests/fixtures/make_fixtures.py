#!/usr/bin/env python3
"""Generate Python reference fixtures for the Luau parity tests.

Writes tests/fixtures/race_math.json and tests/fixtures/trip.json; with --d057 also
tests/fixtures/trip_d057.json (about 15 MB; CI and tests/test_luau_parity.py pass --d057, and
tests/luau/trip_d057_tests.luau replays it against Trip.luau). Deterministic (fixed seeds).
race_math.json is append-only: new sections draw from their own generators, so the original
sections stay byte-for-byte the same. trip.json is D-054 (it records the config without the
D-057 keys, which are all off); trip_d057.json is D-057 switched on.
"""

import json
import random
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "src"))

import gavel_race_v2 as m  # noqa: E402
import race_rating as rr  # noqa: E402
import stride as st  # noqa: E402
import pace_meter as pm  # noqa: E402
import trip  # noqa: E402

TRIP_RUNS = 200
SNAPSHOT_EVERY = 10  # ticks (1 s)
TRIP_OVERRIDES = [None] * 8 + [{"scale": 0.5}, {"enabled": False}, {"maxQueued": 0}, {"smart.homeLane": 1},
                               {"scale": 0.0}, {"gapRampSeconds": 0.0}]


class ListRng:
    """Replays a fixed list of uniforms, like the Luau test stub."""

    def __init__(self, values):
        self.values = list(values)
        self.i = 0

    def random(self):
        v = self.values[self.i]
        self.i += 1
        return v


def race_math_data() -> dict:
    """Everything in race_math.json, in the original generation order."""
    rng = random.Random(20261004)
    cases = []
    for _ in range(300):
        n = rng.choice([2, 4, 6, 8, 8, 8])
        cfg = m.Config(
            T=rng.choice([12.0, 14.4, 18.0, 22.0]),
            q_floor=rng.choice([0.0, 0.025, 0.04]),
            kappa=rng.choice([0.6, 1.0, 1.2, 1.4]),
            r_floor=rng.choice([-1.0, -0.5, -0.25]),
            B=rng.choice([20, 50, 120, 300, 750]),
        )
        ratings = [round(rng.uniform(20, 95), 3) for _ in range(n)]
        scores = [round(rng.uniform(0, 100), 3) for _ in range(n)]
        uniforms = [rng.random() for _ in range(n)]
        q = m.base_chances(ratings, cfg)
        R = m.skills(scores, cfg)
        p = m.live_chances(q, R, cfg)
        cases.append({
            "cfg": {"T": cfg.T, "qFloor": cfg.q_floor, "kappa": cfg.kappa, "rFloor": cfg.r_floor, "B": cfg.B},
            "ratings": ratings,
            "scores": scores,
            "uniforms": uniforms,
            "q": q,
            "purses": m.lock_purses(q, cfg),
            "R": R,
            "p": p,
            "finish": [i + 1 for i in m.draw_finish(p, ListRng(uniforms))],  # 1-based for Luau
        })
    windows = [{"d": d, "s": m.window_score(d)} for d in (-0.5, 0, 0.1, 0.25, 0.5, 0.99, 1, 1.5)]
    ratings_cases = []
    strategies = [None, "FrontRunner", "Stalker", "Closer"]
    for _ in range(300):
        stats = {k: round(rng.uniform(-10, 110), 2) for k in ("speed", "accel", "stamina", "grit", "focus")}
        cond = {"distance": rng.choice(list(rr.DISTANCE_WEIGHTS)), "surface": rng.choice(list(rr.SURFACE_SHIFT)),
                "weather": rng.choice(list(rr.WEATHER_SHIFT))}
        care, pilot, bond = rng.uniform(-0.2, 1.2), rng.uniform(0, 1), rng.uniform(0, 1)
        strategy = rng.choice(strategies)
        ratings_cases.append({"stats": stats, "cond": cond, "care": care, "pilot": pilot, "bond": bond,
                              "strategy": strategy or "", "rating": rr.rating(stats, cond, care, pilot, strategy, bond)})
    stride_cases = []
    for _ in range(200):
        lo = rng.choice([0.42, 0.46, 0.50, 0.55, 0.60])
        spec = {"beats": 8, "intervalLo": lo, "intervalHi": lo + rng.choice([0.0, 0.05, 0.06]),
                "drift": rng.choice([0.0, 0.02, 0.03]), "leadChange": rng.random() < 0.3, "half": 0.08}
        uniforms = [rng.random() for _ in range(spec["beats"])]
        start = round(rng.uniform(0, 100), 3)
        beats = st.schedule(ListRng(uniforms), start, spec["beats"], spec["intervalLo"], spec["intervalHi"],
                            spec["drift"], spec["leadChange"])
        sd = rng.choice([0.005, 0.03, 0.06])
        taps = [b + rng.gauss(-0.02, sd) for b in beats if rng.random() > 0.1]
        taps += [rng.uniform(beats[0] - 0.3, beats[-1] + 0.3) for _ in range(rng.choice([0, 0, 1, 3]))]
        taps.sort()
        stride_cases.append({"spec": spec, "uniforms": uniforms, "start": start, "beats": beats, "taps": taps,
                             "score": st.score(beats, taps, spec["half"]),
                             "gaps": st.gap_errors(beats, taps, spec["half"])})
    pace_cases = []
    for _ in range(120):
        spec = {"sweepSeconds": rng.choice([1.1, 1.3, 1.6, 2.0, 2.4]), "speedDrift": rng.choice([0.0, 0.08, 0.15]),
                "shiftMin": 2, "shiftMax": 3, "centerRange": rng.choice([0.0, 0.5, 0.6])}
        start = round(rng.uniform(0, 100), 3)
        duration = rng.choice([12.0, 20.0, 36.0])
        uniforms = [rng.random() for _ in range(400)]
        passes = pm.schedule(ListRng(uniforms), start, duration, spec["sweepSeconds"], spec["speedDrift"],
                             spec["shiftMin"], spec["shiftMax"], spec["centerRange"])
        sd = rng.choice([0.01, 0.05, 0.12])
        taps = [pm.ideal_time(p) + rng.gauss(0, sd) for p in passes if rng.random() > 0.15]
        taps += [rng.uniform(start, start + duration) for _ in range(rng.choice([0, 2, 6]))]
        taps.sort()
        mean, errs, single = pm.score(passes, taps)
        # Finger bounces (D-055): some taps get a second touch 20-200 ms later (own generator, so
        # the other cases' numbers don't move).
        brng = random.Random(len(pace_cases) * 7919 + 17)
        btaps = sorted(taps + [t + brng.uniform(0.02, 0.2) for t in taps if brng.random() < 0.3])
        bmean, berrs, bsingle = pm.score(passes, btaps, 0.15)
        pace_cases.append({"spec": spec, "start": start, "duration": duration, "uniforms": uniforms,
                           "passes": [p._asdict() for p in passes], "taps": taps, "score": mean, "errors": errs,
                           "single": single, "bounceTaps": btaps, "bounceScore": bmean, "bounceErrors": berrs,
                           "bounceSingle": bsingle})
    return {"cases": cases, "windows": windows, "ratings": ratings_cases, "stride": stride_cases,
            "pace": pace_cases, "extraCases": extra_cases()}


def main(argv=None) -> None:
    argv = sys.argv[1:] if argv is None else argv
    data = race_math_data()
    out = ROOT / "tests" / "fixtures" / "race_math.json"
    out.write_text(json.dumps(data))
    print(f"wrote {len(data['cases'])} cases to {out.relative_to(ROOT)}")
    trip_out = ROOT / "tests" / "fixtures" / "trip.json"
    trip_out.write_text(json.dumps(trip_fixture()))
    print(f"wrote {TRIP_RUNS} trip runs to {trip_out.relative_to(ROOT)}")
    if "--d057" not in argv:
        return
    d057 = trip_d057_fixture()
    d057_out = ROOT / "tests" / "fixtures" / "trip_d057.json"
    d057_out.write_text(json.dumps(d057))
    print(f"wrote {len(d057['runs'])} D-057 trip runs and {len(d057['edges'])} edge runs to {d057_out.relative_to(ROOT)}")


def extra_cases():
    """live_chances with an extra exponent (crowd boost c + steering tau, D-054): exponent
    kappa * R + extra. Some cases are all-zero extras, which must equal the plain path."""
    rng = random.Random(20261005)
    out = []
    for k in range(100):
        n = rng.choice([2, 4, 6, 8, 8, 8])
        cfg = m.Config(
            T=rng.choice([12.0, 14.4, 18.0, 22.0]),
            q_floor=rng.choice([0.0, 0.025, 0.04]),
            kappa=rng.choice([0.6, 1.0, 1.2, 1.4]),
            r_floor=rng.choice([-1.0, -0.5, -0.25]),
            B=rng.choice([20, 50, 120, 300, 750]),
        )
        ratings = [round(rng.uniform(20, 95), 3) for _ in range(n)]
        scores = [round(rng.uniform(0, 100), 3) for _ in range(n)]
        if k % 10 == 0:
            extra = [0.0] * n
        else:
            extra = [(rng.uniform(0, 0.03) if rng.random() < 0.3 else 0.0) + rng.uniform(-0.02, 0.04) for _ in range(n)]
        uniforms = [rng.random() for _ in range(n)]
        q = m.base_chances(ratings, cfg)
        R = m.skills(scores, cfg)
        p = m.live_chances(q, R, cfg, extra)
        out.append({
            "cfg": {"T": cfg.T, "qFloor": cfg.q_floor, "kappa": cfg.kappa, "rFloor": cfg.r_floor, "B": cfg.B},
            "ratings": ratings,
            "scores": scores,
            "extra": extra,
            "uniforms": uniforms,
            "q": q,
            "R": R,
            "p0": m.live_chances(q, R, cfg),
            "p": p,
            "finish": [i + 1 for i in m.draw_finish(p, ListRng(uniforms))],  # 1-based for Luau
        })
    return out


def trip_run(k, baseline, geometry):
    """One scripted phase-A run from its own seed (so a test can build any subset)."""
    rng = random.Random(20261007 * 1000 + k)
    course = trip.COURSE_ORDER[k % 2]
    distance = trip.DISTANCE_ORDER[(k // 2) % 4]
    geo = geometry[course][distance]
    cfg = trip.CONFIG
    override = TRIP_OVERRIDES[k % len(TRIP_OVERRIDES)] if k >= 8 else None
    if override:
        cfg = json.loads(json.dumps(trip.CONFIG))
        for key, value in override.items():
            node = cfg
            parts = key.split(".")
            for part in parts[:-1]:
                node = node[part]
            node[parts[-1]] = value
    n = 8
    posts = list(range(1, n + 1))
    if k % 3 == 1:
        rng.shuffle(posts)
    kinds = [rng.choice(["bot", "bot", "bot", "smart", "manual"]) for _ in range(n)]
    mcfg = m.Config(T=rng.choice([22.0, 18.0, 14.4, 12.0]))
    ratings = [50 + rng.uniform(-8, 8) for _ in range(n)]
    q = m.base_chances(ratings, mcfg)
    p1 = m.live_chances(q, m.skills([rng.uniform(20, 100) for _ in range(n)], mcfg), mcfg)
    uniforms = [rng.random() for _ in range(2 * n)]
    dt = 1.0 / cfg["tickHz"]
    ticks = 0
    while ticks * dt < trip.lock_time(geo) - trip.EPS:
        ticks += 1
    switch = rng.randrange(ticks // 4, ticks)
    steerers = [i for i in range(n) if kinds[i] != "bot"] or [0]
    rate = rng.choice([0.01, 0.03, 0.1, 0.3])
    intents = []
    by_tick = {}
    for tick in range(ticks):
        for i in steerers:
            if rng.random() < rate:
                roll = rng.random()
                d = -1 if roll < 0.6 else (1 if roll < 0.97 else rng.choice([0, 2]))
                presses = 1 if rng.random() < 0.9 else rng.choice([2, 3])
                for _ in range(presses):
                    intents.append([tick, i + 1, d])
                    by_tick.setdefault(tick, []).append((i, d))
    after_lock = [[rng.randrange(n) + 1, rng.choice([-1, 1])] for _ in range(rng.choice([1, 2, 3]))]
    st_ = trip.new_state(posts, q, uniforms, geo, cfg, kinds)
    answers = []
    snaps = []
    for tick in range(ticks):
        t = tick * dt
        answers.extend(trip.step(st_, q if tick < switch else p1, by_tick.get(tick, []), t, dt))
        if tick % SNAPSHOT_EVERY == 0 or tick == ticks - 1:
            snaps.append({"tick": tick, "x": list(st_.x), "off": list(st_.off), "tgt": list(st_.tgt)})
    lock_x = list(st_.x)
    trip.lock(st_)
    # Presses after the bell: refused, and nothing moves.
    lock_answers = trip.step(st_, p1, [(lane - 1, d) for lane, d in after_lock], ticks * dt, dt)
    tr = trip.trip_values(st_)
    row = trip.baseline_row(baseline, course, distance)
    tau = trip.tau(tr, posts, row, cfg)
    # Lune's JSON reader can land a number one ulp off; Luau's tonumber is exact, so the inputs
    # that drive the lanes also go as exact decimal strings.
    exact = {"q": [repr(v) for v in q], "p1": [repr(v) for v in p1], "uniforms": [repr(v) for v in uniforms]}
    run = {"course": course, "distance": distance, "posts": posts, "kinds": kinds, "q": q, "p1": p1, "exact": exact,
           "switchTick": switch, "ticks": ticks, "uniforms": uniforms, "intents": intents, "answers": answers,
           "snapshots": snaps, "lockX": lock_x, "afterLock": after_lock, "afterLockAnswers": lock_answers,
           "ground": list(st_.ground), "draft": list(st_.draft), "trip": tr, "tau": tau,
           "stars": [trip.trip_stars(v, cfg) for v in tau]}
    if override:
        run["cfg"] = trip.config_record(cfg)
    return run


def trip_fixture(only=None):
    """Scripted phase-A runs for the Trip.luau parity test (S2). Lane indices in intents are
    1-based; x values are lane positions (1 = the rail). Each intent is [tick, lane, dir];
    several can share a tick (applied in list order). live = q before switchTick, p1 from it.
    After the lock, afterLock presses are stepped once (all "locked", nothing changes).
    Snapshots of x, off and tgt every SNAPSHOT_EVERY ticks and on the last tick. geometry
    holds each course and distance's gate and phase A for the TrackLayout check in run_all."""
    baseline = json.loads((ROOT / "tests" / "fixtures" / "trip_baseline.json").read_text())["baseline"]
    geometry = {c: {d: trip.phase_a(c, d) for d in trip.DISTANCE_ORDER} for c in trip.COURSE_ORDER}
    runs = [trip_run(k, baseline, geometry) for k in (only if only is not None else range(TRIP_RUNS))]
    geo_out = {c: {d: {key: geometry[c][d][key] for key in ("segments", "lockS", "turnLength", "length", "r1", "gate")}
                   for d in trip.DISTANCE_ORDER} for c in trip.COURSE_ORDER}
    finish = {c: trip.COURSES[c]["finishFromTop"] for c in trip.COURSE_ORDER}
    return {"cfg": trip.config_record(trip.CONFIG), "race": trip.RACE, "geometry": geo_out, "finishFromTop": finish,
            "distances": trip.DISTANCES, "baseline": baseline, "runs": runs}



# ---------------------------------------------------------------- D-057 (stage N1, for the N2 port)

TRIP_D057_RUNS = 100
D057_SNAPSHOT_EVERY = 10
# Runs k >= 8 cycle through these on top of the D-057 config, so every switch's other branch is
# replayed too.
D057_OVERRIDES = [None] * 8 + [
    {"brushPays": "both"}, {"brushPays": "bumped"}, {"gapWaitInSeconds": 3.0}, {"tuckAfterSeconds": 0.5},
    {"glide": "linear"}, {"brush": "off"}, {"scale": 0.5}, {"weaveGapSeconds": 0.0},
    {"laneSpeedMax": 1.667, "laneAccel": 5.56}, {"chainWindow": 0.0}, {"glideReserveFeet": 0.0},
    {"pressBounceSeconds": 0.0}, {"brushRepeatSeconds": 0.0}, {"blockedPress": "d054"}, {"gapWaitSeconds": 0.0},
    {"brushPays": "none"}, {"reverseGapSeconds": 0.0},
]
D057_STYLES = ("casual", "masher", "ditherer", "double", "bounce")


def _d057_cfg(override=None):
    cfg = trip.d057_config()
    for key, value in (override or {}).items():
        node = cfg
        parts = key.split(".")
        for part in parts[:-1]:
            node = node[part]
        node[parts[-1]] = value
    return cfg


def _d057_snapshot(st_, tick):
    """Everything the N2 port compares at a tick (the clocks included), plus the boxed-in view N4
    reads. boxed, noTuckInside and boxedNoTuck are trip.boxed_in, trip.no_tuck_inside and
    trip.boxed_no_tuck, worked out from the sides already found."""
    n = st_.n
    sides = [[trip.side_state(st_, i, -1), trip.side_state(st_, i, 1)] for i in range(n)]
    boxed = [sides[i][0] != "free" and sides[i][1] != "free" and trip.horse_ahead(st_, i, st_.cfg["boxedAheadFeet"])
             for i in range(n)]
    no_tuck = [st_.tgt[i] > 1 and sides[i][0] == "blocked" for i in range(n)]
    return {"tick": tick, "x": list(st_.x), "v": list(st_.v), "tgt": list(st_.tgt), "off": list(st_.off),
            "want": list(st_.want), "queued": list(st_.queued), "check": list(st_.check),
            "charged": list(st_.charged), "tucking": list(st_.tucking),
            "alongSince": [list(a) for a in st_.along_since], "steadyUntil": list(st_.steady_until),
            "firstPressAt": list(st_.first_press_at), "lastRevAt": list(st_.last_rev_at),
            "arrivedAt": list(st_.arrived_at), "manualAt": list(st_.manual_at),
            "sides": sides, "boxed": boxed, "noTuckInside": no_tuck,
            "boxedNoTuck": [boxed[i] and no_tuck[i] for i in range(n)]}


def _exact(value):
    """A config with every number as an exact decimal string (Lune's JSON reader can land a
    number one ulp off; Luau's tonumber is exact). Strings and booleans stay as they are."""
    if isinstance(value, (bool, str)):
        return value
    if isinstance(value, (int, float)):
        return repr(value)
    if isinstance(value, list):
        return [_exact(v) for v in value]
    return {k: _exact(v) for k, v in value.items()}


def _d057_play(course, distance, posts, kinds, q, p1, uniforms, switch, ticks, cfg, presses, after_lock, baseline,
               snap_every):
    """Runs one scripted phase A. presses(st, tick) -> this tick's [(lane index, dir)] (it may
    read the state, as the edge scripts do; the presses made are recorded, so a replay needs no
    script). After `ticks` ticks the bell rings (edge runs ring it early)."""
    geo = trip.phase_a(course, distance)
    st_ = trip.new_state(posts, q, uniforms, geo, cfg, kinds)
    dt = 1.0 / cfg["tickHz"]
    intents, answers, snaps, events = [], [], [], []
    for tick in range(ticks):
        now = presses(st_, tick)
        for lane, d in now:
            intents.append([tick, lane + 1, d])
        before = len(st_.events)
        answers.extend(trip.step(st_, q if tick < switch else p1, now, tick * dt, dt))
        for e in st_.events[before:]:
            events.append([tick, e[2] + 1, e[3] + 1, e[4]])
        if tick % snap_every == 0 or tick == ticks - 1:
            snaps.append(_d057_snapshot(st_, tick))
    lock_x = list(st_.x)
    trip.lock(st_)
    lock_answers = trip.step(st_, p1, [(lane - 1, d) for lane, d in after_lock], ticks * dt, dt)
    charges = trip.brush_charges(st_)
    tr = trip.trip_values(st_)
    tau = trip.tau(tr, posts, trip.baseline_row(baseline, course, distance), cfg, charges)
    exact = {"q": [repr(v) for v in q], "p1": [repr(v) for v in p1], "uniforms": [repr(v) for v in uniforms]}
    return {"course": course, "distance": distance, "posts": posts, "kinds": kinds, "q": q, "p1": p1, "exact": exact,
            "switchTick": switch, "ticks": ticks, "uniforms": uniforms, "intents": intents, "answers": answers,
            "snapEvery": snap_every, "snapshots": snaps, "lockX": lock_x, "afterLock": after_lock,
            "afterLockAnswers": lock_answers, "ground": list(st_.ground), "draft": list(st_.draft), "trip": tr,
            "brushes": list(st_.brushes), "charged": list(st_.charged), "charges": charges,
            "events": events,
            "tau": tau, "stars": [trip.trip_stars(v, cfg) for v in tau]}


def trip_d057_run(k, baseline, geometry):
    """One scripted phase-A run with D-057 on, from its own seed. Riders press in five styles,
    drawn per rider: casual (a press now and then), masher (4 a second, random side), ditherer
    (In, Out, In, Out every 0.2 s), double (a second press the same way 0.2-1.9 s after the
    first: brushes) and bounce (a second press 0-0.2 s after the first). The presses never read
    the state."""
    rng = random.Random(20261057 * 1000 + k)
    course = trip.COURSE_ORDER[k % 2]
    distance = trip.DISTANCE_ORDER[(k // 2) % 4]
    geo = geometry[course][distance]
    override = D057_OVERRIDES[k % len(D057_OVERRIDES)] if k >= 8 else None
    cfg = _d057_cfg(override)
    n = 8
    posts = list(range(1, n + 1))
    if k % 3 == 1:
        rng.shuffle(posts)
    kinds = [rng.choice(["bot", "bot", "smart", "manual", "manual"]) for _ in range(n)]
    mcfg = m.Config(T=rng.choice([22.0, 18.0, 14.4, 12.0]))
    ratings = [50 + rng.uniform(-8, 8) for _ in range(n)]
    q = m.base_chances(ratings, mcfg)
    p1 = m.live_chances(q, m.skills([rng.uniform(20, 100) for _ in range(n)], mcfg), mcfg)
    uniforms = [rng.random() for _ in range(2 * n)]
    dt = 1.0 / cfg["tickHz"]
    ticks = 0
    while ticks * dt < trip.lock_time(geo) - trip.EPS:
        ticks += 1
    switch = rng.randrange(ticks // 4, ticks)
    steerers = [i for i in range(n) if kinds[i] != "bot"] or [0]
    styles = [rng.choice(D057_STYLES) for _ in steerers]
    rate = rng.choice([0.01, 0.03, 0.1])
    by_tick = {}
    for i, style in zip(steerers, styles):
        flip = rng.choice((-1, 1))
        phase = rng.randrange(2)
        for tick in range(ticks):
            if style == "casual":
                if rng.random() < rate:
                    roll = rng.random()
                    d = -1 if roll < 0.6 else (1 if roll < 0.97 else rng.choice([0, 2]))
                    by_tick.setdefault(tick, []).append((i, d))
            elif style == "masher":
                if rng.random() < 0.4:
                    by_tick.setdefault(tick, []).append((i, -1 if rng.random() < 0.5 else 1))
            elif style == "ditherer":
                if tick % 2 == phase:
                    flip = -flip
                    by_tick.setdefault(tick, []).append((i, flip))
            elif rng.random() < 0.03:
                d = -1 if rng.random() < 0.6 else 1
                later = tick + (rng.randint(2, 19) if style == "double" else rng.choice([0, 1, 2]))
                by_tick.setdefault(tick, []).append((i, d))
                if later < ticks:
                    by_tick.setdefault(later, []).append((i, d))
    after_lock = [[rng.randrange(n) + 1, rng.choice([-1, 1])] for _ in range(rng.choice([1, 2, 3]))]
    run = _d057_play(course, distance, posts, kinds, q, p1, uniforms, switch, ticks, cfg,
                     lambda _st, tick: by_tick.get(tick, []), after_lock, baseline, D057_SNAPSHOT_EVERY)
    run["styles"] = [[i + 1, style] for i, style in zip(steerers, styles)]
    if override:
        run["cfg"] = cfg
        run["cfgExact"] = _exact(cfg)
    return run


def _at(script):
    """A press script from {tick: [(lane index, dir), ...]}."""
    return lambda _st, tick: script.get(tick, [])


def _edge(name, posts, kinds, live, presses, ticks, after_lock, baseline, course="dirt", distance="Classic",
          live_after=None, switch=None, cfg=None):
    n = len(posts)
    run = _d057_play(course, distance, posts, kinds, list(live), list(live_after or live), [0.5] * (2 * n),
                     switch if switch is not None else ticks, ticks, cfg or _d057_cfg(), presses, after_lock,
                     baseline, 1)
    run["name"] = name
    if cfg is not None:
        run["cfg"] = cfg
        run["cfgExact"] = _exact(cfg)
    return run


def _grace_script():
    """Edge "grace": horse 2 closes up on horse 1's outside from behind. Horse 1 presses Out
    once that lane has no room but horse 2 isn't alongside yet, again the tick after horse 2
    comes alongside (inside brushGraceSeconds: no brush, the press queues) and again 0.4 s
    after it came alongside (a brush)."""
    marks = {}

    def presses(st_, tick):
        if tick < 100:
            return []
        if "first" not in marks and trip.side_state(st_, 0, 1) == "blocked" and st_.along_since[0][1] == trip.NOT_ALONG:
            marks["first"] = tick
            return [(0, 1)]
        if "first" in marks and "along" not in marks and st_.along_since[0][1] != trip.NOT_ALONG:
            marks["along"] = tick - 1  # it came alongside on the tick before
        if "along" in marks and tick in (marks["along"] + 1, marks["along"] + 4):
            return [(0, 1)]
        return []
    return presses


def trip_d057_edges(baseline):
    """Hand-built runs, one per D-057 rule edge (fixed lives, everyone "manual" unless noted;
    the bell rings after `ticks`). Snapshots every tick."""
    one = [1.0]
    return [
        # Four lanes chained: one press each, the next while the glide is under way.
        _edge("chain", [5], ["manual"], one, _at({100: [(0, -1)], 103: [(0, -1)], 109: [(0, -1)], 115: [(0, -1)]}),
              150, [[1, -1]], baseline),
        # In; Out during the glide (queued until 0.5 s after landing); In within 5 s of that
        # reversal (a second reversal: 2.5 s after landing); Out again (the weave gap again).
        _edge("reverse-weave", [4], ["manual"], one,
              _at({100: [(0, -1)], 103: [(0, 1)], 126: [(0, -1)], 152: [(0, 1)]}), 230, [[1, 1]], baseline),
        # Same tick, 0.1 s (bounces) and 0.2 s (counts); an opposite press cancels; 0.1 s later
        # the same way (bounce); an opposite press 0.1 s later (not a bounce).
        _edge("bounce", [5], ["manual"], one,
              _at({100: [(0, -1), (0, -1)], 101: [(0, -1)], 102: [(0, -1)], 110: [(0, 1)], 111: [(0, 1)],
                   140: [(0, 1)], 141: [(0, -1)], 160: [(0, -1)]}), 190, [[1, -1]], baseline),
        # Lane 3 (horse 2) boxed: horse 1 11 ft ahead in its lane, horses alongside in lanes 2
        # and 4. Out waits 1.5 s and drops; In tucks back and slips in behind; a second In while
        # tucking never brushes.
        _edge("boxed-both-sides", [3, 3, 2, 4], ["manual"] * 4, [0.25 + 11 / 320, 0.25, 0.25, 0.25],
              _at({110: [(1, 1)], 130: [(1, -1)], 132: [(1, -1)]}), 200, [[2, -1], [3, 1]], baseline),
        # Lane 3 (horse 2) boxed with no tuck slot inside: a line of four in lane 2 (no slot within
        # tuckBackMax), horse 1 ahead, horse 7 outside. Pairs of In presses: brushes 1 (free),
        # 2, 3, 4 (charged up to the cap); a fifth pair just waits (the cap). Presses while
        # steadying answer "steady". After the bell: nothing.
        _edge("trapped-brush-cap", [3, 3, 2, 2, 2, 2, 4], ["manual"] * 7, [1 / 7 + 11 / 320] + [1 / 7] * 6,
              _at({110: [(1, -1)], 115: [(1, -1)], 118: [(1, -1)], 130: [(1, -1)], 135: [(1, -1)], 150: [(1, -1)],
                   152: [(1, -1)], 170: [(1, -1)], 172: [(1, -1)], 190: [(1, -1)], 192: [(1, -1)], 194: [(1, 1)],
                   196: [(1, 1)]}),
              220, [[2, -1], [2, -1], [7, -1]], baseline),
        # The same box: a second In 2.1 s after the first is outside brushRepeatSeconds (it queues),
        # two Outs cancel both, then a fresh pair 1.8 s apart brushes.
        _edge("brush-window", [3, 3, 2, 2, 2, 2, 4], ["manual"] * 7, [1 / 7 + 11 / 320] + [1 / 7] * 6,
              _at({110: [(1, -1)], 131: [(1, -1)], 133: [(1, 1)], 135: [(1, 1)], 140: [(1, -1)], 158: [(1, -1)]}),
              180, [[2, -1]], baseline),
        # The window starts when the waiting press was pressed, even if it queued: horse 1 glides
        # In from lane 4 (10.0 s), presses Out mid-glide (10.5 s, queued for the reverse gap),
        # finds horse 2 alongside in lane 4 when it may move (11.5 s) and presses Out again at
        # 12.2 s: a brush, 1.7 s after the queued press (2.2 s after the accepted one).
        _edge("brush-window-queued", [4, 4], ["manual", "manual"], [0.5, 0.5 - 28 / 320],
              _at({100: [(0, -1)], 105: [(0, 1)], 122: [(0, 1)]}), 150, [[1, 1]], baseline,
              live_after=[0.5, 0.5], switch=95),
        # Out into a horse closing from behind: no brush within brushGraceSeconds of it coming
        # alongside, a brush after.
        _edge("grace", [3, 4], ["manual", "manual"], [0.5, 0.5 - 40 / 320], _grace_script(), 160, [[1, 1]], baseline,
              live_after=[0.5, 0.5], switch=95),
        # Glide reserve: horse 1 glides out into lane 3; horse 2, 12 ft behind it in lane 4,
        # presses In: no room while horse 1 glides (14 ft ahead with the reserve), room once it lands.
        _edge("reserve", [2, 4], ["manual", "manual"], [0.5, 0.5 - 12 / 320],
              _at({100: [(0, 1)], 102: [(1, -1)]}), 140, [[2, -1]], baseline),
        # Smart Steer trapped heading in (the line in lane 2 has formed before its turn lead,
        # 8 s before the clubhouse turn): it waits for room, never drops, never brushes.
        _edge("smart-trapped", [3, 2, 2, 2, 2], ["smart"] + ["manual"] * 4, [0.2] * 5, _at({}), 220, [[1, -1]],
              baseline),
        # Outward press into a horse alongside, pressed again within 2 s: a brush (outward never
        # tucks back); with brushPays = "bumped" the other horse pays and steadies back instead.
        _edge("brush-out-bumped-pays", [3, 4], ["manual", "manual"], [0.5, 0.5],
              _at({100: [(0, 1)], 105: [(0, 1)], 108: [(0, 1)]}), 140, [[1, 1]], baseline,
              cfg=_d057_cfg({"brushPays": "bumped"})),
        # An inward press that can't tuck back drops after gapWaitInSeconds when that isn't 0.
        _edge("trapped-drop", [3, 2, 2, 2, 2], ["manual"] * 5, [0.2] * 5, _at({100: [(0, -1)]}), 150, [[1, -1]],
              baseline, cfg=_d057_cfg({"gapWaitInSeconds": 3.0})),
    ]


def trip_d057_fixture(only=None):
    """D-057 (stage N1) parity runs for the N2 Luau port: TRIP_D057_RUNS scripted phase-A runs
    on the D-057 config (masher, ditherer, double-press and bounce riders; runs k >= 8 cycle
    D057_OVERRIDES), plus hand-built edge runs (`edges`, one per rule edge, snapshots every
    tick). Same conventions as trip.json: 1-based lanes in intents ([tick, lane, dir]), live =
    q before switchTick and p1 from it, exact decimal strings for the lanes' inputs, presses
    after the bell all "locked". Snapshots add v, want, queued, check, charged, tucking, the
    clocks (alongSince, steadyUntil, firstPressAt, lastRevAt, arrivedAt, manualAt), each side's
    state ("free", "tuck", "blocked"), boxed, noTuckInside and boxedNoTuck. Results add brushes,
    charged, charges (brush_charge), events ([tick, mover, other, dir], 1-based) and tau with the
    brush term. cfg = the D-057 config; defaults = trip.CONFIG with every key (D-054 values),
    what GameConfig.steering holds until N3; a run with other settings carries its whole cfg.
    Each config also comes as exact decimal strings (cfgExact, defaultsExact)."""
    baseline = json.loads((ROOT / "tests" / "fixtures" / "trip_baseline.json").read_text())["baseline"]
    geometry = {c: {d: trip.phase_a(c, d) for d in trip.DISTANCE_ORDER} for c in trip.COURSE_ORDER}
    runs = [trip_d057_run(k, baseline, geometry) for k in (only if only is not None else range(TRIP_D057_RUNS))]
    return {"cfg": trip.d057_config(), "cfgExact": _exact(trip.d057_config()), "defaults": trip.CONFIG,
            "defaultsExact": _exact(trip.CONFIG), "race": trip.RACE, "baseline": baseline, "runs": runs,
            "edges": trip_d057_edges(baseline)}


if __name__ == "__main__":
    main()
