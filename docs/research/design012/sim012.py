#!/usr/bin/env python3
"""Debate 012 prototype simulations (scratch; never part of the repo's tests).

    python sim012.py motion      # E1: zig-zag, sideways speed/accel, yaw per motion variant
    python sim012.py boxed       # E2: how often horses are boxed in, by post and policy
    python sim012.py bumps       # E3: brush frequency and cost per bump rule and policy
    python sim012.py grief       # E4: can strangers lower a kid's tau by riding alongside or bumping?
    python sim012.py accept V    # E5: D-054 acceptance targets for variant V (regenerates its baseline)
    python sim012.py all         # everything (writes results/*.json and results/*.md)

Reuses sims/steering.py (race setup, seeds, calibration, report summary) with the scratch model
trip012 swapped in. Every race has its own seed; jobs never change a number.
"""

from __future__ import annotations

import copy
import json
import math
import random
import sys
import time
from multiprocessing import Pool
from pathlib import Path
from typing import Dict, List, Optional, Sequence, Tuple

HERE = Path(__file__).resolve().parent
REPO = Path(r"C:\Users\David S\Documents\GitHub\gavel-race")
sys.path.insert(0, str(REPO / "src"))
sys.path.insert(0, str(REPO / "sims"))
sys.path.insert(0, str(HERE))

import steering as S  # noqa: E402
import trip012 as T  # noqa: E402

S.trip = T  # steering.py's helpers (calibrate, summarize) now run the scratch model
RESULTS = HERE / "results"
LANES = 8
LANE_FT = 6.0
SPEED = 56.0
DT = 0.1

# ------------------------------------------------------------------ variants

BASE_MOTION = {"chainWindow": 0.3}
RES = {"glideReserveFeet": 6.0}
VARIANTS: Dict[str, Dict] = {
    # D-054 as built
    "D054": {},
    # D-054 glide with only the anti-zig-zag rule
    "D054+gap": {"reverseGapSeconds": 0.5},
    # eased S-curve glides without anti-zig-zag rules ("before")
    "E10raw": {"glide": "eased", "laneSpeedMax": 1.5, "laneAccel": 4.5},
    # eased + chain + reverse gap ("after"); one lane in ~0.9 / ~1.0 / ~1.2 s
    "E09": {"glide": "eased", "laneSpeedMax": 1.667, "laneAccel": 5.56, "chainWindow": 0.3, "reverseGapSeconds": 0.4},
    "E10": {"glide": "eased", "laneSpeedMax": 1.5, "laneAccel": 4.5, "chainWindow": 0.3, "reverseGapSeconds": 0.5},
    "E10refuse": {"glide": "eased", "laneSpeedMax": 1.5, "laneAccel": 4.5, "chainWindow": 0.3, "reverseGapSeconds": 0.5,
                  "reverseQueue": False},
    "E12": {"glide": "eased", "laneSpeedMax": 1.35, "laneAccel": 3.0, "chainWindow": 0.3, "reverseGapSeconds": 0.8},
    # E10 plus the weave gap: a second reversal within 5 s waits 2.5 s (a horse settles before changing its mind again)
    "E10w": {"glide": "eased", "laneSpeedMax": 1.5, "laneAccel": 4.5, "chainWindow": 0.3, "reverseGapSeconds": 0.5,
             "weaveGapSeconds": 2.5, "weaveWindowSeconds": 5.0, "glideReserveFeet": 6.0},
    "E09w": {"glide": "eased", "laneSpeedMax": 1.667, "laneAccel": 5.56, "chainWindow": 0.3, "reverseGapSeconds": 0.4,
             "weaveGapSeconds": 2.5, "weaveWindowSeconds": 5.0, "glideReserveFeet": 6.0},
    "E10w0": {"glide": "eased", "laneSpeedMax": 1.5, "laneAccel": 4.5, "chainWindow": 0.3, "reverseGapSeconds": 0.5,
              "weaveGapSeconds": 2.5, "weaveWindowSeconds": 5.0},
}
# boxed-in press handling on top of E10
BOXED = {
    "d054": {},                                                         # tuck at once (inward), outward waits 1 s
    "wait+tuck": {"blockedPress": "wait", "gapWaitSeconds": 1.5, "tuckAfterSeconds": 0.0},
    "wait+tuck0.5": {"blockedPress": "wait", "gapWaitSeconds": 1.5, "tuckAfterSeconds": 0.5},
    "wait-only": {"blockedPress": "wait", "gapWaitSeconds": 1.5, "tuckInward": False},
    "wait3+tuck": {"blockedPress": "wait", "gapWaitSeconds": 1.5, "gapWaitInSeconds": 3.0, "tuckAfterSeconds": 0.0},
    # recommended: inward presses wait until room (as D-054) or tuck back at once; outward presses wait 1.5 s
    "waitinf+tuck": {"blockedPress": "wait", "gapWaitSeconds": 1.5, "gapWaitInSeconds": 1e9, "tuckAfterSeconds": 0.0},
    "wait3+tuck0.5": {"blockedPress": "wait", "gapWaitSeconds": 1.5, "gapWaitInSeconds": 3.0, "tuckAfterSeconds": 0.5},
}
BUMPS = {
    "off": {"bump": "off"},
    "repeat(eng)": {"bump": "repeat", "bumpCost": 0.005, "bumpFree": 0, "bumpMaxCharged": 2},
    "any(comp)": {"bump": "any", "bumpCost": 0.002, "bumpFree": 1, "bumpMaxCharged": 3},
    "any(free)": {"bump": "any", "bumpCost": 0.0, "bumpFree": 0, "bumpMaxCharged": 3},
    "repeat(comp)": {"bump": "repeat", "bumpCost": 0.002, "bumpFree": 1, "bumpMaxCharged": 3},
    # recommended: the second press must follow the first within 2 s ("insisting")
    "repeat2s": {"bump": "repeat", "bumpCost": 0.002, "bumpFree": 1, "bumpMaxCharged": 3, "bumpRepeatWithin": 2.0},
}


