"""Overlap and jerk stress test for the debate-012 variants (Trip's own positions, before the lock).

Three riders press at once (a masher, a ◀▶ ditherer and a casual rider) among five bots.
Counts frames where two horses are within half a lane and 6 ft (the overlap test's rule), the
closest same-lane gap (within laneBand), and the fastest any horse falls back against the pace
(ft/s; D-055's jerk line is 20).
"""
import json
import random
import sys
from multiprocessing import Pool

import sim012 as M
import steering as S
import trip012 as T

COMBOS = [("D054", "d054", "off"), ("E10", "wait+tuck", "off"), ("E10w0", "wait+tuck", "off"), ("E10w", "wait+tuck", "off"),
          ("E10w", "wait+tuck", "any(comp)"), ("E09w", "wait+tuck", "off")]


def chunk(args):
    combo, cell, k0, k1 = args
    cfg = M.named_cfg(*combo)
    course, distance = S.cells()[cell]
    geo = T.phase_a(course, distance)
    res = {"overlap_frames": 0, "overlap_races": 0, "min_gap": 1e9, "back_max": 0.0, "races": 0, "frames": 0}
    for k in range(k0, k1):
        setup = S.race_setup(S.race_seed(9191, cell, k), distance)
        order = list(range(8))
        random.Random(setup["press_seed"]).shuffle(order)
        pols = ["bot"] * 8
        for idx, p in zip(order[:3], ("masher", "dither", "scripted")):
            pols[idx] = p
        st = T.new_state(S.posts(), setup["q"], setup["uniforms"], geo, cfg, [M.kind_of(p) for p in pols])
        rng = random.Random(setup["press_seed"] + 1)
        riders = {i: M.Rider(p, rng, setup["focal"]) for i, p in enumerate(pols) if p in M.HUMAN}
        sw = S.switch_tick(geo, cfg)
        tl = T.lock_time(geo)
        tick = 0
        ov = 0
        prev = list(st.off)
        while tick * 0.1 < tl - T.EPS:
            intents = []
            for i in sorted(riders):
                d = riders[i].press(st, i, tick)
                if d:
                    intents.append((i, d))
            T.step(st, setup["q"] if tick < sw else setup["p1"], intents, tick * 0.1, 0.1)
            for i in range(8):
                back = -(st.off[i] - prev[i]) / 0.1
                if back > res["back_max"]:
                    res["back_max"] = back
                prev[i] = st.off[i]
                for j in range(i + 1, 8):
                    dx = abs(st.x[i] - st.x[j])
                    if dx < cfg["laneBand"]:
                        res["min_gap"] = min(res["min_gap"], abs(st.off[i] - st.off[j]))
                    if dx < 0.5 and abs(st.off[i] - st.off[j]) < 6.0:
                        ov += 1
            tick += 1
            res["frames"] += 1
        res["overlap_frames"] += ov
        res["overlap_races"] += 1 if ov else 0
        res["races"] += 1
    return combo, res


def main():
    races = int(sys.argv[1]) if len(sys.argv) > 1 else 150
    tasks = [(c, cell, a, b) for c in COMBOS for cell in range(8) for a, b in S._chunks(races, 25)]
    with Pool() as pool:
        parts = pool.map(chunk, tasks)
    agg = {}
    for combo, r in parts:
        key = "|".join(combo)
        a = agg.setdefault(key, {"overlap_frames": 0, "overlap_races": 0, "min_gap": 1e9, "back_max": 0.0, "races": 0, "frames": 0})
        a["overlap_frames"] += r["overlap_frames"]
        a["overlap_races"] += r["overlap_races"]
        a["min_gap"] = min(a["min_gap"], r["min_gap"])
        a["back_max"] = max(a["back_max"], r["back_max"])
        a["races"] += r["races"]
        a["frames"] += r["frames"]
    for k, a in agg.items():
        print(f"{k:32s} races {a['races']:5d}  overlap races {a['overlap_races']:3d} frames {a['overlap_frames']:4d}  "
              f"closest same-lane {a['min_gap']:.2f} ft  fastest fall-back {a['back_max']:.1f} ft/s")
    M.RESULTS.mkdir(exist_ok=True)
    (M.RESULTS / "stress.json").write_text(json.dumps(agg, indent=1))


if __name__ == "__main__":
    main()
