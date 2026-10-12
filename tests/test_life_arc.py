"""The life arc reference (src/life_arc.py): ageing, selling, the vet run, its Luau mirror and the
sims' gates. Regenerate the parity table with `python tests/test_life_arc.py --write`."""

import json
import random
import re
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))
sys.path.insert(0, str(ROOT / "sims"))

import life_arc as la  # noqa: E402

FIXTURE = ROOT / "tests" / "fixtures" / "ageing.json"
GAME_CONFIG = ROOT / "game" / "src" / "shared" / "GameConfig.luau"
RACES = [-5, 0, 1, 9.7, 29, 30, 31, 339, 340, 349, 350, 351, 389, 390, 399, 400, 401, 449, 450, 499, 500,
         539, 540, 549, 550, 551, 600, 1000, 1e12]
CFGS = {
    "live": la.AGEING,
    "on": {**la.AGEING, "declineScale": 1},
    "half": {**la.AGEING, "declineScale": 0.5},
    "systems": {**la.AGEING, "declineScale": 1, "declinePer": 25, "declineCap": 6, "veteranAt": 300},
}


FROMS = [None, 350, 420, 600]
PEAKS = [
    ({"speed": 45, "accel": 45, "stamina": 45, "grit": 45}, {"speed": 80, "accel": 75, "stamina": 70, "grit": 85}),
    ({"speed": 72, "accel": 68, "stamina": 63, "grit": 77}, {"speed": 80, "accel": 75, "stamina": 70, "grit": 85}),
    ({"speed": 71.9, "accel": 67.5, "stamina": 63, "grit": 76.5}, {"speed": 80, "accel": 75, "stamina": 70, "grit": 85}),
    ({"speed": 90, "accel": 10, "stamina": 70, "grit": 85}, {"speed": 80, "accel": 75, "stamina": 70, "grit": 85}),
    ({"speed": 50, "accel": 50, "stamina": 50, "grit": 50}, {"speed": 0, "accel": 55, "stamina": 55, "grit": 55}),
]


def parity_table() -> dict:
    out = {}
    for name, cfg in CFGS.items():
        rows = []
        for r in RACES:
            for f in FROMS:
                rows.append({
                    "races": r, "from": f, "stage": la.stage(r, False, cfg), "steps": la.decline_steps(r, f, cfg),
                    "offset": la.rating_offset(r, f, cfg), "raced": la.raced_rating(61.5, r, f, False, cfg),
                    "practice": la.raced_rating(61.5, r, f, True, cfg), "next": la.races_to_next_step(r, f, cfg),
                    "warn": la.decline_warning(r, f, cfg), "vetSoon": la.veteran_soon(r, cfg), "train": la.train_mult(r, cfg),
                })
        peaks = []
        for stats, pot in PEAKS:
            for r in (349, 350, 400):
                for f in (None, 360):
                    peaks.append({"stats": stats, "pot": pot, "races": r, "from": f, "share": la.peak_share(stats, pot),
                                  "atPeak": la.at_peak(stats, pot, cfg),
                                  "update": la.update_decline_from(f, r, stats, pot, cfg)})
        out[name] = {"cfg": cfg, "rows": rows, "peaks": peaks}
    return out


def _luau_table(name: str) -> dict:
    text = GAME_CONFIG.read_text(encoding="utf-8")
    body = re.search(rf"GameConfig\.{name}\s*=\s*\{{([^}}]*)\}}", text).group(1)
    return {k: float(v) for k, v in re.findall(r"(\w+)\s*=\s*([0-9.]+)", body)}


def test_parity_fixture_is_current():
    assert json.loads(FIXTURE.read_text(encoding="utf-8")) == json.loads(json.dumps(parity_table()))