def make_cfg(*overrides: Dict) -> Dict:
    cfg = copy.deepcopy(T.CONFIG)
    for o in overrides:
        for k, v in o.items():
            cfg[k] = v
    return cfg


def named_cfg(motion: str, boxed: str = "d054", bump: str = "off") -> Dict:
    return make_cfg(VARIANTS[motion], BOXED[boxed], BUMPS[bump])


# ------------------------------------------------------------------ policies

HUMAN = ("rail", "wanderer", "scripted", "masher", "dither", "shadow", "crew_in", "crew_out", "crew_ahead", "bumper",
         "smart_kid")
KIND = {"bot": "bot", "smart": "smart", "never": "manual", "smart_kid": "smart", "mbot": "smart"}


def kind_of(p: str) -> str:
    return KIND.get(p, "smart")


class Rider:
    def __init__(self, policy: str, rng: random.Random, kid: int):
        self.p = policy
        self.rng = rng
        self.kid = kid
        self.flip = -1

    def _toward(self, st, i: int, goal: int, tick: int) -> int:
        if tick % 3 != 0:
            return 0
        after = T.lane_after(st, i)
        if after > goal:
            return -1
        if after < goal:
            return 1
        return 0

    def press(self, st, i: int, tick: int) -> int:
        p = self.p
        rng = self.rng
        if p == "rail":
            if tick % 3 == 0 and T.lane_after(st, i) > 1:
                return -1
        elif p == "wanderer":
            if rng.random() < 0.03:
                return -1 if rng.random() < 0.5 else 1
        elif p == "scripted":
            u = rng.random()
            if u < 0.02 and T.lane_after(st, i) > 1:
                return -1
            idle = st.want[i] == 0 and st.queued[i] == 0 and st.x[i] == st.tgt[i]
            if 0.02 <= u < 0.025 and idle and T.lane_after(st, i) < st.lanes:
                return 1
        elif p == "masher":  # 4 presses a second, random side
            if rng.random() < 0.4:
                return -1 if rng.random() < 0.5 else 1
        elif p == "dither":  # In, Out, In, Out ... every 0.2 s (the worst zig-zag case)
            if tick % 2 == 0:
                self.flip = -self.flip
                if T.lane_after(st, i) + self.flip < 1 or T.lane_after(st, i) + self.flip > st.lanes:
                    self.flip = -self.flip
                return self.flip
        elif p in ("shadow", "crew_in"):  # sit on the kid's inside
            return self._toward(st, i, max(1, st.tgt[self.kid] - 1), tick)
        elif p == "crew_out":
            return self._toward(st, i, min(st.lanes, st.tgt[self.kid] + 1), tick)
        elif p == "crew_ahead":
            return self._toward(st, i, st.tgt[self.kid], tick)
        elif p == "bumper":  # get beside the kid, then keep pressing into it
            k = self.kid
            goal = st.tgt[k] - 1 if st.tgt[k] > 1 else st.tgt[k] + 1
            if T.lane_after(st, i) != goal:
                return self._toward(st, i, goal, tick)
            if tick % 3 == 0:
                return 1 if st.tgt[k] > st.tgt[i] else -1
        return 0


# ------------------------------------------------------------------ one race

def side_blocked(st, i: int, d: int) -> bool:
    lane = st.tgt[i] + d
    if lane < 1 or lane > st.lanes:
        return True
    _slot, blocked = T._slot(st, i, lane)
    return blocked


def front_blocked(st, i: int, feet: float = 12.0) -> bool:
    band = st.cfg["laneBand"]
    for j in range(st.n):
        if j != i and abs(st.x[j] - st.x[i]) < band:
            a = st.off[j] - st.off[i]
            if 0 < a <= feet:
                return True
    return False


