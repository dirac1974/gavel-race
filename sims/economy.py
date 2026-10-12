#!/usr/bin/env python3
"""Progression and Green Cash simulator for Giddy-Up.

Simulates players racing day by day through the leagues using the v2 race model,
then reports time to each league and Green Cash earned per hour.

Assumptions (edit the CONFIG block; each is logged in docs/memory/DECISIONS.md):
- Players are matched against horses of similar Rating, so base chance is 1/8.
- Rival riders score Normal(50, 15); the player's mean score comes from their skill percentile.
- Play time includes care and stable activities: RACES_PER_PLAY_HOUR races per hour played.
- Reaching the league's points threshold unlocks Stakes races; a Stakes win promotes and
  resets points. Each Stakes attempt is one race.

`--solo` reports the solo win rate (D-061 stage 2): one rider against seven league-anchored bots
(`BOT_RATING_ANCHOR` +- `BOT_RATING_SPREAD`, the D-061 anchors kept as history; GameConfig carries the
D-068 ones, `PHASE3["anchors"]`, pass `anchors=` to use them), by horse and kid.
The D-061 gate: a fresh starter ridden by an average kid wins 20-35% of solo Rookie races.

`--silver` is the D-062 stage 8 Silver Cup sim: League Points per Silver race against
league-anchored bots (full Harville finish order, so 2nd-4th count), +10 for the horse's first
Silver win, and the races each cohort needs to open the Silver Cup at a given threshold. The
target: a casual player (new-kid riding on a Silver horse that is not trained past entry) opens
the Cup in 150-200 Silver races.

`--ladder phase3|current` is the AAA Phase 3 ladder (D-068): a starter's Rating grows week by week
under Training's weekly cap (plus care and bond), and each profile (casual, engaged, and the same
schedules with average or perfect riding) races through every league with the real win model,
League Points, first-win bonus, Cup races and ceilings. `--ladder-search` re-derives PHASE3:
anchors from each league's casual entry Rating, ceilings at about 35% wins, Cup points for
20 / 40 / 90 / 180 counted races. Results: docs/reviews/aaa-2026-10-11/phase3-sim.md.
"""

from __future__ import annotations

import argparse
import math
import random
import statistics as st
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
import gavel_race_v2 as m  # noqa: E402

LEAGUES = ["Rookie", "Bronze", "Silver", "Gold", "Champion"]
B = {"Rookie": 20, "Bronze": 50, "Silver": 120, "Gold": 300, "Champion": 750}
POINTS = [10, 6, 4, 2]       # 1st..4th, others FINISH_POINTS
FINISH_POINTS = 1
PLACE_PRIZES = [1.2, 0.8, 0.4]
RACES_PER_PLAY_HOUR = 12     # about half of play time spent racing

COHORTS = {
    # name: (races per day, mean score)
    "casual": (6, 42),
    "regular": (12, 50),
    "engaged": (25, 55),
    "skilled": (25, 70),
}


# Solo races against league-anchored bots (D-061 stage 2). Mirrors GameConfig.luau (a test checks).
T = {"Rookie": 22, "Bronze": 18, "Silver": 18, "Gold": 14.4, "Champion": 12}
BOT_RATING_ANCHOR = {"Rookie": 32, "Bronze": 46, "Silver": 56, "Gold": 69, "Champion": 80}
BOT_RATING_SPREAD = 6
BOT_PACE = (60, 15)          # GameConfig.botPaceMean, botPaceSd
BOT_BURST = (55, 15)         # GameConfig.botBurstMean, botBurstSd
SEGMENTS = ["pace", "pace", "burst", "pace"]
SEGMENT_WEIGHTS = [1, 1, 2, 1]
LANES = 8
# Kids: mean slider score per checkpoint (sd 10) and Final Burst score (sd 20). The D-026 sims
# put an average kid at 66-75 on the slider and a random burst tap at 50.
KIDS = {"new": (60, 50), "average": (70, 60), "skilled": (80, 70)}
STARTER_STAT = 45            # Horse.STARTER_STAT
CARE_MAX = 0.05              # RaceRating.CARE_MAX
FRESH_RATING = STARTER_STAT * (1 + CARE_MAX * 0.5)  # a starter on a half-cared day, bond 0
# A horse entering each league (the last league's ceiling) and at its own ceiling (D-046).
LEAGUE_ENTRY = {"Rookie": FRESH_RATING, "Bronze": 58, "Silver": 68, "Gold": 78, "Champion": 88}
LEAGUE_TOP = {"Rookie": 58, "Bronze": 68, "Silver": 78, "Gold": 88, "Champion": 95}
SOLO_BAND = (0.20, 0.35)


