#!/usr/bin/env python3
"""Gavel Race v2 reference model (no-wager game version).

Six steps per race:
  1. Base win chance q from Race Ratings (softmax, temperature T, floor).
  2. Locked win purse in whole cash: round(B / q). Every horse expects B (within 0.5 q / B).
  3. Gavel window score: 100 * (1 - d), constant-speed meter.
  4. Skill vs. this race's average: R = clamp((S - mean S) / 50, rFloor, 1).
  5. Live win chance by exponential tilt: p' ∝ q * exp(kappa * R).
  6. Finish order by sequential draw from p' (Harville).

See docs/V2_PROPOSAL.md for the rationale. v1 (src/gavel_race.py) is kept
for history. Stdlib only. Mirrors src/RaceMath.luau.
"""

from __future__ import annotations

import argparse
import math
import random
import sys
from dataclasses import dataclass
from typing import List, Sequence


@dataclass
class Config:
    T: float = 14.4        # stat temperature: 10 rating points ~ 2x win chance
    q_floor: float = 0.025  # smallest base win chance; caps purse near 40B
    kappa: float = 1.0      # gavel strength
    r_floor: float = -0.5   # worst skill value
    B: float = 100.0        # league base purse


LEAGUE_T = {"Rookie": 22.0, "Bronze": 18.0, "Silver": 18.0, "Gold": 14.4, "Champion": 12.0}
LEAGUE_B = {"Rookie": 20, "Bronze": 50, "Silver": 120, "Gold": 300, "Champion": 750}
PLACE_PRIZES = (1.2, 0.8, 0.4)  # 2nd, 3rd, 4th, in units of B


def normalize(w: Sequence[float]) -> List[float]:
    total = sum(w)
    return [x / total for x in w]


# Step 1
def base_chances(ratings: Sequence[float], cfg: Config) -> List[float]:
    m = max(ratings)
    q = normalize([math.exp((r - m) / cfg.T) for r in ratings])
    return normalize([max(v, cfg.q_floor) for v in q])


# Step 2
def lock_purses(q: Sequence[float], cfg: Config) -> List[int]:
    # Whole cash (D-017). floor(x + 0.5) rather than round(): Python's round() is
    # banker's rounding, Luau's math.round rounds half away from zero.
    return [math.floor(cfg.B / qi + 0.5) for qi in q]


# Step 3
def window_score(d: float) -> float:
    """d = |offset from meter center| / half-width. Random tap averages 50."""
    return 100.0 * (1.0 - min(max(d, 0.0), 1.0))


# Step 4
def skills(scores: Sequence[float], cfg: Config) -> List[float]:
    mean = sum(scores) / len(scores)
    return [min(max((s - mean) / 50.0, cfg.r_floor), 1.0) for s in scores]


# Step 5
def live_chances(q: Sequence[float], R: Sequence[float], cfg: Config) -> List[float]:
    return normalize([qi * math.exp(cfg.kappa * ri) for qi, ri in zip(q, R)])


# Step 6
def draw_finish(p: Sequence[float], rng) -> List[int]:
    """Sequential draw (Harville). Lanes are scanned in index order so the
    Luau port gives the identical order from the same uniform draws."""
    taken = [False] * len(p)
    order: List[int] = []
    for _ in range(len(p)):
        total = sum(v for i, v in enumerate(p) if not taken[i])
        x = rng.random() * total
        pick = -1
        for i, v in enumerate(p):
            if taken[i]:
                continue
            pick = i
            x -= v
            if x <= 0:
                break
        order.append(pick)
        taken[pick] = True
    return order


def pick_winner(p: Sequence[float], rng: random.Random) -> int:
    x, c = rng.random(), 0.0
    for i, pi in enumerate(p):
        c += pi
        if x <= c:
            return i
    return len(p) - 1


