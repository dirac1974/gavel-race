#!/usr/bin/env python3
"""Life arc sims (fun-and-return consensus, 2026-10-12): `--ageing`, `--sell`, `--legs`.

--ageing  Long careers (650+ counted races per horse) for casual / average / keen kids on the
          D-068 ladder (economy.career), three variants paired on one RNG stream: off (today),
          young (Youngster training boost only, declineScale 0) and decline (declineScale 1).
          Reports league arrival (must not move before veteranAt), the Champion win rate before the
          decline and at the cap, cash per race, and when each profile first loses Rating.
--sell    Riding School sale = half the price paid + min(perWin x wins + perCup x Cups, cap).
          A cap is safe when buy -> race N -> sell nets less than racing an owned horse N races.
--legs    The vet run counter (6 counted races in a row on one horse) over sessions with Energy,
          care top-ups, the Spa, training rides and rest; vet checks per session and races/hour.

Results: docs/reviews/fun-and-return-2026-10-12/lifearc-sim.md. Single process, small samples.
"""

from __future__ import annotations

import argparse
import math
import random
import statistics as st
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
import economy as eco  # noqa: E402
import life_arc as la  # noqa: E402

LIFE_PROFILES = {"casual": "casual", "average": "casual-average", "keen": "engaged"}
VARIANTS = {
    "off": None,
    "young": {**la.AGEING, "declineScale": 0},
    "decline": {**la.AGEING, "declineScale": 1},
}
CAREER_RACES = 1500
PRE = (250, 350)       # Champion races before the Veteran stage
CAPPED = (550, 650)    # at the decline cap
LATE = (1200, 1500)    # about the trained-out plateau (Potential reached) for every profile
WINDOWS = {"pre": PRE, "350-400": (350, 400), "400-450": (400, 450), "450-500": (450, 500), "500-550": (500, 550),
           "550-650": CAPPED, "650-900": (650, 900), "900-1200": (900, 1200), "1200-1500": LATE}
GATE_WIN = (0.30, 0.50)


def _ci(xs: list) -> tuple:
    if len(xs) < 2:
        return (st.mean(xs) if xs else float("nan"), 0.0)
    return st.mean(xs), 1.96 * st.stdev(xs) / math.sqrt(len(xs))


def _window(trace: list, lo: int, hi: int, league: str = "Champion") -> list:
    return [r for r in trace if lo <= r[0] < hi and r[1] == league and not r[5]]


def ageing_runs(profile: str, variant: str, players: int, seed: int, races: int = CAREER_RACES) -> list:
    prof = eco.PROFILES[LIFE_PROFILES.get(profile, profile)]
    rng = random.Random(seed)
    runs = []
    for _ in range(players):
        trace: list = []
        out = eco.career(rng, prof, eco.PHASE3, max_weeks=400, ageing=VARIANTS[variant],
                         min_played=races, trace=trace)
        runs.append((out, trace))
    return runs


def ageing_summary(runs: list) -> dict:
    rep: dict = {"arrive": {}, "windows": {}}
    starts = [next((r[7] for r in tr if r[7] is not None), None) for _, tr in runs]
    got = [x for x in starts if x is not None]
    rep["decline_from"] = (st.median(got) if got else None, len(got) / len(runs))
    for lg in eco.LEAGUES[1:]:
        played = [o[lg]["played"] for o, _ in runs if o[lg]["played"] is not None]
        weeks = [o[lg]["week"] for o, _ in runs if o[lg]["week"] is not None]
        rep["arrive"][lg] = (st.median(played) if played else None, st.median(weeks) if weeks else None,
                             len(played) / len(runs))
    for name, (lo, hi) in WINDOWS.items():
        p, cash, rating, share = [], [], [], []
        for _, tr in runs:
            w = _window(tr, lo, hi)
            share.append(len(w) / max(1, sum(1 for r in tr if lo <= r[0] < hi)))
            if len(w) >= 10:
                p.append(st.mean(r[2] for r in w))
                cash.append(st.mean(r[4] for r in w))
                rating.append(min(r[6] for r in w))
        rep["windows"][name] = {"p": _ci(p), "cash": _ci(cash), "n": len(p),
                                "min_rating": min(rating) if rating else None,
                                "champion_share": st.mean(share)}
    return rep