def _clamp(x: float) -> float:
    return min(100.0, max(0.0, x))


def solo_win_rate(league: str, rating: float, kid: str = "average", races: int = 20000, seed: int = 1,
                  anchors: dict | None = None, spread: float = BOT_RATING_SPREAD) -> float:
    """Mean win chance of one rider against LANES - 1 bots rated anchor +- spread (uniform, as
    RaceSession.fillWithBots). Uses the live chance (no finish draw), so it converges fast."""
    rng = random.Random(seed)
    anchor = (anchors or BOT_RATING_ANCHOR)[league]
    cfg = m.Config(T=T[league])
    kid_pace, kid_burst = KIDS[kid]
    wsum = sum(SEGMENT_WEIGHTS)
    total = 0.0
    for _ in range(races):
        ratings = [rating] + [anchor + (rng.random() * 2 - 1) * spread for _ in range(LANES - 1)]
        q = m.base_chances(ratings, cfg)
        S = []
        for lane in range(LANES):
            seg_scores = []
            for kind in SEGMENTS:
                if lane == 0:
                    mean, sd = (kid_burst, 20) if kind == "burst" else (kid_pace, 10)
                else:
                    mean, sd = BOT_BURST if kind == "burst" else BOT_PACE
                seg_scores.append(_clamp(rng.gauss(mean, sd)))
            S.append(sum(w * x for w, x in zip(SEGMENT_WEIGHTS, seg_scores)) / wsum)
        total += m.live_chances(q, m.skills(S, cfg), cfg)[0]
    return total / races


def solo_report(races: int = 20000, seed: int = 1, anchors: dict | None = None) -> dict:
    """{league: {"entry"|"top": {kid: win rate}}}."""
    out = {}
    for lg in LEAGUES:
        out[lg] = {
            where: {kid: solo_win_rate(lg, r[lg], kid, races, seed, anchors) for kid in KIDS}
            for where, r in (("entry", LEAGUE_ENTRY), ("top", LEAGUE_TOP))
        }
    return out


# Silver Cup target (D-062 stage 8). Cohorts are (kid, horse Rating) for the whole Silver stay.
# Casual: a new kid on a horse that just came up from Bronze and is not trained further
# (training only shortens the trip: past the ceiling, 78, the Cup opens anyway, D-046).
SILVER_TARGET = (150, 200)
FIRST_WIN_BONUS = 10          # GameConfig.firstWinBonus (a test checks)
SILVER_COHORTS = {
    "casual": ("new", LEAGUE_ENTRY["Silver"]),
    "regular": ("average", (LEAGUE_ENTRY["Silver"] + LEAGUE_TOP["Silver"]) / 2),
    "skilled": ("skilled", (LEAGUE_ENTRY["Silver"] + LEAGUE_TOP["Silver"]) / 2),
}


def _solo_place(rng: random.Random, league: str, rating: float, kid: str) -> int:
    """One solo race against league-anchored bots; returns the rider's place (full finish draw)."""
    anchor = BOT_RATING_ANCHOR[league]
    cfg = m.Config(T=T[league])
    kid_pace, kid_burst = KIDS[kid]
    wsum = sum(SEGMENT_WEIGHTS)
    ratings = [rating] + [anchor + (rng.random() * 2 - 1) * BOT_RATING_SPREAD for _ in range(LANES - 1)]
    q = m.base_chances(ratings, cfg)
    S = []
    for lane in range(LANES):
        seg_scores = []
        for kind in SEGMENTS:
            if lane == 0:
                mean, sd = (kid_burst, 20) if kind == "burst" else (kid_pace, 10)
            else:
                mean, sd = BOT_BURST if kind == "burst" else BOT_PACE
            seg_scores.append(_clamp(rng.gauss(mean, sd)))
        S.append(sum(w * x for w, x in zip(SEGMENT_WEIGHTS, seg_scores)) / wsum)
    p = m.live_chances(q, m.skills(S, cfg), cfg)
    return m.draw_finish(p, rng).index(0) + 1


