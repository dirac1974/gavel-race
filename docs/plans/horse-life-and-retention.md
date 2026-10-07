# Plan: horse life and retention (debate 013, D-058 to D-065)

Build order for David's 2026-10-07 request. Each stage is one build loop (CLAUDE.md): plan in STATUS, implement, tests and policy guard green, review, record, PR. Every new value lives in `GameConfig` so it can be reversed (hard rule 4). Stage 1 is what most risks breaking tonight's first Studio playtest; build it first and on its own.

**Art:** every Meshy prompt below starts with the house style line from `tools/meshy/queue.json` ("County Fair Toy style … chunky stylized natural horses … no whip, no wagering imagery … never generate a rider"), written here as **[CFT]**. Props are low-poly, painted wood, bright daylight, readable at 40 px (D-023, `docs/art/ART_DIRECTION.md`). Text-to-3D costs about 30 credits, a retexture about 10. The balance was 460 after the world pass; this plan asks for **at most 300**, never going below 150, checked before every batch (as the world pass did). Log every spend in `tools/meshy/queue.json` and verdicts in `docs/art/ART_REVIEW.md`. Icons come from `tools/ui/make_ui_svgs.py`, not Meshy.

**Parent checks** are things David (or any grown-up) can do in a Studio playtest with no tools: Play Solo, or Test → Clients and Servers with 2 players, plus Device emulator → a phone in landscape.

---

## Stage 1 — Playtest-safe tonight (D-065, D-061 core, D-058 label, D-064 basics)

**Goal:** nobody gets stuck on "loading", kicked, or locked out of racing; the words about rest are true; phone buttons are big enough to tap.

**Work:**
1. `Profiles.sendSync`: `pcall` each decorator, `warn` once per decorator name, still fire ProfileSync.
2. `Profiles.load` on a locked save: no `Kick`. Tell the client "Opening your stable…" (new `ProfileWaiting` remote), keep retrying every 10 s until the lock is stale (`LOCK_STALE`), show a "Try again" button (TeleportService to the same place). Cancel cleanly if the player leaves.
3. **Lockout fix:** `RaceService` gets one queue per `league|kind`. `join` puts the rider in their queue; when a course is free, the longest-waiting queue claims it (`claimCard`). `bestCourse` returns only a course the rider can join or `nil` (then they wait in their queue). A claimed course never takes a rider of another league.
4. `RacePicker`: preselect only a card the active horse can join; other leagues' cards show the league badge and "Watch"; redraw key includes league, kind and Cup.
5. `GameConfig.lobbyFillSeconds = 15`.
6. **Rest label:** `Horse.view` reports `ready = energy ≥ 1`; dock and Stable Board say "Ready" / "Napping" only at 0 (`energy.restingLabelAt = 0`); `Advice` no longer says "napping" above 0.
7. **Energy icon:** one horseshoe icon in the dock, picker and horse cards; picker Sprint becomes 🐇 Short.
8. **Dock floors:** `fitDock` never scales a button below 56 px or a label below 14 px rendered; on phones (`ui.dockPhoneItems = 3`) the dock is horse card, RACE!, ☰ More, and the rest moves into More.
9. No retiring a horse being ridden, training, queued or racing (`MarketService` `RetireHorse`).
10. `PlayerData`: Green Cash and Wins no longer go in `leaderstats`.

**Files:** `game/src/server/Profiles.luau`, `RaceService.server.luau`, `MarketService.server.luau`, `PlayerData.server.luau`, `game/src/client/RacePicker.client.luau`, `Hud.client.luau`, `GrownUps.client.luau` (loading card), `game/src/shared/Horse.luau`, `Advice.luau`, `GameConfig.luau`.

**Tests:** Lune (`tests/luau/world_tests.luau` or a new `queue_tests.luau`): a throwing decorator still produces a view; a Rookie joining while Bronze holds course A and a race runs on B waits, then gets the first free course, and never a Bronze card; two leagues waiting → longest wait wins; `bestCourse` never returns another league's course; `Horse.view` says ready at 1 Energy; retire is refused while riding or queued. Python: a `tests/test_ui_assets.py`-style check that the dock floor constants are ≥ 56 / 14.

**Meshy:** none.

**Parent checks:**
- Two players: player 1 (Bronze save, or use the Studio cheat) taps RACE on dirt; player 2 (new, Rookie) taps RACE. Player 2 never sees "That race is for Bronze horses"; they get the turf course, or wait with "Bots join at 0" and race next.
- After one Bronze race the dock still says **Ready** and shows 4 horseshoes; after 5 it says **Napping**.
- On the phone emulator, every dock button is at least the size of a fingertip (about 1 cm on a laptop screen) and the words are readable.
- The player list shows no Green Cash or Wins column.
- In the command bar, `require(game.ServerScriptService...Profiles).decorators[1] = function() error("x") end` then do anything: the client still updates (no "loading" forever).
- Ride your horse, open My Horses, tap Retire on it: it says you can't while riding.

