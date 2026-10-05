#!/usr/bin/env python3
"""Race steering trip model (D-054): lanes from the gate to the far-turn lock.

Python reference for game/src/shared/Trip.luau; the two must agree exactly (D-012).
Stdlib only. Written to be mirrored line by line in Luau:
- lanes are visited in index order, and every sort uses a total key (offset, then lane
  position, then index), so no tie depends on sort stability;
- step(), lock() and tau() use only +, -, *, /, comparisons, min, max and abs (never exp,
  log or pow), so Python and Luau doubles stay bit-identical;
- nothing iterates a dict where the order could matter.

Coordinates: s = feet along the lane-1 path from the gate (the shared pace is speed * t);
off = feet ahead of the pace; x = lateral lane position, 1 (the rail) .. lanes, fractional
while gliding. Lane indices are 0-based here and 1-based in Luau; lane positions and posts
are 1-based in both.

One race: geo = phase_a(course, distance); st = new_state(posts, q, uniforms, geo);
step(st, live, intents, t, dt) on every 10 Hz tick while t < lock time; lock(st);
trip = trip_values(st); t_i = tau(trip, posts, baseline_row(table, course, distance)).
The exponent becomes kappa * R + c + tau (live_chances(..., extra) in gavel_race_v2).
"""

from __future__ import annotations

import math
from typing import Dict, List, Optional, Sequence, Tuple

EPS = 1e-9
LONG_AGO = -1e9  # "never" for request and change times

# Mirrors GameConfig.steering (S2 copies this block). S0 calibration changed
# groundPerLaneTurn (0.012 -> 0.010) and added bots.wideShare and the last three keys, which
# the plan's block left implicit. All values are tuning: docs/research/steering-calibration.md.
CONFIG: Dict = {
    "enabled": True,              # False: today's fixed lanes (tau = 0)
    "scale": 1.0,                 # 0: steering is cosmetic
    "floor": -0.02,               # clamp on tau (1 point of S = 0.02)
    "ceiling": 0.04,
    "groundPerLaneTurn": 0.010,   # per lane off the rail per 180 degrees of turn (D-054 said 0.012; S0 calibration)
    "draftPerSecond": 0.0012,
    "draftCap": 0.016,
    "draftNear": 4.0,             # feet behind the horse ahead in your lane (0.5-3 lengths)
    "draftFar": 24.0,
    "laneSeconds": 0.6,           # one lane's glide
    "minRequestGap": 0.6,         # at most one lane change started per this many seconds
    "maxQueued": 1,
    "clearFeet": 8.0,             # a lane is blocked by a horse within +-1 length
    "holdGap": 10.0,              # a held horse sits this far behind the one ahead
    "tuckBackMax": 12.0,          # ease back at most this far to slot in behind a horse
    "outwardWaitSeconds": 1.0,    # a blocked move outward cancels after this long
    "tickHz": 10,
    "sendHz": 10,
    "gapRampSeconds": 8.0,        # skill gaps grow in over this long from the gate
    "lockBellSeconds": 3.0,
    "smart": {"homeLane": 2, "turnLeadSeconds": 8.0, "resumeSeconds": 5.0},
    "bots": {"turnLeadMin": 4.0, "turnLeadMax": 12.0, "railShare": 0.25, "wideShare": 0.20},
    "introRaces": 3,
    "stars": [0.015, -0.005],     # trip three-star and two-star thresholds
    "laneBand": 0.9,              # horses closer than this (in lanes) share a lane
    "smoothPerSecond": 2.5,       # offsets ease toward their target at this rate (the client lerp)
    "tuckReleasePerSecond": 4.0,  # a tuck-back fades this fast once nothing is blocked
}

# Mirrors GameConfig: raceSpeedStudsPerSecond, raceShape.leadFeetPerShare, lanes.
RACE: Dict = {"speed": 56.0, "leadFeetPerShare": 320.0, "lanes": 8}

