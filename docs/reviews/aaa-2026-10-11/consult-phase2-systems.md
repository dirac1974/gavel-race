# Systems consult: built Phase 2 (2026-10-11)

Scope: the loop and the money-safety view of the first minute, Race again, the race-first pill, the Best ride rank and the warm-up. I read the diff of Advice, Tour, ResultsText, Hud and GameConfig, plus RaceService's join and job counting.

## Energy and napping: no bypass

- **Race again** fires the same `PressRace` as RACE!. The server still decides the race kind: `RaceService` (around `:421-427`) falls back to Practice when the horse can't enter a cash race.
- `ResultsText.nextKind` only picks the button's words. In the worst case, a stale client view shows "🏁 Race again" and the server then puts the kid in a Practice race. That is a cosmetic mismatch with no loss to the kid.
- **The race-first pill** (`Advice.luau`, `raceFirstUntilRaces` 3) skips resting horses and horses past their league's Rating ceiling. It counts `totals.races`, which only cash races raise, and those first races are free Rookie races anyway.
- Care is postponed for three races, not lost. The tour's next step is "feed", and the pill goes back to its normal order after that.
- **Best ride rank** is shown for the top 3 only, never as a list. It is cosmetic and ranks the ride, never a prediction, so there is no wagering concern. Its server switch, `results.riderRank`, can turn it off.

## Money and kid safety

- **💎 door: OK.** `firstMinute.hideGemPill` only adds a hiding condition. The pill still waits `DiamondProducts.afterRaceSeconds` (120 s) after a race, has no glow or pulse, and never opens the shop by itself. D-050 holds.
- **Held toasts** (≤ 60 s) are copy only.
- **Race again** is not a purchase prompt.

## MUST-FIX

None. Nothing bypasses Energy, the shop's closed-after-race rule holds, and no hard rule is touched.

## SHOULD-FIX

1. **A napping horse's Race again should point at what helps** (`ResultsText.nextKind` / `raceAgainLabel`, behind config):
   - If another stalled horse can race: "🏁 Race with Maple".
   - Otherwise, the pill offers the Energy top-up: "Feed Comet: +1 Energy" or the Spa.
   - Showing only "🎈 Practice race" keeps a napping kid in an endless prize-free loop and skips the care loop, which is the one place Energy ties care to racing.
2. **The 💎 pill should first appear only once the whole tour is done** (`tourDone`), not just after its race step. Its first appearance is then not tied to the first race, the moment D-050 protects. This is a one-line change from the race step to the whole tour.
3. **Practice races count toward the "race" jobs** (`RaceService.server.luau:1139`). That is fine for effort jobs. But with one-tap Race again, a napping kid can finish "Ride in 40 races" in Practice. Accept it (it rewards effort) and log it in D-067, or count Practice at half.
4. **Re-read the horse's Energy just before labelling Race again**, so the label matches the kind the server will choose. This is cosmetic.
5. **Warm-up** (`queueCard.warmUpRaces` 3): confirm in the playtest that it sends nothing to the server. Make sure it isn't counted by `Integrity` or toward `great_tap` jobs, or the warm-up becomes a job farm.

## Sign-off

**YES** for Phase 2, as built. The should-fix items can follow in Phase 3 or the playtest fixes.
