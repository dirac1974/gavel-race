# Fun and return, phases 2–4: code review (2026-10-12)

Scope: the uncommitted D-076 (visible progress), D-077 (legs and the vet) and D-078 (life arc, Riding School) work against HEAD 2b70430 on `claude/race-realism`. The phase 5 visiting files were left out of scope.

Tests run (about 2.7 GB was free):
- Lune suites progress, legs, lifearc, ageing and career: **22,443/22,443 checks pass.**
- `tests/test_life_arc.py` and `tests/test_compile_all.py`: **28 passed.**
- `policy_guard.sh`: exit 0.
- New untracked files were grepped by hand. There are no wagering words (only the existing `stakesUnlockPoints` key appears, in a comment), no hurt words outside the lint list, and no model names.

## BLOCKING

**B1. A lent horse's 🏠 Home is hidden under 💵 Sell, and lent-horse sales follow the wrong rule.** `game/src/client/RehomeClient.client.luau:129` and `:136`, plus `game/src/shared/Market.luau:247-262`.
- `Market.rehomeBlock` never checks `h.lent`. With two or more racers, a lent horse therefore gets both "🏠 Home" (x −130) and "💵 Sell" (x −130).
- Sell is created second, so it sits on top. A kid who taps where Home should be gets "Sure? 💵", and a second tap sells the horse.
- With exactly one racer, selling the *lent* horse is refused as "Keep one horse racing with you!", even though selling it leaves that racer in place. The rule is wrong in both directions.

Fix: decide whether a lent horse can be sold.
- If it can't (simplest, and it matches "take back any time"), add `if h.lent ~= nil then return "Bring " .. h.name .. " home first!" end` to `rehomeBlock` and keep Home alone.
- If it can, skip the racers check for lent horses and draw Sell at x −256 on a lent row.

Add a lifearc test for whichever rule you pick.

## SHOULD

**S1. Class-up ceremonies stop after a move up within a session.** `game/src/client/ClassUp.client.luau:43-47`.
- `seen` is keyed by horse id only. After a promotion `path.at` drops (for example 5 → 1), so Rising Star and Open in the new league never count as a rise until the step passes the old league's top.
- Fix: key `seen` by `h.id .. ":" .. (h.league or "")`.

**S2. 💦 now means two things.** `game/src/shared/Legs.luau:18`
- "💦 Worked hard!" reuses the Grit / Mud Splash emoji (`Training.luau:23`, `HorseBook.luau:41`, training rides), which breaks D-064's one symbol per meaning. The consensus text chose it.
- Fix: pick another symbol (not 💧, which is the cold hose), or log the exception in DECISIONS.

**S3. The Cool-down Check shares the Spa's throttle.** `game/src/server/TrainingService.server.luau:842-844`
- `VetCheckStart` reads and writes `lastSpa`, so a Spa tap less than 1 s before silently drops the check's start, and the kid finishes 30 s of play only to hear "Let's do the vet check again!".
- Fix: give it its own `lastVetCheck` table and clear it on PlayerRemoving.

**S4. Traceability.**
- `DECISIONS.md` and `REVIEW_QUEUE.md` have no D-076, D-077 or D-078 entries yet. They need:
  - `declineScale = 1`, logged as "decided by David (real decline)" with the re-run numbers;
  - `recordBonusCap` 100;
  - `fromRaces` 26 and peakShare 0.90;
  - Rehome no longer limited to the corral (`MarketService.server.luau`, where the `atCorral` check was removed);
  - "Stakes" renamed to "Star Race" (hard rule 1).
- `Legs.luau`, `ClassPath.luau`, `HorseLook.luau`, `ClassUp.client.luau` and the three new test suites are untracked. They must be `git add`ed, or the `WaitForChild` calls yield forever.
- Stage the shared files (GameConfig, Profile, run_all, GrownUps) by hunk, because the phase 5 work is mixed into them.
- This session's injected commit trailer names a model. Use plain `Co-Authored-By: Claude` (rule 5).

**S5. `LendHorse` treats any value other than `false` as "lend".** `game/src/server/MarketService.server.luau:302`
- Fix: require `lend == true` to lend and `lend == false` to take back, and ignore anything else.

## NIT

- **N1.** `Market.luau:237`: `origin == nil and paid > 0` sells as a Market horse, but `life_arc.sell_value` returns 0 for those. It's harmless (origin repair only), but document it or mirror it in Python.
- **N2.** `HorsesClient.client.luau:179-180`: "🦉 Comet is getting wise. Soon a little slower" is 8 words, over the 6-word limit. Show only the first half, or use two lines. `Market.luau:273`, "X is a Legend and lives with you!", is 8 words too.
- **N3.** `GrownUps.client.luau:164` says "no countdowns", while the card shows "🦉 Veteran in %d races" (`HorsesClient:182`). It isn't urgency, but say "no timers" instead.
- **N4.** `HorsesClient.client.luau:255`: the buttons rely on creation order under `SortOrder.LayoutOrder` with every LayoutOrder at 0. Set explicit LayoutOrder values.
- **N5.** `RaceService.server.luau:1345`: `row.points` goes to every rider's client in the summary. Only the owner's card uses it, so consider sending it only to that owner.

## Checked and fine

- **Parity with `src/life_arc.py`.**
  - `Legs.luau` matches it exactly: `run_after_race` (`>` fromRaces), `run_after_care` (cooldown per kind), `run_now`, `needs_vet` and `legs_warning`.
  - So does `Ageing.luau`: `stage`, `peakShare`, `updateDeclineFrom` (never un-set), `declineSteps` from `max(declineFrom, veteranAt)`, `racesToNextStep` and `warning`.
  - The GameConfig mirrors are tested, including the energy cooldown and `career.veteranAt == ageing.veteranAt == 350`.
- **Decline.** It applies only through `Ageing.racedRating(..., card.practice)` (`RaceService:701`), on the race count *before* this race. `bestRating`, ceilings, points and stats are untouched (tested).
- **Server authority.**
  - `rideable` turns rated joins away with `Legs.REJECT` and checks again in `runRace`. The REJECT return comes before the Practice fallback.
  - The vet needs a stalled horse, the player at the Vet, not racing, and `minSeconds − lagAllowance` from a server-side start, checked again on Done. The wrap colour is whitelisted.
  - Faking Done only skips a free mini-game.
  - Care spam is capped once per kind per 2 h.
  - The run only grows on counted races.
  - A lent horse can't race, train, visit the vet or retire (`canEnter`, no stall, `retire`).
- **Cash.** `rehomeValue < paid` holds at every price (tested), and undo charges the same cash back, so there's no buy → sell loop. Lend is cash-free and `MAX_HORSES` still counts lent horses, so there's no duplication.
- **Old saves.** `Legs.ensure`, `Ageing.ensure` and the lent repair in `Horse.repair` all handle them.
- **Kid safety (hard rule 3).** There are no purchase prompts. The vet has no Green Cash, no Diamonds and no timer. The UI is sky blue, the hurt-word lint scans more than 1,000 strings, and "Star Race" replaces "Stakes".
- **Diamonds** touch nothing in these phases.
- **Superseded tests changed honestly.**
  - career_tests drops only "sell" (David's decision) and keeps "sold".
  - world_tests pins a Prime horse for the classic gains, and lifearc_tests covers the Young ×1.25.

**CHANGES REQUESTED** (B1, then S1–S5 before commit).