def _points(place: int) -> int:
    return POINTS[place - 1] if place <= len(POINTS) else FINISH_POINTS


def races_to_cup(threshold: int, league: str, rating: float, kid: str, players: int = 200,
                 seed: int = 1, first_win_bonus: int = FIRST_WIN_BONUS, cap: int = 2000) -> float:
    """Median races a horse needs in `league` to reach `threshold` League Points (its Cup opens),
    with +first_win_bonus on its first win there (D-062)."""
    rng = random.Random(seed)
    counts = []
    for _ in range(players):
        pts, won, n = 0, False, 0
        while pts < threshold and n < cap:
            place = _solo_place(rng, league, rating, kid)
            pts += _points(place)
            if place == 1 and not won:
                won = True
                pts += first_win_bonus
            n += 1
        counts.append(n)
    return st.median(counts)


def silver_report(thresholds=(600, 700, 750, 800, 1400), players: int = 200, seed: int = 1) -> dict:
    """{cohort: {threshold: median Silver races to open the Silver Cup}}."""
    return {name: {th: races_to_cup(th, "Silver", rating, kid, players, seed) for th in thresholds}
            for name, (kid, rating) in SILVER_COHORTS.items()}


# ---------------------------------------------------------------------------------------------
# Realistic-Rating ladder (AAA review Phase 3, D-068). A horse's Rating follows from the weeks it
# has been played: Training's weekly cap (Training.luau), care and bond, never a fixed league
# entry Rating. Every race uses the real win model (league-anchored bots, Harville finish), the
# real League Points, the first-win bonus, Cup races (3B to the winner) and the league ceilings.
# The ladder targets: a casual kid opens each Cup in about 20 / 40 / 90 / 180 counted races
# (Rookie, Bronze, Silver, Gold), entering any league at about 25% solo wins (average kid) and
# at most about 35% at the league's ceiling.

import race_rating as rr  # noqa: E402

TRAIN_K = 0.12               # Training.K
WEEKLY_CAP = 6               # Training.WEEKLY_CAP, stat points per horse per week (a test checks)
RESTED_BONUS = 1.5           # Training.RESTED_BONUS
MIN_GAIN = 0.1               # Training.MIN_GAIN
POTENTIAL = (70, 85)         # Horse.starter: Potential per stat
BOND_CAP = 100
CUP_PURSE_B = 3              # GameConfig.cupPurseB
LEAGUE_B = {"Rookie": 20, "Bronze": 50, "Silver": 120, "Gold": 300, "Champion": 750}  # purses unchanged
LEAGUE_DISTANCES = {"Rookie": ("Sprint", "Mile"), "Bronze": ("Sprint", "Mile", "Classic")}
ALL_DISTANCES = ("Sprint", "Mile", "Classic", "Marathon")
SURFACES = ("Dirt", "Turf")
WEATHERS = ("Sunny", "Sunny", "Rain", "Wind")  # RaceService WEATHERS
KIDS["perfect"] = (97, 95)   # every tap near the centre; scores clamp at 100

# The ladder before D-068 (the D-061/D-062 values, kept as the "before" record) and the Phase 3
# values, which GameConfig.luau carries since AAA Phase 3 (tests/test_sims.py checks the live file).
CURRENT = {
    "anchors": dict(BOT_RATING_ANCHOR),
    "stakes": {"Rookie": 100, "Bronze": 110, "Silver": 750, "Gold": 3000},
    "ceilings": {"Rookie": 58, "Bronze": 68, "Silver": 78, "Gold": 88},
}
PHASE3 = {
    "anchors": {"Rookie": 32, "Bronze": 35, "Silver": 38, "Gold": 48, "Champion": 56},
    "stakes": {"Rookie": 100, "Bronze": 200, "Silver": 450, "Gold": 900},
    "ceilings": {"Rookie": 55, "Bronze": 57, "Silver": 60, "Gold": 66},
}
LADDER_TARGET = {"Rookie": 20, "Bronze": 40, "Silver": 90, "Gold": 180}
LADDER_TOLERANCE = 0.2       # each league's median within +-20% of its target
ENTRY_BAND = (0.20, 0.30)    # casual's horse entering a league: average kid's solo win rate
CEILING_MAX = 0.37           # average kid at the league ceiling: about 35%


