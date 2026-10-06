"""Inward-press reach (pure lane mechanics, no baseline needed) for several motion / press rules.
all = every inward press (D-054's metric); first = no press by the rider in the previous 3 s;
serv = the lane had room or a tuck slot at the press; chips = presses still waiting after 1 s
with no glide and no tuck-back, per race, before and after the 10 s chip limit."""
import json
import random
import sys
from multiprocessing import Pool

import sim012 as M
import steering as S
import trip012 as T

COMBOS = [("D054", "d054"), ("E10w", "d054"), ("E10w", "wait3+tuck"), ("E10w", "waitinf+tuck"), ("E09w", "wait3+tuck"),
          ("E09w", "waitinf+tuck")]
if len(sys.argv) > 2 and sys.argv[2] == "final":
    COMBOS = [("E10w", "waitinf+tuck", "repeat(comp)"), ("E10w", "waitinf+tuck", "repeat2s"), ("E09w", "waitinf+tuck", "repeat2s")]
M.BOXED["waitinf+tuck"] = {"blockedPress": "wait", "gapWaitSeconds": 1.5, "gapWaitInSeconds": 1e9, "tuckAfterSeconds": 0.0}


def chunk(args):
    combo, cell, k0, k1 = args
    M.BOXED["waitinf+tuck"] = {"blockedPress": "wait", "gapWaitSeconds": 1.5, "gapWaitInSeconds": 1e9, "tuckAfterSeconds": 0.0}
    cfg = M.named_cfg(*combo)
    course, distance = S.cells()[cell]
    geo = T.phase_a(course, distance)
    agg = {}
    for pol in ("scripted", "rail"):
        a = {"ok3": 0, "n": 0, "first_ok3": 0, "first_n": 0, "serv_ok3": 0, "serv_n": 0, "presses": 0, "chip": 0,
             "races": 0, "chips_limited": 0, "brushes": 0, "brush_races": 0, "charged_races": 0, "cost": 0.0}
        for k in range(k0, k1):
            setup = S.race_setup(S.race_seed(S.REPORT_SEED, cell, k), distance)
            pols = ["bot"] * 8
            pols[setup["focal"]] = pol
            r = M.run_race(geo, setup, pols, cfg)
            for key in ("ok3", "n", "first_ok3", "first_n", "serv_ok3", "serv_n", "presses", "chip"):
                a[key] += r["reach"][key]
            a["races"] += 1
            f = setup["focal"]
            a["brushes"] += r["brushes"][f]
            a["brush_races"] += 1 if r["brushes"][f] > 0 else 0
            a["charged_races"] += 1 if r["bump_cost"][f] > 0 else 0
            a["cost"] += r["bump_cost"][f]
        agg[pol] = a
    return combo, cell, agg


def main():
    races = int(sys.argv[1]) if len(sys.argv) > 1 else 150
    tasks = [(c, cell, a, b) for c in COMBOS for cell in range(8) for a, b in S._chunks(races, 25)]
    with Pool() as pool:
        parts = pool.map(chunk, tasks)
    out = {}
    for combo, cell, agg in parts:
        key = "|".join(combo)
        row = out.setdefault(key, {}).setdefault(" ".join(S.cells()[cell]), {})
        for pol, a in agg.items():
            b = row.setdefault(pol, {k: 0 for k in a})
            for k, v in a.items():
                b[k] += v
    name = "reach_final.json" if len(sys.argv) > 2 and sys.argv[2] == "final" else "reach.json"
    (M.RESULTS / name).write_text(json.dumps(out, indent=1))
    q = lambda a, b: f"{a / b:.0%}" if b else "-"
    for key, cells in out.items():
        print("==", key)
        for cell, row in cells.items():
            c, r = row["scripted"], row["rail"]
            print(f"  {cell:15s} casual all {q(c['ok3'], c['n'])} first {q(c['first_ok3'], c['first_n'])} serv {q(c['serv_ok3'], c['serv_n'])} "
                  f"waits>1s/race {c['chip'] / c['races']:.2f} brushes/race {c['brushes'] / c['races']:.2f} brush races {c['brush_races'] / c['races']:.1%} charged {c['charged_races'] / c['races']:.1%} | rail all {q(r['ok3'], r['n'])} first {q(r['first_ok3'], r['first_n'])} serv {q(r['serv_ok3'], r['serv_n'])}")


if __name__ == "__main__":
    main()
