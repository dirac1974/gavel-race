# Race realism: plan consensus (2026-10-12)

Plans: `racing-plan.md` (gameplay, D-072) and `steeplechase-plan.md` (systems, D-073 Hurdles, D-074 forward jump). Votes: `votes-*.md`. All four designers voted AGREE-WITH-CHANGES on both plans; none voted BLOCK. Every required change in the vote files is part of the spec. The tech lead settled the splits below.

## Splits settled

| Topic | Positions | Ruling |
| --- | --- | --- |
| Move denial rate | gameplay: 20–35% of moves denied; feel: a **lit** arrow is denied at most 10% of the time | Two gates. Presses on a lit arrow are denied ≤ 10%. All move attempts are denied 20–35% (most denials are presses with no room, where the arrow is unlit and "No room yet!" shows). |
| Fence zone length | systems 60 ft; UI/UX 90 ft (when the ring starts); gameplay about 116 ft; feel "ends 1.8 s before the zone" | The zone runs from **90 ft before** each fence (the ring starts there) to **30 ft after** it (`hurdles.zoneBeforeFeet` 90, `zoneAfterFeet` 30). A pass, move or lane change may start only if its glide ends at least 1.8 s before the zone. Bots don't start a pass within 150 ft of a zone. |
| Chip text inside a zone | "Jump first!" (systems, feel) / "After the jump!" (UI/UX) | **"Jump first!"** The press is dropped and the pip is kept. It never says "Door shut!" inside a zone. |
| The move in Hurdles | gameplay: intended; UI/UX: off until each is playtested on its own | Ship it **off** (`hurdles.movesEnabled = false`), since Hurdles ships Practice-only first. A jump scoring 80+ still feeds pips (2 clean taps' worth) once moves are on there. |
| The move counting (old phase C) | gameplay put it behind David's approval | David asked for the stored move himself, so it counts now behind `steering.move.scale` (provisional, REVIEW_QUEUE). The plan's phases B and C merge. |
| Onboarding | gameplay: buttons from race 1 | UI/UX staging: race 1 shows the ◀ ▶ buttons only, race 2 shows the ghost-thumb tip, race 3 shows the move pips. In the first 3 races a kid's own presses can't push τ below 0 (systems). |

## Binding cross-cutting requirements
- **Fairness (systems):**
  - Bots make moves at an average kid's rate, and Smart Steer's automatic move counts in the baseline, so humans gain no edge over bots and a passive kid nets zero.
  - The move changes the winner in ≤ 2% of races and any place in ≤ 8%.
  - Trip τ at p99 stays ≤ +0.04.
  - Cash per race moves ≤ 2%.
  - Post and style bias ≤ 0.002.
- **Phase A changes outcomes**, so it needs Python parity (`src/trip.py`, fixtures) and the full sim gates before David plays it.
- **Feel:**
  - Drift comes from two mixed waves, capped at 3 ft/s between neighbours, with no pulsing.
  - Every pass shows the two horses alongside for at least 0.8 s, and a bot shutting the door visibly turns toward the rider.
  - Nothing pops or teleports at 10 Hz playback.
- **UI/UX:**
  - Gold chevron pips, 24 px.
  - Labels never change mid-race; a lit arrow gets a gold rim and a pulse.
  - 16 px dead zone round the pad.
  - One message at a time, in a fixed priority order.
  - Copy: "Nice move!", "No room yet!", "Jump first!".
- **Hurdles:**
  - Fences on straights only.
  - A screen-space ring that closes from 160 to 64 px.
  - The arc follows track distance and always clears the brush.
  - The tap-preview lead eases back to ≤ 3 ft before a fence (`tapPreview.fenceCapFeet`).
  - The camera lifts during the jump.
  - Fence sounds map to existing clips; no Meshy.
  - Practice-only first. Rated Hurdles from Bronze only once the skill premium is within ±10% of flat.

## David's ruling on Hurdles (2026-10-12, supersedes the fence-zone rows above)
> "the hurdles race should not have passing and all horses should stay in their lane"

- In a Hurdles race every horse keeps its post lane from the gate to the finish:
  - no lane changes;
  - no passing manoeuvres;
  - no filing in;
  - no shut doors;
  - no stored move (`hurdles.movesEnabled` is removed; moves don't exist in Hurdles).
- The steer buttons and keys are hidden and sunk in Hurdles. The tap button is used for pace and for the fences.
- Order changes only from straight-line pace, jumps and luck, drawn as horses gaining or losing ground in their own lanes.
- These are dropped: the fence-zone rows, "Jump first!", the 150 ft no-pass rule, the Hurdles pass and boxed gates, and fence jumps feeding pips.
- Trip τ in Hurdles is 0 for everyone. Lanes are fixed, so there's no ground or draft difference to score.
- Post fairness: posts are already random. Lanes stay equal, because fences sit on the straights only and τ is 0.
- This is David's decision, not provisional. Record it in DECISIONS as decided by David.

## Build order
1. **Quick fixes (in progress):** the forward jump and tucked pose (D-074); steer keys never turn the camera.
2. **Phase A, the field:**
   - horses file in;
   - running styles and drift;
   - passing mostly on the straights, with doors shut;
   - buttons from race 1 with staged onboarding;
   - Python parity and the sims.
3. **Phase B, the move:** pips, the surge, denial, bot moves, and counting behind `move.scale`.
4. **Phase C, Hurdles:** a Practice-only slice.

After each phase: code review, then a designer consult, with fixes before the next phase.
