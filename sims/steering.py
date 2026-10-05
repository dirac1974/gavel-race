#!/usr/bin/env python3
"""Race steering calibration (D-054): the per-post trip baseline and the acceptance report.

    python sims/steering.py                  # report, using the checked-in baseline
    python sims/steering.py --write          # regenerate the baseline files, then report
    python sims/steering.py --races 2000 --report-races 600 --jobs 8

--write regenerates tests/fixtures/trip_baseline.json and game/src/shared/TripBaseline.luau
from a fixed seed: BASELINE_RACES bot-mix races per course x distance, so every post gets
that many samples. Every race has its own seed, so the result never depends on --jobs.

Policies (one focal rider among seven bots, the same race replayed for each policy):
  smart     Smart Steer on, never touches the arrows (the default rider)
  bot       a bot: Smart Steer with variety (turn lead 4-12 s; 25% ride the rail, 20% one lane wider)
  rail      a skilled steerer: presses In every 0.3 s until on the rail
  never     Smart Steer off and never steers (stays in its post lane)
  wanderer  presses a random arrow about every 3 s
  scripted  a casual human: In about every 5 s, Out about every 20 s (Smart Steer on)
"""

from __future__ import annotations

import argparse
import json
import math
import random
import sys
import time
from multiprocessing import Pool
from pathlib import Path
from typing import Dict, List, Optional, Sequence, Tuple

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))

import gavel_race_v2 as m  # noqa: E402
import trip  # noqa: E402

SEED = 20261005
REPORT_SEED = 20261006
BASELINE_RACES = 2000
REPORT_RACES = 600
PROBE_RACES = 12          # the first races of each cell, stored for the regeneration test
CALIBRATION_PASSES = 4
LANES = 8
BASELINE_JSON = ROOT / "tests" / "fixtures" / "trip_baseline.json"
BASELINE_LUAU = ROOT / "game" / "src" / "shared" / "TripBaseline.luau"

# League temperatures that run each distance (GameConfig.leagues: Rookie runs Sprint and
# Mile, Bronze adds the Classic, Silver and up run everything).
LEAGUE_T = {
    "Sprint": (22.0, 18.0, 18.0, 14.4, 12.0),
    "Mile": (22.0, 18.0, 18.0, 14.4, 12.0),
    "Classic": (18.0, 18.0, 14.4, 12.0),
    "Marathon": (18.0, 14.4, 12.0),
}
BOT_RATING_SPREAD = 6.0           # GameConfig.botRatingSpread
PACE_MEAN, PACE_SD = 60.0, 15.0   # GameConfig.botPaceMean / botPaceSd
LATENCY_GRACE = 0.35              # RaceService: a checkpoint closes this long after its passes

POLICIES = ("smart", "rail", "never", "wanderer", "scripted")
KIND = {"bot": "bot", "smart": "smart", "rail": "smart", "never": "manual", "wanderer": "smart", "scripted": "smart"}

TARGETS = {
    "rail_vs_smart": (0.01, 0.03),
    "never": (-0.02, -0.01),
    "reach3s": 0.70,
    "draft_share": 0.40,
    "post_bias": 0.005,
    "smart_mean": 0.003,
}


def cells() -> List[Tuple[str, str]]:
    return [(c, d) for c in trip.COURSE_ORDER for d in trip.DISTANCE_ORDER]


def race_seed(base: int, cell: int, k: int) -> int:
    return (base * 16 + cell) * 1_000_000 + k


# ---------------------------------------------------------------- one race

def race_setup(seed: int, distance: str) -> Dict:
    """Ratings around a median, base chances, first-checkpoint scores, bot variety
    uniforms, the focal lane and a separate stream for the riders' presses."""
    rng = random.Random(seed)
    T = rng.choice(LEAGUE_T[distance])
    ratings = [50.0 + rng.uniform(-BOT_RATING_SPREAD, BOT_RATING_SPREAD) for _ in range(LANES)]
    mcfg = m.Config(T=T, q_floor=0.025, kappa=1.0, r_floor=-0.5, B=20)
    q = m.base_chances(ratings, mcfg)
    s1 = [min(100.0, max(0.0, rng.gauss(PACE_MEAN, PACE_SD))) for _ in range(LANES)]
    p1 = m.live_chances(q, m.skills(s1, mcfg), mcfg)
    uniforms = [rng.random() for _ in range(2 * LANES)]
    focal = rng.randrange(LANES)
    return {"q": q, "p1": p1, "uniforms": uniforms, "focal": focal, "press_seed": rng.getrandbits(32)}


