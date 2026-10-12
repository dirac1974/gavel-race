#!/usr/bin/env python3
"""Breeding sims (D-080, docs/reviews/breeding-2026-10-12/plan.md §7): every gate, single process.

--bloodline  Generations of foals under four strategies from Market top-tier founders (the worst
             case for runaway): random pairs, best-two-of-3-foals each generation, the same with a
             Legend parent every generation, and the greedy stable (always breed the two best horses
             in a 20-horse stable, one foal at a time).
--spread     The foal Potential distribution: one fixed pair, and pairs drawn from starters and
             Market stock.
--ladder     A generation-3 foal (best of three, top-tier founders) against a starter: Champion
             arrival on the D-068 ladder (economy.career, Youngster boost on, no decline), and the
             gameplay vote's Rookie gate (>= 15 regular Rookie races, average-kid win 20-30%).
--power      Trained-out horses (stats = Potential, full care and bond) at Champion with an average
             kid: starter, Market top tier, bred plateau. Bred horses must not beat the top tier
             too often.
--cash       16 weeks of D-070 cash (economy.career ledgers, jobs, feed, Barn Builder wishes) per
             casual / average / keen kid, with no breeding, breeding after shopping, and breeding
             first. Fee share of cash created after Bronze, the week-12 pile, Barn Builder waits and
             the time to the first foal (the second horse is tamed; it needs 30 races too).
--profit     Sell value of a bred foal against its fee for every league and record.

Results: docs/reviews/breeding-2026-10-12/sim.md.
"""

from __future__ import annotations

import argparse
import importlib.util
import math
import random
import statistics as st
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
import economy as eco  # noqa: E402
import life_arc as la  # noqa: E402

# src/breeding.py under its own name: this file is also called breeding, so a plain import could
# find itself first.
_spec = importlib.util.spec_from_file_location("breeding_model", Path(__file__).resolve().parents[1] / "src" / "breeding.py")
br = importlib.util.module_from_spec(_spec)
sys.modules["breeding_model"] = br
_spec.loader.exec_module(br)

STATS = br.STATS
PROFILES = {"casual": "casual", "average": "casual-average", "keen": "engaged"}
NO_DECLINE = {**la.AGEING, "declineScale": 0}

GATE_PLATEAU_MAX = 92.0        # mean Potential per stat at generation 10, best selection
GATE_LEVEL_OFF = 0.5           # generation 8 -> 9 change at most +0.5
GATE_PURE_MIN = 83.0           # systems ruling 3: a pure top-tier line holds >= 83 at generation 10
GATE_TOP1 = 98                 # top 1% of foal stats
GATE_SD = (2.8, 4.0)           # "about 3-4": one pair's foal sd (U(-5, 5) noise gives 2.89 before rounding)
GATE_ARRIVAL = 0.85            # generation-3 foal's Champion arrival >= 85% of a starter's
GATE_ROOKIE_RACES = 15         # gameplay vote
GATE_ROOKIE_WIN = (0.20, 0.30)
GATE_FEE_SHARE = (0.10, 0.25)
GATE_PILE_DROP = 0.30
GATE_WAIT = 2
GATE_FIRST_FOAL = {"casual": 5, "average": 4, "keen": 2}  # weeks
GATE_POWER_PTS = 0.05          # bred plateau win rate at most 5 points over the top tier
GATE_POWER_SHARE = 0.15        # at most 15% of bred plateau horses above the top tier's p90 Rating


def _ci(xs: list) -> tuple:
    if len(xs) < 2:
        return (st.mean(xs) if xs else float("nan"), 0.0)
    return st.mean(xs), 1.96 * st.stdev(xs) / math.sqrt(len(xs))


def _mean_pot(pot: dict) -> float:
    return sum(pot[k] for k in STATS) / len(STATS)


