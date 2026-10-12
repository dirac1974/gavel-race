# Systems consult: D-071 tap preview as built

## My required changes (votes-plans-systems.md): status

| Change | Status |
| --- | --- |
| Trust row | Landed: −0.70 points (limit +3) |
| Masher | Landed: at most +0.59 ft and 0 messages; clean-pass rule; `capBackFeet` 6 |
| Nudge stacked in the overlap test | Landed (`baseFall` cap); 2 own-screen frames in 1 of 3,840 races, inside Ruling 2's gate |
| Compute only for human races at pass ends | Landed (`RaceService` ~:822, :1083) |
| Allocation-free `step` | Landed (5,000 steps, 0 KB) |
| `RaceSend` profiled, PLAYTEST < 1 ms | Landed (`:981`, PLAYTEST "Server cost") |
| Chip wording | **Not met** (see below) |

**Integrity of the held cue: no concern.**
- `TapHeld` is unreliable, goes to the rider only, is limited to 2 Hz, and reflects only `previewOwn`: your own skill, with no luck and no other lane.
- The per-tap labels already give a macro richer timing feedback.
- A masher is never held, so the cue rewards nothing new.

## MUST-FIX

1. **Remove "Pulling away!"** (`TapMessage.TEXT.away`, `TapPreview.message` returning `"away"` when drawn 1st).
   - I required: never "leading" or "winning" before the lock. "Pulling away" says leading.
   - Our own trust row shows that a horse drawn 1st at the lock finishes 4th or worse **44%** of the time.
   - Telling a kid they're pulling away just before the luck reorder is exactly the "it's rigged" moment.
   - **Fix:** always return `"up"` ("Giddy-up! Moving up!"). Update the copy in `GameConfig` and `TapCue`, and add a test that no message text contains "away", "lead" or "win".

## Sign-off

**YES** after the must-fix. I accept Ruling 2 (boxed share ≤ 55%, no regression). The Smart Steer "find room" study belongs with David as a recalibration.