def switch_tick(geo: Dict, cfg: Dict = trip.CONFIG) -> int:
    """First checkpoint: halfway from the gate to the pause before the Final Burst
    (RaceService's mid), plus the latency grace."""
    t_top = (geo["length"] - trip.COURSES[geo["course"]]["finishFromTop"]) / trip.RACE["speed"]
    pre_end = t_top + 0.5 - 1.5  # burstAfterTurnSeconds, burstLeadSeconds
    return int(math.ceil((pre_end / 2 + LATENCY_GRACE) * cfg["tickHz"]))


class Rider:
    """Arrow presses for one policy; draws only from its own stream."""

    def __init__(self, policy: str, rng: random.Random):
        self.policy = policy
        self.rng = rng

    def press(self, st: trip.TripState, i: int, tick: int) -> int:
        p = self.policy
        if p == "rail":
            if tick % 3 == 0 and trip.lane_after(st, i) > 1:
                return -1
        elif p == "wanderer":
            if self.rng.random() < 0.03:
                return -1 if self.rng.random() < 0.5 else 1
        elif p == "scripted":
            u = self.rng.random()
            if u < 0.02 and trip.lane_after(st, i) > 1:
                return -1
            idle = st.want[i] == 0 and st.queued[i] == 0 and st.x[i] == st.tgt[i]
            if 0.02 <= u < 0.025 and idle and trip.lane_after(st, i) < st.lanes:
                return 1
        return 0


def run_race(geo: Dict, setup: Dict, policies: Sequence[str], cfg: Dict = trip.CONFIG) -> Dict:
    """Phase A for one field. policies[i] per lane ("bot" or one of POLICIES)."""
    kinds = [KIND[p] for p in policies]
    posts = list(range(1, LANES + 1))
    st = trip.new_state(posts, setup["q"], setup["uniforms"], geo, cfg, kinds)
    press_rng = random.Random(setup["press_seed"])
    riders = {i: Rider(p, press_rng) for i, p in enumerate(policies) if p not in ("bot", "smart", "never")}
    dt = 1.0 / cfg["tickHz"]
    t_lock = trip.lock_time(geo)
    sw = switch_tick(geo, cfg)
    q, p1 = setup["q"], setup["p1"]
    reach_ticks = int(round(3.0 * cfg["tickHz"]))
    pending: List[Tuple[int, int, int]] = []  # (lane, goal, deadline tick)
    reach_ok = reach_n = 0
    counts = {"accepted": 0, "queued": 0, "cancelled": 0, "bounds": 0, "rate": 0, "locked": 0, "invalid": 0}
    min_gap = math.inf
    tick = 0
    while tick * dt < t_lock - trip.EPS:
        t = tick * dt
        intents = []
        goals = []
        for i in sorted(riders):
            d = riders[i].press(st, i, tick)
            if d != 0:
                intents.append((i, d))
                goals.append(trip.lane_after(st, i) + d)
        answers = trip.step(st, q if tick < sw else p1, intents, t, dt)
        for (i, d), goal, ans in zip(intents, goals, answers):
            counts[ans] += 1
            if d < 0 and ans in ("accepted", "queued") and (tick + reach_ticks) * dt <= t_lock:
                pending.append((i, goal, tick + reach_ticks))
        still = []
        for lane_i, goal, deadline in pending:
            if st.x[lane_i] <= goal + trip.EPS:
                reach_ok += 1
                reach_n += 1
            elif tick >= deadline:
                reach_n += 1
            else:
                still.append((lane_i, goal, deadline))
        pending = still
        for i in range(LANES):
            for j in range(i + 1, LANES):
                if abs(st.x[i] - st.x[j]) < cfg["laneBand"]:
                    min_gap = min(min_gap, abs(st.off[i] - st.off[j]))
        tick += 1
    lock_x = list(st.x)
    trip.lock(st)
    return {"trip": trip.trip_values(st), "ground": list(st.ground), "draft": list(st.draft), "lock_x": lock_x,
            "reach": (reach_ok, reach_n), "counts": counts, "min_gap": min_gap}


