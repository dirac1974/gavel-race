# Phase 3 code review: progression and friends (D-068)

Code reviewer, 2026-10-11. Branch `claude/aaa-review`, uncommitted working tree. Scope: the Phase 3 files listed in the brief. The Phase 2 files that another developer is fixing (RaceController, ResultsCard, FinishMoment, FanClient, Starter) were not reviewed.

## Checks run

| Check | Result |
| --- | --- |
| `python -m pytest -q` | 1730 passed, **1 failed**: `test_luau_parity` → `finish_tests.luau:206-207` ("coaching reuses the steering tip's ghost thumb", "the tap's word at the marker"). Both pin strings in `RaceController.client.luau`, which is a Phase 2 file being fixed by the other developer, so this is not a Phase 3 failure. It must be green before the commit. |
| `python -m pytest -q tests/test_sims.py` | 35 passed. The PENDING_CONFIG xfails are now normal tests and pass (`test_live_config_is_phase3`, `test_live_config_casual_races_to_cup[*]`). |
| `bash scripts/policy_guard.sh` | pass (exit 0) |
| Lune `luau.compile` on every `game/src/**/*.luau` | 118 files, 0 failed |
| Locals used before they're defined (RacePicker, HorsesClient, RehomeClient) | none. `close` (RacePicker:158) and `render` (HorsesClient:99) are forward-declared and assigned before any button can fire; `pickedHorse`, `raceRemotes`, `gui`, `joinBtn` and `kindRow` are declared above the friends code. |
| Ladder values vs `phase3-sim.md` | exact match: `stakesUnlockPoints` 100/200/450/900, `botRatingAnchor` 32/35/38/48/56, `leagueCeiling` 55/57/60/66 (GameConfig.luau:418, 449, 428). `economy.PHASE3` holds the same values and `test_live_config_is_phase3` pins them. |
| Model names, wagering words in the diff | none |

## BLOCKING