def print_ageing(players: int, seed: int) -> dict:
    cfg = la.AGEING
    print(f"ageing: Veteran at {cfg['veteranAt']}, -1 per {cfg['declinePer']} races (first step at "
          f"declineFrom + {cfg['declinePer']}; declineFrom = first race with {cfg['veteranAt']}+ races and stats >= "
          f"{cfg['peakShare']:.0%} of Potential), cap -{cfg['declineCap']}; Young x{cfg['youngTrainMult']} "
          f"training for {cfg['youngRaces']} races; {players} horses per cell, {CAREER_RACES}+ races each")
    allrep = {}
    for prof in LIFE_PROFILES:
        reps = {v: ageing_summary(ageing_runs(prof, v, players, seed)) for v in VARIANTS}
        allrep[prof] = reps
        pr = eco.PROFILES[LIFE_PROFILES[prof]]
        print(f"\n{prof} ({LIFE_PROFILES[prof]}: {pr.sessions}x{pr.races} races a week, {pr.kid} rider)")
        df = reps["decline"]["decline_from"]
        print(f"  decline starts (declineFrom, median of horses that reach it): "
              f"{df[0] if df[0] is not None else '-'} ({df[1]:.0%} of horses by {CAREER_RACES})")
        print("  arrival (median counted races / week): " + "; ".join(
            f"{lg} " + " | ".join(f"{v} {r['arrive'][lg][0]:.0f}/{r['arrive'][lg][1]:.1f}"
                                  if r["arrive"][lg][0] is not None else f"{v} -" for v, r in reps.items())
            for lg in eco.LEAGUES[1:]))
        print(f"  {'window':9}{'Champ':>6}" + "".join(f"{v + ' win':>18}{v + ' cash':>15}" for v in VARIANTS)
              + f"{'min R':>7}")
        for wname in reps["off"]["windows"]:
            row = f"  {wname:9}{reps['off']['windows'][wname]['champion_share']:6.0%}"
            for v in VARIANTS:
                w = reps[v]["windows"][wname]
                row += f"{w['p'][0]:11.1%} ±{w['p'][1]:4.1%}{w['cash'][0]:9.1f} ±{w['cash'][1]:4.1f}"
            mr = reps["decline"]["windows"][wname]["min_rating"]
            print(row + (f"{mr:7.1f}" if mr is not None else f"{'-':>7}"))
        crossed = [w for w in WINDOWS if reps["off"]["windows"][w]["p"][0] >= GATE_WIN[0] > reps["decline"]["windows"][w]["p"][0]]
        late = reps["decline"]["windows"]["1200-1500"]["p"][0]
        print(f"  gates: decline alone takes >= {GATE_WIN[0]:.0%} below it in {crossed or 'no window'}; plateau with decline "
              f"{late:.1%} ({'in' if GATE_WIN[0] <= late <= GATE_WIN[1] else 'OUT of'} {GATE_WIN[0]:.0%}-{GATE_WIN[1]:.0%})")
    return allrep


# --- Sell -------------------------------------------------------------------------------------

def market_listing(rng: random.Random) -> tuple:
    """Market.stock's distribution: (stats, potential, price)."""
    tier = rng.random()
    lo, hi = (82, 95) if tier > 0.85 else (72, 86) if tier > 0.5 else (62, 78)
    stats, pot = {}, {}
    for k in eco.rr.STATS:
        stats[k] = rng.randint(40, 52)
        pot[k] = max(stats[k] + 5, rng.randint(lo, hi))
    avg_pot, avg_stat = sum(pot.values()) / 4, sum(stats.values()) / 4
    price = 250 + max(0, avg_pot - 65) ** 2 * 2.2 + max(0, avg_stat - 40) * 12
    return stats, pot, int(math.floor(price / 10 + 0.5) * 10)


SELL_N = (25, 50, 100, 200)


