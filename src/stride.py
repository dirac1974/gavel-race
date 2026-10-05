#!/usr/bin/env python3
"""Giddy-up stride scoring (D-022), shared by riders and Clap Along fans (D-020).

Mirrors game/src/shared/Stride.luau exactly; parity is tested in tests/luau.

  schedule: beat times for one stretch. Tempo is picked per stretch inside the
            league's range, drifts a little each stride, and Champion adds one
            off-beat lead change (a half-beat shift) mid-stretch.
  score:    each beat takes its closest tap within +-half seconds and scores
            1 - |error| / half; every other tap counts -1; the stretch score is
            100 * total / beats, floored at 0. Mashing and fixed-rhythm macros
            land near 0.
  gap errors: for consecutive matched beats, (tap gap - beat gap). Integrity
            checks look at the spread of these: people are off by 30-50 ms,
            beat-tracking bots by about 5.
"""

from __future__ import annotations

from typing import List, Optional, Sequence, Tuple


def schedule(uniforms, start: float, beats: int, interval_lo: float, interval_hi: float,
             drift: float, lead_change: bool) -> List[float]:
    """`uniforms` is anything with .random() returning [0, 1).

    Consumes 1 uniform for the tempo, then 1 per beat after the first.
    """
    nxt = uniforms.random
    interval = interval_lo + (interval_hi - interval_lo) * nxt()
    lead_at = beats // 2 + 1 if lead_change else -1
    t = start
    out: List[float] = []
    for k in range(1, beats + 1):
        if k > 1:
            interval *= 1 + drift * (2 * nxt() - 1)
            t += interval
            if k == lead_at:
                t += interval / 2
        out.append(t)
    return out


def match(beats: Sequence[float], taps: Sequence[float], half: float) -> Tuple[List[Optional[float]], int]:
    """Per beat, the closest tap within +-half (or None); and the count of extra taps.

    Beats are always more than 2 * half apart, so a tap can sit in at most one window.
    """
    matched: List[Optional[float]] = [None] * len(beats)
    used = [False] * len(taps)
    for k, b in enumerate(beats):
        best, best_err = -1, 0.0
        for j, t in enumerate(taps):
            e = abs(t - b)
            if not used[j] and e <= half and (best == -1 or e < best_err):
                best, best_err = j, e
        if best >= 0:
            used[best] = True
            matched[k] = taps[best]
    extras = sum(1 for u in used if not u)
    return matched, extras


def score(beats: Sequence[float], taps: Sequence[float], half: float) -> float:
    if not beats:
        return 0.0
    matched, extras = match(beats, taps, half)
    total = 0.0
    for b, t in zip(beats, matched):
        if t is not None:
            total += 1 - abs(t - b) / half
    return max(0.0, 100 * (total - extras) / len(beats))


def gap_errors(beats: Sequence[float], taps: Sequence[float], half: float) -> List[float]:
    matched, _ = match(beats, taps, half)
    out: List[float] = []
    for k in range(1, len(beats)):
        a, b = matched[k - 1], matched[k]
        if a is not None and b is not None:
            out.append((b - a) - (beats[k] - beats[k - 1]))
    return out