def run_race(geo: Dict, setup: Dict, pols: Sequence[str], cfg: Dict, match: Optional[Dict[int, float]] = None,
             detail: bool = False) -> Dict:
    """Phase A for one field. match = {lane: feet}: that lane's skill target is the kid's plus
    `feet` (a griefer who managed to tap exactly like the kid)."""
    kinds = [kind_of(p) for p in pols]
    st = T.new_state(S.posts(), setup["q"], setup["uniforms"], geo, cfg, kinds)
    kid = setup["focal"]
    rng = random.Random(setup["press_seed"])
    riders = {i: Rider(p, rng, kid) for i, p in enumerate(pols) if p in HUMAN and p != "smart_kid"}
    t_lock = T.lock_time(geo)
    sw = S.switch_tick(geo, cfg)
    q, p1 = setup["q"], setup["p1"]
    reach3, reach5 = int(round(3.0 / DT)), int(round(5.0 / DT))
    pending: List[List] = []  # [lane, goal, tick0, free, serviceable, first]
    reach = {"ok3": 0, "ok5": 0, "n": 0, "free_ok3": 0, "free_n": 0, "blk_ok3": 0, "blk_ok5": 0, "blk_n": 0,
             "serv_ok3": 0, "serv_n": 0, "first_ok3": 0, "first_n": 0, "presses": 0, "chip": 0}
    last_press = {}
    chipq: List[List] = []  # [lane, tick0, tgt0, dir]
    counts: Dict[str, int] = {}
    min_gap = math.inf
    overlaps = 0
    # sideways motion of every horse
    vmax = 0.0
    amax = 0.0
    vhist = [0] * 16    # |v| ft/s bins of 1 while moving
    ahist = [0] * 13    # |a| ft/s^2 bins of 10
    prev_x = list(st.x)
    prev_v = [0.0] * LANES
    # focal: lane change starts and arrivals, boxed time
    starts: List[Tuple[float, int]] = []
    last_tgt = st.tgt[kid]
    boxed_ticks = pinned_ticks = trapped_ticks = 0
    boxed_all = [0] * LANES
    ticks = 0
    tick = 0
    while tick * DT < t_lock - T.EPS:
        t = tick * DT
        intents = []
        goals = []
        frees = []
        servs = []
        firsts = []
        for i in sorted(riders):
            d = riders[i].press(st, i, tick)
            if d != 0:
                intents.append((i, d))
                goals.append(T.lane_after(st, i) + d)
                fr = not side_blocked(st, i, d)
                frees.append(fr)
                sv = fr
                if not fr and d < 0 and st.tgt[i] > 1 and cfg["tuckInward"]:
                    slot, _b = T._slot(st, i, st.tgt[i] - 1)
                    sv = st.off[i] - slot <= cfg["tuckBackMax"] + T.EPS
                servs.append(sv)
                firsts.append(tick - last_press.get(i, -10**9) > 30)
                last_press[i] = tick
        live = list(q if tick < sw else p1)
        if match:
            for g, feet in match.items():
                live[g] = live[kid] + feet / st.lead
        answers = T.step(st, live, intents, t, DT)
        for (i, d), goal, free, sv, fst, ans in zip(intents, goals, frees, servs, firsts, answers):
            counts[ans] = counts.get(ans, 0) + 1
            reach["presses"] += 1
            if ans in ("accepted", "queued") and (tick + 10) * DT <= t_lock:
                chipq.append([i, tick, st.tgt[i], d])
            if d < 0 and ans in ("accepted", "queued") and (tick + reach5) * DT <= t_lock:
                pending.append([i, goal, tick, free, sv, fst])
        keep = []
        for item in chipq:
            lane_i, t0, tg0, dd = item
            if st.tgt[lane_i] != tg0 or st.tuck[lane_i] > 0:
                continue  # it moved or is tucking: no "wait for a gap" chip
            if tick - t0 >= 10:
                if st.want[lane_i] == dd or st.queued[lane_i] == dd:
                    reach["chip"] += 1  # still waiting after 1 s with nothing happening
                continue
            keep.append(item)
        chipq = keep
        still = []
        for item in pending:
            lane_i, goal, t0, free, sv, fst = item
            age = tick - t0
            arrived = st.x[lane_i] <= goal + T.EPS
            if arrived or age >= reach5:
                ok3 = arrived and age <= reach3
                reach["n"] += 1
                reach["ok3"] += ok3
                reach["ok5"] += arrived
                if sv:
                    reach["serv_n"] += 1
                    reach["serv_ok3"] += ok3
                if fst:
                    reach["first_n"] += 1
                    reach["first_ok3"] += ok3
                if free:
                    reach["free_n"] += 1
                    reach["free_ok3"] += ok3
                else:
                    reach["blk_n"] += 1
                    reach["blk_ok3"] += ok3
                    reach["blk_ok5"] += arrived
            else:
                still.append(item)
        pending = still
        for i in range(LANES):
            for j in range(i + 1, LANES):
                dx = abs(st.x[i] - st.x[j])
                if dx < cfg["laneBand"]:
                    min_gap = min(min_gap, abs(st.off[i] - st.off[j]))
                if dx < 0.5 and abs(st.off[i] - st.off[j]) < 6.0:
                    overlaps += 1
        for i in range(LANES):
            v = (st.x[i] - prev_x[i]) * LANE_FT / DT
            a = (v - prev_v[i]) / DT
            if abs(v) > 1e-9 or abs(prev_v[i]) > 1e-9:
                vhist[min(15, int(abs(v)))] += 1
                ahist[min(12, int(abs(a) / 10.0))] += 1
                vmax = max(vmax, abs(v))
                amax = max(amax, abs(a))
            prev_x[i] = st.x[i]
            prev_v[i] = v
        if st.tgt[kid] != last_tgt:
            starts.append((t, 1 if st.tgt[kid] > last_tgt else -1))
            last_tgt = st.tgt[kid]
        fb = front_blocked(st, kid)
        ib = side_blocked(st, kid, -1)
        ob = side_blocked(st, kid, 1)
        if fb and ib and ob:
            boxed_ticks += 1
            lane = st.tgt[kid] - 1
            if lane >= 1:
                slot, _ = T._slot(st, kid, lane)
                if st.off[kid] - slot > cfg["tuckBackMax"] + T.EPS:
                    trapped_ticks += 1
        if ib and st.tgt[kid] > 1:
            pinned_ticks += 1
        if detail:
            for i in range(LANES):
                if front_blocked(st, i) and side_blocked(st, i, -1) and side_blocked(st, i, 1):
                    boxed_all[i] += 1
        ticks += 1
        tick += 1
    lock_x = list(st.x)
    T.lock(st)
    bump_cost = [T.bump_charge(st, i) for i in range(LANES)]
    # zig-zag: a change opposite to the previous one
    flips = []
    for a in range(1, len(starts)):
        if starts[a][1] != starts[a - 1][1]:
            flips.append(starts[a][0])
    gaps = [flips[a] - flips[a - 1] for a in range(1, len(flips))]
    return {
        "trip": T.trip_values(st), "ground": list(st.ground), "draft": list(st.draft), "lock_x": lock_x,
        "bump_cost": bump_cost, "bumps": list(st.bumps), "brushes": list(st.brushes), "events": len(st.events),
        "reach": reach, "counts": counts, "min_gap": min_gap, "overlaps": overlaps,
        "vmax": vmax, "amax": amax, "vhist": vhist, "ahist": ahist,
        "seconds": ticks * DT, "starts": len(starts), "flips": len(flips),
        "min_flip_gap": min(gaps) if gaps else None, "flip_gaps": gaps,
        "boxed": boxed_ticks * DT, "pinned": pinned_ticks * DT, "trapped": trapped_ticks * DT,
        "boxed_all": [b * DT for b in boxed_all],
    }


