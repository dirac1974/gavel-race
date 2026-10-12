#!/usr/bin/env python3
"""Race steering calibration (D-054, D-057): the per-post trip baseline and the acceptance report.

    python sims/steering.py                  # report, using the checked-in baseline
    python sims/steering.py --write          # regenerate the baseline files and the stored report
    python sims/steering.py --set groundPerLaneTurn=0.011 --races 500 --report-races 200   # try a change
    python sims/steering.py --profile d057 --write   # brushes on too: its own baseline and report
    python sims/steering.py --profile d054 --write   # D-054 (the switch-back): its own baseline and report

Profiles:
  live  trip.CONFIG, what the game runs (since N3: D-057's motion and press rules; N5: brushes).
        --write regenerates tests/fixtures/trip_baseline.json and game/src/shared/TripBaseline.luau
        from a fixed seed, then runs the report and stores it in tests/fixtures/steering_report.json
        (tests/test_trip_d057.py asserts its targets).
  d057  trip.d057_config(): D-057 in full, brushes on (N5). --write stores
        tests/fixtures/trip_baseline_d057.json and steering_report_d057.json.
  d054  trip.d054_config(): every D-057 switch off, the game before N3. --write stores
        tests/fixtures/trip_baseline_d054.json and steering_report_d054.json (tests/test_trip.py).
        Switching the game back to D-054 means the D-057 keys back in GameConfig.steering and
        trip.CONFIG and a live --write, which then reproduces trip_baseline_d054.json's table.
Only the live profile writes TripBaseline.luau. Every race has its own seed, so --jobs never
changes a number. With any D-057 switch on (trip.d057_on), the report adds the D-057 measures:
zig-zag reversals, sideways speed and acceleration, a body yaw estimate, boxed-in time by post
and policy, brushes by policy, reach per intent, the griefing test and an overlap stress run.

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
  doubletap (N5 review, griefing kid) a press every 2-6 s, pressed again 0.3-0.8 s later
Griefers (D-057 griefing test; strangers who tapped exactly like the kid, see GRIEF):
  shadow / crew_in   sit on the kid's inside      crew_out  sit on its outside
  crew_ahead         sit in its lane              bumper    get beside it, then keep pressing into it
"""

from __future__ import annotations