def sell_samples(profile: str, players: int, seed: int) -> list:
    """Per kid: the main horse's trace (owned, raced on) and one bought horse's first 200 races,
    bought as soon as the main horse's race cash covers the price."""
    prof = eco.PROFILES[LIFE_PROFILES.get(profile, profile)]
    rng = random.Random(seed)
    out = []
    for _ in range(players):
        main: list = []
        eco.career(rng, prof, eco.PHASE3, max_weeks=400, min_played=900, trace=main)
        stats, pot, price = market_listing(rng)
        new: list = []
        eco.career(rng, prof, eco.PHASE3, max_weeks=400, min_played=max(SELL_N), trace=new, start=(stats, pot))
        cum, b = 0, None
        for i, r in enumerate(main):
            cum += r[4]
            if cum >= price + eco.START_CASH and b is None:
                b = i + 1
        if b is None or b + max(SELL_N) > len(main):
            continue
        rows = {}
        for n in SELL_N:
            w = new[:n]
            rows[n] = {"new": sum(r[4] for r in w), "owned": sum(r[4] for r in main[b:b + n]),
                       "wins": sum(1 for r in w if r[3] == 1), "cups": sum(1 for r in w if r[3] == 1 and r[5])}
        out.append({"price": price, "buy_at": b, "rows": rows})
    return out


def sell_surplus(sample: dict, n: int, cap: int) -> float:
    """buy -> race n -> sell, minus racing the owned horse n races (< 0 = no loop)."""
    r = sample["rows"][n]
    sale = la.sell_value(sample["price"], r["wins"], r["cups"], "market", {**la.SELL, "recordBonusCap": cap})
    return r["new"] + sale - sample["price"] - r["owned"]


def sale_minus_price(sample: dict, n: int, cap: int) -> int:
    r = sample["rows"][n]
    return la.sell_value(sample["price"], r["wins"], r["cups"], "market", {**la.SELL, "recordBonusCap": cap}) - sample["price"]


def print_sell(players: int, seed: int) -> dict:
    caps = [0, 25, 50, 75, 100, 125, 150, 200, 300]
    samples = {prof: sell_samples(prof, players, seed) for prof in LIFE_PROFILES}
    prices = [s["price"] for v in samples.values() for s in v]
    print(f"sell: {la.SELL['share']:.0%} of price + min({la.SELL['perWin']} x wins + {la.SELL['perCup']} x Cups, cap); "
          f"prices min {min(prices)}, p10 {sorted(prices)[len(prices) // 10]}, median {st.median(prices):.0f}")
    print("mean surplus (buy -> race N -> sell, minus racing the owned horse N races; < 0 = no loop), and the "
          "share of kids with surplus > 0; then the share whose sale beats the price paid")
    res: dict = {}
    for prof, ss in samples.items():
        print(f"\n{prof}: {len(ss)} kids, bought after {st.median(s['buy_at'] for s in ss):.0f} races (median)")
        for n in SELL_N:
            w = st.median(s["rows"][n]["wins"] for s in ss)
            c = st.mean(s["rows"][n]["cups"] for s in ss)
            cells = []
            for cap in caps:
                sur = [sell_surplus(s, n, cap) for s in ss]
                pos = sum(1 for x in sur if x > 0) / len(sur)
                beat = sum(1 for s in ss if sale_minus_price(s, n, cap) > 0) / len(ss)
                res.setdefault(prof, {}).setdefault(n, {})[cap] = (st.mean(sur), pos, beat)
                cells.append(f"{cap}:{st.mean(sur):+.0f}/{pos:.0%}/{beat:.0%}")
            print(f"  N {n:3} (wins {w:.0f}, Cups {c:.1f}): " + "  ".join(cells))
    return res


# --- Legs (the vet run) -------------------------------------------------------------------------

RACE_MIN = 4.0        # queue + race + results, minutes
CARE_MIN, SPA_MIN, RIDE_MIN, VET_MIN = 0.5, 1.0, 2.0, 0.5
E_MAX, E_REGEN_MIN, CARE_COOLDOWN_MIN = 5, 20.0, 120.0
LEGS_KIDS = {
    # sessions/week, races per session (mean, sd), care at start (each of feed, groom), training ride
    # per session, heed the 5-race chip (feed or groom), Spa when out of Energy, wait for Energy
    # (else stop), owns a second horse to rotate, counted Rookie races (free) before Bronze
    "casual": dict(sessions=3, races=(10, 2), care=0.5, ride=0.67, heed=0.3, spa=0.5, wait=0.4, second=0.0, rookie=26),
    "average": dict(sessions=4, races=(14, 3), care=0.75, ride=0.67, heed=0.4, spa=0.6, wait=0.6, second=0.3, rookie=24),
    "keen": dict(sessions=6, races=(24, 4), care=1.0, ride=0.67, heed=0.5, spa=0.8, wait=0.8, second=0.5, rookie=22),
}


