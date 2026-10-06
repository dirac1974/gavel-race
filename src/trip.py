#!/usr/bin/env python3
"""Race steering trip model (D-054, D-057): lanes from the gate to the far-turn lock.

Python reference for game/src/shared/Trip.luau; the two must agree exactly (D-012).
Stdlib only. Written to be mirrored line by line in Luau:
- lanes are visited in index order, and every sort uses a total key (offset, then lane
  position, then index), so no tie depends on sort stability;
- step(), lock() and tau() use only +, -, *, /, comparisons, min, max, abs and sqrt (never exp,
  log or pow). sqrt is correctly rounded under IEEE 754 in CPython and Luau alike, so Python and
  Luau doubles stay bit-identical (it is only used by the D-057 eased glide);
- nothing iterates a dict where the order could matter;
- a bad lane index or post raises (Python would wrap a negative index; Luau would read nil).

Coordinates: s = feet along the lane-1 path from the gate (the shared pace is speed * t, the
server's timeline: RaceService's tFar is the lock); off = feet ahead of the pace; x = lateral
lane position, 1 (the rail) .. lanes, fractional while gliding. Lane indices are 0-based here
and 1-based in Luau; lane positions and posts are 1-based in both.

One race: geo = phase_a(course, distance); st = new_state(posts, q, uniforms, geo);
step(st, live, intents, t, dt) on every 10 Hz tick while t < lock time; lock(st);
trip = trip_values(st); t_i = tau(trip, posts, baseline_row(table, course, distance),
brush=brush_charges(st)). The exponent becomes kappa * R + c + tau (live_chances(..., extra) in
gavel_race_v2).

D-057 (natural steering, boxed in, brushes): N1 built every rule switched off; N3 switched the
motion and press rules on in CONFIG (the eased glide, chaining, the reverse and weave gaps, the
press bounce, the glide reserve and wait-for-room presses). Brushes stay off until N5. D057 holds
every switch; d057_config() builds the full D-057 config (brushes on) and d054_config() the
D-054 one (every D-057 switch off: the switch-back, and the config of files made before D-057).
"""

from __future__ import annotations

import copy
import math
from typing import Dict, List, Optional, Sequence, Tuple

EPS = 1e-9
LONG_AGO = -1e9  # "never" for request and change times
NOT_ALONG = 1e9  # along_since when no horse is alongside (D-057 brushes)
KINDS = ("bot", "smart", "manual")
GLIDES = ("linear", "eased")
BLOCKED_PRESS = ("d054", "wait")
BRUSH_RULES = ("off", "repeat")
BRUSH_PAYS = ("mover", "bumped", "both", "none")

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
    # ---- D-057: N3 switched the motion and press rules on (D-054 values in D057_OFF, the
    # switch-back: d054_config()). Brushes stay off until N5. ----
    "glide": "eased",             # "eased": S-curve (D-057); "linear": one lane per laneSeconds (D-054)
    "laneSpeedMax": 1.5,          # eased: top sideways speed, lanes/s (9 ft/s)
    "laneAccel": 4.5,             # eased: sideways acceleration and braking, lanes/s^2 (27 ft/s^2)
    "chainWindow": 0.3,           # a same-way change may start this close (lanes) to landing (D-054 0)
    "reverseGapSeconds": 0.5,     # a change the other way starts this long after landing (D-054 0)
    "weaveGapSeconds": 2.5,       # ...or this long, for a second reversal within the window (D-054 0)
    "weaveWindowSeconds": 7.0,    # N1 review: 7 (D-057 said 5); every masher cell under 8 reversals a minute
    "pressBounceSeconds": 0.2,    # a press the same way this soon after the last counts once (D-054 0)
    "glideReserveFeet": 6.0,      # a horse gliding into a lane keeps this much more room (D-054 0)
    "blockedPress": "wait",       # "wait" (D-057) or "d054": a press into a lane with no room
    "gapWaitSeconds": 1.5,        # wait: an outward press waits this long for room, then drops
    "gapWaitInSeconds": 0.0,      # wait: an inward press that can't tuck back drops after this (0 = waits)
    "tuckAfterSeconds": 0.0,      # wait: an inward press tucks back after this long without room
    "boxedAheadFeet": 12.0,       # boxed in: no room either side and a horse this close ahead (reported)
    "brush": "off",               # "repeat" (D-057, N5): a second press into a horse alongside brushes it
    "brushAlongFeet": 8.0,        # alongside = within this many feet lengthwise in the next lane...
    "brushGraceSeconds": 0.3,     # ...for at least this long (the rider saw it, whatever the lag)
    "brushRepeatSeconds": 2.0,    # the second press comes within this long of the first (0 = any time)
    "brushPays": "mover",         # "mover" (D-057); "bumped", "both", "none" for the sims
    "brushCost": 0.002,           # tau per charged brush (own term, after the field mean)
    "brushFree": 1,               # the first brushes cost nothing
    "brushMaxCharged": 3,         # at most this many charged; at most brushFree + this many a race
    "brushCheckFeet": 4.0,        # the payer steadies this far back (Trip's offsets)...
    "brushRecoverPerSecond": 2.0, # ...and comes back at this rate
    "steadySeconds": 1.0,         # the mover can't steer for this long after a brush
}