# ---------------------------------------------------------------- workers

def _baseline_chunk(args) -> List[List[Tuple[float, float, float]]]:
    cell, k0, k1, cfg = args
    course, distance = cells()[cell]
    geo = trip.phase_a(course, distance)
    out = []
    for k in range(k0, k1):
        setup = race_setup(race_seed(SEED, cell, k), distance)
        res = run_race(geo, setup, ["bot"] * LANES, cfg)
        out.append([(res["trip"][i], res["ground"][i], res["draft"][i]) for i in range(LANES)])
    return out


def _report_chunk(args) -> List[Dict]:
    cell, k0, k1, cfg, table = args
    course, distance = cells()[cell]
    geo = trip.phase_a(course, distance)
    row = trip.baseline_row(table, course, distance)
    posts = list(range(1, LANES + 1))
    out = []
    for k in range(k0, k1):
        setup = race_setup(race_seed(REPORT_SEED, cell, k), distance)
        f = setup["focal"]
        rec: Dict = {"focal": f}
        bots = run_race(geo, setup, ["bot"] * LANES, cfg)
        rec["bot_tau"] = trip.tau(bots["trip"], posts, row, cfg)
        rec["bot_trip"] = bots["trip"]
        rec["bot_ground"] = bots["ground"]
        rec["bot_draft"] = bots["draft"]
        rec["min_gap"] = bots["min_gap"]
        for pol in POLICIES:
            pols = ["bot"] * LANES
            pols[f] = pol
            res = run_race(geo, setup, pols, cfg)
            tau = trip.tau(res["trip"], posts, row, cfg)
            rec[pol] = {"tau": tau[f], "lane": res["lock_x"][f], "ground": res["ground"][f], "draft": res["draft"][f],
                        "reach": res["reach"], "counts": res["counts"]}
            rec["min_gap"] = min(rec["min_gap"], res["min_gap"])
        allsmart = run_race(geo, setup, ["smart"] * LANES, cfg)
        rec["allsmart_tau"] = trip.tau(allsmart["trip"], posts, row, cfg)
        out.append(rec)
    return out


def _chunks(total: int, size: int) -> List[Tuple[int, int]]:
    return [(a, min(total, a + size)) for a in range(0, total, size)]


# ---------------------------------------------------------------- baseline files

def generate_baseline(races: int, jobs: int, cfg: Dict = trip.CONFIG) -> Dict:
    tasks = []
    for cell in range(len(cells())):
        for a, b in _chunks(races, 100):
            tasks.append((cell, a, b, cfg))
    with Pool(jobs) as pool:
        parts = pool.map(_baseline_chunk, tasks)
    per_cell: Dict[int, List] = {}
    for (cell, _a, _b, _cfg), part in zip(tasks, parts):
        per_cell.setdefault(cell, []).extend(part)
    return summarize_baseline(per_cell, races, cfg)


def calibrate(rows: List, cfg: Dict) -> List[float]:
    """Per-post baseline from bot-mix races (rows[k][post] = (trip, ground, draft)).

    Start from each post's mean trip, then CALIBRATION_PASSES fixed-point passes that move
    every post's mean clamped tau to the all-post mean. The clamp is uneven (-0.02 / +0.04),
    so plain means leave wide-spread posts a little positive. A shift common to all posts
    cancels in the field mean and can't be removed this way; the report shows it separately
    ("clamp shift")."""
    n = len(rows)
    posts = list(range(1, LANES + 1))
    base = [0.0] * LANES
    for race in rows:
        for p in range(LANES):
            base[p] += race[p][0]
    base = [b / n for b in base]
    if not cfg["enabled"] or cfg["scale"] <= 0:
        return base
    for _ in range(CALIBRATION_PASSES):
        sums = [0.0] * LANES
        for race in rows:
            tau = trip.tau([race[p][0] for p in range(LANES)], posts, base, cfg)
            for p in range(LANES):
                sums[p] += tau[p]
        res = [s / n for s in sums]
        shift = sum(res) / LANES
        base = [base[p] + (res[p] - shift) / cfg["scale"] for p in range(LANES)]
    return base


