#!/usr/bin/env python3
"""Generate Python reference fixtures for the Luau parity tests.

Writes tests/fixtures/race_math.json and tests/fixtures/trip.json. Deterministic (fixed
seeds). race_math.json is append-only: new sections draw from their own generators, so the
original sections stay byte-for-byte the same.
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
SNAPSHOT_EVERY = 50  # ticks (5 s)


class ListRng:
    """Replays a fixed list of uniforms, like the Luau test stub."""

    def __init__(self, values):
        self.values = list(values)
        self.i = 0

    def random(self):
        v = self.values[self.i]
        self.i += 1
        return v


def main() -> None:
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
        pace_cases.append({"spec": spec, "start": start, "duration": duration, "uniforms": uniforms,
                           "passes": [p._asdict() for p in passes], "taps": taps, "score": mean, "errors": errs,
                           "single": single})
    out = ROOT / "tests" / "fixtures" / "race_math.json"
    out.write_text(json.dumps({"cases": cases, "windows": windows, "ratings": ratings_cases, "stride": stride_cases,
                               "pace": pace_cases, "extraCases": extra_cases()}))
    print(f"wrote {len(cases)} cases to {out.relative_to(ROOT)}")
    trip_out = ROOT / "tests" / "fixtures" / "trip.json"
    trip_out.write_text(json.dumps(trip_fixture()))
    print(f"wrote {TRIP_RUNS} trip runs to {trip_out.relative_to(ROOT)}")


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


def trip_fixture():
    """Scripted phase-A runs for the Trip.luau parity test (S2). Lane indices in intents are
    1-based; x values are lane positions (1 = the rail). Each intent is [tick, lane, dir];
    several can share a tick (applied in list order). live = q before switchTick, p1 from it."""
    rng = random.Random(20261007)
    baseline = json.loads((ROOT / "tests" / "fixtures" / "trip_baseline.json").read_text())["baseline"]
    geometry = {c: {d: trip.phase_a(c, d) for d in trip.DISTANCE_ORDER} for c in trip.COURSE_ORDER}
    overrides = [None] * 8 + [{"scale": 0.5}, {"enabled": False}, {"maxQueued": 0}, {"smart.homeLane": 1},
                              {"scale": 0.0}, {"gapRampSeconds": 0.0}]
    runs = []
    for k in range(TRIP_RUNS):
        course = trip.COURSE_ORDER[k % 2]
        distance = trip.DISTANCE_ORDER[(k // 2) % 4]
        geo = geometry[course][distance]
        cfg = trip.CONFIG
        override = overrides[k % len(overrides)] if k >= 8 else None
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
        tr = trip.trip_values(st_)
        row = trip.baseline_row(baseline, course, distance)
        tau = trip.tau(tr, posts, row, cfg)
        run = {"course": course, "distance": distance, "posts": posts, "kinds": kinds, "q": q, "p1": p1,
               "switchTick": switch, "ticks": ticks, "uniforms": uniforms, "intents": intents, "answers": answers,
               "snapshots": snaps, "lockX": lock_x, "ground": list(st_.ground), "draft": list(st_.draft),
               "trip": tr, "tau": tau, "stars": [trip.trip_stars(v, cfg) for v in tau]}
        if override:
            run["cfg"] = cfg
        runs.append(run)
    geo_out = {c: {d: {"segments": geometry[c][d]["segments"], "lockS": geometry[c][d]["lockS"],
                       "turnLength": geometry[c][d]["turnLength"], "length": geometry[c][d]["length"]}
                   for d in trip.DISTANCE_ORDER} for c in trip.COURSE_ORDER}
    return {"cfg": trip.CONFIG, "race": trip.RACE, "geometry": geo_out, "baseline": baseline, "runs": runs}


if __name__ == "__main__":
    main()
