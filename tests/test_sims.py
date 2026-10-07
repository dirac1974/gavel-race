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
