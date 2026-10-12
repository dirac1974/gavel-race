#!/usr/bin/env python3
"""Synthesize stand-in sound effects for every effect in tools/audio/sounds.json and pack them into one sound sheet.

  python tools/audio/synth_sheet.py              # render, write the sheet, manifest, previews and SoundSheet.luau
  python tools/audio/synth_sheet.py --rebuild    # replace a sheet that was already uploaded (spends an audio upload)

Roblox caps audio uploads (10 per 30 days on this account), so every effect shares one upload: the game plays a
clip with Sound.PlaybackRegion (game/src/client/Sound.luau). An effect that later gets its own uploaded file
(ElevenLabs, tools/audio/generate_audio.py) takes over from its clip automatically.

Writes:
  assets/audio/sound_sheet.wav           the sheet (mono 16-bit 44.1 kHz WAV, clips on a 10 ms grid, 0.25 s apart)
  tools/audio/sheet.json                 name -> start, length (seconds), loop
  assets/audio/synth_preview/<name>.wav  each clip alone, for listening (gitignored)
  game/src/shared/SoundSheet.luau        generated through tools/roblox/upload_assets.py (asset id from uploaded.json)

Tone: County Fair Toy (docs/art/ART_DIRECTION.md): warm, soft, short, nothing harsh, scary or loud. Every clip is
band-limited (35 Hz to 9 kHz), faded at the edges and peak-normalized to -3 dBFS. Rendering is seeded, so a re-run
gives the same audio. Once the sheet is uploaded it is never overwritten without --rebuild (the uploaded clip
offsets must keep matching the uploaded file). MUTED drops a clip from the game without touching the audio.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import io
import json
import sys
import wave
import zlib
from pathlib import Path
from typing import Callable

import numpy as np

REPO = Path(__file__).resolve().parents[2]
SPEC = REPO / "tools" / "audio" / "sounds.json"
MANIFEST = REPO / "tools" / "audio" / "sheet.json"
SHEET = REPO / "assets" / "audio" / "sound_sheet.wav"
PREVIEW = REPO / "assets" / "audio" / "synth_preview"
UPLOADER = REPO / "tools" / "roblox" / "upload_assets.py"
SHEET_NAME = "sound_sheet"  # its record name in tools/roblox/uploaded.json

SR = 44100
GRID = SR // 100  # clip starts and lengths land on 10 ms steps, so the manifest times are exact
GAP_S = 0.25
LEAD_S = 0.1
PEAK = 10 ** (-3 / 20)
MUTED: tuple[str, ...] = ()  # names left out of SoundSheet.luau (the audio stays in the sheet)

Array = np.ndarray


# Building blocks ------------------------------------------------------------------------------
def rng_for(name: str) -> np.random.Generator:
    return np.random.default_rng(zlib.crc32(name.encode()))


def secs(n: int) -> Array:
    return np.arange(n) / SR


def samples(s: float) -> int:
    return int(round(s * SR))


# Filters are zero-phase Butterworth magnitude responses applied in the frequency domain (numpy only: no compiled
# filter library needed). A one-shot is zero-padded first; circular=True filters round the loop instead.
def _lp_gain(f: Array, hz: float, order: int) -> Array:
    return 1 / np.sqrt(1 + (f / hz) ** (2 * order))


def _hp_gain(f: Array, hz: float, order: int) -> Array:
    with np.errstate(divide="ignore"):
        return np.where(f > 0, 1 / np.sqrt(1 + (hz / np.maximum(f, 1e-9)) ** (2 * order)), 0.0)


def _apply(x: Array, gain: Callable[[Array], Array], circular: bool) -> Array:
    n = len(x) if circular else len(x) + samples(0.3)
    f = np.fft.rfftfreq(n, 1 / SR)
    return np.fft.irfft(np.fft.rfft(x, n) * gain(f), n)[: len(x)]


def lp(x: Array, hz: float, order: int = 2, circular: bool = False) -> Array:
    return _apply(x, lambda f: _lp_gain(f, hz, order), circular)


def hp(x: Array, hz: float, order: int = 2, circular: bool = False) -> Array:
    return _apply(x, lambda f: _hp_gain(f, hz, order), circular)


def bp(x: Array, lo: float, hi: float, order: int = 2, circular: bool = False) -> Array:
    return _apply(x, lambda f: _hp_gain(f, lo, order) * _lp_gain(f, hi, order), circular)


def perc(n: int, attack: float, tau: float) -> Array:
    """Fast attack, exponential decay."""
    t = secs(n)
    a = max(samples(attack), 1)
    env = np.exp(-t / tau)
    env[:a] *= np.linspace(0, 1, a, endpoint=False) ** 1.5
    return env


def adsr(n: int, a: float, d: float, s: float, r: float) -> Array:
    """Attack, decay to sustain level s, hold, release over the last r seconds."""
    na, nd, nr = samples(a), samples(d), samples(r)
    nh = max(n - na - nd - nr, 0)
    env = np.concatenate([np.linspace(0, 1, na, endpoint=False) ** 1.5,
                          s + (1 - s) * np.exp(-5 * np.linspace(0, 1, nd, endpoint=False)),
                          np.full(nh, s),
                          s * np.linspace(1, 0, nr) ** 2])
    return np.pad(env, (0, max(n - len(env), 0)))[:n]


def place(out: Array, clip: Array, at: float, gain: float = 1.0) -> None:
    i = samples(at)
    if i >= len(out):
        return
    m = min(len(clip), len(out) - i)
    out[i:i + m] += gain * clip[:m]


def partials(n: int, f0: float, ratios: list[float], amps: list[float], taus: list[float],
             attack: float = 0.002, phase_seed: int = 0) -> Array:
    """Additive struck tone (bells, marimba, wood): each partial decays at its own rate."""
    t = secs(n)
    out = np.zeros(n)
    ph = np.random.default_rng(phase_seed).uniform(0, 2 * np.pi, len(ratios))
    for r, a, tau, p in zip(ratios, amps, taus, ph):
        f = f0 * r
        if f >= 9000:
            continue
        out += a * np.sin(2 * np.pi * f * t + p) * perc(n, attack, tau)
    return out


def fm_bell(n: int, fc: float, ratio: float, index: float, tau: float, itau: float) -> Array:
    """Two-operator FM bell: the brightness (index) dies away faster than the tone."""
    t = secs(n)
    mod = index * np.exp(-t / itau) * np.sin(2 * np.pi * fc * ratio * t)
    return np.sin(2 * np.pi * fc * t + mod) * perc(n, 0.002, tau)


def bell(n: int, f0: float, tau: float, bright: float = 1.0, seed: int = 0) -> Array:
    """Warm small bell: additive hand-bell partials plus a little FM shimmer."""
    tone = partials(n, f0, [1, 2.0, 2.76, 4.07, 5.40], [1, 0.35 * bright, 0.22 * bright, 0.08 * bright, 0.04 * bright],
                    [tau, tau * 0.55, tau * 0.4, tau * 0.25, tau * 0.15], phase_seed=seed)
    return tone + 0.25 * fm_bell(n, f0, 1.41, 1.2 * bright, tau * 0.8, 0.08)


def noise(n: int, rng: np.random.Generator) -> Array:
    return rng.standard_normal(n)


def reverb(x: Array, seconds: float, wet: float, rng: np.random.Generator, damp: float = 3500.0,
           circular: bool = False) -> Array:
    """Small-room tail: a decaying, darkened noise impulse response mixed under the dry sound."""
    n = samples(seconds)
    t = secs(n)
    ir = lp(rng.standard_normal(n), damp) * np.exp(-6.9 * t / seconds)
    ir[: samples(0.008)] = 0  # pre-delay: keep the attack clear
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-12
    if circular:
        tail = np.real(np.fft.ifft(np.fft.fft(x) * np.fft.fft(np.pad(ir, (0, max(len(x) - n, 0)))[:len(x)])))
    else:
        m = len(x) + n
        tail = np.fft.irfft(np.fft.rfft(x, m) * np.fft.rfft(ir, m), m)[: len(x)]
    return x + wet * tail * (np.max(np.abs(x)) / (np.max(np.abs(tail)) + 1e-12))


def svf_bandpass(x: Array, centre: Array, q: float) -> Array:
    """Chamberlin state-variable band-pass with a moving centre (whooshes and bristles)."""
    f = 2 * np.sin(np.pi * np.clip(centre, 20, SR / 6) / SR)
    damp = 1 / q
    low = band = 0.0
    out = np.empty_like(x)
    for i in range(len(x)):
        high = x[i] - low - damp * band
        band += f[i] * high
        low += f[i] * band
        out[i] = band
    return out


def glide_sine(n: int, f_start: float, f_end: float, tau: float) -> Array:
    """A sine whose pitch slides from f_start to f_end (thumps fall, pops rise)."""
    t = secs(n)
    f = f_end + (f_start - f_end) * np.exp(-t / tau)
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def harmonic_voice(n: int, f0: Array, tilt: float, max_hz: float = 4500.0) -> Array:
    """Band-limited harmonic source with a moving pitch (brass, voices)."""
    phase = 2 * np.pi * np.cumsum(f0) / SR
    out = np.zeros(n)
    for k in range(1, int(max_hz / max(np.min(f0), 1.0)) + 1):
        gate = (k * f0 < max_hz).astype(float)
        out += gate * np.sin(k * phase) / k ** tilt
    return out


def formants(x: Array, bands: list[tuple[float, float, float]]) -> Array:
    """Parallel resonances (centre, width, gain): a vowel or a body."""
    return sum(g * bp(x, c - w / 2, c + w / 2) for c, w, g in bands)


# The sounds -----------------------------------------------------------------------------------
def hoof(rng: np.random.Generator, vel: float) -> Array:
    n = samples(0.22)
    body = 0.7 * np.tanh(2 * glide_sine(n, 140 * rng.uniform(0.92, 1.08), 75, 0.02) * perc(n, 0.001, 0.05))
    dirt = lp(noise(n, rng), 900) * perc(n, 0.001, 0.035)
    grit = lp(bp(noise(n, rng), 1200, 2600), 3000) * perc(n, 0.0005, 0.008)
    return vel * (body + 1.1 * dirt / (np.max(np.abs(dirt)) + 1e-9) * 0.6 + 0.25 * grit / (np.max(np.abs(grit)) + 1e-9))


def gallop_loop(rng: np.random.Generator) -> Array:
    """Four strides of a four-beat gallop (beat, beat, beat, beat, float), rendered round a circle so it loops."""
    n = samples(2.0)
    out = np.zeros(n)
    stride = 0.5
    offsets = [0.0, 0.085, 0.165, 0.245]
    accents = [0.8, 0.95, 0.75, 1.0]
    for s in range(4):
        for off, acc in zip(offsets, accents):
            at = s * stride + off + rng.uniform(-0.005, 0.005)
            hit = hoof(rng, acc * rng.uniform(0.9, 1.05))
            idx = (samples(at) + np.arange(len(hit))) % n
            np.add.at(out, idx, hit)
    out = reverb(out, 0.25, 0.12, rng, damp=2000, circular=True)
    return out


def crowd_cheer(rng: np.random.Generator) -> Array:
    n = samples(3.0)
    t = secs(n)
    swell = np.clip(t / 0.35, 0, 1) ** 1.5 * (1 + 0.18 * np.sin(2 * np.pi * (t - 0.6) / 1.6)) \
        * np.clip((3.0 - t) / 0.9, 0, 1) ** 1.3
    bed = bp(noise(n, rng), 300, 2400) + 0.5 * lp(noise(n, rng), 500)
    bed = bed / np.max(np.abs(bed))
    voices = np.zeros(n)
    vowels = [[(750, 260, 1.0), (1200, 300, 0.6)], [(500, 200, 1.0), (1850, 400, 0.4)], [(520, 220, 1.0), (900, 260, 0.6)]]
    for _ in range(18):
        dur = rng.uniform(0.6, 1.6)
        m = samples(dur)
        tt = secs(m)
        f0 = rng.uniform(190, 420) * (1 + rng.uniform(0.08, 0.25) * (1 - np.exp(-tt / 0.15))) \
            * (1 + 0.012 * np.sin(2 * np.pi * rng.uniform(4.5, 6) * tt))
        v = formants(harmonic_voice(m, f0, 1.2, 3500), vowels[rng.integers(3)])
        v *= adsr(m, 0.12, 0.2, 0.7, 0.35)
        place(voices, v / (np.max(np.abs(v)) + 1e-9), rng.uniform(0.0, 1.3), rng.uniform(0.3, 0.7))
    claps = np.zeros(n)
    for _ in range(90):
        at = rng.uniform(0.05, 2.7)
        m = samples(0.06)
        c = bp(noise(m, rng), 900 * rng.uniform(0.8, 1.3), 2300 * rng.uniform(0.85, 1.1)) * perc(m, 0.0005, 0.012)
        place(claps, c / (np.max(np.abs(c)) + 1e-9), at, rng.uniform(0.15, 0.4) * np.interp(at, t, swell))
    mix = 0.55 * bed + 0.5 * voices / (np.max(np.abs(voices)) + 1e-9) + 0.35 * claps
    return reverb(lp(mix * swell, 5000), 0.8, 0.3, rng, damp=3000)


def gate_bell(rng: np.random.Generator) -> Array:
    n = samples(1.5)
    out = np.zeros(n)
    m = samples(1.45)
    ring = partials(m, 880, [0.5, 1, 1.183, 1.506, 2.0, 2.514], [0.35, 1, 0.45, 0.3, 0.25, 0.1],
                    [0.9, 0.7, 0.5, 0.4, 0.3, 0.2], phase_seed=7)
    for i, g in enumerate([1.0, 0.55, 0.35]):
        place(out, ring, 0.03 + 0.055 * i, g)
    k = samples(0.3)
    clang = partials(k, 310, [1, 2.37, 3.84], [1, 0.6, 0.3], [0.08, 0.05, 0.03], phase_seed=3) \
        + 0.4 * bp(noise(k, rng), 500, 1500) * perc(k, 0.0005, 0.02)
    thunk = glide_sine(k, 140, 80, 0.03) * perc(k, 0.001, 0.05)
    place(out, 0.35 * clang + 0.4 * thunk, 0.0)
    return reverb(out, 0.9, 0.22, rng)


def count_tick(rng: np.random.Generator) -> Array:
    n = samples(0.5)
    t = secs(n)
    f0 = 200 + 40 * np.exp(-t / 0.015)
    drum = np.zeros(n)
    for r, a, tau in [(1, 1, 0.12), (1.59, 0.45, 0.06), (2.14, 0.25, 0.04)]:
        drum += a * np.sin(2 * np.pi * np.cumsum(f0 * r) / SR) * perc(n, 0.001, tau)
    stick = lp(bp(noise(n, rng), 1500, 3500), 4000) * perc(n, 0.0005, 0.006)
    return reverb(drum + 0.2 * stick / np.max(np.abs(stick)), 0.3, 0.12, rng)


def lock_tick(rng: np.random.Generator) -> Array:
    n = samples(0.8)
    return reverb(bell(n, 1318.5, 0.32, bright=0.7, seed=11), 0.5, 0.15, rng)


def bump_soft(rng: np.random.Generator) -> Array:
    n = samples(0.4)
    thump = np.tanh(2.5 * glide_sine(n, 110, 60, 0.04) * perc(n, 0.004, 0.08))
    pad = bp(noise(n, rng), 150, 650, 2) * perc(n, 0.003, 0.05)
    return thump + 0.6 * pad / np.max(np.abs(pad))


def burst_whoosh(rng: np.random.Generator) -> Array:
    n = samples(1.5)
    t = secs(n)
    centre = 300 * (1800 / 300) ** np.clip(t / 1.0, 0, 1)
    swoosh = svf_bandpass(noise(n, rng), centre, 1.6) * (np.clip(t / 0.8, 0, 1) ** 2 * np.clip((1.45 - t) / 0.6, 0, 1))
    swoosh /= np.max(np.abs(swoosh))
    chimes = np.zeros(n)
    notes = [1046.5, 1174.7, 1318.5, 1568.0, 1760.0, 2093.0, 2349.3, 2637.0]
    for i, f in enumerate(notes):
        m = samples(0.6)
        place(chimes, bell(m, f, 0.18, bright=0.5 - 0.04 * i, seed=i), 0.2 + i * 0.11 + rng.uniform(-0.01, 0.01),
              0.25 + 0.04 * i)
    return reverb(lp(0.6 * swoosh + 0.5 * chimes / np.max(np.abs(chimes)), 6000), 0.9, 0.25, rng)


def tap_good(rng: np.random.Generator) -> Array:
    n = samples(0.5)
    tone = partials(n, 784.0, [1, 3.93, 9.2], [1, 0.25, 0.05], [0.18, 0.05, 0.015], phase_seed=5)
    mallet = lp(noise(n, rng), 2000) * perc(n, 0.0005, 0.003)
    return reverb(tone + 0.15 * mallet / np.max(np.abs(mallet)), 0.35, 0.1, rng)


def tap_ok(rng: np.random.Generator) -> Array:
    """Soft wooden tick heard on every counted tap; the game raises its pitch with the score (PlaybackSpeed)."""
    n = samples(0.15)
    tone = partials(n, 1000.0, [1, 2.57, 4.2], [1, 0.3, 0.1], [0.035, 0.015, 0.008], attack=0.001, phase_seed=9)
    click = lp(noise(n, rng), 2500) * perc(n, 0.0003, 0.002)
    return tone + 0.12 * click / np.max(np.abs(click))


def brass(n: int, f: float, rng: np.random.Generator, vibrato: bool) -> Array:
    t = secs(n)
    vib = 1 + (0.006 * np.sin(2 * np.pi * 5.5 * t) * np.clip((t - 0.18) / 0.2, 0, 1) if vibrato else 0)
    out = np.zeros(n)
    for detune in (0.997, 1.003):
        f0 = f * detune * vib
        phase = 2 * np.pi * np.cumsum(f0) / SR + rng.uniform(0, 2 * np.pi)
        bright = 2 + 5 * np.clip(t / 0.05, 0, 1) - 1.5 * np.clip((t - 0.05) / 0.3, 0, 1)
        for k in range(1, int(4500 / f) + 1):
            out += np.exp(-k / bright) * np.sin(k * phase) / k ** 0.6
    return out * adsr(n, 0.025, 0.08, 0.8, min(0.08, n / SR / 3))


def finish_fanfare(rng: np.random.Generator) -> Array:
    n = samples(2.5)
    out = np.zeros(n)
    G4, C5, E5, G5 = 392.0, 523.25, 659.25, 783.99
    phrase = [(0.00, G4, 0.12), (0.14, G4, 0.12), (0.28, G4, 0.12), (0.42, C5, 0.38), (0.84, G4, 0.14)]
    for at, f, dur in phrase:
        place(out, brass(samples(dur), f, rng, False), at, 0.8)
    hold = samples(1.15)
    for f, g in [(G5, 0.8), (E5, 0.45), (C5, 0.45)]:
        place(out, brass(hold, f, rng, True), 1.0, g)
    out = lp(out, 4000)
    return reverb(out, 1.0, 0.22, rng)


def ui_pop(rng: np.random.Generator) -> Array:
    n = samples(0.18)
    t = secs(n)
    f = 1250 - 900 * np.exp(-t / 0.012)
    s = np.sin(2 * np.pi * np.cumsum(f) / SR)
    return (s + 0.15 * np.sin(2 * np.pi * np.cumsum(2 * f) / SR)) * perc(n, 0.001, 0.03)


def coin(rng: np.random.Generator) -> Array:
    n = samples(1.0)
    out = np.zeros(n)
    place(out, bell(samples(0.12), 987.8, 0.06, bright=0.6, seed=1) * np.linspace(1, 0, samples(0.12)) ** 0.5, 0.0, 0.8)
    place(out, bell(samples(0.9), 1318.5, 0.3, bright=0.6, seed=2), 0.075)
    for i, f in enumerate([2637.0, 3136.0]):
        place(out, bell(samples(0.4), f, 0.08, bright=0.3, seed=3 + i), 0.14 + 0.06 * i, 0.15)
    return reverb(out, 0.5, 0.15, rng)


def horse_nicker(rng: np.random.Generator) -> Array:
    """A low, fluttering 'huh-huh-huh': a pitched voice pulsed by a slowing flutter, through a long-nosed vowel."""
    n = samples(1.2)
    t = secs(n)
    f0 = (105 - 22 * np.clip(t / 0.9, 0, 1)) * (1 + 0.01 * rng.standard_normal(n).cumsum() / np.sqrt(np.arange(1, n + 1)))
    source = harmonic_voice(n, f0, 1.3, 3000)
    rate = 13 - 5 * np.clip(t / 0.9, 0, 1)
    flutter = (0.5 - 0.5 * np.cos(2 * np.pi * np.cumsum(rate) / SR)) ** 1.6
    breath = lp(noise(n, rng), 1400)
    breath /= np.max(np.abs(breath))
    voiced = formants(source, [(420, 220, 1.0), (950, 300, 0.55), (2300, 500, 0.12)])
    voiced /= np.max(np.abs(voiced))
    env = adsr(n, 0.06, 0.15, 0.85, 0.35) * np.clip((1.0 - t) / 0.25, 0, 1)
    body = (voiced * (0.35 + 0.65 * flutter) + 0.18 * breath * (0.4 + 0.6 * flutter)) * env
    return reverb(lp(body, 2500), 0.4, 0.12, rng)


def brush(rng: np.random.Generator) -> Array:
    n = samples(1.5)
    out = np.zeros(n)
    for at, length, g in [(0.08, 0.55, 1.0), (0.78, 0.6, 0.85)]:
        m = samples(length)
        tt = secs(m)
        shape = np.sin(np.pi * tt / length) ** 2
        centre = 1000 + 900 * tt / length
        bristle = svf_bandpass(noise(m, rng), centre, 1.2)
        grain = 1 + 0.6 * lp(np.abs(noise(m, rng)) ** 3, 120)
        body = lp(noise(m, rng), 700)
        stroke = shape * (bristle * grain / np.max(np.abs(bristle)) + 0.35 * body / np.max(np.abs(body)))
        place(out, stroke, at, g)
    return reverb(lp(out, 4000), 0.3, 0.1, rng)


def munch(rng: np.random.Generator) -> Array:
    n = samples(2.0)
    out = np.zeros(n)
    for i, at in enumerate([0.05, 0.42, 0.76, 1.1, 1.42]):
        g = 1.0 if i == 0 else 0.75 - 0.08 * i
        burst_len = 0.14 if i == 0 else 0.1
        m = samples(burst_len + 0.05)
        crunch = np.zeros(m)
        for _ in range(int(55 if i == 0 else 30)):
            k = samples(rng.uniform(0.002, 0.006))
            grain = noise(k, rng) * np.exp(-np.arange(k) / (k / 4))
            place(crunch, grain, rng.uniform(0, burst_len) ** 1.2 / burst_len ** 0.2, rng.uniform(0.3, 1.0))
        crunch = lp(bp(crunch, 500, 3200), 3500)
        jaw = glide_sine(m, 120, 80, 0.02) * perc(m, 0.002, 0.04)
        crunch = np.tanh(3 * crunch / np.max(np.abs(crunch)))  # soft-saturate: fuller, less spiky
        place(out, crunch + 0.3 * jaw, at, g)
    return reverb(out, 0.25, 0.08, rng)


def harvest_pop(rng: np.random.Generator) -> Array:
    n = samples(0.8)
    out = np.zeros(n)
    m = samples(0.15)
    pop = glide_sine(m, 160, 620, 0.025) * perc(m, 0.002, 0.04)
    place(out, pop, 0.0)
    k = samples(0.3)
    soil = np.zeros(k)
    for _ in range(40):
        g = samples(0.003)
        place(soil, noise(g, rng) * np.hanning(g), rng.uniform(0, 0.22) ** 1.5 / 0.22 ** 0.5, rng.uniform(0.2, 1))
    place(out, 0.5 * lp(soil, 1800) / (np.max(np.abs(lp(soil, 1800))) + 1e-9), 0.01)
    for i, f in enumerate([1568.0, 2093.0]):
        place(out, bell(samples(0.5), f, 0.12, bright=0.4, seed=20 + i), 0.12 + 0.07 * i, 0.3)
    return reverb(out, 0.5, 0.15, rng)


def job_done(rng: np.random.Generator) -> Array:
    n = samples(1.5)
    out = np.zeros(n)
    for i, f in enumerate([1046.5, 1318.5, 1568.0, 2093.0]):
        place(out, bell(samples(1.2), f, 0.35 if i == 3 else 0.2, bright=0.6, seed=30 + i), 0.0 + 0.09 * i, 0.7 + 0.1 * i)
    for i in range(6):
        f = [2637.0, 3136.0, 3520.0][i % 3]
        place(out, bell(samples(0.3), f, 0.06, bright=0.2, seed=40 + i), 0.36 + 0.07 * i + rng.uniform(0, 0.02), 0.12)
    return reverb(out, 0.9, 0.22, rng)


def clap(rng: np.random.Generator) -> Array:
    n = samples(0.45)
    out = np.zeros(n)
    for at, g, tau in [(0.0, 0.5, 0.004), (0.007, 0.6, 0.004), (0.014, 0.5, 0.004), (0.022, 1.0, 0.03)]:
        m = samples(0.15)
        place(out, bp(noise(m, rng), 800, 2400) * perc(m, 0.0003, tau), at, g)
    return reverb(lp(out, 5000), 0.25, 0.15, rng)


def heartbeat(rng: np.random.Generator) -> Array:
    n = samples(0.8)
    out = np.zeros(n)
    m = samples(0.3)
    for at, f0, f1, tau, g in [(0.03, 70, 48, 0.07, 1.0), (0.3, 85, 58, 0.05, 0.75)]:
        beat = glide_sine(m, f0, f1, 0.03) * perc(m, 0.008, tau)
        upper = glide_sine(m, 3 * f0, 3 * f1, 0.03) + 0.5 * bp(noise(m, rng), 150, 450) / 3
        beat = 0.7 * np.tanh(4 * beat) + 0.8 * upper * perc(m, 0.006, tau * 0.6)
        place(out, beat, at, g)
    return lp(out, 600)  # muffled, as through a stethoscope, but with enough upper body for a phone speaker


SYNTHS: dict[str, Callable[[np.random.Generator], Array]] = {
    f.__name__: f for f in (gallop_loop, crowd_cheer, gate_bell, count_tick, lock_tick, bump_soft, burst_whoosh,
                            tap_good, tap_ok, finish_fanfare, ui_pop, coin, horse_nicker, brush, munch, harvest_pop,
                            job_done, clap, heartbeat)
}


# Mastering and packing ------------------------------------------------------------------------
def master(x: Array, loop: bool) -> Array:
    """Band-limit, de-click the edges (not a loop's), and peak-normalize to -3 dBFS."""
    x = hp(lp(x, 9000, 4, circular=loop), 35, 2, circular=loop)  # a loop is filtered round the circle: seamless
    if not loop:
        fi, fo = samples(0.002), min(samples(0.015), len(x) // 4)
        x[:fi] *= np.linspace(0, 1, fi)
        x[-fo:] *= np.linspace(1, 0, fo) ** 2
    return x * (PEAK / (np.max(np.abs(x)) + 1e-12))


def effect_names() -> list[str]:
    return [s["name"] for s in json.loads(SPEC.read_text())["sounds"] if s["kind"] == "sfx"]


def loops() -> set[str]:
    return {s["name"] for s in json.loads(SPEC.read_text())["sounds"] if s.get("loop")}


def render() -> dict[str, Array]:
    names = effect_names()
    missing = [n for n in names if n not in SYNTHS]
    if missing:
        raise SystemExit(f"synth_sheet: no synth for {missing}")
    looped = loops()
    return {name: master(SYNTHS[name](rng_for(name)), name in looped) for name in names}


def pack(clips: dict[str, Array]) -> tuple[Array, dict[str, dict[str, float | bool]]]:
    looped = loops()
    parts: list[Array] = [np.zeros(samples(LEAD_S))]
    pos = len(parts[0])
    manifest: dict[str, dict[str, float | bool]] = {}
    for name, x in clips.items():
        n = -(-len(x) // GRID) * GRID
        parts.append(np.pad(x, (0, n - len(x))))
        manifest[name] = {"start": round(pos / SR, 2), "length": round(n / SR, 2), "loop": name in looped}
        pos += n
        gap = samples(GAP_S)
        parts.append(np.zeros(gap))
        pos += gap
    return np.concatenate(parts), manifest


def to_int16(x: Array) -> Array:
    return np.clip(np.round(x * 32767), -32768, 32767).astype(np.int16)


def wav_bytes(x: Array) -> bytes:
    buf = io.BytesIO()
    with wave.open(buf, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(to_int16(x).astype("<i2").tobytes())
    return buf.getvalue()


def uploader():
    spec = importlib.util.spec_from_file_location("upload_assets", UPLOADER)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--rebuild", action="store_true", help="overwrite a sheet that was already uploaded")
    args = ap.parse_args(argv)

    clips = render()
    PREVIEW.mkdir(parents=True, exist_ok=True)
    for name, x in clips.items():
        (PREVIEW / f"{name}.wav").write_bytes(wav_bytes(x))

    sheet, manifest = pack(clips)
    data = wav_bytes(sheet)
    up = uploader()
    record = up.load_state().get(SHEET_NAME)
    current = hashlib.sha256(SHEET.read_bytes()).hexdigest() if SHEET.exists() else None
    uploaded = record is not None and record.get("sha256") == current
    if uploaded and hashlib.sha256(data).hexdigest() != current and not args.rebuild:
        print(f"synth_sheet: the sheet is uploaded (asset {record['assetId']}) and this render differs; kept the "
              "uploaded sheet and its offsets. Pass --rebuild to replace it (that spends an audio upload).")
        old = json.loads(MANIFEST.read_text())
        old["muted"] = sorted(MUTED)
        MANIFEST.write_text(json.dumps(old, indent=1) + "\n")
    else:
        SHEET.parent.mkdir(parents=True, exist_ok=True)
        SHEET.write_bytes(data)
        MANIFEST.write_text(json.dumps({
            "file": str(SHEET.relative_to(REPO)).replace("\\", "/"), "sampleRate": SR, "gapSeconds": GAP_S,
            "seconds": round(len(sheet) / SR, 2), "muted": sorted(MUTED), "clips": manifest}, indent=1) + "\n")
        print(f"wrote {SHEET.relative_to(REPO)} ({len(data) // 1024} KB, {len(sheet) / SR:.2f} s, {len(manifest)} clips)")
    up.write_sound_sheet(up.load_state())
    print(f"wrote {MANIFEST.relative_to(REPO)}, {up.SOUND_SHEET.relative_to(REPO)} and previews in "
          f"{PREVIEW.relative_to(REPO)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
