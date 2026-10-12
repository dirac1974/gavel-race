# Systems consult: D-072 phase A as built (2026-10-12)

## Rulings applied: checked in code

| Ruling | Status |
| --- | --- |
| Gates (`TARGETS_D072`) | Applied. Post bias 0.002 for a kid among bots, 0.003 for all-Smart; intent 0.55 at 3 s and 0.85 at 6 s; passive kid 0 ± 0.003; style ≤ 0.002; overtakes 3–15 (a length clear, held 2 s); masher 8.0 with the 8.5 fallback noted. |
| `weaveWindowSeconds` 8 | Applied (`GameConfig.luau:105`). The D-057 switch-back keeps 7. |
| `introRaces` 0 with the learner floor | Applied: `learner = { races = 3, tauFloor = 0 }`, and no shut doors on learners. |
| No human edge over bots | The "rider" style row is subtracted in `Trip.tau`. The gate is the passive-kid row; the numbers are pending. |
| Fixed lanes τ = 0 | `Trip.tau(..., fixed)` returns zeros. Ground, draft and presses are guarded (`Trip.luau:1077-1220`). |

**The learner floor is correct in kind.** The floor is the learner's own passive-race τ, not 0. So a press that changes nothing ("bounds" or "steady") leaves τ equal to the shadow and earns nothing. This resolves the code review's SHOULD 1 about τ ≥ 0 for free.

## MUST-FIX

1. **Measure the floor's option value.** The floor is `τ = max(actual, passive)`, so a learner's presses can only help. A masher in races 1–3 gets a free lottery worth E[max(0, actual − passive)].
   - Add a `learner_edge` row to `sims/steering.py`: mean τ of a learner masher and of a learner casual minus a learner passive, among bots.
   - **Gate ≤ +0.002.** If it fails, set `learner.races` to 2 or cap the gain (`τ ≤ passive + 0.004`).
2. **Bound the shadow cost.**
   - Every learner who presses forks a full TripState (deep copy) and steps it every tick. Eight learners mean 9× Trip work per tick, twice per server.
   - Add a Lune bench: an 8-learner race with everyone pressing stays ≤ 2 ms per tick on the dev machine.
   - Drop each shadow at the lock, once its floor is taken, to free memory.
   - Add `Trip.step` to the `RaceSend` profile line in PLAYTEST.
3. **Close the code review's open items before merge:**
   - the full `steering.py --write` (TripBaseline posts and styles);
   - re-stamped fixtures;
   - `Trip.cosmetic` guarded on `st.fixed`;
   - a whole-race `fixedLanes` test through `raceTau`.

## Exploits checked

- **Alt accounts:** at most 3 learner races each, in free Rookie races, worth about 0.1 S. Negligible.
- **Practice:** it doesn't advance `totals.races`, but Practice pays nothing, so staying a learner forever gains nothing.

## Sign-off

**CONDITIONAL YES.** I sign off once must-fixes 1–3 are in and the final calibration passes every `TARGETS_D072` gate, including passive kid 0 ± 0.003 and post bias for a kid among bots ≤ 0.002.
