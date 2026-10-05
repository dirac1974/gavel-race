"""Smoke test: the economy simulator runs and promotes players."""

import random
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
