"""Breeding (D-080): src/breeding.py, its Luau mirror's config and parity table, and the sim gates
that are cheap enough to run here. Regenerate the parity table with
`python tests/test_breeding.py --write`."""

import json
import random
import re
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))

import breeding as br  # noqa: E402
import life_arc as la  # noqa: E402

FIXTURE = ROOT / "tests" / "fixtures" / "breeding.json"
GAME_CONFIG = ROOT / "game" / "src" / "shared" / "GameConfig.luau"
MARKET = ROOT / "game" / "src" / "shared" / "Market.luau"
HORSE = ROOT / "game" / "src" / "shared" / "Horse.luau"

ON = {**br.BREEDING, "enabled": True}
CFGS = {
    "live": ON,
    "wide": {**ON, "noise": 8, "startMax": 100, "startShare": 0.35, "parentShare": 0.5, "breedAnchor": 70,
             "coatParentEach": 0.4, "coatSurprise": 0.2, "potMin": 60, "potMax": 95},
}
POTS = [
    ({"speed": 88, "accel": 90, "stamina": 85, "grit": 92}, {"speed": 84, "accel": 86, "stamina": 90, "grit": 83}),
    ({"speed": 70, "accel": 70, "stamina": 70, "grit": 70}, {"speed": 70, "accel": 70, "stamina": 70, "grit": 70}),
    ({"speed": 100, "accel": 100, "stamina": 100, "grit": 100}, {"speed": 100, "accel": 99, "stamina": 98, "grit": 100}),
    ({"speed": 55, "accel": 40, "stamina": 61, "grit": 58}, {"speed": 60, "accel": 62, "stamina": 59, "grit": 57}),
    ({"speed": 80, "accel": 81, "stamina": 79, "grit": 81}, {"speed": 93, "accel": 77, "stamina": 93, "grit": 70}),
]
UNIFORMS = [[0.0, 0.0, 0.0, 0.0], [0.999999, 0.999999, 0.999999, 0.999999], [0.5, 0.5, 0.5, 0.5],
            [0.05, 0.35, 0.65, 0.95], [0.45, 0.55, 0.45, 0.55]]
COAT_US = [0.0, 0.2, 0.449999, 0.45, 0.5, 0.8999, 0.9, 0.92, 0.95, 0.975, 0.999999]


class ListRng:
    def __init__(self, values):
        self.values, self.i = list(values), 0

    def random(self):
        v = self.values[self.i]
        self.i += 1
        return v


def _horse(i, league, races, pot, coat, legend=None, lent=None, name=None):
    h = {"id": f"h{i}", "name": name or f"Horse{i}", "league": league, "record": {"races": races},
         "potential": pot, "coat": coat}
    if legend is not None:
        h["legend"] = legend
    if lent is not None:
        h["lent"] = lent
    return h


def _profile(cash=1000, races=100, extra=0):
    pa, pb = POTS[0]
    horses = [_horse(1, "Bronze", 40, pa, "bay", name="Comet"), _horse(2, "Rookie", 31, pb, "grey", name="Maple"),
              _horse(3, "Rookie", 12, pb, "pinto"), _horse(4, "Gold", 400, pa, "appaloosa", legend=1),
              _horse(5, "Silver", 80, pb, "dun", lent=5), _horse(6, "Rookie", 50, pa, "white")]
    for k in range(extra):
        horses.append(_horse(10 + k, "Rookie", 0, pb, "bay"))
    return {"cash": cash, "totals": {"races": races}, "horses": horses}