def place_probs(p: Sequence[float], depth: int = 4) -> List[List[float]]:
    """Exact Harville probabilities of finishing in positions 1..depth."""
    n = len(p)
    out = [[0.0] * depth for _ in range(n)]

    def rec(rem: List[int], prob: float, pos: int) -> None:
        if pos == depth:
            return
        tot = sum(p[i] for i in rem)
        for i in rem:
            pi = prob * p[i] / tot
            out[i][pos] += pi
            rec([j for j in rem if j != i], pi, pos + 1)

    rec(list(range(n)), 1.0, 0)
    return out


# ---------------------------------------------------------------- v1 checks

def v1_adjust(q, skill, o, gamma=0.80):
    """v1 linear shift with two constraints (from src/gavel_race.py)."""
    n = len(q)
    desired = [gamma * sk * qi for sk, qi in zip(skill, q)]
    sum_d, sum_do = sum(desired), sum(d * oi for d, oi in zip(desired, o))
    sum_o, sum_oo = sum(o), sum(oi * oi for oi in o)
    det = n * sum_oo - sum_o * sum_o
    a = (sum_oo * (-sum_d) - sum_o * (-sum_do)) / det
    b = (n * (-sum_do) - sum_o * (-sum_d)) / det
    return [qi + d + a + b * oi for qi, d, oi in zip(q, desired, o)]


def round_tier(o: float) -> float:
    if o >= 5.0:
        return float(round(o))
    if o > 2.0:
        return round(o * 2.0) / 2.0
    return round(o * 5.0) / 5.0


# ---------------------------------------------------------------- reports

REPO_Q = [0.25, 0.20, 0.15, 0.12, 0.10, 0.08, 0.06, 0.04]
REPO_S = [88, 72, 60, 50, 42, 35, 28, 18]
RATINGS = [70, 67, 64, 62, 60, 58, 56, 52]


def pct(x: float) -> str:
    return f"{x:6.1%}"


def report_v1_problems(rng: random.Random, n: int) -> None:
    print("=== v1 problems (for comparison) ===")
    o = [round_tier(1 / (qi * 1.07)) for qi in REPO_Q]
    p = v1_adjust(REPO_Q, [(s - 50) / 50 for s in REPO_S], o)
    print(f"S=18 longshot: base {REPO_Q[-1]:.2%} -> v1 {p[-1]:.2%} (worst player gains)")
    neg = 0
    for _ in range(n):
        S = [rng.randint(1, 100) for _ in REPO_Q]
        R = [(s - 50) / 50 + rng.gauss(0, 0.65) for s in S]
        neg += min(v1_adjust(REPO_Q, R, o)) < 0
    print(f"races with a negative win chance: {neg / n:.1%}")
    print("tier-rounding expected return by horse:",
          " ".join(f"{qi * oi:.3f}" for qi, oi in zip(REPO_Q, o)))
    print()


def report_example(cfg: Config) -> None:
    print("=== v2 lobby: ratings -> base chance -> locked purse (B=100) ===")
    q = base_chances(RATINGS, cfg)
    purses = lock_purses(q, cfg)
    for i, (r, qi, pu) in enumerate(zip(RATINGS, q, purses), 1):
        print(f"lane {i}  rating {r:3d}  win chance {pct(qi)}  win purse {pu:5d}  E[win cash] {qi * pu:6.1f}")
    print()
    print("=== repo example field under v2 (kappa=1.0) ===")
    R = skills(REPO_S, cfg)
    p = live_chances(REPO_Q, R, cfg)
    for s, qi, pi in zip(REPO_S, REPO_Q, p):
        print(f"S {s:3d}  base {pct(qi)}  live {pct(pi)}  x{pi / qi:4.2f}")
    print()


