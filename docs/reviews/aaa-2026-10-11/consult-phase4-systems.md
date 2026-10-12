# Systems consult: Phase 4 and overall sign-off (2026-10-11)

## Phase 4 checks

**Performance on phones.** No must-fix.
- **TrackDressing** has hard caps in config (`trackDressing.maxParts = 350`, `maxBeams = 80`). It is built once on the server and has no per-frame cost.
- **TrackLife** updates at 30 Hz, but each tick only writes about 30 texture offsets and flag positions, with no allocation. It stops under Reduced Motion.
- **Should-fix:**
  - Run TrackLife only while the player is within `spectate.keepStuds` of a course; today it also ticks at the barn and the Trail.
  - On phones, use 15 Hz (`trackLife.updateHz`, `phoneHz`).
  - Measure frame time on the emulator in the PLAYTEST performance pass.

**Big Board.** It shows only lane chips, lane numbers and horse names for the top 4 (`TrackLifeView.boardRows`), refreshed at 4 Hz. It shows no win %, purse or prize, and the comment and the config both say so. That satisfies rule 1.

**Economy.** Phase 4 doesn't touch purses, prices, Energy, jobs or Diamonds. The music bed is id 0, and the confetti and stars are draw-only.

**MUST-FIX: none.**

## Scorecard against my original top 5

| # | Must-do | Status |
| --- | --- | --- |
| 1 | Ladder on realistic Ratings | **Done.** D-068 values (anchors 32/35/38/48/56, points 100/200/450/900, ceilings 55/57/60/66). Light-player test passes. Old saves are covered in PLAYTEST. |
| 2 | Friends can race together | **Done, better than asked.** Open Practice at Rookie settings with equal horses, "Race with [friend]", and a server friendship check. |
| 3 | Green Cash means something | **Open: launch gate.** STATUS has it as a launch gate (cosmetics sink, then flatter purses). Under the new ladder, inflation is worse (about 106k by week 12). |
| 4 | Feature freeze and a core playtest | **Partly done.** The `corePlaytest` switch is built, and Phases 1–4 added feel only, no new systems. The playtest itself hasn't run, so the Phase 1 gate and next-day return are still unmeasured. The word pass is partly done: bows for 🎀, goodbye rosettes on the Wall and the Horse Book "Prizes" page are queued. |
| 5 | Legend undo, no early suggestion | **Done.** `Leagues.unretire`, `career.suggest = false`. The plaque comes down on unretire, which is logged. |

The lower items from my review:
- **Race before chores:** partly done. The pill puts racing first for a new player's first 3 races, not every day.
- **Spa folded into the Vet:** open, deferred.
- **Repeatable Stable Star tiers:** open. It matters before the day-30 point.
- **Champion endgame:** logged in REVIEW_QUEUE.

## Overall verdict

The progression cliff and the friend lockout, the two worst systems problems, are fixed and backed by sims and tests. Those changes and the others are config-backed and reversible.

Two things still stand between this and players:
1. **Nothing has run in Studio.** Four phases of new code sit on a core that hasn't been played. David's playtest, starting with `corePlaytest = true`, is now the only thing that matters.
2. **Green Cash has no value past Rookie.** That is correctly a soft-launch gate, not a playtest blocker.

## Sign-off

**YES** on Phase 4, and **YES** overall for the playtest. Not for soft launch until the Green Cash sink gate is closed and Stable Star repeats exist.