# The D-057 keys with their D-054 (off) values, in CONFIG's order. A literal, never read from
# CONFIG: with D-057 on in CONFIG (N3), files recorded before D-057 still read as D-054
# (config_from_record) and a D-057 config records its keys (config_record).
D057_OFF: Dict = {
    "glide": "linear", "laneSpeedMax": 1.5, "laneAccel": 4.5, "chainWindow": 0.0, "reverseGapSeconds": 0.0,
    "weaveGapSeconds": 0.0, "weaveWindowSeconds": 7.0, "pressBounceSeconds": 0.0, "glideReserveFeet": 0.0,
    "blockedPress": "d054", "gapWaitSeconds": 1.5, "gapWaitInSeconds": 0.0, "tuckAfterSeconds": 0.0,
    "boxedAheadFeet": 12.0, "brush": "off", "brushAlongFeet": 8.0, "brushGraceSeconds": 0.3,
    "brushRepeatSeconds": 2.0, "brushPays": "mover", "brushCost": 0.002, "brushFree": 1, "brushMaxCharged": 3,
    "brushCheckFeet": 4.0, "brushRecoverPerSecond": 2.0, "steadySeconds": 1.0,
}
D057_KEYS: Tuple[str, ...] = tuple(D057_OFF)

# D-057 on (debate 012): the switches N3 (motion and presses) and N5 (brushes) flip.
D057: Dict = {
    "glide": "eased", "chainWindow": 0.3, "reverseGapSeconds": 0.5, "weaveGapSeconds": 2.5,
    "pressBounceSeconds": 0.2, "glideReserveFeet": 6.0, "blockedPress": "wait", "brush": "repeat",
}


def d057_config(base: Optional[Dict] = None) -> Dict:
    """A copy of base (CONFIG by default) with D-057 switched on, brushes included."""
    cfg = copy.deepcopy(CONFIG if base is None else base)
    for key in D057_KEYS:
        if key in D057:
            cfg[key] = D057[key]
    return cfg


def d054_config(base: Optional[Dict] = None) -> Dict:
    """A copy of base (CONFIG by default) with every D-057 key at its D-054 value: the switch-back."""
    cfg = copy.deepcopy(CONFIG if base is None else base)
    for key in D057_KEYS:
        cfg[key] = copy.deepcopy(D057_OFF[key])
    return cfg


def d057_on(cfg: Dict) -> bool:
    """Any D-057 key away from its D-054 value."""
    return any(cfg.get(k) != D057_OFF[k] for k in D057_KEYS)


def config_record(cfg: Dict) -> Dict:
    """The config as generated files record it. While every D-057 key holds its D-054 value the
    keys are left out, so files made before D-057 (trip_baseline.json, steering_report.json,
    trip.json) stay current byte for byte; once any is switched on the whole config is recorded
    and those files must be regenerated."""
    if not d057_on(cfg):
        return {k: copy.deepcopy(v) for k, v in cfg.items() if k not in D057_OFF}
    return copy.deepcopy(cfg)


