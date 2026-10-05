#!/usr/bin/env python3
"""Giddy-up pace meter (D-026): the continuous slider riders tap through the whole race.

Mirrors game/src/shared/PaceMeter.luau exactly; parity is tested in tests/luau.

  schedule: the marker's passes across the bar, back and forth with no pauses. Each pass
            takes half a sweep, nudged by up to +-speed_drift; the glowing target moves to
            a new spot every shift_min..shift_max passes (David's anti-macro idea), so a
            fixed-interval clicker can't follow it.
  score:    one tap per pass, scored 100 * (1 - distance from the target), distance in
            half-bar units; a pass with no tap or with two or more taps scores 0.
  errors:   tap time minus the moment the marker crossed the target, for passes with one
            tap; Integrity looks at their spread.
"""

from __future__ import annotations

from typing import List, NamedTuple, Optional, Sequence, Tuple


class Pass(NamedTuple):
    t0: float
    t1: float
    dir: int        # +1: left to right, -1: right to left
    center: float   # target centre in [-1, 1] bar units


def schedule(uniforms, start: float, duration: float, sweep: float, speed_drift: float,
             shift_min: int, shift_max: int, center_range: float) -> List[Pass]:
    """`uniforms` has .random() in [0, 1). Per new target: 2 uniforms (centre, run length);
    per pass: 1 uniform (speed)."""
    nxt = uniforms.random
    out: List[Pass] = []
    t, direction, left, center = start, 1, 0, 0.0
    while t < start + duration - 1e-9:
        if left == 0:
            center = (2 * nxt() - 1) * center_range
            left = shift_min + int(nxt() * (shift_max - shift_min + 1))
        half = sweep / 2 * (1 + speed_drift * (2 * nxt() - 1))
        out.append(Pass(t, t + half, direction, center))
        t += half
        direction = -direction
        left -= 1
    return out


def position(p: Pass, t: float) -> float:
    f = (t - p.t0) / (p.t1 - p.t0)
    return -1 + 2 * f if p.dir > 0 else 1 - 2 * f


def ideal_time(p: Pass) -> float:
    f = (p.center + 1) / 2 if p.dir > 0 else (1 - p.center) / 2
    return p.t0 + f * (p.t1 - p.t0)


def tap_score(p: Pass, t: float) -> float:
    return 100 * (1 - min(abs(position(p, t) - p.center), 1))


def pass_index(passes: Sequence[Pass], t: float) -> Optional[int]:
    for k, p in enumerate(passes):
        if p.t0 <= t < p.t1:
            return k
    return None


def debounce(taps: Sequence[float], bounce: float = 0.0) -> Tuple[List[float], int]:
    """Finger bounces (D-055): drop taps within `bounce` s of the last counted tap; return (counted, ignored)."""
    if bounce <= 0:
        return list(taps), 0
    kept: List[float] = []
    last, ignored = float("-inf"), 0
    for t in sorted(taps):
        if t - last < bounce:
            ignored += 1
        else:
            kept.append(t)
            last = t
    return kept, ignored


def score(passes: Sequence[Pass], taps: Sequence[float], bounce: float = 0.0) -> Tuple[float, List[float], int]:
    """Mean pass score (missed or doubled passes count 0), timing errors, and passes hit once."""
    if not passes:
        return 0.0, [], 0
    taps, _ = debounce(taps, bounce)
    by_pass: List[List[float]] = [[] for _ in passes]
    for t in taps:
        k = pass_index(passes, t)
        if k is not None:
            by_pass[k].append(t)
    total, errors, single = 0.0, [], 0
    for p, ts in zip(passes, by_pass):
        if len(ts) == 1:
            total += tap_score(p, ts[0])
            errors.append(ts[0] - ideal_time(p))
            single += 1
    return total / len(passes), errors, single
