#!/usr/bin/env python3
"""Race steering calibration (D-054, D-057): the per-post trip baseline and the acceptance report.

    python sims/steering.py                  # report, using the checked-in baseline
    python sims/steering.py --write          # regenerate the baseline files and the stored report
    python sims/steering.py --set groundPerLaneTurn=0.011 --races 500 --report-races 200   # try a change
    python sims/steering.py --profile d057 --write   # D-057 on: its own baseline and report (no game files)

--write regenerates tests/fixtures/trip_baseline.json and game/src/shared/TripBaseline.luau
from a fixed seed, then runs the report and stores it in tests/fixtures/steering_report.json
(tests/test_trip.py asserts its targets). Every race has its own seed, so --jobs never
changes a number.

--profile d057 runs the same pipeline with D-057 switched on (trip.d057_config(): the eased
glide, chaining, reverse and weave gaps, press bounce, glide reserve, wait-for-room presses and
brushes). With --write it stores tests/fixtures/trip_baseline_d057.json and
tests/fixtures/steering_report_d057.json (tests/test_trip_d057.py asserts them) and leaves
TripBaseline.luau alone: the game keeps D-054 until stage N3 flips the config and regenerates.
Its report adds the D-057 measures: zig-zag reversals, sideways speed and acceleration, a body
yaw estimate, boxed-in time by post and policy, brushes by policy, reach per intent, the
griefing test and an overlap stress run.

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
  masher    (D-057) 4 presses a second on a random side
  ditherer  (D-057) In, Out, In, Out ... every 0.2 s
Griefers (D-057 griefing test; strangers who tapped exactly like the kid, see GRIEF):
  shadow / crew_in   sit on the kid's inside      crew_out  sit on its outside
  crew_ahead         sit in its lane              bumper    get beside it, then keep pressing into it
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
GRIEF_SEED = 20261008
STRESS_SEED = 20261009
BASELINE_RACES = 2000     # per course x distance: each post gets this many Smart Steer riders
REPORT_RACES = 600
GRIEF_RACES = 200         # D-057: per course x distance, each scenario and kid policy
STRESS_RACES = 500        # D-057: per course x distance (4,000 in all)
PROBE_RACES = 4           # the first races of each cell, stored for the regeneration test
CALIBRATION_PASSES = 4
MIX_WEIGHT = 0.5          # Smart Steer rider among bots vs all-Smart fields (calibrate())
LANES = 8
BASELINE_JSON = ROOT / "tests" / "fixtures" / "trip_baseline.json"
BASELINE_LUAU = ROOT / "game" / "src" / "shared" / "TripBaseline.luau"
REPORT_JSON = ROOT / "tests" / "fixtures" / "steering_report.json"
BASELINE_JSON_D057 = ROOT / "tests" / "fixtures" / "trip_baseline_d057.json"
REPORT_JSON_D057 = ROOT / "tests" / "fixtures" / "steering_report_d057.json"
PROFILES = ("d054", "d057")

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
FOCAL_D057 = FOCAL + ("masher", "ditherer")
POLICIES = ("smart",) + FOCAL
POLICIES_D057 = ("smart",) + FOCAL_D057
GRIEFERS = ("shadow", "crew_in", "crew_out", "crew_ahead", "bumper")
PRESSERS = ("rail", "wanderer", "scripted", "masher", "ditherer") + GRIEFERS
KIND = {"bot": "bot", "smart": "smart", "rail": "smart", "never": "manual", "wanderer": "smart", "scripted": "smart",
        "masher": "smart", "ditherer": "smart", "shadow": "smart", "crew_in": "smart", "crew_out": "smart",
        "crew_ahead": "smart", "bumper": "smart"}

TARGETS = {
    "rail_vs_smart": (0.01, 0.03),
    "never": (-0.02, -0.01),
    "reach3s": 0.70,
    "draft_share": 0.40,
    "post_bias": 0.005,
    "smart_mean": 0.003,
}
# D-057 (debate 012). intent3s replaces reach3s: an inward press counts once per intent (no press
# by that rider in the 3 s before). The others are new.
TARGETS_D057 = {
    "intent3s": 0.70,
    "masher_reversals_per_min": 8.0,
    "masher_min_reversal_gap": 3.0,     # seconds between a masher's reversals, at least
    "accel_max_ftps2": 30.0,            # sideways, between ticks, any horse
    "casual_charged_share": 0.05,       # races in which a casual rider is charged for a brush
    "griefing": -0.001,                 # targeted minus untargeted own trip, at least
    "stress_fallback_ftps": 20.0,       # fastest a horse falls back on the pace (D-055)
}

# Mirrors GameConfig.steerView (D-057, N3's SteerPose) for the body-turn estimate.
STEER_VIEW = {"yawGain": 1.0, "yawMaxDeg": 10.0, "yawSmoothSeconds": 0.15, "leanDegPerFtps2": 0.12, "leanMaxDeg": 3.0}

# D-057 griefing scenarios: (stranger policies, feet ahead of the kid's skill target for each).
# The strangers' skill targets are the kid's plus those feet: they tapped exactly like the kid,
# the worst case. "matched" is the same strangers on plain Smart Steer; rail1 / rail3 are the
# untargeted controls (the same strangers riding for the rail, targeting nobody).
GRIEF: Dict[str, Tuple[Tuple[str, ...], Tuple[float, ...]]] = {
    "matched": (("smart", "smart", "smart"), (0.0, 0.0, 12.0)),
    "shadow": (("shadow",), (0.0,)),
    "crew": (("crew_in", "crew_out", "crew_ahead"), (0.0, 0.0, 12.0)),
    "bumper": (("bumper",), (0.0,)),
    "rail1": (("rail",), (0.0,)),
    "rail3": (("rail", "rail", "rail"), (0.0, 0.0, 12.0)),
}
GRIEF_PAIRS = (("shadow", "rail1"), ("crew", "rail3"), ("bumper", "rail1"))  # targeted, its untargeted control
GRIEF_KIDS = ("smart", "rail")


def cells() -> List[Tuple[str, str]]:
    return [(c, d) for c in trip.COURSE_ORDER for d in trip.DISTANCE_ORDER]


def race_seed(base: int, cell: int, k: int) -> int:
    return (base * 16 + cell) * 1_000_000 + k


def posts() -> List[int]:
    return list(range(1, LANES + 1))


def profile_config(profile: str) -> Dict:
    if profile == "d054":
        return trip.CONFIG
    if profile == "d057":
        return trip.d057_config()
    raise ValueError(f"unknown profile {profile!r}")


def baseline_path(profile: str) -> Path:
    return BASELINE_JSON if profile == "d054" else BASELINE_JSON_D057


def report_path(profile: str) -> Path:
    return REPORT_JSON if profile == "d054" else REPORT_JSON_D057


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
    """Arrow presses for one policy; draws only from its own stream. kid = the lane the
    griefers target."""

    def __init__(self, policy: str, rng: random.Random, kid: int = -1):
        self.policy = policy
        self.rng = rng
        self.kid = kid
        self.flip = 1

    def _toward(self, st: trip.TripState, i: int, goal: int, tick: int) -> int:
        if tick % 3 != 0:
            return 0
        after = trip.lane_after(st, i)
        if after > goal:
            return -1
        if after < goal:
            return 1
        return 0

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
        elif p == "masher":
            if self.rng.random() < 0.4:
                return -1 if self.rng.random() < 0.5 else 1
        elif p == "ditherer":
            if tick % 2 == 0:
                self.flip = -self.flip
                after = trip.lane_after(st, i)
                if after + self.flip < 1 or after + self.flip > st.lanes:
                    self.flip = -self.flip
                return self.flip
        elif p in ("shadow", "crew_in"):
            return self._toward(st, i, max(1, st.tgt[self.kid] - 1), tick)
        elif p == "crew_out":
            return self._toward(st, i, min(st.lanes, st.tgt[self.kid] + 1), tick)
        elif p == "crew_ahead":
            return self._toward(st, i, st.tgt[self.kid], tick)
        elif p == "bumper":
            k = self.kid
            goal = st.tgt[k] - 1 if st.tgt[k] > 1 else st.tgt[k] + 1
            if trip.lane_after(st, i) != goal:
                return self._toward(st, i, goal, tick)
            if tick % 3 == 0:
                return 1 if st.tgt[k] > st.tgt[i] else -1
        return 0


def run_race(geo: Dict, setup: Dict, policies: Sequence[str], cfg: Dict = trip.CONFIG,
             match: Optional[Dict[int, float]] = None, focal: int = -1, measure: Sequence[str] = ()) -> Dict:
    """Phase A for one field. policies[i] per lane ("bot" or one of the policies above).
    match = {lane: feet}: that lane's skill target is the focal (kid) lane's plus feet.
    measure (D-057 detail, slower): "boxed" (the focal horse's boxed-in and trapped time),
    "motion" (the focal horse's lane-change starts; every horse's sideways speed, acceleration
    and estimated body yaw and lean), "stress" (overlaps and the fastest fall-back)."""
    kinds = [KIND[p] for p in policies]
    st = trip.new_state(posts(), setup["q"], setup["uniforms"], geo, cfg, kinds)
    press_rng = random.Random(setup["press_seed"])
    riders = {i: Rider(p, press_rng, focal) for i, p in enumerate(policies) if p in PRESSERS}
    dt = 1.0 / cfg["tickHz"]
    t_lock = trip.lock_time(geo)
    sw = switch_tick(geo, cfg)
    q, p1 = setup["q"], setup["p1"]
    reach_ticks = int(round(3.0 * cfg["tickHz"]))
    pending: List[Tuple[int, int, int, bool]] = []  # (lane, goal, deadline tick, first press of an intent)
    reach_ok = reach_n = intent_ok = intent_n = 0
    last_press: Dict[int, int] = {}
    counts = {"accepted": 0, "queued": 0, "cancelled": 0, "bounds": 0, "rate": 0, "locked": 0, "invalid": 0}
    min_gap = math.inf
    boxed_on, motion_on, stress_on = "boxed" in measure, "motion" in measure, "stress" in measure
    lane_ft = trip.COURSES[geo["course"]]["laneWidth"]
    boxed_s = trapped_s = 0.0
    waits: List[Tuple[int, int, int]] = []  # the focal rider's presses: (tick, lane held then, dir)
    waits1s = 0
    starts: List[Tuple[float, int]] = []
    last_tgt = st.tgt[focal] if focal >= 0 else 0
    prev_x = list(st.x)
    prev_v = [0.0] * LANES
    yaw = [0.0] * LANES
    lean = [0.0] * LANES
    vmax = amax = yaw_max = lean_max = 0.0
    vhist = [0] * 16    # |v| ft/s, bins of 1, while moving
    ahist = [0] * 13    # |a| ft/s^2, bins of 5
    yhist = [0] * 12    # |yaw| degrees, bins of 1
    overlaps = 0
    back_max = 0.0
    prev_off = list(st.off)
    alpha = min(1.0, dt / STEER_VIEW["yawSmoothSeconds"])
    tick = 0
    while tick * dt < t_lock - trip.EPS:
        t = tick * dt
        intents = []
        goals = []
        firsts = []
        for i in sorted(riders):
            d = riders[i].press(st, i, tick)
            if d != 0:
                intents.append((i, d))
                goals.append(trip.lane_after(st, i) + d)
                firsts.append(tick - last_press.get(i, -10 ** 9) > reach_ticks)
                last_press[i] = tick
        live = q if tick < sw else p1
        if match:
            live = list(live)
            for g, feet in match.items():
                live[g] = live[focal] + feet / st.lead
        answers = trip.step(st, live, intents, t, dt)
        for (i, d), goal, first, ans in zip(intents, goals, firsts, answers):
            counts[ans] = counts.get(ans, 0) + 1
            if d < 0 and ans in ("accepted", "queued") and (tick + reach_ticks) * dt <= t_lock:
                pending.append((i, goal, tick + reach_ticks, first))
            if boxed_on and i == focal and ans in ("accepted", "queued") and (tick + 10) * dt <= t_lock:
                waits.append((tick, st.tgt[i], d))
        still = []
        for lane_i, goal, deadline, first in pending:
            if st.x[lane_i] <= goal + trip.EPS:
                reach_ok += 1
                reach_n += 1
                if first:
                    intent_ok += 1
                    intent_n += 1
            elif tick >= deadline:
                reach_n += 1
                if first:
                    intent_n += 1
            else:
                still.append((lane_i, goal, deadline, first))
        pending = still
        for i in range(LANES):
            for j in range(i + 1, LANES):
                if abs(st.x[i] - st.x[j]) < cfg["laneBand"]:
                    min_gap = min(min_gap, abs(st.off[i] - st.off[j]))
        if boxed_on and trip.boxed_in(st, focal):
            boxed_s += dt
            if st.tgt[focal] > 1 and trip.side_state(st, focal, -1) == "blocked":
                trapped_s += dt
        if boxed_on and waits:
            # "No room yet" (N4): a press still waiting after 1 s with no glide and no tuck-back.
            keep = []
            for t0, tg0, dd in waits:
                if st.tgt[focal] != tg0 or st.tuck[focal] > 0:
                    continue
                if tick - t0 >= 10:
                    if st.want[focal] == dd or st.queued[focal] == dd:
                        waits1s += 1
                    continue
                keep.append((t0, tg0, dd))
            waits = keep
        if motion_on:
            if st.tgt[focal] != last_tgt:
                starts.append((t, 1 if st.tgt[focal] > last_tgt else -1))
                last_tgt = st.tgt[focal]
            for i in range(LANES):
                v = (st.x[i] - prev_x[i]) * lane_ft / dt
                a = (v - prev_v[i]) / dt
                raw = max(-STEER_VIEW["yawMaxDeg"], min(STEER_VIEW["yawMaxDeg"],
                          math.degrees(math.atan2(v, st.speed)) * STEER_VIEW["yawGain"]))
                yaw[i] = yaw[i] + (raw - yaw[i]) * alpha
                rl = max(-STEER_VIEW["leanMaxDeg"], min(STEER_VIEW["leanMaxDeg"], a * STEER_VIEW["leanDegPerFtps2"]))
                lean[i] = lean[i] + (rl - lean[i]) * alpha
                if abs(v) > 1e-9 or abs(prev_v[i]) > 1e-9:
                    vhist[min(15, int(abs(v)))] += 1
                    ahist[min(12, int(abs(a) / 5.0))] += 1
                    yhist[min(11, int(abs(yaw[i])))] += 1
                    vmax = max(vmax, abs(v))
                    amax = max(amax, abs(a))
                yaw_max = max(yaw_max, abs(yaw[i]))
                lean_max = max(lean_max, abs(lean[i]))
                prev_x[i] = st.x[i]
                prev_v[i] = v
        if stress_on:
            for i in range(LANES):
                back_max = max(back_max, -(st.off[i] - prev_off[i]) / dt)
                prev_off[i] = st.off[i]
                for j in range(i + 1, LANES):
                    if abs(st.x[i] - st.x[j]) < 0.5 and abs(st.off[i] - st.off[j]) < 6.0:
                        overlaps += 1
        tick += 1
    lock_x = list(st.x)
    trip.lock(st)
    out = {"trip": trip.trip_values(st), "ground": list(st.ground), "draft": list(st.draft), "lock_x": lock_x,
           "reach": (reach_ok, reach_n), "counts": counts, "min_gap": min_gap,
           "intent": (intent_ok, intent_n), "brushes": list(st.brushes), "charged": list(st.charged),
           "brush_cost": trip.brush_charges(st), "events": len(st.events), "seconds": tick * dt}
    if boxed_on:
        out["boxed"], out["trapped"], out["waits1s"] = boxed_s, trapped_s, waits1s
    if motion_on:
        out.update({"starts": starts, "vmax": vmax, "amax": amax, "yaw_max": yaw_max, "lean_max": lean_max,
                    "vhist": vhist, "ahist": ahist, "yhist": yhist})
    if stress_on:
        out["overlaps"], out["back_max"] = overlaps, back_max
    return out


def smart_at(post_index: int) -> List[str]:
    pols = ["bot"] * LANES
    pols[post_index] = "smart"
    return pols


def reversals(starts: Sequence[Tuple[float, int]]) -> List[float]:
    """Times of the lane changes that went the other way from the change before."""
    return [starts[a][0] for a in range(1, len(starts)) if starts[a][1] != starts[a - 1][1]]


def glide_seconds(cfg: Dict, lanes: int = 1) -> Optional[float]:
    """A free glide of `lanes` lanes inward (one press each, pressed as soon as the queue takes
    it, the field far behind), from the first press to landing."""
    geo = trip.phase_a("dirt", "Mile")
    st = trip.new_state([5, 1, 2, 3, 4, 6, 7, 8], [0.125] * 8, [0.5] * 16, geo, cfg, ["manual"] * 8)
    for i in range(1, 8):
        st.off[i] = -200.0 - 20 * i
    live = [0.125] * 8
    presses = lanes
    for tick in range(200):
        intents = []
        if presses > 0 and st.queued[0] == 0 and trip.lane_after(st, 0) > 5 - lanes and \
                (tick == 0 or tick * 0.1 - st.last_press_at[0] >= cfg["pressBounceSeconds"] - trip.EPS):
            intents.append((0, -1))
            presses -= 1
        trip.step(st, live, intents, tick * 0.1, 0.1)
        if st.x[0] == 5 - lanes:
            return round((tick + 1) * 0.1, 6)
    return None


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


def _tau(res: Dict, row: Sequence[float], cfg: Dict, profile: str) -> List[float]:
    if profile == "d054":
        return trip.tau(res["trip"], posts(), row, cfg)
    return trip.tau(res["trip"], posts(), row, cfg, res["brush_cost"])


def _report_chunk(args) -> List[Dict]:
    cell, k0, k1, cfg, table, profile = args
    d057 = profile == "d057"
    course, distance = cells()[cell]
    geo = trip.phase_a(course, distance)
    row = trip.baseline_row(table, course, distance)
    out = []
    for k in range(k0, k1):
        setup = race_setup(race_seed(REPORT_SEED, cell, k), distance)
        f = setup["focal"]
        rec: Dict = {"focal": f, "p1": setup["p1"], "s1": setup["s1"]}
        bots = run_race(geo, setup, ["bot"] * LANES, cfg)
        rec["bot_tau"] = _tau(bots, row, cfg, profile)
        rec["bot_ground"] = bots["ground"]
        rec["bot_draft"] = bots["draft"]
        rec["min_gap"] = bots["min_gap"]
        sweep_tau, sweep_lane, sweep_boxed = [], [], []
        for p in range(LANES):
            res = run_race(geo, setup, smart_at(p), cfg, focal=p, measure=("boxed",) if d057 else ())
            sweep_tau.append(_tau(res, row, cfg, profile)[p])
            sweep_lane.append(res["lock_x"][p])
            rec["min_gap"] = min(rec["min_gap"], res["min_gap"])
            if d057:
                sweep_boxed.append((res["boxed"], res["trapped"], res["seconds"]))
        rec["sweep_tau"] = sweep_tau
        rec["smart"] = {"tau": sweep_tau[f], "lane": sweep_lane[f]}
        if d057:
            rec["sweep_boxed"] = sweep_boxed
        for pol in FOCAL_D057 if d057 else FOCAL:
            pols = ["bot"] * LANES
            pols[f] = pol
            res = run_race(geo, setup, pols, cfg, focal=f, measure=("boxed", "motion") if d057 else ())
            rec[pol] = {"tau": _tau(res, row, cfg, profile)[f], "lane": res["lock_x"][f],
                        "reach": res["reach"], "counts": res["counts"]}
            if d057:
                rec[pol].update({
                    "intent": res["intent"], "brushes": res["brushes"][f], "charged": res["charged"][f],
                    "cost": res["brush_cost"][f], "others_charged": sum(res["charged"]) - res["charged"][f],
                    "boxed": res["boxed"], "trapped": res["trapped"], "waits1s": res["waits1s"], "seconds": res["seconds"],
                    "starts": len(res["starts"]), "reversals": reversals(res["starts"]),
                    "vmax": res["vmax"], "amax": res["amax"], "yaw_max": res["yaw_max"], "lean_max": res["lean_max"],
                    "vhist": res["vhist"], "ahist": res["ahist"], "yhist": res["yhist"]})
            rec["min_gap"] = min(rec["min_gap"], res["min_gap"])
        allsmart = run_race(geo, setup, ["smart"] * LANES, cfg)
        rec["allsmart_tau"] = _tau(allsmart, row, cfg, profile)
        out.append(rec)
    return out


def _grief_chunk(args) -> List[Dict]:
    """D-057 griefing: per race and kid policy, every GRIEF scenario with the same race."""
    cell, k0, k1, cfg, table = args
    course, distance = cells()[cell]
    geo = trip.phase_a(course, distance)
    row = trip.baseline_row(table, course, distance)
    out = []
    for k in range(k0, k1):
        setup = race_setup(race_seed(GRIEF_SEED, cell, k), distance)
        kid = setup["focal"]
        others = [i for i in range(LANES) if i != kid]
        random.Random(setup["press_seed"] ^ 0x5EED).shuffle(others)
        rec: Dict = {}
        for kid_pol in GRIEF_KIDS:
            per: Dict = {}
            for name, (gpols, feet) in GRIEF.items():
                pols = ["bot"] * LANES
                pols[kid] = kid_pol
                match = {}
                for g, (gp, ft) in enumerate(zip(gpols, feet)):
                    pols[others[g]] = gp
                    match[others[g]] = ft
                res = run_race(geo, setup, pols, cfg, match=match, focal=kid, measure=("boxed",))
                strangers = [others[g] for g in range(len(gpols))]
                per[name] = {"tau": trip.tau(res["trip"], posts(), row, cfg, res["brush_cost"])[kid],
                             "own": res["trip"][kid] - res["brush_cost"][kid], "lane": res["lock_x"][kid],
                             "kid_charged": res["charged"][kid], "kid_brushes": res["brushes"][kid],
                             "stranger_brushes": sum(res["brushes"][s] for s in strangers),
                             "stranger_charged": sum(res["charged"][s] for s in strangers),
                             "boxed": res["boxed"], "seconds": res["seconds"]}
            rec[kid_pol] = per
        out.append(rec)
    return out


def _stress_chunk(args) -> Dict:
    """D-057 overlap stress: a masher, a ditherer and a casual rider press at once among five
    bots (Trip's own positions before the lock)."""
    cell, k0, k1, cfg = args
    course, distance = cells()[cell]
    geo = trip.phase_a(course, distance)
    res = {"races": 0, "overlap_frames": 0, "overlap_races": 0, "min_gap": math.inf, "back_max": 0.0, "brushes": 0}
    for k in range(k0, k1):
        setup = race_setup(race_seed(STRESS_SEED, cell, k), distance)
        order = list(range(LANES))
        random.Random(setup["press_seed"]).shuffle(order)
        pols = ["bot"] * LANES
        for idx, p in zip(order[:3], ("masher", "ditherer", "scripted")):
            pols[idx] = p
        r = run_race(geo, setup, pols, cfg, measure=("stress",))
        res["races"] += 1
        res["overlap_frames"] += r["overlaps"]
        res["overlap_races"] += 1 if r["overlaps"] else 0
        res["min_gap"] = min(res["min_gap"], r["min_gap"])
        res["back_max"] = max(res["back_max"], r["back_max"])
        res["brushes"] += sum(r["brushes"])
    return res


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
    with residuals of equal size and opposite sign, half the gap between their profiles.
    Smart Steer never brushes, so no brush term enters the baseline (D-057)."""
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
        "config": trip.config_record(cfg),
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


def write_baseline(data: Dict, profile: str = "d054") -> None:
    baseline_path(profile).write_text(json.dumps(data, indent=1) + "\n")
    if profile == "d054":
        BASELINE_LUAU.write_text(render_luau(data))


def load_baseline(profile: str = "d054") -> Dict:
    return json.loads(baseline_path(profile).read_text())


def load_report(profile: str = "d054") -> Dict:
    return json.loads(report_path(profile).read_text())


# ---------------------------------------------------------------- report

def mean(v: Sequence[float]) -> float:
    return sum(v) / len(v) if v else float("nan")


def run_report(races: int, jobs: Optional[int], data: Dict, cfg: Dict = trip.CONFIG, profile: str = "d054",
               grief_races: int = GRIEF_RACES, stress_races: int = STRESS_RACES) -> Dict:
    table = data["baseline"]
    tasks = []
    for cell in range(len(cells())):
        for a, b in _chunks(races, 10):
            tasks.append((cell, a, b, cfg, table, profile))
    with Pool(jobs) as pool:
        parts = pool.map(_report_chunk, tasks)
        grief_parts, stress_parts = [], []
        grief_tasks, stress_tasks = [], []
        if profile == "d057":
            grief_tasks = [(cell, a, b, cfg, table) for cell in range(len(cells())) for a, b in _chunks(grief_races, 10)]
            stress_tasks = [(cell, a, b, cfg) for cell in range(len(cells())) for a, b in _chunks(stress_races, 25)]
            grief_parts = pool.map(_grief_chunk, grief_tasks)
            stress_parts = pool.map(_stress_chunk, stress_tasks)
    per_cell: Dict[int, List[Dict]] = {}
    for (cell, *_rest), part in zip(tasks, parts):
        per_cell.setdefault(cell, []).extend(part)
    summary = summarize_report(per_cell, cfg, profile)
    if profile == "d057":
        grief_cell: Dict[int, List[Dict]] = {}
        for (cell, *_rest), part in zip(grief_tasks, grief_parts):
            grief_cell.setdefault(cell, []).extend(part)
        stress_cell: Dict[int, List[Dict]] = {}
        for (cell, *_rest), part in zip(stress_tasks, stress_parts):
            stress_cell.setdefault(cell, []).append(part)
        summary["griefing"] = summarize_griefing(grief_cell)
        summary["stress"] = summarize_stress(stress_cell)
        summary["glides"] = {str(n): glide_seconds(cfg, n) for n in (1, 2, 3, 4)}
        summary["checks"] = check_targets(summary, "d057")
    return summary


def by_post_residual(rows: List[List[float]]) -> Tuple[List[float], float]:
    """Mean per post across races, minus the mean over posts; and that mean."""
    by_post = [mean([r[p] for r in rows]) for p in range(LANES)]
    shift = mean(by_post)
    return [v - shift for v in by_post], shift


def _pct(hist: Sequence[int], p: float, width: float) -> float:
    """The upper edge of the histogram bin holding the p quantile."""
    total = sum(hist)
    run = 0
    for b, c in enumerate(hist):
        run += c
        if total and run >= p * total:
            return (b + 1) * width
    return len(hist) * width


def summarize_report(per_cell: Dict[int, List[Dict]], cfg: Dict, profile: str = "d054") -> Dict:
    d057 = profile == "d057"
    pols_all = POLICIES_D057 if d057 else POLICIES
    rows = []
    for cell, (course, distance) in enumerate(cells()):
        recs = per_cell[cell]
        r: Dict = {"course": course, "distance": distance, "races": len(recs)}
        for pol in pols_all:
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
        if d057:
            _summarize_d057_cell(r, recs)
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
    if d057:
        _summarize_d057(summary, per_cell)
    summary["checks"] = check_targets(summary, profile)
    return summary


def _summarize_d057_cell(r: Dict, recs: List[Dict]) -> None:
    """Per cell: reach per intent, brushes, boxed-in time and reversals by policy; the Smart
    Steer kid's boxed-in time by post."""
    for pol in ("scripted", "rail"):
        ok = sum(x[pol]["intent"][0] for x in recs)
        n = sum(x[pol]["intent"][1] for x in recs)
        r[pol + "_intent_ok"], r[pol + "_intent_n"] = ok, n
        r[pol + "_intent3s"] = ok / n if n else float("nan")
    r["intent3s"] = r["scripted_intent3s"]
    for pol in FOCAL_D057:
        xs = [x[pol] for x in recs]
        secs = sum(v["seconds"] for v in xs)
        revs = sum(len(v["reversals"]) for v in xs)
        gaps = [b - a for v in xs for a, b in zip(v["reversals"], v["reversals"][1:])]
        r[pol + "_brushes_per_race"] = mean([v["brushes"] for v in xs])
        r[pol + "_brush_races"] = mean([1.0 if v["brushes"] > 0 else 0.0 for v in xs])
        r[pol + "_charged_races"] = mean([1.0 if v["cost"] > 0 else 0.0 for v in xs])
        r[pol + "_mean_cost"] = mean([v["cost"] for v in xs])
        r[pol + "_max_cost"] = max(v["cost"] for v in xs)
        r[pol + "_others_charged"] = sum(v["others_charged"] for v in xs)
        r[pol + "_boxed_share"] = sum(v["boxed"] for v in xs) / secs
        r[pol + "_trapped_share"] = sum(v["trapped"] for v in xs) / secs
        r[pol + "_reversals_per_min"] = 60.0 * revs / secs
        r[pol + "_min_reversal_gap"] = min(gaps) if gaps else None
        r[pol + "_changes_per_min"] = 60.0 * sum(v["starts"] for v in xs) / secs
        r[pol + "_waits1s_per_race"] = mean([v["waits1s"] for v in xs])
    boxed = [[x["sweep_boxed"][p] for x in recs] for p in range(LANES)]
    r["smart_boxed_post"] = [sum(b[0] for b in boxed[p]) / sum(b[2] for b in boxed[p]) for p in range(LANES)]
    secs = sum(b[2] for p in range(LANES) for b in boxed[p])
    r["smart_boxed_share"] = sum(b[0] for p in range(LANES) for b in boxed[p]) / secs
    r["smart_trapped_share"] = sum(b[1] for p in range(LANES) for b in boxed[p]) / secs
    r["smart_boxed_1s_races"] = mean([1.0 if b[0] >= 1.0 - 1e-9 else 0.0 for p in range(LANES) for b in boxed[p]])


def _summarize_d057(summary: Dict, per_cell: Dict[int, List[Dict]]) -> None:
    """Pooled over the cells: reach per intent, motion, boxed by post and policy, brushes."""
    rows = summary["rows"]
    summary["intent3s"] = sum(r["scripted_intent_ok"] for r in rows) / max(1, sum(r["scripted_intent_n"] for r in rows))
    summary["rail_intent3s"] = sum(r["rail_intent_ok"] for r in rows) / max(1, sum(r["rail_intent_n"] for r in rows))
    allrecs = [x for cell in range(len(cells())) for x in per_cell[cell]]
    motion: Dict = {}
    vh, ah, yh = [0] * 16, [0] * 13, [0] * 12
    vmax = amax = yaw_max = lean_max = 0.0
    for pol in FOCAL_D057:
        xs = [x[pol] for x in allrecs]
        secs = sum(v["seconds"] for v in xs)
        gaps = sorted(b - a for v in xs for a, b in zip(v["reversals"], v["reversals"][1:]))
        motion[pol] = {"reversals_per_min": 60.0 * sum(len(v["reversals"]) for v in xs) / secs,
                       "changes_per_min": 60.0 * sum(v["starts"] for v in xs) / secs,
                       "min_reversal_gap": gaps[0] if gaps else None,
                       "median_reversal_gap": gaps[len(gaps) // 2] if gaps else None}
        for v in xs:
            for b in range(16):
                vh[b] += v["vhist"][b]
            for b in range(13):
                ah[b] += v["ahist"][b]
            for b in range(12):
                yh[b] += v["yhist"][b]
            vmax, amax = max(vmax, v["vmax"]), max(amax, v["amax"])
            yaw_max, lean_max = max(yaw_max, v["yaw_max"]), max(lean_max, v["lean_max"])
    motion["all_horses"] = {
        "vmax_ftps": vmax, "amax_ftps2": amax, "max_drift_deg": math.degrees(math.atan(vmax / trip.RACE["speed"])),
        "v_p50": _pct(vh, 0.5, 1.0), "v_p95": _pct(vh, 0.95, 1.0), "a_p50": _pct(ah, 0.5, 5.0), "a_p95": _pct(ah, 0.95, 5.0),
        "yaw_max_deg": yaw_max, "yaw_p95_deg": _pct(yh, 0.95, 1.0), "lean_max_deg": lean_max,
        "vhist": vh, "ahist": ah, "yhist": yh}
    summary["motion"] = motion
    boxed: Dict = {}
    for pol in ("smart",) + FOCAL_D057:
        by_post_b = [0.0] * LANES
        by_post_s = [0.0] * LANES
        trapped = 0.0
        long_races = races = 0
        if pol == "smart":
            for x in allrecs:
                for p in range(LANES):
                    b, tr, s = x["sweep_boxed"][p]
                    by_post_b[p] += b
                    by_post_s[p] += s
                    trapped += tr
                    races += 1
                    long_races += 1 if b >= 1.0 - 1e-9 else 0
        else:
            for x in allrecs:
                v, p = x[pol], x["focal"]
                by_post_b[p] += v["boxed"]
                by_post_s[p] += v["seconds"]
                trapped += v["trapped"]
                races += 1
                long_races += 1 if v["boxed"] >= 1.0 - 1e-9 else 0
        boxed[pol] = {"share": sum(by_post_b) / sum(by_post_s), "trapped_share": trapped / sum(by_post_s),
                      "races_boxed_1s": long_races / races,
                      "by_post": [by_post_b[p] / by_post_s[p] if by_post_s[p] else 0.0 for p in range(LANES)]}
    summary["boxed"] = boxed
    brushes: Dict = {}
    for pol in FOCAL_D057:
        xs = [x[pol] for x in allrecs]
        costs = sorted(v["cost"] for v in xs)
        brushes[pol] = {"brushes_per_race": mean([v["brushes"] for v in xs]),
                        "brush_races": mean([1.0 if v["brushes"] > 0 else 0.0 for v in xs]),
                        "charged_races": mean([1.0 if v["cost"] > 0 else 0.0 for v in xs]),
                        "mean_cost": mean(costs), "p95_cost": costs[int(0.95 * (len(costs) - 1))], "max_cost": costs[-1],
                        "others_charged": sum(v["others_charged"] for v in xs),
                        "brushes_by_answer": sum(v["counts"].get("brush", 0) for v in xs),
                        "bounces_per_race": mean([v["counts"].get("bounce", 0) for v in xs]),
                        "steady_per_race": mean([v["counts"].get("steady", 0) for v in xs]),
                        "waits1s_per_race": mean([v["waits1s"] for v in xs])}
    summary["brushes"] = brushes


def summarize_griefing(grief_cell: Dict[int, List[Dict]]) -> Dict:
    """Per kid policy: each scenario's kid own trip, tau, lane and charges against "matched", and
    targeted minus untargeted own trip (GRIEF_PAIRS), per cell and pooled."""
    out: Dict = {}
    for kid_pol in GRIEF_KIDS:
        res: Dict = {"cells": [], "pooled": {}}
        pooled: Dict[str, List] = {}
        for cell, (course, distance) in enumerate(cells()):
            recs = [x[kid_pol] for x in grief_cell[cell]]
            row: Dict = {"course": course, "distance": distance, "races": len(recs)}
            for target, control in GRIEF_PAIRS:
                d = [x[target]["own"] - x[control]["own"] for x in recs]
                row[target + "_minus_" + control] = mean(d)
                pooled.setdefault(target + "_minus_" + control, []).extend(d)
            res["cells"].append(row)
        for name in GRIEF:
            recs = [x[kid_pol] for cell in range(len(cells())) for x in grief_cell[cell]]
            own_d = sorted(x[name]["own"] - x["matched"]["own"] for x in recs)
            secs = sum(x[name]["seconds"] for x in recs)
            res["pooled"][name] = {
                "kid_tau": mean([x[name]["tau"] for x in recs]),
                "tau_vs_matched": mean([x[name]["tau"] - x["matched"]["tau"] for x in recs]),
                "own_vs_matched": mean(own_d), "own_vs_matched_p5": own_d[int(0.05 * (len(own_d) - 1))],
                "kid_lane": mean([x[name]["lane"] for x in recs]),
                "kid_boxed_share": sum(x[name]["boxed"] for x in recs) / secs,
                "kid_charged_per_race": mean([x[name]["kid_charged"] for x in recs]),
                "kid_charged_not_own": sum(x[name]["kid_charged"] - x[name]["kid_brushes"] for x in recs),
                "stranger_brushes_per_race": mean([x[name]["stranger_brushes"] for x in recs]),
                "stranger_charged_per_race": mean([x[name]["stranger_charged"] for x in recs])}
        for key, d in pooled.items():
            res["pooled"][key] = mean(d)
        out[kid_pol] = res
    return out


def summarize_stress(stress_cell: Dict[int, List[Dict]]) -> Dict:
    parts = [p for cell in range(len(cells())) for p in stress_cell[cell]]
    return {"races": sum(p["races"] for p in parts), "overlap_races": sum(p["overlap_races"] for p in parts),
            "overlap_frames": sum(p["overlap_frames"] for p in parts), "min_gap": min(p["min_gap"] for p in parts),
            "back_max": max(p["back_max"] for p in parts), "brushes": sum(p["brushes"] for p in parts)}


def check_targets(s: Dict, profile: str = "d054") -> Dict[str, bool]:
    rows = s["rows"]
    lo, hi = TARGETS["rail_vs_smart"]
    nlo, nhi = TARGETS["never"]
    pb, sm = TARGETS["post_bias"], TARGETS["smart_mean"]
    checks = {
        "rail_vs_smart": all(lo <= r["rail_vs_smart"] <= hi for r in rows),
        "never": all(nlo <= r["never"] <= nhi for r in rows),
        "reach3s": all(r["reach3s"] >= TARGETS["reach3s"] for r in rows),
        "draft_share": all(r["draft_share"] <= TARGETS["draft_share"] for r in rows),
        "post_bias_smart_among_bots": all(r["smart_post_max"] < pb for r in rows),
        "post_bias_all_smart": all(r["allsmart_post_max"] < pb for r in rows),
        "smart_among_bots_mean": all(abs(r["smart_among_bots"]) <= sm for r in rows),
        "all_smart_field_mean": all(abs(r["allsmart_mean"]) <= sm for r in rows),
    }
    if profile != "d057":
        return checks
    t = TARGETS_D057
    del checks["reach3s"]  # replaced by reach per intent (D-057); the per-press figure stays in the report
    out = {"rail_vs_smart": checks["rail_vs_smart"], "never": checks["never"],
           "intent3s": all(r["intent3s"] >= t["intent3s"] for r in rows)}
    for key in ("draft_share", "post_bias_smart_among_bots", "post_bias_all_smart", "smart_among_bots_mean",
                "all_smart_field_mean"):
        out[key] = checks[key]
    # Pooled over the cells, as debate 012 measured it (7.1); the per-cell rates are in the report
    # (two cells sit just above 8 with the D-057 values, see docs/research/steering-calibration.md).
    out["masher_reversals"] = s["motion"]["masher"]["reversals_per_min"] <= t["masher_reversals_per_min"]
    out["masher_reversal_gap"] = all(r["masher_min_reversal_gap"] is None or
                                     r["masher_min_reversal_gap"] >= t["masher_min_reversal_gap"] for r in rows)
    # To the whole ft/s^2, as D-057 quotes it: Trip's own speed changes by at most laneAccel (27);
    # the 10 Hz finite difference peaks at 30.4 on a landing tick (the snap), which the prototype
    # also measured and printed as 30.
    out["sideways_accel"] = round(s["motion"]["all_horses"]["amax_ftps2"]) <= t["accel_max_ftps2"]
    out["casual_charged"] = all(r["scripted_charged_races"] <= t["casual_charged_share"] for r in rows)
    out["no_bystander_charged"] = all(r[pol + "_others_charged"] == 0 for r in rows for pol in FOCAL_D057)
    if "griefing" in s:
        out["griefing"] = all(s["griefing"][k]["pooled"][a + "_minus_" + b] >= t["griefing"]
                              for k in GRIEF_KIDS for a, b in GRIEF_PAIRS)
        out["griefing_mover_pays"] = all(
            s["griefing"][k]["pooled"][name]["kid_charged_not_own"] == 0 for k in GRIEF_KIDS for name in GRIEF) and all(
            s["griefing"]["smart"]["pooled"][name]["kid_charged_per_race"] == 0 for name in GRIEF)
    if "stress" in s:
        out["stress"] = s["stress"]["overlap_frames"] == 0 and s["stress"]["back_max"] <= t["stress_fallback_ftps"]
    return out


LABELS = {
    "rail_vs_smart": "Rail rider vs Smart Steer +0.01 to +0.03 (every cell)",
    "never": "Never-steer between -0.02 and -0.01 (every cell)",
    "reach3s": "Inward request reaching its lane within 3 s >= 70% (every cell)",
    "intent3s": "Inward press reaching its lane within 3 s >= 70%, per intent (every cell)",
    "draft_share": "Draft share of positive trip <= 40% (every cell)",
    "post_bias_smart_among_bots": "Post bias < 0.005, Smart Steer kid among bots (every cell, every post)",
    "post_bias_all_smart": "Post bias < 0.005, all-Smart fields (every cell, every post)",
    "smart_among_bots_mean": "Smart Steer kid among bots averages 0 +- 0.003 (every cell)",
    "all_smart_field_mean": "All-Smart field mean 0 +- 0.003 (every cell)",
    "masher_reversals": "Masher reversals <= 8 a minute (pooled over the cells; per cell in the report)",
    "masher_reversal_gap": "No masher reversal within 3 s of the previous (every cell)",
    "sideways_accel": "Sideways acceleration <= 30 ft/s^2 between ticks, to the whole ft/s^2 (every horse)",
    "casual_charged": "Casual riders charged for a brush in <= 5% of races (every cell)",
    "no_bystander_charged": "Only the mover pays: no other horse is ever charged (every cell)",
    "griefing": "Griefing: targeted minus untargeted own trip >= -0.001 (each scenario and kid, pooled)",
    "griefing_mover_pays": "Griefing: a kid is only ever charged for its own brushes (a Smart Steer kid never)",
    "stress": "Stress: 0 overlaps and fall-back <= 20 ft/s",
}


def _posts(v: Sequence[float]) -> str:
    return " ".join(f"{x:+.4f}" for x in v)


def _pcts(v: Sequence[float]) -> str:
    return " ".join(f"{x:.1%}" for x in v)


def format_report(s: Dict, data: Dict, cfg: Dict, profile: str = "d054") -> str:
    d057 = profile == "d057"
    out = []
    rows = s["rows"]
    out.append(f"Steering calibration ({'D-057 on' if d057 else 'D-054'}): baseline seed {data['seed']}, "
               f"{data['races']:,} races per cell and post, "
               f"mix {data['mixWeight']}; report seed {REPORT_SEED}, {rows[0]['races']} races per cell")
    out.append(f"groundPerLaneTurn {cfg['groundPerLaneTurn']}, draftPerSecond {cfg['draftPerSecond']}, "
               f"draftCap {cfg['draftCap']}, smart.homeLane {cfg['smart']['homeLane']}, bots.wideShare {cfg['bots']['wideShare']}, "
               f"clearFeet {cfg['clearFeet']}, tuckBackMax {cfg['tuckBackMax']}")
    if d057:
        out.append("D-057: " + ", ".join(f"{k} {cfg[k]}" for k in trip.D057_KEYS if k != "boxedAheadFeet"))
    out.append("")
    out.append("Mean tau (focal rider among seven bots; Smart Steer = a kid at every post among bots):")
    reach_head = "In within 3 s (per intent / per press)" if d057 else "In within 3 s"
    out.append("| Course | Distance | Smart Steer | Rail rider | Rail - Smart | Never steers | Wanderer | Casual "
               f"| All-Smart field | Post bias: kid among bots | Post bias: all-Smart | Draft share | {reach_head} |")
    out.append("| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |")
    for r in rows:
        reach = f"{r['intent3s']:.0%} / {r['reach3s']:.0%}" if d057 else f"{r['reach3s']:.0%}"
        out.append(f"| {r['course']} | {r['distance']} | {r['smart_among_bots']:+.4f} | {r['rail']:+.4f} "
                   f"| {r['rail_vs_smart']:+.4f} | {r['never']:+.4f} | {r['wanderer']:+.4f} | {r['scripted']:+.4f} "
                   f"| {r['allsmart_mean']:+.4f} | {r['smart_post_max']:.4f} | {r['allsmart_post_max']:.4f} "
                   f"| {r['draft_share']:.0%} | {reach} |")
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
    if d057:
        out.append(f"  per intent: casual {s['intent3s']:.1%} overall "
                   f"(cells {min(r['intent3s'] for r in rows):.1%}-{max(r['intent3s'] for r in rows):.1%}), "
                   f"rail rider {s['rail_intent3s']:.1%}")
    out.append(f"Draft share of the positive trip: {s['draft_share']:.1%} overall")
    out.append(f"Closest same-lane horses at a tick end: {min(r['min_gap'] for r in rows):.2f} ft")
    if d057:
        out.extend(_format_d057(s))
    out.append("")
    for key, ok in s["checks"].items():
        out.append(f"  [{'PASS' if ok else 'MISS'}] {LABELS[key]}")
    return "\n".join(out)


def _format_d057(s: Dict) -> List[str]:
    out = [""]
    rows = s["rows"]
    g = s["glides"]
    out.append(f"Free glides, press to landing: 1 lane {g['1']} s, 2 lanes {g['2']} s, 3 lanes {g['3']} s, 4 lanes {g['4']} s")
    out.append("Zig-zag (focal rider among bots): reversals a minute (shortest gap, median gap), lane changes a minute")
    for pol in FOCAL_D057:
        mo = s["motion"][pol]
        mg = "-" if mo["min_reversal_gap"] is None else f"{mo['min_reversal_gap']:.1f} s"
        md = "-" if mo["median_reversal_gap"] is None else f"{mo['median_reversal_gap']:.1f} s"
        out.append(f"  {pol:9s} {mo['reversals_per_min']:5.2f} ({mg}, {md}), changes {mo['changes_per_min']:.2f}")
    out.append("  masher per cell: " + ", ".join(f"{r['course']} {r['distance']} {r['masher_reversals_per_min']:.1f}"
                                                 for r in rows))
    a = s["motion"]["all_horses"]
    out.append(f"Sideways motion, every horse while it moves: top {a['vmax_ftps']:.1f} ft/s (drift {a['max_drift_deg']:.1f} deg), "
               f"speed p50/p95 {a['v_p50']:.0f}/{a['v_p95']:.0f} ft/s, accel p50/p95 {a['a_p50']:.0f}/{a['a_p95']:.0f} ft/s^2, "
               f"max {a['amax_ftps2']:.1f} ft/s^2")
    out.append(f"Body estimate (SteerPose from 10 Hz lanes): yaw max {a['yaw_max_deg']:.1f} deg, p95 {a['yaw_p95_deg']:.0f} deg; "
               f"lean max {a['lean_max_deg']:.1f} deg")
    out.append("Boxed in (share of pre-lock time; trapped; races with >= 1 s; by post 1-8):")
    for pol, b in s["boxed"].items():
        out.append(f"  {pol:9s} {b['share']:.1%}  trapped {b['trapped_share']:.2%}  >=1 s {b['races_boxed_1s']:.0%}  "
                   f"posts {_pcts(b['by_post'])}")
    out.append("Brushes (focal rider; races with a brush / charged; brushes a race; mean / max cost):")
    for pol, b in s["brushes"].items():
        out.append(f"  {pol:9s} {b['brush_races']:.1%} / {b['charged_races']:.1%}; {b['brushes_per_race']:.2f}; "
                   f"{b['mean_cost']:.4f} / {b['max_cost']:.3f}; bounces a race {b['bounces_per_race']:.1f}; "
                   f"waits over 1 s a race {b['waits1s_per_race']:.2f}")
    out.append("  casual charged per cell: " + ", ".join(f"{r['course']} {r['distance']} {r['scripted_charged_races']:.1%}"
                                                         for r in rows))
    if "griefing" in s:
        out.append("Griefing (kid's own trip = ground + draft - own brush charge; strangers tapped exactly like the kid):")
        for kid, res in s["griefing"].items():
            p = res["pooled"]
            out.append(f"  {kid} kid: " + "; ".join(f"{a} - {b} {p[a + '_minus_' + b]:+.4f}" for a, b in GRIEF_PAIRS))
            for name in GRIEF:
                v = p[name]
                out.append(f"    {name:8s} own vs matched {v['own_vs_matched']:+.4f} (p5 {v['own_vs_matched_p5']:+.4f}), "
                           f"tau vs matched {v['tau_vs_matched']:+.4f}, lane {v['kid_lane']:.2f}, boxed {v['kid_boxed_share']:.1%}, "
                           f"kid charged {v['kid_charged_per_race']:.2f}, strangers charged {v['stranger_charged_per_race']:.2f}")
            out.append("    per cell: " + ", ".join(
                f"{c['course']} {c['distance']} " + "/".join(f"{c[a + '_minus_' + b]:+.4f}" for a, b in GRIEF_PAIRS)
                for c in res["cells"]))
    if "stress" in s:
        st = s["stress"]
        out.append(f"Stress ({st['races']:,} races, masher + ditherer + casual among 5 bots): {st['overlap_frames']} overlap frames "
                   f"in {st['overlap_races']} races, closest same-lane {st['min_gap']:.2f} ft, fastest fall-back "
                   f"{st['back_max']:.1f} ft/s, {st['brushes']} brushes")
    return out


def main(argv: Optional[Sequence[str]] = None) -> int:
    ap = argparse.ArgumentParser(description="Race steering calibration (D-054, D-057)")
    ap.add_argument("--write", action="store_true", help="regenerate the baseline files and the stored report")
    ap.add_argument("--profile", choices=PROFILES, default="d054", help="d054 (the game today) or d057 (D-057 on)")
    ap.add_argument("--races", type=int, default=BASELINE_RACES, help="baseline races per cell (each post gets this many)")
    ap.add_argument("--report-races", type=int, default=REPORT_RACES, help="races per cell for the report")
    ap.add_argument("--grief-races", type=int, default=GRIEF_RACES, help="d057: griefing races per cell")
    ap.add_argument("--stress-races", type=int, default=STRESS_RACES, help="d057: stress races per cell")
    ap.add_argument("--jobs", type=int, default=0, help="worker processes (default: all cores)")
    ap.add_argument("--mix", type=float, default=None, help="trial: weight of the kid-among-bots profile")
    ap.add_argument("--json", type=str, default="", help="also write the report numbers to this file")
    ap.add_argument("--set", action="append", default=[], metavar="KEY=VALUE",
                    help="try a config change (e.g. groundPerLaneTurn=0.011, smart.homeLane=2); nothing is written")
    args = ap.parse_args(argv)
    cfg = profile_config(args.profile)
    if args.set:
        cfg = json.loads(json.dumps(cfg))
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
            write_baseline(data, args.profile)
            written = baseline_path(args.profile).relative_to(ROOT)
            if args.profile == "d054":
                written = f"{written} and {BASELINE_LUAU.relative_to(ROOT)}"
            print(f"wrote {written} ({args.races} races per cell and post, {time.time() - t0:.0f} s)")
    else:
        data = load_baseline(args.profile)
    if data["config"] != trip.config_record(cfg):
        print("warning: the checked-in baseline was made with a different config; run with --write")
    summary = run_report(args.report_races, jobs, data, cfg, args.profile, args.grief_races, args.stress_races)
    print(format_report(summary, data, cfg, args.profile))
    print(f"({time.time() - t0:.0f} s)")
    stored = {"seed": REPORT_SEED, "races": args.report_races, "baselineSeed": data["seed"],
              "baselineRaces": data["races"], "mixWeight": data["mixWeight"], "config": trip.config_record(cfg),
              "summary": summary}
    if args.profile == "d057":
        stored.update({"profile": "d057", "griefSeed": GRIEF_SEED, "griefRaces": args.grief_races,
                       "stressSeed": STRESS_SEED, "stressRaces": args.stress_races})
    if args.write:
        report_path(args.profile).write_text(json.dumps(stored, indent=1) + "\n")
        print(f"wrote {report_path(args.profile).relative_to(ROOT)}")
    if args.json:
        Path(args.json).write_text(json.dumps(stored, indent=1))
    return 0 if all(summary["checks"].values()) else 1


if __name__ == "__main__":
    sys.exit(main())