def market_listing(rng: random.Random, tier: str | None = None) -> tuple:
    """Market.stock's distribution: (stats, potential). tier "top" forces the 82-95 tier."""
    t = 0.9 if tier == "top" else rng.random()
    lo, hi = (82, 95) if t > 0.85 else (72, 86) if t > 0.5 else (62, 78)
    stats, pot = {}, {}
    for k in STATS:
        stats[k] = rng.randint(40, 52)
        pot[k] = max(stats[k] + 5, rng.randint(lo, hi))
    return stats, pot


def starter_pot(rng: random.Random) -> dict:
    return {k: rng.randint(*eco.POTENTIAL) for k in STATS}


# --- Bloodlines --------------------------------------------------------------------------------

STRATEGIES = ("random", "best3", "best3+legend", "greedy")


def bloodline(rng: random.Random, strategy: str, gens: int = 12, cfg: dict = br.BREEDING) -> list:
    """Mean Potential per stat by generation (index 0 = founders) and, for Legend lines, the
    legacy stat. Generation g's value is the mean over the horses chosen as its parents (random,
    best3) or the stable's two best (greedy)."""
    founders = [market_listing(rng, "top")[1] for _ in range(2)]
    out = [(st.mean(_mean_pot(p) for p in founders), None)]
    if strategy == "greedy":
        stable = [(p, 0) for p in founders]
        foals = 0
        by_gen: dict = {}
        while foals < 200:
            stable.sort(key=lambda x: -_mean_pot(x[0]))
            (pa, ga), (pb, gb) = stable[0], stable[1]
            foal = br.foal_potential(pa, pb, False, False, rng, cfg)
            g = max(ga, gb) + 1
            stable.append((foal, g))
            stable.sort(key=lambda x: -_mean_pot(x[0]))
            del stable[cfg["stableCap"]:]
            foals += 1
            top2 = st.mean(_mean_pot(x[0]) for x in stable[:2])
            by_gen.setdefault(max(x[1] for x in stable[:2]), []).append(top2)
            if g > gens:
                break
        last = out[0][0]
        for g in range(1, gens + 1):
            last = st.mean(by_gen[g]) if g in by_gen else last
            out.append((last, None))
        return out
    pa, pb = founders
    for _ in range(gens):
        legend_a = strategy == "best3+legend"
        foals = [br.foal_potential(pa, pb, legend_a, False, rng, cfg) for _ in range(3)]
        if strategy == "random":
            pa, pb = rng.sample(foals, 2)
        else:
            foals.sort(key=lambda p: -_mean_pot(p))
            pa, pb = foals[0], foals[1]
        best = max(pa, pb, key=_mean_pot)
        out.append((st.mean([_mean_pot(pa), _mean_pot(pb)]), max(best[k] for k in STATS)))
    return out


def bloodline_report(lines: int, seed: int, gens: int = 12) -> dict:
    rep = {}
    for strategy in STRATEGIES:
        rng = random.Random(seed)
        runs = [bloodline(rng, strategy, gens) for _ in range(lines)]
        rows = []
        for g in range(gens + 1):
            m = _ci([r[g][0] for r in runs])
            top = [r[g][1] for r in runs if r[g][1] is not None]
            rows.append({"gen": g, "mean": m, "best_stat": _ci(top) if top else None,
                         "max_stat": max(top) if top else None})
        d89 = rows[9]["mean"][0] - rows[8]["mean"][0]
        rep[strategy] = {"rows": rows, "d89": d89}
    return rep