---

## Stage 2 — One race button and a visible queue (D-061)

**Goal:** "I tap RACE, I race", and kids can see the wait.

**Work:** "Race with Comet ▶" (active horse) as the RACE! action, with "More choices" opening today's picker; queue card at the top: countdown ring, 8 gate slots filling with names and coat dots, "Bots join at 0"; groom, ride or visit while queued, "Race time!" with GO hoofprints at the fill; bots rated at `botRatingAnchor = { Rookie = 50, Bronze = 63, Silver = 73, Gold = 83, Champion = 90 }` ± 6; bot names from `NameGen` horse names only. Economy sim first: solo Rookie win rate with the anchors must be 20–35% (tune anchors if not).

**Files:** `RaceService.server.luau`, `RaceSession.luau` (`fillWithBots`), `GameConfig.luau`, `Hud.client.luau`, new `game/src/client/QueueCard.client.luau`, `RacePicker.client.luau`, `sims/economy.py` (solo win-rate report).

**Tests:** Lune: bots' ratings sit within anchor ± 6 for each league; bot names never match `^[A-Za-z]+[0-9_]{2,}`; queue card state from server events. Python: `tests/test_sims.py` asserts the solo Rookie win rate band.

**Meshy:** none (UI art).

**Parent checks:** a new player taps RACE once and is in a gate within 20 s; the ring counts down and the gate slots fill with horse names; while waiting, brushing the horse works and "Race time!" calls you back; after a few days of training a horse, it wins noticeably more than a fresh one.

---

## Stage 3 — Clarity pass (D-064, Next-thing pill)

**Goal:** a kid who reads slowly understands every screen.

**Work:** the symbol map (★ ride only, ❤️ care, 📣 fans, 🎀 stamps, 🌱 family line, horseshoe Energy, 🐇 Short); results card one row "You rode ★★☆" and "Your taps gained Comet N places!" (positive only); picker cards one line ≤ 5 words with league colour; toasts ≤ 10 words (rewrite the long ones in the audit); one "Next thing" pill above the dock from `Advice` (one suggestion, a GO button); weekly and monthly jobs inline on the Stable Board; panels re-lay out at phone height instead of shrinking text below 14 px; Pip gives a hint after 20 s stuck.

**Files:** `ResultsText.luau`, `RaceController.client.luau`, `RacePicker.client.luau`, `StableBoard.client.luau`, `HorsesClient.client.luau`, `Hud.client.luau`, `Advice.luau`, `Ui.luau`, `Market.luau` (bloodline icon), `tools/ui/make_ui_svgs.py` (horseshoe pip, heart, rosette, sprout icons).

**Tests:** Lune: a copy test reads every toast and results string (≤ 10 words, none of the banned words in D-058 and hard rule 1); the results card has one star row; `Ui` scale never yields text < 14 px at a 375 px-high screen. Python: `tests/test_ui_assets.py` checks the new icons exist.

**Meshy:** none.

**Parent checks:** ask a child "what does the star mean?" and "what does the horseshoe mean?": one answer each. The results card has one row of stars. The pill always shows one thing to do, and tapping GO takes you there.

---

## Stage 4 — Spa Day and rest cues (D-058)

**Goal:** David's "care at the vet", the happy way.

**Work:** yawn at 1 Energy, lie down with Zzz at 0 (stand pose + a lying pose, or a lowered stall pose); Spa Day at the vet: tap the hose to rinse (cool-down hose from D-039), tap-brush, towel; +1 Energy once per horse per server day, a Passport stamp, a shine sparkle on its next race; "Spa opens again tomorrow"; "Great day! Comet's dreaming of tomorrow." when every horse naps; Stable Board job "Give a horse a Spa Day".

**Files:** `Training.luau` or new `shared/Spa.luau`, `TrainingService.server.luau` (or new `SpaService`), `PaddockClient.client.luau` (vet menu), `StableService.server.luau` (stall poses), `RaceView.client.luau` (shine), `Jobs.luau`, `GameConfig.spa`.

**Tests:** Lune: Spa gives +1 Energy once per day per horse and never above max; no bond or Rating change (`RaceRating` unchanged before and after); second Spa the same day refused; a copy test bans hurt/sore/injury/limp/sick.

