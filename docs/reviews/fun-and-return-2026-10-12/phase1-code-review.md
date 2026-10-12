# Phase 1 "Find it" (D-075): code review

Reviewed: the uncommitted working tree against 7f312ba. The life-arc files (Ageing, life_arc.py, lifearc.py) are out of scope except where they share a file with Find it.

Tests run (3.2 GB free at run time): Lune findit, queue, clarity and world suites: 1,447 checks, 0 failures. `tests/test_compile_all.py`, `test_dock_floors.py` and `test_clarity_floors.py`: 13 passed. `policy_guard.sh`: exit 0. The guard uses `git grep`, so it can't see the four untracked Find it files. I grepped them by hand: no wagering words and no model names.

## BLOCKING

1. **A pointer chosen before a race shows again right after it** (`game/src/client/StableBoard.client.luau:448-449`, `:465`).
   - `pointerNow` returns the latched `pointer` without re-checking the context.
   - Sequence: a pointer latches, then the kid taps RACE!. In line, the in-line pill wins. During the race and on the results card, the pill is hidden. When the results card closes, `sinceRace` is under 120 s, but the same "New! Meet horses at Market" or "New! Build things…" comes back with GO.
   - The Market GO then opens a listing card with no race guard. That breaks the pointer pacing rule and is a purchase push right after a race (hard rule 3).
   - The Lune tests only cover `FindIt.pointerDue`, so they can't catch this.
   - Fix: when a latched pointer exists, re-check the gates (touring, busy, results open, `sinceRace`). If any gate fails, drop the pointer without marking it seen. A `FindIt.pointerOk(ctx)` helper would let the gates be tested in Lune.

2. **The tappable portrait in the thumbstick zone reverses D-056 without a log entry** (`game/src/client/Hud.client.luau:550`, `:571`).
   - D-056 (REVIEW_QUEUE) says "nothing tappable in the thumbstick zone".
   - On touch, the dock anchors bottom-left. `PHONE_ORDER.horse = 1` puts a live 70 px button there, 12 px from the corner, which is exactly where a thumb lands to move. A kid who starts moving opens My Horses instead.
   - The council asked for "tap: My Horses", but no one weighed it against D-056.
   - Fix, either one:
     - (a) Keep the portrait display-only on touch (`horseHit.Visible = not touch`). My Horses is already in ☰ More.
     - (b) Log D-075 as an explicit reversal of that D-056 clause, with a Studio thumbstick check in PLAYTEST.
   - (a) is the reversible default.

3. **The commit would mix in life-arc work.**
   - `tests/luau/run_all.luau:231` requires the untracked `ageing_tests`.
   - `game/src/shared/GameConfig.luau:722-741` adds `ageing` (with `declineScale = 1`) and `sell`.
   - `career_tests`, `progression_tests` and `Career.luau` also changed.
   - A Find it commit with these but without `Ageing.luau` breaks CI. A Find it commit with them also ships decline switched on.
   - Fix: stage hunks with `git add -p`, and add the 4 untracked Find it files (`FindIt.luau`, `GoTo.luau`, `HowRacing.luau`, `findit_tests.luau`).

## SHOULD

4. **The server doesn't check "never in line" or training rides** (`game/src/server/StableService.server.luau:990`).
   - `canTravel` blocks only `Racing` and a race saddle. A client that fires `Travel` directly can travel while `InLine` or on a training ride (`TrainingRide` attribute). The Map now has 12 destinations, up from 5.
   - It can't skip a queue, because queue order doesn't depend on where you stand. TrainingRide also marks teleport gaps. So this is defence in depth.
   - Fix: add `InLine` and `TrainingRide` checks to match the client.

5. **A walk that started calm can open a feature in line** (`game/src/client/GoTo.luau:128-129`).
   - `openAfter` checks only `racing()`. If a kid walks toward Feed & Seed and joins a line on the way, the shop opens on arrival.
   - Fix: also bail on `state().inLine`, `state().training` or `RaceState.shopClosed(0)`.

6. **A "seen" save can be dropped** (`game/src/server/SettingsService.server.luau:67`).
   - `SetSetting` shares a 0.3 s limit (the `last[player]` table) with `BoardOpened` (`:102`). A dropped "seen" makes the pointer come back.
   - Fix: give "seen" its own limit table. The ids are already bounded by `SEEN_IDS`.

7. **Text likely overflows** (verify in Studio):
   - The HowRacing caption "2. Riders fill the gate" at 18 px, unwrapped, in 172 px is about 220 px wide (`HowRacing.luau:95`).
   - The Map labels "Barn Builder" and "Tack & Paint" at 18 px in 112 px will truncate (`WorldClient.client.luau:150`). PLAYTEST says "no word is cut off".

8. **The Race Board tile mixes two symbols** (`game/src/shared/WorldLayout.luau:147`). Its atlas icon is `flag_ready` (🏁 art, the RACE! symbol) while its emoji is 📣, which goes against one symbol per meaning (D-064). Fix: use `""` until a megaphone icon exists.

9. **D-075 is not in DECISIONS.md or REVIEW_QUEUE.md yet.** Record these in it:
   - `seen_<id>` instead of `flags.seen[id]`;
   - Pick 64 px instead of 56;
   - RACE 210 px;
   - a phone dock 463.75 px wide in 467 px of space (3 px margin).

## NIT

10. Pointer "pick", map tile "Race Board": `GoTo` fires `OpenRacePicker` without the Hud's `pickerJoinWatch()` (`Hud.client.luau:435`). A join from the picker then gets no reason window.
11. `GoTo.register("visit")` (`WorldClient.client.luau:308`) does nothing silently when visits are off. Give it a toast like the other no-op paths.
12. "Bots fill spots at 0": "at 0" is terse for young readers. "Bots join at 0" or a picture caption test with the young-player designer.
13. The session's injected commit trailer names a model. Use plain `Claude` (rule 5).

## Checked and fine

- `isTravelDest`: a string, on the Map, and not "visit".
- `SetSetting("seen")` takes only `SEEN_IDS`.
- `LineKey` and `LineHorse` are cleared on every InLine exit, including `courseLoop`.
- Tack & Paint and Barn Builder GO both keep `shopClosed(...)`, and no pointer targets Tack & Paint.
- GO while racing does "wait". GO in a line or on a training ride only walks.
- The registry is keyed by id, so a second registration overwrites the first. `ResetOnSpawn = false` keeps the fade alive.
- The ring is 1 Hz, and it holds still with Reduced Motion.
- Pointer copy is 6 words or fewer.
- The signpost's yaw math is correct, and its arms don't collide.

CHANGES REQUESTED
