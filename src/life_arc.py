#!/usr/bin/env python3
"""The horse life arc (fun-and-return consensus, 2026-10-12): ageing, selling and the vet run.

Pure rules on counted races (Practice never counts). Mirrors game/src/shared/Ageing.luau for the
ageing half (tests/fixtures/ageing.json holds the parity table); the sell value and the vet run
are the reference for Market.luau and the vet-check work.

Ageing: Young (training x youngTrainMult for the first youngRaces counted races), Prime, then
Veteran at veteranAt. Decline counts from declineFrom, stored the first time the horse has both
veteranAt races and stats at peakShare of Potential: then -declineScale Race Rating per declinePer
counted races, at most declineCap steps. The offset only touches the Rating a horse races with in
rated races: never Practice, League Points, ceilings or stats.
"""

from __future__ import annotations

import math

STATS = ("speed", "accel", "stamina", "grit")

AGEING = {
    "veteranAt": 350,
    "declinePer": 50,
    "declineCap": 4,
    "declineScale": 1,      # 0 = stages only; 1 = David's real decline (--ageing gates pass, provisional)
    "youngRaces": 30,
    "youngTrainMult": 1.25,
    "warnAhead": 10,
    "peakShare": 0.90,      # decline waits until stats reach this share of Potential (systems ruling 1)
}

SELL = {
    "share": 0.5,           # GameConfig.rehome.share
    "perWin": 5,
    "perCup": 100,
    "recordBonusCap": 100,  # --sell: under half the cheapest Market price (250), so a sale never beats the price
}

LEGS = {
    "runLimit": 6,          # counted races in a row on one horse -> vet check
    "warnAt": 5,
    "careLowers": 2,        # feed or groom
    "restSeconds": 30 * 60, # no counted race on this horse for this long -> run 0
    "fromRaces": 26,        # the run only grows after the horse's first fromRaces counted races (ruling 2)
    "careCooldownSeconds": 2 * 60 * 60,  # = GameConfig.energy.careCooldownSeconds: feed/groom count once per kind
}


def _races(races) -> int:
    try:
        n = float(races)
    except (TypeError, ValueError):
        return 0
    if n != n or n <= 0:
        return 0
    return int(math.floor(min(n, 1e9)))


# --- Ageing ---------------------------------------------------------------------------------

def stage(races, legend: bool = False, cfg: dict = AGEING) -> str:
    if legend:
        return "Legend"
    n = _races(races)
    if n < cfg["youngRaces"]:
        return "Young"
    return "Prime" if n < cfg["veteranAt"] else "Veteran"


def peak_share(stats: dict, potential: dict) -> float:
    """Mean of stat / Potential over the four stats (a stat with no Potential counts as full)."""
    shares = []
    for k in STATS:
        pot = float(potential.get(k, 0) or 0)
        shares.append(1.0 if pot <= 0 else min(1.0, max(0.0, float(stats.get(k, 0) or 0)) / pot))
    return sum(shares) / len(shares)


def at_peak(stats: dict, potential: dict, cfg: dict = AGEING) -> bool:
    return peak_share(stats, potential) >= cfg["peakShare"] - 1e-12


def update_decline_from(decline_from, races, stats: dict, potential: dict, cfg: dict = AGEING):
    """The stored h.ageing.declineFrom: the counted races when the horse first had both veteranAt
    races and stats at peakShare of Potential. Once set it never changes (or un-sets)."""
    if decline_from is not None:
        return decline_from
    n = _races(races)
    return n if n >= cfg["veteranAt"] and at_peak(stats, potential, cfg) else None


def decline_steps(races, decline_from=None, cfg: dict = AGEING) -> int:
    if decline_from is None:
        return 0
    n = _races(races)
    start = max(_races(decline_from), cfg["veteranAt"])
    if n < start:
        return 0
    return min(cfg["declineCap"], (n - start) // cfg["declinePer"])


def rating_offset(races, decline_from=None, cfg: dict = AGEING) -> float:
    """Race Rating change (<= 0) for a horse with `races` counted races before this race."""
    steps = decline_steps(races, decline_from, cfg)
    return -cfg["declineScale"] * steps if steps else 0.0


def raced_rating(rating: float, races, decline_from=None, practice: bool = False, cfg: dict = AGEING) -> float:
    return rating if practice else rating + rating_offset(races, decline_from, cfg)


def races_to_next_step(races, decline_from=None, cfg: dict = AGEING):
    """Counted races until the next decline step, or None (decline off, not at its peak yet, or capped)."""
    if cfg["declineScale"] <= 0 or decline_from is None:
        return None
    n = _races(races)
    steps = decline_steps(n, decline_from, cfg)
    if steps >= cfg["declineCap"]:
        return None
    return max(_races(decline_from), cfg["veteranAt"]) + (steps + 1) * cfg["declinePer"] - n


def decline_warning(races, decline_from=None, cfg: dict = AGEING) -> bool:
    left = races_to_next_step(races, decline_from, cfg)
    return left is not None and 1 <= left <= cfg["warnAhead"]


def veteran_soon(races, cfg: dict = AGEING) -> bool:
    left = cfg["veteranAt"] - _races(races)
    return 1 <= left <= cfg["warnAhead"]


def train_mult(races, cfg: dict = AGEING) -> float:
    return cfg["youngTrainMult"] if _races(races) < cfg["youngRaces"] else 1.0


# --- Selling (Riding School) -----------------------------------------------------------------

def sell_value(paid, wins, cups, origin: str = "market", cfg: dict = SELL) -> int:
    """Half the price paid plus the capped record bonus; tamed and gifted horses (and the
    starter, which never sells) give 0."""
    if origin != "market":
        return 0
    p = max(0, int(math.floor(float(paid or 0))))
    base = min(p, int(math.floor(p * cfg["share"])))
    bonus = cfg["perWin"] * max(0, int(wins or 0)) + cfg["perCup"] * max(0, int(cups or 0))
    return base + max(0, min(int(cfg["recordBonusCap"]), bonus))


# --- The vet run ------------------------------------------------------------------------------

def run_after_race(run: int, races_after: int, cfg: dict = LEGS) -> int:
    """The run after a counted race; `races_after` is the horse's counted races including it."""
    return run + 1 if _races(races_after) > cfg["fromRaces"] else 0


def run_after_care(run: int, last_counted_at: float, now: float, cfg: dict = LEGS) -> tuple:
    """Feed or groom: -careLowers once per kind per careCooldownSeconds (pass that kind's last
    counted time). Returns (run, counted)."""
    if now - last_counted_at < cfg["careCooldownSeconds"]:
        return run, False
    return max(0, run - cfg["careLowers"]), True


def run_now(run: int, last_race_at: float, now: float, cfg: dict = LEGS) -> int:
    """30 minutes without a counted race on this horse clears the run."""
    return 0 if now - last_race_at >= cfg["restSeconds"] else run


def needs_vet(run: int, cfg: dict = LEGS) -> bool:
    return run >= cfg["runLimit"]


def legs_warning(run: int, cfg: dict = LEGS) -> bool:
    return cfg["warnAt"] <= run < cfg["runLimit"]
