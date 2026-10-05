#!/usr/bin/env python3
"""Race Rating from racer stats, race conditions, care, and pilot (D-014).

Theme-agnostic: stat keys are generic (speed, accel, stamina, grit, focus).
Mirrors game/src/shared/RaceRating.luau exactly.

Rating = (sum_k w_k(conditions) * stat_k) * care_mult + pilot_bonus + strategy_bonus + bond_bonus
Focus is not part of Rating; it only (slightly) affects the gavel meter.
"""

from __future__ import annotations

from typing import Dict

STATS = ("speed", "accel", "stamina", "grit")

DISTANCE_WEIGHTS: Dict[str, Dict[str, float]] = {
    "Sprint":   {"speed": 0.30, "accel": 0.45, "stamina": 0.10, "grit": 0.15},
    "Mile":     {"speed": 0.45, "accel": 0.25, "stamina": 0.20, "grit": 0.10},
    "Classic":  {"speed": 0.40, "accel": 0.15, "stamina": 0.35, "grit": 0.10},
    "Marathon": {"speed": 0.25, "accel": 0.10, "stamina": 0.55, "grit": 0.10},
}
# Added to the distance weights, then everything is renormalized to sum to 1.
SURFACE_SHIFT: Dict[str, Dict[str, float]] = {
    "Dirt": {},
    "Turf": {"speed": 0.10},
    "Sand": {"grit": 0.10, "stamina": 0.05},
}
WEATHER_SHIFT: Dict[str, Dict[str, float]] = {
    "Sunny": {},
    "Rain": {"grit": 0.20},
    "Wind": {"stamina": 0.10},
}
STRATEGY_SUITS = {
    "FrontRunner": ("Sprint", "Mile"),
    "Stalker": ("Mile", "Classic"),
    "Closer": ("Classic", "Marathon"),
}
CARE_MAX = 0.05       # +5% Rating when fully cared for
PILOT_MAX = 3.0       # jockey level bonus, points
STRATEGY_BONUS = 2.0  # points when the strategy suits the distance
BOND_MAX = 2.0        # points at full bond


def weights(distance: str, surface: str, weather: str) -> Dict[str, float]:
    w = dict(DISTANCE_WEIGHTS[distance])
    for shift in (SURFACE_SHIFT[surface], WEATHER_SHIFT[weather]):
        for k, v in shift.items():
            w[k] += v
    total = sum(w[k] for k in STATS)
    return {k: w[k] / total for k in STATS}


def clamp01(x: float) -> float:
    return min(max(x, 0.0), 1.0)


def rating(stats: Dict[str, float], cond: Dict[str, str], care: float = 0.0,
           pilot_level: float = 0.0, strategy: str | None = None, bond: float = 0.0) -> float:
    """care, pilot_level, bond are 0..1. Stats are 0..100."""
    w = weights(cond["distance"], cond["surface"], cond["weather"])
    base = sum(w[k] * min(max(stats[k], 0.0), 100.0) for k in STATS)
    r = base * (1 + CARE_MAX * clamp01(care))
    r += PILOT_MAX * clamp01(pilot_level)
    if strategy is not None and cond["distance"] in STRATEGY_SUITS.get(strategy, ()):
        r += STRATEGY_BONUS
    r += BOND_MAX * clamp01(bond)
    return r
