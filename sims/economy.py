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
    ap.add_argument("--thresholds", default="100,110,1400,3000", help="points to unlock Stakes, Rookie..Gold")
    args = ap.parse_args(argv)
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
