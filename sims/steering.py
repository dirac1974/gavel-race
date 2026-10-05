#!/usr/bin/env python3
"""Race steering calibration (D-054): the per-post trip baseline and the acceptance report.

    python sims/steering.py                  # report, using the checked-in baseline
    python sims/steering.py --write          # regenerate the baseline files and the stored report
    python sims/steering.py --set groundPerLaneTurn=0.011 --races 500 --report-races 200   # try a change

--write regenerates tests/fixtures/trip_baseline.json and game/src/shared/TripBaseline.luau
from a fixed seed, then runs the report and stores it in tests/fixtures/steering_report.json
(tests/test_trip.py asserts its targets). Every race has its own seed, so --jobs never
changes a number.

The baseline is fair for the riders who matter: a Smart Steer kid. For every course x
distance it simulates BASELINE_RACES races with a Smart Steer rider at each post among seven
bots, and BASELINE_RACES all-Smart races (a full lobby of kids who never steer), and mixes
the two per-post profiles with weight MIX_WEIGHT (see calibrate()).

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
BASELINE_RACES = 2000     # per course x distance: each post gets this many Smart Steer riders
REPORT_RACES = 600
PROBE_RACES = 4           # the first races of each cell, stored for the regeneration test
CALIBRATION_PASSES = 4
MIX_WEIGHT = 0.5          # Smart Steer rider among bots vs all-Smart fields (calibrate())
LANES = 8
BASELINE_JSON = ROOT / "tests" / "fixtures" / "trip_baseline.json"
BASELINE_LUAU = ROOT / "game" / "src" / "shared" / "TripBaseline.luau"
REPORT_JSON = ROOT / "tests" / "fixtures" / "steering_report.json"

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

FOCAL = ("rail", "never", "wanderer", "scripted")
POLICIES = ("smart",) + FOCAL
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


def posts() -> List[int]:
    return list(range(1, LANES + 1))


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
    return {"q": q, "p1": p1, "s1": s1, "uniforms": uniforms, "focal": focal, "press_seed": rng.getrandbits(32)}


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
    st = trip.new_state(posts(), setup["q"], setup["uniforms"], geo, cfg, kinds)
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


def smart_at(post_index: int) -> List[str]:
    pols = ["bot"] * LANES
    pols[post_index] = "smart"
    return pols


# ---------------------------------------------------------------- workers

def _baseline_chunk(args) -> List[Dict]:
    """Per race: the trips of eight fields (a Smart Steer rider at each post among bots) and
    of one all-Smart field."""
    cell, k0, k1, cfg = args
    course, distance = cells()[cell]
    geo = trip.phase_a(course, distance)
    out = []
    for k in range(k0, k1):
        setup = race_setup(race_seed(SEED, cell, k), distance)
        sweep = [run_race(geo, setup, smart_at(p), cfg)["trip"] for p in range(LANES)]
        allsmart = run_race(geo, setup, ["smart"] * LANES, cfg)["trip"]
        out.append({"sweep": sweep, "allsmart": allsmart})
    return out


def _report_chunk(args) -> List[Dict]:
    cell, k0, k1, cfg, table = args
    course, distance = cells()[cell]
    geo = trip.phase_a(course, distance)
    row = trip.baseline_row(table, course, distance)
    out = []
    for k in range(k0, k1):
        setup = race_setup(race_seed(REPORT_SEED, cell, k), distance)
        f = setup["focal"]
        rec: Dict = {"focal": f, "p1": setup["p1"], "s1": setup["s1"]}
        bots = run_race(geo, setup, ["bot"] * LANES, cfg)
        rec["bot_tau"] = trip.tau(bots["trip"], posts(), row, cfg)
        rec["bot_ground"] = bots["ground"]
        rec["bot_draft"] = bots["draft"]
        rec["min_gap"] = bots["min_gap"]
        sweep_tau, sweep_lane = [], []
        for p in range(LANES):
            res = run_race(geo, setup, smart_at(p), cfg)
            sweep_tau.append(trip.tau(res["trip"], posts(), row, cfg)[p])
            sweep_lane.append(res["lock_x"][p])
            rec["min_gap"] = min(rec["min_gap"], res["min_gap"])
        rec["sweep_tau"] = sweep_tau
        rec["smart"] = {"tau": sweep_tau[f], "lane": sweep_lane[f]}
        for pol in FOCAL:
            pols = ["bot"] * LANES
            pols[f] = pol
            res = run_race(geo, setup, pols, cfg)
            rec[pol] = {"tau": trip.tau(res["trip"], posts(), row, cfg)[f], "lane": res["lock_x"][f],
                        "reach": res["reach"], "counts": res["counts"]}
            rec["min_gap"] = min(rec["min_gap"], res["min_gap"])
        allsmart = run_race(geo, setup, ["smart"] * LANES, cfg)
        rec["allsmart_tau"] = trip.tau(allsmart["trip"], posts(), row, cfg)
        out.append(rec)
    return out


def _chunks(total: int, size: int) -> List[Tuple[int, int]]:
    return [(a, min(total, a + size)) for a in range(0, total, size)]


# ---------------------------------------------------------------- baseline files

def generate_baseline(races: int, jobs: Optional[int], cfg: Dict = trip.CONFIG, mix: float = MIX_WEIGHT) -> Dict:
    tasks = []
    for cell in range(len(cells())):
        for a, b in _chunks(races, 25):
            tasks.append((cell, a, b, cfg))
    with Pool(jobs) as pool:
        parts = pool.map(_baseline_chunk, tasks)
    per_cell: Dict[int, List] = {}
    for (cell, _a, _b, _cfg), part in zip(tasks, parts):
        per_cell.setdefault(cell, []).extend(part)
    return summarize_baseline(per_cell, races, cfg, mix)


def raw_profiles(rows: List[Dict]) -> Tuple[List[float], List[float]]:
    """Per post: a Smart Steer rider's mean trip there among bots, and the all-Smart mean."""
    n = len(rows)
    a = [0.0] * LANES
    b = [0.0] * LANES
    for race in rows:
        for p in range(LANES):
            a[p] += race["sweep"][p][p]
            b[p] += race["allsmart"][p]
    return [v / n for v in a], [v / n for v in b]