def config_from_record(rec: Dict) -> Dict:
    """A full config from a recorded one: missing D-057 keys take their D-054 values."""
    cfg = copy.deepcopy(rec)
    for k in D057_KEYS:
        if k not in cfg:
            cfg[k] = D057_OFF[k]
    return cfg


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
        # D-057
        self.v: List[float] = []          # sideways speed, lanes/s (eased glide)
        self.last_dir: List[int] = []     # direction of the last lane change started
        self.arrived_at: List[float] = [] # when the last glide landed
        self.last_rev_at: List[float] = []  # when the last change opposite to the one before started
        self.brushes: List[int] = []      # brushes this horse started (charged or not)
        self.charged: List[int] = []      # brushes this horse pays for (brush_charge caps the cost)
        self.check: List[float] = []      # feet below the skill target after a brush (steadying)
        self.steady_until: List[float] = []
        self.along_since: List[List[float]] = []  # [inside, outside]: since when a horse is alongside
        self.smart_block_at: List[float] = []     # since when Smart Steer's move has met no room, unbroken
        self.last_press_at: List[float] = []      # the last counted press (not a bounce)...
        self.last_press_dir: List[int] = []       # ...and its direction
        self.first_press_at: List[float] = []     # when the press now waiting was made
        self.tucking: List[bool] = []     # a tuck-back is under way this tick (SteerLane, N4)
        self.events: List[Tuple] = []     # (t, "brush", mover, other, dir), in order


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
    if cfg["glide"] not in GLIDES or cfg["blockedPress"] not in BLOCKED_PRESS or cfg["brush"] not in BRUSH_RULES \
            or cfg["brushPays"] not in BRUSH_PAYS:
        raise ValueError("unknown glide, blockedPress, brush or brushPays")
    if cfg["glide"] == "eased" and (cfg["laneAccel"] <= 0 or cfg["laneSpeedMax"] <= 0):
        raise ValueError("an eased glide needs laneAccel > 0 and laneSpeedMax > 0")
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
    st.last_rev_at = [LONG_AGO] * n
    st.brushes = [0] * n
    st.charged = [0] * n
    st.check = [0.0] * n
    st.steady_until = [LONG_AGO] * n
    st.along_since = [[NOT_ALONG, NOT_ALONG] for _ in range(n)]
    st.smart_block_at = [LONG_AGO] * n
    st.last_press_at = [LONG_AGO] * n
    st.last_press_dir = [0] * n
    st.first_press_at = [LONG_AGO] * n
    st.tucking = [False] * n
    st.events = []
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
    "locked", "invalid", "bounds", "rate". Every press but a locked, invalid or bounced one
    pauses Smart Steer for resumeSeconds. At most one press waits behind the one in progress.

    D-057 answers (never with the D-054 config): "bounce" (the same way within
    pressBounceSeconds of the last counted press: nothing happens, Smart Steer isn't paused
    again), "steady" (the horse is steadying after a brush), "brush" (see _brush_target). A
    change the other way waits in the queue while the horse glides and for its reverse gap
    after landing (reverse_gap)."""
    _check_lane(st, i)
    cfg = st.cfg
    if st.locked:
        return "locked"
    if d != 1 and d != -1:
        return "invalid"
    if d == st.last_press_dir[i] and t - st.last_press_at[i] < cfg["pressBounceSeconds"] - EPS:
        return "bounce"
    st.last_press_at[i] = t
    st.last_press_dir[i] = d
    st.manual_at[i] = t
    if t < st.steady_until[i] - EPS:
        return "steady"
    other = _brush_target(st, i, d, t)
    if other >= 0:
        _brush(st, i, other, d, t)
        return "brush"
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
    rgap = reverse_gap(st, i, t)
    reversing = rgap > 0 and st.last_dir[i] != 0 and d != st.last_dir[i] and \
        (st.x[i] != st.tgt[i] or t - st.arrived_at[i] < rgap - EPS)
    idle = st.want[i] == 0 and st.x[i] == st.tgt[i] and t - st.last_change[i] >= cfg["minRequestGap"] - EPS \
        and not reversing
    if idle:
        st.want[i] = d
        st.want_at[i] = t
        st.first_press_at[i] = t
        return "accepted"
    if st.queued[i] == 0 and cfg["maxQueued"] >= 1:
        if st.want[i] == 0:
            st.first_press_at[i] = t  # the first press waiting (behind a glide or a reverse gap)
        st.queued[i] = d
        return "queued"
    return "rate"


def reverse_gap(st: TripState, i: int, t: float) -> float:
    """D-057: how long a horse runs straight after landing before a change opposite to its last
    one: reverseGapSeconds, or weaveGapSeconds for a second reversal within weaveWindowSeconds
    of the last (a horse settles before it changes its mind again). 0 with the D-054 config."""
    cfg = st.cfg
    g = cfg["reverseGapSeconds"]
    if cfg["weaveGapSeconds"] > g and t - st.last_rev_at[i] < cfg["weaveWindowSeconds"] - EPS:
        g = cfg["weaveGapSeconds"]
    return g


def _reverse_wait(st: TripState, i: int, d: int, t: float) -> bool:
    """A change in direction d must still wait for the reverse gap."""
    g = reverse_gap(st, i, t)
    return g > 0 and st.last_dir[i] != 0 and d != st.last_dir[i] and t - st.arrived_at[i] < g - EPS


def lane_after(st: TripState, i: int) -> int:
    """The lane the rider ends up in once every waiting press is done."""
    _check_lane(st, i)
    return st.tgt[i] + st.want[i] + st.queued[i]


# ---------------------------------------------------------------- boxed in (D-057)

def side_state(st: TripState, i: int, d: int) -> str:
    """Room on side d (-1 in, +1 out) by Trip's clearance rule (the glide reserve included):
    "free" (a press moves now), "tuck" (no room, but an inward press can ease back to a slot
    within tuckBackMax and slip in behind: the "can tuck-back help" flag) or "blocked" (the rail
    or the outer edge, or no room and no tuck slot). The N4 arrows: Out greys while not "free";
    In greys only when "blocked" (no_tuck_inside, or on the rail)."""
    _check_lane(st, i)
    lane = st.tgt[i] + d
    if lane < 1 or lane > st.lanes:
        return "blocked"
    slot, blocked = _slot(st, i, lane)
    if not blocked:
        return "free"
    if d < 0 and st.off[i] - slot <= st.cfg["tuckBackMax"] + EPS:
        return "tuck"
    return "blocked"


def horse_ahead(st: TripState, i: int, feet: float) -> bool:
    """A horse within `feet` ahead of horse i in its lane (by lane position)."""
    _check_lane(st, i)
    band = st.cfg["laneBand"]
    for j in range(st.n):
        if j != i and abs(st.x[j] - st.x[i]) < band:
            a = st.off[j] - st.off[i]
            if a > 0 and a <= feet:
                return True
    return False


def boxed_in(st: TripState, i: int) -> bool:
    """D-057 boxed in: no room on either side and a horse within boxedAheadFeet ahead in your
    lane. Costs nothing (no boxed-in penalty); the sims and the N4 chips read it."""
    if not horse_ahead(st, i, st.cfg["boxedAheadFeet"]):
        return False
    return side_state(st, i, -1) != "free" and side_state(st, i, 1) != "free"


def no_tuck_inside(st: TripState, i: int) -> bool:
    """Off the rail, no room inside and no tuck slot within tuckBackMax: what D-057 calls
    "trapped" for the grey In arrow (boxed or not). An inward press then waits for room."""
    return st.tgt[i] > 1 and side_state(st, i, -1) == "blocked"


def boxed_no_tuck(st: TripState, i: int) -> bool:
    """Boxed in and no_tuck_inside: debate 012's "trapped" measure (about 1% of a Smart Steer
    kid's pre-lock time)."""
    return boxed_in(st, i) and no_tuck_inside(st, i)


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
    if cfg["blockedPress"] == "wait":
        _wait_for_room(st, i, d, t, slot, tucking, manual)
        return False
    if d < 0:
        # Tuck-in: ease back to the slot behind the horses alongside, then move in. Only when
        # the slot is at most tuckBackMax behind; otherwise wait for room.
        if st.off[i] - slot <= cfg["tuckBackMax"] + EPS:
            st.tuck[i] = max(0.0, st.skill[i] - slot)
            tucking[i] = True
    elif manual and t - st.want_at[i] >= cfg["outwardWaitSeconds"] - EPS:
        st.want[i] = 0  # no room outside: the request cancels
    return False