def scenarios() -> list:
    """Action scripts run on a fresh profile; each step's result is recorded for Luau."""
    day0 = 20000 * 86400 + 3600
    scripts = [
        ("happy", {}, [("confirm", "h1", "h2", day0, [0.1, 0.6, 0.9, 0.3, 0.93]), ("ready", day0),
                        ("races", 7), ("ready", day0), ("arrive", day0), ("races", 1), ("ready", day0),
                        ("arrive", day0), ("block", "h1", "h2"), ("races", 51), ("block", "h1", "h2"),
                        ("races", 1), ("block", "h1", "h2"), ("confirm", "h1", "h2", day0, [0.5, 0.5, 0.5, 0.5, 0.0])]),
        ("legend", {"cash": 5000}, [("confirm", "h4", "h2", day0, [0.2, 0.4, 0.6, 0.8, 0.46]),
                                    ("confirm", "h4", "h1", day0, [0.2, 0.4, 0.6, 0.8, 0.1]),
                                    ("ready", day0 + 86399 - 3600), ("ready", day0 + 86400), ("arrive", day0 + 86400)]),
        ("poor", {"cash": 399}, [("confirm", "h1", "h2", day0, [0.5] * 5), ("cash", 1),
                                 ("confirm", "h1", "h2", day0, [0.5] * 5)]),
        ("blocks", {}, [("block", "h1", "h1"), ("block", "h1", "h3"), ("block", "h1", "h5"), ("block", "h2", "h6"),
                        ("block", "h1", "nope"), ("block", "h6", "h4"), ("busy", "h1", "h4", {"racing": True}),
                        ("busy", "h1", "h4", {"ridingHorse": "h4"}), ("busy", "h1", "h4", {"trainingRide": True}),
                        ("busy", "h1", "h4", {"ridingHorse": "h9"})]),
        ("full", {"extra": 14}, [("block", "h1", "h2")]),
        ("almost", {"extra": 13}, [("confirm", "h1", "h2", day0, [0.5] * 5), ("block", "h1", "h4")]),
    ]
    out = []
    for name, kw, steps in scripts:
        p = _profile(**kw)
        log = []
        for step in steps:
            kind = step[0]
            if kind == "confirm":
                ok, msg, pend = br.confirm(p, step[1], step[2], step[3], ListRng(step[4]), None, ON)
                log.append({"ok": ok, "msg": msg, "pending": pend, "cash": p["cash"],
                            "restA": br.rest_left(p, step[1]), "restB": br.next_foal_in(p)})
            elif kind == "ready":
                pend = p.get("breeding", {}).get("pending", [])
                log.append({"ready": br.ready(pend[0], br.owner_races(p), step[1], ON) if pend else False})
            elif kind == "races":
                p["totals"]["races"] += step[1]
                log.append({"races": p["totals"]["races"]})
            elif kind == "cash":
                p["cash"] += step[1]
                log.append({"cash": p["cash"]})
            elif kind == "arrive":
                log.append({"horse": br.arrive(p, "foal1", "Little Star", step[1], ON)})
            elif kind == "block":
                log.append({"why": br.pair_block(p, step[1], step[2], None, ON),
                            "a": br.horse_block(p, br.find(p, step[1]), None, ON)})
            elif kind == "busy":
                log.append({"why": br.pair_block(p, step[1], step[2], step[3], ON)})
        out.append({"name": name, "kw": kw, "steps": [list(s) for s in steps], "log": log})
    return out


def parity_table() -> dict:
    out = {"cfgs": CFGS, "pots": [], "coats": [], "fees": [], "sell": [], "scale": [], "scenarios": scenarios(),
           "profile": {"pots": POTS, "day0": None}}
    for name, cfg in CFGS.items():
        for i, (pa, pb) in enumerate(POTS):
            for la_, lb_ in ((False, False), (True, False), (False, True), (True, True)):
                for us in UNIFORMS:
                    pot = br.foal_potential(pa, pb, la_, lb_, ListRng(us), cfg)
                    out["pots"].append({"cfg": name, "pair": i, "legendA": la_, "legendB": lb_, "u": us, "pot": pot,
                                        "start": br.start_stats(pot, cfg), "family": br.family_level(pot, cfg),
                                        "expected": br.expected_potential(pa, pb, la_, lb_, cfg),
                                        "legacy": br.legacy(pa, pb, la_, lb_)})
        for a in br.COATS if name == "live" else br.COATS[:4] + br.COATS[-2:]:
            for b in br.COATS:
                t = br.coat_chances(a, b, cfg)
                out["coats"].append({"cfg": name, "a": a, "b": b, "table": t,
                                     "rolls": [br.roll_coat(t["chances"], u) for u in COAT_US]})
    for a in br.LEAGUES + ("Nowhere",):
        for b in br.LEAGUES:
            out["fees"].append({"a": a, "b": b, "fee": br.fee(a, b)})
    for paid in (0, 399, 400, 800, 1500, 2500, 2501):
        for wins, cups in ((0, 0), (3, 0), (10, 1), (100, 4)):
            out["sell"].append({"paid": paid, "wins": wins, "cups": cups, "value": br.sell_value(paid, wins, cups)})
    for r in (-3, 0, 1, 15, 29, 30, 500):
        out["scale"].append({"races": r, "scale": br.young_scale(r)})
    out["us"] = COAT_US
    return out


# --- Parity and config -------------------------------------------------------------------------

def test_parity_fixture_is_current():
    assert json.loads(FIXTURE.read_text(encoding="utf-8")) == json.loads(json.dumps(parity_table()))


