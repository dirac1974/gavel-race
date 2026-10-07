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
(`BOT_RATING_ANCHOR` +- `BOT_RATING_SPREAD`, mirrors GameConfig.botRatingAnchor), by horse and kid.
The D-061 gate: a fresh starter ridden by an average kid wins 20-35% of solo Rookie races.

`--silver` is the D-062 stage 8 Silver Cup sim: League Points per Silver race against
league-anchored bots (full Harville finish order, so 2nd-4th count), +10 for the horse's first
Silver win, and the races each cohort needs to open the Silver Cup at a given threshold. The
target: a casual player (new-kid riding on a Silver horse that is not trained past entry) opens
the Cup in 150-200 Silver races.
"""

from __future__ import annotations

import argparse
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
    args = ap.parse_args(argv)
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
