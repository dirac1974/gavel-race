# Breeding (D-080): code review

Commit `be811e0` ("wip: breeding") against `b6696a6`. Reviewer: code-reviewer, 2026-10-12.

**Tests not run.** About 1,166 MB was free, under the 1,200 MB floor, so no Lune, pytest or compile run happened. This review is static only. Run `lune run tests/luau/run_all.luau` (breeding suites), `python -m pytest -q tests/test_breeding.py` and the compile-all before merging.

## Verified (no finding)

- **Server authority.**
  - `Breeding.confirm` re-checks everything on the server: pair, ownership (`find` on `p.horses`), lent, races, league, busy, the wait, the stable cap and cash (`game/src/shared/Breeding.luau:243-301`).
  - The client sends only ids and NameGen words. Ids are capped at 20 characters (`BreedingService.server.luau:66`), and NameGen rejects free text.
  - Confirm and arrive are rate limited and need you at the barn (`:95`, `:114`). The handlers never yield, so a double fire can't confirm twice.
  - Horses waiting at the Riding School aren't in `p.horses`, so they come back "No such horse".
- **The roll happens once.** It is stored on `p.breeding.pending`. `Profile.repairBreeding` keeps every number on load (`Profile.luau:278-308`). Arrival is checked on the server through `Foals.ready`. The Potential and the coat aren't sent to the client until the foal is ready (`Foals.luau:57-69`), and `Profile.view` doesn't copy `p.breeding`.
- **The cap.** `Market.canAddHorse` counts the foal on the way (`Market.luau:119-122`), so no other path can fill its place.
- **Money.**
  - Green Cash only: there's no Diamond, Robux or MarketplaceService path. `Purchases` grants Diamonds only.
  - A sold foal is always worth less than its fee: at most 300, 500, 850 and 1,350 against fees of 400, 800, 1,500 and 2,500.
- **Parity.** The arithmetic order, `floor(x + 0.5)`, the rng draw order, `coatChances` and `rollCoat` match line for line between `src/breeding.py:114-200` and `Breeding.luau:84-171`.
- **Chances on the card.** The client runs the same shared `Breeding.coatChances` with the same replicated config as the server's roll, and the rows add up to 100%.
- **`studioTest.breedReady`.** It only runs through `StudioTest.apply`, which returns early unless `RunService:IsStudio()` (`StudioTest.luau:82`, `Profiles.luau:260`). It is tested both ways.
- **The changed tests are honest.**
  - `career_tests` and `progression_tests` now assert `suggest == breeding.enabled` and restore the saved value.
  - `test_game_config_mirrors_python` skips `enabled` with a stated reason.
- **Copy and model names.** No banned words in game copy. The only match is "birth-like" in a comment at `BreedingClient.client.luau:13`. No model names, and the commit trailer is plain "Claude".

## BLOCKING

None in the code.

Merge gate: run the tests (see the top of this review) and get them green.

## SHOULD

1. **Missing decision entries** (`docs/memory/DECISIONS.md`, `REVIEW_QUEUE.md`).
   - D-080 isn't logged.
   - Also missing:
     - `breedAnchor` 80.5 (the ruling said 80);
     - `foalEveryRaces` replacing `parentRestRaces`;
     - no PolicyService gate on a Green Cash random coat;
     - `startShare` 0.60, which amends D-047.
   - Required before this lands on `main` (rule 4).
2. **The "Your foal is here!" toast shows over the results.**
   - `Foals.luau:112` fires `Profiles.notify` at `runInSeconds + 4`, about 7.5 s after the result. `Hud.client.luau:513` toasts it at once, even with the results card open.
   - `PLAYTEST.md` promises "never during a race or its results", and plan §4.5 says nothing within 120 s of a race.
   - Fix: queue it on the client until `not busy()`, as the FirstRace banner already does (`BreedingClient.client.luau:783-800`), or send it through Advice.
3. **Each Surprise coat's own chance isn't shown.**
   - The card shows "Surprise: Buckskin, Dun, White or Roan 10%" as one row (`BreedingClient.client.luau:272-277`), but the roll gives each coat 2.5%.
   - The grown-ups paragraph says "every coat the foal can have and its chance" (`GrownUps.client.luau:177`).
   - The consensus format allows the grouped row, but full per-item disclosure is what rule 2 asks for.
   - Fix: add "(2.5% each)" when there is more than one Surprise coat, or soften the grown-ups copy.
4. **"Surprise" is worked out from the parents' coats now, not at the roll.**
   - `BreedingClient.client.luau:545` compares the foal's coat with `p.coats`.
   - If a parent has left, `Foals.coatOf` falls back to `"bay"` (`Foals.luau:33-36`). Then a chestnut parent's chestnut foal can show "A surprise coat".
   - Fix: store `surprise = true/false` on the pending foal at confirm and send that flag.
5. **The `enabled` pin is inconsistent** (`tests/luau/breeding_game_tests.luau:93`).
   - The test asserts `B.enabled == true`, so switching breeding off breaks the suite.
   - Meanwhile `career_tests` and `progression_tests` correctly assert that the two flags are equal.
   - Fix: use `B.enabled == GameConfig.career.suggest`, the same as the other suites.

## NIT

1. `Breeding.luau:245`: "The Foaling Barn is closed today" still uses the old name. The building is the "Foal Barn" (consensus), and `Foals.luau:46` already says "The Foal Barn is closed".
2. `BreedingClient.client.luau:268`: when both parents share a coat, the row reads "Both's coat". Use "Both parents' coat".
3. `BreedingService.server.luau:92`: a confirm dropped by the 2 s rate limit gets no reply, so the button stays on "…" until the next re-render. Send `{ ok = false, text = "One moment" }` or reset the button on a timer, as the naming button does.
4. `BreedingService.server.luau:63`: the barn check allows a 90-stud radius (`p.w`) around the plot's middle, which is generous. Something like `p.w / 2 + 10` would still cover the barn and the paddock.
5. `GameConfig.breeding.stableCap` (20) duplicates `Market.MAX_HORSES`. pytest pins them equal, but `BreedingService.server.luau:122` uses one and `Breeding.pairBlock` the other. Pick one source.
6. `FoalArrive` doesn't check `busyState`. It's harmless because you must be at the barn, but it's inconsistent with confirm.
7. "Arrives … or tomorrow" means the next UTC day, so for US players the foal can arrive the same evening. The Spa precedent accepts this; it's noted for David.

## Verdict

**APPROVE**, with the decision entries (SHOULD 1) required before commit to `main`, and only once the skipped test run is green. SHOULD 2–4 are quick fixes; please do them in this loop.