def _luau_breeding() -> str:
    text = GAME_CONFIG.read_text(encoding="utf-8")
    start = text.index("GameConfig.breeding = {")
    depth, i = 0, text.index("{", start)
    for j in range(i, len(text)):
        depth += {"{": 1, "}": -1}.get(text[j], 0)
        if depth == 0:
            return text[i:j + 1]
    raise AssertionError("unclosed GameConfig.breeding")


def test_game_config_mirrors_python():
    body = _luau_breeding()
    flat = re.sub(r"\w+\s*=\s*\{[^{}]*\}", "", body[1:-1])
    flat = re.sub(r"surprise\s*=\s*\{.*\}", "", flat, flags=re.S)
    flat = re.sub(r"--[^\n]*", "", flat)
    got = dict(re.findall(r"(\w+)\s*=\s*([^,\n]+)", flat))
    for k, v in br.BREEDING.items():
        if isinstance(v, (dict, tuple)):
            continue
        raw = got.pop(k).strip()
        if k == "enabled":  # the game's on/off switch (D-080: on with career.suggest), not part of the math
            assert raw in ("true", "false"), k
            continue
        if isinstance(v, bool):
            assert raw == str(v).lower(), k
        elif isinstance(v, str):
            assert raw == f'"{v}"', k
        else:
            assert float(raw) == float(v), k
    assert not got, f"keys only in Luau: {got}"
    fee = dict(re.findall(r"(\w+)\s*=\s*(\d+)", re.search(r"fee\s*=\s*\{([^}]*)\}", body).group(1)))
    assert {k: int(v) for k, v in fee.items()} == br.BREEDING["fee"]
    levels = re.search(r"familyLevels\s*=\s*\{([^}]*)\}", body).group(1)
    assert tuple(int(x) for x in levels.split(",")) == br.BREEDING["familyLevels"]
    sur = re.search(r"surprise\s*=\s*\{(.*)\}", body, re.S).group(1)
    luau_sur = {k: tuple(re.findall(r'"(\w+)"', v)) for k, v in re.findall(r"(\w+)\s*=\s*\{([^}]*)\}", sur)}
    assert luau_sur == br.BREEDING["surprise"]
    text = GAME_CONFIG.read_text(encoding="utf-8")
    assert int(re.search(r"legacyMax\s*=\s*(\d+)", text).group(1)) == br.CAREER_LEGACY_MAX
    assert int(re.search(r"MAX_HORSES\s*=\s*(\d+)", MARKET.read_text(encoding="utf-8")).group(1)) == br.BREEDING["stableCap"]
    coats = re.search(r"Horse\.COATS\s*=\s*\{([^}]*)\}", HORSE.read_text(encoding="utf-8")).group(1)
    assert tuple(re.findall(r'"(\w+)"', coats)) == br.COATS


# --- Model properties --------------------------------------------------------------------------

def test_potential_formula_and_bounds():
    rng = random.Random(7)
    for _ in range(3000):
        pa = {k: rng.randint(40, 100) for k in br.STATS}
        pb = {k: rng.randint(40, 100) for k in br.STATS}
        la_, lb_ = rng.random() < 0.3, rng.random() < 0.3
        pot = br.foal_potential(pa, pb, la_, lb_, rng)
        bonus = br.legacy(pa, pb, la_, lb_)
        for k in br.STATS:
            mid = ON["parentShare"] * (pa[k] + pb[k]) / 2 + (1 - ON["parentShare"]) * ON["breedAnchor"]
            assert 55 <= pot[k] <= 100
            assert ON["parentShare"] == 0.75 and ON["breedAnchor"] == 80.5
            lo = max(55, min(100, int(mid - 5 + 0.5) - 1 + bonus[k]))
            hi = min(100, max(55, int(mid + 5 + 0.5) + bonus[k]))
            assert lo <= pot[k] <= hi
        assert sum(bonus.values()) <= 2 * br.CAREER_LEGACY_MAX
        assert max(bonus.values()) <= br.CAREER_LEGACY_MAX


def test_two_legends_same_best_stat_never_stack():
    p = {"speed": 95, "accel": 80, "stamina": 80, "grit": 80}
    assert br.legacy(p, p, True, True) == {"speed": 2, "accel": 0, "stamina": 0, "grit": 0}
    q = {"speed": 80, "accel": 80, "stamina": 96, "grit": 80}
    assert br.legacy(p, q, True, True) == {"speed": 2, "accel": 0, "stamina": 2, "grit": 0}
    assert br.legacy(p, q, False, False) == {k: 0 for k in br.STATS}