class Profile:
    def __init__(self, sessions: int, races: int, trains: int, train_score: float, care: float,
                 bond: float, kid: str):
        self.sessions, self.races, self.trains = sessions, races, trains  # per week, per session, per week
        self.train_score, self.care, self.bond, self.kid = train_score, care, bond, kid


# Casual: 3 sessions a week of 10 races (one horse's Energy covers it: 5 stored, about 1.5 regen,
# 2 care top-ups, the Spa), 2 training rides, feeds or grooms (half care), a vet visit and a treat.
# Engaged: 6 sessions of 10, 4 rides (the cap every week), full care, more treats.
PROFILES = {
    "casual": Profile(3, 10, 2, 50, 0.5, 2, "new"),
    "casual-average": Profile(3, 10, 2, 50, 0.5, 2, "average"),
    "casual-perfect": Profile(3, 10, 2, 50, 0.5, 2, "perfect"),
    "engaged": Profile(6, 10, 4, 70, 1.0, 4, "average"),
    # Light: one session of 10 races a week but both training rides, so the weekly cap is always
    # reached: the horse outgrows its league fastest per race (the systems consult's check).
    "light": Profile(1, 10, 2, 50, 0.5, 2, "new"),
    "light-average": Profile(1, 10, 2, 50, 0.5, 2, "average"),
    "engaged-perfect": Profile(6, 10, 4, 70, 1.0, 4, "perfect"),
}


def _distances(league: str) -> tuple:
    return LEAGUE_DISTANCES.get(league, ALL_DISTANCES)


def best_rating(stats: dict, league: str) -> float:
    """RaceService.bestRating: best base Rating over the league's conditions, no care or bond."""
    return max(rr.rating(stats, {"distance": d, "surface": s, "weather": w})
               for d in _distances(league) for s in SURFACES for w in rr.WEATHER_SHIFT)


def ladder_race(rng: random.Random, league: str, rating: float, kid: str, anchors: dict,
                kappa: float = 1.0) -> tuple:
    """One solo race against league-anchored bots: (place, live win chance, base chance)."""
    anchor = anchors[league]
    cfg = m.Config(T=T[league], kappa=kappa)
    kid_pace, kid_burst = KIDS[kid]
    wsum = sum(SEGMENT_WEIGHTS)
    ratings = [rating] + [anchor + (rng.random() * 2 - 1) * BOT_RATING_SPREAD for _ in range(LANES - 1)]
    q = m.base_chances(ratings, cfg)
    S = []
    for lane in range(LANES):
        tot = 0.0
        for kind, w in zip(SEGMENTS, SEGMENT_WEIGHTS):
            if lane == 0:
                mean, sd = (kid_burst, 20) if kind == "burst" else (kid_pace, 10)
            else:
                mean, sd = BOT_BURST if kind == "burst" else BOT_PACE
            tot += w * _clamp(rng.gauss(mean, sd))
        S.append(tot / wsum)
    p = m.live_chances(q, m.skills(S, cfg), cfg)
    return m.draw_finish(p, rng).index(0) + 1, p[0], q[0]