def summarize_baseline(per_cell: Dict[int, List], races: int, cfg: Dict) -> Dict:
    table: Dict = {c: {} for c in trip.COURSE_ORDER}
    trips: Dict = {c: {} for c in trip.COURSE_ORDER}
    ground: Dict = {c: {} for c in trip.COURSE_ORDER}
    draft: Dict = {c: {} for c in trip.COURSE_ORDER}
    probe: Dict = {c: {} for c in trip.COURSE_ORDER}
    for cell, (course, distance) in enumerate(cells()):
        rows = per_cell[cell]
        n = len(rows)
        sums = [[0.0, 0.0, 0.0] for _ in range(LANES)]
        for race in rows:
            for post in range(LANES):
                for c in range(3):
                    sums[post][c] += race[post][c]
        table[course][distance] = [round(v, 6) for v in calibrate(rows, cfg)]
        trips[course][distance] = [round(sums[p][0] / n, 6) for p in range(LANES)]
        ground[course][distance] = [round(sums[p][1] / n, 6) for p in range(LANES)]
        draft[course][distance] = [round(sums[p][2] / n, 6) for p in range(LANES)]
        probe[course][distance] = calibrate(rows[:PROBE_RACES], cfg)
    return {
        "generator": "sims/steering.py --write",
        "seed": SEED,
        "races": races,
        "calibrationPasses": CALIBRATION_PASSES,
        "config": cfg,
        "race": trip.RACE,
        "baseline": table,
        "meanTrip": trips,
        "ground": ground,
        "draft": draft,
        "probe": {"races": PROBE_RACES, "baseline": probe},
    }


def probe_cell(course: str, distance: str, cfg: Dict = trip.CONFIG) -> List[float]:
    """The generator's whole pipeline on the first PROBE_RACES races of one cell (the
    regeneration test compares it with the stored probe)."""
    cell = cells().index((course, distance))
    return calibrate(_baseline_chunk((cell, 0, PROBE_RACES, cfg)), cfg)


def render_luau(data: Dict) -> str:
    lines = [
        "--!strict",
        "-- GENERATED by sims/steering.py (python sims/steering.py --write). Do not edit by hand.",
        "-- Per-post trip baseline (D-054), TripBaseline[course][distance][post] for posts (gate",
        "-- stalls) 1-8: each post's mean trip in bot-mix races, calibrated so every post's clamped",
        f"-- tau averages the same. Seed {data['seed']}, {data['races']:,} races per course and distance.",
        "-- Trip.tau subtracts it, so no post is favoured and q and the locked purses stay untouched.",
        "-- Regenerate whenever GameConfig.steering, src/trip.py or the course geometry changes;",
        "-- tests/test_trip.py fails while this table is stale.",
        "return {",
    ]
    for course in trip.COURSE_ORDER:
        lines.append(f"\t{course} = {{")
        for distance in trip.DISTANCE_ORDER:
            vals = ", ".join(_num(v) for v in data["baseline"][course][distance])
            lines.append(f"\t\t{distance} = {{ {vals} }},")
        lines.append("\t},")
    lines.append("}")
    return "\n".join(lines) + "\n"


def _num(v: float) -> str:
    s = f"{v:.6f}"
    return "0" if s in ("0.000000", "-0.000000") else s


def write_baseline(data: Dict) -> None:
    BASELINE_JSON.write_text(json.dumps(data, indent=1) + "\n")
    BASELINE_LUAU.write_text(render_luau(data))


def load_baseline() -> Dict:
    return json.loads(BASELINE_JSON.read_text())


# ---------------------------------------------------------------- report

def mean(v: Sequence[float]) -> float:
    return sum(v) / len(v) if v else float("nan")