def gate_bloodline(rep: dict) -> list:
    out = []
    for s in ("best3", "best3+legend", "greedy"):
        g10 = rep[s]["rows"][10]["mean"][0]
        out.append((f"bloodline {s}: gen-10 mean per stat <= {GATE_PLATEAU_MAX}", f"{g10:.1f}", g10 <= GATE_PLATEAU_MAX))
        out.append((f"bloodline {s}: gen 8->9 change <= +{GATE_LEVEL_OFF}", f"{rep[s]['d89']:+.2f}", rep[s]["d89"] <= GATE_LEVEL_OFF))
    pure = rep["best3"]["rows"][10]["mean"][0]
    out.append((f"bloodline best3 (pure top-tier line): gen-10 mean per stat >= {GATE_PURE_MIN}", f"{pure:.1f}",
                pure >= GATE_PURE_MIN))
    mx = max(r["max_stat"] or 0 for s in rep for r in rep[s]["rows"])
    out.append(("bloodline: no stat above 100", f"{mx}", mx <= 100))
    return out


# --- Potential spread --------------------------------------------------------------------------

def spread_report(foals: int, seed: int) -> dict:
    rng = random.Random(seed)
    pa, pb = {k: 85 for k in STATS}, {k: 80 for k in STATS}
    fixed = [br.foal_potential(pa, pb, False, False, rng)["speed"] for _ in range(foals)]
    pop, means = [], []
    for _ in range(foals // 4):
        a = starter_pot(rng) if rng.random() < 0.5 else market_listing(rng)[1]
        b = market_listing(rng)[1]
        f = br.foal_potential(a, b, False, False, rng)
        pop.extend(f.values())
        means.append(_mean_pot(f))
    top = [market_listing(rng, "top")[1] for _ in range(2 * (foals // 4))]
    tops = []
    for i in range(0, len(top), 2):
        tops.extend(br.foal_potential(top[i], top[i + 1], True, True, rng).values())
    pop.sort()
    tops.sort()
    fam = {lv: sum(1 for m in means if br.family_level({k: m for k in STATS}) == lv) / len(means) for lv in (1, 2, 3)}
    return {"fixed_sd": st.pstdev(fixed), "fixed_mean": st.mean(fixed),
            "pop_sd": st.pstdev(pop), "pop_mean": st.mean(pop), "pop_p01": pop[len(pop) // 100],
            "pop_p99": pop[int(len(pop) * 0.99)], "pop_max": pop[-1],
            "top_p99": tops[int(len(tops) * 0.99)], "top_max": tops[-1], "top_mean": st.mean(tops),
            "family": fam, "n": len(pop)}


def gate_spread(rep: dict) -> list:
    return [
        (f"spread: foal sd about {GATE_SD[0]:.0f}-{GATE_SD[1]:.0f} for one pair (the noise; population sd is reported)",
         f"{rep['fixed_sd']:.2f} (population {rep['pop_sd']:.2f})", GATE_SD[0] <= rep["fixed_sd"] <= GATE_SD[1]),
        (f"spread: top 1% <= {GATE_TOP1} (two top-tier Legends)", f"{rep['top_p99']}", rep["top_p99"] <= GATE_TOP1),
        ("spread: no stat above 100", f"{max(rep['pop_max'], rep['top_max'])}", max(rep["pop_max"], rep["top_max"]) <= 100),
    ]


# --- Ladder and the Rookie gate ----------------------------------------------------------------

def gen3_foal(rng: random.Random, cfg: dict = br.BREEDING) -> dict:
    """The best of three generation-3 foals from two Market top-tier founders (best-two selection)."""
    pa, pb = market_listing(rng, "top")[1], market_listing(rng, "top")[1]
    for _ in range(2):
        foals = sorted((br.foal_potential(pa, pb, False, False, rng, cfg) for _ in range(3)), key=lambda p: -_mean_pot(p))
        pa, pb = foals[0], foals[1]
    return max((br.foal_potential(pa, pb, False, False, rng, cfg) for _ in range(3)), key=_mean_pot)


def ladder_report(players: int, seed: int, cfg: dict = br.BREEDING) -> dict:
    rep = {}
    for name, key in PROFILES.items():
        prof = eco.PROFILES[key]
        res = {}
        for kind in ("starter", "foal"):
            rng = random.Random(seed)
            played, rook_regular, rook_p, rook_wins, closed, pots = [], [], [], [], [], []
            for _ in range(players):
                if kind == "foal":
                    pot = gen3_foal(rng, cfg)
                    start = (br.start_stats(pot, cfg), pot)
                else:
                    pot = starter_pot(rng)
                    start = ({k: eco.STARTER_STAT for k in STATS}, pot)
                pots.append(_mean_pot(pot))
                out = eco.career(rng, prof, eco.PHASE3, max_weeks=120, ageing=NO_DECLINE, start=start)
                if out["Champion"]["played"] is not None:
                    played.append(out["Champion"]["played"])
                r = out["Rookie"]
                rook_regular.append(r["unlock"] if r["unlock"] is not None else r["regular"])
                if r["p"]:
                    rook_p.append(st.mean(r["p"]))
                    rook_wins.append(r["wins"] / max(1, r["regular"]))
                closed.append(r["closed"])
            res[kind] = {"champion": st.median(played) if played else None, "reached": len(played) / players,
                         "rookie_regular": st.median(rook_regular), "rookie_regular_p10": sorted(rook_regular)[players // 10],
                         "rookie_p": _ci(rook_p), "rookie_wins": _ci(rook_wins),
                         "closed": sum(closed) / players, "pot": st.mean(pots)}
        rep[name] = res
    return rep


def gate_ladder(rep: dict) -> list:
    out = []
    for name, r in rep.items():
        s, f = r["starter"]["champion"], r["foal"]["champion"]
        ratio = f / s if s and f else float("nan")
        out.append((f"ladder {name}: gen-3 foal's Champion arrival >= {GATE_ARRIVAL:.0%} of a starter's",
                    f"{f:.0f} / {s:.0f} races = {ratio:.0%}" if s and f else "-", ratio >= GATE_ARRIVAL))
    a = rep["average"]["foal"]
    out.append((f"Rookie (average kid): gen-3 foal plays >= {GATE_ROOKIE_RACES} regular Rookie races (median)",
                f"{a['rookie_regular']:.0f} (p10 {a['rookie_regular_p10']})", a["rookie_regular"] >= GATE_ROOKIE_RACES))
    w = a["rookie_p"][0]
    out.append((f"Rookie (average kid): gen-3 foal's win chance {GATE_ROOKIE_WIN[0]:.0%}-{GATE_ROOKIE_WIN[1]:.0%}",
                f"{w:.1%} ±{a['rookie_p'][1]:.1%}", GATE_ROOKIE_WIN[0] <= w <= GATE_ROOKIE_WIN[1]))
    return out


# --- Power at Champion -------------------------------------------------------------------------

def plateau_horse(rng: random.Random, gens: int = 10) -> tuple:
    """A best3+legend line at generation `gens`: the better parent (Legend lines are the worst case)."""
    pa, pb = market_listing(rng, "top")[1], market_listing(rng, "top")[1]
    for _ in range(gens):
        foals = sorted((br.foal_potential(pa, pb, True, False, rng) for _ in range(3)), key=lambda p: -_mean_pot(p))
        pa, pb = foals[0], foals[1]
    return pa


def greedy_best(rng: random.Random, foals: int = 40, cfg: dict = br.BREEDING) -> dict:
    """The best horse in a 20-horse stable after `foals` foals, always from its two best (top-tier
    founders, a Legend parent whenever the better parent could be one: the worst case)."""
    stable = [market_listing(rng, "top")[1] for _ in range(2)]
    for _ in range(foals):
        stable.sort(key=lambda p: -_mean_pot(p))
        stable.append(br.foal_potential(stable[0], stable[1], True, False, rng, cfg))
        stable.sort(key=lambda p: -_mean_pot(p))
        del stable[cfg["stableCap"]:]
    return stable[0]


def champion_rate(rng: random.Random, pot: dict, races: int) -> tuple:
    ratings, wins, ps = [], 0, []
    for _ in range(races):
        cond = {"distance": rng.choice(eco.ALL_DISTANCES), "surface": rng.choice(eco.SURFACES),
                "weather": rng.choice(eco.WEATHERS)}
        r = eco.rr.rating(pot, cond, 1.0, 0, None, 1.0)
        place, p0, _ = eco.ladder_race(rng, "Champion", r, "average", eco.PHASE3["anchors"])
        ratings.append(r)
        ps.append(p0)
        wins += place == 1
    return st.mean(ratings), st.mean(ps), wins / races


def power_report(horses: int, races: int, seed: int) -> dict:
    rng = random.Random(seed)
    groups = {
        "starter": lambda: starter_pot(rng),
        "market top tier": lambda: market_listing(rng, "top")[1],
        "bred plateau (gen 10, Legend line)": lambda: plateau_horse(rng),
        "greedy stable best (40 foals, Legend)": lambda: greedy_best(rng),
    }
    rep = {}
    for name, make in groups.items():
        rows = [champion_rate(rng, make(), races) for _ in range(horses)]
        rep[name] = {"rating": _ci([r[0] for r in rows]), "p": _ci([r[1] for r in rows]),
                     "ratings": sorted(r[0] for r in rows), "pot": None}
    top = rep["market top tier"]["ratings"]
    p90 = top[int(len(top) * 0.9)]
    for name in ("bred plateau (gen 10, Legend line)", "greedy stable best (40 foals, Legend)"):
        bred = rep[name]["ratings"]
        rep[name]["share_above_p90"] = sum(1 for r in bred if r > p90) / len(bred)
    rep["top_p90"] = p90
    return rep


def gate_power(rep: dict) -> list:
    out = []
    top = rep["market top tier"]["p"][0]
    for name in ("bred plateau (gen 10, Legend line)", "greedy stable best (40 foals, Legend)"):
        bred, share = rep[name]["p"][0], rep[name]["share_above_p90"]
        out.append((f"power {name}: Champion win chance <= top tier + {GATE_POWER_PTS:.0%}", f"{bred:.1%} vs {top:.1%}",
                    bred <= top + GATE_POWER_PTS))
        out.append((f"power {name}: rated above the top tier's p90 (info; {GATE_POWER_SHARE:.0%} flags a tail)", f"{share:.0%}",
                    None if share > GATE_POWER_SHARE else True))
    return out


# --- Cash --------------------------------------------------------------------------------------

TAME_SESSION = {"casual": 1, "average": 1, "keen": 0}  # the session (0-based) the second horse is tamed
SECOND_RACES = 4             # races per session on the second horse until it has minParentRaces
WEEKS = 16


def cash_kid(rng: random.Random, name: str, policy: str, cfg: dict = br.BREEDING, weeks: int = WEEKS) -> dict:
    """One kid's 16 weeks. policy: "none", "after" (Barn Builder wish first, then breed when the
    fee leaves FEED_RESERVE) or "first" (breed first). The first foal is always saved for once
    the parents qualify (a kid who wants a foal). Owner races = 10 per session."""
    prof = eco.PROFILES[PROFILES[name]]
    ledger: list = []
    eco.career(rng, prof, eco.PHASE3, max_weeks=weeks, purses=eco.LEAGUE_B, ledger=ledger)
    shelf = eco._shelf()
    feed = eco.FEED_COST["full" if prof.care >= 1 else "half"]
    cash, owned, best = eco.START_CASH, set(), 0
    owner, main_races, second_races, second = 0, 0, 0, False
    next_at, pending_at, pending_day = 0, None, None
    fees = sales = created_bronze = fees_last = 0
    first_confirm = first_arrive = None
    foals, stable = 0, 2
    buys, leagues, balances = [], [], {}
    for i, (league, earned) in enumerate(ledger):
        week = i // prof.sessions + 1
        if i >= TAME_SESSION[name]:
            second = True
        races = prof.races
        on_second = min(SECOND_RACES, cfg["minParentRaces"] - second_races) if second and second_races < cfg["minParentRaces"] else 0
        second_races += on_second
        main_races += races - on_second
        owner += races
        cash += earned + eco.JOBS_CASH - feed
        if league != "Rookie":
            created_bronze += earned + eco.JOBS_CASH
        best = max(best, eco.LEAGUES.index(league))
        leagues.append(league)
        # the foal arrives (8 owner races, or a later play day = a later session)
        if pending_at is not None and (owner >= pending_at or i > pending_day):
            pending_at = None
            foals += 1
            if first_arrive is None:
                first_arrive = i
            stable += 1
            if stable > cfg["stableCap"]:  # make room: the newest foal goes to the Riding School
                sales += br.sell_value(fees_last, 0, 0)
                cash += br.sell_value(fees_last, 0, 0)
                stable -= 1
        can = (policy != "none" and pending_at is None and owner >= next_at and league != "Rookie"
               and main_races >= cfg["minParentRaces"] and second_races >= cfg["minParentRaces"])
        price = br.fee(league, "Rookie", cfg) if can else None

        def breed():
            nonlocal cash, fees, next_at, pending_at, pending_day, first_confirm, fees_last
            cash -= price
            fees += price
            fees_last = price
            next_at = owner + cfg["foalEveryRaces"]
            pending_at, pending_day = owner + cfg["foalAfterRaces"], i
            if first_confirm is None:
                first_confirm = i

        if can and first_confirm is None:
            if cash - price >= eco.FEED_RESERVE:
                breed()
                can = False
            else:
                can = None  # saving for the first foal: no shopping
        if can and policy == "first" and cash - price >= eco.FEED_RESERVE:
            breed()
            can = False
        if can is not None:
            while True:
                wish = eco._next_wish(shelf, owned, best)
                if wish is None or cash - wish[3] < eco.FEED_RESERVE:
                    break
                cash -= wish[3]
                owned.add(wish[0])
                buys.append(i)
        if can and policy == "after" and cash - price >= eco.FEED_RESERVE:
            breed()
        if (i + 1) % prof.sessions == 0:
            nxt = eco._next_wish(shelf, owned, best)
            balances[week] = (cash, nxt[3] if nxt else None)
    # Barn Builder waits: sessions from each session (Rookie..Gold) to the next build
    waits = []
    bset = sorted(set(buys))
    for s, lg in enumerate(leagues):
        if lg == "Champion":
            continue
        nxt = next((b for b in bset if b >= s), None)
        waits.append(nxt - s + 1 if nxt is not None else float("inf"))
    sess = prof.sessions
    return {"fees": fees, "sales": sales, "created_bronze": created_bronze, "balances": balances,
            "waits": waits, "foals": foals, "owned": len(owned),
            "first_confirm": None if first_confirm is None else (first_confirm + 1) / sess,
            "first_foal": None if first_arrive is None else (first_arrive + 1) / sess}


def cash_report(players: int, seed: int, cfg: dict = br.BREEDING) -> dict:
    rep = {}
    for name in PROFILES:
        rows = {}
        for policy in ("none", "after", "first"):
            rng = random.Random(seed)
            kids = [cash_kid(rng, name, policy, cfg) for _ in range(players)]
            share = [k["fees"] / k["created_bronze"] for k in kids if k["created_bronze"] > 0]
            w12 = [k["balances"][12][0] for k in kids]
            waits = sorted(w for k in kids for w in k["waits"])
            firsts = [k["first_foal"] for k in kids if k["first_foal"] is not None]
            rows[policy] = {
                "share": _ci(share) if share else (0.0, 0.0), "w12": st.median(w12),
                "wait": st.median(waits), "wait_p75": waits[int(len(waits) * 0.75)],
                "foals": st.mean(k["foals"] for k in kids), "fees_wk": st.mean(k["fees"] for k in kids) / WEEKS,
                "created_wk": st.mean(k["created_bronze"] for k in kids) / WEEKS,
                "first_foal": st.median(firsts) if firsts else None,
                "first_foal_p75": sorted(firsts)[int(len(firsts) * 0.75)] if firsts else None,
                "has_foal": len(firsts) / players, "owned": st.median(k["owned"] for k in kids),
            }
        rep[name] = rows
    return rep


def gate_cash(rep: dict) -> list:
    out = []
    for name, rows in rep.items():
        for policy in ("after", "first"):
            r = rows[policy]
            s = r["share"][0]
            inside = GATE_FEE_SHARE[0] <= s <= GATE_FEE_SHARE[1]
            out.append((f"cash {name} [{policy}]: fees {GATE_FEE_SHARE[0]:.0%}-{GATE_FEE_SHARE[1]:.0%} of cash created after Bronze"
                        + (" (stress row, info)" if policy == "first" else ""),
                        f"{s:.1%} ±{r['share'][1]:.1%}", inside if policy == "after" else (True if inside else None)))
            out.append((f"cash {name} [{policy}]: Barn Builder median wait <= {GATE_WAIT} sessions",
                        f"{r['wait']:.0f} (p75 {r['wait_p75']:.0f}; none {rows['none']['wait']:.0f})", r["wait"] <= GATE_WAIT))
        if name == "keen":
            drop = 1 - rows["after"]["w12"] / rows["none"]["w12"] if rows["none"]["w12"] else 0
            out.append((f"cash keen: week-12 pile falls >= {GATE_PILE_DROP:.0%} [after]",
                        f"{rows['none']['w12']:,.0f} -> {rows['after']['w12']:,.0f} ({drop:.0%})", drop >= GATE_PILE_DROP))
        ff = rows["after"]["first_foal"]
        out.append((f"first foal {name}: by week {GATE_FIRST_FOAL[name]} (median)", f"week {ff:.1f}" if ff else "-",
                    ff is not None and ff <= GATE_FIRST_FOAL[name]))
    return out


# --- No profit ---------------------------------------------------------------------------------

def profit_report() -> list:
    rows = []
    for league, price in br.BREEDING["fee"].items():
        best = br.sell_value(price, 10 ** 6, 10 ** 6)
        rows.append((league, price, br.sell_value(price, 0, 0), best, best < price))
    return rows


# --- Main --------------------------------------------------------------------------------------

def _gates(rows: list) -> bool:
    ok = True
    for name, value, passed in rows:
        print(f"  [{'INFO' if passed is None else 'PASS' if passed else 'FAIL'}] {name}: {value}")
        ok &= passed is not False
    return ok


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Giddy-Up breeding sims (D-080)")
    for flag in ("bloodline", "spread", "ladder", "power", "cash", "profit", "all"):
        ap.add_argument(f"--{flag}", action="store_true")
    ap.add_argument("--lines", type=int, default=300)
    ap.add_argument("--players", type=int, default=80)
    ap.add_argument("--races", type=int, default=150)
    ap.add_argument("--seed", type=int, default=1)
    args = ap.parse_args(argv)
    every = args.all or not any(getattr(args, f) for f in ("bloodline", "spread", "ladder", "power", "cash", "profit"))
    ok = True
    if every or args.bloodline:
        rep = bloodline_report(args.lines, args.seed)
        print(f"bloodline ({args.lines} lines per strategy, Market top-tier founders): mean Potential per stat by generation")
        print("  gen " + "".join(f"{s:>22}" for s in STRATEGIES))
        for g in range(len(rep["random"]["rows"])):
            cells = ""
            for s in STRATEGIES:
                m, ci = rep[s]["rows"][g]["mean"]
                bs = rep[s]["rows"][g]["best_stat"]
                extra = f" ({bs[0]:.0f})" if s == "best3+legend" and bs else ""
                cells += f"{m:15.1f} ±{ci:3.1f}{extra:>5}" if extra else f"{m:17.1f} ±{ci:3.1f}"
            print(f"  {g:3d} {cells}")
        ok &= _gates(gate_bloodline(rep))
    if every or args.spread:
        rep = spread_report(40000, args.seed)
        print(f"\nspread: fixed pair 85/80 sd {rep['fixed_sd']:.2f} (mean {rep['fixed_mean']:.1f}); population pairs "
              f"mean {rep['pop_mean']:.1f} sd {rep['pop_sd']:.2f}, p1 {rep['pop_p01']}, p99 {rep['pop_p99']}, max {rep['pop_max']}; "
              f"two top-tier Legends mean {rep['top_mean']:.1f}, p99 {rep['top_p99']}, max {rep['top_max']}; "
              f"family sprouts {', '.join(f'{k}: {v:.0%}' for k, v in rep['family'].items())}")
        ok &= _gates(gate_spread(rep))
    if every or args.ladder:
        rep = ladder_report(args.players, args.seed)
        print(f"\nladder ({args.players} horses per cell; median counted races to Champion; Rookie regular races before the Cup opens)")
        for name, r in rep.items():
            for kind in ("starter", "foal"):
                x = r[kind]
                print(f"  {name:8}{kind:8} Potential {x['pot']:.1f}  Champion {x['champion']} ({x['reached']:.0%})  "
                      f"Rookie regular {x['rookie_regular']:.0f} (p10 {x['rookie_regular_p10']}), win chance "
                      f"{x['rookie_p'][0]:.1%} ±{x['rookie_p'][1]:.1%}, wins {x['rookie_wins'][0]:.1%}, ceiling closed {x['closed']:.0%}")
        ok &= _gates(gate_ladder(rep))
    if every or args.power:
        rep = power_report(args.players, args.races, args.seed)
        print(f"\npower at Champion ({args.players} horses x {args.races} races, trained out, average kid)")
        for name in ("starter", "market top tier", "bred plateau (gen 10, Legend line)", "greedy stable best (40 foals, Legend)"):
            r = rep[name]
            print(f"  {name:38} Rating {r['rating'][0]:.1f} ±{r['rating'][1]:.1f}  win chance {r['p'][0]:.1%} ±{r['p'][1]:.1%}")
        ok &= _gates(gate_power(rep))
    if every or args.cash:
        rep = cash_report(args.players, args.seed)
        print(f"\ncash ({args.players} kids per cell, {WEEKS} weeks)")
        for name, rows in rep.items():
            for policy, r in rows.items():
                print(f"  {name:8}{policy:6} fees/wk {r['fees_wk']:6.0f}  created after Bronze/wk {r['created_wk']:6.0f}  "
                      f"share {r['share'][0]:5.1%}  w12 {r['w12']:6,.0f}  wait {r['wait']:.0f} (p75 {r['wait_p75']:.0f})  "
                      f"foals {r['foals']:.1f}  first foal wk {r['first_foal'] if r['first_foal'] is None else round(r['first_foal'], 1)} "
                      f"(p75 {r['first_foal_p75'] if r['first_foal_p75'] is None else round(r['first_foal_p75'], 1)}, {r['has_foal']:.0%})  "
                      f"items {r['owned']:.0f}")
        ok &= _gates(gate_cash(rep))
    if every or args.profit:
        print("\nno profit: league, fee, sell at once, sell with any record")
        rows = profit_report()
        for league, price, now, best, _ in rows:
            print(f"  {league:9}{price:6}{now:6}{best:6}")
        ok &= _gates([(f"profit {lg}: sell value < fee", f"{best} < {price}", passed) for lg, price, _, best, passed in rows])
    print("\nALL GATES PASS" if ok else "\nSOME GATES FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
