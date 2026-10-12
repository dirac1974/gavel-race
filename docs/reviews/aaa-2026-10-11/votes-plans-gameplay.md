# Gameplay vote on greencash-plan.md (2026-10-11)

**Verdict: AGREE-WITH-CHANGES.**

## Skill premium and reasons to race well

- The premium survives. Purses are B/q and place prizes are multiples of B, so how much skill earns relative to average play is unchanged: about 1.5× cash per race, and κ is unchanged.
- The cash gap between leagues shrinks from 37× to 4×. That's fine, because the reasons to race well move to:
  - **League Points:** faster Cups, which unlock higher `bestLeague` shelves;
  - **"Best ride"** on the results card;
  - **the Cup itself.**
- Earned prestige through tiers is a better skill reward for kids than a bigger number.

## Race math and parity

- Flattening B doesn't touch the race math. B sets purses only, never q, p′, offsets or the draw.
- The 300-race parity fixtures draw B from a fixed list (`make_fixtures.py:61,184`) as math inputs, not as the game's leagues.
- Rounding error at B 20–80 is at most 0.5q/B, under 1% (D-017 already accepts this for Rookie).

## Conflict with the tap-gap plan

- **None in function.** Tap-gap is draw-only and reads live chances, never purses.
- **Numbering clash:** both plans claim D-070.

## Required changes

1. **Renumber** one of the plans. I suggest Green Cash D-070 and tap-gap D-071. Fix the REVIEW_QUEUE rows to match.
2. **Leave the parity fixtures alone.**
   - Change only `LEAGUE_B` in `src/gavel_race_v2.py` and `sims/economy.py`, the `test_sims.py:228` assertion, and the B row of the V2_PROPOSAL table.
   - Optionally add 30/45/60/80 to the fixture B list (an append, not a replace), then regenerate.
3. **Add a skill test to `--greencash`.** It should check that a casual-perfect kid reaches each tier's first item in no more sessions than a casual kid, and sooner in at least 3 of 5 leagues. A 1.33× premium ratio alone doesn't show that racing well matters to the kid.
4. **Keep wish prompts away from the race loop.** No wish chip or "You can build" pill on the results card, and none while "Race again" is showing, not even after 120 s. Racing again stays the first action after a race.
