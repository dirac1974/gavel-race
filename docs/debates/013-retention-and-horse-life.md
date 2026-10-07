# 013 — Retention and horse life: what makes kids come back, and how should rest, the vet, ageing, selling, visits, the race queue, classes and the UI work?

Date: 2026-10-07 · Status: Decided provisionally (D-058 to D-065) · Moderated by Claude. The four designers ran as separate agents. Each wrote an opening from the moderator's brief without seeing the others, then one rebuttal round after reading all four openings and the moderator's list of splits.

## Question and constraints

David, 2026-10-07: "Take another pass looking at ways to improve the game and make it fun for kids and make them want to come back. Create a plan for improvements and create a plan for other features. We don't want [death], but over running horses could cause injury or care at the vet needed. Horses can age and become less effective, be sold etc… People could go around and visit other users' stables etc… how does the queue work for each [race]? Horse classes to qualify for certain races/prestige? Etc… use your market research and plan with the team of game designers. Then autonomously implement the decision after the debate. Use meshy as needed to create a truly professional game, UI and ease of understanding should be a focal point. Create to impress."

**The question, in one sentence:** what is the kid-safe, easy-to-read version of each of David's ideas, and in what order do we build them so tonight's first Studio playtest doesn't break?

**Topics:**
1. Overwork, rest and the vet.
2. Ageing, decline, retirement, legacy and selling.
3. Visiting other stables.
4. The race queue and the league lockout bug.
5. Race classes, qualifying and prestige.
6. The retention loop: first 5 minutes, daily, weekly, seasons, collections, welcome back, photos.
7. UI clarity.
8. Code risks found by the audit.

**Constraints:**
- Hard rule 1 (no wagering words or win-chance displays that read as odds), rule 2 (Diamonds never change win chance), rule 3 ("no streak resets to zero, no fake-urgency offers … Horses never die, sicken, or run away from neglect").
- D-039: the vet is a wellness clinic. "Sore legs after hard races" was rejected because it "teaches that racing hurts horses". David confirmed on 2026-10-05: "skip sick horses".
- D-037: no ageing, no trading, retiring is the player's choice. D-046: no demotion. D-042: visits Friends (default) / Club / Nobody, no likes or rankings, one free treat a day per friend (bond only). D-043: no streaks or countdowns. D-050: no Derby Pass (its season clock pressures kids). D-055: no win % or purse anywhere in the race HUD. D-013: Cup thresholds 100 / 110 / 1,400 / 3,000.

## Facts (researcher)