import argparse
import json
import math
import os
import pickle
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
REPORT_RACES = 1000        # D-072 ruling 1: >= 1,000 report races per cell for the post bias
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
BASELINE_JSON_D054 = ROOT / "tests" / "fixtures" / "trip_baseline_d054.json"
REPORT_JSON_D054 = ROOT / "tests" / "fixtures" / "steering_report_d054.json"
PROFILES = ("live", "d057", "d054")
OVERTAKE_FEET = 8.0     # D-072 drawn overtakes (ruling 8): from a length behind to a length clear...
OVERTAKE_HOLD_TICKS = 20  # ...held this long (2 s)...
OVERTAKE_LANES = 1.5    # ...of a neighbour (within this many lanes)

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
FOCAL_D072 = FOCAL_D057 + ("lit",)  # D-072 ruling 2: the press-when-lit rider, report only
POLICIES = ("smart",) + FOCAL
POLICIES_D057 = ("smart",) + FOCAL_D057
GRIEFERS = ("shadow", "crew_in", "crew_out", "crew_ahead", "bumper")
PRESSERS = ("rail", "wanderer", "scripted", "masher", "ditherer", "doubletap") + GRIEFERS
KIND = {"bot": "bot", "smart": "smart", "rail": "smart", "never": "manual", "wanderer": "smart", "scripted": "smart",
        "masher": "smart", "ditherer": "smart", "lit": "smart", "doubletap": "smart", "shadow": "smart", "crew_in": "smart", "crew_out": "smart",
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
# D-072 phase A (race realism; consensus.md, racing-plan.md section 4).
TARGETS_D072 = {"post_bias": 0.002,          # ruling 1: kid among bots (all-Smart <= 0.003, reported)
                "allsmart_post_bias": 0.003, "style_bias": 0.002, "tau_p99": 0.04, "drift_rel": 3.0,
                "smart_mean": 0.003,        # ruling 5: a passive kid among bots nets 0 +- this
                "intent3s": 0.55, "intent6s": 0.85,  # ruling 3
                "masher_reversals_per_min": 8.0,     # ruling 4 (8.5 only if 8 still fails at weaveWindowSeconds 8)
                "passes_sprint": (1.0, 10.0), "passes": (3.0, 10.0),  # ruling 8: Trip passes a race
                "overtakes": (3.0, 15.0),   # ruling 8: drawn overtakes, a length clear held 2 s
                "pass_along_min": 0.8}      # feel: every completed pass alongside at least this long

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
# N5 review: the kids who press the most (wanderer, masher) and the one who presses again when
# nothing seems to happen (doubletap) too. Every kid is measured and reported; the targets:
# - own trip, targeted minus untargeted >= -0.001 (the D-057 bound), for the kids who steer with
#   a purpose (GRIEF_TARGET_KIDS). A stranger matched to a kid who presses at random and sitting
#   just inside it pushes it wide whatever the brush rule (brushes off too): the N5 review's
#   shadow finding, reported and queued for David (REVIEW_QUEUE), not a brush effect;
# - the brush charges strangers add (targeted minus untargeted) >= -0.001 for every kid but the
#   masher (GRIEF_BRUSH_KIDS): a natural press pattern never pays for being boxed in. A masher
#   who keeps pressing into a box pays: that is what a brush teaches.
GRIEF_KIDS = ("smart", "rail", "wanderer", "masher", "doubletap")
GRIEF_TARGET_KIDS = ("smart", "rail")
GRIEF_BRUSH_KIDS = ("smart", "rail", "wanderer", "doubletap")


def cells() -> List[Tuple[str, str]]:
    return [(c, d) for c in trip.COURSE_ORDER for d in trip.DISTANCE_ORDER]


def race_seed(base: int, cell: int, k: int) -> int:
    return (base * 16 + cell) * 1_000_000 + k


def posts() -> List[int]:
    return list(range(1, LANES + 1))


def profile_config(profile: str) -> Dict:
    if profile == "live":
        return trip.CONFIG
    if profile == "d057":
        return trip.d057_config()
    if profile == "d054":
        return trip.d054_config()
    raise ValueError(f"unknown profile {profile!r}")


def _peak_mb() -> float:
    """This process's peak working set in MB (Windows; 0 elsewhere). For --mem only."""
    try:
        import ctypes
        from ctypes import wintypes

        class PMC(ctypes.Structure):
            _fields_ = [("cb", wintypes.DWORD), ("PageFaultCount", wintypes.DWORD),
                        ("PeakWorkingSetSize", ctypes.c_size_t), ("WorkingSetSize", ctypes.c_size_t),
                        ("QuotaPeakPagedPoolUsage", ctypes.c_size_t), ("QuotaPagedPoolUsage", ctypes.c_size_t),
                        ("QuotaPeakNonPagedPoolUsage", ctypes.c_size_t), ("QuotaNonPagedPoolUsage", ctypes.c_size_t),
                        ("PagefileUsage", ctypes.c_size_t), ("PeakPagefileUsage", ctypes.c_size_t)]
        pmc = PMC()
        pmc.cb = ctypes.sizeof(PMC)
        k32 = ctypes.WinDLL("kernel32")
        psapi = ctypes.WinDLL("psapi")
        k32.GetCurrentProcess.restype = wintypes.HANDLE
        psapi.GetProcessMemoryInfo.argtypes = [wintypes.HANDLE, ctypes.POINTER(PMC), wintypes.DWORD]
        psapi.GetProcessMemoryInfo.restype = wintypes.BOOL
        psapi.GetProcessMemoryInfo(k32.GetCurrentProcess(), ctypes.byref(pmc), pmc.cb)
        return pmc.PeakWorkingSetSize / 2 ** 20
    except Exception:  # noqa: BLE001 - not Windows
        return 0.0


def _mem(label: str) -> None:
    """--mem: print this process's peak working set to stderr (never into any output)."""
    if os.environ.get("STEERING_MEM"):
        print(f"[mem] pid {os.getpid()} {label}: peak {_peak_mb():.0f} MB", file=sys.stderr, flush=True)


OUT_DIR: Optional[Path] = None  # --out: write the files here instead (a scratch run)


def _out(path: Path) -> Path:
    return path if OUT_DIR is None else OUT_DIR / path.name


def baseline_path(profile: str) -> Path:
    return {"live": BASELINE_JSON, "d057": BASELINE_JSON_D057, "d054": BASELINE_JSON_D054}[profile]


def report_path(profile: str) -> Path:
    return {"live": REPORT_JSON, "d057": REPORT_JSON_D057, "d054": REPORT_JSON_D054}[profile]


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
    press_seed = rng.getrandbits(32)
    # D-072: seven more per lane, after every earlier draw (so those keep their values)
    uniforms72 = [rng.random() for _ in range(trip.D072_UNIFORMS * LANES)]
    return {"q": q, "p1": p1, "s1": s1, "uniforms": uniforms, "focal": focal, "press_seed": press_seed,
            "uniforms72": uniforms72}


def race_uniforms(setup: Dict, cfg: Dict) -> List[float]:
    """The uniforms Trip consumes: two per lane, and D-072's seven per lane after them when on."""
    return setup["uniforms"] + setup["uniforms72"] if trip.d072_on(cfg) else setup["uniforms"]


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
        self.next_at, self.again_at, self.again_dir = -1, -1, 0  # doubletap

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
        elif p == "doubletap":
            # N5 review: an intent every 2-6 s, one press, and the same press again 0.3-0.8 s
            # later (nothing seemed to happen)
            if self.next_at < 0:
                self.next_at = tick + int(self.rng.uniform(10, 50))
            if tick == self.again_at:
                self.again_at = -1
                return self.again_dir
            if tick >= self.next_at:
                self.next_at = tick + int(self.rng.uniform(20, 60))
                d = -1 if self.rng.random() < 0.5 else 1
                after = trip.lane_after(st, i)
                if after + d < 1 or after + d > st.lanes:
                    d = -d
                self.again_dir = d
                self.again_at = tick + int(self.rng.uniform(3, 9))
                return d
        elif p == "lit":
            # D-072 ruling 2 (phase C's gate, reported now): a horse within 20 ft ahead in its lane and a
            # side with room ("lit"): press that way, outside first, at most every 0.3 s
            if tick % 3 == 0 and st.x[i] == st.tgt[i] and st.want[i] == 0 and trip.horse_ahead(st, i, 20.0):
                for d in (1, -1):
                    if trip.side_state(st, i, d) == "free":
                        return d
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
    measure (D-057 detail, slower): "boxed" (the focal horse's boxed-in time, and boxed with no
    tuck slot inside),
    "motion" (the focal horse's lane-change starts; every horse's sideways speed, acceleration
    and estimated body yaw and lean), "stress" (overlaps and the fastest fall-back)."""
    kinds = [KIND[p] for p in policies]
    st = trip.new_state(posts(), setup["q"], race_uniforms(setup, cfg), geo, cfg, kinds)
    d072 = trip.d072_on(cfg)
    pack_on = d072 and "pack" in measure
    behind: Dict[Tuple[int, int], Tuple[int, int, int]] = {}  # D-072 overtakes: (i, j) -> (order, candidate, since)
    overtakes = overtakes_straight = 0
    drift_rel = 0.0
    prev_drift: List[float] = list(st.drift)
    along_acc = [0.0] * LANES
    pass_along: List[float] = []
    ev_seen = 0
    press_rng = random.Random(setup["press_seed"])
    riders = {i: Rider(p, press_rng, focal) for i, p in enumerate(policies) if p in PRESSERS}
    dt = 1.0 / cfg["tickHz"]
    t_lock = trip.lock_time(geo)
    sw = switch_tick(geo, cfg)
    q, p1 = setup["q"], setup["p1"]
    reach_ticks = int(round(3.0 * cfg["tickHz"]))
    # (lane, goal, deadline tick, counts per press, first press of an intent). Per press (D-054):
    # inward presses answered accepted or queued. Per intent (D-057): the first inward press after
    # 3 s without presses, whatever it was answered except a refusal (bounds, invalid, locked) or
    # a bounce; an answer of cancelled, steady or brush counts too (it fails unless the horse
    # still gets there in 3 s). Steady, brush, bounce and rate need an earlier press within 3 s,
    # so in practice a first press is accepted, queued, cancelled or bounds.
    pending: List[Tuple[int, int, int, bool, bool]] = []
    reach_ok = reach_n = intent_ok = intent_n = 0
    pending6: List[Tuple[int, int, int]] = []  # D-072 ruling 3: the same intents, within 6 s
    intent6_ok = intent6_n = 0
    last_press: Dict[int, int] = {}
    counts = {"accepted": 0, "queued": 0, "cancelled": 0, "bounds": 0, "rate": 0, "locked": 0, "invalid": 0}
    min_gap = math.inf
    boxed_on, motion_on, stress_on = "boxed" in measure, "motion" in measure, "stress" in measure
    lane_ft = trip.COURSES[geo["course"]]["laneWidth"]
    boxed_s = no_tuck_s = 0.0
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
            per_press = ans in ("accepted", "queued")
            per_intent = first and ans in ("accepted", "queued", "cancelled", "steady", "brush")
            if d < 0 and (per_press or per_intent) and (tick + reach_ticks) * dt <= t_lock:
                pending.append((i, goal, tick + reach_ticks, per_press, per_intent))
            if d < 0 and per_intent and (tick + 2 * reach_ticks) * dt <= t_lock:
                pending6.append((i, goal, tick + 2 * reach_ticks))
            if boxed_on and i == focal and ans in ("accepted", "queued") and (tick + 10) * dt <= t_lock:
                waits.append((tick, st.tgt[i], d))
        still = []
        for lane_i, goal, deadline, per_press, first in pending:
            if st.x[lane_i] <= goal + trip.EPS:
                if per_press:
                    reach_ok += 1
                    reach_n += 1
                if first:
                    intent_ok += 1
                    intent_n += 1
            elif tick >= deadline:
                if per_press:
                    reach_n += 1
                if first:
                    intent_n += 1
            else:
                still.append((lane_i, goal, deadline, per_press, first))
        pending = still
        still6 = []
        for lane_i, goal, deadline in pending6:
            if st.x[lane_i] <= goal + trip.EPS:
                intent6_ok += 1
                intent6_n += 1
            elif tick >= deadline:
                intent6_n += 1
            else:
                still6.append((lane_i, goal, deadline))
        pending6 = still6
        for i in range(LANES):
            for j in range(i + 1, LANES):
                if abs(st.x[i] - st.x[j]) < cfg["laneBand"]:
                    min_gap = min(min_gap, abs(st.off[i] - st.off[j]))
        if boxed_on and trip.boxed_in(st, focal):
            boxed_s += dt
            if trip.no_tuck_inside(st, focal):
                no_tuck_s += dt
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
        if pack_on:
            # Drawn overtakes before the lock (ruling 8): neighbours (within OVERTAKE_LANES) whose order
            # flips from a length (OVERTAKE_FEET) one way to a length the other, the new order held
            # OVERTAKE_HOLD_TICKS; and the drift's relative speed between any two horses.
            in_turn, _ = trip._turn_info(geo, st.speed * t)
            for i in range(LANES):
                for j in range(i + 1, LANES):
                    a = st.off[i] - st.off[j]
                    side = 1 if a >= OVERTAKE_FEET else (-1 if a <= -OVERTAKE_FEET else 0)
                    if abs(st.x[i] - st.x[j]) > OVERTAKE_LANES:
                        side = 0
                    was, cand, since = behind.get((i, j), (0, 0, 0))
                    if side != cand:
                        cand, since = side, tick
                    if cand != 0 and cand != was and tick - since >= OVERTAKE_HOLD_TICKS:
                        if was != 0:
                            overtakes += 1
                            overtakes_straight += 0 if in_turn else 1
                        was = cand
                    behind[(i, j)] = (was, cand, since)
            # D-072 feel: time alongside (within pass.alongFeet) in each completed pass
            for i in range(LANES):
                j = st.pass_from[i]
                if j >= 0 and abs(st.off[i] - st.off[j]) < cfg["pass"]["alongFeet"]:
                    along_acc[i] += dt
            for e in st.pack_events[ev_seen:]:
                if e[1] == "pass":
                    pass_along.append(along_acc[e[2]])
                if e[1] in ("pass", "out"):
                    along_acc[e[2]] = 0.0
            ev_seen = len(st.pack_events)
            if tick > 0:
                for i in range(LANES):
                    for j in range(i + 1, LANES):
                        drift_rel = max(drift_rel, abs((st.drift[i] - prev_drift[i]) - (st.drift[j] - prev_drift[j])) / dt)
            prev_drift = list(st.drift)
        tick += 1
    lock_x = list(st.x)
    trip.lock(st)
    out = {"trip": trip.trip_values(st), "ground": list(st.ground), "draft": list(st.draft), "lock_x": lock_x,
           "reach": (reach_ok, reach_n), "counts": counts, "min_gap": min_gap,
           "intent": (intent_ok, intent_n), "brushes": list(st.brushes), "charged": list(st.charged),
           "brush_cost": trip.brush_charges(st), "events": len(st.events), "seconds": tick * dt}
    if boxed_on:
        out["boxed"], out["boxed_no_tuck"], out["waits1s"] = boxed_s, no_tuck_s, waits1s
    if motion_on:
        out.update({"starts": starts, "vmax": vmax, "amax": amax, "yaw_max": yaw_max, "lean_max": lean_max,
                    "vhist": vhist, "ahist": ahist, "yhist": yhist})
    if stress_on:
        out["overlaps"], out["back_max"] = overlaps, back_max
    if d072:
        ev = st.pack_events
        out["intent6"] = (intent6_ok, intent6_n)
        out["style"] = list(st.style)
        out["outs"] = sum(1 for e in ev if e[1] == "out")
        out["passes"] = sum(1 for e in ev if e[1] == "pass")
        out["passes_straight"] = sum(1 for e in ev if e[1] == "pass" and e[4] == 0)
        out["shuts"] = sum(1 for e in ev if e[1] == "shut")
        out["shut_on"] = [sum(1 for e in ev if e[1] == "shut" and e[3] == i) for i in range(LANES)]
        if pack_on:
            out["overtakes"], out["overtakes_straight"], out["drift_rel"] = overtakes, overtakes_straight, drift_rel
            out["pass_along"] = pass_along
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
    st = trip.new_state([5, 1, 2, 3, 4, 6, 7, 8], [0.125] * 8, [0.5] * 72, geo, cfg, ["manual"] * 8)
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
    d072 = trip.d072_on(cfg)
    for k in range(k0, k1):
        setup = race_setup(race_seed(SEED, cell, k), distance)
        if not d072:
            sweep = [run_race(geo, setup, smart_at(p), cfg)["trip"] for p in range(LANES)]
            allsmart = run_race(geo, setup, ["smart"] * LANES, cfg)["trip"]
            out.append({"sweep": sweep, "allsmart": allsmart})
            continue
        res = [run_race(geo, setup, smart_at(p), cfg) for p in range(LANES)]
        alls = run_race(geo, setup, ["smart"] * LANES, cfg)
        out.append({"sweep": [r["trip"] for r in res], "allsmart": alls["trip"],
                    "styles": [r["style"] for r in res], "allsmart_styles": alls["style"]})
    _mem("baseline chunk")
    return out


def style_lanes(styles: Sequence[int], srow: Optional[Sequence[float]]) -> Optional[List[float]]:
    """Each lane's per-style baseline (D-072), or None without a style row."""
    if srow is None:
        return None
    return [srow[s] for s in styles]


def _tau(res: Dict, row: Sequence[float], cfg: Dict, srow: Optional[Sequence[float]] = None) -> List[float]:
    if not trip.d057_on(cfg):
        return trip.tau(res["trip"], posts(), row, cfg)
    if trip.d072_on(cfg):
        return trip.tau(res["trip"], posts(), row, cfg, res["brush_cost"], style_lanes(res["style"], srow))
    return trip.tau(res["trip"], posts(), row, cfg, res["brush_cost"])


def _report_chunk(args) -> List[Dict]:
    cell, k0, k1, cfg, table, *more = args
    d057 = trip.d057_on(cfg)
    d072 = trip.d072_on(cfg)
    course, distance = cells()[cell]
    geo = trip.phase_a(course, distance)
    row = trip.baseline_row(table, course, distance)
    srow = trip.style_row(more[0], course, distance) if d072 and more and more[0] else None
    out = []
    for k in range(k0, k1):
        setup = race_setup(race_seed(REPORT_SEED, cell, k), distance)
        f = setup["focal"]
        rec: Dict = {"focal": f, "p1": setup["p1"], "s1": setup["s1"]}
        bots = run_race(geo, setup, ["bot"] * LANES, cfg, measure=("pack",) if d072 else ())
        rec["bot_tau"] = _tau(bots, row, cfg, srow)
        if d072:
            rec["bot_style"] = bots["style"]
            rec["bot_raw"] = trip.tau_unclamped(bots["trip"], posts(), row, cfg, style_lanes(bots["style"], srow))
            rec["pack"] = {k: bots[k] for k in ("outs", "passes", "passes_straight", "shuts", "overtakes",
                                                 "overtakes_straight", "drift_rel", "pass_along")}
        rec["bot_ground"] = bots["ground"]
        rec["bot_draft"] = bots["draft"]
        rec["min_gap"] = bots["min_gap"]
        sweep_tau, sweep_lane, sweep_boxed = [], [], []
        for p in range(LANES):
            res = run_race(geo, setup, smart_at(p), cfg, focal=p, measure=("boxed",) if d057 else ())
            sweep_tau.append(_tau(res, row, cfg, srow)[p])
            sweep_lane.append(res["lock_x"][p])
            rec["min_gap"] = min(rec["min_gap"], res["min_gap"])
            if d057:
                sweep_boxed.append((res["boxed"], res["boxed_no_tuck"], res["seconds"]))
        rec["sweep_tau"] = sweep_tau
        rec["smart"] = {"tau": sweep_tau[f], "lane": sweep_lane[f]}
        if d057:
            rec["sweep_boxed"] = sweep_boxed
        for pol in (FOCAL_D072 if d072 else FOCAL_D057) if d057 else FOCAL:
            pols = ["bot"] * LANES
            pols[f] = pol
            res = run_race(geo, setup, pols, cfg, focal=f, measure=("boxed", "motion") if d057 else ())
            rec[pol] = {"tau": _tau(res, row, cfg, srow)[f], "lane": res["lock_x"][f],
                        "reach": res["reach"], "counts": res["counts"]}
            if d057:
                rec[pol].update({
                    "intent": res["intent"], "intent6": res.get("intent6", (0, 0)), "brushes": res["brushes"][f], "charged": res["charged"][f],
                    "cost": res["brush_cost"][f], "others_charged": sum(res["charged"]) - res["charged"][f],
                    "boxed": res["boxed"], "boxed_no_tuck": res["boxed_no_tuck"], "waits1s": res["waits1s"],
                    "seconds": res["seconds"],
                    "starts": len(res["starts"]), "reversals": reversals(res["starts"]),
                    "vmax": res["vmax"], "amax": res["amax"], "yaw_max": res["yaw_max"], "lean_max": res["lean_max"],
                    "vhist": res["vhist"], "ahist": res["ahist"], "yhist": res["yhist"]})
            rec["min_gap"] = min(rec["min_gap"], res["min_gap"])
        allsmart = run_race(geo, setup, ["smart"] * LANES, cfg)
        rec["allsmart_tau"] = _tau(allsmart, row, cfg, srow)
        out.append(rec)
    _mem("report chunk")
    return out


def _grief_chunk(args) -> List[Dict]:
    """D-057 griefing: per race and kid policy, every GRIEF scenario with the same race."""
    cell, k0, k1, cfg, table, *more = args
    course, distance = cells()[cell]
    geo = trip.phase_a(course, distance)
    row = trip.baseline_row(table, course, distance)
    srow = trip.style_row(more[0], course, distance) if trip.d072_on(cfg) and more and more[0] else None
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
                per[name] = {"tau": _tau(res, row, cfg, srow)[kid],
                             "own": res["trip"][kid] - res["brush_cost"][kid], "cost": res["brush_cost"][kid],
                             "lane": res["lock_x"][kid],
                             "kid_charged": res["charged"][kid], "kid_brushes": res["brushes"][kid],
                             "stranger_brushes": sum(res["brushes"][s] for s in strangers),
                             "stranger_charged": sum(res["charged"][s] for s in strangers),
                             "boxed": res["boxed"], "seconds": res["seconds"]}
            rec[kid_pol] = per
        out.append(rec)
    _mem("grief chunk")
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
    _mem("stress chunk")
    return res


def probe_races(cfg: Dict) -> Dict:
    """A few exact races stored with the D-057 report, which the tests rerun: a masher and a
    casual rider (the report's dirt Mile race 3, where the masher brushes), a bumper against a
    Smart Steer kid (griefing race 3, where it brushes) and a stress field (masher, ditherer and casual rider together). Any change
    to the press, brush, bounce, weave or glide rules changes them, so a stale report can't stay
    green."""
    out: Dict = {}
    cell = 1
    course, distance = cells()[cell]
    geo = trip.phase_a(course, distance)
    setup = race_setup(race_seed(REPORT_SEED, cell, 3), distance)
    f = setup["focal"]
    for pol in ("masher", "scripted"):
        pols = ["bot"] * LANES
        pols[f] = pol
        out[pol] = run_race(geo, setup, pols, cfg, focal=f, measure=("boxed", "motion"))
    gs = race_setup(race_seed(GRIEF_SEED, cell, 3), distance)
    kid = gs["focal"]
    others = [i for i in range(LANES) if i != kid]
    random.Random(gs["press_seed"] ^ 0x5EED).shuffle(others)
    pols = ["bot"] * LANES
    pols[kid] = "smart"
    pols[others[0]] = "bumper"
    out["bumper"] = run_race(geo, gs, pols, cfg, match={others[0]: 0.0}, focal=kid, measure=("boxed",))
    ss = race_setup(race_seed(STRESS_SEED, cell, 0), distance)
    order = list(range(LANES))
    random.Random(ss["press_seed"]).shuffle(order)
    pols = ["bot"] * LANES
    for idx, pol in zip(order[:3], ("masher", "ditherer", "scripted")):
        pols[idx] = pol
    out["stress"] = run_race(geo, ss, pols, cfg, measure=("stress",))
    return json.loads(json.dumps(out))


def _chunks(total: int, size: int) -> List[Tuple[int, int]]:
    return [(a, min(total, a + size)) for a in range(0, total, size)]


# ---------------------------------------------------------------- baseline files

# ---- memory (D-072 write): workers hand back each chunk pickled, and the parent keeps records
# pickled until it reads them; the baseline is run and calibrated one cell at a time. The numbers
# are the same as building every list in memory (pickle round-trips floats exactly, and every
# record is read in the same order).

def _packed(job: Tuple) -> bytes:
    fn, args = job
    return pickle.dumps(fn(args), protocol=pickle.HIGHEST_PROTOCOL)


class PickledRecs:
    """A cell's records, kept as the workers' pickled chunks in chunk order; iterating unpickles one
    chunk at a time."""

    def __init__(self) -> None:
        self.blobs: List[bytes] = []
        self.n = 0

    def add(self, blob: bytes, n: int) -> None:
        self.blobs.append(blob)
        self.n += n

    def __iter__(self):
        for blob in self.blobs:
            yield from pickle.loads(blob)

    def __len__(self) -> int:
        return self.n


def _gather(pool, fn, tasks: List[Tuple], sizes: List[int]) -> Dict[int, "PickledRecs"]:
    """Runs fn over tasks ((cell, ...) each, sizes[k] records), in order, into one PickledRecs a cell."""
    out: Dict[int, PickledRecs] = {}
    for task, size, blob in zip(tasks, sizes, pool.imap(_packed, [(fn, t) for t in tasks])):
        out.setdefault(task[0], PickledRecs()).add(blob, size)
    return out


class _BaselineCells:
    """per_cell for summarize_baseline: a cell's rows are run when it is read (once per cell), so
    only one cell's rows are ever in memory."""

    def __init__(self, pool, races: int, cfg: Dict) -> None:
        self.pool, self.races, self.cfg = pool, races, cfg

    def __getitem__(self, cell: int) -> List[Dict]:
        tasks = [(cell, a, b, self.cfg) for a, b in _chunks(self.races, 25)]
        rows: List[Dict] = []
        for blob in self.pool.imap(_packed, [(_baseline_chunk, t) for t in tasks]):
            rows.extend(pickle.loads(blob))
        return rows


def generate_baseline(races: int, jobs: Optional[int], cfg: Dict = trip.CONFIG, mix: float = MIX_WEIGHT) -> Dict:
    with Pool(jobs) as pool:
        data = summarize_baseline(_BaselineCells(pool, races, cfg), races, cfg, mix)
    _mem("parent, after the baseline")
    return data


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
    return calibrate_styles(rows, cfg, mix)[0]


def calibrate_styles(rows: List[Dict], cfg: Dict, mix: float = MIX_WEIGHT) -> Tuple[List[float], Optional[List[float]]]:
    """calibrate(), and with D-072 on the per-style row too (front, stalker, closer, rider). Each
    pass first moves the posts as calibrate() does (taus with the style row), then each style by
    its mean residual in the kid-among-bots fields (that style's mean tau there, the kid as the
    rider, minus the mean over every lane), shifted so the stalker sits at 0 (a shift common to
    every style cancels in the field mean). The rider entry takes the level a Smart Steer kid sits
    at among bots, which the posts can't (their residuals are taken against the mean over posts):
    a passive kid nets 0 among bots. Without D-072 the style row is None and the posts are
    calibrate()'s exactly."""
    n = len(rows)
    raw_a, raw_b = raw_profiles(rows)
    base = [mix * raw_a[p] + (1 - mix) * raw_b[p] for p in range(LANES)]
    d072 = trip.d072_on(cfg) and "styles" in rows[0]
    srow: Optional[List[float]] = [0.0] * len(trip.STYLES) if d072 else None
    if not cfg["enabled"] or cfg["scale"] <= 0:
        return base, srow
    ps = posts()
    for _ in range(CALIBRATION_PASSES):
        sa = [0.0] * LANES
        sb = [0.0] * LANES
        for race in rows:
            for p in range(LANES):
                sl = style_lanes(race["styles"][p], srow) if d072 else None
                sa[p] += trip.tau(race["sweep"][p], ps, base, cfg, None, sl)[p]
            sl = style_lanes(race["allsmart_styles"], srow) if d072 else None
            tb = trip.tau(race["allsmart"], ps, base, cfg, None, sl)
            for p in range(LANES):
                sb[p] += tb[p]
        ra = [v / n for v in sa]
        rb = [v / n for v in sb]
        ma, mb = sum(ra) / LANES, sum(rb) / LANES
        base = [base[p] + (mix * (ra[p] - ma) + (1 - mix) * (rb[p] - mb)) / cfg["scale"] for p in range(LANES)]
        if not d072:
            continue
        tot = [0.0] * len(trip.STYLES)
        cnt = [0] * len(trip.STYLES)
        for race in rows:
            for p in range(LANES):
                styles = race["styles"][p]
                taus = trip.tau(race["sweep"][p], ps, base, cfg, None, style_lanes(styles, srow))
                for j in range(LANES):
                    tot[styles[j]] += taus[j]
                    cnt[styles[j]] += 1
        allm = sum(tot) / max(1, sum(cnt))
        resid = [tot[s] / cnt[s] - allm if cnt[s] else 0.0 for s in range(len(trip.STYLES))]
        srow = [srow[s] + resid[s] / cfg["scale"] for s in range(len(trip.STYLES))]
        srow = [v - srow[1] for v in srow]
    return base, srow


def summarize_baseline(per_cell: Dict[int, List], races: int, cfg: Dict, mix: float) -> Dict:
    table: Dict = {c: {} for c in trip.COURSE_ORDER}
    src_a: Dict = {c: {} for c in trip.COURSE_ORDER}
    src_b: Dict = {c: {} for c in trip.COURSE_ORDER}
    probe: Dict = {c: {} for c in trip.COURSE_ORDER}
    styles: Dict = {c: {} for c in trip.COURSE_ORDER}
    probe_styles: Dict = {c: {} for c in trip.COURSE_ORDER}
    d072 = trip.d072_on(cfg)
    for cell, (course, distance) in enumerate(cells()):
        rows = per_cell[cell]
        raw_a, raw_b = raw_profiles(rows)
        base, srow = calibrate_styles(rows, cfg, mix)
        table[course][distance] = [round(v, 6) for v in base]
        src_a[course][distance] = [round(v, 6) for v in raw_a]
        src_b[course][distance] = [round(v, 6) for v in raw_b]
        pbase, psrow = calibrate_styles(rows[:PROBE_RACES], cfg, mix)
        probe[course][distance] = pbase
        if d072:
            styles[course][distance] = [round(v, 6) for v in srow]
            probe_styles[course][distance] = psrow
    out = {
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
    if d072:
        out["styles"] = styles  # D-072: per course and distance, (front, stalker, closer, rider)
        out["probe"]["styles"] = probe_styles
    return out


def probe_cell(course: str, distance: str, cfg: Dict = trip.CONFIG, mix: float = MIX_WEIGHT) -> List[float]:
    """The generator's whole pipeline on the first PROBE_RACES races of one cell (the
    regeneration test compares it with the stored probe)."""
    return probe_cell_styles(course, distance, cfg, mix)[0]


def probe_cell_styles(course: str, distance: str, cfg: Dict = trip.CONFIG,
                      mix: float = MIX_WEIGHT) -> Tuple[List[float], Optional[List[float]]]:
    cell = cells().index((course, distance))
    return calibrate_styles(_baseline_chunk((cell, 0, PROBE_RACES, cfg)), cfg, mix)


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
    if "styles" in data:
        lines.append("\t-- D-072: per-style baseline, styles[course][distance] = { front, stalker, closer, rider }")
        lines.append("\t-- (bots' running styles and every rider; stalker at 0); Trip.tau subtracts it with the post's.")
        lines.append("\tstyles = {")
        for course in trip.COURSE_ORDER:
            lines.append(f"\t\t{course} = {{")
            for distance in trip.DISTANCE_ORDER:
                vals = ", ".join(_num(v) for v in data["styles"][course][distance])
                lines.append(f"\t\t\t{distance} = {{ {vals} }},")
            lines.append("\t\t},")
        lines.append("\t},")
    lines.append("}")
    return "\n".join(lines) + "\n"


def _num(v: float) -> str:
    s = f"{v:.6f}"
    return "0" if s in ("0.000000", "-0.000000") else s


def write_baseline(data: Dict, profile: str = "live") -> None:
    _out(baseline_path(profile)).write_text(json.dumps(data, indent=1) + "\n")
    if profile == "live":
        _out(BASELINE_LUAU).write_text(render_luau(data))


def load_baseline(profile: str = "live") -> Dict:
    return json.loads(baseline_path(profile).read_text())


def load_report(profile: str = "live") -> Dict:
    return json.loads(report_path(profile).read_text())


# ---------------------------------------------------------------- report

def mean(v: Sequence[float]) -> float:
    return sum(v) / len(v) if v else float("nan")


def run_report(races: int, jobs: Optional[int], data: Dict, cfg: Dict = trip.CONFIG,
               grief_races: int = GRIEF_RACES, stress_races: int = STRESS_RACES) -> Dict:
    table = data["baseline"]
    stable = data.get("styles")
    d057 = trip.d057_on(cfg)
    tasks, sizes = [], []
    for cell in range(len(cells())):
        for a, b in _chunks(races, 10):
            tasks.append((cell, a, b, cfg, table, stable))
            sizes.append(b - a)
    with Pool(jobs) as pool:
        per_cell = _gather(pool, _report_chunk, tasks, sizes)
        stress_parts = []
        grief_cell: Dict[int, PickledRecs] = {}
        stress_tasks = []
        if d057:
            grief_tasks, grief_sizes = [], []
            for cell in range(len(cells())):
                for a, b in _chunks(grief_races, 10):
                    grief_tasks.append((cell, a, b, cfg, table, stable))
                    grief_sizes.append(b - a)
            stress_tasks = [(cell, a, b, cfg) for cell in range(len(cells())) for a, b in _chunks(stress_races, 25)]
            grief_cell = _gather(pool, _grief_chunk, grief_tasks, grief_sizes)
            stress_parts = pool.map(_stress_chunk, stress_tasks)
    summary = summarize_report(per_cell, cfg)
    if d057:
        stress_cell: Dict[int, List[Dict]] = {}
        for (cell, *_rest), part in zip(stress_tasks, stress_parts):
            stress_cell.setdefault(cell, []).append(part)
        summary["griefing"] = summarize_griefing(grief_cell)
        summary["stress"] = summarize_stress(stress_cell)
        summary["glides"] = {str(n): glide_seconds(cfg, n) for n in (1, 2, 3, 4)}
        summary["checks"] = check_targets(summary)
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


def summarize_report(per_cell: Dict[int, List[Dict]], cfg: Dict) -> Dict:
    d057 = trip.d057_on(cfg)
    pols_all = POLICIES_D057 if d057 else POLICIES
    rows = []
    for cell, (course, distance) in enumerate(cells()):
        recs = list(per_cell[cell])
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
        if trip.d072_on(cfg):
            _summarize_d072_cell(r, recs)
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
    if trip.d072_on(cfg):
        summary["d072"] = {"post_bias_max": max(r["smart_post_max"] for r in rows),
                           "allsmart_post_bias_max": max(r["allsmart_post_max"] for r in rows),
                           "smart_mean_max": max(abs(r["smart_among_bots"]) for r in rows),
                           "pass_along_min": min((r["pass_along_min"] for r in rows if r["pass_along_min"] is not None),
                                                 default=None),
                           "lit_vs_never": mean([r["lit_vs_never"] for r in rows]),
                           "style_bias_max": max(r["style_bias_max"] for r in rows),
                           "tau_raw_p99": max(r["tau_raw_p99"] for r in rows),
                           "passes_per_race": mean([r["passes_per_race"] for r in rows]),
                           "overtakes_per_race": mean([r["overtakes_per_race"] for r in rows]),
                           "drift_rel_max": max(r["drift_rel_max"] for r in rows)}
    summary["checks"] = check_targets(summary)
    return summary


def _summarize_d072_cell(r: Dict, recs: List[Dict]) -> None:
    """D-072, per cell (bot fields): each style's mean tau minus the bots' mean (style bias), the
    trip part of tau before the clamp at p99, passes, drawn overtakes, shut doors, drift speed."""
    tot = [0.0] * len(trip.STYLES)
    cnt = [0] * len(trip.STYLES)
    raw = []
    for x in recs:
        for j in range(LANES):
            tot[x["bot_style"][j]] += x["bot_tau"][j]
            cnt[x["bot_style"][j]] += 1
        raw.extend(x["bot_raw"])
    allm = sum(tot) / max(1, sum(cnt))
    r["style_bias"] = [tot[k] / cnt[k] - allm if cnt[k] else 0.0 for k in range(len(trip.STYLES))]
    r["style_bias_max"] = max(abs(v) for v in r["style_bias"])
    raw.sort()
    r["tau_raw_p99"] = raw[int(0.99 * (len(raw) - 1))]
    r["tau_raw_p1"] = raw[int(0.01 * (len(raw) - 1))]
    pk = [x["pack"] for x in recs]
    r["outs_per_race"] = mean([v["outs"] for v in pk])
    r["passes_per_race"] = mean([v["passes"] for v in pk])
    r["passes_straight_share"] = sum(v["passes_straight"] for v in pk) / max(1, sum(v["passes"] for v in pk))
    r["overtakes_per_race"] = mean([v["overtakes"] for v in pk])
    r["overtakes_straight_share"] = sum(v["overtakes_straight"] for v in pk) / max(1, sum(v["overtakes"] for v in pk))
    r["shuts_per_race"] = mean([v["shuts"] for v in pk])
    r["drift_rel_max"] = max(v["drift_rel"] for v in pk)
    along = [a for v in pk for a in v["pass_along"]]
    r["pass_along_min"] = min(along) if along else None
    r["pass_along_median"] = sorted(along)[len(along) // 2] if along else None
    for pol in ("scripted", "rail"):
        ok = sum(x[pol]["intent6"][0] for x in recs)
        n = sum(x[pol]["intent6"][1] for x in recs)
        r[pol + "_intent6s"] = ok / n if n else float("nan")
    r["intent6s"] = r["scripted_intent6s"]
    r["lit_vs_never"] = mean([x["lit"]["tau"] - x["never"]["tau"] for x in recs])
    r["lit"] = mean([x["lit"]["tau"] for x in recs])


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
        r[pol + "_no_tuck_share"] = sum(v["boxed_no_tuck"] for v in xs) / secs
        r[pol + "_reversals_per_min"] = 60.0 * revs / secs
        r[pol + "_min_reversal_gap"] = min(gaps) if gaps else None
        r[pol + "_changes_per_min"] = 60.0 * sum(v["starts"] for v in xs) / secs
        r[pol + "_waits1s_per_race"] = mean([v["waits1s"] for v in xs])
    boxed = [[x["sweep_boxed"][p] for x in recs] for p in range(LANES)]
    r["smart_boxed_post"] = [sum(b[0] for b in boxed[p]) / sum(b[2] for b in boxed[p]) for p in range(LANES)]
    secs = sum(b[2] for p in range(LANES) for b in boxed[p])
    r["smart_boxed_share"] = sum(b[0] for p in range(LANES) for b in boxed[p]) / secs
    r["smart_no_tuck_share"] = sum(b[1] for p in range(LANES) for b in boxed[p]) / secs
    r["smart_boxed_1s_races"] = mean([1.0 if b[0] >= 1.0 - 1e-9 else 0.0 for p in range(LANES) for b in boxed[p]])


class _AllRecs:
    """Every cell's records in cell order, read afresh on each pass (never all in memory)."""

    def __init__(self, per_cell) -> None:
        self.per_cell = per_cell

    def __iter__(self):
        for cell in range(len(cells())):
            yield from self.per_cell[cell]


def _summarize_d057(summary: Dict, per_cell: Dict[int, List[Dict]]) -> None:
    """Pooled over the cells: reach per intent, motion, boxed by post and policy, brushes."""
    rows = summary["rows"]
    summary["intent3s"] = sum(r["scripted_intent_ok"] for r in rows) / max(1, sum(r["scripted_intent_n"] for r in rows))
    summary["rail_intent3s"] = sum(r["rail_intent_ok"] for r in rows) / max(1, sum(r["rail_intent_n"] for r in rows))
    allrecs = _AllRecs(per_cell)
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
        no_tuck = 0.0
        long_races = races = 0
        if pol == "smart":
            for x in allrecs:
                for p in range(LANES):
                    b, nt, s = x["sweep_boxed"][p]
                    by_post_b[p] += b
                    by_post_s[p] += s
                    no_tuck += nt
                    races += 1
                    long_races += 1 if b >= 1.0 - 1e-9 else 0
        else:
            for x in allrecs:
                v, p = x[pol], x["focal"]
                by_post_b[p] += v["boxed"]
                by_post_s[p] += v["seconds"]
                no_tuck += v["boxed_no_tuck"]
                races += 1
                long_races += 1 if v["boxed"] >= 1.0 - 1e-9 else 0
        boxed[pol] = {"share": sum(by_post_b) / sum(by_post_s), "no_tuck_share": no_tuck / sum(by_post_s),
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
    targeted minus untargeted own trip (GRIEF_PAIRS), per cell and pooled, with its brush-charge
    part ("_charges": minus the extra charges, so it adds into the own-trip figure)."""
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
                c = [x[control]["cost"] - x[target]["cost"] for x in recs]
                row[target + "_minus_" + control + "_charges"] = mean(c)
                pooled.setdefault(target + "_minus_" + control + "_charges", []).extend(c)
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


def check_targets(s: Dict) -> Dict[str, bool]:
    """D-054's targets; with D-057 on (the summary has its motion measures), D-057's set."""
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
    if "motion" not in s:
        return checks
    t = TARGETS_D057
    del checks["reach3s"]  # replaced by reach per intent (D-057); the per-press figure stays in the report
    out = {"rail_vs_smart": checks["rail_vs_smart"], "never": checks["never"],
           "intent3s": all(r["intent3s"] >= t["intent3s"] for r in rows)}
    for key in ("draft_share", "post_bias_smart_among_bots", "post_bias_all_smart", "smart_among_bots_mean",
                "all_smart_field_mean"):
        out[key] = checks[key]
    # Every cell (D-057's targets are per cell). With weaveWindowSeconds 5, as debate 012 had it,
    # the dirt Mile and Marathon sat at 8.35; 7 (N1 review) brings every cell under 7.5.
    out["masher_reversals"] = all(r["masher_reversals_per_min"] <= t["masher_reversals_per_min"] for r in rows)
    out["masher_reversal_gap"] = all(r["masher_min_reversal_gap"] is None or
                                     r["masher_min_reversal_gap"] >= t["masher_min_reversal_gap"] for r in rows)
    # Trip's own sideways speed changes by at most laneAccel (27 ft/s^2). The 10 Hz finite
    # difference peaks at 30.4 on a landing tick: the last step snaps onto the lane, shorter than a
    # braking step. The prototype measured the same 30.4 and quoted it as "30", so the check allows
    # the landing tick explicitly: 30.5.
    out["sideways_accel"] = s["motion"]["all_horses"]["amax_ftps2"] <= t["accel_max_ftps2"] + 0.5
    out["casual_charged"] = all(r["scripted_charged_races"] <= t["casual_charged_share"] for r in rows)
    out["no_bystander_charged"] = all(r[pol + "_others_charged"] == 0 for r in rows for pol in FOCAL_D057)
    if "griefing" in s:
        out["griefing"] = all(s["griefing"][k]["pooled"][a + "_minus_" + b] >= t["griefing"]
                              for k in GRIEF_TARGET_KIDS for a, b in GRIEF_PAIRS)
        out["griefing_brushes"] = all(s["griefing"][k]["pooled"][a + "_minus_" + b + "_charges"] >= t["griefing"]
                                      for k in GRIEF_BRUSH_KIDS for a, b in GRIEF_PAIRS)
        out["griefing_mover_pays"] = all(
            s["griefing"][k]["pooled"][name]["kid_charged_not_own"] == 0 for k in GRIEF_KIDS for name in GRIEF) and all(
            s["griefing"]["smart"]["pooled"][name]["kid_charged_per_race"] == 0 for name in GRIEF)
    if "stress" in s:
        out["stress"] = s["stress"]["overlap_frames"] == 0 and s["stress"]["back_max"] <= t["stress_fallback_ftps"]
    if "d072" in s:
        t72 = TARGETS_D072
        # ruling 2: the rail-rider target is retired (Smart Steer rides the rail); ruling 3: the
        # inward-press gate is >= 55% within 3 s and >= 85% within 6 s
        del out["rail_vs_smart"]
        out["intent3s"] = all(r["intent3s"] >= t72["intent3s"] for r in rows)
        out["d072_intent6s"] = all(r["intent6s"] >= t72["intent6s"] for r in rows)
        out["masher_reversals"] = all(r["masher_reversals_per_min"] <= t72["masher_reversals_per_min"] for r in rows)
        out["d072_post_bias"] = s["d072"]["post_bias_max"] <= t72["post_bias"]
        out["d072_smart_mean"] = s["d072"]["smart_mean_max"] <= t72["smart_mean"]
        lo, hi = t72["passes_sprint"]
        lo2, hi2 = t72["passes"]
        out["d072_passes"] = all((lo <= r["passes_per_race"] <= hi) if r["distance"] == "Sprint"
                                 else (lo2 <= r["passes_per_race"] <= hi2) for r in rows)
        out["d072_overtakes"] = all(t72["overtakes"][0] <= r["overtakes_per_race"] <= t72["overtakes"][1] for r in rows)
        out["d072_pass_along"] = s["d072"]["pass_along_min"] is None or s["d072"]["pass_along_min"] >= t72["pass_along_min"]
        out["d072_style_bias"] = s["d072"]["style_bias_max"] <= t72["style_bias"]
        out["d072_tau_p99"] = s["d072"]["tau_raw_p99"] <= t72["tau_p99"]
        out["d072_drift"] = s["d072"]["drift_rel_max"] <= t72["drift_rel"] + 1e-9
    return out


LABELS = {
    "rail_vs_smart": "Rail rider vs Smart Steer +0.01 to +0.03 (every cell)",
    "never": "Never-steer between -0.02 and -0.01 (every cell)",
    "reach3s": "Inward request reaching its lane within 3 s >= 70% (every cell)",
    "intent3s": "Inward press reaching its lane within 3 s, per intent: >= 70% (D-057), >= 55% (D-072 ruling 3) (every cell)",
    "draft_share": "Draft share of positive trip <= 40% (every cell)",
    "post_bias_smart_among_bots": "Post bias < 0.005, Smart Steer kid among bots (every cell, every post)",
    "post_bias_all_smart": "Post bias < 0.005, all-Smart fields (every cell, every post)",
    "smart_among_bots_mean": "Smart Steer kid among bots averages 0 +- 0.003 (every cell)",
    "all_smart_field_mean": "All-Smart field mean 0 +- 0.003 (every cell)",
    "masher_reversals": "Masher reversals <= 8 a minute (every cell; D-072 ruling 4 allows 8.5 if griefing and brushes hold)",
    "masher_reversal_gap": "No masher reversal within 3 s of the previous (every cell)",
    "sideways_accel": "Sideways acceleration <= 30 ft/s^2 between ticks, + 0.5 for the landing tick (every horse)",
    "casual_charged": "Casual riders charged for a brush in <= 5% of races (every cell)",
    "no_bystander_charged": "Only the mover pays: no other horse is ever charged (every cell)",
    "griefing": "Griefing: targeted minus untargeted own trip >= -0.001 (each scenario, Smart Steer and rail kids, pooled)",
    "griefing_brushes": "Griefing: brush charges strangers add >= -0.001 (each scenario, every kid but the masher, pooled)",
    "griefing_mover_pays": "Griefing: a kid is only ever charged for its own brushes (a Smart Steer kid never)",
    "stress": "Stress: 0 overlaps and fall-back <= 20 ft/s",
    "d072_post_bias": "D-072: post bias <= 0.002, kid among bots (every cell, every post; all-Smart <= 0.003 reported)",
    "d072_smart_mean": "D-072: a passive Smart Steer kid among bots nets 0 +- 0.003 (every cell)",
    "d072_intent6s": "D-072: inward press reaching its lane within 6 s >= 85%, per intent (every cell)",
    "d072_passes": "D-072: Trip passes a race 1-10 (Sprint), 3-10 (others), bot fields (every cell)",
    "d072_overtakes": "D-072: drawn overtakes (a length clear, held 2 s) 3-15 a race, bot fields (every cell)",
    "d072_pass_along": "D-072: every completed pass alongside >= 0.8 s (the minimum over all)",
    "d072_style_bias": "D-072: style bias <= 0.002 (bot fields, every cell, every style)",
    "d072_tau_p99": "D-072: trip part of tau before the clamp, p99 <= +0.04 (bot fields, every cell)",
    "d072_drift": "D-072: drift moves two horses apart at most 3 ft/s",
}


def _posts(v: Sequence[float]) -> str:
    return " ".join(f"{x:+.4f}" for x in v)


def _pcts(v: Sequence[float]) -> str:
    return " ".join(f"{x:.1%}" for x in v)


def format_report(s: Dict, data: Dict, cfg: Dict) -> str:
    d057 = trip.d057_on(cfg)
    out = []
    rows = s["rows"]
    label = "D-054" if not d057 else ("D-057 on" if cfg["brush"] != "off" else "D-057 on, brushes off")
    out.append(f"Steering calibration ({label}): baseline seed {data['seed']}, "
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
    if "d072" in s:
        out.append("")
        d = s["d072"]
        out.append(f"D-072: kid-among-bots post bias max {d['post_bias_max']:.4f}, all-Smart {d['allsmart_post_bias_max']:.4f} "
                   f"(reported), passive kid mean max |{d['smart_mean_max']:.4f}|, pass alongside min "
                   f"{d['pass_along_min'] if d['pass_along_min'] is None else round(d['pass_along_min'], 2)} s, "
                   f"press-when-lit minus never {d['lit_vs_never']:+.4f} (reported; phase C gate +0.003..+0.008)")
        out.append("  per cell: intent 3 s / 6 s; masher reversals a minute; lit - never")
        for r in rows:
            out.append(f"  {r['course']:4s} {r['distance']:8s} {r['intent3s']:.0%} / {r['intent6s']:.0%}; "
                       f"{r['masher_reversals_per_min']:.2f}; {r['lit_vs_never']:+.4f}")
        out.append("D-072 (bot fields): style bias front/stalker/closer/rider; tau before the clamp p1/p99; passes (straight share); "
                   "outs; drawn overtakes (straight share); shut doors; drift relative speed max")
        for r in rows:
            out.append(f"  {r['course']:4s} {r['distance']:8s} {_posts(r['style_bias'])}; {r['tau_raw_p1']:+.4f}/{r['tau_raw_p99']:+.4f}; "
                       f"{r['passes_per_race']:.2f} ({r['passes_straight_share']:.0%}); {r['outs_per_race']:.2f}; "
                       f"{r['overtakes_per_race']:.2f} ({r['overtakes_straight_share']:.0%}); {r['shuts_per_race']:.2f}; "
                       f"{r['drift_rel_max']:.2f} ft/s")
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
    out.append("Boxed in (share of pre-lock time; boxed with no tuck slot inside; races with >= 1 s; by post 1-8):")
    for pol, b in s["boxed"].items():
        out.append(f"  {pol:9s} {b['share']:.1%}  no tuck {b['no_tuck_share']:.2%}  >=1 s {b['races_boxed_1s']:.0%}  "
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
            note = "" if kid in GRIEF_TARGET_KIDS else " (reported; the gate is the charges part)"
            out.append(f"  {kid} kid: " + "; ".join(
                f"{a} - {b} {p[a + '_minus_' + b]:+.4f} (charges {p.get(a + '_minus_' + b + '_charges', 0.0):+.4f})"
                for a, b in GRIEF_PAIRS) + note)
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
    ap.add_argument("--profile", choices=PROFILES, default="live",
                    help="live (trip.CONFIG, the game), d057 (brushes on too) or d054 (the switch-back)")
    ap.add_argument("--races", type=int, default=BASELINE_RACES, help="baseline races per cell (each post gets this many)")
    ap.add_argument("--report-races", type=int, default=REPORT_RACES, help="races per cell for the report")
    ap.add_argument("--grief-races", type=int, default=GRIEF_RACES, help="d057: griefing races per cell")
    ap.add_argument("--stress-races", type=int, default=STRESS_RACES, help="d057: stress races per cell")
    ap.add_argument("--jobs", type=int, default=0, help="worker processes (default: all cores)")
    ap.add_argument("--mix", type=float, default=None, help="trial: weight of the kid-among-bots profile")
    ap.add_argument("--json", type=str, default="", help="also write the report numbers to this file")
    ap.add_argument("--out", type=str, default="", help="with --write: write the files into this folder instead (scratch)")
    ap.add_argument("--mem", action="store_true", help="print each process's peak memory to stderr")
    ap.add_argument("--set", action="append", default=[], metavar="KEY=VALUE",
                    help="try a config change (e.g. groundPerLaneTurn=0.011, smart.homeLane=2); nothing is written")
    args = ap.parse_args(argv)
    global OUT_DIR
    if args.out:
        OUT_DIR = Path(args.out)
        OUT_DIR.mkdir(parents=True, exist_ok=True)
    if args.mem:
        os.environ["STEERING_MEM"] = "1"  # inherited by the workers
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
            if args.profile == "live":
                written = f"{written} and {BASELINE_LUAU.relative_to(ROOT)}"
            print(f"wrote {written} ({args.races} races per cell and post, {time.time() - t0:.0f} s)")
    else:
        data = load_baseline(args.profile)
    if data["config"] != trip.config_record(cfg):
        print("warning: the checked-in baseline was made with a different config; run with --write")
    summary = run_report(args.report_races, jobs, data, cfg, args.grief_races, args.stress_races)
    print(format_report(summary, data, cfg))
    _mem("parent, after the report")
    print(f"({time.time() - t0:.0f} s)")
    stored = {"seed": REPORT_SEED, "races": args.report_races, "baselineSeed": data["seed"],
              "baselineRaces": data["races"], "mixWeight": data["mixWeight"], "config": trip.config_record(cfg),
              "summary": summary}
    if trip.d057_on(cfg):
        stored.update({"profile": args.profile, "griefSeed": GRIEF_SEED, "griefRaces": args.grief_races,
                       "stressSeed": STRESS_SEED, "stressRaces": args.stress_races, "probes": probe_races(cfg)})
    if args.write:
        _out(report_path(args.profile)).write_text(json.dumps(stored, indent=1) + "\n")
        print(f"wrote {report_path(args.profile).relative_to(ROOT)}")
    if args.json:
        Path(args.json).write_text(json.dumps(stored, indent=1))
    return 0 if all(summary["checks"].values()) else 1


if __name__ == "__main__":
    sys.exit(main())
