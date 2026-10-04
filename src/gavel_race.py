#!/usr/bin/env python3
"""Gavel Race reference model.

Locked pre-race win and quinella odds. Gavel skill redistributes win
probability so the equal-stake win book keeps the same expected payout.
"""

from __future__ import annotations

import math
from typing import Dict, List, Sequence, Tuple


def round_tier(o: float) -> float:
    """5:1+ nearest whole, >2:1 nearest 0.5, otherwise nearest 0.2."""
    if o >= 5.0:
        return float(round(o))
    if o > 2.0:
        return round(o * 2.0) / 2.0
    return round(o * 5.0) / 5.0


def lock_win_odds(q: Sequence[float], margin: float = 0.07) -> Dict:
    r = [qi * (1.0 + margin) for qi in q]
    o_raw = [1.0 / ri for ri in r]
    o = [round_tier(oi) for oi in o_raw]
    c = sum(qi * oi for qi, oi in zip(q, o))
    return {"r": r, "o_raw": o_raw, "o": o, "C": c}


def solve_ab(n: int, sum_d: float, sum_do: float, sum_o: float, sum_oo: float) -> Tuple[float, float]:
    det = n * sum_oo - sum_o * sum_o
    if abs(det) < 1e-12:
        return 0.0, 0.0
    a = (sum_oo * (-sum_d) - sum_o * (-sum_do)) / det
    b = (n * (-sum_do) - sum_o * (-sum_d)) / det
    return a, b


def adjust_win_probs(
    q: Sequence[float],
    skill: Sequence[float],
    o: Sequence[float],
    gamma: float = 0.80,
) -> Dict:
    """skill_i is (S-50)/50, or that plus noise. Odds o are locked."""
    n = len(q)
    desired = [gamma * sk * qi for sk, qi in zip(skill, q)]
    sum_d = sum(desired)
    sum_do = sum(d * oi for d, oi in zip(desired, o))
    sum_o = sum(o)
    sum_oo = sum(oi * oi for oi in o)
    a, b = solve_ab(n, sum_d, sum_do, sum_o, sum_oo)
    delta = [d + a + b * oi for d, oi in zip(desired, o)]
    p = [qi + di for qi, di in zip(q, delta)]
    ev = [pi * oi for pi, oi in zip(p, o)]
    return {
        "desired": desired,
        "a": a,
        "b": b,
        "delta": delta,
        "p": p,
        "ev": ev,
        "sum_p": sum(p),
        "sum_p_o": sum(pi * oi for pi, oi in zip(p, o)),
    }


def quinella_prob(p: Sequence[float], i: int, j: int) -> float:
    pi, pj = p[i], p[j]
    return pi * (pj / (1.0 - pi)) + pj * (pi / (1.0 - pj))


def lock_quinella_odds(q: Sequence[float], margin: float = 0.07) -> List[Dict]:
    """Freeze either-order pair prices from base q. Do not recompute after the gavel."""
    board = []
    n = len(q)
    for i in range(n):
        for j in range(i + 1, n):
            qij = quinella_prob(q, i, j)
            o_raw = 1.0 / (qij * (1.0 + margin))
            o = round_tier(o_raw)
            board.append({
                "i": i,
                "j": j,
                "q_base": qij,
                "o_raw": o_raw,
                "o": o,
            })
    return board


def quinella_ev(p: Sequence[float], board: Sequence[Dict]) -> List[Dict]:
    rows = []
    for row in board:
        i, j = row["i"], row["j"]
        qij = quinella_prob(p, i, j)
        ev = qij * row["o"]
        rows.append({**row, "q_live": qij, "ev": ev, "roi": ev - 1.0})
    return rows


def skill_from_scores(scores: Sequence[int]) -> List[float]:
    return [(s - 50) / 50.0 for s in scores]


def main() -> None:
    q = [0.25, 0.20, 0.15, 0.12, 0.10, 0.08, 0.06, 0.04]
    locked = lock_win_odds(q)
    print("LOCKED WIN ODDS (set before the race, never updated)")
    print(f"{'H':>3} {'q':>8} {'o_raw':>8} {'o':>8} {'base EV':>8}")
    for i, qi in enumerate(q):
        ev = qi * locked["o"][i]
        print(f"{i+1:3d} {qi:8.4f} {locked['o_raw'][i]:8.2f} {locked['o'][i]:8.1f} {ev:8.4f}")
    print(f"equal-stake book C = {locked['C']:.6f}  (stake 8, house keeps {8 - locked['C']:.4f})")

    scores = [88, 72, 60, 50, 42, 35, 28, 18]
    adj = adjust_win_probs(q, skill_from_scores(scores), locked["o"], gamma=0.80)
    print("\nAFTER GAVEL (odds unchanged, probabilities moved, C preserved)")
    print(f"a={adj['a']:.6f} b={adj['b']:.6f} gamma=0.80")
    print(f"{'H':>3} {'S':>4} {'p\'':>8} {'WinEV':>8} {'ROI':>8}")
    for i, s in enumerate(scores):
        ev = adj["ev"][i]
        print(f"{i+1:3d} {s:4d} {adj['p'][i]:8.5f} {ev:8.4f} {ev-1:8.2%}")
    print(f"sum p' = {adj['sum_p']:.6f}  sum p'*o = {adj['sum_p_o']:.6f}")

    board = lock_quinella_odds(q)
    live = quinella_ev(adj["p"], board)
    print("\nLOCKED QUINELLA vs LIVE PROB (either order, 28 pairs)")
    print(f"{'pair':>6} {'q_base':>8} {'o':>8} {'q_live':>8} {'EV':>8} {'ROI':>8}")
    for row in live:
        pair = f"{row['i']+1}-{row['j']+1}"
        print(
            f"{pair:>6} {row['q_base']:8.5f} {row['o']:8.1f} {row['q_live']:8.5f} "
            f"{row['ev']:8.4f} {row['roi']:8.2%}"
        )


if __name__ == "__main__":
    main()
