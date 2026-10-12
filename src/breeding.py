#!/usr/bin/env python3
"""Breeding (D-080 provisional, amends D-047): the reference for game/src/shared/Breeding.luau.

Pure rules on plain dicts shaped like the Luau Profile and Horse records. Every number lives in
BREEDING (= GameConfig.breeding); career.legacyMax is CAREER_LEGACY_MAX. Randomness comes only
from an injected rng with .random() in [0, 1) (Luau: rng:NextNumber()), drawn in a fixed order:
one uniform per stat in STATS order for the Potential noise, then one for the coat. Rounding is
floor(x + 0.5) in both languages (never Python's banker's round).

The foal is rolled once, at confirm (gameplay vote): Potential, start stats and coat are stored
on the pending foal, and arrival only reads them back. There is no reroll path.

Owner races are the profile's counted races (Profile totals.races). The stable-wide wait between
foals (foalEveryRaces, from confirm) and the foal's arrival are counted in them: no clocks, except "the next UTC day you play".
"""

from __future__ import annotations

import math

import life_arc as la

STATS = ("speed", "accel", "stamina", "grit")
LEAGUES = ("Rookie", "Bronze", "Silver", "Gold", "Champion")
COATS = ("bay", "chestnut", "grey", "black", "palomino", "pinto", "appaloosa", "buckskin", "dun", "roan",
         "white", "chestnut_blaze")  # Horse.COATS order: the coat roll walks this order

CAREER_LEGACY_MAX = 2  # GameConfig.career.legacyMax

BREEDING = {
    "enabled": False,          # true once BreedingService is wired (plan §9 phase 2); hides everything when false
    "minParentRaces": 30,
    "needLeague": "Bronze",
    "foalEveryRaces": 60,      # systems ruling 1: one foal per 60 owner races, stable-wide, from confirm
    "maxWaiting": 1,
    "foalAfterRaces": 8,
    "foalAfterNewDay": True,
    "fee": {"Bronze": 400, "Silver": 800, "Gold": 1500, "Champion": 2500},
    "parentShare": 0.75,       # systems ruling 3 (was 0.7)
    "breedAnchor": 80.5,       # systems ruling 3 said 80 (was 75); 80.5 holds the pure-line gate >= 83 (flagged)
    "noise": 5,
    "potMin": 55,
    "potMax": 100,
    "startShare": 0.60,
    "startMax": 50,            # gameplay vote: a 90-Potential foal still plays Rookie
    "coatParentEach": 0.45,
    "coatSurprise": 0.10,
    "youngScaleFrom": 0.80,
    "stableCap": 20,           # = Market.MAX_HORSES; a foal on the way holds a place
    "bond": 10,
    "familyLevels": (76, 84),  # Market.stars: expected mean Potential for 2 and 3 sprouts
    # Surprise families (plan §3; wild coats: systems ruling 4). The parents' own coats are left out
    # of the union; with no option left the Surprise share goes back to the parents' coats.
    "surprise": {
        "bay": ("buckskin", "dun"), "chestnut": ("buckskin", "dun"), "black": ("buckskin", "dun"),
        "chestnut_blaze": ("buckskin", "dun"), "grey": ("white", "roan"), "palomino": ("buckskin",),
        "pinto": ("appaloosa",), "appaloosa": ("pinto",),
        "buckskin": ("dun", "palomino"), "dun": ("buckskin",), "roan": ("grey",), "white": ("grey",),
    },
}


def _round(x: float) -> int:
    return int(math.floor(x + 0.5))


def _num(x, default: float = 0.0) -> float:
    try:
        v = float(x)
    except (TypeError, ValueError):
        return default
    return default if v != v else v


def _league_index(league) -> int:
    return LEAGUES.index(league) if league in LEAGUES else 0


def _races(h: dict) -> int:
    return la._races((h.get("record") or {}).get("races", 0))


def _is_legend(h: dict) -> bool:
    return h.get("legend") is not None and h.get("legend") is not False


