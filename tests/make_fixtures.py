"""Regenerate tests/fixtures/race_cases.json from the Python reference."""
import json
import random
import sys
from dataclasses import asdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
from gavel_race_v2 import Config, base_chances, lock_purses, skills, live_chances  # noqa: E402


def main() -> None:
    rng = random.Random(2026)
    cases = []
    for i in range(20):
        cfg = Config(T=rng.choice([22.0, 18.0, 14.4, 12.0]), kappa=rng.choice([1.0, 1.2]),
                     B=rng.choice([20, 50, 120, 300, 750]))
        ratings = [round(rng.uniform(40, 80), 1) for _ in range(8)]
        scores = [round(rng.uniform(0, 100), 1) for _ in range(8)]
        q = base_chances(ratings, cfg)
        R = skills(scores, cfg)
        cases.append({
            "id": i, "config": asdict(cfg), "ratings": ratings, "scores": scores,
            "expected": {"q": q, "purses": lock_purses(q, cfg), "R": R,
                         "p": live_chances(q, R, cfg)},
        })
    out = Path(__file__).parent / "fixtures" / "race_cases.json"
    out.write_text(json.dumps(cases, indent=1) + "\n")
    print(f"wrote {len(cases)} cases to {out}")


if __name__ == "__main__":
    main()