# Mirrors TrackLayout.churchill / churchillTurf and TrackLayout.distances.
COURSES: Dict[str, Dict] = {
    "dirt": {"straight": 1320.0, "railRadius": 417.0, "laneOffset": 4.0, "laneWidth": 6.0,
             "lanes": 8, "finishFromTop": 1234.5},
    "turf": {"straight": 1320.0, "railRadius": 417.0 - 30.0 - 80.0, "laneOffset": 4.0, "laneWidth": 6.0,
             "lanes": 8, "finishFromTop": 1234.5},
}
COURSE_ORDER: Tuple[str, ...] = ("dirt", "turf")
DISTANCES: Dict[str, float] = {"Sprint": 3960.0, "Mile": 5280.0, "Classic": 6600.0, "Marathon": 7920.0}
DISTANCE_ORDER: Tuple[str, ...] = ("Sprint", "Mile", "Classic", "Marathon")


# ---------------------------------------------------------------- geometry

def _lmod(a: float, b: float) -> float:
    """Luau's float %: a - floor(a / b) * b (Python's % rounds differently)."""
    return a - math.floor(a / b) * b


def lane_radius(cfg: Dict, i: int) -> float:
    return cfg["railRadius"] + cfg["laneOffset"] + (i - 0.5) * cfg["laneWidth"]


def lap_length(cfg: Dict, r: float) -> float:
    return 2 * cfg["straight"] + 2 * math.pi * r


def gate_plan(cfg: Dict, distance: float) -> Dict:
    """TrackLayout.plan for lane 1: which straight the gate is on, how far along, and the
    lane-1 race length."""
    r1 = lane_radius(cfg, 1)
    lap1 = lap_length(cfg, r1)
    laps = math.floor((distance - 1e-6) / lap1)
    d = _lmod(cfg["finishFromTop"] - (distance - laps * lap1), lap1)
    straight_len, turn = cfg["straight"], math.pi * r1
    if d < straight_len:
        straight, offset = "home", d
    elif d < straight_len + turn:
        straight, offset = "back", 0.0
    elif d < 2 * straight_len + turn:
        straight, offset = "back", d - straight_len - turn
    else:
        straight, offset = "home", 0.0
    s = offset if straight == "home" else cfg["straight"] + math.pi * r1 + offset
    length = _lmod(cfg["finishFromTop"] - s, lap1) + laps * lap1
    if length < 1:
        length += lap1
    return {"straight": straight, "offset": offset, "laps": laps, "length": length}


def phase_a(course: str, distance: str) -> Dict:
    """Phase A: the gate to the final far-turn entry (the lock), as straights and turns along
    the lane-1 path. Turns before the lock count live; the far turn is booked at the lock."""
    cfg = COURSES[course]
    plan = gate_plan(cfg, DISTANCES[distance])
    r1 = lane_radius(cfg, 1)
    turn = math.pi * r1
    lock_s = plan["length"] - cfg["finishFromTop"] - turn
    kinds = ("S", "T", "S", "T")  # home straight, clubhouse turn, backstretch, far turn
    lens = (cfg["straight"], turn, cfg["straight"], turn)
    k = 0 if plan["straight"] == "home" else 2
    within = plan["offset"]
    segments: List[Dict] = []
    s = 0.0
    while lock_s - s > EPS:
        rem = lens[k] - within
        run = min(rem, lock_s - s)
        segments.append({"kind": kinds[k], "start": s, "length": run})
        s = s + run
        if run >= rem:
            k = (k + 1) % 4
            within = 0.0
        else:
            within = within + run
    turns = [(g["start"], g["start"] + g["length"]) for g in segments if g["kind"] == "T"]
    return {"course": course, "distance": distance, "segments": segments, "turns": turns,
            "turnLength": turn, "lockS": lock_s, "length": plan["length"], "r1": r1}