def calibrate(rows: List[Dict], cfg: Dict, mix: float = MIX_WEIGHT) -> List[float]:
    """Per-post baseline that is fair for Smart Steer kids in any lobby.

    Two kinds of field: (a) one Smart Steer kid among seven bots (most races) and (b) eight
    Smart Steer kids (a full lobby). Start from mix * (a)'s per-post mean trip + (1 - mix) *
    (b)'s, then CALIBRATION_PASSES fixed-point passes on clamped tau: each pass moves every
    post by mix * (its residual in (a)) + (1 - mix) * (its residual in (b)), each residual
    taken against the mean over posts. A shift common to all posts cancels in the field mean
    and can't be removed (the report shows it). With mix = 0.5 the two kinds of field end up
    with residuals of equal size and opposite sign, half the gap between their profiles."""
    n = len(rows)
    raw_a, raw_b = raw_profiles(rows)
    base = [mix * raw_a[p] + (1 - mix) * raw_b[p] for p in range(LANES)]
    if not cfg["enabled"] or cfg["scale"] <= 0:
        return base
    ps = posts()
    for _ in range(CALIBRATION_PASSES):
        sa = [0.0] * LANES
        sb = [0.0] * LANES
        for race in rows:
            for p in range(LANES):
                sa[p] += trip.tau(race["sweep"][p], ps, base, cfg)[p]
            tb = trip.tau(race["allsmart"], ps, base, cfg)
            for p in range(LANES):
                sb[p] += tb[p]
        ra = [v / n for v in sa]
        rb = [v / n for v in sb]
        ma, mb = sum(ra) / LANES, sum(rb) / LANES
        base = [base[p] + (mix * (ra[p] - ma) + (1 - mix) * (rb[p] - mb)) / cfg["scale"] for p in range(LANES)]
    return base