def career(rng: random.Random, prof: Profile, params: dict, max_weeks: int = 60,
           kappa: dict | None = None, stop_at: str | None = None) -> dict:
    """One horse from a fresh starter until it reaches Champion (or max_weeks). Per league:
    entry Rating, counted races to open the Cup, races in the league (Cup tries included), week
    and races played when it moved up, cash, and the live win chance over its first and last ten
    regular races there."""
    anchors, stakes, ceilings = params["anchors"], params["stakes"], params["ceilings"]
    stats = {k: float(STARTER_STAT) for k in rr.STATS}
    potential = {k: rng.randint(*POTENTIAL) for k in rr.STATS}
    bond, league, points, played, best = 0.0, "Rookie", 0, 0, None
    out = {lg: {"entry_rating": None, "unlock": None, "races": 0, "week": None, "played": None, "cash": 0,
                "p": [], "wins": 0, "regular": 0, "first_win": False, "closed": False, "closed_at_entry": False,
                "cup_p": []} for lg in LEAGUES}
    out["Rookie"]["week"], out["Rookie"]["played"] = 0.0, 0
    for week in range(max_weeks):
        sessions_with_ride = set(range(min(prof.trains, prof.sessions)))
        extra_rides = max(0, prof.trains - prof.sessions)
        gained = 0.0
        for s in range(prof.sessions):
            rides = (1 if s in sessions_with_ride else 0) + (extra_rides if s == 0 else 0)
            if rides and gained < WEEKLY_CAP - 1e-9:
                gained += _train_rides(stats, potential, rides, prof.train_score, WEEKLY_CAP - gained)
                best = None
            bond = min(BOND_CAP, bond + prof.bond)
            for _ in range(prof.races):
                lg = out[league]
                if lg["entry_rating"] is None:
                    lg["entry_rating"] = rr.rating(stats, {"distance": "Mile", "surface": "Dirt", "weather": "Sunny"},
                                                   prof.care, 0, None, bond / BOND_CAP)
                nxt = LEAGUES.index(league) + 1 < len(LEAGUES)
                if nxt and best is None:
                    best = best_rating(stats, league)
                cup_open = nxt and (points >= stakes[league] or best > ceilings[league])
                if cup_open and lg["unlock"] is None:
                    lg["unlock"] = lg["regular"]
                    # regular races closed by the ceiling before the points opened the Cup
                    lg["closed"] = points < stakes[league]
                    lg["closed_at_entry"] = lg["closed"] and lg["races"] == 0
                cond = {"distance": rng.choice(_distances(league)), "surface": rng.choice(SURFACES),
                        "weather": rng.choice(WEATHERS)}
                rating = rr.rating(stats, cond, prof.care, 0, None, bond / BOND_CAP)
                place, p0, q0 = ladder_race(rng, league, rating, prof.kid, anchors,
                                            (kappa or {}).get(league, 1.0))
                lg["races"] += 1
                played += 1
                B = LEAGUE_B[league]
                if place == 1:
                    lg["cash"] += CUP_PURSE_B * B if cup_open else math.floor(B / q0 + 0.5)
                elif place <= 4:
                    lg["cash"] += round(B * PLACE_PRIZES[place - 2])
                if cup_open:
                    lg["cup_p"].append(p0)
                    if place == 1:
                        league, points, best = LEAGUES[LEAGUES.index(league) + 1], 0, None
                        out[league]["week"] = week + (s + 1) / prof.sessions
                        out[league]["played"] = played
                        out[league]["entry_rating"] = rr.rating(
                            stats, {"distance": "Mile", "surface": "Dirt", "weather": "Sunny"},
                            prof.care, 0, None, bond / BOND_CAP)
                        if stop_at == league:
                            return out
                    continue
                lg["regular"] += 1
                lg["p"].append(p0)
                points += _points(place)
                if place == 1:
                    lg["wins"] += 1
                    if not lg["first_win"]:
                        lg["first_win"] = True
                        points += FIRST_WIN_BONUS
        if league == "Champion" and out["Champion"]["races"] >= 30:
            break
    return out


def _train_rides(stats: dict, potential: dict, rides: int, score: float, cap_left: float) -> float:
    gained = 0.0
    for _ in range(rides):
        if gained >= cap_left - 1e-9:
            break
        stat = max(rr.STATS, key=lambda k: potential[k] - stats[k])
        room = potential[stat] - stats[stat]
        if room < MIN_GAIN:
            break
        g = TRAIN_K * room * (0.5 + 0.5 * score / 100) * RESTED_BONUS
        g = min(g, room, cap_left - gained)
        g = max(math.floor(g * 10 + 0.5) / 10, MIN_GAIN)
        g = min(g, math.floor(room * 10) / 10, cap_left - gained)
        stats[stat] = math.floor((stats[stat] + g) * 10 + 0.5) / 10
        gained += g
    return gained