def _wait_for_room(st: TripState, i: int, d: int, t: float, slot: float, tucking: List[bool], manual: bool) -> None:
    """D-057 blockedPress = "wait": inward, the horse steadies back to the slot behind the horses
    alongside (tuck-back, after tuckAfterSeconds) when it is within tuckBackMax; otherwise the
    press waits for room (gapWaitInSeconds, 0 = until room). Outward, it waits gapWaitSeconds
    (0 = until room), then drops quietly. Smart Steer never drops; smart_block_at is its clock
    (cleared on any tick it doesn't try and fail, so it only measures an unbroken wait)."""
    cfg = st.cfg
    if manual:
        since = st.want_at[i]
    else:
        if st.smart_block_at[i] == LONG_AGO:
            st.smart_block_at[i] = t
        since = st.smart_block_at[i]
    can_tuck = d < 0 and st.off[i] - slot <= cfg["tuckBackMax"] + EPS
    if can_tuck:
        if t - since >= cfg["tuckAfterSeconds"] - EPS:
            st.tuck[i] = max(0.0, st.skill[i] - slot)
            tucking[i] = True
    elif manual:
        limit = cfg["gapWaitInSeconds"] if d < 0 else cfg["gapWaitSeconds"]
        if limit > 0 and t - since >= limit - EPS:
            st.want[i] = 0  # no room came: the press drops