Two notes, both 2026-10-07:
- [Retention, horse life and kid-clear UI](../research/2026-10-07-retention-and-horse-life.md). Key points: the big kid games make ageing a *gain* (Horse Life's opt-in Elder quest, Adopt Me's Neon, Umamusume's Legacy); Howrse's death by old age is the counter-example. Roblox Community Standards forbid depicting animal abuse, and Kids & Select needs a Minimal or Mild rating. Real racing's maiden → allowance → stakes ladder fits our leagues if claiming races (a forced sale) are left out. Roblox's retention guidance: fun within 5 minutes (D1), clear goals (D7), updates every 2–4 weeks plus social features (D30); daily login rewards aren't in it. NN/g: touch targets ≥ 2 × 2 cm for young children, no dragging, goals stated plainly.
- [Systems audit](../research/2026-10-07-systems-audit.md). Key points: "Resting" shows after one cash race though the horse can race 4 more times; there is no visit button; two course cards cause a **league lockout** (a Rookie can't race while a Bronze rider holds one card and a race runs on the other, and the picker preselects the wrong-league card); bots sit at the human median ±6, so training barely shows solo; Silver Cup ≈ 470 races; monthly stamps lead nowhere; stars mean 8 things, Energy has 3 looks and ⚡ also means Sprint; phone dock buttons render about 35 px and labels about 8 px; one throwing sync decorator leaves "Your stable is loading…" forever; a locked save waits about 70 s then kicks; a horse being ridden can be retired; the client sets its own taming score; Green Cash and Wins are public in leaderstats.

## Openings (summaries of the independent statements)

### Engagement
- **Rest/vet:** no injury, no sore. "Happy-tired → Spa": after 3 cash races a day the horse looks "Puffed & muddy"; a free 30 s Spa (hose and brush) cleans it, +1 Energy once a day, a Passport stamp. Fix "Resting" to "Ready" until 0.
- **Age:** adds, never takes. Badge every 25 races, "Veteran" at 100 opens opt-in Legend Retirement (Hall of Fame paddock, glow coat, rideable, later a foal boost ≤ +3). "Rehome" at the Market Corral: NPC pays 50%, goodbye card, 24 h undo.
- **Visits:** Map "Friends' stables" with teleport; Tour stamps, post-box carrots, a treat, a "Help a friend" chore (+1 bond both).
- **Queue:** per league, not per card; lock on other leagues' cards; 20 s ring "Bots join at 0!"; groom while waiting; ≤ 45 s; bots at the league band.
- **Classes:** First Win → Rising Star → Open → Cup as entry rules; 470 races to Silver "is a D-30 killer", aim for 60–90 races per league after a sim; Stable Star prestige (20 levels × 8 goal cards).
- **Retention:** race within 2 minutes; Spa and friend treat daily; a recurring weekend Fun Run; pay out the monthly stamps; Horse Book, flat Welcome Back gift, Photo Finish camera; an update every 2 weeks, an event every 8.
- **UI:** horseshoe = Energy, heart = care, ★ only on one results row; dock ≤ 5 buttons ≥ 56 px, text ≥ 14 px; picker icon + 3 words; one "Next thing" pill.

### Competitive
- **Rest/vet:** no sore state. Lowering Rating turns care into win chance (why D-015 kept Energy out of speed); a sore state that changes nothing is fake. `restingLabelAt = 0`; a yawn at ≤ 1 Energy; Spa +1 Energy and a shine, never Rating, bond or tilt.
- **Age:** no decline ("a kid loses races without changing anything they did"). Legacy ≤ +2 starting Potential (after the D-047 sim). Buy-back 40% with a 24 h undo; never more than the price paid, or buy-and-sell becomes a farm.
- **Visits:** must never raise bond or Rating (bond = 2 Rating points, D-014; alt accounts could farm win chance).
- **Queue (his #1):** another league's card never takes a rider; `bestCourse` and the picker pick only joinable cards; a league waiting ≥ 8 s reserves the next card; `lobbyFillSeconds` 20 → 15. Bots at fixed league anchors {Rookie 50, Bronze 63, Silver 73, Gold 83} ± 6, so a Rookie at 56 wins about 1.3× as often (T 22) and training shows.
- **Classes:** no split queues (2 courses → worse lockout); +10 League Points for the first win in each league instead; Silver 1,400 → about 700 after a sim.
- **Retention:** personal bests per distance with "New best!", no public ranking.
- **UI:** one results row with "Your taps moved Comet from 12% → 19% to win."

### Child safety
- **Rest/vet:** against any sore, injured or limping state however mild: D-039, David's "skip sick horses", rule 3, and the team can't override it. Tired only at 0 Energy (yawn, straw, Zzz), hoof pips ("3 races left"), free Spa, build D-039's missing cool-down hose. Banned copy: hurt, sore, injury, limp. Put the trade-off to David.
- **Age:** no decline. Rehome ≤ 50% of market price; starter and last horse can't be rehomed; two-tap confirm; 24 h buy-back. Drop "going to a farm": parents read it as a death euphemism. Use "Comet is joining Sunny Meadow Riding School".
- **Visits:** a "Visit a friend" list of friends in this server whose gate is open; one pat and one treat; owner closes the gate in one tap and visitors walk out gently; hide "Club" until Clubs exist.
- **Queue:** fix the lockout, lock icon on other leagues' cards, no kid waits > 45 s, bots never named like real players.
- **Classes:** Silver ~470 races pushes long grindy sessions; sim about 600 points.
- **Retention:** monthly stamps pay out and the look returns next year (no FOMO); Ribbon Trail free with no end-date timer; photos only through CaptureService's share prompt; all horses tired → "Great day! Comet's dreaming of tomorrow."
- **UI:** ⭐ = care only; Sprint 🐇; dock floor 56 px / 14 px; toasts ≤ 10 words.

### Young player
- **Rest/vet:** happy-tired only ("A kid who sees 'sore' will think 'I hurt my horse'"). Spa Day: hose-and-brush mini-game, stamp, sparkle coat, bond +1, Energy +1. "A horse labelled tired that can still race 4 more times teaches kids that the words in this game lie."
- **Age:** badge every 25, opt-in "Legend" at 100. "Send to Sunny Farm" card, NPC 50%, **72 h undo** (24 h is too short for a weekend player).
- **Visits:** Map faces of friends in this server, golden hoofprints to their gate; walking Barn Lane reading signs is "a reading test, and a kid gives up after about 2 signs".
- **Queue:** one big "Race with Comet ▶" button; the server picks the course; an unjoinable card never appears; queue by league; bots at league midpoint ± 8.
- **Classes:** badges on the card, not queues; Silver ≈ 60 races after a sim; prestige a Rosette Wall, not a number.
- **Retention:** pay out the monthly stamp now or hide "This month ⭐N"; Horse Book; Photo button on the win card.
- **UI:** one symbol per meaning (horseshoe Energy, ❤️ care, 📣 fans, stars = how you rode); phone dock = horse card, RACE!, ☰ More; 56 px / 16 px floors; one results star row; picker copy ≤ 5 words.

## Rebuttals

The moderator listed nine splits (A–I) and two facts: D-055 bans a win % in the race HUD, and D-042 already allows one free treat a day (bond only).

- **A. Tired look and Spa.** Engagement dropped "Puffed & muddy" ("mud plus sweat can read as hurt"). Young player and Competitive moved to tired cues at ≤ 1 / 0 Energy only. Child safety moved partway: a grinning "Muddy & happy" splash look is fine, but not "Puffed", sweat or yawning before 0. Spa once a day per horse: Young player and Child safety want a calendar day with "Spa opens again tomorrow" ("a visible 20 h timer is fake urgency"); Engagement and Competitive said 20 h. Spa bond: Young player and Engagement dropped it (bond is Rating); Competitive keeps any bond inside the D-038 daily care cap; Child safety keeps +1.
- **B. Visits and bond.** All four: a pat gives a Tour stamp only; D-042's one treat stays; **bond from visits capped at 1 per horse per day in total** (Competitive's anti-farming rule). All four: the Map list **teleports to the friend's gate** (not inside); Young player moved off the walk ("a phone kid won't finish a long walk").
- **C. Queue.** All four converged: one "Race with Comet ▶" button over a **per-league queue that takes the next free course**; a card you can't join never shows; `lobbyFillSeconds` 15. Competitive's reserve rule is "no longer needed".
- **D. Bots.** Engagement and Young player moved to Competitive's fixed anchors {50, 63, 73, 83} ± 6. Child safety had no view on method but set the gate: solo Rookie win rate 20–35%, and bots never named like real players. Competitive: 20–35% in a sim before shipping.
- **E. Classes.** All four: badges on one queue, no class queues. Silver Cup target: Young player ~100–150 races, Engagement ≤ 200 races, Competitive ~600 points (~200 races), Child safety 600–700 points. All four: a sim first, D-013 unchanged until then.
- **F. Selling.** 50% of the price paid, never more (all four). Undo: 72 h (Engagement, Competitive, Child safety), 48 h (Young player). Copy: "joining Sunny Meadow Riding School" (all four; Young player conceded "farm"). Starter and last horse locked (all four).
- **G. Results line.** Competitive conceded the %. One star row ("You rode ★★☆"), "Good trip" row dropped. Cause line without %: "Your taps gained Comet 2 places" (Child safety), "1.5 lengths" (Competitive), "3 great boosts!" (Engagement), a tap-closeness bar (Young player).
- **H. Phone dock.** 3 items + ☰ More (Young player, Engagement, Child safety); Competitive: floor only, ≤ 5 items. Floors: 56 px buttons (all); text 16 px for main labels, never below 14 (all four, in slightly different words).
- **I. Prestige.** Rosette Wall, no number (all four). Stable Star goal cards private (Engagement, Child safety) and including skill goals (Competitive).

**What would change their minds:** kids skip the Spa twice or read the look as hurt (Engagement); solo Rookies win < 15% or > 40%, or kids can't explain a win from the cause line (Competitive); David approves a non-blocking "sore" state in writing *and* kids 8–12 don't read it as hurt *and* the maturity questionnaire stays Minimal (Child safety); 3 of 4 kids aged 8–10 on phones join a race, explain Energy and find a friend's barn unaided (Young player).

## Options

| Topic | Option | For | Against | Panel support |
| --- | --- | --- | --- | --- |
| 1 Rest/vet | **A. Happy-tired + free Spa Day (no injury)** | Gives David vet care; nothing is lost or hurt; fits D-039 | Not literally "injury" | 4/4 |
| | B. Mild "sore" that never blocks, fixed by a free vet visit | Closest to David's words | D-039 + David's 10-05 "skip sick horses"; reads as "I hurt my horse"; maturity rating risk | 0/4 |
| | C. Sore that lowers Rating | Real-racing flavour | Rule 3; turns care into win chance (D-015) | 0/4 |
| 2 Age | **A. Career badges + opt-in Legend Retirement, no decline** | Age is a gain (Horse Life, Umamusume) | Needs world space for the paddock | 4/4 |
| | B. Slow decline after N races | David's "less effective" | Loss; unreadable cause and effect; D-037 | 0/4 |
| 2 Sell | **A. NPC Rehome 50%, 72 h undo, starter/last locked** | Answers "be sold", frees stalls, undoable | Kids can regret it | 4/4 (undo 3–1) |
| | B. Player trading | Social | Scams, paid-item gating, D-037 | 0/4 |
| 3 Visits | **A. Map "Friends' barns" → teleport to gate; stamps, one treat, post box; bond cap 1/horse/day** | Removes the reading test; reason to visit | Teleport could help a follower (only friends are listed) | 4/4 |
| 4 Queue | **A. One "Race with Comet" button over per-league queues to the next free course; ring; 15 s fill** | Kills the lockout; no wrong-league cards | Server rework of `claimCard` / `bestCourse` | 4/4 |
| | B. Only fix preselect + grey unjoinable cards | Small | A Rookie can still be locked out | 0/4 (as a full fix) |
| 4 Bots | **A. Fixed league anchors {50, 63, 73, 83} ± 6, gated by a sim (Rookie solo 20–35%)** | Training shows | May feel harder for some | 4/4 after rebuttal |
| 5 Classes | **A. Badges on one queue (First Win, Rising Star, Open) + 10 LP for a league's first win; Silver target by sim (~150–200 races)** | No new lockouts; clear next goal | Less real-racing flavour than separate races | 4/4 (target split) |
| | B. Separate condition-race queues | Real-racing ladder | Splits fields across 2 courses | 0/4 |
| 6 Loop | **A. Monthly stamp payout, Horse Book, flat Welcome Back, personal bests, Photo Finish camera, Next-thing pill; Ribbon Trail and weekend Fun Run later** | Roblox's D1/D7/D30 guidance; nothing pressures | Several builds | 4/4 |
| 7 UI | **A. One symbol per meaning, 3-item phone dock + More, 56 px / 16 px floors, one results row** | Phones first | Moves familiar buttons | 3/4 on the 3-item dock |

## Recommendation

Eight decisions, D-058 to D-065, all `Accepted (provisional)`. Full text in `docs/memory/DECISIONS.md`; build order in [docs/plans/horse-life-and-retention.md](../plans/horse-life-and-retention.md).

1. **D-058 Rest and Spa Day (no injury).** The horse yawns at 1 Energy and lies down with Zzz at 0; the dock shows horseshoe pips and says "Ready" until 0, then "Napping". A free **Spa Day** at the vet (hose, brush and cool-down, about 30 s) once per horse per day: +1 Energy, a Passport stamp, a shine for its next race; no bond, no Rating; "Spa opens again tomorrow", never a timer. D-039's cool-down hose is built as part of it. No sore, hurt or injured state of any kind. **Flagged for David** (OPEN_QUESTIONS 5): if he still wants "injury", the least-bad version is option 1B, which the panel rejected 4/4.
2. **D-059 Careers, Legend Retirement and Rehoming.** No ageing or decline. A career badge every 25 races; at 100 races a horse is a **Veteran** and may take an opt-in **Legend Retirement** to the Hall of Fame paddock (glow coat, plaque, rideable and visitable; later a foal legacy ≤ +2 starting Potential, with D-047). **Rehome** at the Market Corral: the NPC pays 50% of what you paid (never more), two-tap confirm, a goodbye card "Comet is joining Sunny Meadow Riding School", undo for 72 h at the same price; the starter horse and your last horse can't be rehomed; never while in use. No trading.
3. **D-060 Visiting friends' barns.** Map → "Friends' barns": faces of friends in this server whose gate lets you in; tap to teleport to their gate. Pat each horse once for a Tour stamp (once per friend), one free treat a day (D-042), carrots in the post box (anonymous count); bond from all visitors capped at 1 per horse per day. The owner shuts the gate in one tap from the dock and visitors walk out gently. "Club" is hidden until Clubs exist. No counts, likes or guestbook text. Show-off: the Rosette Wall and the Legend paddock.
4. **D-061 One race button and a visible queue.** "Race with Comet ▶" joins the **league queue** (league + kind) for the active horse; the server sends it to whichever course frees first. Cards for other leagues never take a rider: they show "Watch" with that league's badge. A countdown ring with the gate filling by name, "Bots join at 0", 15 s fill (`lobbyFillSeconds = 15`). Kids can groom or ride while queued. Bots anchored by league {Rookie 50, Bronze 63, Silver 73, Gold 83, Champion 90} ± 6, shipped only if the sim shows a solo Rookie win rate of 20–35%; bot names never look like usernames.
5. **D-062 Class badges and the Rosette Wall.** One queue per league; the card shows the horse's class badge (First Win → Rising Star → Open → Cup). A horse's first win in each league earns +10 League Points. D-013 stays until an economy sim; the sim's target is a Silver Cup in **150–200 Silver races** for a casual player (≈ 600 points). Prestige is a **Rosette Wall** in the stable that visitors see, driven by private **Stable Star** goal cards (care, collection and skill goals). No claiming races, no demotion, no public number.
6. **D-063 Reasons to come back.** Monthly stamps pay out (8 stamps = the month's saddle cloth, earned not sold, and it comes back next year); a **Horse Book** with silhouettes; a flat **Welcome Back Hay Bale** after 3+ days away; **personal bests** per distance; a **Photo Finish** button on the win card (CaptureService's own prompt); "Great day! Comet's dreaming of tomorrow" when every horse is napping. Later: a free **Ribbon Trail** season with no end-date anywhere, a weekend Fun Run that always comes back. A small update every 2 weeks.
7. **D-064 One symbol per meaning, phones first.** Horseshoe = Energy everywhere; ★ = how you rode, only; ❤️ = care; 📣 = fans; 🎀 = monthly stamps; 🌱 = good family line (market); Sprint = 🐇 Short. Phone dock: horse card, RACE!, ☰ More; buttons ≥ 56 px rendered, labels ≥ 16 px, nothing below 14. One results row "You rode ★★☆" plus "Your taps gained Comet N places!" (only when positive; never a %). Picker cards one line ≤ 5 words; toasts ≤ 10 words; one "Next thing" pill; weekly and monthly jobs inline.
8. **D-065 Playtest-safety fixes (engineering).** pcall each sync decorator; a locked save shows "Opening your stable…" and keeps trying until the lock goes stale, with a "Try again" button, never a kick; no retiring or rehoming a horse being ridden, trained, queued or raced; taming scored on the server; Green Cash and Wins out of public leaderstats; picker redraw key includes league, kind and Cup; stall assignment kept explicit on retire.

## Minority view

- **Child safety:** a grinning "Muddy & happy" splash look after 3 cash races is acceptable, and the Spa may give +1 bond. Not adopted: three designers read mud as a possible hurt cue, and bond is Rating (D-014). It can be added later as a cosmetic (`spa.muddyLook`, off).
- **Competitive:** the phone dock needs only a floor (≤ 5 items, 56 px), not a 3-item limit. Not adopted (3–1); `ui.dockPhoneItems` holds it.
- **Young player:** 48 h undo for rehoming. Not adopted (72 h, 3–1).
- **Engagement:** Spa on a 20 h cooldown. Not adopted: Young player and Child safety showed a calendar day reads more simply and needs no timer.
- **Silver Cup target:** Young player wanted ~100–150 races, Child safety 600–700 points. The sim decides; the target band is 150–200 races.
- **Every designer, on injury:** unanimous against any sore state. Child safety: it would change only if David approves in writing after seeing this alternative *and* a playtest with 8–12-year-olds shows kids don't read it as hurt *and* the maturity questionnaire stays Minimal.

## Decision

Accepted provisionally as D-058 to D-065 under D-009 and listed in `REVIEW_QUEUE.md`. The injury question is open for David (`OPEN_QUESTIONS.md` 5).
