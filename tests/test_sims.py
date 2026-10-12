"""Smoke test: the economy simulator runs and promotes players."""

import random
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "sims"))
import economy  # noqa: E402


def test_engaged_player_reaches_silver_quickly_with_d013_thresholds():
    th = {"Rookie": 100, "Bronze": 110, "Silver": 1400, "Gold": 3000}
    rng = random.Random(3)
    days = []
    for _ in range(30):
        reached, _ = economy.simulate_player(rng, 25, 55, th, 10)
        days.append(reached.get("Silver", 99))
    days.sort()
    assert days[len(days) // 2] < 6


GAME_CONFIG = Path(__file__).resolve().parents[1] / "game" / "src" / "shared" / "GameConfig.luau"


def _luau_anchors():
    text = GAME_CONFIG.read_text(encoding="utf-8")
    body = re.search(r"GameConfig\.botRatingAnchor\s*=\s*\{([^}]*)\}", text).group(1)
    spread = float(re.search(r"GameConfig\.botRatingSpread\s*=\s*([0-9.]+)", text).group(1))
    return {k: float(v) for k, v in re.findall(r"(\w+)\s*=\s*([0-9.]+)", body)}, spread


def test_bot_anchors_match_game_config():
    """GameConfig holds the D-061 anchors (economy.BOT_RATING_ANCHOR) or the D-068 ones."""
    anchors, spread = _luau_anchors()
    assert anchors in ({k: float(v) for k, v in economy.BOT_RATING_ANCHOR.items()},
                       {k: float(v) for k, v in economy.PHASE3["anchors"].items()})
    assert spread == economy.BOT_RATING_SPREAD == 6


def test_solo_rookie_win_rate_in_band():
    """D-061 gate: a fresh starter ridden by an average kid wins 20-35% of solo Rookie races."""
    lo, hi = economy.SOLO_BAND
    rate = economy.solo_win_rate("Rookie", economy.FRESH_RATING, "average", races=4000, seed=5)
    assert lo <= rate <= hi
    for kid in ("new", "skilled"):  # new and skilled kids stay in the band too
        assert lo <= economy.solo_win_rate("Rookie", economy.FRESH_RATING, kid, races=4000, seed=6) <= hi


def test_debate_anchors_failed_the_gate():
    """The debate's anchors (Rookie 50) are why the anchors were tuned: under 20% solo."""
    debate = {"Rookie": 50, "Bronze": 63, "Silver": 73, "Gold": 83, "Champion": 90}
    rate = economy.solo_win_rate("Rookie", economy.FRESH_RATING, "average", races=4000, seed=5, anchors=debate)
    assert rate < economy.SOLO_BAND[0]


def test_training_shows_in_solo_races():
    """A horse trained to its league's ceiling wins noticeably more than one just entering it."""
    for league in economy.LEAGUES:
        entry = economy.solo_win_rate(league, economy.LEAGUE_ENTRY[league], "average", races=3000, seed=7)
        top = economy.solo_win_rate(league, economy.LEAGUE_TOP[league], "average", races=3000, seed=7)
        assert economy.SOLO_BAND[0] <= entry <= economy.SOLO_BAND[1], league
        assert top - entry >= 0.08, league


def _luau_stakes():
    text = GAME_CONFIG.read_text(encoding="utf-8")
    body = re.search(r"GameConfig\.stakesUnlockPoints\s*=\s*\{([^}]*)\}", text).group(1)
    bonus = int(re.search(r"GameConfig\.firstWinBonus\s*=\s*(\d+)", text).group(1))
    return {k: int(v) for k, v in re.findall(r"(\w+)\s*=\s*(\d+)", body)}, bonus


def test_first_win_bonus_matches_game_config():
    _, bonus = _luau_stakes()
    assert bonus == economy.FIRST_WIN_BONUS == 10


D062_SILVER = 750  # the D-062 Silver threshold, on D-062's premise (Silver-entry horse 68, D-061 bots)


def test_silver_cup_casual_in_target_band():
    """D-062 stage 8 (history): with 750 points, a casual player (new kid, Silver-entry horse 68,
    D-061 bots, +10 first win) opens the Silver Cup in 150-200 Silver races. D-068 replaced the
    premise (no horse enters Silver at 68 under the training cap); see the ladder tests below."""
    kid, rating = economy.SILVER_COHORTS["casual"]
    n = economy.races_to_cup(D062_SILVER, "Silver", rating, kid, players=80, seed=11)
    lo, hi = economy.SILVER_TARGET
    assert lo <= n <= hi, n


def test_silver_cup_better_riders_and_horses_get_there_sooner():
    casual_kid, casual_rating = economy.SILVER_COHORTS["casual"]
    casual = economy.races_to_cup(D062_SILVER, "Silver", casual_rating, casual_kid, players=40, seed=12)
    regular_kid, regular_rating = economy.SILVER_COHORTS["regular"]
    regular = economy.races_to_cup(D062_SILVER, "Silver", regular_rating, regular_kid, players=40, seed=12)
    assert regular < casual
    assert regular >= 100  # the Cup is still a goal, not a formality


def test_old_silver_threshold_missed_the_band():
    """D-013's 1,400 points took a casual player far past 200 Silver races; 600 lands under 150."""
    kid, rating = economy.SILVER_COHORTS["casual"]
    assert economy.races_to_cup(1400, "Silver", rating, kid, players=30, seed=13) > economy.SILVER_TARGET[1]
    assert economy.races_to_cup(600, "Silver", rating, kid, players=60, seed=13) < economy.SILVER_TARGET[0]


# --- Realistic-Rating ladder (AAA Phase 3, D-068) --------------------------------------------
# These run against economy.PHASE3. The test_live_config_* tests read the live GameConfig.luau,
# which carries the PHASE3 values since AAA Phase 3 (they were strict xfails until then).

from functools import lru_cache  # noqa: E402

import pytest  # noqa: E402

TRAINING = GAME_CONFIG.parent / "Training.luau"


def _luau_table(name: str) -> dict:
    text = GAME_CONFIG.read_text(encoding="utf-8")
    body = re.search(rf"GameConfig\.{name}\s*=\s*\{{([^}}]*)\}}", text).group(1)
    return {k: float(v) for k, v in re.findall(r"(\w+)\s*=\s*([0-9.]+)", body)}


def _live_ladder() -> dict:
    return {"anchors": _luau_table("botRatingAnchor"), "stakes": _luau_table("stakesUnlockPoints"),
            "ceilings": _luau_table("leagueCeiling")}


def _as_float(params: dict) -> dict:
    return {k: {lg: float(v) for lg, v in d.items()} for k, d in params.items()}


@lru_cache(maxsize=None)
def _ladder(profile: str, which: str = "phase3", players: int = 120) -> dict:
    params = _live_ladder() if which == "live" else {"phase3": economy.PHASE3, "current": economy.CURRENT}[which]
    return economy.ladder_report(economy.PROFILES[profile], params, players=players, seed=21, max_weeks=40)


def test_ladder_mirrors_match_game_code():
    text = TRAINING.read_text(encoding="utf-8")
    assert float(re.search(r"Training\.WEEKLY_CAP\s*=\s*([0-9.]+)", text).group(1)) == economy.WEEKLY_CAP
    assert float(re.search(r"Training\.K\s*=\s*([0-9.]+)", text).group(1)) == economy.TRAIN_K
    assert float(re.search(r"Training\.RESTED_BONUS\s*=\s*([0-9.]+)", text).group(1)) == economy.RESTED_BONUS
    cfg = GAME_CONFIG.read_text(encoding="utf-8")
    assert int(re.search(r"GameConfig\.cupPurseB\s*=\s*(\d+)", cfg).group(1)) == economy.CUP_PURSE_B
    for lg in economy.LEAGUES:  # purses and T unchanged by D-068
        row = re.search(rf'\b{lg} = \{{ name = "{lg}", T = ([0-9.]+), B = (\d+)', cfg)
        assert float(row.group(1)) == economy.T[lg] and int(row.group(2)) == economy.LEAGUE_B[lg], lg


def test_game_config_is_one_whole_ladder():
    """Anchors, Cup points and ceilings move together: GameConfig holds all the D-061/D-062 values
    or all the D-068 values, never half of each."""
    live = _live_ladder()
    assert live in (_as_float(economy.CURRENT), _as_float(economy.PHASE3)), live


def test_current_ladder_has_the_silver_cliff():
    """The systems review's finding, reproduced: on realistic Ratings the pre-D-068 ladder takes a
    casual kid about 230 Silver races and about 800 Gold races, and over 30 weeks to Champion."""
    rep = economy.ladder_report(economy.PROFILES["casual"], economy.CURRENT, players=40, seed=21,
                                max_weeks=40, stop_at="Gold")
    assert rep["Silver"]["unlock"] > 180
    rep = economy.ladder_report(economy.PROFILES["casual"], economy.CURRENT, players=40, seed=21, max_weeks=30)
    assert rep["Champion"]["week"] is None  # not reached within 30 weeks


@pytest.mark.parametrize("league", list(economy.LADDER_TARGET))
def test_phase3_casual_races_to_cup(league):
    """D-068: a casual kid (3 sessions of 10 races a week, new-kid riding, training inside the
    weekly cap) opens each Cup in about 20 / 40 / 90 / 180 counted races."""
    n = _ladder("casual")[league]["unlock"]
    target = economy.LADDER_TARGET[league]
    assert abs(n - target) <= economy.LADDER_TOLERANCE * target, (league, n)


def test_phase3_no_cliff_and_champion_reachable():
    rep = _ladder("casual")
    steps = [rep[lg]["unlock"] for lg in economy.LADDER_TARGET]
    assert all(b / a <= 2.6 for a, b in zip(steps, steps[1:])), steps  # each league about twice the last
    assert rep["Champion"]["reached"] == 1.0 and rep["Champion"]["week"] <= 16  # no Diamonds anywhere
    eng = _ladder("engaged")
    assert eng["Gold"]["week"] <= 3.5      # GAME_DESIGN: Gold in about 3 weeks
    assert eng["Bronze"]["played"] <= 36   # Bronze in about 3 hours (12 races an hour)


@pytest.mark.parametrize("league", ["Bronze", "Silver", "Gold", "Champion"])
def test_phase3_entry_win_rate(league):
    """A casual horse entering any league: an average kid wins 20-30% of solo races, a new kid at
    least 17% (Gold enters lowest, by design: about six weeks of training happen there)."""
    rating = economy.entry_ratings(economy.PROFILES["casual"], economy.PHASE3, league, players=60, seed=4)
    anchors = economy.PHASE3["anchors"]
    avg = economy.solo_win_rate(league, rating, "average", 3000, 9, anchors)
    new = economy.solo_win_rate(league, rating, "new", 3000, 9, anchors)
    lo, hi = economy.ENTRY_BAND
    assert lo <= avg <= hi, (league, rating, avg)
    assert new >= 0.17, (league, rating, new)


@pytest.mark.parametrize("league", list(economy.PHASE3["ceilings"]))
def test_phase3_ceiling_win_rate(league):
    """At its league's ceiling an average kid wins about 35%, never more than CEILING_MAX."""
    r = economy.PHASE3["ceilings"][league]
    rate = economy.solo_win_rate(league, r, "average", 3000, 9, economy.PHASE3["anchors"])
    assert 0.28 <= rate <= economy.CEILING_MAX, (league, rate)


def test_phase3_ceilings_climb_and_points_lead_for_casual():
    c = economy.PHASE3["ceilings"]
    assert c["Rookie"] < c["Bronze"] < c["Silver"] < c["Gold"]
    rep = _ladder("casual")
    for lg in economy.LADDER_TARGET:  # the casual kid leaves on points, still under about 35%
        assert rep[lg]["p_out"] <= economy.CEILING_MAX, lg


def test_phase3_skill_premium():
    """A perfect rider on the same schedule out-earns a new-kid rider in every league by at least
    a third per race, and reaches Champion sooner."""
    casual, perfect = _ladder("casual"), _ladder("casual-perfect")
    for lg in economy.LEAGUES:
        assert perfect[lg]["cash_per_race"] >= 1.33 * casual[lg]["cash_per_race"], lg
    assert perfect["Champion"]["week"] < casual["Champion"]["week"] - 1.5


def test_phase3_purses_and_entry_unchanged():
    """D-068 keeps purses (flattening waits for a cosmetics sink), adds no entry fee and keeps the
    D-061 Rookie anchor."""
    assert economy.LEAGUE_B == {"Rookie": 20, "Bronze": 50, "Silver": 120, "Gold": 300, "Champion": 750}
    assert economy.PHASE3["anchors"]["Rookie"] == economy.BOT_RATING_ANCHOR["Rookie"]


@pytest.mark.parametrize("league", ["Bronze", "Silver", "Gold"])  # Rookie's Cup points are unchanged
def test_live_config_casual_races_to_cup(league):
    """The live GameConfig ladder meets the D-068 targets."""
    n = _ladder("casual", "live")[league]["unlock"]
    target = economy.LADDER_TARGET[league]
    assert abs(n - target) <= economy.LADDER_TOLERANCE * target, (league, n)


def test_live_config_is_phase3():
    """GameConfig carries the D-068 values."""
    assert _live_ladder() == _as_float(economy.PHASE3)


@pytest.mark.parametrize("league", ["Bronze", "Silver", "Gold"])
def test_phase3_light_player_never_stuck(league):
    """Systems consult: a light kid (1 session of 10 races a week, both training rides, so the cap
    every week) outgrows each league before its points open the Cup, so RACE! turns into the Cup.
    It must still get regular races in every new league (never over the ceiling on arrival), race
    a good stretch before the ceiling closes them, and win its Cup tries at 30% or more."""
    rep = _ladder("light", players=160)[league]
    assert rep["closed_at_entry"] <= 0.01, (league, rep["closed_at_entry"])
    assert rep["unlock"] >= 15, (league, rep["unlock"])
    if rep["closed"]:
        assert rep["cup_p_closed"] >= 0.30, (league, rep["cup_p_closed"])
    assert rep["cup_tries"] <= 4, (league, rep["cup_tries"])
    assert _ladder("light", players=160)["Champion"]["week"] <= 20

