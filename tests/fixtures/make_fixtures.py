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
    out = ROOT / "tests" / "fixtures" / "race_math.json"
    out.write_text(json.dumps({"cases": cases, "windows": windows}))
    print(f"wrote {len(cases)} cases to {out.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