def _slot(st: TripState, i: int, lane: int) -> Tuple[float, bool]:
    """Where horse i could enter `lane`, and whether it is blocked now. A horse in that lane
    (or gliding into it) blocks when it is less than clearFeet ahead or less than holdGap
    behind, so the mover never pushes the horse behind it back. A horse gliding into the lane
    keeps glideReserveFeet more room on both sides (D-057; 0 = D-054). The slot is the mover's
    own offset when nothing blocks, else holdGap behind the rearmost blocker, repeated down a
    line of horses. Each pass moves the slot past a horse that then stops counting, so n passes
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
                    cj, gj = clear + reserve, gap + reserve
                if a < cj and a > -gj:
                    if not found or st.off[j] < lowest:
                        lowest = st.off[j]
                    found = True
        if not found:
            break
        blocked = True
        p = lowest - gap
    return p, blocked


# ---------------------------------------------------------------- brushes (D-057)

def _alongside(st: TripState, i: int, d: int) -> int:
    """The horse alongside horse i in the next lane on side d (in it by laneBand or gliding into
    it, within brushAlongFeet lengthwise), or -1: the nearest, ties to the lower index. The rail
    and the outer edge are not horses."""
    lane = st.tgt[i] + d
    if lane < 1 or lane > st.lanes:
        return -1
    band, along = st.cfg["laneBand"], st.cfg["brushAlongFeet"]
    best, best_gap = -1, 0.0
    for j in range(st.n):
        if j != i and (abs(st.x[j] - lane) < band or st.tgt[j] == lane):
            g = abs(st.off[j] - st.off[i])
            if g < along and (best < 0 or g < best_gap):
                best, best_gap = j, g
    return best


def _track_alongside(st: TripState, t: float) -> None:
    """Since when each horse has had a horse alongside on each side (after the first hold)."""
    for i in range(st.n):
        for side in range(2):
            j = _alongside(st, i, -1 if side == 0 else 1)
            if j < 0:
                st.along_since[i][side] = NOT_ALONG
            elif st.along_since[i][side] == NOT_ALONG:
                st.along_since[i][side] = t


def _brush_target(st: TripState, i: int, d: int, t: float) -> int:
    """The horse a press by rider i in direction d brushes, or -1. A brush needs all of:
    brush = "repeat"; fewer than brushFree + brushMaxCharged brushes so far; the mover at rest;
    its first press the same way still waiting (want == d), made at most brushRepeatSeconds ago;
    a horse alongside on that side for at least brushGraceSeconds; and no tuck-back possible
    (outward, or inward with no slot within tuckBackMax, and not tucking already). So a first
    press never brushes, Smart Steer and bots (who never press) never brush, and nothing
    brushes after the lock (accept_intent refuses first)."""
    cfg = st.cfg
    if cfg["brush"] == "off":
        return -1
    if st.brushes[i] >= cfg["brushFree"] + cfg["brushMaxCharged"]:
        return -1
    if st.x[i] != st.tgt[i] or st.want[i] != d:
        return -1
    if cfg["brushRepeatSeconds"] > 0 and t - st.first_press_at[i] > cfg["brushRepeatSeconds"] + EPS:
        return -1
    side = 0 if d < 0 else 1
    j = _alongside(st, i, d)
    if j < 0 or t - st.along_since[i][side] < cfg["brushGraceSeconds"] - EPS:
        return -1
    if st.tuck[i] > 0:
        return -1
    if d < 0:
        slot, _blocked = _slot(st, i, st.tgt[i] - 1)
        if st.off[i] - slot <= cfg["tuckBackMax"] + EPS:
            return -1
    return j


def _brush(st: TripState, i: int, j: int, d: int, t: float) -> None:
    """Horse i brushes horse j. The mover's waiting presses clear and it can't steer for
    steadySeconds. Each payer (brushPays: the mover in D-057) is charged and steadies back
    brushCheckFeet in Trip's offsets."""
    cfg = st.cfg
    st.brushes[i] = st.brushes[i] + 1
    st.steady_until[i] = t + cfg["steadySeconds"]
    st.want[i] = 0
    st.queued[i] = 0
    pays = cfg["brushPays"]
    if pays == "mover" or pays == "both":
        st.charged[i] = st.charged[i] + 1
        st.check[i] = st.check[i] + cfg["brushCheckFeet"]
    if pays == "bumped" or pays == "both":
        st.charged[j] = st.charged[j] + 1
        st.check[j] = st.check[j] + cfg["brushCheckFeet"]
    st.events.append((t, "brush", i, j, d))


