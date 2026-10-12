# Green Cash sink (D-070): code review

Reviewer: code-reviewer, 2026-10-11. Branch `claude/green-cash-and-taps`, uncommitted working tree against HEAD `df2d9d3`.
Spec: `greencash-plan.md` (including "Final prices (sim)"), `plans-consensus.md`, `greencash-sim.md`, and the `game/PLAYTEST.md` section "Green Cash: Barn Builder (D-070)".
Out of scope (another developer's work in progress): `shared/TapPreview.luau`, `GameConfig.tapPreview`, `tests/luau/zz_*.luau`, `tap_preview_report.luau`.

**Checks run**
- `python -m pytest -q`: 1766 passed. This includes `test_compile_all`, the Luau suite with `greencash_tests`, `test_greencash_catalog.py` and the new `test_sims.py` Green Cash gates.
- `bash scripts/policy_guard.sh`: exit 0.

## Verdict

The server side holds up. One BLOCKING item is a one-line catalog fix. Two process items must be done before the commit (see the end).

**Verified, no finding:**
- **Double spend.** `BuyCash` passes the 0.4 s `busy` gate and `buyGapSeconds`. Then `Style.buyCash` checks, pays and takes ownership with nothing yielding in between, and the owned check refuses a second buy. `StyleService.server.luau:118-137`, `Style.luau:250-272`.
- **Locked-tier spoofing.** The tier is checked on the server against `Profile.syncBestLeague(data)`, which recomputes from horses, the riding school and Hall of Fame plaques. The client sends only an id. Horses enter only at Rookie (`Horse.luau:71`), and leagues never go down.
- **Bad ids.** `typeof(id) ~= "string" or #id > 40` returns early, then the `byId` lookup refuses unknown ids. Negative, NaN and table ids can't get through.
- **Green Cash never goes negative.** `cashBlock` requires `cash >= price`, and `forCash` requires `price > 0`.
- **Returns.**
  - The refund goes to the currency that was paid (`paidIn`, or the item's own currency), and the 24 h check uses server `os.time`.
  - Returning clears `boughtAt`, `paid`, `paidIn` and `builtAt`.
  - Buying and returning repeatedly is net zero, and returns never touch `cashEarned`.
- **No route between Diamonds and Green Cash.** `forSale` excludes cash items and `forCash` excludes everything else. `shopItems` splits the two shops, and Lune tests cover both directions.
- **Profile writes and DataStore.** Cash and ownership change in the same profile in the same tick, so a lost save rolls both back together. Session locking (`Profiles.luau`) stops duplication across servers.
- **`bestLeague` high-water mark.**
  - It never goes down. Old saves are migrated in `Profile.repairBarnBuilder`, and `shelfSeen` is set to the migrated best, so an old save gets no "New shelf" spam.
  - Junk in `wish`, `wishTold`, `boughtAt`, `paid`, `builtAt` and `paidIn` is cleaned on load.
  - Tested in `greencash_tests.luau:221-250`.
- **Race window.**
  - On the server, `cashWindowShut` refuses a build while in line, racing, on a training ride, or within 120 s of `LastRaceEnd`.
  - On the client, `RaceState.shopClosed(120)` disables the prompt and closes the panel. It also covers the results card.
  - The pill (`Advice.buildPill`) needs a context and is blocked in line, while racing, on results or Race again, during the tour and within 120 s. The shelf note is gated on `shut()`, the tour and `busy()`.
- **Copy.** No "sale", "limited" or "deal" and no wagering words (`policy_guard` and `greencash_tests:181`). Every price shows 💵. There is no 💎 in BarnBuilder. Tack & Paint shows the one-line hint.
- **Cleanup when a player leaves.** Every build is under `Barn`, which `clearPlot` destroys. `FreshBuildId` is cleared, and the `lastBuy[player]` table is cleared on `PlayerRemoving`.
- **Visitors.** Builds are server parts, so everyone sees them. Only the owner's own screen hides a new piece until the build moment. `signature()` includes the new slots and the yard ids, so a buy, a return or a put-away rebuilds the barn.
- **LEAGUE_B parity.** `GameConfig.leagues[*].B`, `economy.LEAGUE_B` and `gavel_race_v2.LEAGUE_B` are all 20/30/45/65/85. `tests/fixtures/race_math.json` is unchanged and the parity tests pass, so race math is untouched. Only `B` (the purse scale) moved.
- **Floors.** BarnBuilder uses `Ui.fitPanel(panel, W, H, nil, 16, 64)`, all text is 16 px or more, and all buttons are 64 px.
- **Model names.** None in the diff (`policy_guard`).

## BLOCKING

1. **A rosette icon on a 💵 item.** `game/src/shared/BarnCatalog.luau:134`: `bb_frame_champion` uses the emoji `🏵️` (a rosette).
   - Plan §1 and D-050: "Never sold for 💵: trophies, rosettes, Cups or anything that looks like a real win."
   - The swatch shows this emoji on the card, and the wish chip shows it on the dock's cash card. A kid sees what looks like a Champion rosette priced at 💵 4,000.
   - `test_greencash_catalog_rules` (regex `rosette$` on id and label) and `greencash_tests` (the `notSoldOk` check) look only at text, so neither catches the emoji.
   - **Fix:** change the emoji to `🖼️` or `🪵`. Add `🏵️ 🎖️ 🏅 🏆 🥇 🥈 🥉` to the not-sold check in `greencash_tests.luau` (around line 99) so it covers `emoji` as well as `id` and `name`.

## NON-BLOCKING

2. **The cash buy skips the wallet function.** `Style.luau:259`: `p.cash -= it.price` goes around `Profile.spendCash`, although the comment says it goes through it. The result is correct today, but there are now two spend paths.
   - **Fix:** use `if not Profile.spendCash(p, it.price) then return false, ..., "cash" end`. Style can't require Profile without a cycle, so either pass it in or move the floor and compare inline. At the least, fix the comment.

3. **A latent route between currencies in returns.**
   - `Style.luau:291`: `inCash = paidIn == "cash" or Style.isCash(it)`.
   - `Style.buy` (`Style.luau:205`) never records `paidIn = "diamonds"`. If an item ever moves from Tack & Paint to Barn Builder in a config change, a Diamond purchase made inside the return window would be refunded in Green Cash: Diamonds turned into Green Cash, against hard rule 2.
   - **Fix:** have `Style.buy` record `paidIn[id] = "diamonds"`. In `giveBack`, trust `paidIn` first and fall back to the item's currency only when it is missing.

4. **Wrong shop named for Barn Builder items.** `Style.luau:352`: `equip` on an unowned item says "Get it in the Tack & Paint shop first", even for a `bb_` item.
   - **Fix:** `if Style.isCash(it) then "Build it at Barn Builder first" else ...`.

5. **Part count per yard.** BarnDecor builds a pennant as one rope part and two wedges.
   - With a barn of about 74 studs, `bunting` (`BarnDecor.luau:445-448`) is about 130 parts. Add the gate-arch pennants (about 30), the bunting frame (about 45), the flower photo board (about 35) and the weathervane (about 26 parts and 8 SurfaceGuis). A full Champion yard adds about 300 parts.
   - With 20 plots and StreamingEnabled not set in the project, that is up to about 6,000 extra parts. Every signature change (including rest poses) rebuilds them.
   - **Fix:** draw bunting runs as one `Beam` per run with the existing `bunting_strip` image (`WorldArt.NAMES`, already uploaded), keeping parts only as a fallback before the image loads. Or cap `n` at about 8 pennants per run.

6. **Spamming the wear remote rebuilds the barn.** `StyleWear` can toggle a yard piece every 0.4 s, and each toggle rebuilds the whole barn, now including the heavy Barn Builder pieces. This pattern existed before, but this change makes it heavier.
   - **Fix:** debounce `refresh` per plot (for example, coalesce to once every 0.5–1 s) in `StableService.server.luau:942-944`.

7. **Sparkles still play with Reduced Motion on.**
   - `BuildFx.luau:112` (the still path of `dropIn`), `BarnBuilder.client.luau:236` (paint reveal) and `:239` (worn reveal) still emit particle bursts with Reduced Motion on.
   - `VisitClient.client.luau:174` (a friend's fresh build) doesn't check Reduced Motion at all.
   - The PLAYTEST text promises "fades in ... with the same toast and sound". It doesn't mention sparkles.
   - **Fix:** skip `BuildFx.sparkle` and `burst` when `BuildFx.reducedMotion()` is on, inside `burst` itself, so every caller is covered.

8. **The gate arch and fence in Studio.** `BarnDecor.luau:352-366` and `:371-396` need a check in Studio.
   - The uploaded `trail_gate_arch` is placed unscaled and keeps its own collision, because `quiet()` doesn't clear `CanCollide`. If it's narrower than `GATE_W = 14`, it can block the gate.
   - The fallback posts at ±8 overlap the painted fence's end post at ±7.
   - **Fix:** set `CanCollide = false` on the arch, or scale it to `GATE_W + 2`. Add a PLAYTEST line: "walk and ride through the arch".

9. **`FreshBuildId` goes stale.** `StableService.server.luau:869` sets it only in `refresh`. After 48 h the ✨ sparkle on a visit continues until the owner's next profile change. The Friends' list itself is computed live, so only the visit sparkle lags.
   - **Fix:** recompute it in the existing slow loop, or accept it and note that in PLAYTEST.

10. **Tap-gap code uses D-070.** `plans-consensus.md:6` assigns Green Cash to D-070 and the tap gap to D-071. But `GameConfig.luau` (the `tapPreview` comment), `PacePreview.luau` (`beforeLock`), `RaceFx.luau` (`stepNudge` `baseFall`) and `tests/luau/race_overlap.luau` label the tap-gap work "D-070", and `tapgap-plan.md:1` says D-070 too. This is out of scope for this review but breaks traceability.
    - **Fix:** the tap-gap owner relabels those comments D-071 before commit.

11. **The plan's final table doesn't match the game.** "Final prices (sim)" in `greencash-plan.md` lists ids and names like `paint_barn_red` / "Red barn paint", but the game ships `bb_paint_cherry` / "Cherry barn paint", and others differ too. Tiers and prices match (tested).
    - **Fix:** add a note under the table, or update the ids, so DECISIONS and REVIEW_QUEUE cite what actually ships.

12. **The decorator writes to the profile.** `StyleService.server.luau:78`: the `addDecorator` hook writes `data.bestLeague` while building a view. It is idempotent and only ever goes up, and BuyCash re-syncs anyway, so this is harmless.
    - **Fix:** also call `Profile.syncBestLeague` where promotion happens (`Leagues.luau` around line 120), so the mark doesn't depend on a view being built.

## Before commit (required, process)

- **D-070 is not yet logged.** It is missing from `docs/memory/DECISIONS.md` and `docs/memory/REVIEW_QUEUE.md`, which the plan's acceptance requires.
  - The scribe must log it as `Accepted (provisional)` with the alternatives considered:
    - plan B 20/30/45/60/80 against the shipped 20/30/45/65/85;
    - a hay barn from `training_shed` against the code-built hay loft;
    - a Meshy weathervane against the code-built one;
    - the 120 s server refusal of builds, which is stricter than the plan's "no suggestion".
  - Add one REVIEW_QUEUE row each for D-070 and D-071.
- **Commit attribution.** Hard rule 5: the commit trailer must say "Claude" with no model name. This session's injected attribution names a model. `policy_guard` checks `origin/main..HEAD` messages, so run it after committing and before pushing. Never rewrite history (rule 6).
- **Untracked files.** Don't commit the untracked `.claude/worktrees/` directory.

## Result

**CHANGES REQUESTED.** Only #1 blocks: a one-line emoji swap plus a test that checks emoji. After that, and with D-070 logged, this is ready to approve.