def test_noise_and_rounding_are_deterministic():
    a = br.foal_potential(POTS[0][0], POTS[0][1], False, False, random.Random(3))
    b = br.foal_potential(POTS[0][0], POTS[0][1], False, False, random.Random(3))
    assert a == b
    # u = 0.5 is no noise: equals the expected Potential
    assert br.foal_potential(POTS[4][0], POTS[4][1], True, False, ListRng([0.5] * 4)) == \
        br.expected_potential(POTS[4][0], POTS[4][1], True, False)


def test_start_stats_share_and_cap():
    assert br.start_stats({"speed": 75, "accel": 90, "stamina": 55, "grit": 100}) == \
        {"speed": 45, "accel": 50, "stamina": 33, "grit": 50}
    for p in range(55, 101):
        s = br.start_stats({k: p for k in br.STATS})["speed"]
        assert s <= 50 and s == min(50, int(0.6 * p + 0.5))


@pytest.mark.parametrize("a", br.COATS)
@pytest.mark.parametrize("b", br.COATS)
def test_coat_chances_sum_to_one_and_are_shown(a, b):
    t = br.coat_chances(a, b)
    assert abs(sum(t["chances"].values()) - 1) < 1e-12
    assert all(v > 0 for v in t["chances"].values())
    shown = sum(c for _, c in t["parents"]) + t["surprise"]["chance"]
    assert abs(shown - 1) < 1e-12
    assert set(t["chances"]) == {a, b} | set(t["surprise"]["coats"])
    if t["surprise"]["coats"]:
        assert abs(t["surprise"]["chance"] - 0.10) < 1e-12
    # every coat breeding can give is also a Market or wild coat (no breeding-only coat)
    market = {"bay", "chestnut", "grey", "black", "palomino", "chestnut_blaze", "pinto", "dun", "roan"}
    wild = {"pinto", "appaloosa", "buckskin", "dun", "roan", "white"}
    assert set(t["surprise"]["coats"]) <= market | wild


def test_plan_examples():
    t = br.coat_chances("bay", "chestnut")
    assert t["parents"] == [["bay", 0.45], ["chestnut", 0.45]]
    assert t["surprise"]["coats"] == ["buckskin", "dun"]
    assert br.coat_chances("bay", "bay")["parents"] == [["bay", 0.9]]
    assert br.coat_chances("grey", "grey")["surprise"]["coats"] == ["roan", "white"]
    # wild coats (systems ruling 4); a parent's own coat is never the Surprise
    assert br.coat_chances("buckskin", "buckskin")["surprise"]["coats"] == ["palomino", "dun"]
    assert br.coat_chances("dun", "buckskin")["surprise"]["coats"] == ["palomino"]
    assert br.coat_chances("roan", "white")["surprise"]["coats"] == ["grey"]
    assert br.coat_chances("grey", "white")["surprise"]["coats"] == ["roan"]
    # no option left: the 10% goes back to the parents
    t = br.coat_chances("pinto", "appaloosa")
    assert t["chances"] == {"pinto": 0.5, "appaloosa": 0.5} and t["surprise"]["chance"] == 0
    t = br.coat_chances("dun", "white", {**ON, "surprise": {}})
    assert t["chances"] == {"dun": 0.5, "white": 0.5}


def test_coat_roll_frequencies_match_the_card():
    rng = random.Random(11)
    t = br.coat_chances("palomino", "grey")["chances"]
    n = 40000
    seen = {}
    for _ in range(n):
        c = br.roll_coat(t, rng.random())
        seen[c] = seen.get(c, 0) + 1
    for c, p in t.items():
        sd = (p * (1 - p) / n) ** 0.5
        assert abs(seen.get(c, 0) / n - p) < 4 * sd + 1e-9, c


def test_fee_by_higher_league_and_never_profitable():
    assert br.fee("Rookie", "Rookie") is None
    assert br.fee("Rookie", "Bronze") == 400
    assert br.fee("Gold", "Silver") == 1500
    assert br.fee("Champion", "Rookie") == 2500
    for price in br.BREEDING["fee"].values():
        for wins in (0, 10, 100, 10000):
            for cups in (0, 1, 4, 100):
                assert br.sell_value(price, wins, cups) < price
    assert la.SELL["recordBonusCap"] < min(br.BREEDING["fee"].values()) * (1 - la.SELL["share"])