**Meshy (≈ 90 credits):**
- `spa_wash_stall` — "[CFT] A small open-sided horse wash bay for a county-fair vet clinic: painted pale-blue wooden frame with a white scalloped roof trim, a rubber mat floor, a coiled green garden hose on a wall reel, a bucket of soapy bubbles and a big sponge; cheerful, clean, toy-like, no horse, no people."
- `horse_lie_bay` — "[CFT] A chunky red bay horse lying down resting in straw with legs folded under, head up and relaxed, ears soft forward, eyes open and calm, mouth closed; healthy, glossy coat, dark hooves; no saddle, no rider." (then retexture to the other coats at 10 each, only if the first reads well; or reuse a lowered stand pose if it doesn't.)
- `towel_rack` — "[CFT] A small wooden towel rack with two folded striped towels and a brush caddy, painted wood, bright colours, toy-like."

**Parent checks:** race a Bronze horse to 1 Energy: it yawns in the stall; to 0: it lies down with Zzz and the dock says Napping. At the vet, the Spa takes under a minute, the horse gets one more race, and the Spa then says "opens again tomorrow" with no clock. Nothing anywhere says hurt or sore.

---

## Stage 5 — Visiting friends' barns (D-060)

**Goal:** a kid finds a friend's barn in two taps and has something to do there.

**Work:** Map → "Friends' barns" (friends in this server whose setting allows you; faces from `GetUserThumbnailAsync`); teleport to their gate; pat each horse once for a Tour stamp (per friend, once); one treat a day (D-042); post box carrot drop with the owner's anonymous count; bond cap 1 per horse per day from visitors; dock gate button for the owner while visitors are in (closing walks them out); hide "Club"; Tour stamp card in the Horse Book.

**Files:** `WorldClient.client.luau` (Map), `WorldLayout.luau`, `StableService.server.luau` (gate, post box), `CareService.server.luau` (visitor pat/treat), `Profile.luau` (tour stamps, carrot count, bond cap), `GrownUps.client.luau`, `Hud.client.luau`.

**Tests:** Lune: a non-friend is never listed; a visitor's pat gives a stamp and no bond; treats beyond one a day refused; bond from visitors ≤ 1 per horse per day with three visitors; every other care action on another plot still refused; closing the gate moves visitors out.

**Meshy (≈ 60 credits):**
- `rosette_wall` — "[CFT] A painted wooden display board for a barn wall, red barn colour frame with a little shingle roof, rows of small hooks and shelves for ribbons, rosettes and small trophies, empty and ready to fill, cheerful and toy-like."
- `post_box_carrots` — retexture of `post_box` (10): "[CFT] The same farm post box with a small carrot-shaped flag and a little basket of carrots on top."
- `visitor_bell` — "[CFT] A small wooden gate post with a brass bell and a flower box, county-fair style, toy-like."

**Parent checks:** two Studio players who are not Roblox friends: player 2's Map list is empty. (With two friend accounts on a published test server:) tap the friend's face, arrive at their gate, pat their horses for a stamp, drop a carrot; the owner taps the gate button and the visitor is walked out.

---

## Stage 6 — Reasons to come back (D-063)

**Goal:** something new every day and every month, with no pressure.

**Work:** monthly stamp payout (8 stamps = the month's saddle cloth via `Style`, earned flag, not sold; hide "This month" until a cloth exists); Horse Book (coats, breeds, rosettes, courses, Cups, Tour stamps, silhouettes until earned); Welcome Back Hay Bale (3+ days away, flat gift, the horse trots up); personal bests per distance ("New best!"); Photo Finish button on the win card and in the stable (`CaptureService:PromptSaveCapturesToGallery`/share prompt only); tour's first GO opens Race with Comet.

**Files:** `Jobs.luau`, `JobService.server.luau`, `Style.luau` (12 monthly cloths), new `shared/HorseBook.luau` + `client/HorseBookClient.client.luau`, `Profile.luau` (`lastSeen`, bests, book), `RaceController.client.luau` (photo, New best), `Tour.luau`.

**Tests:** Lune: 8 stamps grant the month's cloth once, and it can't be bought; the welcome-back gift is the same size after 3 and 30 days and never on consecutive days; personal best updates only on improvement; the book lists every coat in `MeshAssets`.

**Meshy (≈ 60 credits):**
- `welcome_hay_bale` — "[CFT] A round golden hay bale tied with a big red ribbon bow and a small gift tag, with a few carrots and an apple tucked on top, cheerful toy-like."
- `photo_frame_stand` — "[CFT] A county-fair photo board on wooden legs: a big painted frame with bunting and a gold rosette in one corner, the centre open, bright and toy-like, no text."

**Parent checks:** finish 8 monthly jobs (or set the stamp count in Studio): the month's saddle cloth appears in Tack & Paint as earned with no price. Change `lastSeen` to 4 days ago and rejoin: the hay bale gift appears once. Win a race and tap the camera: Roblox's own save/share prompt opens.

---

## Stage 7 — Careers, Legend Retirement and Rehoming (D-059)

**Goal:** David's "age" and "sold", without loss.

**Work:** career counters and a badge every 25 races (horse card); Veteran at 100 races; opt-in Legend Retirement (two taps, once-only suggestion) to a Hall of Fame paddock beside the barn: plaque, glow coat (a subtle gold sheen, ParticleEmitter sparkle under Reduced Motion off), still rideable and visitable; Rehome at the Market Corral (50% of price paid, tamed/gifted 0 + goodbye rosette; two-tap; goodbye card "Comet is joining Sunny Meadow Riding School!"; undo for 72 h at the same price; starter and last horse locked; in-use check); stall assignment stored per horse.

**Files:** `Leagues.luau` (`retire`), `Market.luau` (`rehome`, `undoRehome`), `MarketService.server.luau`, `HorsesClient.client.luau`, `StableService.server.luau` (paddock), `Profile.luau` (career, rehomed list with expiry, explicit stalls), `GameConfig.career`, `GameConfig.rehome`.

**Tests:** Lune: rehome pays 50% of `paid` and never more; undo within 72 h restores the horse with stats and name; after 72 h it's gone; starter and last horse refused; in-use refused; Legend horse keeps stats and is still rideable; stalls don't shift when a stalled horse retires.

**Meshy (≈ 90 credits):**
- `legend_paddock_arch` — "[CFT] A small paddock entrance arch of white-painted wooden posts with a curved top board, gold star finials and laurel garlands, bunting along the top, a little gold horseshoe in the middle, no text, cheerful toy-like."
- `legend_plaque_post` — "[CFT] A short wooden post holding a gold-framed plaque with a blank face and a small rosette, painted wood, toy-like."
- `riding_school_trailer` — "[CFT] A friendly two-horse trailer in cream and sky blue with rounded corners, a painted sun and meadow on the side, no text, ramp up, empty, toy-like." (For the goodbye card art; it never drives off-screen with the horse visible.)

**Parent checks:** set a horse's races to 100 in Studio: it shows Veteran and offers Legend Retirement once; accept: it appears in the paddock with a plaque and can still be ridden. Rehome a bought horse: the card shows Sunny Meadow Riding School and half the price; undo it at once: the horse is back. The starter horse has no Rehome button.

---

## Stage 8 — Class badges, first-win points and the Rosette Wall (D-062)

**Goal:** a clear next goal for older kids, without new queues.

**Work:** economy sim for the Silver target (casual player reaches the Silver Cup in 150–200 Silver races, about 600 points) and log the result in D-013 or a new decision; class badges (First Win, Rising Star, Open, Cup) on the picker and horse cards; +10 League Points for a horse's first win in each league; Rosette Wall in the stable (rosettes, Cups, Legend plaques); Stable Star goal cards (private; care, collection and skill goals) that hang new rosettes on the wall.

**Files:** `sims/economy.py`, `Leagues.luau`, `GameConfig.stakesUnlockPoints` (only after the sim), `RaceService.server.luau`, `StableService.server.luau` (wall), new `shared/StableStar.luau`, `StableBoard.client.luau`.

**Tests:** Python: `tests/test_sims.py` asserts the Silver race-count band with the chosen value; Lune: first-win bonus once per horse per league; badges by win count; goal cards never require a win in a particular race (no luck tasks, D-043).

**Meshy (≈ 0–30):** reuse `rosette_ribbon` and `trophy_cup` with retextures in league colours (10 each, only if colours can't be set in Studio).

**Parent checks:** a new horse's card says First Win; after its first win it says Rising Star and the League Points jump by 10 once; the stable's Rosette Wall shows the new rosette and a visiting friend sees it.

---

## Stage 9 — Later: seasons and events (D-063 later items)

**Goal:** the D30 layer, once stages 1–8 have been playtested.

**Work:** a free-only Ribbon Trail season (no end date or "last chance" text anywhere; items return next year); a weekend Fun Run that always comes back; Club visits and Friend Races (backlog); foal legacy from Legends with breeding (D-047). Each needs its own short debate check against D-050 and rule 3.

**Meshy:** to be planned per event, within the same cap.

**Parent checks:** nothing on any screen tells a child they'll miss out if they don't play today.

---

## Risks

- **Per-league queues (stage 1)** change the busiest server code just before the first playtest. Keep it small: queues decide only who claims a free course; race sessions are untouched. If it misbehaves, `GameConfig.queue.mode = "cards"` restores today's claiming.
- **League anchors (stage 2)** could make Rookies lose too often. Ship only inside the sim band; the anchors are config.
- **Reading "tired" as hurt (stage 4).** The yawn and lying-down poses must look content; check with kids, and drop the lying pose if any child says "is it sick?".
- **Teleport visits (stage 5)** only ever list Roblox friends; check that with two non-friend accounts.
- **Rehome regret (stage 7):** the 72 h undo and the two-tap confirm; the starter can never go.