def sd(v: Sequence[float]) -> float:
    mu = mean(v)
    return math.sqrt(sum((x - mu) ** 2 for x in v) / max(1, len(v) - 1))


def run_report(races: int, jobs: int, data: Dict, cfg: Dict = trip.CONFIG) -> Dict:
    table = data["baseline"]
    tasks = []
    for cell in range(len(cells())):
        for a, b in _chunks(races, 25):
            tasks.append((cell, a, b, cfg, table))
    with Pool(jobs) as pool:
        parts = pool.map(_report_chunk, tasks)
    per_cell: Dict[int, List[Dict]] = {}
    for (cell, *_rest), part in zip(tasks, parts):
        per_cell.setdefault(cell, []).extend(part)
    return summarize_report(per_cell, data, cfg)


def summarize_report(per_cell: Dict[int, List[Dict]], data: Dict, cfg: Dict) -> Dict:
    rows = []
    tot = {"reach": [0, 0], "rail_reach": [0, 0], "pos_d": 0.0, "pos_g": 0.0, "scripted_counts": {}}
    for cell, (course, distance) in enumerate(cells()):
        recs = per_cell[cell]
        r: Dict = {"course": course, "distance": distance, "races": len(recs)}
        for pol in POLICIES:
            taus = [x[pol]["tau"] for x in recs]
            r[pol] = mean(taus)
            r[pol + "_sd"] = sd(taus)
            r[pol + "_lane"] = mean([x[pol]["lane"] for x in recs])
            r[pol + "_floor"] = mean([1.0 if t <= cfg["floor"] + 1e-12 else 0.0 for t in taus])
            r[pol + "_top"] = mean([1.0 if t >= cfg["ceiling"] - 1e-12 else 0.0 for t in taus])
        r["rail_vs_smart"] = mean([x["rail"]["tau"] - x["smart"]["tau"] for x in recs])
        r["never_vs_smart"] = mean([x["never"]["tau"] - x["smart"]["tau"] for x in recs])
        r["allsmart_mean"] = mean([t for x in recs for t in x["allsmart_tau"]])
        # Residual post bias: bot-mix fields from a fresh seed, each post's mean tau against the
        # mean over posts. The mean over posts itself is the clamp shift (no post's doing).
        by_post = [mean([x["bot_tau"][p] for x in recs]) for p in range(LANES)]
        shift = mean(by_post)
        r["post_bias"] = [v - shift for v in by_post]
        r["post_bias_max"] = max(abs(v - shift) for v in by_post)
        r["clamp_shift"] = shift
        # Draft share of the positive trip: split each bot's tau into its draft and ground
        # parts (each against its own per-post mean and field mean); over lanes with tau > 0,
        # the draft part's share of the positive parts.
        dmean = data["draft"][course][distance]
        gmean = data["ground"][course][distance]
        pos_d = pos_g = 0.0
        for x in recs:
            dadj = [x["bot_draft"][p] - dmean[p] for p in range(LANES)]
            gadj = [gmean[p] - x["bot_ground"][p] for p in range(LANES)]
            dm, gm = mean(dadj), mean(gadj)
            for p in range(LANES):
                if x["bot_tau"][p] > 0:
                    pos_d += max(0.0, dadj[p] - dm)
                    pos_g += max(0.0, gadj[p] - gm)
        r["draft_share"] = pos_d / (pos_d + pos_g) if pos_d + pos_g > 0 else 0.0
        tot["pos_d"] += pos_d
        tot["pos_g"] += pos_g
        ok = sum(x["scripted"]["reach"][0] for x in recs)
        n = sum(x["scripted"]["reach"][1] for x in recs)
        r["reach3s"] = ok / n if n else float("nan")
        r["reach_n"] = n
        tot["reach"][0] += ok
        tot["reach"][1] += n
        rok = sum(x["rail"]["reach"][0] for x in recs)
        rn = sum(x["rail"]["reach"][1] for x in recs)
        r["rail_reach3s"] = rok / rn if rn else float("nan")
        tot["rail_reach"][0] += rok
        tot["rail_reach"][1] += rn
        for x in recs:
            for key, v in x["scripted"]["counts"].items():
                tot["scripted_counts"][key] = tot["scripted_counts"].get(key, 0) + v
        r["min_gap"] = min(x["min_gap"] for x in recs)
        rows.append(r)
    summary = {
        "rows": rows,
        "reach3s": tot["reach"][0] / tot["reach"][1] if tot["reach"][1] else float("nan"),
        "rail_reach3s": tot["rail_reach"][0] / tot["rail_reach"][1] if tot["rail_reach"][1] else float("nan"),
        "draft_share": tot["pos_d"] / (tot["pos_d"] + tot["pos_g"]) if tot["pos_d"] + tot["pos_g"] > 0 else 0.0,
        "scripted_counts": tot["scripted_counts"],
    }
    summary["checks"] = check_targets(summary)
    return summary


