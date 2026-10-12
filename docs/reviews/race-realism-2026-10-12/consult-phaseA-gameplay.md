# D-072 phase A consult: gameplay (2026-10-12)

Static review: `src/trip.py`, `Trip.luau`, the `GameConfig.steering` blocks (`:125-158`), phaseA-sim (interim), phaseA-rulings, phaseA-code-review. No sims run.

## Does it deliver what David asked for?

**Yes, by design.**
- **Filing in:** home lane 1, bots spread 50/35/15 across lanes 1–3, filing in from 2 to 12 s after the gate.
- **A flowing pack:** running styles plus drift.
- **Passing:** bots pass, mostly on straights (70–100% of passes in the interim run).
- **Shut doors:** 3–8 a race.
- **Boxed share:** 66% → 23% in the Python stand-in.

**Not yet in the game.** It runs against D-057's baseline, which has no style row (code review B1).

## Rulings

1. **Passes per race.**
   - Trip passes: **Sprint ≥ 1, Mile ≥ 2, Classic and Marathon ≥ 3**, at most 10.
   - Drawn overtakes (1 length clear, held 2 s, ruling 8): **3–12 a race**.
   - New gate, because this is what David sees: **at least one overtake within 60 ft of the rider and 3 lanes, in ≥ 70% of races.**
2. **Straight/turn 1.0 / 0.25: keep.** It produces "easier on the straight" with turn passes still possible.
3. **Doors 0.3 / 1.5 s / 5 s gap: keep.**
   - Add a rider gate: of a non-learner rider's outward presses that would otherwise have room, doors shut **≤ 25%**.
   - `steerView.shutYawDeg` 3 → **5**, so the block reads.
4. **Learner floor: sound.**
   - It is τ = max(own, passive shadow). Shadows are deterministic, take pre-drawn uniforms, and see no luck.
   - The code review's "τ ≥ 0 for free" is wrong. The floor is the shadow's τ, not 0, so a press that changes nothing gives no edge (`trip.py:1443-1453`).
   - The real edge is option value on presses that do change something. Gate: **a random-press learner's mean τ over a passive kid ≤ +0.004**, in the first 3 races only.
   - Count only accepted, queued or brush presses as forks; that saves the shadow cost.
   - Server cost: `RaceSend` ≤ 1 ms with 8 learners. If it's over, cap shadows at 4 per race (the oldest learners keep their floor).
5. **"No room yet!" and lit arrows: right.**
   - A lit arrow is a promise, so doors may deny a lit arrow **≤ 10%** of the time.
   - Keep `doorWouldShut` greying the arrow ahead, so most door blocks look like "no room", not a broken promise.
   - Copy: "No room yet!" with the "!" (code review nit).

## MUST-FIX before David plays phase A

1. **Calibration** (code review B1): run `steering.py --write` (posts plus the style row with the rider entry), `make_fixtures.py`, and the gates. Otherwise ship with `file`, `pack`, `pass` and `doors` off.
2. **Commit trailer:** `Co-Authored-By: Claude <noreply@anthropic.com>` (B2).
3. **Gates updated to the rulings** (code review S3 plus the above):
   - post bias ≤ 0.002 kid-among-bots and ≤ 0.003 all-Smart;
   - press within 3 s ≥ 55% and within 6 s ≥ 85%;
   - `weaveWindowSeconds` **8**;
   - the overtake definition and the pass bands from ruling 1;
   - the door ≤ 25% and lit ≤ 10% gates;
   - the learner ≤ +0.004 gate.
4. **Fixed lanes after the lock:** guard `Trip.cosmetic` (`if st.fixed then return st.shown end`), make `Trip.submit` refuse with "fixed", and test the whole race to `raceTau` (code review S2). This is needed before Hurdles.
5. **Learner fork:** only on accepted, queued or brush answers (`trip.py:1207-1210`, the matching place in `Trip.luau`).

## Sign-off

**Not yet. Sign-off follows MUST-FIX 1–5 and green gates at full size.**

The design delivers what David asked for. The open risk is the numbers, not the shape.