def brush_charge(st: TripState, i: int) -> float:
    """Horse i's brush cost: brushCost per brush it pays for after the first brushFree, at most
    brushMaxCharged of them. Fixed at the lock (nothing brushes after it)."""
    _check_lane(st, i)
    cfg = st.cfg
    charged = min(max(0, st.charged[i] - cfg["brushFree"]), cfg["brushMaxCharged"])
    return cfg["brushCost"] * charged


def brush_charges(st: TripState) -> List[float]:
    return [brush_charge(st, i) for i in range(st.n)]


# ---------------------------------------------------------------- the glide

def _glide_linear(st: TripState, t: float, dt: float) -> None:
    """D-054: one lane per laneSeconds, starting and stopping at once."""
    glide = dt / st.cfg["laneSeconds"]
    for i in range(st.n):
        if st.x[i] != st.tgt[i]:
            diff = st.tgt[i] - st.x[i]
            if abs(diff) <= glide + EPS:
                st.x[i] = float(st.tgt[i])
                st.arrived_at[i] = t + dt
            elif diff > 0:
                st.x[i] = st.x[i] + glide
            else:
                st.x[i] = st.x[i] - glide


def _glide_eased(st: TripState, t: float, dt: float) -> None:
    """D-057 S-curve: sideways speed changes by at most laneAccel * dt a tick, caps at
    laneSpeedMax and brakes in time to land. vb is the speed from which steps of adt a tick stop
    exactly in the distance left (so the horse brakes at laneAccel too); a chained change only
    moves tgt further, so the horse keeps its speed. It snaps to the lane on arrival."""
    cfg = st.cfg
    adt = cfg["laneAccel"] * dt
    vmax = cfg["laneSpeedMax"]
    for i in range(st.n):
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