def test_eligibility_and_rest_counted_in_owner_races():
    p = _profile()
    assert br.pair_block(p, "h1", "h2", None, br.BREEDING) == "The Foaling Barn is closed today"
    assert br.pair_block(p, "h1", "h2", None, ON) is None
    assert br.horse_block(p, br.find(p, "h3"), None, ON) == "Needs 30 races"
    assert br.horse_block(p, br.find(p, "h5"), None, ON) == "Lent"
    assert br.pair_block(p, "h2", "h6", None, ON) == "One parent needs Bronze"
    assert br.pair_block(p, "h4", "h6", None, ON) is None  # a Legend counts by its plaque league
    ok, _, pend = br.confirm(p, "h1", "h2", 0, ListRng([0.5] * 5), None, ON)
    assert ok and p["cash"] == 600 and pend["fee"] == 400
    assert br.pair_block(p, "h4", "h6", None, ON) == "A foal is on the way!"
    every = ON["foalEveryRaces"]
    assert br.next_foal_in(p) == every == br.rest_left(p, "h6")
    p["totals"]["races"] += 8
    assert br.arrive(p, "f", "F", 0, ON)["origin"] == "bred"
    assert br.horse_block(p, br.find(p, "h1"), None, ON) is None  # no per-horse rest any more
    assert br.pair_block(p, "h1", "h2", None, ON) == f"Next foal in {every - 8} races"
    p["totals"]["races"] += every - 9
    assert br.pair_block(p, "h4", "h6", None, ON) == "Next foal in 1 race"
    p["totals"]["races"] += 1
    assert br.pair_block(p, "h1", "h2", None, ON) is None


def test_a_second_pair_waits_for_the_stable():
    """Systems ruling 2: the wait is per stable, so rotating to other parents gains nothing."""
    every = ON["foalEveryRaces"]
    p = _profile(cash=10000)
    assert br.confirm(p, "h1", "h2", 0, ListRng([0.5] * 5), None, ON)[0]
    p["totals"]["races"] += 8
    assert br.arrive(p, "f1", "F", 0, ON) is not None
    for extra in range(8, every):
        ok, why, _ = br.confirm(p, "h4", "h6", 0, ListRng([0.5] * 5), None, ON)
        assert not ok and why.startswith("Next foal in"), extra
        p["totals"]["races"] += 1
    assert br.confirm(p, "h4", "h6", 0, ListRng([0.5] * 5), None, ON)[0]


def test_roll_once_at_confirm():
    p = _profile()
    ok, _, pend = br.confirm(p, "h1", "h2", 0, ListRng([0.1, 0.2, 0.3, 0.4, 0.95]), None, ON)
    assert ok
    stored = json.loads(json.dumps(pend))
    # a second confirm can't roll again while the foal is on the way
    ok2, why, _ = br.confirm(p, "h1", "h2", 0, ListRng([0.9] * 5), None, ON)
    assert not ok2 and why == "A foal is on the way!"
    p["totals"]["races"] += 100
    h = br.arrive(p, "f", "F", 0, ON)
    assert h["potential"] == stored["potential"] and h["coat"] == stored["coat"] and h["stats"] == stored["stats"]
    assert h["paid"] == 400 and h["parents"] == ["h1", "h2"] and h["league"] == "Rookie" and h["bond"] == 10


def test_arrival_after_races_or_next_day():
    pend = {"atRaces": 108, "day": 5}
    assert not br.ready(pend, 107, 5 * 86400 + 86399, ON)
    assert br.ready(pend, 108, 5 * 86400, ON)
    assert br.ready(pend, 100, 6 * 86400, ON)
    assert not br.ready(pend, 100, 6 * 86400, {**ON, "foalAfterNewDay": False})


def test_room_counts_the_foal_on_the_way():
    assert br.pair_block(_profile(extra=14), "h1", "h2", None, ON) == "Make room first"
    assert br.pair_block(_profile(extra=13), "h1", "h2", None, ON) is None


def test_young_scale():
    assert br.young_scale(0) == 0.8 and br.young_scale(30) == 1.0 and abs(br.young_scale(15) - 0.9) < 1e-12


# --- Sim gates (small samples; the full run is `python sims/breeding.py --all`) ------------------

def _sim():
    import importlib.util
    spec = importlib.util.spec_from_file_location("breeding_sim", ROOT / "sims" / "breeding.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def test_sim_bloodlines_level_off_and_spread():
    sim = _sim()
    for name, value, passed in sim.gate_bloodline(sim.bloodline_report(60, 3)) + sim.gate_spread(sim.spread_report(8000, 3)):
        assert passed is not False, f"{name}: {value}"


def test_sim_no_profit_rows():
    sim = _sim()
    assert all(row[-1] for row in sim.profit_report())


if __name__ == "__main__":
    if "--write" in sys.argv:
        FIXTURE.write_text(json.dumps(parity_table(), separators=(",", ":")) + "\n", encoding="utf-8", newline="\n")
        print(f"wrote {FIXTURE}")
