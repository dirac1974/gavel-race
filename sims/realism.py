#!/usr/bin/env python3
"""Race realism phase A gates (D-072): the race outcome with Trip's tau in it, before and after.

    python sims/realism.py                 # default sizes, prints the before/after tables
    python sims/realism.py --races 500     # quicker

"before" is the game before D-072 (trip.d057_config() with tests/fixtures/trip_baseline_d057.json);
"after" is trip.CONFIG with tests/fixtures/trip_baseline.json (posts and styles). Every race is the
same draw in both (same ratings, scores, posts and Trip uniforms), so the differences are paired.

- Solo win rate by kid (Rookie: dirt and turf, Sprint and Mile): one Smart Steer rider on a fresh
  starter (economy.FRESH_RATING) among seven bots rated the Rookie anchor +- 6 (economy.PHASE3), the
  economy's segment model (pace, pace, burst x2, pace), live = q until the first checkpoint and p1
  from it in Trip; the result is the live win chance with tau in the exponent. Cash per race is the
  expected purse (economy: a win pays B / q, 2nd-4th B x PLACE_PRIZES; Harville places).
- Upsets: eight bots rated 70..52 (gavel_race_v2.RATINGS), scores N(50, 15), T 22 / 18 / 14.4:
  the expected share of wins by the bottom half and by the longest shot.
- Boxed share, a Python stand-in for the D-071 harness (Rookie Mile, four riders on equal horses
  at the anchor tapping perfect / average / masher / streaky among four bots): of the pre-lock
  ticks where a rider's previewed taps want at least 4 ft (heldCue.minFeet) more, the share where
  the horse ahead in its lane leaves less than that much room. The preview's aim is the rider's own
  checkpoint-1 gain growing in over the segment (TapPreview's goal, without its lane-join slack).
  The D-071 Luau report gives the shipped figure once Trip.luau is ported.
- Passes per race (Trip's pass rule, completed) and drawn overtakes, from the same Rookie fields.
"""

from __future__ import annotations

import argparse
import json
import math
import os
import random
import sys
import time
from multiprocessing import Pool
from pathlib import Path
from typing import Dict, List, Sequence, Tuple

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))
sys.path.insert(0, str(ROOT / "sims"))

import gavel_race_v2 as m  # noqa: E402
import trip  # noqa: E402
import economy as eco  # noqa: E402

SEED = 20261012
LANES = 8
ROOKIE_CELLS = (("dirt", "Sprint"), ("dirt", "Mile"), ("turf", "Sprint"), ("turf", "Mile"))
KIDS = ("new", "average", "perfect")
UPSET_T = (22.0, 18.0, 14.4)
TAP_PROFILES = {"perfect": (97.0, 3.0), "average": (70.0, 10.0), "masher": (15.0, 10.0), "streaky": (80.0, 15.0)}
HELD_MIN = 4.0          # GameConfig.tapPreview.heldCue.minFeet
PREVIEW_CAP = 12.0      # tapPreview.capFeet
PREVIEW_BACK = 6.0      # tapPreview.capBackFeet


def configs() -> Dict[str, Tuple[Dict, Dict, Dict]]:
    """name -> (trip config, per-post baseline table, per-style table or {})."""
    before = json.loads((ROOT / "tests" / "fixtures" / "trip_baseline_d057.json").read_text())
    after = json.loads((ROOT / "tests" / "fixtures" / "trip_baseline.json").read_text())
    cfg = trip.CONFIG
    trial = os.environ.get("REALISM_SET")  # a trial: {"pass.riderTriggerFeet": 6, ...} on the after config
    if trial:
        cfg = json.loads(json.dumps(cfg))
        for key, value in json.loads(trial).items():
            node = cfg
            parts = key.split(".")
            for part in parts[:-1]:
                node = node[part]
            node[parts[-1]] = value
    return {"before": (trip.d057_config(), before["baseline"], {}),
            "after": (cfg, after["baseline"], after.get("styles", {}))}


def switch_tick(geo: Dict, cfg: Dict) -> int:
    t_top = (geo["length"] - trip.COURSES[geo["course"]]["finishFromTop"]) / trip.RACE["speed"]
    return int(math.ceil(((t_top - 1.0) / 2 + 0.35) * cfg["tickHz"]))