def step(st: TripState, live: Sequence[float], intents: Sequence[Tuple[int, int]], t: float, dt: float) -> List[str]:
    """One server tick at race time t (seconds since the gate) lasting dt. intents = this
    tick's (lane index, direction) requests in arrival order; returns accept_intent's answer
    for each."""
    for lane_i, _d in intents:
        _check_lane(st, lane_i)
    if st.locked:
        return ["locked" for _ in intents]
    cfg, race = st.cfg, st.race
    n = st.n
    if len(live) != n:
        raise ValueError("one live chance per lane")
    prev = list(st.off)  # where every horse was at the start of the tick (holds settle from here)
    # 1. Skill targets (gaps ramp in from the gate), minus any tuck-back and brush steadying.
    #    Offsets move toward them as the race view moves gaps: eased, and no faster than
    #    maxGapFeetPerSecond unless a horse must hurry to be in place by the line.
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
    # 2. Hold: nobody overlaps the horse ahead in its lane. Then who is alongside whom (brushes).
    _hold(st, _order(st), prev, dt)
    order = _order(st)
    if cfg["brush"] != "off":
        _track_alongside(st, t)
    # 3. Lane changes: this tick's requests in arrival order, then everyone else leader
    #    first, then the inside horse. A horse gliding may start a same-way change within
    #    chainWindow of landing (D-057); a change the other way waits for the landing and the
    #    reverse gap.
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
    chain = cfg["chainWindow"]
    gaps_on = cfg["reverseGapSeconds"] > 0 or cfg["weaveGapSeconds"] > 0
    smart_waiting = [False] * n
    for a in range(n):
        i = order[a]
        if tried[i]:
            continue
        moving = st.x[i] != st.tgt[i]
        mdir = 0
        if moving:
            if chain <= 0 or abs(st.tgt[i] - st.x[i]) > chain + EPS:
                continue
            mdir = 1 if st.tgt[i] > st.x[i] else -1
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
            if gaps_on and _reverse_wait(st, i, d, t):
                st.want_at[i] = t  # the wait for room starts once the horse may move
                continue
            _try_move(st, i, d, t, tucking, True)
        elif st.smart[i] and t - st.manual_at[i] >= resume - EPS and st.tgt[i] > st.home[i]:
            # Smart Steer: heads in before and through turns, never out, never for a draft.
            if moving and mdir != -1:
                continue
            if not (in_turn or to_turn <= st.turn_lead[i] * st.speed + EPS):
                continue
            if gaps_on and _reverse_wait(st, i, -1, t):
                continue
            if not _try_move(st, i, -1, t, tucking, False):
                smart_waiting[i] = True
    # Smart Steer's wait clock (smart_block_at, set only by blockedPress "wait") measures one
    # unbroken wait: a tick on which it didn't try and fail clears it, so a later block starts a
    # fresh wait.
    if cfg["blockedPress"] == "wait":
        for i in range(n):
            if not smart_waiting[i]:
                st.smart_block_at[i] = LONG_AGO
    # 4. Lateral glide, then hold again so a horse arriving in a lane never overlaps.
    if cfg["glide"] == "eased":
        _glide_eased(st, t, dt)
    else:
        _glide_linear(st, t, dt)
    _hold(st, order, prev, dt)
    release = cfg["tuckReleasePerSecond"] * dt
    for i in range(n):
        if not tucking[i] and st.tuck[i] > 0:
            st.tuck[i] = max(0.0, st.tuck[i] - release)
    if cfg["brush"] != "off":
        recover = cfg["brushRecoverPerSecond"] * dt
        for i in range(n):
            if st.check[i] > 0:
                st.check[i] = max(0.0, st.check[i] - recover)
    st.tucking = tucking
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
    """The far-turn bell: book the far turn from each horse's lane position, freeze the trip.
    Waiting presses and any steadying after a brush clear; brush charges are fixed."""
    if st.locked:
        return
    g = st.cfg["groundPerLaneTurn"]
    for i in range(st.n):
        st.ground[i] = st.ground[i] + g * (st.x[i] - 1)
        st.want[i] = 0
        st.queued[i] = 0
        st.steady_until[i] = LONG_AGO
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
        brush: Optional[Sequence[float]] = None) -> List[float]:
    """tau_i = clamp(scale * (trip_i - baseline[post_i] - field mean of the same)
    - scale * brush_i, floor, ceiling). baseline = the per-post row for this course and
    distance. brush = brush_charges(st) (D-057): the mover's own cost, after the field mean (a
    brush never moves anyone else's tau) and inside the clamp; None or zeros change nothing."""
    n = len(trip)
    if len(posts) != n:
        raise ValueError("one post per lane")
    if brush is not None and len(brush) != n:
        raise ValueError("one brush charge per lane")
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
        if brush is not None:
            v = v - cfg["scale"] * brush[i]
        out.append(min(cfg["ceiling"], max(cfg["floor"], v)))
    return out


def trip_stars(t: float, cfg: Dict = CONFIG) -> int:
    """Results line "Good trip": three stars, two, or one (never zero)."""
    if t >= cfg["stars"][0]:
        return 3
    if t >= cfg["stars"][1]:
        return 2
    return 1