def _med(xs):
    xs = [x for x in xs if x is not None]
    return st.median(xs) if xs else None


def ladder_report(prof: Profile, params: dict, players: int = 200, seed: int = 1,
                  max_weeks: int = 60, kappa: dict | None = None, stop_at: str | None = None) -> dict:
    """{league: medians over players}: entry Rating, counted races to open the Cup, races in the
    league, week and total races when the horse reached it, live win chance entering (first 10
    regular races) and leaving (last 10), cash per race; plus the share that reached it."""
    rng = random.Random(seed)
    runs = [career(rng, prof, params, max_weeks, kappa, stop_at) for _ in range(players)]
    rep = {}
    for lg in LEAGUES:
        rows = [r[lg] for r in runs]
        reached = [x for x in rows if x["week"] is not None]
        rep[lg] = {
            "reached": len(reached) / players,
            "week": _med([x["week"] for x in rows]) if len(reached) * 2 >= players else None,
            "played": _med([x["played"] for x in rows]) if len(reached) * 2 >= players else None,
            "entry_rating": _med([x["entry_rating"] for x in reached]),
            "unlock": _med([x["unlock"] for x in reached]) if lg != "Champion" else None,
            "races": _med([x["races"] for x in reached]),
            "p_in": _med([st.mean(x["p"][:10]) for x in reached if len(x["p"]) >= 10]),
            "p_out": _med([st.mean(x["p"][-10:]) for x in reached if len(x["p"]) >= 10]),
            "cash_per_race": _med([x["cash"] / x["races"] for x in reached if x["races"]]),
            # the ceiling closed regular races before the points opened the Cup (share of horses),
            # closed on the horse's first race there, and the live win chance in its Cup tries
            "closed": sum(x["closed"] for x in reached) / len(reached) if reached else None,
            "closed_at_entry": sum(x["closed_at_entry"] for x in reached) / len(reached) if reached else None,
            "cup_p": _med([st.mean(x["cup_p"]) for x in reached if x["cup_p"]]),
            "cup_p_closed": _med([st.mean(x["cup_p"]) for x in reached if x["cup_p"] and x["closed"]]),
            "cup_tries": _med([len(x["cup_p"]) for x in reached if x["cup_p"]]),
        }
    return rep


def entry_ratings(prof: Profile, params: dict, league: str, players: int = 200, seed: int = 1) -> float:
    """Median Rating (as raced, care and bond in) when a profile's horse first races in `league`."""
    rng = random.Random(seed)
    vals = []
    for _ in range(players):
        r = career(rng, prof, params, 60, stop_at=league)[league]["entry_rating"]
        vals.append(r)
    return _med(vals)


ENTRY_TARGET = {"Bronze": 0.25, "Silver": 0.25, "Gold": 0.22, "Champion": 0.25}


def search_ladder(players: int = 150, seed: int = 1, entry_target: dict | None = None,
                  ceiling_target: float = 0.36, verbose: bool = True) -> dict:
    """The Phase 3 search, one league at a time (a league's entry Rating depends on the leagues
    below): bot anchor so the casual horse's entry Rating gives an average kid `entry_target`
    solo wins (ENTRY_TARGET: Gold enters a little lower, since a casual horse spends about six
    weeks of training there); ceiling where an average kid wins `ceiling_target`; Cup points (to the nearest
    10) so the casual profile's median counted races hit LADDER_TARGET. Rookie keeps the D-061
    anchor (32) and ceiling (58)."""
    prof = PROFILES["casual"]
    params = {k: dict(v) for k, v in PHASE3.items()}
    for lg in LEAGUES:
        if lg != "Rookie":
            # the horse enters `lg` after the leagues below are tuned
            rating = entry_ratings(prof, params, lg, players, seed)
            best = min(range(20, 90), key=lambda a: abs(
                solo_win_rate(lg, rating, "average", 3000, seed, {**params["anchors"], lg: a})
                - (entry_target or ENTRY_TARGET)[lg]))
            params["anchors"][lg] = best
            if lg in params["ceilings"]:
                anchors = params["anchors"]
                r = rating
                while solo_win_rate(lg, r, "average", 3000, seed, anchors) < ceiling_target and r < 100:
                    r += 1
                params["ceilings"][lg] = int(r)
            if verbose:
                print(f"{lg}: casual entry Rating {rating:.1f} -> anchor {best}, ceiling {params['ceilings'].get(lg)}")
        if lg in LADDER_TARGET:
            lo, hi = 20, 3000
            while hi - lo > 10:
                mid = (lo + hi) // 20 * 10
                params["stakes"][lg] = mid
                n = ladder_report(prof, params, players, seed, stop_at=LEAGUES[LEAGUES.index(lg) + 1])[lg]["unlock"]
                if n is None or n > LADDER_TARGET[lg]:
                    hi = mid
                else:
                    lo = mid
            params["stakes"][lg] = lo
            if verbose:
                print(f"{lg}: Cup at {lo} points")
    return params