def check_targets(s: Dict) -> Dict[str, bool]:
    rows = s["rows"]
    lo, hi = TARGETS["rail_vs_smart"]
    nlo, nhi = TARGETS["never"]
    return {
        "rail_vs_smart": all(lo <= r["rail_vs_smart"] <= hi for r in rows),
        "never": all(nlo <= r["never"] <= nhi for r in rows),
        "reach3s": s["reach3s"] >= TARGETS["reach3s"],
        "draft_share": s["draft_share"] <= TARGETS["draft_share"],
        "post_bias": all(r["post_bias_max"] < TARGETS["post_bias"] for r in rows),
        "smart_mean": all(abs(r["allsmart_mean"]) <= TARGETS["smart_mean"] for r in rows),
        "smart_in_bot_field": all(abs(r["smart"]) <= TARGETS["smart_mean"] for r in rows),
    }


def format_report(s: Dict, data: Dict, cfg: Dict) -> str:
    out = []
    out.append(f"Steering calibration (D-054): baseline seed {data['seed']}, {data['races']:,} bot-mix races per cell; "
               f"report seed {REPORT_SEED}, {s['rows'][0]['races']} races per cell")
    out.append(f"groundPerLaneTurn {cfg['groundPerLaneTurn']}, draftPerSecond {cfg['draftPerSecond']}, "
               f"draftCap {cfg['draftCap']}, smart.homeLane {cfg['smart']['homeLane']}")
    out.append("")
    out.append("Mean tau of one rider among seven bots (same races for every policy):")
    out.append("| Course | Distance | Smart Steer | Rail rider | Rail - Smart | Never steers | Wanderer | Casual (scripted) "
               "| All-Smart field | Post bias max | Draft share | In within 3 s |")
    out.append("| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |")
    for r in s["rows"]:
        out.append(f"| {r['course']} | {r['distance']} | {r['smart']:+.4f} | {r['rail']:+.4f} | {r['rail_vs_smart']:+.4f} "
                   f"| {r['never']:+.4f} | {r['wanderer']:+.4f} | {r['scripted']:+.4f} | {r['allsmart_mean']:+.4f} "
                   f"| {r['post_bias_max']:.4f} | {r['draft_share']:.0%} | {r['reach3s']:.0%} |")
    out.append("")
    out.append("Lane at the lock (mean):")
    out.append("| Course | Distance | Smart Steer | Rail rider | Never steers | Wanderer | Casual |")
    out.append("| --- | --- | --- | --- | --- | --- | --- |")
    for r in s["rows"]:
        out.append(f"| {r['course']} | {r['distance']} | {r['smart_lane']:.2f} | {r['rail_lane']:.2f} | {r['never_lane']:.2f} "
                   f"| {r['wanderer_lane']:.2f} | {r['scripted_lane']:.2f} |")
    out.append("")
    out.append("Clamp binding (share of races at the floor / ceiling):")
    for r in s["rows"]:
        out.append(f"  {r['course']:4s} {r['distance']:8s} " + "  ".join(
            f"{p} {r[p + '_floor']:.0%}/{r[p + '_top']:.0%}" for p in POLICIES))
    out.append("")
    out.append("Residual post bias by post, posts 1-8 (bot-mix, fresh seed; against the mean over posts) | clamp shift:")
    for r in s["rows"]:
        out.append(f"  {r['course']:4s} {r['distance']:8s} " + " ".join(f"{v:+.4f}" for v in r["post_bias"])
                   + f" | {r['clamp_shift']:+.4f}")
    out.append("")
    out.append("Baseline by post (calibrated), with the raw mean trip in brackets:")
    for c in trip.COURSE_ORDER:
        for d in trip.DISTANCE_ORDER:
            out.append(f"  {c:4s} {d:8s} " + " ".join(f"{v:+.4f}" for v in data["baseline"][c][d])
                       + "  [" + " ".join(f"{v:+.4f}" for v in data["meanTrip"][c][d]) + "]")
    out.append("")
    out.append(f"Inward request reaching its lane within 3 s: casual {s['reach3s']:.1%}, rail rider {s['rail_reach3s']:.1%}")
    out.append(f"Casual rider's presses: {s['scripted_counts']}")
    out.append(f"Draft share of the positive trip (all cells): {s['draft_share']:.1%}")
    out.append(f"Closest same-lane horses at a tick end: {min(r['min_gap'] for r in s['rows']):.2f} ft")
    out.append("")
    labels = {
        "rail_vs_smart": "Rail rider vs Smart Steer +0.01 to +0.03 (every cell)",
        "never": "Never-steer between -0.02 and -0.01 (every cell)",
        "reach3s": "Inward request reaching its lane within 3 s >= 70%",
        "draft_share": "Draft share of positive trip <= 40%",
        "post_bias": "Residual post bias < 0.005 (every cell)",
        "smart_mean": "Smart Steer field mean 0 +- 0.003 (all-Smart fields, every cell)",
        "smart_in_bot_field": "Smart Steer rider among bots 0 +- 0.003 (every cell)",
    }
    for key, ok in s["checks"].items():
        out.append(f"  [{'PASS' if ok else 'MISS'}] {labels[key]}")
    return "\n".join(out)