def run_trip(geo: Dict, posts: List[int], q: List[float], p1: List[float], uniforms: List[float], kinds: List[str],
             cfg: Dict, row: Sequence[float], srow: Sequence[float], aims: Dict[int, float] = None) -> Dict:
    """One phase A; returns tau, pass counts and (with aims = {lane: feet at the switch}) the
    boxed-share samples."""
    uni = uniforms if trip.d072_on(cfg) else uniforms[:2 * LANES]
    st = trip.new_state(posts, q, uni, geo, cfg, kinds)
    dt = 1.0 / cfg["tickHz"]
    sw = switch_tick(geo, cfg)
    t_lock = trip.lock_time(geo)
    aim_n = held_n = 0
    tick = 0
    while tick * dt < t_lock - trip.EPS:
        t = tick * dt
        trip.step(st, q if tick < sw else p1, [], t, dt)
        if aims:
            for i, full in aims.items():
                aim = full * min(1.0, (tick + 1) / sw) if tick < sw else 0.0
                aim = max(-PREVIEW_BACK, min(PREVIEW_CAP, aim * min(1.0, t / cfg["gapRampSeconds"])))
                if aim < HELD_MIN:
                    continue
                aim_n += 1
                room = math.inf
                for j in range(LANES):
                    if j != i and abs(st.x[j] - st.x[i]) < cfg["laneBand"] and st.off[j] > st.off[i]:
                        room = min(room, st.off[j] - cfg["holdGap"] - st.off[i])
                if aim - max(0.0, room) >= HELD_MIN:
                    held_n += 1
        tick += 1
    trip.lock(st)
    style = None
    if trip.d072_on(cfg) and srow:
        style = trip.style_baseline(st, srow)
    tau = trip.tau(trip.trip_values(st), posts, row, cfg, trip.brush_charges(st), style)
    ev = st.pack_events
    return {"tau": tau, "passes": sum(1 for e in ev if e[1] == "pass"),
            "passes_straight": sum(1 for e in ev if e[1] == "pass" and e[4] == 0),
            "outs": sum(1 for e in ev if e[1] == "out"), "shuts": sum(1 for e in ev if e[1] == "shut"),
            "aim": aim_n, "held": held_n}


def harville_places(p: Sequence[float], k: int, top: int = 4) -> List[float]:
    """P(lane k finishes 1st..top-th) under Harville."""
    n = len(p)
    out = [p[k]]
    # place 2..top: sum over ordered sets of others ahead
    def rec(depth: int, used: List[int], prob: float, rest: float) -> None:
        if depth == len(out_targets):
            return
        for j in range(n):
            if j == k or j in used:
                continue
            pj = prob * p[j] / rest
            r2 = rest - p[j]
            out_targets[depth] += pj * p[k] / r2
            rec(depth + 1, used + [j], pj, r2)
    out_targets = [0.0] * (top - 1)
    rec(0, [], 1.0, 1.0)
    return out + out_targets


def _solo_chunk(args) -> List[Dict]:
    cell, k0, k1 = args
    course, distance = ROOKIE_CELLS[cell]
    geo = trip.phase_a(course, distance)
    cfgs = configs()
    anchor = eco.PHASE3["anchors"]["Rookie"]
    mcfg = m.Config(T=eco.T["Rookie"])
    B = eco.LEAGUE_B["Rookie"]
    out = []
    for k in range(k0, k1):
        rng = random.Random((SEED * 8 + cell) * 1_000_000 + k)
        kid = rng.randrange(LANES)
        ratings = [anchor + (rng.random() * 2 - 1) * eco.BOT_RATING_SPREAD for _ in range(LANES)]
        ratings[kid] = eco.FRESH_RATING
        q = m.base_chances(ratings, mcfg)
        bot_seg = [[eco._clamp(rng.gauss(*(eco.BOT_BURST if s == "burst" else eco.BOT_PACE))) for s in eco.SEGMENTS]
                   for _ in range(LANES)]
        kid_z = [rng.gauss(0, 1) for _ in eco.SEGMENTS]
        posts = list(range(1, LANES + 1))
        rng.shuffle(posts)
        uniforms = [rng.random() for _ in range((2 + trip.D072_UNIFORMS) * LANES)]
        kinds = ["bot"] * LANES
        kinds[kid] = "smart"
        rec: Dict = {}
        for kname in KIDS:
            pace, burst = eco.KIDS[kname]
            seg = [list(s) for s in bot_seg]
            seg[kid] = [eco._clamp((burst if s == "burst" else pace) + z * (20 if s == "burst" else 10))
                        for s, z in zip(eco.SEGMENTS, kid_z)]
            S = [sum(w * x for w, x in zip(eco.SEGMENT_WEIGHTS, s)) / sum(eco.SEGMENT_WEIGHTS) for s in seg]
            p1 = m.live_chances(q, m.skills([s[0] for s in seg], mcfg), mcfg)
            R = m.skills(S, mcfg)
            for name, (cfg, table, stable) in cfgs.items():
                res = run_trip(geo, posts, q, p1, uniforms, kinds, cfg, table[course][distance],
                               stable.get(course, {}).get(distance) if stable else None)
                p = m.live_chances(q, R, mcfg, res["tau"])
                pl = harville_places(p, kid)
                cash = pl[0] * math.floor(B / q[kid] + 0.5) + sum(pl[i + 1] * round(B * eco.PLACE_PRIZES[i])
                                                                   for i in range(3))
                rec[(kname, name)] = (p[kid], cash, res["tau"][kid])
        out.append(rec)
    return out