### B1. "Race with [friend]" doesn't move you to your friend's course when you're already in line, which is the main way to reach it
`game/src/server/RaceService.server.luau:497` passes the friend's course to `joinQueue` as `courseId`, but `joinQueue` (RaceService:442-458) returns early before it ever looks at `courseId`:
- **Alone in line** (the usual case: one-tap RACE! puts you in line at once, and "🔀 More choices" is only on the queue card, which shows *while you're in line*): the `#c.queue == 1 and c.queue[1] == player` branch calls `claimCard(c, h.league, "practice")` on your **own** course and returns. You end up in Practice on course X while your friend waits on course Y.
- **Already in Open Practice on another course**: `RaceQueues.cardKey(c.card) == key` holds, so only `chosen[player]` is updated and you stay where you are.

So the PLAYTEST step "A taps RACE! → More choices → Friends → Race with B … A goes to B's course" fails whenever A is alone in line, which is most of the time.

**Fix:** when a friend's course is resolved, and it differs from `inLine[player]` and can take the rider (`RaceQueues.canTake(courses[friendCourse], RaceQueues.key(h.league, "practice"), GameConfig.lanes)`), call `leaveLine(player)` first and skip the same-key and alone shortcuts. For example, pass a `follow: boolean` into `joinQueue`. When `follow` is true and `want ~= (inLine[player] and inLine[player].id)`, go straight to `leaveLine` and then `RaceQueues.join(..., want)`. Add a Luau test that drives `RaceQueues.join`/`pump` with a rider already alone on course 1 and a friend's want of course 2 (or a RaceService-level string test in the style of `finish_tests`). If the friend's course is full, keep today's behaviour (stay put, kind toast).

## NON-BLOCKING

### Security and exploits (checked, no holes found)
- **UnretireHorse** (MarketService:244-257): rate limited (`busy(player, 1, "unretire")`), id type-checked, horse looked up only in the caller's own profile, and blocked while racing, in line or riding that Legend. No reward is attached to retire or unretire (no Diamonds, Green Cash, rosette, Stable Star goal or `Progress.record`), first wins are keyed by the horse's league wins (unchanged), and the plaque is replaced rather than added (Leagues.lua:160-162, 189-193). Retire/unretire loops can't farm anything, and the "last racer stays" rule still holds (Leagues:153). Good.
- **friendId** (RaceService:473-479): only used for `kind == "practice"` with Open Practice on, friendship is read from the server-side `TrainingFriends` cache (`Player:IsFriendsWith` run on the server), and the result is only a course *wish* that `RaceQueues.bestCourse` honours when the card's key is `Open|practice`. It can't reach a cash race or Cup, and it can't target a non-friend. JoinRace keeps its 0.5 s limit. Good.
- **runRace filter** (RaceService:633): mixed leagues are let through only when `card.practice and Leagues.openPractice()`; cash and Cup cards keep the old filter. Practice purses are zeroed at the session (RaceService:675-676) and again at payout (1050-1052), `Profile.recordRace`, League Points, first-win bonus and Cup promotion all sit under `if not card.practice`, and `costOf` is 0 for Practice (345). No route to another league's cash race: `RaceQueues.key` keeps `league|race` / `league|cup`, and `Leagues.canEnter` only short-circuits for `card.practice`.

### N1. Unretire doesn't use the shared busy rule
`game/src/shared/Leagues.luau:182-184` re-implements part of `retireBlock` and leaves out `trainingRide` and `racingHorse`. Nothing exploitable today (a Legend can't race, and a ride on it sets `RidingHorse`), but the two will drift. **Fix:** `local why = Leagues.retireBlock(h.name, id, b, "Bring back")`, or give `retireBlock` a verb for unretire, and keep one rule.

### N2. Retiring while careers are off gives the wrong reason
With `corePlaytest` (or `career.enabled = false`), `Career.canBeLegend` is false, so `Leagues.retire` answers "Legends need 100 races. Keep going!" (Leagues.luau:151) to a horse that already has 300. **Fix:** check `GameConfig.career.enabled` first in `retire` and return e.g. "Legends are resting today!". The button is hidden client-side, so only a stale client hits this.

### N3. Core-playtest switch leaves the career row up
`corePlaytest` turns `career.enabled` off server-side (no toasts, no Legend button, Retire refused). Good. But `Career.view`/`Career.line` still put "🎖️ 2 patches · 🎖️ in N races" on every horse card (HorsesClient:131-134), so the meta is still visible during a core playtest. **Fix:** return `line = ""` and `toNextBadge = nil` from `Career.view` when `cfg().enabled` is false, or hide the row in HorsesClient. Everything else in `CORE_PLAYTEST_OFF` is honoured server-side: Spa (TrainingService:781, Spa.luau:56), visits (VisitAccess:43), rehoming (Market.luau:237), Photo Finish (StableService:589), Horse Book (ComeBackService:26, HorseBookClient:23).

### N4. Open Practice uses the first rider's league for the meter and bots
A Rookie kid who follows a Gold friend runs on a Gold card: the Gold sweep, T 14.4 and anchor-48 bots (RaceService `leagueName` comes from `card.league`). It pays nothing, so this is fair, but it's a much harder slider for the youngest player in the pair. For the Phase 3 consult: claim Open Practice cards at the lowest league among the riders waiting, or add a config value (`queue.openPracticeLeague = "Rookie"`).

### N5. Race with a friend ignores the friend's "Nobody" visits setting
Grown-ups says "'Nobody' also means no Ride together invites" (GrownUps.client.luau). Race with a friend sends nothing, and Practice lines are public, so the risk is low. Still, a parent who chose Nobody may expect friends not to follow their child into a specific gate. **Fix (optional):** in `friendPracticeCourse`, return nil when the friend's `settings.visits == "nobody"`, and leave them off the client list. Log it as a provisional design call either way.

### N6. `friendId` NaN or inf
`typeof(friendId) == "number"` accepts NaN and inf. `Players:GetPlayerByUserId(NaN)` may throw, which drops the whole JoinRace for that exploiter only. **Fix:** `friendId ~= friendId or math.abs(friendId) == math.huge` → return nil.

### N7. The client toast fires before the server answers
RacePicker:177 toasts "🎈 Practice race with B!" and closes the picker before the server confirms, then the server sends "You're in line!" as well. After B1 is fixed, consider dropping the client toast and letting the queue card speak.

### N8. Toast length
`CareService.server.luau:165` "Sunny Comet nuzzles you! 3 more to pat for a pin" is 11 words with a two-word name (`ui.toastMaxWords` = 10). The count was the same before the rename, but phase3-words.md says every changed toast is 10 words or fewer. **Fix:** "Sunny Comet nuzzles you! 3 more for a pin".

### N9. Stale mirrors and comments (clarity)
- `sims/economy.py:15, 62` and `sims/README.md:24` still say `BOT_RATING_ANCHOR` (32/46/56/69/80) "mirrors GameConfig.botRatingAnchor"; it's now the "before" record, and `--solo` reports win rates for the old anchors. **Fix:** rename it `BOT_RATING_ANCHOR_D061` and make `PHASE3["anchors"]` the default for `solo_win_rate`/`--solo`, or reword both docstrings. `test_bot_anchors_match_game_config` (test_sims.py:33) accepts either ladder; `test_live_config_is_phase3` is the real pin, so the weaker test could go.
- `GameConfig.luau:412-414` (Silver 750 rationale) and `:444-445` ("tuned by --solo … about 24% … 35% at the ceiling") now describe the old ladder. Mark them "before D-068" or remove them.
- `docs/GAME_DESIGN.md:84-90` league table still says 110 / 1,400 / 3,000 (stale since D-062). Update it to 100/200/450/900.

### N10. Friends button layout
RacePicker:134 puts "👫 Friends" (150 × 64) at the top left of a 720-wide panel, under the centred "🔀 More choices" title (full width at y 12). Text and button overlap on narrow phones once `fitPanel` scales. Check in Studio, or shorten the title's width to `1, -340`.

### N11. HorsesClient Legend row width
Legend cards now carry 🐴 Ride (80) + 🏁 Back to races (160) + ✏️ Name (80) + padding = 332 px in a cell of about 344 px (HorsesClient:63, 157). It fits at full size with no room for a longer label. Fine for now; check it on a phone.

### N12. Traceability
`docs/memory/DECISIONS.md` and `REVIEW_QUEUE.md` have no D-068 entry yet (expected: the scribe logs after review). Before the commit they must list as `Accepted (provisional)`, each with its rollback switch:
- the ladder values and targets (20/40/90/180, 25% entry, Gold 22%, about 36% at the ceiling)
- Champion with no ceiling (phase3-sim recommendation 4)
- `queue.openPractice`, and the card taking the first rider's league (N4)
- Race with a friend, including the N5 choice
- `Leagues.unretire`
- `career.suggest = false`
- `corePlaytest`
- the word mapping (patch, medal, pin), plus the deferred stamp and rosette items.

## Verdict

**CHANGES REQUESTED.** Fix B1. The rest is non-blocking. The one pytest failure is in a Phase 2 file and belongs to the other developer's fixes, but the suite must be green before the commit.
