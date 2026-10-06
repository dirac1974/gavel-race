#!/usr/bin/env python3
"""DEBATE 012 PROTOTYPE (scratch copy of src/trip.py; never imported by the game or tests).
With the default CONFIG it reproduces src/trip.py exactly (checked by check_parity.py). New,
switchable rules for debate 012: an eased (accel-limited) sideways glide, same-direction chaining,
a reverse gap (anti zig-zag), wait-for-a-gap presses with optional tuck delay, and rule-based
brushes ("bumps") with a who-pays switch and a bump term in tau.

Race steering trip model (D-054): lanes from the gate to the far-turn lock.

Python reference for game/src/shared/Trip.luau; the two must agree exactly (D-012).
Stdlib only. Written to be mirrored line by line in Luau:
- lanes are visited in index order, and every sort uses a total key (offset, then lane
  position, then index), so no tie depends on sort stability;
- step(), lock() and tau() use only +, -, *, /, comparisons, min, max and abs (never exp,
  log or pow), so Python and Luau doubles stay bit-identical;
- nothing iterates a dict where the order could matter;
- a bad lane index or post raises (Python would wrap a negative index; Luau would read nil).

Coordinates: s = feet along the lane-1 path from the gate (the shared pace is speed * t, the
server's timeline: RaceService's tFar is the lock); off = feet ahead of the pace; x = lateral
lane position, 1 (the rail) .. lanes, fractional while gliding. Lane indices are 0-based here
and 1-based in Luau; lane positions and posts are 1-based in both.

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
NOT_ALONG = 1e9  # along_since when no horse is alongside
KINDS = ("bot", "smart", "manual")

# Mirrors GameConfig.steering (S2 copies this block). S0 calibration changed
# groundPerLaneTurn (0.012 -> 0.010), draftPerSecond (0.0012 -> 0.0010) and tuckBackMax
# (12 -> 24), and added bots.wideShare, laneBand and tuckReleasePerSecond, which the plan's
# block left implicit. All values are tuning: docs/research/steering-calibration.md.
CONFIG: Dict = {
    "enabled": True,              # False: today's fixed lanes (tau = 0)
    "scale": 1.0,                 # 0: steering is cosmetic
    "floor": -0.02,               # clamp on tau (1 point of S = 0.02)
    "ceiling": 0.04,
    "groundPerLaneTurn": 0.010,   # per lane off the rail per 180 degrees of turn (plan: 0.012)
    "draftPerSecond": 0.0010,     # (plan: 0.0012)
    "draftCap": 0.016,
    "draftNear": 4.0,             # feet behind the horse ahead in your lane (0.5-3 lengths)
    "draftFar": 24.0,
    "laneSeconds": 0.6,           # one lane's glide
    "minRequestGap": 0.6,         # at most one lane change started per this many seconds
    "maxQueued": 1,               # 0 or 1: one press can wait behind the one in progress
    "clearFeet": 8.0,             # a lane change needs this much room ahead in the new lane...
    "holdGap": 10.0,              # ...and this much behind; a held horse sits this far back
    "holdPullPerSecond": 19.0,    # a hold settles a horse back no faster than this (no hop on screen)
    "tuckBackMax": 24.0,          # ease back at most this far to slot in behind horses (plan: 12)
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
    "tuckReleasePerSecond": 4.0,  # a tuck-back fades this fast once nothing is blocked
    # ---- debate 012 (defaults = D-054 behaviour) ----
    "glide": "linear",            # "linear" (D-054: 1 lane per laneSeconds) or "eased" (S-curve)
    "laneSpeedMax": 1.5,          # eased: top sideways speed (lanes/s; 1.5 = 9 ft/s)
    "laneAccel": 4.5,             # eased: sideways accel and braking (lanes/s^2)
    "chainWindow": 0.0,           # a same-direction change may start this close (lanes) to arriving; 0 = at rest only
    "reverseGapSeconds": 0.0,     # a change opposite to the last one starts at least this long after arriving
    "reverseQueue": True,         # an opposite press during a glide or the gap waits (True) or is refused (False)
    "weaveGapSeconds": 0.0,       # a second reversal within weaveWindowSeconds of the last one waits this long instead
    "weaveWindowSeconds": 5.0,
    "glideReserveFeet": 0.0,      # a horse gliding into a lane keeps this much extra room ahead and behind
    "blockedPress": "d054",       # "d054": inward tucks at once, outward waits outwardWaitSeconds
                                  # "wait": both wait gapWaitSeconds; inward tucks after tuckAfterSeconds if tuckInward
    "gapWaitSeconds": 1.5,        # an outward press waits this long for a gap
    "gapWaitInSeconds": 1.5,      # an inward press that can't tuck back waits this long
    "tuckInward": True,
    "tuckAfterSeconds": 0.0,
    "bump": "off",                # "off" | "any" (a press at a horse alongside) | "repeat" (a second press while the
                                  # first waits); neither ever replaces a tuck-back the press can start
    "bumpAlongFeet": 8.0,         # alongside = within this many feet lengthwise in the next lane
    "bumpGraceSeconds": 0.3,      # ...and alongside for at least this long (lag safety: the rider saw it)
    "bumpRepeatWithin": 0.0,      # "repeat": the second press must come within this long of the first (0 = any time)
    "bumpPays": "mover",          # "mover" | "bumped" | "both" | "none"
    "bumpCost": 0.002,            # tau per charged bump (own term, after the field mean, inside the clamp)
    "bumpFree": 0,                # first N bumps cost nothing
    "bumpMaxCharged": 3,          # at most this many charged; at most bumpFree + this many brushes a race
    "bumpCheckFeet": 4.0,         # the payer steadies this far back (visual)
    "bumpRecoverPerSecond": 2.0,  # ...and comes back at this rate
    "steadySeconds": 1.0,         # no steering for this long after a brush
}

# Mirrors GameConfig: raceSpeedStudsPerSecond, raceShape.leadFeetPerShare, lanes, and the
# race view's gap easing before the lock (RaceView.client.luau, D-055): ease at
# viewEasePerSecond (RaceView's literal `dt * 2.5`), but never faster than
# raceView.maxGapFeetPerSecond unless the horse must hurry to be in place by the line
# (raceView.catchUpMarginSeconds).
RACE: Dict = {"speed": 56.0, "leadFeetPerShare": 320.0, "lanes": 8,
              "viewEasePerSecond": 2.5, "maxGapFeetPerSecond": 10.0, "catchUpMarginSeconds": 0.3}

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
            "turnLength": turn, "lockS": lock_s, "length": plan["length"], "r1": r1,
            "gate": {"straight": plan["straight"], "offset": plan["offset"], "laps": plan["laps"]}}


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
        self.race: Dict = RACE
        self.geo: Dict = {}
        self.n = 0
        self.lanes = 8
        self.speed = 56.0
        self.lead = 320.0
        self.posts: List[int] = []
        self.x: List[float] = []          # lateral lane position
        self.tgt: List[int] = []          # lane being held or glided into
        self.off: List[float] = []        # feet ahead of the pace (held, eased as on screen)
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
        # debate 012
        self.v: List[float] = []          # sideways speed (lanes/s, eased glide)
        self.last_dir: List[int] = []     # direction of the last lane change started
        self.arrived_at: List[float] = [] # when the last glide ended
        self.bumps: List[int] = []        # brushes charged to this horse
        self.brushes: List[int] = []      # brushes started by this horse (charged or not)
        self.check: List[float] = []      # feet below the target after a brush (steadying)
        self.steady_until: List[float] = []
        self.along_since: List[List[float]] = []  # [inside, outside]: since when a horse is alongside
        self.smart_block_at: List[float] = []
        self.events: List[Tuple] = []     # (t, "brush", mover, other, dir)
        self.last_rev_at: List[float] = []  # when the last reversal started
        self.first_press_at: List[float] = []  # when the press now waiting was made


def _check_lane(st: TripState, i: int) -> None:
    if not isinstance(i, int) or i < 0 or i >= st.n:
        raise IndexError(f"lane index {i!r} out of range 0..{st.n - 1}")


def new_state(posts: Sequence[int], q: Sequence[float], uniforms: Sequence[float], geo: Dict,
              cfg: Dict = CONFIG, kinds: Optional[Sequence[str]] = None, race: Dict = RACE) -> TripState:
    """posts[i] = lane i's starting lane position (1..lanes). q = base chances (unused before
    the first step; kept so the call matches Trip.new). uniforms = two per lane in lane order
    (rail, lead), drawn from the race generator after all existing draws; bots use them for
    variety, everyone consumes them. kinds[i] = "bot" (Smart Steer with variety, the default),
    "smart" (a rider with Smart Steer on) or "manual" (Smart Steer off)."""
    n = len(posts)
    lanes = race["lanes"]
    if len(q) != n or len(uniforms) < 2 * n or (kinds is not None and len(kinds) != n):
        raise ValueError("posts, q, uniforms (two per lane) and kinds must cover every lane")
    for p in posts:
        if not isinstance(p, int) or p < 1 or p > lanes:
            raise IndexError(f"post {p!r} out of range 1..{lanes}")
    if cfg["maxQueued"] not in (0, 1):
        raise ValueError("maxQueued is 0 or 1 (one waiting press at most)")
    st = TripState()
    st.cfg, st.race, st.geo, st.n = cfg, race, geo, n
    st.lanes, st.speed, st.lead = lanes, race["speed"], race["leadFeetPerShare"]
    st.posts = list(posts)
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
    st.v = [0.0] * n
    st.last_dir = [0] * n
    st.arrived_at = [LONG_AGO] * n
    st.bumps = [0] * n
    st.brushes = [0] * n
    st.check = [0.0] * n
    st.steady_until = [LONG_AGO] * n
    st.along_since = [[NOT_ALONG, NOT_ALONG] for _ in range(n)]
    st.smart_block_at = [LONG_AGO] * n
    st.events = []
    st.last_rev_at = [LONG_AGO] * n
    st.first_press_at = [LONG_AGO] * n
    smart, bots = cfg["smart"], cfg["bots"]
    for i in range(n):
        u_rail, u_lead = uniforms[2 * i], uniforms[2 * i + 1]
        kind = kinds[i] if kinds is not None else "bot"
        if kind not in KINDS:
            raise ValueError(f"unknown kind {kind!r}")
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
    _check_lane(st, i)
    st.smart[i] = on


# ---------------------------------------------------------------- rider input

def accept_intent(st: TripState, i: int, d: int, t: float) -> str:
    """A rider's lane-change request. Returns "accepted" (starts on this tick if the lane is
    clear), "queued", "cancelled" (the opposite of a press still waiting), or a refusal:
    "locked", "invalid", "bounds", "rate". Every press but a locked or invalid one pauses
    Smart Steer for resumeSeconds. At most one press waits behind the one in progress."""
    _check_lane(st, i)
    cfg = st.cfg
    if st.locked:
        return "locked"
    if d != 1 and d != -1:
        return "invalid"
    st.manual_at[i] = t
    if t < st.steady_until[i] - EPS:
        return "steady"  # debate 012: steadying after a brush
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
    # debate 012: the reverse gap. A change opposite to the last one waits until the horse has
    # run straight for reverseGapSeconds after arriving (commit: never reversing mid-glide).
    rgap = reverse_gap(st, i, t)
    reversing = rgap > 0 and st.last_dir[i] != 0 and d != st.last_dir[i] and \
        (st.x[i] != st.tgt[i] or t - st.arrived_at[i] < rgap - EPS)
    if reversing and not cfg["reverseQueue"] and st.want[i] == 0 and st.queued[i] == 0:
        return "commit"
    idle = st.want[i] == 0 and st.x[i] == st.tgt[i] and t - st.last_change[i] >= cfg["minRequestGap"] - EPS \
        and not reversing
    if idle:
        st.want[i] = d
        st.want_at[i] = t
        st.first_press_at[i] = t
        return "accepted"
    if st.queued[i] == 0 and cfg["maxQueued"] >= 1:
        st.queued[i] = d
        return "queued"
    return "rate"


def reverse_gap(st: TripState, i: int, t: float) -> float:
    """debate 012: how long a horse must run straight after arriving before a change opposite to
    its last one: reverseGapSeconds, or weaveGapSeconds for a second reversal within
    weaveWindowSeconds of the last (a horse settles before changing its mind again)."""
    cfg = st.cfg
    g = cfg["reverseGapSeconds"]
    if cfg["weaveGapSeconds"] > g and t - st.last_rev_at[i] < cfg["weaveWindowSeconds"] - EPS:
        g = cfg["weaveGapSeconds"]
    return g


def lane_after(st: TripState, i: int) -> int:
    """The lane the rider ends up in once every waiting press is done."""
    _check_lane(st, i)
    return st.tgt[i] + st.want[i] + st.queued[i]


# ---------------------------------------------------------------- one tick

def _order(st: TripState) -> List[int]:
    """Leader first (largest offset), then the inside horse, then the lower index."""
    off, x = st.off, st.x
    return sorted(range(st.n), key=lambda i: (-off[i], x[i], i))


def _hold(st: TripState, order: List[int], prev: Sequence[float], dt: float) -> None:
    """A horse may not sit closer than holdGap behind a horse sharing its lane. It settles back
    no faster than holdPullPerSecond, counted from where it was at the start of the tick (prev):
    a horse arriving in a lane a little close (a lane change needs clearFeet ahead, a hold keeps
    holdGap) eases into its place over a few ticks instead of hopping back on screen. Following
    a horse never needs more: a follower moves back with the horse ahead, at most
    maxGapFeetPerSecond."""
    band, gap = st.cfg["laneBand"], st.cfg["holdGap"]
    pull = st.cfg["holdPullPerSecond"] * dt
    off, x = st.off, st.x
    for a in range(st.n):
        i = order[a]
        for b in range(a):
            j = order[b]
            if abs(x[i] - x[j]) < band and off[j] - off[i] < gap:
                off[i] = max(off[j] - gap, min(off[i], prev[i] - pull))


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
        if st.last_dir[i] != 0 and d != st.last_dir[i]:
            st.last_rev_at[i] = t
        st.last_dir[i] = d
        st.smart_block_at[i] = LONG_AGO
        if manual:
            st.want[i] = 0
        return True
    if cfg["blockedPress"] == "d054":
        if d < 0:
            # Tuck-in: ease back to the slot behind the horses alongside, then move in. Only when
            # the slot is at most tuckBackMax behind; otherwise wait for room.
            if st.off[i] - slot <= cfg["tuckBackMax"] + EPS:
                st.tuck[i] = max(0.0, st.skill[i] - slot)
                tucking[i] = True
        elif manual and t - st.want_at[i] >= cfg["outwardWaitSeconds"] - EPS:
            st.want[i] = 0  # no room outside: the request cancels
        return False
    # debate 012 "wait": the press waits for a gap; inward, after tuckAfterSeconds, the horse
    # steadies back (tuck) to the slot behind the horses alongside when it is near enough.
    if manual:
        since = st.want_at[i]
    else:
        if st.smart_block_at[i] == LONG_AGO:
            st.smart_block_at[i] = t
        since = st.smart_block_at[i]
    can_tuck = d < 0 and cfg["tuckInward"] and st.off[i] - slot <= cfg["tuckBackMax"] + EPS
    if can_tuck and t - since >= cfg["tuckAfterSeconds"] - EPS:
        st.tuck[i] = max(0.0, st.skill[i] - slot)
        tucking[i] = True
    elif manual and not can_tuck and t - since >= (cfg["gapWaitInSeconds"] if d < 0 else cfg["gapWaitSeconds"]) - EPS:
        st.want[i] = 0  # no gap came: the press drops quietly
    return False


def _alongside(st: TripState, i: int, d: int) -> int:
    """debate 012: a horse alongside horse i in the next lane on side d (in or gliding into it,
    within bumpAlongFeet lengthwise), or -1. The rail and the outside edge are not horses."""
    lane = st.tgt[i] + d
    if lane < 1 or lane > st.lanes:
        return -1
    band, along = st.cfg["laneBand"], st.cfg["bumpAlongFeet"]
    best, best_gap = -1, 0.0
    for j in range(st.n):
        if j != i and (abs(st.x[j] - lane) < band or st.tgt[j] == lane):
            g = abs(st.off[j] - st.off[i])
            if g < along and (best < 0 or g < best_gap):
                best, best_gap = j, g
    return best


def _brush(st: TripState, i: int, j: int, d: int, t: float) -> None:
    """debate 012: horse i brushes horse j. Who pays follows bumpPays; the payer steadies back
    bumpCheckFeet (visual) and, after bumpFree, is charged up to bumpMaxCharged bumps."""
    cfg = st.cfg
    st.brushes[i] += 1
    st.steady_until[i] = t + cfg["steadySeconds"]
    st.want[i] = 0
    st.queued[i] = 0
    pays = cfg["bumpPays"]
    payers = []
    if pays in ("mover", "both"):
        payers.append(i)
    if pays in ("bumped", "both"):
        payers.append(j)
    for p in payers:
        st.bumps[p] += 1
        st.check[p] = st.check[p] + cfg["bumpCheckFeet"]
    st.events.append((t, "brush", i, j, d))


def bump_charge(st: TripState, i: int) -> float:
    cfg = st.cfg
    charged = min(max(0, st.bumps[i] - cfg["bumpFree"]), cfg["bumpMaxCharged"])
    return cfg["bumpCost"] * charged


def _slot(st: TripState, i: int, lane: int) -> Tuple[float, bool]:
    """Where horse i could enter `lane`, and whether it is blocked now. A horse in that lane
    (or gliding into it) blocks when it is less than clearFeet ahead or less than holdGap
    behind, so the mover never pushes the horse behind it back. The slot is the mover's own
    offset when nothing blocks, else holdGap behind the rearmost blocker, repeated down a line
    of horses. Each pass moves the slot past a horse that then stops counting, so n passes
    always finish."""
    band, clear, gap = st.cfg["laneBand"], st.cfg["clearFeet"], st.cfg["holdGap"]
    reserve = st.cfg["glideReserveFeet"]
    p = st.off[i]
    blocked = False
    for _ in range(st.n):
        lowest = 0.0
        found = False
        for j in range(st.n):
            if j != i and (abs(st.x[j] - lane) < band or st.tgt[j] == lane):
                a = st.off[j] - p
                cj, gj = clear, gap
                if reserve > 0 and st.tgt[j] == lane and st.x[j] != lane:
                    cj, gj = clear + reserve, gap + reserve  # debate 012: a horse gliding in reserves more room
                if a < cj and a > -gj:
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
    for each ("brush" when the press became a brush, debate 012)."""
    for lane_i, _d in intents:
        _check_lane(st, lane_i)
    if st.locked:
        return ["locked" for _ in intents]
    cfg, race = st.cfg, st.race
    n = st.n
    if len(live) != n:
        raise ValueError("one live chance per lane")
    prev = list(st.off)
    ramp = 1.0
    if cfg["gapRampSeconds"] > 0:
        ramp = min(1.0, t / cfg["gapRampSeconds"])
    fair = 1.0 / n
    k = min(1.0, dt * race["viewEasePerSecond"])
    to_line = st.geo["length"] / st.speed - t
    allowed = race["maxGapFeetPerSecond"] * dt
    margin = race["catchUpMarginSeconds"]
    for i in range(n):
        st.skill[i] = st.lead * (live[i] - fair) * ramp
        gap = st.skill[i] - st.tuck[i] - st.check[i] - st.off[i]
        if to_line <= margin:
            limit = math.inf
        else:
            limit = max(allowed, abs(gap) * dt / (to_line - margin))
        st.off[i] = st.off[i] + min(limit, max(-limit, gap * k))
    _hold(st, _order(st), prev, dt)
    order = _order(st)
    bump_on = cfg["bump"] != "off"
    if bump_on:
        for i in range(n):
            for side in (0, 1):
                j = _alongside(st, i, -1 if side == 0 else 1)
                if j < 0:
                    st.along_since[i][side] = NOT_ALONG
                elif st.along_since[i][side] == NOT_ALONG:
                    st.along_since[i][side] = t
    tried = [False] * n
    tucking = [False] * n
    answers = []
    max_brush = cfg["bumpFree"] + cfg["bumpMaxCharged"]
    for lane_i, d in intents:
        if bump_on and (d == 1 or d == -1) and t >= st.steady_until[lane_i] - EPS \
                and st.brushes[lane_i] < max_brush:
            side = 0 if d < 0 else 1
            j = _alongside(st, lane_i, d)
            seen = j >= 0 and t - st.along_since[lane_i][side] >= cfg["bumpGraceSeconds"] - EPS
            at_rest = st.x[lane_i] == st.tgt[lane_i]
            tuckable = False
            if seen and d < 0 and cfg["tuckInward"] and cfg["blockedPress"] != "off":
                slot, _b = _slot(st, lane_i, st.tgt[lane_i] - 1)
                tuckable = st.off[lane_i] - slot <= cfg["tuckBackMax"] + EPS
            busy = st.tuck[lane_i] > 0 and st.want[lane_i] == d
            quick = cfg["bumpRepeatWithin"] <= 0 or t - st.first_press_at[lane_i] <= cfg["bumpRepeatWithin"] + EPS
            if seen and at_rest and not tuckable and not busy and                     (cfg["bump"] == "any" or (st.want[lane_i] == d and quick)):
                st.manual_at[lane_i] = t
                _brush(st, lane_i, j, d, t)
                answers.append("brush")
                continue
        answer = accept_intent(st, lane_i, d, t)
        answers.append(answer)
        if answer == "accepted":
            tried[lane_i] = True
            _try_move(st, lane_i, st.want[lane_i], t, tucking, True)
    s0 = st.speed * t
    in_turn, to_turn = _turn_info(st.geo, s0)
    resume = cfg["smart"]["resumeSeconds"]
    chain = cfg["chainWindow"]
    rgap = cfg["reverseGapSeconds"]
    for a in range(n):
        i = order[a]
        if tried[i]:
            continue
        moving = st.x[i] != st.tgt[i]
        mdir = 0
        if moving:
            mdir = 1 if st.tgt[i] > st.x[i] else -1
            if chain <= 0 or abs(st.tgt[i] - st.x[i]) > chain + EPS:
                continue
        if t - st.last_change[i] < cfg["minRequestGap"] - EPS:
            continue
        if st.want[i] == 0 and st.queued[i] != 0:
            if moving and st.queued[i] != mdir:
                continue
            st.want[i] = st.queued[i]
            st.want_at[i] = t
            st.queued[i] = 0
        if st.want[i] != 0:
            d = st.want[i]
            if moving and d != mdir:
                continue
            if rgap > 0 and st.last_dir[i] != 0 and d != st.last_dir[i] and t - st.arrived_at[i] < reverse_gap(st, i, t) - EPS:
                st.want_at[i] = t  # the wait for a gap starts once the horse may move
                continue
            _try_move(st, i, d, t, tucking, True)
        elif st.smart[i] and t - st.manual_at[i] >= resume - EPS and st.tgt[i] > st.home[i]:
            if moving and mdir != -1:
                continue
            if rgap > 0 and st.last_dir[i] == 1 and t - st.arrived_at[i] < reverse_gap(st, i, t) - EPS:
                continue
            if in_turn or to_turn <= st.turn_lead[i] * st.speed + EPS:
                _try_move(st, i, -1, t, tucking, False)
    # 4. Lateral glide, then hold again so a horse arriving in a lane never overlaps.
    if cfg["glide"] == "eased":
        acc, vmax = cfg["laneAccel"], cfg["laneSpeedMax"]
        adt = acc * dt
        for i in range(n):
            if st.x[i] == st.tgt[i] and st.v[i] == 0:
                continue
            diff = st.tgt[i] - st.x[i]
            dist = abs(diff)
            if dist <= EPS:
                st.x[i] = float(st.tgt[i])
                st.v[i] = 0.0
                st.arrived_at[i] = t + dt
                continue
            sgn = 1.0 if diff > 0 else -1.0
            # discrete braking: the speed from which steps of adt per tick stop exactly in dist
            vb = adt * (math.sqrt(0.25 + 2.0 * dist / (adt * dt)) - 0.5)
            vdes = sgn * min(vmax, vb)
            st.v[i] = st.v[i] + min(adt, max(-adt, vdes - st.v[i]))
            nx = st.x[i] + st.v[i] * dt
            if (nx - st.tgt[i]) * sgn >= -EPS:
                st.x[i] = float(st.tgt[i])
                st.v[i] = 0.0
                st.arrived_at[i] = t + dt
            else:
                st.x[i] = nx
    else:
        glide = dt / cfg["laneSeconds"]
        for i in range(n):
            if st.x[i] != st.tgt[i]:
                diff = st.tgt[i] - st.x[i]
                if abs(diff) <= glide + EPS:
                    st.x[i] = float(st.tgt[i])
                    st.arrived_at[i] = t + dt
                elif diff > 0:
                    st.x[i] = st.x[i] + glide
                else:
                    st.x[i] = st.x[i] - glide
    _hold(st, order, prev, dt)
    release = cfg["tuckReleasePerSecond"] * dt
    for i in range(n):
        if not tucking[i] and st.tuck[i] > 0:
            st.tuck[i] = max(0.0, st.tuck[i] - release)
    if bump_on:
        rec = cfg["bumpRecoverPerSecond"] * dt
        for i in range(n):
            if st.check[i] > 0:
                st.check[i] = max(0.0, st.check[i] - rec)
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


def tau(trip: Sequence[float], posts: Sequence[int], baseline: Sequence[float], cfg: Dict = CONFIG,
        bump_cost: Optional[Sequence[float]] = None) -> List[float]:
    """tau_i = clamp(scale * (trip_i - baseline[post_i] - field mean of the same), floor,
    ceiling). baseline = the per-post row for this course and distance."""
    n = len(trip)
    if len(posts) != n:
        raise ValueError("one post per lane")
    for p in posts:
        if not isinstance(p, int) or p < 1 or p > len(baseline):
            raise IndexError(f"post {p!r} out of range 1..{len(baseline)}")
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
        if bump_cost is not None:
            v = v - cfg["scale"] * bump_cost[i]  # debate 012: own term, after the field mean
        out.append(min(cfg["ceiling"], max(cfg["floor"], v)))
    return out


def trip_stars(t: float, cfg: Dict = CONFIG) -> int:
    """Results line "Good trip": three stars, two, or one (never zero)."""
    if t >= cfg["stars"][0]:
        return 3
    if t >= cfg["stars"][1]:
        return 2
    return 1
