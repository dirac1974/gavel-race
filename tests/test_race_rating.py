"""Tests for Race Rating (D-014)."""

import math

import pytest

import race_rating as rr

SUNNY_MILE_DIRT = {"distance": "Mile", "surface": "Dirt", "weather": "Sunny"}


@pytest.mark.parametrize("d", list(rr.DISTANCE_WEIGHTS))
@pytest.mark.parametrize("s", list(rr.SURFACE_SHIFT))
@pytest.mark.parametrize("w", list(rr.WEATHER_SHIFT))
def test_weights_sum_to_one(d, s, w):
    assert math.isclose(sum(rr.weights(d, s, w).values()), 1.0, abs_tol=1e-12)


def test_all_stats_equal_gives_that_rating():
    stats = {k: 60 for k in ("speed", "accel", "stamina", "grit", "focus")}
    for d in rr.DISTANCE_WEIGHTS:
        assert math.isclose(rr.rating(stats, {"distance": d, "surface": "Sand", "weather": "Rain"}), 60)


def test_conditions_change_who_is_best():
    sprinter = {"speed": 60, "accel": 85, "stamina": 40, "grit": 60, "focus": 50}
    stayer = {"speed": 60, "accel": 40, "stamina": 85, "grit": 60, "focus": 50}
    sprint = {"distance": "Sprint", "surface": "Dirt", "weather": "Sunny"}
    marathon = {"distance": "Marathon", "surface": "Dirt", "weather": "Sunny"}
    assert rr.rating(sprinter, sprint) > rr.rating(stayer, sprint)
    assert rr.rating(stayer, marathon) > rr.rating(sprinter, marathon)


def test_rain_rewards_grit():
    gritty = {"speed": 55, "accel": 55, "stamina": 55, "grit": 90, "focus": 50}
    plain = {"speed": 62, "accel": 62, "stamina": 62, "grit": 50, "focus": 50}
    rain = {"distance": "Mile", "surface": "Dirt", "weather": "Rain"}
    assert rr.rating(gritty, rain) > rr.rating(plain, rain)


def test_bonuses_and_caps():
    stats = {k: 50 for k in ("speed", "accel", "stamina", "grit", "focus")}
    base = rr.rating(stats, SUNNY_MILE_DIRT)
    assert math.isclose(rr.rating(stats, SUNNY_MILE_DIRT, care=1), base * 1.05)
    assert math.isclose(rr.rating(stats, SUNNY_MILE_DIRT, care=5), base * 1.05)  # clamped
    assert math.isclose(rr.rating(stats, SUNNY_MILE_DIRT, pilot_level=1), base + 3)
    assert math.isclose(rr.rating(stats, SUNNY_MILE_DIRT, strategy="Stalker"), base + 2)
    assert math.isclose(rr.rating(stats, SUNNY_MILE_DIRT, strategy="Closer"), base)
    assert math.isclose(rr.rating(stats, SUNNY_MILE_DIRT, bond=1), base + 2)


def test_full_bonus_stack_is_modest():
    """All non-stat bonuses together add about 10 points at 60 stats: one doubling of win chance at T=14.4."""
    stats = {k: 60 for k in ("speed", "accel", "stamina", "grit", "focus")}
    full = rr.rating(stats, SUNNY_MILE_DIRT, care=1, pilot_level=1, strategy="Stalker", bond=1)
    assert full - 60 <= 10 + 1e-9