def _turn_info(geo: Dict, s: float) -> Tuple[bool, float]:
    """(inside a live turn?, feet to the next turn start, the far turn at the lock included)."""
    nxt = geo["lockS"]
    for a, b in geo["turns"]:
        if a <= s < b:
            return True, 0.0
        if a > s and a < nxt:
            nxt = a
    return False, nxt - s


# ---------------------------------------------------------------- state

class TripState:
    """Per-race steering state. Lists are indexed by lane index (0-based)."""

    def __init__(self) -> None:
        self.cfg: Dict = CONFIG
        self.geo: Dict = {}
        self.n = 0
        self.lanes = 8
        self.speed = 56.0
        self.lead = 320.0
        self.posts: List[int] = []
        self.live: List[float] = []
        self.x: List[float] = []          # lateral lane position
        self.tgt: List[int] = []          # lane being held or glided into
        self.off: List[float] = []        # feet ahead of the pace (held, smoothed)
        self.skill: List[float] = []      # this tick's skill target (ramped), before any tuck
        self.tuck: List[float] = []       # feet below the skill target, to slot in behind a horse
        self.drafting: List[bool] = []    # tucked in behind a horse this tick
        self.ground: List[float] = []
        self.draft: List[float] = []
        self.want: List[int] = []         # rider's lane change waiting to start (-1 in, +1 out)
        self.want_at: List[float] = []
        self.queued: List[int] = []
        self.manual_at: List[float] = []  # last rider input (pauses Smart Steer)
        self.last_change: List[float] = []
        self.smart: List[bool] = []
        self.home: List[int] = []         # Smart Steer's lane
        self.turn_lead: List[float] = []  # Smart Steer heads in this long before a turn
        self.locked = False


def new_state(posts: Sequence[int], q: Sequence[float], uniforms: Sequence[float], geo: Dict,
              cfg: Dict = CONFIG, kinds: Optional[Sequence[str]] = None, race: Dict = RACE) -> TripState:
    """posts[i] = lane i's starting lane position. q = base chances (the live chances until
    the first checkpoint). uniforms = two per lane in lane order (rail, lead), drawn from the
    race generator after all existing draws; bots use them for variety, everyone consumes
    them. kinds[i] = "bot" (Smart Steer with variety, the default), "smart" (a rider with
    Smart Steer on) or "manual" (Smart Steer off)."""
    n = len(posts)
    st = TripState()
    st.cfg, st.geo, st.n = cfg, geo, n
    st.lanes, st.speed, st.lead = race["lanes"], race["speed"], race["leadFeetPerShare"]
    st.posts = list(posts)
    st.live = list(q)
    st.x = [float(p) for p in posts]
    st.tgt = [int(p) for p in posts]
    st.off = [0.0] * n
    st.skill = [0.0] * n
    st.tuck = [0.0] * n
    st.drafting = [False] * n
    st.ground = [0.0] * n
    st.draft = [0.0] * n
    st.want = [0] * n
    st.want_at = [LONG_AGO] * n
    st.queued = [0] * n
    st.manual_at = [LONG_AGO] * n
    st.last_change = [LONG_AGO] * n
    smart, bots = cfg["smart"], cfg["bots"]
    for i in range(n):
        u_rail, u_lead = uniforms[2 * i], uniforms[2 * i + 1]
        kind = kinds[i] if kinds is not None else "bot"
        if kind == "bot":
            st.smart.append(True)
            if u_rail < bots["railShare"]:
                st.home.append(1)
            elif u_rail >= 1 - bots["wideShare"]:
                st.home.append(smart["homeLane"] + 1)
            else:
                st.home.append(smart["homeLane"])
            st.turn_lead.append(bots["turnLeadMin"] + (bots["turnLeadMax"] - bots["turnLeadMin"]) * u_lead)
        else:
            st.smart.append(kind == "smart")
            st.home.append(smart["homeLane"])
            st.turn_lead.append(smart["turnLeadSeconds"])
    return st