def race(rng: random.Random, my_mean: float, league: str):
    """One race; returns (place, cash)."""
    cfg = m.Config(T=14.4)
    q = [1 / 8] * 8
    scores = [min(100, max(0, rng.gauss(my_mean, 10)))] + [min(100, max(0, rng.gauss(50, 15))) for _ in range(7)]
    p = m.live_chances(q, m.skills(scores, cfg), cfg)
    order = m.draw_finish(p, rng)
    place = order.index(0) + 1
    b = B[league]
    if place == 1:
        cash = m.lock_purses(q, m.Config(B=b))[0]
    elif place <= 4:
        cash = round(b * PLACE_PRIZES[place - 2])
    else:
        cash = 0
    return place, cash


def simulate_player(rng, races_per_day, my_mean, thresholds, days):
    league_i, points, cash = 0, 0, 0
    reached = {"Rookie": 0.0}
    cash_by_league = {lg: [0, 0] for lg in LEAGUES}  # cash, races
    for day in range(days):
        for r in range(races_per_day):
            league = LEAGUES[league_i]
            place, c = race(rng, my_mean, league)
            cash += c
            cash_by_league[league][0] += c
            cash_by_league[league][1] += 1
            if league_i < len(LEAGUES) - 1 and points >= thresholds[league]:
                if place == 1:  # Stakes win
                    league_i += 1
                    points = 0
                    reached[LEAGUES[league_i]] = day + (r + 1) / races_per_day
                continue
            points += POINTS[place - 1] if place <= 4 else FINISH_POINTS
    return reached, cash_by_league


def run(thresholds, players, days, seed):
    rng = random.Random(seed)
    out = {}
    for name, (rpd, mean) in COHORTS.items():
        reach = {lg: [] for lg in LEAGUES[1:]}
        per_hour = {lg: [] for lg in LEAGUES}
        for _ in range(players):
            reached, cbl = simulate_player(rng, rpd, mean, thresholds, days)
            for lg in LEAGUES[1:]:
                reach[lg].append(reached.get(lg))
            for lg, (c, n) in cbl.items():
                if n:
                    per_hour[lg].append(c / n * RACES_PER_PLAY_HOUR)
        out[name] = (rpd, reach, per_hour)
    return out


def fmt_days(values, rpd):
    got = [v for v in values if v is not None]
    if len(got) < len(values) / 2:
        return "not reached"
    med = st.median(got + [float("inf")] * (len(values) - len(got)))
    hours = med * rpd / RACES_PER_PLAY_HOUR
    return f"day {med:4.1f} ({hours:4.1f} h play)"