def summarize_baseline(per_cell: Dict[int, List], races: int, cfg: Dict, mix: float) -> Dict:
    table: Dict = {c: {} for c in trip.COURSE_ORDER}
    src_a: Dict = {c: {} for c in trip.COURSE_ORDER}
    src_b: Dict = {c: {} for c in trip.COURSE_ORDER}
    probe: Dict = {c: {} for c in trip.COURSE_ORDER}
    for cell, (course, distance) in enumerate(cells()):
        rows = per_cell[cell]
        raw_a, raw_b = raw_profiles(rows)
        table[course][distance] = [round(v, 6) for v in calibrate(rows, cfg, mix)]
        src_a[course][distance] = [round(v, 6) for v in raw_a]
        src_b[course][distance] = [round(v, 6) for v in raw_b]
        probe[course][distance] = calibrate(rows[:PROBE_RACES], cfg, mix)
    return {
        "generator": "sims/steering.py --write",
        "seed": SEED,
        "races": races,
        "mixWeight": mix,
        "calibrationPasses": CALIBRATION_PASSES,
        "config": cfg,
        "race": trip.RACE,
        "baseline": table,
        "smartAmongBots": src_a,
        "allSmart": src_b,
        "probe": {"races": PROBE_RACES, "baseline": probe},
    }


def probe_cell(course: str, distance: str, cfg: Dict = trip.CONFIG, mix: float = MIX_WEIGHT) -> List[float]:
    """The generator's whole pipeline on the first PROBE_RACES races of one cell (the
    regeneration test compares it with the stored probe)."""
    cell = cells().index((course, distance))
    return calibrate(_baseline_chunk((cell, 0, PROBE_RACES, cfg)), cfg, mix)


