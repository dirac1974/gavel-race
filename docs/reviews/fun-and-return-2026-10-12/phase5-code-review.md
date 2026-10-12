# Phase 5 code review: visiting other stables (D-079)

Reviewer: code-reviewer (Claude). Scope: the uncommitted phase 5 changes against HEAD `2b70430`. Phases 2–4 files are out of scope.

Checks run:
- The world and visit Lune suites: 1,929 checks, 0 failures.
- `tests/test_compile_all.py`: 2 passed. It compiles `rglob("*.luau")`, so the untracked files are included.
- `scripts/policy_guard.sh`: exit 0. The guard uses `git grep`, so it can't see the two untracked files. I grepped them by hand: no wagering words and no model names.

## What holds

- **Server authority.** Every visit remote re-checks on the server.
  - `VisitHello` (`VisitService.server.luau:53-99`) checks the per-visitor gap, Racing, `VisitAccess.check` with a named action, `near`, the stalled-horse list, and the server-side stop distance (`:92`).
  - `VisitFriend` checks `"enter"` (`StableService.server.luau:1056`).
  - `PostBox` checks `"post"`, which is friends only (`:1075`).
  - The sweep checks `"enter"` (`:1133`).
  - `CareService.VisitCare` keeps the no-action check, which means friends only (`CareService.server.luau:146`).
- **Permission matrix.**
  - `Visits.canVisit`/`may` (`Visits.luau:76-109`) is tested in every cell (3 settings × friend or stranger × 6 actions, with the gate on and off).
  - Nobody blocks friends too (`"private"`).
  - A closed gate blocks every cell.
  - With no action named, the check is the strictest one ("treat").
- **One-time ask.** `SettingsService.server.luau:89-92` runs only once and never writes over Nobody. A ⚙️ choice also counts as asked.
- **Old saves.** `"Club"` is kept as saved and reads as Friends (`Profile.luau:239`, `Visits.setting`). The shell attribute now publishes the effective setting (`StableService.server.luau:872`).
- **No PII to the owner.**
  - The cheer toast has no name, and the toasts are spaced out (`VisitService.server.luau:84-87`).
  - A stranger's row on the barns list shows 🏡, never `GetUserThumbnailAsync` (`WorldClient.client.luau:302`).
  - The list rows carry no counts, likes or rankings (tested).
- **No text.** Cheers are 4 preset ids, and any other value is refused (`Visits.luau:270`).
- **Nothing to take or change.** A stranger's pat sends `CareFx` and a toast only. It gives no bond and writes nothing to the owner's save.
- **Teleports land at the gate.** `gateArrival` is unchanged and lands on Barn Lane, outside the plot.
- **Rate limits.**
  - Hello: 0.5 s.
  - Cheers: 3 per barn per day, capped at 50 barns.
  - The owner's cheer toast: at most one every 30 s.
  - The list: 0.5 s. Travel: 3 s.

## BLOCKING

1. **New files are untracked, and the shared files are tangled with phases 3–4.**
   - `game/src/server/VisitService.server.luau` and `game/src/client/VisitTour.client.luau` are `??`. The client's `WaitForChild("VisitHello")` would hang without them, and CI's `syntax_check` only sees `git ls-files`.
   - `Profile.luau:13-14` now requires `Legs` and `Ageing`, and `Legs.luau` is untracked.
   - `StableService.server.luau:50` requires `HorseLook`, which is also untracked.
   - Committing these files whole, without phases 3–4, breaks every `require` of Profile.
   - Fix: `git add` the two new visit files, and stage only the visit hunks of `Profile.luau`, `StableService.server.luau` and `GameConfig.luau` (`git add -p`), or commit together with phases 3–4.
2. **D-079 isn't logged (hard rule 4).** `DECISIONS.md` and `REVIEW_QUEUE.md` have no D-079 entry. D-060's consequence at `DECISIONS.md:1300` ("only friends are ever listed, so the teleport can't help a stranger follow a kid") is now reversed for Everyone-here barns. That is a kid-safety change and needs its own explicit line for David. The new entry should list:
   - the matrix;
   - the PolicyService rule;
   - the one-time ask;
   - "Ask to leave" deferred (see S3);
   - the alternatives considered.

## SHOULD

1. **The PolicyService gate reads no policy.** `VisitAccess.luau:36-39` treats "the call returned" as OK and checks no field. The comment and the GrownUps copy present it as policy gating. Fix: have roblox-researcher name the field(s) that should gate stranger contact. At minimum, refuse strangers where `IsSubjectToChinaPolicies` is true. Otherwise, rename it to a reachability check in the code, in D-079 and in `OPEN_QUESTIONS`. A failed call never retries, so the player stays friends-only for the whole session. That fails closed, which is acceptable, but add one retry after about 10 s.
2. **The client and server disagree on strangers, which makes a bounce loop.** The clients can't see the PolicyService state:
   - `WorldClient.client.luau:51` opens the walls for any Everyone barn.
   - `VisitClient.client.luau:43` shows Pat.
   - When either player's PolicyService call failed, the server's sweep teleports the stranger back to the gate every second.

   Fix: publish the effective state. Set the shell `Visits` attribute to "Friends" when the owner's policy is unread, and set a `VisitStrangersOk` attribute on each player for the visitor's side.
3. **The owner's controls for strangers.** Three of the four votes (systems, feel, ui-ux) asked for per-visitor "👋 Ask to leave". Today the only tools are Close gate, which ejects friends too, or switching to Friends in ⚙️. The sweep makes that switch work within 1 s, which is good, but nothing in the yard points the kid to it. Either add Ask to leave, or log its deferral in D-079.
4. **The one-time ask is a forced choice at the wrong moment.**
   - `WorldClient.client.luau:350-351` hides the barns list until the kid answers.
   - A kid who opened the list to *go visiting* may read "🌍 Everyone" as "let me see everyone's barns".
   - Fix:
     - Add a "Not now" button, which leaves the setting at Friends and asks again later or never.
     - Show the current choice in gold, as in ⚙️ (Friends).
     - Make the subline clear: "Who can come to *your* barn?"

## NIT

1. `VisitService.server.luau:121-136`: each crossing of the plot edge re-fires `VisitArrive`, which plays the bell and the banner again. Add a short per-barn cooldown, for example 20 s.
2. `Visits.luau:236`: when the 50-barn daily cap is hit, `stop` returns ok with an empty list. The client then re-sends every 0.25 s with "Look!" and `tap_ok`, and the server's 0.5 s gap throttles the sends. The case is rare, but return `false` so the client backs off.
3. `CareService.server.luau:160`: the old pat-all-horses Tour stamp (`Visits.pat`) is still reachable for friends by firing `VisitCare "pat"` by hand. That is a second route to a pin, and the client no longer uses it. Drop it or route it to VisitService.
4. Stranger rows and the pin toast (`VisitService.server.luau:97`, `:128`) use the owner's DisplayName. It matches the barn sign that everyone can already see, and ui-ux §3d asked for it. But votes-systems says "no names of non-friends", so record that reading in D-079.
5. PLAYTEST "Cheer 3 more times: the 4th says…" is right, but it reads ambiguously. Suggested wording: "the 4th cheer in total".

CHANGES REQUESTED
