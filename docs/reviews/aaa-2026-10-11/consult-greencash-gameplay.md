# Green Cash consult: gameplay (2026-10-11)

## Skill test: holds

`greencash-sim.md:84` shows a perfect rider reaching each shelf's first item at sessions 1/2/6/13/30. A casual kid gets there at 1/3/8/18/38.
- No shelf is later, and 4 of 5 are sooner. Rookie ties at session 1.
- The per-race premium is 1.46–1.69×, all at or above 1.33×.

Racing well visibly buys the next shelf sooner.

## Change #4: landed

- `Advice.buildPill` returns nil when `resultsOpen`, `raceAgain` or `busy` is set, or within `pillAfterRaceSeconds` (120) (`Advice.luau:98-99`).
- `StableBoard` passes `raceAgain = RaceState.resultsOpen` (`StableBoard.client.luau:401`) and hides the pill on results (`:495`).
- The wish chip sits on the dock, and the dock hides while riding, on results and in replays (`Hud.client.luau:517`).

## Reasons to race well higher up

- **Bronze–Gold: fine.** Points speed up Cups, which open shelves, alongside "Best ride".
- **Champion is thin.** Engaged kids own all 39 items about 4 weeks after reaching Champion (`greencash-sim.md:108`). Phase 3 also has the average kid's Champion win rate drifting to about 54%. Once there, there's nothing to buy and little rivalry, so taps matter less. Not blocking for launch, since few kids get there in month 1.

## MUST-FIX

None.

## SHOULD-FIX (after the playtest)

1. Champion bots rated `max(anchor, rating − 9)` (from the Phase 3 consult).
2. A milestone-grown Champion shelf, never timed (sim option b).
3. Keep any Diamond "time skip" off Energy, training and the queue (`greencash-sim.md:96`). Otherwise Diamonds turn into races, cash and League Points.

## Sign-off

**Yes.**