def day(now: float) -> int:
    return int(now // 86400)


# --- Potential ---------------------------------------------------------------------------------

def best_stat(potential: dict) -> str:
    """The highest-Potential stat (ties: the first in STATS order)."""
    best = STATS[0]
    for k in STATS[1:]:
        if _num(potential.get(k)) > _num(potential.get(best)):
            best = k
    return best


def legacy(pot_a: dict, pot_b: dict, legend_a: bool, legend_b: bool,
           legacy_max: int = CAREER_LEGACY_MAX) -> dict:
    """{stat: bonus}: each Legend parent adds legacy_max to its own best stat; two Legends with
    the same best stat still give legacy_max once (never 2 x legacy_max on one stat)."""
    out = {k: 0 for k in STATS}
    if legend_a:
        out[best_stat(pot_a)] = legacy_max
    if legend_b:
        out[best_stat(pot_b)] = legacy_max
    return out


def expected_potential(pot_a: dict, pot_b: dict, legend_a: bool = False, legend_b: bool = False,
                       cfg: dict = BREEDING, legacy_max: int = CAREER_LEGACY_MAX) -> dict:
    """The foal's Potential with zero noise (the parent card's sprouts; never shown as numbers)."""
    bonus = legacy(pot_a, pot_b, legend_a, legend_b, legacy_max)
    share = cfg["parentShare"]
    out = {}
    for k in STATS:
        mid = share * (_num(pot_a.get(k)) + _num(pot_b.get(k))) / 2 + (1 - share) * cfg["breedAnchor"]
        out[k] = min(cfg["potMax"], max(cfg["potMin"], _round(mid) + bonus[k]))
    return out


def foal_potential(pot_a: dict, pot_b: dict, legend_a: bool, legend_b: bool, rng, cfg: dict = BREEDING,
                   legacy_max: int = CAREER_LEGACY_MAX) -> dict:
    """P = clamp(round(share x avg + (1 - share) x anchor + U(-noise, noise)) + legacy, potMin, potMax).
    Draws one uniform per stat, in STATS order."""
    bonus = legacy(pot_a, pot_b, legend_a, legend_b, legacy_max)
    share = cfg["parentShare"]
    out = {}
    for k in STATS:
        u = rng.random()
        mid = share * (_num(pot_a.get(k)) + _num(pot_b.get(k))) / 2 + (1 - share) * cfg["breedAnchor"]
        x = mid + cfg["noise"] * (2 * u - 1)
        out[k] = min(cfg["potMax"], max(cfg["potMin"], _round(x) + bonus[k]))
    return out


def start_stats(potential: dict, cfg: dict = BREEDING) -> dict:
    """min(round(startShare x P), startMax) per stat."""
    return {k: min(cfg["startMax"], _round(cfg["startShare"] * _num(potential.get(k)))) for k in STATS}


def family_level(potential: dict, cfg: dict = BREEDING) -> int:
    """1..3 sprouts from mean Potential (Market.stars thresholds)."""
    avg = sum(_num(potential.get(k)) for k in STATS) / len(STATS)
    two, three = cfg["familyLevels"]
    return 3 if avg >= three else 2 if avg >= two else 1


# --- Coats -------------------------------------------------------------------------------------

def surprise_coats(coat_a: str, coat_b: str, cfg: dict = BREEDING) -> list:
    """The union of both parents' Surprise families minus the parents' own coats, in COATS order
    (empty: no option left, so the Surprise share goes back to the parents)."""
    fam = set(cfg["surprise"].get(coat_a, ())) | set(cfg["surprise"].get(coat_b, ()))
    return [c for c in COATS if c in fam and c != coat_a and c != coat_b]


def coat_chances(coat_a: str, coat_b: str, cfg: dict = BREEDING) -> dict:
    """What the card shows before paying, and what the roll uses.
    {"parents": [[coat, chance], ...] (one row when both share a coat),
     "surprise": {"chance": x, "coats": [...]},
     "chances": {coat: chance} (sums to 1; a Surprise coat that is also a parent's coat adds up)}"""
    each, sur = cfg["coatParentEach"], cfg["coatSurprise"]
    coats = surprise_coats(coat_a, coat_b, cfg)
    if not coats:  # no Surprise family: its share goes back to the parents
        each, sur = each + sur / 2, 0.0
    chances = {}
    for c in COATS:
        p = 0.0
        if c == coat_a:
            p += each
        if c == coat_b:
            p += each
        if c in coats:
            p += sur / len(coats)
        if p > 0:
            chances[c] = p
    parents = [[coat_a, each + each]] if coat_a == coat_b else [[coat_a, each], [coat_b, each]]
    return {"parents": parents, "surprise": {"chance": sur, "coats": coats}, "chances": chances}


def roll_coat(chances: dict, u: float) -> str:
    """Walk COATS order, adding each chance; the first coat whose running total passes u."""
    acc, last = 0.0, None
    for c in COATS:
        p = chances.get(c, 0.0)
        if p <= 0:
            continue
        acc += p
        last = c
        if u < acc:
            return c
    return last


# --- Fees, selling -----------------------------------------------------------------------------

def fee(league_a: str, league_b: str, cfg: dict = BREEDING):
    """The fee by the higher parent league, or None below the first fee league."""
    top = LEAGUES[max(_league_index(league_a), _league_index(league_b))]
    return cfg["fee"].get(top)


def sell_value(paid, wins=0, cups=0, sell_cfg: dict = la.SELL) -> int:
    """A bred horse sells like a Market horse with h.paid = the fee: half of it plus the capped
    record bonus (life_arc.sell_value). Market.rehomeValue must treat origin "bred" this way."""
    return la.sell_value(paid, wins, cups, "market", sell_cfg)


# --- Eligibility -------------------------------------------------------------------------------

def _state(p: dict) -> dict:
    b = p.get("breeding")
    if not isinstance(b, dict):
        b = {}
        p["breeding"] = b
    if not isinstance(b.get("pending"), list):
        b["pending"] = []
    return b


def owner_races(p: dict) -> int:
    return la._races((p.get("totals") or {}).get("races", 0))


def next_foal_in(p: dict) -> int:
    """Owner races until the stable can start its next foal (0 = now). Stable-wide: one foal per
    foalEveryRaces owner races, counted from confirm, whichever horses are the parents."""
    at = _state(p).get("nextAt")
    return 0 if at is None else max(0, int(_num(at)) - owner_races(p))


def rest_left(p: dict, horse_id: str = None) -> int:
    """Kept for the Luau API (Breeding.restLeft): the stable-wide wait; the horse doesn't matter."""
    return next_foal_in(p)


def find(p: dict, horse_id):
    for h in p.get("horses") or []:
        if h.get("id") == horse_id:
            return h
    return None


def busy_block(h: dict, busy: dict | None) -> str | None:
    busy = busy or {}
    if busy.get("racing") or busy.get("inLine") or busy.get("racingHorse") == h.get("id"):
        return "After your race!"
    if busy.get("ridingHorse") == h.get("id") or (busy.get("trainingRide") and busy.get("ridingHorse") is None):
        return "Out riding"
    return None


def horse_block(p: dict, h: dict, busy: dict | None = None, cfg: dict = BREEDING) -> str | None:
    """Why this horse can't be a parent now (the greyed reason), or None."""
    if h is None:
        return "No such horse"
    if h.get("lent") is not None:
        return "Lent"
    if not _is_legend(h) and _races(h) < cfg["minParentRaces"]:
        return f"Needs {cfg['minParentRaces']} races"
    return busy_block(h, busy)


def pair_block(p: dict, id_a: str, id_b: str, busy: dict | None = None, cfg: dict = BREEDING) -> str | None:
    """Why these two can't be parents now, or None. Checks the stable before the horses."""
    if not cfg["enabled"]:
        return "The Foaling Barn is closed today"
    st = _state(p)
    if len(st["pending"]) >= cfg["maxWaiting"]:
        return "A foal is on the way!"
    left = next_foal_in(p)
    if left > 0:
        return "Next foal in 1 race" if left == 1 else f"Next foal in {left} races"
    if len(p.get("horses") or []) + len(st["pending"]) >= cfg["stableCap"]:
        return "Make room first"
    if id_a == id_b:
        return "Pick two different horses"
    a, b = find(p, id_a), find(p, id_b)
    for h in (a, b):
        why = horse_block(p, h, busy, cfg)
        if why:
            return why if h is None else f"{h.get('name', 'This horse')}: {why}"
    need = _league_index(cfg["needLeague"])
    if max(_league_index(a.get("league")), _league_index(b.get("league"))) < need:
        return f"One parent needs {cfg['needLeague']}"
    if fee(a.get("league"), b.get("league"), cfg) is None:
        return f"One parent needs {cfg['needLeague']}"
    return None


# --- Confirm and arrival -----------------------------------------------------------------------

def preview(p: dict, id_a: str, id_b: str, cfg: dict = BREEDING, legacy_max: int = CAREER_LEGACY_MAX) -> dict | None:
    """The card before paying: family sprouts, coat chances, fee. No randomness."""
    a, b = find(p, id_a), find(p, id_b)
    if a is None or b is None:
        return None
    exp = expected_potential(a["potential"], b["potential"], _is_legend(a), _is_legend(b), cfg, legacy_max)
    return {"family": family_level(exp, cfg), "coats": coat_chances(a.get("coat"), b.get("coat"), cfg),
            "fee": fee(a.get("league"), b.get("league"), cfg), "afterRaces": cfg["foalAfterRaces"],
            "newDay": cfg["foalAfterNewDay"]}


def confirm(p: dict, id_a: str, id_b: str, now: float, rng, busy: dict | None = None, cfg: dict = BREEDING,
            legacy_max: int = CAREER_LEGACY_MAX):
    """Pay the fee and roll the foal once. Returns (ok, message, pending). The pending foal stores
    everything the arrival needs; nothing is rolled again."""
    why = pair_block(p, id_a, id_b, busy, cfg)
    if why:
        return False, why, None
    a, b = find(p, id_a), find(p, id_b)
    price = fee(a.get("league"), b.get("league"), cfg)
    if _num(p.get("cash")) < price:
        return False, f"A foal needs {price} Green Cash", None
    pot = foal_potential(a["potential"], b["potential"], _is_legend(a), _is_legend(b), rng, cfg, legacy_max)
    table = coat_chances(a.get("coat"), b.get("coat"), cfg)
    coat = roll_coat(table["chances"], rng.random())
    p["cash"] = int(math.floor(_num(p.get("cash")))) - price
    st = _state(p)
    races = owner_races(p)
    st["nextAt"] = races + cfg["foalEveryRaces"]
    pending = {"parents": [id_a, id_b], "fee": price, "potential": pot, "stats": start_stats(pot, cfg),
               "coat": coat, "atRaces": races + cfg["foalAfterRaces"], "day": day(now)}
    st["pending"].append(pending)
    return True, "A foal is on the way! 🍼", pending


def ready(pending: dict, races: int, now: float, cfg: dict = BREEDING) -> bool:
    """After foalAfterRaces owner races, or on a later UTC day (foalAfterNewDay)."""
    if pending is None:
        return False
    if races >= pending["atRaces"]:
        return True
    return bool(cfg["foalAfterNewDay"]) and day(now) > pending["day"]


def foal_horse(pending: dict, horse_id: str, name: str, now: float, cfg: dict = BREEDING) -> dict:
    """The new horse from the stored roll: Young, Rookie, origin "bred", paid = the fee."""
    return {
        "id": horse_id, "name": name, "coat": pending["coat"], "style": "Stalker",
        "stats": dict(pending["stats"]), "potential": dict(pending["potential"]), "league": "Rookie",
        "points": 0, "bond": cfg["bond"], "record": {"races": 0, "wins": 0, "places": 0, "cash": 0, "cups": 0},
        "born": now, "origin": "bred", "parents": list(pending["parents"]), "paid": pending["fee"],
    }


def arrive(p: dict, horse_id: str, name: str, now: float, cfg: dict = BREEDING):
    """Takes the first ready foal off the pending list and returns its horse record (the caller adds
    it to the stable: Profile.addHorse gives it a stall), or None when none is ready."""
    st = _state(p)
    if not st["pending"] or not ready(st["pending"][0], owner_races(p), now, cfg):
        return None
    pending = st["pending"].pop(0)
    return foal_horse(pending, horse_id, name, now, cfg)


def young_scale(races, cfg: dict = BREEDING, young_races: int = la.AGEING["youngRaces"]) -> float:
    """HorseLook size for a Young horse: youngScaleFrom at race 0, 1.0 at youngRaces."""
    n = la._races(races)
    if n >= young_races:
        return 1.0
    return cfg["youngScaleFrom"] + (1 - cfg["youngScaleFrom"]) * n / young_races


if __name__ == "__main__":
    import random

    r = random.Random(1)
    a = {"speed": 88, "accel": 90, "stamina": 85, "grit": 92}
    b = {"speed": 84, "accel": 86, "stamina": 90, "grit": 83}
    for _ in range(3):
        print(foal_potential(a, b, False, True, r))
    print(coat_chances("bay", "grey"))
