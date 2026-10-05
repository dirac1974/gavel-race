#!/usr/bin/env python3
"""Generate Python reference fixtures for the Luau parity tests.

Writes tests/fixtures/race_math.json. Deterministic (fixed seed).
"""

import json
import random
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "src"))

import gavel_race_v2 as m  # noqa: E402
import race_rating as rr  # noqa: E402
import stride as st  # noqa: E402
import pace_meter as pm  # noqa: E402


class ListRng:
    """Replays a fixed list of uniforms, like the Luau test stub."""

    def __init__(self, values):
        self.values = list(values)
        self.i = 0

    def random(self):
        v = self.values[self.i]
        self.i += 1
        return v


def main() -> None:
    rng = random.Random(20261004)
    cases = []
    for _ in range(300):
        n = rng.choice([2, 4, 6, 8, 8, 8])
        cfg = m.Config(
            T=rng.choice([12.0, 14.4, 18.0, 22.0]),
            q_floor=rng.choice([0.0, 0.025, 0.04]),
            kappa=rng.choice([0.6, 1.0, 1.2, 1.4]),
            r_floor=rng.choice([-1.0, -0.5, -0.25]),
            B=rng.choice([20, 50, 120, 300, 750]),
        )
        ratings = [round(rng.uniform(20, 95), 3) for _ in range(n)]
        scores = [round(rng.uniform(0, 100), 3) for _ in range(n)]
        uniforms = [rng.random() for _ in range(n)]
        q = m.base_chances(ratings, cfg)
        R = m.skills(scores, cfg)
        p = m.live_chances(q, R, cfg)
        cases.append({
            "cfg": {"T": cfg.T, "qFloor": cfg.q_floor, "kappa": cfg.kappa, "rFloor": cfg.r_floor, "B": cfg.B},
            "ratings": ratings,
            "scores": scores,
            "uniforms": uniforms,
            "q": q,
            "purses": m.lock_purses(q, cfg),
            "R": R,
            "p": p,
            "finish": [i + 1 for i in m.draw_finish(p, ListRng(uniforms))],  # 1-based for Luau
        })
    windows = [{"d": d, "s": m.window_score(d)} for d in (-0.5, 0, 0.1, 0.25, 0.5, 0.99, 1, 1.5)]
    ratings_cases = []
    strategies = [None, "FrontRunner", "Stalker", "Closer"]
    for _ in range(300):
        stats = {k: round(rng.uniform(-10, 110), 2) for k in ("speed", "accel", "stamina", "grit", "focus")}
        cond = {"distance": rng.choice(list(rr.DISTANCE_WEIGHTS)), "surface": rng.choice(list(rr.SURFACE_SHIFT)),
                "weather": rng.choice(list(rr.WEATHER_SHIFT))}
        care, pilot, bond = rng.uniform(-0.2, 1.2), rng.uniform(0, 1), rng.uniform(0, 1)
        strategy = rng.choice(strategies)
        ratings_cases.append({"stats": stats, "cond": cond, "care": care, "pilot": pilot, "bond": bond,
                              "strategy": strategy or "", "rating": rr.rating(stats, cond, care, pilot, strategy, bond)})
    stride_cases = []
    for _ in range(200):
        lo = rng.choice([0.42, 0.46, 0.50, 0.55, 0.60])
        spec = {"beats": 8, "intervalLo": lo, "intervalHi": lo + rng.choice([0.0, 0.05, 0.06]),
                "drift": rng.choice([0.0, 0.02, 0.03]), "leadChange": rng.random() < 0.3, "half": 0.08}
        uniforms = [rng.random() for _ in range(spec["beats"])]
        start = round(rng.uniform(0, 100), 3)
        beats = st.schedule(ListRng(uniforms), start, spec["beats"], spec["intervalLo"], spec["intervalHi"],
                            spec["drift"], spec["leadChange"])
        sd = rng.choice([0.005, 0.03, 0.06])
        taps = [b + rng.gauss(-0.02, sd) for b in beats if rng.random() > 0.1]
        taps += [rng.uniform(beats[0] - 0.3, beats[-1] + 0.3) for _ in range(rng.choice([0, 0, 1, 3]))]
        taps.sort()
        stride_cases.append({"spec": spec, "uniforms": uniforms, "start": start, "beats": beats, "taps": taps,
                             "score": st.score(beats, taps, spec["half"]),
                             "gaps": st.gap_errors(beats, taps, spec["half"])})
    pace_cases = []
    for _ in range(120):
        spec = {"sweepSeconds": rng.choice([1.1, 1.3, 1.6, 2.0, 2.4]), "speedDrift": rng.choice([0.0, 0.08, 0.15]),
                "shiftMin": 2, "shiftMax": 3, "centerRange": rng.choice([0.0, 0.5, 0.6])}
        start = round(rng.uniform(0, 100), 3)
        duration = rng.choice([12.0, 20.0, 36.0])
        uniforms = [rng.random() for _ in range(400)]
        passes = pm.schedule(ListRng(uniforms), start, duration, spec["sweepSeconds"], spec["speedDrift"],
                             spec["shiftMin"], spec["shiftMax"], spec["centerRange"])
        sd = rng.choice([0.01, 0.05, 0.12])
        taps = [pm.ideal_time(p) + rng.gauss(0, sd) for p in passes if rng.random() > 0.15]
        taps += [rng.uniform(start, start + duration) for _ in range(rng.choice([0, 2, 6]))]
        taps.sort()
        mean, errs, single = pm.score(passes, taps)
        pace_cases.append({"spec": spec, "start": start, "duration": duration, "uniforms": uniforms,
                           "passes": [p._asdict() for p in passes], "taps": taps, "score": mean, "errors": errs,
                           "single": single})
    out = ROOT / "tests" / "fixtures" / "race_math.json"
    out.write_text(json.dumps({"cases": cases, "windows": windows, "ratings": ratings_cases, "stride": stride_cases,
                               "pace": pace_cases}))
    print(f"wrote {len(cases)} cases to {out.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