def test_game_config_mirrors_python():
    assert _luau_table("ageing") == {k: float(v) for k, v in la.AGEING.items()}
    sell = _luau_table("sell")
    assert sell == {k: float(la.SELL[k]) for k in ("perWin", "perCup", "recordBonusCap")}
    # one "Veteran": the career label and the ageing stage start together (ruling 3)
    assert _luau_table("career")["veteranAt"] == la.AGEING["veteranAt"] == 350
    energy = GAME_CONFIG.read_text(encoding="utf-8")
    cool = re.search(r"careCooldownSeconds\s*=\s*(\d+)\s*\*\s*(\d+)\s*\*\s*(\d+)", energy)
    assert int(cool.group(1)) * int(cool.group(2)) * int(cool.group(3)) == la.LEGS["careCooldownSeconds"]
    assert float(re.search(r"GameConfig\.rehome\s*=\s*\{[^}]*share\s*=\s*([0-9.]+)",
                           GAME_CONFIG.read_text(encoding="utf-8")).group(1)) == la.SELL["share"]


def test_game_config_legs_mirrors_python():
    """GameConfig.legs (phase 3, D-077) carries life_arc.LEGS, and its care cooldown is Energy's."""
    legs = _luau_table("legs")
    assert {k: legs[k] for k in la.LEGS} == {k: float(v) for k, v in la.LEGS.items()}
    assert legs["wrapRaces"] == 3


def test_consensus_numbers():
    c = la.AGEING
    assert (c["veteranAt"], c["declinePer"], c["declineCap"], c["youngRaces"], c["youngTrainMult"], c["warnAhead"]) \
        == (350, 50, 4, 30, 1.25, 10)
    assert c["peakShare"] == 0.90
    assert c["declineScale"] in (0, 1)
    assert (la.LEGS["runLimit"], la.LEGS["warnAt"], la.LEGS["careLowers"], la.LEGS["fromRaces"]) == (6, 5, 2, 26)
    assert la.LEGS["restSeconds"] == 1800


@pytest.mark.parametrize("cfg", list(CFGS.values()))
def test_no_change_before_veteran_or_peak_and_never_in_practice(cfg):
    for f in FROMS:
        for r in range(0, cfg["veteranAt"] + cfg["declinePer"]):
            assert la.rating_offset(r, f, cfg) == 0
        for r in range(0, 2000, 7):
            assert la.raced_rating(70.0, r, f, True, cfg) == 70.0
    # not at its peak yet: no decline at any age
    assert all(la.rating_offset(r, None, cfg) == 0 for r in range(0, 5000, 13))


def test_decline_from_waits_for_both_and_never_unsets():
    young, peak = PEAKS[0], PEAKS[1]
    assert la.update_decline_from(None, 349, *peak) is None
    assert la.update_decline_from(None, 360, *young) is None
    assert la.update_decline_from(None, 360, *peak) == 360
    assert la.update_decline_from(360, 900, *young) == 360  # stored: never un-set
    assert la.at_peak(*peak) and not la.at_peak(*PEAKS[2]) and la.peak_share(*PEAKS[3]) <= 1


@pytest.mark.parametrize("cfg", list(CFGS.values()))
@pytest.mark.parametrize("start", [350, 420, 777])
def test_decline_is_monotone_capped_and_warned(cfg, start):
    start = max(start, cfg["veteranAt"])
    prev = 0.0
    for r in range(0, 2000):
        off = la.rating_offset(r, start, cfg)
        assert off <= prev + 1e-12
        assert off >= -cfg["declineScale"] * cfg["declineCap"] - 1e-12
        prev = off
    if cfg["declineScale"] > 0:
        for k in range(1, cfg["declineCap"] + 1):
            step = start + k * cfg["declinePer"]
            assert la.rating_offset(step, start, cfg) < la.rating_offset(step - 1, start, cfg)
            assert all(la.decline_warning(r, start, cfg) for r in range(step - cfg["warnAhead"], step))
        assert la.races_to_next_step(10_000, start, cfg) is None
    else:
        assert not any(la.decline_warning(r, start, cfg) for r in range(0, 2000))


