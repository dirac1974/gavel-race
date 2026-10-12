# Gameplay vote on steeplechase-plan.md (2026-10-12)

**Verdict: AGREE-WITH-CHANGES.**

## Agreed as written

- The forward jump.
- Hurdles first, Practice-only as the first slice.
- Fences on straights only.
- No falls and no refusals.
- Fence segments in the Python model with parity.
- The Dash deferred until passing works.

## Coupling ruling: fences, passing and the move

1. **Fence zones hold lanes**, from 60 ft before a fence to 30 ft after it.
   - No lane change, pass or move may **start** if its glide can't finish before the zone begins.
   - Effectively, nothing starts within `60 + glide` ft of a fence (about 116 ft at 1.0 s a lane).
   - A press inside a zone waits (D-057). Its pip is not spent until the glide starts.
2. **Moves are banned in fence zones.** The lit arrow and "Make your move!" are off there.
   - Coming out of a zone after a clean jump is the natural moment to move, and that is intended.
3. **A fence tap feeds the pips.**
   - A jump scoring at least `pipMinScore` (80) counts as **2** clean passes toward the 4-per-pip rule.
   - Okay, missed or doubled jumps count 0 and don't reset the count.
   - Mashers still earn nothing.
4. **Sim gate for Hurdles** (in `sims/steeple.py` with the racing-plan pack and pass rules):
   - at least 2 drawn passes a race;
   - the boxed share no worse than flat plus 5 points;
   - move denial still 20–35%.

## Other required changes

5. **The drawn horse must meet the fence when the ring closes.**
   - The tap preview and the nudge can draw your horse up to 17 ft ahead. The kid would see the horse reach the fence before the ring closes, and a tap timed to the picture would score late.
   - In fence zones, clamp the drawn lead to ≤ 3 ft: `tapPreview.fenceCapFeet = 3`, eased in and out at the D-071 rate limits.
   - Play the drawn jump at the server's ring close.
6. **Fence segments in TapPreview and PacePreview.**
   - Previews run only in pace segments.
   - A fence close calls `TapPreview.closed`.
   - Re-run every D-071 gate on Hurdles races.
7. **Copy test:** add "fall", "crash", "refuse" and "unseat" as planned. Also add "jockey off".

## Note on racing-plan.md: Phase C is in scope now

David asked for the stored move himself, so Phase C ships as **provisional** in this round.
- It sits behind `steering.move.scale`: 1 counts (`tauPerMove 0.008`, at most 2 counted); 0 is cosmetic.
- It needs the §4 parity and sim gates.
- Log it to D-072 and REVIEW_QUEUE.

Phases B and C merge. Nothing else in racing-plan.md changes, apart from the fence-zone rules above.