def set_smart(st: TripState, i: int, on: bool) -> None:
    """Settings toggle, or a disconnect (on = True)."""
    st.smart[i] = on


# ---------------------------------------------------------------- rider input

def accept_intent(st: TripState, i: int, d: int, t: float) -> str:
    """A rider's lane-change request. Returns "accepted" (starts on this tick if the lane is
    clear), "queued", "cancelled" (the opposite of a press still waiting), or a refusal:
    "locked", "invalid", "bounds", "rate". Every press but a locked or invalid one pauses
    Smart Steer for resumeSeconds."""
    cfg = st.cfg
    if st.locked:
        return "locked"
    if d != 1 and d != -1:
        return "invalid"
    st.manual_at[i] = t
    last = st.queued[i] if st.queued[i] != 0 else st.want[i]
    if last != 0 and last != d:
        if st.queued[i] != 0:
            st.queued[i] = 0
        else:
            st.want[i] = 0
        return "cancelled"
    after = st.tgt[i] + st.want[i] + st.queued[i]
    if after + d < 1 or after + d > st.lanes:
        return "bounds"
    idle = st.want[i] == 0 and st.x[i] == st.tgt[i] and t - st.last_change[i] >= cfg["minRequestGap"] - EPS
    if idle:
        st.want[i] = d
        st.want_at[i] = t
        return "accepted"
    if st.queued[i] == 0 and cfg["maxQueued"] >= 1:
        st.queued[i] = d
        return "queued"
    return "rate"


def lane_after(st: TripState, i: int) -> int:
    """The lane the rider ends up in once every waiting press is done."""
    return st.tgt[i] + st.want[i] + st.queued[i]


# ---------------------------------------------------------------- one tick

def _order(st: TripState) -> List[int]:
    """Leader first (largest offset), then the inside horse, then the lower index."""
    off, x = st.off, st.x
    return sorted(range(st.n), key=lambda i: (-off[i], x[i], i))


def _hold(st: TripState, order: List[int]) -> None:
    """A horse may not sit closer than holdGap behind a horse sharing its lane."""
    band, gap = st.cfg["laneBand"], st.cfg["holdGap"]
    off, x = st.off, st.x
    for a in range(st.n):
        i = order[a]
        for b in range(a):
            j = order[b]
            if abs(x[i] - x[j]) < band and off[j] - off[i] < gap:
                off[i] = off[j] - gap


def _try_move(st: TripState, i: int, d: int, t: float, tucking: List[bool], manual: bool) -> bool:
    cfg = st.cfg
    lane = st.tgt[i] + d
    if lane < 1 or lane > st.lanes:
        if manual:
            st.want[i] = 0
        return False
    slot, blocked = _slot(st, i, lane)
    if not blocked:
        st.tgt[i] = lane
        st.last_change[i] = t
        if manual:
            st.want[i] = 0
        return True
    if d < 0:
        # Tuck-in: ease back to the slot behind the horses alongside, then move in. Only when
        # the slot is at most tuckBackMax behind; otherwise wait for room.
        if st.off[i] - slot <= cfg["tuckBackMax"] + EPS:
            st.tuck[i] = max(0.0, st.skill[i] - slot)
            tucking[i] = True
    elif manual and t - st.want_at[i] >= cfg["outwardWaitSeconds"] - EPS:
        st.want[i] = 0  # no room outside: the request cancels
    return False


def _slot(st: TripState, i: int, lane: int) -> Tuple[float, bool]:
    """Where horse i could enter `lane`, and whether it is blocked now: its own offset if
    nothing in that lane (or gliding into it) is within clearFeet, else holdGap behind the
    rearmost such horse, repeated down a line of horses. Each pass moves the slot past a
    horse that then stops counting, so n passes always finish."""
    band, clear, gap = st.cfg["laneBand"], st.cfg["clearFeet"], st.cfg["holdGap"]
    p = st.off[i]
    blocked = False
    for _ in range(st.n):
        lowest = 0.0
        found = False
        for j in range(st.n):
            if j != i and (abs(st.x[j] - lane) < band or st.tgt[j] == lane) and abs(st.off[j] - p) < clear:
                if not found or st.off[j] < lowest:
                    lowest = st.off[j]
                found = True
        if not found:
            break
        blocked = True
        p = lowest - gap
    return p, blocked