def main(argv=None):
    ap = argparse.ArgumentParser(description="Giddy-Up progression simulator")
    ap.add_argument("--players", type=int, default=150)
    ap.add_argument("--days", type=int, default=60)
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--thresholds", default="100,110,750,3000", help="points to unlock Stakes, Rookie..Gold")
    ap.add_argument("--solo", action="store_true", help="solo win rate against league-anchored bots (D-061)")
    ap.add_argument("--races", type=int, default=20000, help="--solo: races per cell")
    ap.add_argument("--silver", action="store_true", help="Silver Cup races-to-open by threshold (D-062)")
    ap.add_argument("--ladder", choices=["phase3", "current"], help="realistic-Rating ladder by profile (D-068)")
    ap.add_argument("--ladder-search", action="store_true", help="search anchors, ceilings and Cup points (D-068)")
    args = ap.parse_args(argv)
    if args.ladder_search:
        print(search_ladder(players=args.players, seed=args.seed))
        return
    if args.ladder:
        params = PHASE3 if args.ladder == "phase3" else CURRENT
        print(f"{args.ladder}: {params}")
        print(f"targets: casual opens each Cup in {LADDER_TARGET} counted races; p = live win chance, "
              "first / last ten regular races in the league")
        for name, prof in PROFILES.items():
            rep = ladder_report(prof, params, args.players, args.seed, max_weeks=80)
            print()
            print(f"{name} ({prof.sessions}x{prof.races} races a week, {prof.trains} rides, {prof.kid} kid)")
            print(f"  {'league':9}{'week':>6}{'played':>7}{'Rating':>7}{'to Cup':>7}{'in lg':>6}"
                  f"{'p in':>6}{'p out':>6}{'cash/race':>10}{'closed':>7}{'cup p':>6}")
            for lg, r in rep.items():
                def f(v, w, fmt):
                    return f"{v:{w}{fmt}}" if v is not None else f"{'-':>{w}}"
                print(f"  {lg:9}{f(r['week'], 6, '.1f')}{f(r['played'], 7, '.0f')}{f(r['entry_rating'], 7, '.1f')}"
                      f"{f(r['unlock'], 7, '.0f')}{f(r['races'], 6, '.0f')}{f(r['p_in'], 6, '.0%')}"
                      f"{f(r['p_out'], 6, '.0%')}{f(r['cash_per_race'], 10, '.0f')}"
                      f"{f(r['closed'] if lg != 'Champion' else None, 7, '.0%')}{f(r['cup_p'], 6, '.0%')}")
        return
    if args.silver:
        rep = silver_report(players=args.players, seed=args.seed)
        ths = next(iter(rep.values())).keys()
        print(f"Median Silver races to open the Silver Cup (+{FIRST_WIN_BONUS} first win; "
              f"target casual {SILVER_TARGET[0]}-{SILVER_TARGET[1]})")
        print(f"{'cohort':8} {'kid':>8} {'rating':>6}  " + "  ".join(f"{t:>6}" for t in ths))
        for name, row in rep.items():
            kid, rating = SILVER_COHORTS[name]
            print(f"{name:8} {kid:>8} {rating:6.1f}  " + "  ".join(f"{v:6.0f}" for v in row.values()))
        return
    if args.solo:
        rep = solo_report(args.races, args.seed)
        print(f"Solo win rate vs bots at {BOT_RATING_ANCHOR} +- {BOT_RATING_SPREAD} "
              f"(gate: fresh Rookie, average kid, {SOLO_BAND[0]:.0%}-{SOLO_BAND[1]:.0%})")
        print(f"{'league':9} {'horse':>12}  " + "  ".join(f"{k:>8}" for k in KIDS))
        for lg, rows in rep.items():
            for where, cells in rows.items():
                r = (LEAGUE_ENTRY if where == "entry" else LEAGUE_TOP)[lg]
                print(f"{lg:9} {where + f' {r:4.1f}':>12}  " + "  ".join(f"{v:8.1%}" for v in cells.values()))
        return
    th = dict(zip(LEAGUES[:4], [int(x) for x in args.thresholds.split(",")]))
    print(f"Stakes thresholds: {th}")
    results = run(th, args.players, args.days, args.seed)
    print(f"\n{'cohort':8} {'races/day':>9}  " + "  ".join(f"{lg:>22}" for lg in LEAGUES[1:]))
    for name, (rpd, reach, _) in results.items():
        print(f"{name:8} {rpd:9d}  " + "  ".join(f"{fmt_days(reach[lg], rpd):>22}" for lg in LEAGUES[1:]))
    print("\nGreen Cash per hour of play (median), by league:")
    for name, (_, _, per_hour) in results.items():
        cells = [f"{lg} {st.median(v):6.0f}" if v else f"{lg}      -" for lg, v in per_hour.items()]
        print(f"{name:8}  " + "  ".join(cells))


if __name__ == "__main__":
    main(sys.argv[1:])