def render_luau(data: Dict) -> str:
    lines = [
        "--!strict",
        "-- GENERATED by sims/steering.py (python sims/steering.py --write). Do not edit by hand.",
        "-- Per-post trip baseline (D-054), TripBaseline[course][distance][post] for posts (gate",
        "-- stalls) 1-8: what a Smart Steer kid's trip from each post comes to, mixing one kid among",
        f"-- bots and a full lobby of kids ({data['mixWeight']:g} / {1 - data['mixWeight']:g}), calibrated on clamped tau.",
        f"-- Seed {data['seed']}, {data['races']:,} races per course, distance and post. Trip.tau subtracts it,",
        "-- so no post is favoured and q and the locked purses stay untouched. Regenerate whenever",
        "-- GameConfig.steering, src/trip.py or the course geometry changes; tests/test_trip.py",
        "-- fails while this table is stale.",
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


def load_report() -> Dict:
    return json.loads(REPORT_JSON.read_text())


# ---------------------------------------------------------------- report

def mean(v: Sequence[float]) -> float:
    return sum(v) / len(v) if v else float("nan")


def run_report(races: int, jobs: Optional[int], data: Dict, cfg: Dict = trip.CONFIG) -> Dict:
    table = data["baseline"]
    tasks = []
    for cell in range(len(cells())):
        for a, b in _chunks(races, 10):
            tasks.append((cell, a, b, cfg, table))
    with Pool(jobs) as pool:
        parts = pool.map(_report_chunk, tasks)
    per_cell: Dict[int, List[Dict]] = {}
    for (cell, *_rest), part in zip(tasks, parts):
        per_cell.setdefault(cell, []).extend(part)
    return summarize_report(per_cell, cfg)


def by_post_residual(rows: List[List[float]]) -> Tuple[List[float], float]:
    """Mean per post across races, minus the mean over posts; and that mean."""
    by_post = [mean([r[p] for r in rows]) for p in range(LANES)]
    shift = mean(by_post)
    return [v - shift for v in by_post], shift


def summarize_report(per_cell: Dict[int, List[Dict]], cfg: Dict) -> Dict:
    rows = []
    for cell, (course, distance) in enumerate(cells()):
        recs = per_cell[cell]
        r: Dict = {"course": course, "distance": distance, "races": len(recs)}
        for pol in POLICIES:
            taus = [x[pol]["tau"] for x in recs]
            r[pol] = mean(taus)
            r[pol + "_lane"] = mean([x[pol]["lane"] for x in recs])
            r[pol + "_floor"] = mean([1.0 if t <= cfg["floor"] + 1e-12 else 0.0 for t in taus])
            r[pol + "_top"] = mean([1.0 if t >= cfg["ceiling"] - 1e-12 else 0.0 for t in taus])
        r["rail_vs_smart"] = mean([x["rail"]["tau"] - x["smart"]["tau"] for x in recs])
        # A Smart Steer kid at every post among bots (eight fields per race).
        r["smart_among_bots"] = mean([t for x in recs for t in x["sweep_tau"]])
        rel, _ = by_post_residual([x["sweep_tau"] for x in recs])
        r["smart_post"] = rel
        r["smart_post_abs"] = [v + r["smart_among_bots"] for v in rel]
        r["smart_post_max"] = max(abs(v) for v in rel)
        r["smart_post_abs_max"] = max(abs(v) for v in r["smart_post_abs"])
        # Eight Smart Steer kids.
        rel, shift = by_post_residual([x["allsmart_tau"] for x in recs])
        r["allsmart_post"] = rel
        r["allsmart_post_max"] = max(abs(v) for v in rel)
        r["allsmart_mean"] = shift
        # Bot fields (no kid; for information).
        rel, shift = by_post_residual([x["bot_tau"] for x in recs])
        r["bot_post"] = rel
        r["bot_post_max"] = max(abs(v) for v in rel)
        r["bot_clamp_shift"] = shift
        # Draft and tapping skill in bot fields: mean tau of the lane with the highest and
        # the lowest live chance after the first checkpoint (the on-screen leader and last).
        lead_tau, last_tau, top_tap, low_tap = [], [], [], []
        for x in recs:
            order = sorted(range(LANES), key=lambda i: (-x["p1"][i], i))
            lead_tau.append(x["bot_tau"][order[0]])
            last_tau.append(x["bot_tau"][order[-1]])
            taps = sorted(range(LANES), key=lambda i: (-x["s1"][i], i))
            top_tap.append(x["bot_tau"][taps[0]])
            low_tap.append(x["bot_tau"][taps[-1]])
        r["skill_leader_tau"] = mean(lead_tau)
        r["skill_last_tau"] = mean(last_tau)
        r["top_tapper_tau"] = mean(top_tap)
        r["low_tapper_tau"] = mean(low_tap)
        # Draft share of the positive trip: split each bot's tau into its draft and ground
        # parts (each against its own per-post mean in these bot fields and the field mean);
        # over lanes with tau > 0, the draft part's share of the positive parts.
        dmean = [mean([x["bot_draft"][p] for x in recs]) for p in range(LANES)]
        gmean = [mean([x["bot_ground"][p] for x in recs]) for p in range(LANES)]
        pos_d = pos_g = 0.0
        for x in recs:
            dadj = [x["bot_draft"][p] - dmean[p] for p in range(LANES)]
            gadj = [gmean[p] - x["bot_ground"][p] for p in range(LANES)]
            dm, gm = mean(dadj), mean(gadj)
            for p in range(LANES):
                if x["bot_tau"][p] > 0:
                    pos_d += max(0.0, dadj[p] - dm)
                    pos_g += max(0.0, gadj[p] - gm)
        r["draft_pos"], r["ground_pos"] = pos_d, pos_g
        r["draft_share"] = pos_d / (pos_d + pos_g) if pos_d + pos_g > 0 else 0.0
        for pol in ("scripted", "rail"):
            ok = sum(x[pol]["reach"][0] for x in recs)
            n = sum(x[pol]["reach"][1] for x in recs)
            r[pol + "_reach_ok"], r[pol + "_reach_n"] = ok, n
            r[pol + "_reach3s"] = ok / n if n else float("nan")
        r["reach3s"] = r["scripted_reach3s"]
        counts: Dict[str, int] = {}
        for x in recs:
            for key, v in x["scripted"]["counts"].items():
                counts[key] = counts.get(key, 0) + v
        r["scripted_counts"] = counts
        r["min_gap"] = min(x["min_gap"] for x in recs)
        rows.append(r)
    tot_ok = sum(r["scripted_reach_ok"] for r in rows)
    tot_n = sum(r["scripted_reach_n"] for r in rows)
    pos_d = sum(r["draft_pos"] for r in rows)
    pos_g = sum(r["ground_pos"] for r in rows)
    summary = {
        "rows": rows,
        "reach3s": tot_ok / tot_n if tot_n else float("nan"),
        "rail_reach3s": sum(r["rail_reach_ok"] for r in rows) / max(1, sum(r["rail_reach_n"] for r in rows)),
        "draft_share": pos_d / (pos_d + pos_g) if pos_d + pos_g > 0 else 0.0,
    }
    summary["checks"] = check_targets(summary)
    return summary


def check_targets(s: Dict) -> Dict[str, bool]:
    rows = s["rows"]
    lo, hi = TARGETS["rail_vs_smart"]
    nlo, nhi = TARGETS["never"]
    pb, sm = TARGETS["post_bias"], TARGETS["smart_mean"]
    return {
        "rail_vs_smart": all(lo <= r["rail_vs_smart"] <= hi for r in rows),
        "never": all(nlo <= r["never"] <= nhi for r in rows),
        "reach3s": all(r["reach3s"] >= TARGETS["reach3s"] for r in rows),
        "draft_share": all(r["draft_share"] <= TARGETS["draft_share"] for r in rows),
        "post_bias_smart_among_bots": all(r["smart_post_max"] < pb for r in rows),
        "post_bias_all_smart": all(r["allsmart_post_max"] < pb for r in rows),
        "smart_among_bots_mean": all(abs(r["smart_among_bots"]) <= sm for r in rows),
        "all_smart_field_mean": all(abs(r["allsmart_mean"]) <= sm for r in rows),
    }


LABELS = {
    "rail_vs_smart": "Rail rider vs Smart Steer +0.01 to +0.03 (every cell)",
    "never": "Never-steer between -0.02 and -0.01 (every cell)",
    "reach3s": "Inward request reaching its lane within 3 s >= 70% (every cell)",
    "draft_share": "Draft share of positive trip <= 40% (every cell)",
    "post_bias_smart_among_bots": "Post bias < 0.005, Smart Steer kid among bots (every cell, every post)",
    "post_bias_all_smart": "Post bias < 0.005, all-Smart fields (every cell, every post)",
    "smart_among_bots_mean": "Smart Steer kid among bots averages 0 +- 0.003 (every cell)",
    "all_smart_field_mean": "All-Smart field mean 0 +- 0.003 (every cell)",
}


def _posts(v: Sequence[float]) -> str:
    return " ".join(f"{x:+.4f}" for x in v)


def format_report(s: Dict, data: Dict, cfg: Dict) -> str:
    out = []
    rows = s["rows"]
    out.append(f"Steering calibration (D-054): baseline seed {data['seed']}, {data['races']:,} races per cell and post, "
               f"mix {data['mixWeight']}; report seed {REPORT_SEED}, {rows[0]['races']} races per cell")
    out.append(f"groundPerLaneTurn {cfg['groundPerLaneTurn']}, draftPerSecond {cfg['draftPerSecond']}, "
               f"draftCap {cfg['draftCap']}, smart.homeLane {cfg['smart']['homeLane']}, bots.wideShare {cfg['bots']['wideShare']}, "
               f"clearFeet {cfg['clearFeet']}, tuckBackMax {cfg['tuckBackMax']}")
    out.append("")
    out.append("Mean tau (focal rider among seven bots; Smart Steer = a kid at every post among bots):")
    out.append("| Course | Distance | Smart Steer | Rail rider | Rail - Smart | Never steers | Wanderer | Casual "
               "| All-Smart field | Post bias: kid among bots | Post bias: all-Smart | Draft share | In within 3 s |")
    out.append("| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |")
    for r in rows:
        out.append(f"| {r['course']} | {r['distance']} | {r['smart_among_bots']:+.4f} | {r['rail']:+.4f} "
                   f"| {r['rail_vs_smart']:+.4f} | {r['never']:+.4f} | {r['wanderer']:+.4f} | {r['scripted']:+.4f} "
                   f"| {r['allsmart_mean']:+.4f} | {r['smart_post_max']:.4f} | {r['allsmart_post_max']:.4f} "
                   f"| {r['draft_share']:.0%} | {r['reach3s']:.0%} |")
    out.append("")
    out.append("Per-post residual, posts 1-8 (mean tau at the post minus the mean over posts):")
    for label, key in (("Smart Steer kid among bots", "smart_post"), ("all-Smart fields", "allsmart_post"),
                       ("bot fields (information)", "bot_post")):
        out.append(f"  {label}:")
        for r in rows:
            out.append(f"    {r['course']:4s} {r['distance']:8s} {_posts(r[key])}")
    out.append("  Smart Steer kid among bots, absolute mean tau per post (residual + the kid's mean):")
    for r in rows:
        out.append(f"    {r['course']:4s} {r['distance']:8s} {_posts(r['smart_post_abs'])}")
    out.append("")
    out.append("Lane at the lock (mean): Smart Steer / rail / never / wanderer / casual")
    for r in rows:
        out.append(f"  {r['course']:4s} {r['distance']:8s} {r['smart_lane']:.2f} {r['rail_lane']:.2f} {r['never_lane']:.2f} "
                   f"{r['wanderer_lane']:.2f} {r['scripted_lane']:.2f}")
    out.append("Clamp binding (share of races at the floor / ceiling):")
    for r in rows:
        out.append(f"  {r['course']:4s} {r['distance']:8s} " + "  ".join(
            f"{p} {r[p + '_floor']:.0%}/{r[p + '_top']:.0%}" for p in POLICIES))
    out.append("Draft and tapping skill in bot fields (mean tau): on-screen leader / last after checkpoint 1; "
               "best / worst tapper")
    for r in rows:
        out.append(f"  {r['course']:4s} {r['distance']:8s} {r['skill_leader_tau']:+.4f} / {r['skill_last_tau']:+.4f};  "
                   f"{r['top_tapper_tau']:+.4f} / {r['low_tapper_tau']:+.4f}")
    out.append("")
    out.append(f"Inward request reaching its lane within 3 s: casual {s['reach3s']:.1%} overall "
               f"(cells {min(r['reach3s'] for r in rows):.1%}-{max(r['reach3s'] for r in rows):.1%}), "
               f"rail rider {s['rail_reach3s']:.1%}")
    out.append(f"Draft share of the positive trip: {s['draft_share']:.1%} overall")
    out.append(f"Closest same-lane horses at a tick end: {min(r['min_gap'] for r in rows):.2f} ft")
    out.append("")
    for key, ok in s["checks"].items():
        out.append(f"  [{'PASS' if ok else 'MISS'}] {LABELS[key]}")
    return "\n".join(out)


def main(argv: Optional[Sequence[str]] = None) -> int:
    ap = argparse.ArgumentParser(description="Race steering calibration (D-054)")
    ap.add_argument("--write", action="store_true", help="regenerate the baseline files and the stored report")
    ap.add_argument("--races", type=int, default=BASELINE_RACES, help="baseline races per cell (each post gets this many)")
    ap.add_argument("--report-races", type=int, default=REPORT_RACES, help="races per cell for the report")
    ap.add_argument("--jobs", type=int, default=0, help="worker processes (default: all cores)")
    ap.add_argument("--mix", type=float, default=None, help="trial: weight of the kid-among-bots profile")
    ap.add_argument("--json", type=str, default="", help="also write the report numbers to this file")
    ap.add_argument("--set", action="append", default=[], metavar="KEY=VALUE",
                    help="try a config change (e.g. groundPerLaneTurn=0.011, smart.homeLane=2); nothing is written")
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
    if args.write and (args.set or args.mix is not None):
        ap.error("--write uses the checked-in config; drop --set and --mix")
    if args.write or args.set or args.mix is not None:
        data = generate_baseline(args.races, jobs, cfg, MIX_WEIGHT if args.mix is None else args.mix)
        if args.write:
            write_baseline(data)
            print(f"wrote {BASELINE_JSON.relative_to(ROOT)} and {BASELINE_LUAU.relative_to(ROOT)} "
                  f"({args.races} races per cell and post, {time.time() - t0:.0f} s)")
    else:
        data = load_baseline()
    if data["config"] != cfg:
        print("warning: the checked-in baseline was made with a different config; run with --write")
    summary = run_report(args.report_races, jobs, data, cfg)
    print(format_report(summary, data, cfg))
    print(f"({time.time() - t0:.0f} s)")
    stored = {"seed": REPORT_SEED, "races": args.report_races, "baselineSeed": data["seed"],
              "baselineRaces": data["races"], "mixWeight": data["mixWeight"], "config": cfg, "summary": summary}
    if args.write:
        REPORT_JSON.write_text(json.dumps(stored, indent=1) + "\n")
        print(f"wrote {REPORT_JSON.relative_to(ROOT)}")
    if args.json:
        Path(args.json).write_text(json.dumps(stored, indent=1))
    return 0 if all(summary["checks"].values()) else 1


if __name__ == "__main__":
    sys.exit(main())