def test_stages_and_young_training():
    assert [la.stage(r) for r in (0, 29, 30, 349, 350, 900)] == ["Young", "Young", "Prime", "Prime", "Veteran", "Veteran"]
    assert la.stage(5, legend=True) == "Legend"
    assert la.train_mult(29) == 1.25 and la.train_mult(30) == 1.0
    assert la.veteran_soon(340) and la.veteran_soon(349) and not la.veteran_soon(339) and not la.veteran_soon(350)


def test_race_rating_decline_lowers_chance_but_keeps_the_invariants():
    import gavel_race_v2 as m
    cfg = m.Config(T=12)
    on = {**la.AGEING, "declineScale": 1}
    ratings = [80.0] + [56.0 + i for i in range(-3, 4)]
    aged = [la.raced_rating(ratings[0], 600, 350, False, on)] + ratings[1:]
    q, qa = m.base_chances(ratings, cfg), m.base_chances(aged, cfg)
    assert abs(sum(qa) - 1) < 1e-12 and min(qa) > 0
    assert qa[0] < q[0] and all(a >= b for a, b in zip(qa[1:], q[1:]))


def test_sell_value():
    assert la.sell_value(400, 0, 0) == 200
    assert la.sell_value(400, 30, 2) == 200 + la.SELL["recordBonusCap"]
    # the cheapest Market horse costs 250 (Market.price), so the cap must stay under 125
    assert la.SELL["recordBonusCap"] < 250 * (1 - la.SELL["share"])
    cap = {**la.SELL, "recordBonusCap": 60}
    assert la.sell_value(400, 3, 0, "market", cap) == 215
    assert la.sell_value(400, 30, 2, "market", cap) == 260
    assert la.sell_value(401, 0, 0, "market", cap) == 200
    assert la.sell_value(400, 30, 2, "tamed", cap) == 0 and la.sell_value(400, 30, 2, "starter", cap) == 0
    # the sale never pays back more than the price while the cap stays under half the cheapest price
    assert all(la.sell_value(p, 99, 9, "market", {**la.SELL, "recordBonusCap": la.SELL["recordBonusCap"]}) < p
               for p in range(250, 5000, 10))


def test_vet_run():
    run = 0
    for races in range(1, 27):
        run = la.run_after_race(run, races)
    assert run == 0  # never in a horse's first 26 races (the Rookie phase)
    for races in range(27, 33):
        assert not la.needs_vet(run)
        run = la.run_after_race(run, races)
    assert run == 6 and la.needs_vet(run) and not la.legs_warning(run)
    assert la.legs_warning(5) and not la.legs_warning(4)
    cool = la.LEGS["careCooldownSeconds"]
    assert la.run_after_care(5, -1e9, 0) == (3, True) and la.run_after_care(1, -1e9, 0) == (0, True)
    # once per kind per cooldown: a second groom inside 2 h doesn't count (no spamming past the vet)
    assert la.run_after_care(5, 0, cool - 1) == (5, False) and la.run_after_care(5, 0, cool) == (3, True)
    assert la.run_now(5, 0, 1799) == 5 and la.run_now(5, 0, 1800) == 0


def test_sims_smoke():
    import lifearc
    rep = lifearc.ageing_summary(lifearc.ageing_runs("keen", "decline", 2, 3, races=420))
    young = lifearc.ageing_summary(lifearc.ageing_runs("keen", "young", 2, 3, races=420))
    assert rep["arrive"]["Champion"][0] is not None
    # the decline never moves a league arrival before veteranAt (paired streams)
    for lg, (played, _, _) in rep["arrive"].items():
        y = young["arrive"][lg][0]
        if y is not None and y < la.AGEING["veteranAt"]:
            assert played == y
    legs = lifearc.legs_report("keen", 3, 1, weeks=2)
    assert legs["races"] > 0 and legs["per_hour"] > 0
    stats, pot, price = lifearc.market_listing(random.Random(1))
    assert price >= 250 and all(pot[k] >= stats[k] + 5 for k in stats)


if __name__ == "__main__" and "--write" in sys.argv:
    FIXTURE.write_text(json.dumps(parity_table(), indent=1) + "\n", encoding="utf-8")
    print(f"wrote {FIXTURE}")