def report_skill_premium(rng: random.Random, n: int) -> None:
    print("=== skill premium: E[win cash] vs B, equal horses, field S ~ N(50,15) ===")
    pcts = {"P99": 2.326, "P90": 1.2816, "P75": 0.674, "P50": 0.0, "P25": -0.674, "P10": -1.2816}
    kappas = [0.6, 0.8, 1.0, 1.2]
    print("pctl    S   " + "  ".join(f"k={k:<4}" for k in kappas))
    q = [1 / 8] * 8
    for name, z in pcts.items():
        S0 = 50 + 15 * z
        cells = []
        for k in kappas:
            cfg = Config(kappa=k)
            tot = 0.0
            for _ in range(n):
                S = [S0] + [rng.gauss(50, 15) for _ in range(7)]
                tot += live_chances(q, skills(S, cfg), cfg)[0] / q[0]
            cells.append(f"{tot / n - 1:+6.0%}")
        print(f"{name}  {S0:4.0f}   " + "  ".join(cells))
    print()


def report_upsets(rng: random.Random, n: int) -> None:
    print("=== upsets by stat temperature T (kappa=1.0, ratings 70..52, S ~ N(50,15)) ===")
    print("    T   fav base   bottom-half wins   longest shot wins")
    for T in [14.4, 18.0, 22.0]:
        cfg = Config(T=T)
        q = base_chances(RATINGS, cfg)
        bottom = longest = 0
        for _ in range(n):
            S = [rng.gauss(50, 15) for _ in q]
            w = pick_winner(live_chances(q, skills(S, cfg), cfg), rng)
            bottom += w >= 4
            longest += w == 7
        print(f"{T:5.1f}   {pct(q[0])}   {pct(bottom / n):>16}   {pct(longest / n):>17}")
    print()
    print("=== earned upsets: longshot rider scores 80 vs field N(50,15), T=14.4 ===")
    for k in [0.6, 1.0, 1.4]:
        cfg = Config(kappa=k)
        q = base_chances(RATINGS, cfg)
        tot = 0.0
        for _ in range(n):
            S = [rng.gauss(50, 15) for _ in range(7)] + [80]
            tot += live_chances(q, skills(S, cfg), cfg)[7]
        print(f"kappa {k:3.1f}: longshot {pct(q[7])} -> {pct(tot / n)}")
    print()


def report_faucet(rng: random.Random, n: int) -> None:
    print("=== cash created per race vs. no-skill field (repo q, alpha=1) ===")
    for k in [0.8, 1.0, 1.2]:
        cfg = Config(kappa=k)
        tot = 0.0
        for _ in range(n):
            S = [rng.gauss(50, 15) for _ in REPO_Q]
            p = live_chances(REPO_Q, skills(S, cfg), cfg)
            tot += sum(pi / qi for pi, qi in zip(p, REPO_Q)) / len(REPO_Q)
        print(f"kappa {k:3.1f}: {tot / n - 1:+.2%}")
    pp = place_probs(REPO_Q)
    place = [sum(w * r[j + 1] for j, w in enumerate(PLACE_PRIZES)) for r in pp]
    print("E[cash per entry] in B (win 1.0 + place), favorite -> longshot:",
          " ".join(f"{1 + x:.2f}" for x in place))
    print()


def report_collusion() -> None:
    print("=== collusion: 1 perfect rider, 7 friends score 0, equal horses ===")
    q = [1 / 8] * 8
    cfg = Config()
    p = live_chances(q, skills([100] + [0] * 7, cfg), cfg)
    print(f"boosted rider: {q[0]:.1%} -> {p[0]:.1%} (x{p[0] * 8:.2f}).")
    print("Race-average centering limits this (the tankers drag the average down),")
    print("but parties should still never share a cash race.")
    print()


def main(argv: Sequence[str] | None = None) -> None:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--races", type=int, default=10000, help="races per simulated cell")
    ap.add_argument("--seed", type=int, default=7)
    args = ap.parse_args(argv)
    rng = random.Random(args.seed)
    cfg = Config()
    report_v1_problems(rng, args.races)
    report_example(cfg)
    report_skill_premium(rng, args.races)
    report_upsets(rng, args.races * 2)
    report_faucet(rng, args.races * 2)
    report_collusion()


if __name__ == "__main__":
    main(sys.argv[1:])