def tau_of(res: Dict, row: Sequence[float], cfg: Dict) -> List[float]:
    return T.tau(res["trip"], S.posts(), row, cfg, res["bump_cost"])


def _load_row_table() -> Dict:
    return S.load_baseline()["baseline"]


# ------------------------------------------------------------------ E1 motion

MOTION_POLICIES = ("masher", "dither", "scripted", "rail")


def _motion_chunk(args):
    vname, cell, k0, k1 = args
    cfg = named_cfg(vname)
    course, distance = S.cells()[cell]
    geo = T.phase_a(course, distance)
    out = []
    for k in range(k0, k1):
        setup = S.race_setup(S.race_seed(4242, cell, k), distance)
        rec = {}
        for pol in MOTION_POLICIES:
            pols = ["bot"] * LANES
            pols[setup["focal"]] = pol
            r = run_race(geo, setup, pols, cfg)
            rec[pol] = {k2: r[k2] for k2 in ("vmax", "amax", "vhist", "ahist", "seconds", "starts", "flips",
                                              "min_flip_gap", "flip_gaps", "overlaps", "min_gap")}
        out.append(rec)
    return out


def motion(races: int, jobs: Optional[int]) -> Dict:
    names = ["D054", "D054+gap", "E10raw", "E09", "E10", "E10refuse", "E12", "E09w", "E10w"]
    tasks = [(v, c, a, b) for v in names for c in range(8) for a, b in S._chunks(races, 10)]
    with Pool(jobs) as pool:
        parts = pool.map(_motion_chunk, tasks)
    agg: Dict[str, List] = {}
    for (v, *_), part in zip(tasks, parts):
        agg.setdefault(v, []).extend(part)
    out = {}
    for v in names:
        recs = agg[v]
        row = {}
        for pol in MOTION_POLICIES:
            rs = [r[pol] for r in recs]
            secs = sum(r["seconds"] for r in rs)
            flips = sum(r["flips"] for r in rs)
            gaps = [g for r in rs for g in r["flip_gaps"]]
            row[pol] = {
                "lane_changes_per_min": 60 * sum(r["starts"] for r in rs) / secs,
                "reversals_per_min": 60 * flips / secs,
                "min_reversal_gap": min(gaps) if gaps else None,
                "median_reversal_gap": sorted(gaps)[len(gaps) // 2] if gaps else None,
                "overlaps": sum(r["overlaps"] for r in rs),
                "min_gap": min(r["min_gap"] for r in rs),
            }
        vh = [0] * 16
        ah = [0] * 13
        for r in recs:
            for pol in MOTION_POLICIES:
                for b in range(16):
                    vh[b] += r[pol]["vhist"][b]
                for b in range(13):
                    ah[b] += r[pol]["ahist"][b]
        vmax = max(r[pol]["vmax"] for r in recs for pol in MOTION_POLICIES)
        amax = max(r[pol]["amax"] for r in recs for pol in MOTION_POLICIES)
        row["all_horses"] = {"vmax_ftps": vmax, "amax_ftps2": amax,
                             "max_drift_deg": math.degrees(math.atan(vmax / SPEED)),
                             "v_p50": _pct(vh, 0.5), "v_p95": _pct(vh, 0.95),
                             "a_p50": 10 * _pct(ah, 0.5), "a_p95": 10 * _pct(ah, 0.95),
                             "a_share_over_40": sum(ah[4:]) / max(1, sum(ah)),
                             "vhist": vh, "ahist": ah}
        cfgv = named_cfg(v)
        row["one_lane_seconds"] = one_lane_seconds(cfgv)
        row["two_lane_seconds"] = one_lane_seconds(cfgv, 2)
        out[v] = row
    return out


def _pct(hist: List[int], p: float) -> float:
    total = sum(hist)
    run = 0
    for b, c in enumerate(hist):
        run += c
        if run >= p * total:
            return b + 0.5
    return len(hist) - 0.5


def one_lane_seconds(cfg: Dict, lanes: int = 1) -> float:
    """Time for a free glide of `lanes` lanes (chained presses), from the press to arrival."""
    geo = T.phase_a("dirt", "Mile")
    st = T.new_state([5, 1, 2, 3, 4, 6, 7, 8], [0.125] * 8, [0.5] * 16, geo, cfg, ["manual"] + ["manual"] * 7)
    for i in range(1, 8):
        st.off[i] = -200.0 - 20 * i  # everyone far behind
    live = [0.125] * 8
    t = 0.0
    tick = 0
    done_at = None
    presses = lanes
    while tick < 200:
        intents = []
        if presses > 0 and st.queued[0] == 0 and T.lane_after(st, 0) > 5 - lanes:
            intents.append((0, -1))
            presses -= 1
        T.step(st, live, intents, t, DT)
        tick += 1
        t = tick * DT
        if st.x[0] == 5 - lanes and done_at is None:
            done_at = t
            break
    return done_at


# ------------------------------------------------------------------ E2 boxed in

BOX_POLICIES = ("smart_kid", "rail", "never", "scripted")


def _boxed_chunk(args):
    motion_v, boxed_v, cell, k0, k1 = args
    cfg = named_cfg(motion_v, boxed_v)
    course, distance = S.cells()[cell]
    geo = T.phase_a(course, distance)
    out = []
    for k in range(k0, k1):
        setup = S.race_setup(S.race_seed(5151, cell, k), distance)
        rec = {"cell": cell}
        for pol in BOX_POLICIES:
            per_post = []
            for post in range(LANES):
                pols = ["bot"] * LANES
                pols[post] = pol
                s2 = dict(setup)
                s2["focal"] = post
                r = run_race(geo, s2, pols, cfg)
                per_post.append({"boxed": r["boxed"], "pinned": r["pinned"], "trapped": r["trapped"],
                                 "seconds": r["seconds"], "reach": r["reach"], "counts": r["counts"],
                                 "lock_x": r["lock_x"][post]})
            rec[pol] = per_post
        allbots = run_race(geo, setup, ["bot"] * LANES, cfg, detail=True)
        rec["bots_boxed"] = allbots["boxed_all"]
        rec["bots_seconds"] = allbots["seconds"]
        out.append(rec)
    return out


def boxed(races: int, jobs: Optional[int], motion_v: str = "E10w", boxed_list=("d054", "wait+tuck", "wait+tuck0.5", "wait-only")) -> Dict:
    tasks = [(motion_v, b, c, a, z) for b in boxed_list for c in range(8) for a, z in S._chunks(races, 5)]
    with Pool(jobs) as pool:
        parts = pool.map(_boxed_chunk, tasks)
    agg: Dict[str, List] = {}
    for (m, b, *_), part in zip(tasks, parts):
        agg.setdefault(b, []).extend(part)
    out = {}
    for b in boxed_list:
        recs = agg[b]
        row: Dict = {}
        for pol in BOX_POLICIES:
            by_post = []
            for post in range(LANES):
                secs = sum(r[pol][post]["seconds"] for r in recs)
                by_post.append({
                    "boxed_share": sum(r[pol][post]["boxed"] for r in recs) / secs,
                    "pinned_share": sum(r[pol][post]["pinned"] for r in recs) / secs,
                    "trapped_share": sum(r[pol][post]["trapped"] for r in recs) / secs,
                    "lock_lane": sum(r[pol][post]["lock_x"] for r in recs) / len(recs),
                })
            secs = sum(r[pol][p]["seconds"] for r in recs for p in range(LANES))
            reach = {}
            for key in ("ok3", "ok5", "n", "free_ok3", "free_n", "blk_ok3", "blk_ok5", "blk_n", "serv_ok3", "serv_n",
                        "first_ok3", "first_n", "presses", "chip"):
                reach[key] = sum(r[pol][p]["reach"][key] for r in recs for p in range(LANES))
            counts: Dict[str, int] = {}
            for r in recs:
                for p in range(LANES):
                    for kk, vv in r[pol][p]["counts"].items():
                        counts[kk] = counts.get(kk, 0) + vv
            row[pol] = {
                "boxed_share": sum(r[pol][p]["boxed"] for r in recs for p in range(LANES)) / secs,
                "pinned_share": sum(r[pol][p]["pinned"] for r in recs for p in range(LANES)) / secs,
                "trapped_share": sum(r[pol][p]["trapped"] for r in recs for p in range(LANES)) / secs,
                "races_boxed_1s": sum(1 for r in recs for p in range(LANES) if r[pol][p]["boxed"] >= 1.0) / (len(recs) * LANES),
                "by_post": by_post, "reach": reach, "counts": counts,
            }
        bsecs = sum(r["bots_seconds"] for r in recs) * LANES
        row["bots_boxed_share"] = sum(sum(r["bots_boxed"]) for r in recs) / bsecs
        out[b] = row
    return out


# ------------------------------------------------------------------ E3 bumps

BUMP_POLICIES = ("scripted", "wanderer", "rail", "masher", "dither")


def _bumps_chunk(args):
    motion_v, boxed_v, bump_v, cell, k0, k1 = args
    cfg = named_cfg(motion_v, boxed_v, bump_v)
    course, distance = S.cells()[cell]
    geo = T.phase_a(course, distance)
    out = []
    for k in range(k0, k1):
        setup = S.race_setup(S.race_seed(6262, cell, k), distance)
        rec = {}
        for pol in BUMP_POLICIES:
            pols = ["bot"] * LANES
            pols[setup["focal"]] = pol
            r = run_race(geo, setup, pols, cfg)
            f = setup["focal"]
            rec[pol] = {"brushes": r["brushes"][f], "cost": r["bump_cost"][f], "presses": sum(r["counts"].values()),
                        "victim_brushes": sum(r["brushes"]) - r["brushes"][f], "overlaps": r["overlaps"]}
        out.append(rec)
    return out


def bumps(races: int, jobs: Optional[int], motion_v: str = "E10w", boxed_v: str = "wait+tuck",
          bump_list=("repeat(eng)", "any(comp)", "repeat(comp)")) -> Dict:
    tasks = [(motion_v, boxed_v, bv, c, a, z) for bv in bump_list for c in range(8) for a, z in S._chunks(races, 10)]
    with Pool(jobs) as pool:
        parts = pool.map(_bumps_chunk, tasks)
    agg: Dict[str, List] = {}
    for (m, b, bv, *_), part in zip(tasks, parts):
        agg.setdefault(bv, []).extend(part)
    out = {}
    for bv in bump_list:
        recs = agg[bv]
        row = {}
        for pol in BUMP_POLICIES:
            rs = [r[pol] for r in recs]
            costs = sorted(r["cost"] for r in rs)
            row[pol] = {
                "brushes_per_race": sum(r["brushes"] for r in rs) / len(rs),
                "races_with_brush": sum(1 for r in rs if r["brushes"] > 0) / len(rs),
                "races_charged": sum(1 for r in rs if r["cost"] > 0) / len(rs),
                "mean_cost": sum(costs) / len(costs),
                "p95_cost": costs[int(0.95 * (len(costs) - 1))],
                "max_cost": costs[-1],
                "presses_per_race": sum(r["presses"] for r in rs) / len(rs),
                "overlaps": sum(r["overlaps"] for r in rs),
            }
        out[bv] = row
    return out


# ------------------------------------------------------------------ E4 griefing

GRIEF = {
    # name: (griefer policies, match feet per griefer)
    "control": ([], []),
    "matched-bots": (["mbot", "mbot", "mbot"], [0.0, 0.0, 12.0]),
    "shadow": (["shadow"], [0.0]),
    "crew": (["crew_in", "crew_out", "crew_ahead"], [0.0, 0.0, 12.0]),
    "bumper": (["bumper"], [0.0]),
    # untargeted controls: the same matched-pace strangers riding for the rail themselves
    "rail1": (["rail"], [0.0]),
    "rail3": (["rail", "rail", "rail"], [0.0, 0.0, 12.0]),
}


def _grief_chunk(args):
    motion_v, boxed_v, bump_v, kid_pol, cell, k0, k1, table = args
    cfg = named_cfg(motion_v, boxed_v, bump_v)
    course, distance = S.cells()[cell]
    geo = T.phase_a(course, distance)
    row = T.baseline_row(table, course, distance)
    out = []
    for k in range(k0, k1):
        setup = S.race_setup(S.race_seed(7373, cell, k), distance)
        kid = setup["focal"]
        others = [i for i in range(LANES) if i != kid]
        random.Random(setup["press_seed"] ^ 0x5EED).shuffle(others)
        rec = {}
        for name, (gpols, feet) in GRIEF.items():
            pols = ["bot"] * LANES
            pols[kid] = kid_pol
            match = {}
            for gi, (gp, ft) in enumerate(zip(gpols, feet)):
                pols[others[gi]] = gp
                match[others[gi]] = ft
            r = run_race(geo, setup, pols, cfg, match or None)
            tk = tau_of(r, row, cfg)[kid]
            rec[name] = {"tau": tk, "trip": r["trip"][kid] - r["bump_cost"][kid], "ground": r["ground"][kid], "draft": r["draft"][kid],
                         "boxed": r["boxed"], "pinned": r["pinned"], "lane": r["lock_x"][kid],
                         "kid_bumps": r["bumps"][kid], "griefer_bumps": sum(r["bumps"][others[g]] for g in range(len(gpols))),
                         "brushes": sum(r["brushes"]), "seconds": r["seconds"], "overlaps": r["overlaps"]}
        out.append(rec)
    return out


def grief(races: int, jobs: Optional[int], combos: Sequence[Tuple[str, str, str, str]]) -> Dict:
    table = _load_row_table()
    tasks = [(m, b, bv, kp, c, a, z, table) for (m, b, bv, kp) in combos for c in range(8) for a, z in S._chunks(races, 10)]
    with Pool(jobs) as pool:
        parts = pool.map(_grief_chunk, tasks)
    agg: Dict[Tuple, List] = {}
    for (m, b, bv, kp, *_), part in zip(tasks, parts):
        agg.setdefault((m, b, bv, kp), []).extend(part)
    out = {}
    for key in combos:
        recs = agg[tuple(key)]
        row = {}
        for name in GRIEF:
            d = sorted(r[name]["tau"] - r["matched-bots"]["tau"] for r in recs)
            d0 = sorted(r[name]["tau"] - r["control"]["tau"] for r in recs)
            secs = sum(r[name]["seconds"] for r in recs)
            dt_ = sorted(r[name]["trip"] - r["matched-bots"]["trip"] for r in recs)
            row[name] = {
                "kid_tau": sum(r[name]["tau"] for r in recs) / len(recs),
                "own_trip_delta": sum(dt_) / len(dt_),
                "own_trip_delta_p5": dt_[int(0.05 * (len(dt_) - 1))],
                "own_trip_share_below_-0.005": sum(1 for v in dt_ if v < -0.005) / len(dt_),
                "ground_delta": sum(r[name]["ground"] - r["matched-bots"]["ground"] for r in recs) / len(recs),
                "draft_delta": sum(r[name]["draft"] - r["matched-bots"]["draft"] for r in recs) / len(recs),
                "delta_vs_matched_bots": sum(d) / len(d),
                "delta_p5": d[int(0.05 * (len(d) - 1))],
                "share_delta_below_-0.005": sum(1 for v in d if v < -0.005) / len(d),
                "delta_vs_control": sum(d0) / len(d0),
                "kid_boxed_share": sum(r[name]["boxed"] for r in recs) / secs,
                "kid_pinned_share": sum(r[name]["pinned"] for r in recs) / secs,
                "kid_lock_lane": sum(r[name]["lane"] for r in recs) / len(recs),
                "kid_bumps_per_race": sum(r[name]["kid_bumps"] for r in recs) / len(recs),
                "griefer_bumps_per_race": sum(r[name]["griefer_bumps"] for r in recs) / len(recs),
                "overlaps": sum(r[name]["overlaps"] for r in recs),
            }
        out["|".join(key)] = row
    return out


# ------------------------------------------------------------------ E5 acceptance targets

def _report_chunk(args):
    cell, k0, k1, cfg, table = args
    course, distance = S.cells()[cell]
    geo = T.phase_a(course, distance)
    row = T.baseline_row(table, course, distance)
    out = []
    for k in range(k0, k1):
        setup = S.race_setup(S.race_seed(S.REPORT_SEED, cell, k), distance)
        f = setup["focal"]
        rec: Dict = {"focal": f, "p1": setup["p1"], "s1": setup["s1"]}
        bots = run_race(geo, setup, ["bot"] * LANES, cfg)
        rec["bot_tau"] = tau_of(bots, row, cfg)
        rec["bot_ground"] = bots["ground"]
        rec["bot_draft"] = bots["draft"]
        rec["min_gap"] = bots["min_gap"]
        sweep_tau, sweep_lane = [], []
        for p in range(LANES):
            pols = ["bot"] * LANES
            pols[p] = "smart"
            res = run_race(geo, setup, pols, cfg)
            sweep_tau.append(tau_of(res, row, cfg)[p])
            sweep_lane.append(res["lock_x"][p])
            rec["min_gap"] = min(rec["min_gap"], res["min_gap"])
        rec["sweep_tau"] = sweep_tau
        rec["smart"] = {"tau": sweep_tau[f], "lane": sweep_lane[f]}
        for pol in S.FOCAL:
            pols = ["bot"] * LANES
            pols[f] = pol
            res = run_race(geo, setup, pols, cfg)
            rr = res["reach"]
            rec[pol] = {"tau": tau_of(res, row, cfg)[f], "lane": res["lock_x"][f],
                        "reach": (rr["ok3"], rr["n"]), "reach_full": rr, "counts": res["counts"],
                        "bumps": res["bumps"][f]}
            rec["min_gap"] = min(rec["min_gap"], res["min_gap"])
        allsmart = run_race(geo, setup, ["smart"] * LANES, cfg)
        rec["allsmart_tau"] = tau_of(allsmart, row, cfg)
        out.append(rec)
    return out


def accept(vname: str, races: int, report_races: int, jobs: Optional[int], cfg: Optional[Dict] = None) -> Dict:
    cfg = cfg or named_cfg(*vname.split("/"))
    if vname == "D054":
        data = S.load_baseline()
    else:
        data = S.generate_baseline(races, jobs, cfg)
    table = data["baseline"]
    tasks = [(c, a, b, cfg, table) for c in range(8) for a, b in S._chunks(report_races, 10)]
    with Pool(jobs) as pool:
        parts = pool.map(_report_chunk, tasks)
    per_cell: Dict[int, List[Dict]] = {}
    for (cell, *_r), part in zip(tasks, parts):
        per_cell.setdefault(cell, []).extend(part)
    summary = S.summarize_report(per_cell, cfg)
    extra = []
    for cell in range(8):
        recs = per_cell[cell]
        rf = {k: sum(x["scripted"]["reach_full"][k] for x in recs) for k in recs[0]["scripted"]["reach_full"]}
        rr = {k: sum(x["rail"]["reach_full"][k] for x in recs) for k in recs[0]["rail"]["reach_full"]}
        extra.append({"cell": S.cells()[cell], "casual": rf, "rail": rr,
                      "rail_bumps": sum(x["rail"]["bumps"] for x in recs) / len(recs),
                      "casual_bumps": sum(x["scripted"]["bumps"] for x in recs) / len(recs)})
    return {"variant": vname, "baseline_races": data["races"], "report_races": report_races,
            "summary": summary, "extra": extra, "text": S.format_report(summary, data, cfg)}


# ------------------------------------------------------------------ main

def save(name: str, obj) -> None:
    RESULTS.mkdir(exist_ok=True)
    (RESULTS / f"{name}.json").write_text(json.dumps(obj, indent=1, default=str))


def main(argv: Sequence[str]) -> int:
    what = argv[1] if len(argv) > 1 else "all"
    jobs = None
    t0 = time.time()
    if what in ("motion", "all"):
        save("e1_motion", motion(int(argv[2]) if len(argv) > 2 and what != "all" else 60, jobs))
        print(f"motion done {time.time() - t0:.0f}s")
    if what in ("boxed", "all"):
        save("e2_boxed", boxed(int(argv[2]) if len(argv) > 2 and what != "all" else 25, jobs))
        print(f"boxed done {time.time() - t0:.0f}s")
    if what in ("bumps", "all"):
        save("e3_bumps", bumps(int(argv[2]) if len(argv) > 2 and what != "all" else 60, jobs))
        print(f"bumps done {time.time() - t0:.0f}s")
    if what in ("grief", "all"):
        combos = [
            ("D054", "d054", "off", "smart_kid"),
            ("D054", "d054", "off", "rail"),
            ("E10w", "wait3+tuck", "off", "smart_kid"),
            ("E10w", "wait3+tuck", "off", "rail"),
            ("E10w", "wait-only", "off", "smart_kid"),
            ("E10w", "wait-only", "off", "rail"),
        ]
        for pays in ("mover", "both", "bumped", "none"):
            combos.append(("E10w", "wait3+tuck", "any(comp)@" + pays, "rail"))
        for pays in ("mover", "bumped"):
            combos.append(("E10w", "wait3+tuck", "any(comp)@" + pays, "smart_kid"))
        save("e4_grief", grief(int(argv[2]) if len(argv) > 2 and what != "all" else 40, jobs, combos))
        print(f"grief done {time.time() - t0:.0f}s")
    if what == "bumpsv":  # python sim012.py bumpsv RACES MOTION BOXED
        save("e3_bumps_" + argv[3] + "_" + argv[4].replace("+", "p"),
             bumps(int(argv[2]), jobs, argv[3], argv[4], ("repeat2s", "repeat(comp)", "repeat(eng)", "any(comp)")))
        print(f"bumpsv done {time.time() - t0:.0f}s")
    if what == "griefv":  # python sim012.py griefv RACES
        if len(argv) > 3 and argv[3] == "final":
            combos = [("E10w", "waitinf+tuck", "repeat2s@mover", "smart_kid"), ("E10w", "waitinf+tuck", "repeat2s@mover", "rail"),
                      ("E10w", "waitinf+tuck", "repeat2s@bumped", "smart_kid"), ("E10w", "waitinf+tuck", "repeat2s@bumped", "rail")]
            save("e4_grief_final", grief(int(argv[2]), jobs, combos))
        else:
            combos = [("E10w", "wait3+tuck", "off", "smart_kid"), ("E10w", "wait3+tuck", "off", "rail"),
                      ("E10w", "wait3+tuck", "repeat(comp)@mover", "smart_kid"), ("E10w", "wait3+tuck", "repeat(comp)@mover", "rail"),
                      ("D054", "d054", "off", "smart_kid"), ("D054", "d054", "off", "rail")]
            save("e4_grief_controls", grief(int(argv[2]), jobs, combos))
        print(f"griefv done {time.time() - t0:.0f}s")
    if what == "boxedv":  # python sim012.py boxedv RACES MOTION BOXED...
        res = boxed(int(argv[2]), jobs, argv[3], tuple(argv[4:]))
        save("e2_boxed_" + "_".join(a.replace("+", "p") for a in argv[3:]), res)
        for b, row in res.items():
            for pol in ("rail", "scripted", "smart_kid"):
                re = row[pol]["reach"]
                n = max(1, re["n"]); fn = max(1, re["free_n"]); bn = max(1, re["blk_n"])
                print(f"{b} {pol}: reach3 {re['ok3']/n:.0%} free {re['free_ok3']/fn:.0%} blocked {re['blk_ok3']/bn:.0%}/{re['blk_ok5']/bn:.0%} "
                      f"boxed {row[pol]['boxed_share']:.1%} trapped {row[pol]['trapped_share']:.2%}")
        print(f"boxedv done {time.time() - t0:.0f}s")
    if what == "accept":
        v = argv[2]
        races = int(argv[3]) if len(argv) > 3 else 1000
        rep = int(argv[4]) if len(argv) > 4 else 300
        res = accept(v, races, rep, jobs)
        save("e5_accept_" + v.replace("/", "_").replace("(", "").replace(")", ""), res)
        print(res["text"])
        print(f"accept done {time.time() - t0:.0f}s")
    return 0


# bump who-pays variants addressed as "any(comp)@mover" etc.
for _pays in ("mover", "both", "bumped", "none"):
    for _b in ("any(comp)", "repeat(comp)", "repeat(eng)", "repeat2s"):
        BUMPS[_b + "@" + _pays] = dict(BUMPS[_b], bumpPays=_pays)

if __name__ == "__main__":
    sys.exit(main(sys.argv))