def _upset_chunk(args) -> List[Dict]:
    cell, k0, k1 = args
    course, distance = trip.COURSE_ORDER[cell // 4], trip.DISTANCE_ORDER[cell % 4]
    geo = trip.phase_a(course, distance)
    cfgs = configs()
    out = []
    for k in range(k0, k1):
        rng = random.Random((SEED * 16 + 8 + cell) * 1_000_000 + k)
        T = UPSET_T[k % len(UPSET_T)]
        mcfg = m.Config(T=T)
        q = m.base_chances(m.RATINGS, mcfg)
        S = [rng.gauss(50, 15) for _ in range(LANES)]
        p1 = m.live_chances(q, m.skills(S, mcfg), mcfg)
        posts = list(range(1, LANES + 1))
        rng.shuffle(posts)
        uniforms = [rng.random() for _ in range((2 + trip.D072_UNIFORMS) * LANES)]
        rec = {"T": T}
        for name, (cfg, table, stable) in cfgs.items():
            res = run_trip(geo, posts, q, p1, uniforms, ["bot"] * LANES, cfg, table[course][distance],
                           stable.get(course, {}).get(distance) if stable else None)
            p = m.live_chances(q, m.skills(S, mcfg), mcfg, res["tau"])
            rec[name] = (sum(p[4:]), p[7], res["passes"], res["passes_straight"], res["outs"], res["shuts"])
        out.append(rec)
    return out


def _boxed_chunk(args) -> List[Dict]:
    course, k0, k1 = args
    geo = trip.phase_a(course, "Mile")
    cfgs = configs()
    anchor = eco.PHASE3["anchors"]["Rookie"]
    mcfg = m.Config(T=eco.T["Rookie"])
    out = []
    for k in range(k0, k1):
        rng = random.Random((SEED * 4 + (0 if course == "dirt" else 1)) * 1_000_000 + k)
        lanes = list(range(LANES))
        rng.shuffle(lanes)
        riders = lanes[:4]
        ratings = [anchor + (rng.random() * 2 - 1) * eco.BOT_RATING_SPREAD for _ in range(LANES)]
        for i in riders:
            ratings[i] = anchor
        q = m.base_chances(ratings, mcfg)
        s1 = [eco._clamp(rng.gauss(*eco.BOT_PACE)) for _ in range(LANES)]
        for i, prof in zip(riders, TAP_PROFILES):
            mu, sd = TAP_PROFILES[prof]
            s1[i] = eco._clamp(rng.gauss(mu, sd))
        p1 = m.live_chances(q, m.skills(s1, mcfg), mcfg)
        posts = list(range(1, LANES + 1))
        rng.shuffle(posts)
        uniforms = [rng.random() for _ in range((2 + trip.D072_UNIFORMS) * LANES)]
        kinds = ["bot"] * LANES
        for i in riders:
            kinds[i] = "smart"
        aims = {i: trip.RACE["leadFeetPerShare"] * (p1[i] - q[i]) for i in riders}
        rec = {}
        for name, (cfg, table, stable) in cfgs.items():
            res = run_trip(geo, posts, q, p1, uniforms, kinds, cfg, table[course]["Mile"],
                           stable.get(course, {}).get("Mile") if stable else None, aims)
            rec[name] = (res["aim"], res["held"], res["passes"], res["passes_straight"])
        out.append(rec)
    return out


def _chunks(total: int, size: int) -> List[Tuple[int, int]]:
    return [(a, min(total, a + size)) for a in range(0, total, size)]


def mean(v: Sequence[float]) -> float:
    return sum(v) / len(v) if v else float("nan")


def run(races: int, upset_races: int, boxed_races: int, jobs=None) -> Dict:
    with Pool(jobs) as pool:
        solo = [r for part in pool.map(_solo_chunk, [(c, a, b) for c in range(len(ROOKIE_CELLS))
                                                     for a, b in _chunks(races, 25)]) for r in part]
        ups = [r for part in pool.map(_upset_chunk, [(c, a, b) for c in range(8)
                                                     for a, b in _chunks(upset_races, 25)]) for r in part]
        box = [r for part in pool.map(_boxed_chunk, [(c, a, b) for c in ("dirt", "turf")
                                                     for a, b in _chunks(boxed_races, 10)]) for r in part]
    out: Dict = {"races": races, "upsetRaces": upset_races, "boxedRaces": boxed_races, "solo": {}, "upsets": {},
                 "boxed": {}, "passes": {}}
    for kname in KIDS:
        row = {}
        for name in ("before", "after"):
            row[name] = {"win": mean([r[(kname, name)][0] for r in solo]),
                         "cash": mean([r[(kname, name)][1] for r in solo]),
                         "tau": mean([r[(kname, name)][2] for r in solo])}
        d = [r[(kname, "after")][0] - r[(kname, "before")][0] for r in solo]
        sd = math.sqrt(sum((x - mean(d)) ** 2 for x in d) / max(1, len(d) - 1))
        row["win_change"], row["win_change_se"] = mean(d), sd / math.sqrt(len(d))
        row["cash_change"] = row["after"]["cash"] / row["before"]["cash"] - 1
        out["solo"][kname] = row
    for T in UPSET_T + ("all",):
        rs = [r for r in ups if T == "all" or r["T"] == T]
        out["upsets"][str(T)] = {name: {"bottom": mean([r[name][0] for r in rs]), "longest": mean([r[name][1] for r in rs])}
                                 for name in ("before", "after")}
    for name in ("before", "after"):
        aim = sum(r[name][0] for r in box)
        held = sum(r[name][1] for r in box)
        out["boxed"][name] = held / aim if aim else 0.0
        out["passes"][name] = {
            "rookie_mile": mean([r[name][2] for r in box]),
            "rookie_mile_straight": sum(r[name][3] for r in box) / max(1, sum(r[name][2] for r in box)),
            "bot_fields": mean([r[name][2] for r in ups]),
            "bot_fields_straight": sum(r[name][3] for r in ups) / max(1, sum(r[name][2] for r in ups)),
            "outs": mean([r[name][4] for r in ups]), "shuts": mean([r[name][5] for r in ups])}
    return out


def format_md(o: Dict) -> str:
    L = []
    L.append(f"Solo Rookie win rate (fresh starter, {o['races'] * len(ROOKIE_CELLS):,} races per kid, paired):")
    L.append("| Kid | Before | After | Change (pts, +-2 SE) | Cash/race before | after | change |")
    L.append("| --- | --- | --- | --- | --- | --- | --- |")
    for k, r in o["solo"].items():
        L.append(f"| {k} | {r['before']['win']:.2%} | {r['after']['win']:.2%} | {100 * r['win_change']:+.2f} "
                 f"(+-{200 * r['win_change_se']:.2f}) | {r['before']['cash']:.2f} | {r['after']['cash']:.2f} "
                 f"| {r['cash_change']:+.2%} |")
    L.append("")
    L.append(f"Upsets (bots 70..52, S ~ N(50,15), {o['upsetRaces'] * 8:,} races):")
    L.append("| T | Bottom-half wins before | after | Longest shot before | after |")
    L.append("| --- | --- | --- | --- | --- |")
    for T, r in o["upsets"].items():
        L.append(f"| {T} | {r['before']['bottom']:.2%} | {r['after']['bottom']:.2%} | {r['before']['longest']:.2%} "
                 f"| {r['after']['longest']:.2%} |")
    L.append("")
    L.append(f"Boxed share (Python stand-in, Rookie Mile, {2 * o['boxedRaces']} races): before "
             f"{o['boxed']['before']:.1%}, after {o['boxed']['after']:.1%}")
    for name in ("before", "after"):
        p = o["passes"][name]
        L.append(f"Passes per race {name}: Rookie Mile {p['rookie_mile']:.2f} ({p['rookie_mile_straight']:.0%} on straights); "
                 f"bot fields, every course and distance {p['bot_fields']:.2f} ({p['bot_fields_straight']:.0%}); "
                 f"moves out {p['outs']:.2f}; shut doors {p['shuts']:.2f}")
    return "\n".join(L)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Race realism phase A gates (D-072)")
    ap.add_argument("--races", type=int, default=2000, help="solo races per Rookie course x distance")
    ap.add_argument("--upset-races", type=int, default=500, help="upset races per course x distance")
    ap.add_argument("--boxed-races", type=int, default=200, help="boxed-share Rookie Mile races per course")
    ap.add_argument("--jobs", type=int, default=0)
    ap.add_argument("--json", type=str, default="")
    args = ap.parse_args(argv)
    t0 = time.time()
    o = run(args.races, args.upset_races, args.boxed_races, args.jobs or None)
    print(format_md(o))
    print(f"({time.time() - t0:.0f} s)")
    if args.json:
        Path(args.json).write_text(json.dumps(o, indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
