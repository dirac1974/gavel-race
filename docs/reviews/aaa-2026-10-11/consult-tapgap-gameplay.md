# D-071 tap preview: final consult (gameplay, plan owner)

## Does it close problem #1?

**Yes, enough for the playtest.**
- From the gate, good taps move your horse within about 2 s when there's room.
- When it's held behind a horse, the pressure cue and "Find a gap! ◀ ▶" or "Your taps still count!" show that the taps are pushing.
- It's draw-only and byte-identical in its decisions, shows no luck, and no masher messages appear.

## MUST-FIX

1. **Late taps read as misses in the preview.**
   - **Where:** `tapPassEnd` counts a pass once `p.t1 <= now()` (`RaceService.server.luau:1077-1079`), and the loop wakes at `segPasses[k+1].t1` (`:1110-1116`).
   - **Why it's wrong:** taps arrive up to a one-way latency late. Their claimed time is kept, but up to `maxTapRewindSeconds`, 0.3 s. A Perfect near a pass's turnaround end, from a phone at about 150 ms ping, can still be in flight. That pass scores 0 in the preview.
   - **How bad:** at n = 2–4 passes a single wrongly zeroed Perfect halves or quarters the gain, and the horse jitters back. This hits mobile kids most.
   - **Fix:** wake at, and count passes with, `p.t1 + GameConfig.maxTapRewindSeconds <= now()`. That adds 0.3 s, still inside the 2 s target. Re-run test (d) with a 0.15 s arrival delay on taps.

## SHOULD-FIX

- **Same issue in the stretch.** `previewStretch` has the same `p.t1 <= now()` (`:1053`). Use the same grace there.
- **Smart Steer "find room" study.** Ruling 2's follow-up, which needs David's approval.
- **Playtest note.** Record whether the "Moving up!" message and the place-badge pop feel like too much on top of the per-tap word.

## Scorecard row (updated)

| # | Must-do | Status |
| --- | --- | --- |
| 2 | Make taps move the horse | **Done (pending MF-1).** Nudge, surges, word at the marker, the post-lock preview, and now the D-071 draw-only pre-lock layer from the gate, the steering-off whole race, and the held cue. Open as a follow-up: the 53% boxed share, which needs a Smart Steer recalibration (Ruling 2). |

## Sign-off

**Yes for David's playtest once MF-1 is in.** The deciding test is still the playtest question: "Can you tell how your taps changed the result?"
