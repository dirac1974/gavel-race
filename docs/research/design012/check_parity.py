"""trip012 with its default CONFIG must reproduce src/trip.py exactly (same trips, lanes, offsets)."""
import random
import sys
from pathlib import Path

REPO = Path(r"C:\Users\David S\Documents\GitHub\gavel-race")
sys.path.insert(0, str(REPO / "src"))
sys.path.insert(0, str(REPO / "sims"))
sys.path.insert(0, str(Path(__file__).parent))
import trip  # noqa: E402
import trip012  # noqa: E402
import steering as S  # noqa: E402


def run(mod, geo, setup, pols, seed):
    kinds = [S.KIND.get(p, "smart") for p in pols]
    st = mod.new_state(S.posts(), setup["q"], setup["uniforms"], geo, mod.CONFIG, kinds)
    rng = random.Random(seed)
    dt = 0.1
    t_lock = mod.lock_time(geo)
    sw = S.switch_tick(geo)
    tick = 0
    trace = []
    while tick * dt < t_lock - mod.EPS:
        intents = []
        for i, p in enumerate(pols):
            if p == "masher" and rng.random() < 0.4:
                intents.append((i, -1 if rng.random() < 0.5 else 1))
        ans = mod.step(st, setup["q"] if tick < sw else setup["p1"], intents, tick * dt, dt)
        trace.append((tuple(st.x), tuple(st.off), tuple(ans)))
        tick += 1
    mod.lock(st)
    return mod.trip_values(st), trace


bad = 0
total = 0
for ci, (course, dist) in enumerate(S.cells()):
    geo_a = trip.phase_a(course, dist)
    geo_b = trip012.phase_a(course, dist)
    for k in range(25):
        setup = S.race_setup(S.race_seed(777, ci, k), dist)
        pols = ["bot"] * 8
        pols[setup["focal"]] = "masher"
        pols[(setup["focal"] + 3) % 8] = "masher"
        ta, xa = run(trip, geo_a, setup, pols, k)
        tb, xb = run(trip012, geo_b, setup, pols, k)
        total += 1
        if ta != tb or xa != xb:
            bad += 1
print(f"parity: {total - bad}/{total} races identical")
sys.exit(1 if bad else 0)