def step(st: TripState, live: Sequence[float], intents: Sequence[Tuple[int, int]], t: float, dt: float) -> List[str]:
    """One server tick at race time t (seconds since the gate) lasting dt. intents = this
    tick's (lane index, direction) requests in arrival order; returns accept_intent's answer
    for each."""
    if st.locked:
        return ["locked" for _ in intents]
    cfg = st.cfg
    n = st.n
    st.live = list(live)
    # 1. Skill targets (gaps ramp in from the gate), minus any tuck-back; ease toward them.
    ramp = 1.0
    if cfg["gapRampSeconds"] > 0:
        ramp = min(1.0, t / cfg["gapRampSeconds"])
    fair = 1.0 / n
    k = min(1.0, dt * cfg["smoothPerSecond"])
    for i in range(n):
        st.skill[i] = st.lead * (live[i] - fair) * ramp
        target = st.skill[i] - st.tuck[i]
        st.off[i] = st.off[i] + (target - st.off[i]) * k
    # 2. Hold: nobody overlaps the horse ahead in its lane.
    _hold(st, _order(st))
    order = _order(st)
    # 3. Lane changes: this tick's requests in arrival order, then everyone else leader
    #    first, then the inside horse.
    tried = [False] * n
    tucking = [False] * n
    answers = []
    for lane_i, d in intents:
        answer = accept_intent(st, lane_i, d, t)
        answers.append(answer)
        if answer == "accepted":
            tried[lane_i] = True
            _try_move(st, lane_i, st.want[lane_i], t, tucking, True)
    s0 = st.speed * t
    in_turn, to_turn = _turn_info(st.geo, s0)
    resume = cfg["smart"]["resumeSeconds"]
    for a in range(n):
        i = order[a]
        if tried[i] or st.x[i] != st.tgt[i]:
            continue
        if t - st.last_change[i] < cfg["minRequestGap"] - EPS:
            continue
        if st.want[i] == 0 and st.queued[i] != 0:
            st.want[i] = st.queued[i]
            st.want_at[i] = t
            st.queued[i] = 0
        if st.want[i] != 0:
            _try_move(st, i, st.want[i], t, tucking, True)
        elif st.smart[i] and t - st.manual_at[i] >= resume - EPS and st.tgt[i] > st.home[i]:
            # Smart Steer: heads in before and through turns, never out, never for a draft.
            if in_turn or to_turn <= st.turn_lead[i] * st.speed + EPS:
                _try_move(st, i, -1, t, tucking, False)
    # 4. Lateral glide, then hold again so a horse arriving in a lane never overlaps.
    glide = dt / cfg["laneSeconds"]
    for i in range(n):
        if st.x[i] != st.tgt[i]:
            diff = st.tgt[i] - st.x[i]
            if abs(diff) <= glide + EPS:
                st.x[i] = float(st.tgt[i])
            elif diff > 0:
                st.x[i] = st.x[i] + glide
            else:
                st.x[i] = st.x[i] - glide
    _hold(st, order)
    release = cfg["tuckReleasePerSecond"] * dt
    for i in range(n):
        if not tucking[i] and st.tuck[i] > 0:
            st.tuck[i] = max(0.0, st.tuck[i] - release)
    # 5. Ground on live turns (per 180 degrees) and the tucked-in draft, before the lock.
    s1 = st.speed * (t + dt)
    f = 0.0
    for a_s, b_s in st.geo["turns"]:
        ov = min(s1, b_s) - max(s0, a_s)
        if ov > 0:
            f = f + ov / st.geo["turnLength"]
    if f > 0:
        f = f * cfg["groundPerLaneTurn"]
        for i in range(n):
            st.ground[i] = st.ground[i] + f * (st.x[i] - 1)
    dte = min(dt, st.geo["lockS"] / st.speed - t)
    band, near, far = cfg["laneBand"], cfg["draftNear"], cfg["draftFar"]
    cap, rate = cfg["draftCap"], cfg["draftPerSecond"]
    for i in range(n):
        tucked = False
        if dte > 0:
            for j in range(n):
                if j != i and abs(st.x[j] - st.x[i]) < band:
                    ahead = st.off[j] - st.off[i]
                    if ahead >= near and ahead <= far:
                        tucked = True
                        break
        st.drafting[i] = tucked
        if tucked and st.draft[i] < cap:
            st.draft[i] = min(cap, st.draft[i] + rate * dte)
    return answers