def main(argv: Optional[Sequence[str]] = None) -> int:
    ap = argparse.ArgumentParser(description="Race steering calibration (D-054)")
    ap.add_argument("--write", action="store_true", help="regenerate the baseline files first")
    ap.add_argument("--races", type=int, default=BASELINE_RACES, help="bot-mix races per cell for the baseline")
    ap.add_argument("--report-races", type=int, default=REPORT_RACES, help="races per cell for the report")
    ap.add_argument("--jobs", type=int, default=0, help="worker processes (default: all cores)")
    ap.add_argument("--json", type=str, default="", help="also write the report numbers to this file")
    ap.add_argument("--set", action="append", default=[], metavar="KEY=VALUE",
                    help="try a config change (e.g. groundPerLaneTurn=0.011, smart.homeLane=2); report only")
    args = ap.parse_args(argv)
    cfg = trip.CONFIG
    if args.set:
        cfg = json.loads(json.dumps(trip.CONFIG))
        for item in args.set:
            key, value = item.split("=", 1)
            node = cfg
            parts = key.split(".")
            for part in parts[:-1]:
                node = node[part]
            node[parts[-1]] = json.loads(value)
    jobs = args.jobs or None
    t0 = time.time()
    if args.set:
        data = generate_baseline(args.races, jobs, cfg)  # trial: a fresh baseline, nothing written
    elif args.write:
        data = generate_baseline(args.races, jobs)
        write_baseline(data)
        print(f"wrote {BASELINE_JSON.relative_to(ROOT)} and {BASELINE_LUAU.relative_to(ROOT)} "
              f"({args.races} races per cell, {time.time() - t0:.0f} s)")
    else:
        data = load_baseline()
    if data["config"] != cfg:
        print("warning: the checked-in baseline was made with a different config; run with --write")
    summary = run_report(args.report_races, jobs, data, cfg)
    print(format_report(summary, data, cfg))
    print(f"({time.time() - t0:.0f} s)")
    if args.json:
        Path(args.json).write_text(json.dumps(summary, indent=1))
    return 0 if all(summary["checks"].values()) else 1


if __name__ == "__main__":
    sys.exit(main())
