# Fun and return: pet and horse games, life stages, vet, classes, visits, queues, phone UI

Brief by `roblox-researcher`, 2026-10-12, for David's brief of the same day (`docs/reviews/fun-and-return-2026-10-12/brief.md`). Every page cited was opened on 2026-10-12. This note extends [retention and horse life](2026-10-07-retention-and-horse-life.md) and [world structure](2026-10-04-world-structure.md) and doesn't repeat them. **Fandom wikis returned HTTP 402 today**, so Horse Life, Wild Horse Islands and Bloxburg mechanics rely on the 2026-10-04 and 2026-10-07 notes plus each game's own Roblox description. Third-party sources are marked (3P).

**What changed since 2026-10-07:** David has now *decided* three things the team had argued away: injury that needs the vet, ageing with decline, and visiting beyond friends. This note looks for the kid-safe form of each. It doesn't argue against them.

## Short answer

- **Platform line on injury:** Roblox's maturity page puts "realistic depictions of real-life injuries" at **Moderate**, and says one realistic consequence is enough to lift a rating above Mild. Minimal allows only "occasional mild violence and/or light unrealistic blood" ([content maturity](https://create.roblox.com/docs/production/promotion/content-maturity)).
  - So a vet visit stays Minimal or Mild only if it shows **no wound, no blood, no limp and no pain**. It should be a tired-legs check with wraps and a cold hose, and the horse stays cheerful.
