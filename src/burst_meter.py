#!/usr/bin/env python3
"""Final Burst meter (D-022; scoring from D-010; arming D-066): one tap on a fast slider.

Mirrors game/src/shared/BurstMeter.luau exactly; parity is tested in tests/luau.

  position: the marker in [-1, 1], a triangle wave from a random start shared by every lane.
  score:    100 * (1 - distance from the target), distance in half-widths, floored at 0.
  armed:    the burst counts taps only from arm_seconds after it opens (GameConfig.burstArmSeconds);
            an earlier tap is ignored, not scored and not used up. Only input waits: the marker
            runs from its random start the whole time, so a fixed-delay macro still scores ~50.
"""

from __future__ import annotations

import math
from typing import Optional, TypedDict

BURST_ARM_SECONDS = 0.5  # GameConfig.burstArmSeconds (D-066); tests/test_burst_meter.py checks they match


class Spec(TypedDict, total=False):
    sweepSeconds: float
    targetDrift: float
    twoTargets: bool
    driftSeconds: float
    phase: float


def position(t: float, sweep_seconds: float, phase: float = 0.0) -> float:
    p = (t / sweep_seconds + phase) % 1
    if p < 0.5:
        return -1 + 4 * p
    return 3 - 4 * p


def target_center(t: float, spec: Spec) -> float:
    drift = spec.get("targetDrift", 0.0)
    if drift <= 0:
        return 0.0
    period = spec.get("driftSeconds") or 3.7
    return drift * math.sin(2 * math.pi * t / period)


def distance(t: float, spec: Spec) -> float:
    pos = position(t, spec["sweepSeconds"], spec.get("phase") or 0.0)
    if spec.get("twoTargets"):
        return 2 * min(abs(pos - 0.5), abs(pos + 0.5))
    return abs(pos - target_center(t, spec))


def score(t: float, spec: Spec) -> float:
    return 100 * (1 - min(max(distance(t, spec), 0.0), 1.0))


def armed(t: float, arm_seconds: float = BURST_ARM_SECONDS) -> bool:
    return t >= arm_seconds


def tap_score(t: float, spec: Spec, arm_seconds: float = BURST_ARM_SECONDS) -> Optional[float]:
    if not armed(t, arm_seconds):
        return None
    return score(t, spec)
