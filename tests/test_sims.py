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
    anchors, spread = _luau_anchors()
    assert anchors == {k: float(v) for k, v in economy.BOT_RATING_ANCHOR.items()}
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


def test_silver_cup_casual_in_target_band():
    """D-062 stage 8: with GameConfig's Silver threshold, a casual player (new kid, Silver-entry
    horse, +10 first win) opens the Silver Cup in 150-200 Silver races."""
    stakes, _ = _luau_stakes()
    kid, rating = economy.SILVER_COHORTS["casual"]
    n = economy.races_to_cup(stakes["Silver"], "Silver", rating, kid, players=80, seed=11)
    lo, hi = economy.SILVER_TARGET
    assert lo <= n <= hi, n


def test_silver_cup_better_riders_and_horses_get_there_sooner():
    stakes, _ = _luau_stakes()
    casual_kid, casual_rating = economy.SILVER_COHORTS["casual"]
    casual = economy.races_to_cup(stakes["Silver"], "Silver", casual_rating, casual_kid, players=40, seed=12)
    regular_kid, regular_rating = economy.SILVER_COHORTS["regular"]
    regular = economy.races_to_cup(stakes["Silver"], "Silver", regular_rating, regular_kid, players=40, seed=12)
    assert regular < casual
    assert regular >= 100  # the Cup is still a goal, not a formality


def test_old_silver_threshold_missed_the_band():
    """D-013's 1,400 points took a casual player far past 200 Silver races; 600 lands under 150."""
    kid, rating = economy.SILVER_COHORTS["casual"]
    assert economy.races_to_cup(1400, "Silver", rating, kid, players=30, seed=13) > economy.SILVER_TARGET[1]
    assert economy.races_to_cup(600, "Silver", rating, kid, players=60, seed=13) < economy.SILVER_TARGET[0]