def _mins(cfg: dict) -> dict:
    """LEGS with its times in minutes (the session clock)."""
    return {**cfg, "restSeconds": cfg["restSeconds"] / 60, "careCooldownSeconds": cfg["careCooldownSeconds"] / 60}


class _Horse:
    def __init__(self):
        self.energy, self.e_at, self.run, self.last = float(E_MAX), 0.0, 0, -1e9
        self.feed_at, self.groom_at, self.spa_day, self.races = -1e9, -1e9, -1, 0


def legs_kid(rng: random.Random, kid: dict, weeks: int, cfg: dict | None) -> list:
    """Sessions of one kid: (vets, races, minutes, rookie_phase). cfg None = no vet rule."""
    horses = [_Horse()] + ([_Horse()] if rng.random() < kid["second"] else [])
    out = []
    for s in range(weeks * kid["sessions"]):
        t0 = s * 24 * 60 * 7 / kid["sessions"]
        t = t0
        for h in horses:
            h.energy, h.e_at, h.run = float(E_MAX), t, 0  # days apart: full Energy, rested
        target = max(3, round(rng.gauss(*kid["races"])))
        ride_at = rng.randrange(target) if rng.random() < kid["ride"] else -1
        cur = horses[0]
        for kind in ("feed", "groom"):
            if rng.random() < kid["care"]:
                setattr(cur, kind + "_at", t)
                t += CARE_MIN
        vets = races = 0
        extra = 0.0
        rookie = cur.races < kid["rookie"]
        for i in range(target):
            if i == ride_at:
                cur.run, t = 0, t + RIDE_MIN
            free = cur.races < kid["rookie"]
            if not free:
                cur.energy = min(E_MAX, cur.energy + (t - cur.e_at) / E_REGEN_MIN)
                cur.e_at = t
                if cur.energy < 1:
                    other = next((h for h in horses if h is not cur and min(E_MAX, h.energy + (t - h.e_at) / E_REGEN_MIN) >= 1), None)
                    if other is not None:
                        other.energy, other.e_at = min(E_MAX, other.energy + (t - other.e_at) / E_REGEN_MIN), t
                        cur = other
                        free = cur.races < kid["rookie"]
                    elif t - cur.feed_at >= CARE_COOLDOWN_MIN or t - cur.groom_at >= CARE_COOLDOWN_MIN:
                        kind = "feed" if t - cur.feed_at >= CARE_COOLDOWN_MIN else "groom"
                        if cfg:
                            cur.run = la.run_after_care(cur.run, getattr(cur, kind + "_at"), t, _mins(cfg))[0]
                        setattr(cur, kind + "_at", t)
                        cur.energy += 1
                        t += CARE_MIN
                    elif cur.spa_day != s and rng.random() < kid["spa"]:
                        cur.spa_day, cur.energy, cur.run = s, cur.energy + 1, 0
                        t += SPA_MIN
                    elif rng.random() < kid["wait"]:
                        t += (1 - cur.energy) * E_REGEN_MIN
                        cur.energy, cur.e_at = 1.0, t
                    else:
                        break
            heed = rng.random() < kid["heed"]  # drawn every race, so on/off runs share one stream
            if cfg:
                cur.run = la.run_now(cur.run, cur.last, t, _mins(cfg))
                # heeding the chip: a feed or groom whose kind is off its cooldown (ruling 4)
                kind = next((k for k in ("groom", "feed") if t - getattr(cur, k + "_at") >= CARE_COOLDOWN_MIN), None)
                if la.legs_warning(cur.run, cfg) and heed and kind:
                    cur.run = la.run_after_care(cur.run, getattr(cur, kind + "_at"), t, _mins(cfg))[0]
                    setattr(cur, kind + "_at", t)
                    if not free:
                        cur.energy = min(E_MAX, cur.energy + 1)
                    t += CARE_MIN
                    extra += CARE_MIN
                if la.needs_vet(cur.run, cfg):
                    vets += 1
                    cur.run = 0
                    t += VET_MIN
                    extra += VET_MIN
            t += RACE_MIN
            cur.races += 1
            races += 1
            if cfg:
                cur.run = la.run_after_race(cur.run, cur.races, cfg)
            if not free:
                cur.energy -= 1
            cur.last = t
        out.append((vets, races, t - t0, rookie, extra))
    return out