- **Best model for "over-running needs the vet": Umamusume.** Racing 3+ turns in a row gives a condition that the **Infirmary** removes, and low Energy raises the chance a training fails ([umamusu.wiki](https://umamusu.wiki/Game:Conditions), [Career Mode](https://umamusu.wiki/Game:Career_Mode), 3P). The cause is visible, avoidable and temporary.
- **Best model for ageing: a career, not a clock.** Umamusume runs a fixed career (about 72 turns), then the horse becomes a "Veteran" that still races and passes Sparks to the next trainee. Derby Owners Club retires a horse "to breed a second generation foal" ([Wikipedia](https://en.wikipedia.org/wiki/Derby_Owners_Club)).
  - Loss on a real-time clock is what hurt kids. Club Penguin players logged in "with apprehension"; one says "all of my puffles ran away and never came back" ([Saratoga Falcon, 2017](https://saratogafalcon.org/?p=8185)).
- **Classes:** real racing runs maiden → allowance → stakes → graded (G3, G2, G1, with Listed below G3) ([RRP](https://therrp.org/education/track-life/understanding-racing-levels/), [America's Best Racing](https://www.americasbestracing.net/learn/2014-graded-stakes-races)).
  - Umamusume turns this into *entry by fans*: Pre-OP and OP, then G3 to G1, with higher grades needing more fans.
  - That is the cleanest qualification ladder for us. It never demotes and never claims a horse.
- **Visiting strangers is where Roblox's 2025–26 hits went wrong:**
  - Steal a Brainrot drew "viral clips of upset children whose Brainrots were stolen" ([Wikipedia](https://en.wikipedia.org/wiki/Steal_a_Brainrot)).
  - In Grow a Garden 2, night raids are "free and central", with paid defences ([Kinzoo](https://www.kinzoo.com/blog/is-grow-a-garden-2-safe-for-kids-a-parents-guide), 3P).
  - Safe server-wide visiting has to be look-and-pat only, with nothing taken or given that matters.
- **Queues:** Roblox Party groups up to 6 friends, puts them on the same server and gives developers a party API ([newsroom](https://about.roblox.com/newsroom/2024/12/join-the-party-on-roblox); [SocialService](https://create.roblox.com/docs/reference/engine/classes/SocialService) `GetPartyAsync`, `GetPlayersByPartyId`). We can keep a party together in Open Practice without any invite UI.
- **Discoverability is the first fix.** Roblox's guidance: "Highlighting something … is more effective than describing it in text", and "players generally don't like to read instructions" ([onboarding](https://create.roblox.com/docs/production/game-design/onboarding-techniques)). NN/g: icon labels "should be visible at all times" ([icon usability](https://www.nngroup.com/articles/icon-usability/)).

## 1. The comparable games

**Live players** come from the [Roblox games API](https://games.roblox.com/v1/games?universeIds=2682938349,5422546686,383310974,3317771874,7436755782) (primary source, one moment on Monday 2026-10-12):

| Game | Playing | Visits | Max server size |
| --- | --- | --- | --- |
| Wild Horse Islands | 2,914 | 684M | 20 |
| Horse Life | 2,268 | 370M (2.25M favourites) | 30 |
| Adopt Me | 254,266 | 45.0B | 35 |
| Pet Simulator 99 | 53,789 | 2.67B | 10 |
| Grow a Garden | 21,207 | 36.0B | 4 |

- Grow a Garden peaked at 22.3M concurrent players in August 2025 ([Wikipedia](https://en.wikipedia.org/wiki/Grow_a_Garden)).
- A third-party June 2026 snapshot ranked Adopt Me 2nd (about 324k), Steal a Brainrot 9th (about 151k) and PS99 14th (about 78k) ([RoWatcher](https://rowatcher.com/news/the-most-popular-roblox-games-right-now-ranked-by-live-players), 3P).
- Horse games are a steady niche of about 2–3k each.
- I couldn't locate Equus or Horse Valley in the API today.

| Game | Core loop | D1 / D7 hooks | Collection and progression | Social and showing off | What kids praise / complain about |
| --- | --- | --- | --- | --- | --- |
| **Wild Horse Islands** | Tame wild horses, sell horses and resources, train, bond, breed (Roblox description) | New islands and catches; a "Competition Hub with races and sabotage items" | Large breed catalogue, stable space as the gate | Private island set to public, friends or locked (04 note); trading hub | Praised for scale and its world; "older" look (Earnaldo 2026, 3P, Robux-promo site) |
| **Horse Life** | Tame, breed, build a home; three maps: Main, Market, "Competitor Hub" (description) | Seasonal events (Halloween map and event horse now); a race invite every 15 min (07 note) | Journal quests unlock breeds; mutations; opt-in Elder at age 100 (07 note) | Shared spawns, trading world | "Less toxic, more mature playerbase"; breeding depth (Earnaldo, 3P) |
| **Adopt Me** | Care tasks raise a pet; decorate a house | Events (07 note); new pets | Baby → full grown; 4 full grown → Neon | Houses, block parties; **trading drives status** | Kids: social play and collecting. Complaints: "rise in scammers", "pay-to-win" ([CSM kid reviews](https://www.commonsensemedia.org/website-reviews/adopt-me/user-reviews/child)); trust-trade and quick-swap scams ([Screenwise](https://screenwiseapp.com/media/adopt-me-game), 3P) |
| **Pet Simulator 99** | Break coins → buy eggs → hatch stronger pets → rebirth | "Frequent events"; long-odds Huge pets keep kids opening "one more egg" | 3,000+ pets | Trading Plaza (after the first rebirth) | Cute and free, but "most play is clicking and waiting"; trade pressure on younger kids ([Screenwise](https://screenwiseapp.com/media/pet-simulator-99-game), 3P) |
| **Grow a Garden** (and GaG 2, June 2026) | Plant → harvest → sell → rarer seeds; grows offline | Weekly drops you must be online to claim; restocks | Seeds, pets, mutations | Robux crop stealing (GaG 1); free night raids (GaG 2) | Real-money and off-platform trading (Wikipedia); raid anxiety, "defensive purchases" (Kinzoo, 3P) |
| **Star Stable Online** | Story quests, care, racing in Jorvik | Daily care; quests | Horse levels; gear | MMO chat | Kids: "fun and immersive". Complaints: subscription wall ("can't do much without paying"), "toxic community", "no progress or health meter for the horse" ([CSM](https://www.commonsensemedia.org/game-reviews/star-stable)) |
| **Rival Stars Horse Racing** | Rebuild a ranch: train, race, breed | Live events, seasonal events; training and breeding timers | Levels 1–10, genetics breeding; a career mode with **four leagues** ([App Store](https://apps.apple.com/app/id1215477266)); horses buyable and sellable | Leaderboards, team rankings | 4.8★ from about 148k ratings: "graphics … on the next level". Complaints: gold "takes hours", "getting hella greedy", asks to move horses "without selling them" (App Store). Review: "repetitive and grindy" ([DayOne](https://playday.one/2026/04/27/rival-stars-horse-racing-review/), 3P) |

**Patterns**
1. The big hits run on **collection plus events**, not on daily care.
2. Kids' top complaint across the board is **scams and pressure from trading**, then paywalls.
3. Nobody praises loss.

## 2. Ageing and life stages

**Evidence**
- **Umamusume** ([Career Mode](https://umamusu.wiki/Game:Career_Mode), 3P):
  - A career is about 3 in-game years (72 turns plus a 6-turn finale). Missing a goal ends the run early.
  - When the run ends, "successfully or not", the horse joins the roster as a **Veteran** that can still race and gives Sparks to future trainees.
  - Sparks pass stats, aptitudes and skill hints to the next horse, capped at 10 stars at the start ([Game8](https://game8.co/games/Umamusume-Pretty-Derby/archives/536822), 3P).
  - The arc ends in a gain, never in loss.
- **Derby Owners Club** (arcade): after a race you either pay to continue or "retire the horse in order to breed a second generation foal", and "a horse's breeding ability is limited" ([Wikipedia](https://en.wikipedia.org/wiki/Derby_Owners_Club)).
- **Rival Stars:** training has a ceiling. "Each horse has a limit … you can't just keep making them more and more powerful" (DayOne). I found no retirement or decline. Breeding foals of a higher grade than their parents is what moves the player forward.
- **Nintendogs:** dogs "stay puppies forever!", and "the worst thing that happens to neglected digital dogs is that they run away" ([Spokesman-Review, 2005](https://www.spokesman.com/stories/2005/oct/17/a-dogs-life)). Even that drew complaints.
- **Club Penguin:** kids remembered daily anxiety over puffles that ran away (Saratoga Falcon, above).
- **Neopets:** the lowest hunger level is literally named "dying", but pets can't die. Hunger only blocks battles and lowers mood ([Neodex](https://pinkpt.com/neodex/index.php?title=Hp), 3P).
- Howrse's old-age death and Horse Life's opt-in Elder are in the 07 note.

**What worked and what didn't**
- **Worked:** decline that is **tied to use, not to time**, is shown in advance and turns into something new: Veteran status, Sparks, a foal.
- **Backlash:** loss caused by being away (runaways, deaths) and anything that makes a kid feel watched.

**For Giddy-Up (David's arc, in kid-safe form)**
1. **Count age in races, never in days.** Horse Life's mounts only age "when equipped" (07 note). A kid who's away for a month comes back to the same horse.
2. **Four stages on the horse card, as a path the kid can see from day one:**
   - Youngster: first 25 races, with a small growing bonus as it learns.
   - Prime.
   - Veteran: from about 100 races (D-059 already uses 100).
   - Legend.
3. **Gentle decline:**
   - From Veteran, the horse's Rating *ceiling* drops 1 point per 25 races, to a floor of about −6. It is never a sudden drop, and the card says so 10 races ahead ("Comet is getting wise. Soon a little slower").
   - It never touches Practice. Open Practice already equalises horses (D-068), so a Veteran still races friends as an equal.
   - Put it behind config, and sim it against the D-068 ladder first.
4. **Retirement gives something:** the Legend paddock (D-059), plus a capped Spark to one foal once breeding (D-047) exists. Unretire stays (D-068).
5. **"Sold":** keep it NPC-only, as Rehome (D-059). Rival Stars players' wish to move horses "without selling them" suggests a free **Pasture** or "lend to the Riding School" option (the horse comes back any time) is kinder than a sale.

## 3. Injury and the vet

**How other games handle it**
- **Umamusume:**
  - **Skin Outbreak** comes from "racing for 3 or more consecutive turns".
  - **Legs of Glass:** racing twice in a row costs Energy and gives Practice Poor.
  - The **Infirmary** removes conditions. In Career Mode it restores a little Energy and has a *chance* to cure (umamusu.wiki, 3P).
  - Training at low Energy can fail and lose stats.
  - The vet is a turn spent, not money.
- **Star Stable:** the vet is a **mood boost** for 100 Star Coins, free if mood is already full. Daily feeding, watering, brushing and hoof picking raise mood too ([wiki.gg](https://starstable.wiki.gg/wiki/Veterinary), 3P). I found no injury system.
- **Horse Valley:** the vet restores needs for 25 diamonds (04 note).
- **Rival Stars, Horse Life, Equestrian the Game:** I found **no primary or reachable source** for injury or vet mechanics. Equestrian's site and the fandom wikis didn't load. Treat these as **unconfirmed**.

**Kid reactions:** I found no direct data on kids' reactions to horse injury. The nearest evidence is the anxiety over neglect and runaways above, and adults finding sim diagnoses confusing (Horse Racing Manager, 07 note).

**Roblox policy** ([content maturity](https://create.roblox.com/docs/production/promotion/content-maturity))
- **Minimal:** "occasional mild violence and/or light unrealistic blood".
- **Mild:** "repeated mild violence, heavy unrealistic blood".
- **Moderate:** "realistic depictions of real-life injuries". Any realistic consequence lifts the rating above Mild.
- **Never allowed:** "animal abuse and torture".
- Kids & Select needs Minimal or Mild (04 note).

**What keeps us at Minimal (interpretation, check in the questionnaire):**
- Ruled out: wounds, blood (even cartoon blood), a limp cycle, pain sounds, collapsing, bandages over a cut, needles.
- Fine: the cause is effort, not violence. A "tired legs" state with **leg wraps, an ice-boot or cold-hose mini-game, a happy horse and a carrot** depicts rest, not injury.

**The gentlest real version (builds on D-058, D-015, D-039):**
- **Cause:** only *over-running*. Racing N cash races in a row without a care or Spa break, the Umamusume model. Never neglect, never time away.
- **Warning first:** one race before, the card shows "Comet's legs are working hard. Next: a vet check."
- **Effect:**
  - The horse can't enter **cash races** until a free vet check (about 30 s, tap-only: hose, wraps, carrot).
  - Practice, rides and visits stay open.
  - No Rating change, no lasting effect, no cost, no Diamonds.
- **Copy:** "Comet ran his heart out! Vet check time" never blames the kid. The words hurt, injury, sick and limp stay banned in the UI.

## 4. Classes and qualification

**Real racing in kid words**
- **Maiden:** hasn't won yet.
- **Claiming:** any owner can buy your horse at the listed price. Skip it, it's a forced sale.
- **Allowance:** has won, but isn't ready for stakes. Lighter weights for less experience.
- **Stakes:** the top, biggest-paying races.
- **Graded stakes:** a committee ranks them each year as G1, G2, G3 and Listed, from the best fields (RRP; America's Best Racing).

**How games turn it into progression**
- **Umamusume** ([Career Mode](https://umamusu.wiki/Game:Career_Mode)): Pre-OP → OP → G3 → G2 → G1. Entry needs a debut win and "a minimum number of fans", and higher grades need more. Fans come only from racing.
- **Rival Stars:** horse levels 1–10 gate events, plus a 4-league career.
- **Photo Finish:** "from a local derby … up to … the Cup", 7+ tiers, and seasons that added tiers with trophy boosts ([App Store](https://apps.apple.com/us/app/photo-finish-horse-racing/id993764346)).
  - A top review objects to the all-caps "**YOU LOST!**" (D-067 already avoids this).
- **Derby Owners Club:** handicap races for weaker horses, rated by "prize money they earned".

**For Giddy-Up (extends D-062 labels into entry rights):**
- Keep **First Win → Rising Star → Open → League Cup** as is.
- Add a **Graded tier** of named prestige races, such as Bronze G3 "Daisy Stakes" and a Champion G1 "Giddy-Up Derby".
- **Entry by the horse's record:** wins in its league, plus *fans* (D-019 cheering already makes Fan XP) or rosettes. Never by money.
- Graded races run on a **fixed, always-returning schedule**, for example a G3 every hour. No "last chance".
- They reuse the league queue (D-061) with bots filling the field, so they don't split the queues.
- Winners get a title on the horse ("G1 winner"), a plaque for the Rosette Wall and a Horse Book page.
- No demotion, no claiming, no public ranking (D-042).

## 5. Visiting other players' bases

**Patterns**
- **Adopt Me:** the owner locks the house to family and friends.
- **Bloxburg:** Blocked / Knock / Guest / Roommate tiers (07 note).
- **Restaurant Tycoon 2:** up to 9 players a server, and "friends can eat at each other's" restaurants. Ratings are six stars on *your own* restaurant (food, service, design and so on), not votes from others ([Screenwise](https://screenwiseapp.com/media/restaurant-tycoon-2-game), 3P).
- **Steal a Brainrot and Grow a Garden 2:** visiting means **taking**, and the result was crying kids and paid defences (above).

**Policy**
- Social hangouts are blocked from Kids & Select (04 note).
- Chat needs an age check, and checked players only chat within nearby age bands, so visitors can't rely on chat (04 note).
- Party chat is 13+, and parents can switch Party off ([newsroom](https://about.roblox.com/newsroom/2024/12/join-the-party-on-roblox)).
- **Likes and ratings:** I found no Roblox rule against them (unconfirmed). They do invite popularity contests, bullying and alt-account farming, and D-042 rejects them.

**For Giddy-Up (extends D-060, D-042)**
- A visit setting with **Friends** (default), **Everyone here** and **Nobody**.
- **Strangers:**
  - can walk the barn and see the Rosette Wall and Legend paddock;
  - can **pat** and send one of 4 **preset cheers** (🐴💛👏⭐) that show anonymously;
  - can't give treats, can't use the post box, give no bond and can't teleport by name.
- Friends keep D-060's treats and pins.
- The owner's gate button walks everyone out. No counts or leaderboards.
- Barn Lane gets **"Open barn" flags** so strangers find barns by walking, not from a player list.

## 6. Queues and parties

**Evidence**
- **Horse Life:** a race invite every 15 min, needing 3 players; racing has moved to a separate hub (07 note; the Roblox description lists a "Competitor Hub").
- **The common Roblox pattern:** walk into a zone, a countdown starts at the minimum count, and an owner can restrict it to friends ([DevForum queue module, July 2026](https://devforum.roblox.com/t/queue-v1-a-zone-based-player-queue-module/4755312), community).
- **Party:** up to 6, same server ([newsroom](https://about.roblox.com/newsroom/2024/12/join-the-party-on-roblox)). `GetPlayersByPartyId` doesn't yield ([SocialService](https://create.roblox.com/docs/reference/engine/classes/SocialService)).

**For Giddy-Up:** D-061 and D-067 already built the ring, the gate slots and "Bots join at 0". What David couldn't see is *which line he's in and why*.
- Name each line on the card:
  - "🥉 Bronze line: horses like Comet";
  - "🏆 Cup line: Cup horses only";
  - "🎈 Open Practice: anyone, equal horses".
- Add a one-time three-picture strip: *1 Join the line → 2 The gate fills → 3 Bots fill empty spots at 0*.
- **Party:** players in the same Roblox Party who tap 🎈 Practice follow each other's course automatically (extends D-068's friend follow; no popup).

## 7. UI clarity for ages 8–13 on phones

Extends the 07 note's NN/g touch-size and cognition points.

- **Icons:** pair every icon with a visible word, never hover-only ([NN/g](https://www.nngroup.com/articles/icon-usability/)).
- **Show, don't tell:** highlight the next thing rather than describe it. Teach "without words" for kids still learning to read. Use contextual tutorials that fire when the feature is first relevant ([Roblox onboarding](https://create.roblox.com/docs/production/game-design/onboarding-techniques)).
- **Small screens:** use fonts "readable on mobile devices, not just desktop", avoid thin fonts, and "move less-important buttons into a collapsible menu" ([adaptive design](https://create.roblox.com/docs/production/publishing/adaptive-design)). D-064's ☰ More already does this.
- **Show the goal state before play** (Mission PAW: 6-year-olds grasped it). Young kids misread abstract arrows ([NN/g kids cognition](https://www.nngroup.com/articles/kids-cognition/)).
- **The gap:** Star Stable's "no progress or health meter" complaint (CSM) is the warning. Kids need to *see* the cause behind every state: tired legs, Veteran, a class lock.
- **For us:** every new state (vet check, life stage, graded entry, open barn) gets one picture-chip on the horse card plus a just-in-time 👇 highlight the first time it matters, through the Next-thing pill (D-064).

## 8. Ranked: 15 opportunities

| # | Opportunity | Evidence | Effort | Risk | Builds on |
| --- | --- | --- | --- | --- | --- |
| 1 | **"Find it" pass:** a first-time 👇 highlight for each built feature (Spa, visits, Rehome, Book, classes), fired by the Next-thing pill when it's first relevant; a **"What's here" picture map** of the stable | Brief's key finding; Roblox onboarding (highlight > text, contextual); NN/g labels | S–M | Low | D-064, D-049, D-067 |
| 2 | **Named queue lines + a 3-picture "how racing works" strip**; the card says which line and why | David's queue question; DevForum queue pattern; Horse Life's 15-min wait shows ours is faster but invisible | S | Low | D-061, D-067, D-068 |
| 3 | **Vet check from over-running:** warning one race before, cash races wait for a free 30 s cold-hose-and-wraps play; no Rating change, no limp or blood | David's decision; Umamusume consecutive-race conditions + Infirmary; maturity page (no realistic injury) | M | Med: copy and art review; questionnaire | D-058, D-039, D-015 |
| 4 | **Graded prestige races** (G3 → G1) on an always-returning schedule, entry by wins + fans; titles and plaques | Umamusume fan-gated grades; real G1–G3; Photo Finish tiers | M–L | Med: field fill (bots), sim the entry rule | D-062, D-048, D-019, D-013 |
| 5 | **Life stages by races, not days:** Youngster → Prime → Veteran (gentle ceiling decline, warned 10 races ahead, never in Practice) → Legend | David's decision; Umamusume Veteran; Horse Life "only age when equipped"; Club Penguin and Nintendogs backlash | M–L | Med–High: must sim against the D-068 ladder | D-059, D-068, D-046 |
| 6 | **Breeding with Legend Sparks** as the Champion endgame (free, never paid random) | Umamusume inheritance; DOC retire-to-breed; Rival Stars and Horse Life breeding draw; paid random item rules | L | Med: PolicyService if any Robux touches it | D-047, D-059, D-068 (Champion endgame) |
| 7 | **Open barn for everyone in the server:** pat + 4 preset cheers for strangers; treats and post box stay friends-only; owner gate | David's decision; Adopt Me and Bloxburg locks; RT2 visits; Steal a Brainrot as the anti-pattern | M | Med: griefing and following; default Friends | D-060, D-042 |
| 8 | **Party keeps together:** a Roblox Party joins the same Open Practice course | Party newsroom; `GetPlayersByPartyId` | S | Low | D-068 |
| 9 | **Horse Book breeds and graded pages:** silhouettes for every coat, breed, title | PS99 3,000+ pets; WHI catalogue; collection drives D7 | M | Low | D-063 |
| 10 | **Returning seasonal events** with a free track (a themed course, a coat, an event horse), always back next year | Horse Life's Halloween map and event horse; PS99 "frequent events"; GaG weekly drops | M | Med: no FOMO copy | D-063, D-050 |
| 11 | **"Lend to the Riding School"** (free pasture loan, take back any time) beside Rehome | Rival Stars "without selling them" request; kids' regret | S | Low | D-059 |
| 12 | **Foal stage care loop** (bottle, first steps, name) before Youngster races | Adopt Me baby → full grown; Rival Stars "Care for Foal" | M | Low–Med | D-047, D-038 |
| 13 | **Picture-chip for every horse state** on the card (Ready, Napping, Vet check, Veteran, class) | Star Stable "no health meter" complaint; NN/g | S | Low | D-064, D-058 |
| 14 | **Stable Star → visible prestige level** for the stable (private; shown as a barn flag colour, no number) | Rival Stars Prestige 1–20 (07 note); D-062 cards exist | S–M | Low | D-062 |
| 15 | **"Help a friend" chore** (both get a bond point; friends only) | Social retention (07 note); D-060 deferred it | S | Low–Med: alt farming, capped | D-060, D-014 |

**Off-limits (unchanged):** claiming races, player trading, paid cures or age-ups, stealing or raids, likes and visitor counts, real-time ageing.

## Open uncertainties

- **Fandom wikis (402) and Common Sense's Adopt Me game page (404) were unreachable today.** Horse Life, WHI and Bloxburg mechanics come from the 2026-10-04 and 2026-10-07 notes. Kid reviews come only as Common Sense AI summaries, so there are no individual quotes.
- **Not opened:** YouTube, Reddit and DevForum player threads. Kid sentiment here is from Common Sense, App Store and Screenwise only.
- **Injury and vet in Rival Stars, Horse Life and Equestrian the Game:** unconfirmed.
- **Whether a "vet check / tired legs" state changes the maturity questionnaire answer:** unconfirmed. The policy text points to Minimal if nothing realistic is shown. Confirm when filling it in.
- **Screenwise, Kinzoo, Earnaldo and RoWatcher** are third-party; Kinzoo and Earnaldo are commercial.
- **Player counts** are a single Monday snapshot.
- **Party API details** beyond the SocialService reference page weren't verified in Studio.