def lock(st: TripState) -> None:
    """The far-turn bell: book the far turn from each horse's lane position, freeze the trip."""
    if st.locked:
        return
    g = st.cfg["groundPerLaneTurn"]
    for i in range(st.n):
        st.ground[i] = st.ground[i] + g * (st.x[i] - 1)
        st.want[i] = 0
        st.queued[i] = 0
    st.locked = True


def lock_time(geo: Dict, race: Dict = RACE) -> float:
    """Seconds from the gate to the lock (RaceService's tFar - tStart)."""
    return geo["lockS"] / race["speed"]


# ---------------------------------------------------------------- trip and tau

def trip_values(st: TripState) -> List[float]:
    """Each lane's trip: tucked-in draft minus ground lost on turns."""
    cap = st.cfg["draftCap"]
    return [min(st.draft[i], cap) - st.ground[i] for i in range(st.n)]


def baseline_row(table: Dict, course: str, distance: str) -> List[float]:
    return table[course][distance]


def tau(trip: Sequence[float], posts: Sequence[int], baseline: Sequence[float], cfg: Dict = CONFIG) -> List[float]:
    """tau_i = clamp(scale * (trip_i - baseline[post_i] - field mean of the same), floor,
    ceiling). baseline = the per-post row for this course and distance."""
    n = len(trip)
    if not cfg["enabled"]:
        return [0.0] * n
    adj = [trip[i] - baseline[posts[i] - 1] for i in range(n)]
    total = 0.0
    for i in range(n):
        total = total + adj[i]
    mean = total / n
    out = []
    for i in range(n):
        v = cfg["scale"] * (adj[i] - mean)
        out.append(min(cfg["ceiling"], max(cfg["floor"], v)))
    return out


def trip_stars(t: float, cfg: Dict = CONFIG) -> int:
    """Results line "Good trip": three stars, two, or one (never zero)."""
    if t >= cfg["stars"][0]:
        return 3
    if t >= cfg["stars"][1]:
        return 2
    return 1


def run_scripted(geo: Dict, posts: Sequence[int], q: Sequence[float], p1: Sequence[float], switch_tick: int,
                 uniforms: Sequence[float], kinds: Optional[Sequence[str]], intents_by_tick: Dict[int, List[Tuple[int, int]]],
                 cfg: Dict = CONFIG, race: Dict = RACE, snapshot_every: int = 0):
    """Plays phase A with live = q before switch_tick and p1 from it (the first checkpoint),
    and fixed per-tick intents. Returns (state, snapshots: list of (tick, x, off))."""
    st = new_state(posts, q, uniforms, geo, cfg, kinds, race)
    dt = 1.0 / cfg["tickHz"]
    t_lock = lock_time(geo, race)
    snaps = []
    tick = 0
    while tick * dt < t_lock - EPS:
        t = tick * dt
        live = q if tick < switch_tick else p1
        step(st, live, intents_by_tick.get(tick, []), t, dt)
        if snapshot_every and tick % snapshot_every == 0:
            snaps.append((tick, list(st.x), list(st.off)))
        tick += 1
    lock(st)
    return st, snaps