def legs_report(kid: str, players: int, seed: int, weeks: int = 8, cfg: dict | None = la.LEGS) -> dict:
    rng = random.Random(seed)
    sessions = [x for _ in range(players) for x in legs_kid(rng, LEGS_KIDS[kid], weeks, cfg)]
    later = [x for x in sessions if not x[3]]
    long = [x for x in sessions if x[1] >= 20]
    return {
        "vets_long": _ci([x[0] for x in long]) if long else (float("nan"), 0.0),
        "long_share": len(long) / len(sessions),
        "vets": _ci([x[0] for x in sessions]),
        "vets_later": _ci([x[0] for x in later]),
        "vets_rookie": _ci([x[0] for x in sessions if x[3]]),
        "share_any": sum(1 for x in sessions if x[0] > 0) / len(sessions),
        "races": st.mean(x[1] for x in sessions),
        "per_hour": sum(x[1] for x in sessions) / (sum(x[2] for x in sessions) / 60),
        # the rule's own time (heeding the chip, the Cool-down Check) over all session time
        "time_cost": sum(x[4] for x in sessions) / sum(x[2] for x in sessions),
    }


def print_legs(players: int, seed: int, weeks: int = 8) -> dict:
    c = la.LEGS
    print(f"legs: vet at {c['runLimit']} counted races in a row on one horse (chip at {c['warnAt']}), feed/groom "
          f"-{c['careLowers']}, {c['restSeconds'] // 60} min rest / Spa / training / vet reset, never in the first "
          f"{c['fromRaces']} races; {players} kids x {weeks} weeks")
    res = {}
    for kid in LEGS_KIDS:
        on = legs_report(kid, players, seed, weeks)
        off = legs_report(kid, players, seed, weeks, None)
        res[kid] = (on, off)
        print(f"  {kid:8} vets/session {on['vets'][0]:.2f} ±{on['vets'][1]:.2f} (Rookie phase {on['vets_rookie'][0]:.2f}, "
              f"after {on['vets_later'][0]:.2f}), sessions with a vet {on['share_any']:.0%}, races/session "
              f"{on['races']:.1f}, races/hour {off['per_hour']:.2f} -> {on['per_hour']:.2f} "
              f"({on['per_hour'] / off['per_hour'] - 1:+.1%}, own time cost -{on['time_cost']:.2%}); sessions of 20+ races {on['long_share']:.0%}, "
              f"vets in them {on['vets_long'][0]:.2f}")
    print("  sensitivity (vets/session after Rookie | in 20+ race sessions):")
    for limit in (5, 6, 7):
        for lowers in (1, 2):
            cfg = {**c, "runLimit": limit, "warnAt": limit - 1, "careLowers": lowers}
            cells = []
            for kid in LEGS_KIDS:
                r = legs_report(kid, players, seed, weeks, cfg)
                cells.append(f"{kid} {r['vets_later'][0]:.2f} | {r['vets_long'][0]:.2f}")
            print(f"    runLimit {limit}, care -{lowers}: " + "; ".join(cells))
    return res


def main(argv=None):
    ap = argparse.ArgumentParser(description="Giddy-Up life arc sims")
    ap.add_argument("--ageing", action="store_true")
    ap.add_argument("--sell", action="store_true")
    ap.add_argument("--legs", action="store_true")
    ap.add_argument("--players", type=int, default=60)
    ap.add_argument("--seed", type=int, default=1)
    args = ap.parse_args(argv)
    if args.ageing:
        print_ageing(args.players, args.seed)
    if args.sell:
        print_sell(args.players, args.seed)
    if args.legs:
        print_legs(args.players, args.seed)


if __name__ == "__main__":
    main(sys.argv[1:])
