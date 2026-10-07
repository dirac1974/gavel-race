# Retention, horse life and kid-clear UI

Brief by `roblox-researcher`, 2026-10-07, for David's request of the same day: "ways to improve the game and make it fun for kids and make them want to come back", with injury and vet care from over-running, ageing and selling, visiting stables, how the race queue works, horse classes and prestige, and UI clarity. All pages were opened on 2026-10-07. Fan wikis were read through the Fandom API and are third-party. This note builds on [baseline](2026-10-04-baseline.md) (gambling policy, comparable games) and [world structure](2026-10-04-world-structure.md) (server size, plots, chat, trading gates, Kids & Select) and does not repeat them.

## Short answer

- **Ageing that takes something away is rare in the big kid games.** The ones that work make getting older a *gain*. Horse Life turns age 100 into an opt-in "Elder" quest that adds a halo and a stat passive. Adopt Me's grown pets open up Neon fusion. Umamusume's retirement turns a racer into a parent that passes on bonuses. Howrse's death at 25–32 years is the counter-example.
- **Injury from over-racing goes against D-039, which David confirmed on 2026-10-05 ("skip sick horses").** Roblox forbids depicting animal abuse. A kid-safe version of what David wants is a *tired, happy horse that wants a rest day*, with a visit to the vet's spa. Nothing gets hurt, and nothing is lost.
- **Classes:** real racing's maiden → allowance → stakes → graded ladder fits our leagues, as long as we leave out claiming races (they are a forced sale). ZED Run's points-based class moves are a model to *avoid* because they demote.
- **Visits:** Adopt Me and Bloxburg both use owner-controlled locks and permission tiers. Our D-042 (Friends by default, Club or Nobody) already matches the safest of these.
- **Retention:** Roblox's own guidance is to reach the fun within 5 minutes for D1, give clear goals for D7, and ship updates every 2–4 weeks plus social features for D30. Daily login rewards are *not* in Roblox's guidance.
- **UI:** NN/g says kids need touch targets of 2 × 2 cm or larger, no dragging, real-world icons and goals stated plainly.

## 1. Horse life: ageing, rest, vet, selling

**Evidence**
- *Horse Life* ([Ages](https://horse-life-wiki-roblox.fandom.com/wiki/Ages), third-party wiki): Baby → Teen → Adult → Elder. A horse grows up in 15–25 minutes, and "mounts only age when equipped". At age 100 the owner *may* start eldering: 100 points from bond requests (+1), races (+3) and boss tames (+5). That earns a cosmetic halo and wings plus a permanent stat passive. Only one horse per stable can be eldering at a time. Horses never decline or die.
- *Adopt Me* (third-party guides found by search; the stages and Neon fusion are widely documented, but these pages weren't opened): pets grow through 6 stages by doing tasks. Four Full Grown pets fuse into a Neon, which starts again at "Reborn". Ageing only adds. Age-Up potions are earned through friendship levels, and a Super Age-Up Potion is sold for 225 Robux ([games.gg](https://games.gg/adopt-me/guides/adopt-me-super-age-up-potion-guide/), third-party). That is a paid time-skip.
- *Umamusume* ([Game8 Legacy guide](https://game8.co/games/Umamusume-Pretty-Derby/archives/536822)): a career is a fixed run. At the end the racer "gain[s] a set of random Sparks" and becomes a Legacy (a parent, and later a grandparent) that boosts future trainees' starting stats and skills. Retirement is the main reason players replay.
- *Howrse* ([Howrse Archive, Age](https://howrsearchive.weebly.com/age.html), fan site): horses can die of old age between 25 and 32 unless they carry a Philosopher's Stone, and only death from old age earns a pass. This is the loss pattern our hard rule 3 forbids.
- *Nintendogs*: dogs "could never die or age" ([Activision Blizzard history of digital pets](https://newsroom.activisionblizzard.com/p/unleashed-a-brief-history-of-digital)). The same article notes that kids held funerals for dead Tamagotchis. Loss lands hard at this age.
- *Horse Racing Manager* (adult sim, [Steam thread](https://steamcommunity.com/app/2740170/discussions/0/802342156092207494/)): injuries and chronic illnesses with monthly fees. Players found the diagnoses confusing even as adults.
- *Photo Finish* ([App Store](https://apps.apple.com/us/app/photo-finish-horse-racing/id993764346)): food, rest and training raise performance. Races run in tiers "from a local derby … up to … the Cup".
- **Roblox policy** ([Community Standards](https://about.roblox.com/community-standards)) prohibits "Depicting or glorifying human, animal, or fictional creature abuse and torture" and "realistic … depictions of … graphic violence, or death". A limping racehorse isn't torture. But Kids & Select needs a Minimal or Mild rating (world-structure note), so even mild animal-harm themes are a risk for us.

**Implications for Giddy-Up**
- **Rest, not injury.** Energy (D-015) already limits cash races. Build on it: after a busy day the horse shows *happy-tired* cues (a yawn, lying down in the stall). A **Spa Day** at the vet (a free massage or hose mini-game, plus a stamp in the Health Passport) gives a small *bonus* for the next race. Skipping the spa costs nothing. This gives David his "care at the vet" without anyone getting hurt. Real "injury" or "sore legs" stays rejected, since D-039 already rejected sore legs and David confirmed it.
- **Career milestones, not age decline.** Instead of years, each horse shows a *career* (races run, wins, Cups) with a badge every 25 races. Then comes an **opt-in Legend Retirement** (Horse Life's elder model plus Umamusume's legacy): the horse moves to a Hall of Fame paddock, gets a plaque and a glow coat, stays rideable and visitable, and passes a small, capped *starting* boost to one foal (needs D-047 breeding). Nothing is forced, so nothing is lost. D-037 already makes retiring the player's choice. Keep it that way.
- **Selling:** NPC buy-back at the Market Corral fits the economy ("selling surplus"). Show a goodbye card ("Comet is going to a farm with a big field!") and allow a 24 h buy-back for the same price, so a kid who sells by mistake can undo it. **No player-to-player trading.** It would need `IsPaidItemTradingAllowed` gating for any item bought with Robux ([PolicyService](https://create.roblox.com/docs/reference/engine/classes/PolicyService)). Adopt Me needed a Trade License test and "unfair trade" warnings to fight scams ([Trade System wiki](https://adoptme.fandom.com/wiki/Trade_System)). Grow a Garden drew real-money trading for rare items and off-platform scams ([Wikipedia](https://en.wikipedia.org/wiki/Grow_a_Garden)). D-037's "no trading" stands.

## 2. Visiting stables

**Evidence**
- *Adopt Me* ([Houses wiki](https://adoptme.fandom.com/wiki/Houses)): an owner locks the house, and then only family and friends can enter. A house can be "listed for trade" and toured, which mixes visits with trading.
- *Bloxburg* ([House Permissions wiki](https://welcome-to-bloxburg.fandom.com/wiki/House_Permissions)): Blocked, None (knock only, the default), Guest and Roommate tiers, plus per-door locks. The wiki says the feature is "currently unavailable", which shows how fragile these systems are.
- Matchmaking can weigh **Friends** when picking a server ([Customize matchmaking](https://create.roblox.com/docs/matchmaking/customize-matchmaking), up to 2 custom signals). That makes it more likely a friend's stable is in your server.

**Implications:** D-042 (Friends default, Club, Nobody, an anonymous carrot count, one free treat a day) is already safer than Adopt Me. What's missing is *a reason to visit*:
- **Stable Tour stamps.** Visit a friend's barn and pat each horse to get a stamp. Each friend's stamps count once.
- **Show-off spots.** A trophy wall and Hall of Fame paddock that visitors see.
- **"Help a friend" chores** that give *both* players a bond point.

Keep it to no likes, no rankings and no free-text guestbooks (D-042 already rejected popularity scores).

## 3. Race classes, prestige and the queue

**Evidence**
- Real racing ([Retired Racehorse Project](https://therrp.org/education/track-life/understanding-racing-levels/)) runs "like a grade school system": maidens for horses that haven't won, allowance races with conditions (for example "non-winners of 2"), then stakes. A claiming race means "a horse can actually be claimed away from its owner", which is a forced sale.
- *ZED Run* ([beta classes post](https://medium.com/zed-updates/beta-racing-classes-v-1-34401f15e119); Medium blocks automated reading, so these figures come from a search summary and are **unconfirmed**): 1st = +4 points … 12th = −4, and horses move up *and down* between Classes 1–5.
- *Nintendogs* ([Wikipedia](https://en.wikipedia.org/wiki/Nintendogs)): Beginner → Open → Expert → Master → Championship. A top-3 finish moves the dog up, and it never moves down.
- *Rival Stars* ([Prestige wiki](https://rival-star-horse-racing-player-guide.fandom.com/wiki/Prestige)): Prestige 1–20, each with 10–13 goals ("Breed a Gr4", "Race against your rival").
- *Horse Life queue* ([Horse Races wiki](https://horse-life-wiki-roblox.fandom.com/wiki/Horse_Races)): every 15 minutes there's a 70% chance of a race invitation. A race needs 3 players and starts 30 s after that. In May 2026 Horse Life moved racing to a separate "competitive realm".

**Implications**
- Our queue (D-036): a league's race posts within 30 s of its first rider, and bots fill the gaps after 20 s. Fields stay within a Rating band of ±12, widening to ±20. That's already much shorter than Horse Life's 15-minute cycle. **What's missing is showing it.** Show a big countdown ring and the horses filling the gate with names, and say "Bots join at 0 so you never wait long." Let kids groom or ride while they wait.
- **Classes inside each league, condition races in kid words:** "First Win" (for horses with no wins in this league), "Rising Star" (fewer than 3 wins), "Open", then the league's **Cup** (Stakes) and **Grade 1 Derby Day**. These are entry conditions only, so they never affect demotion or win chance. **Never claiming races.**
- **Prestige for the stable, not the horse:** a Stable Star level built from goal cards (Rival Stars style). This gives older kids something long-term to chase once their horses reach Gold.

## 4. Coming back: what works on Roblox

- **Roblox guidance** ([Retention](https://create.roblox.com/docs/production/analytics/retention)):
  - D1 depends on the core loop and FTUE: finish onboarding "in 5 minutes or less".
  - D7 depends on "clear short-term and long-term goals".
  - D30 depends on "smaller updates … every 2-4 weeks, and bigger updates … every 2-3 months" plus social features.
  - The page gives no number benchmarks.
- **Third-party benchmarks** ([RoLearn](https://rolearn.dev/guidance/first-week-retention-optimization/), method not public, treat as rough):
  - Simulators: D1 35% good, 50% excellent; D7 18% good, 28% excellent.
  - Obbies: D1 20%, D7 8%.
  - Claims that "social players" retain 4× better.
- **Events and passes:**
  - Grow a Garden's weekly drops and weather events drove a peak of 22.3M CCU, but the game "doesn't typically sustain its peaks" ([Wikipedia](https://en.wikipedia.org/wiki/Grow_a_Garden)).
  - Its Season Pass has 50 tiers, a free track and a 749-Robux premium track ([Beebom](https://beebom.com/grow-a-garden-season-pass-guide/), third-party).
  - Adopt Me's Winter 2025 event gave a free pet for 450 pet-care tasks ([wiki](https://adoptme.fandom.com/wiki/Winter_Event_(2025))).
- **Comeback:**
  - Roblox pays creators for bringing back users who have been inactive 60+ days, if they play 10+ minutes ([Creator Rewards announcement](https://devforum.roblox.com/t/introducing-creator-rewards-earn-more-by-growing-the-community/3777628)).
  - A gentle "welcome back" is in line with the platform's incentives.
- **Photo mode:** [CaptureService](https://create.roblox.com/docs/reference/engine/classes/CaptureService) supports screenshots and video, with share and save-to-gallery prompts that need the user's permission.

**Implications (kid-safe versions):**
- **Collection book (Horse Book):** coats, breeds, rosettes, courses and Cups, each with a silhouette until earned.
- **Events whose items come back next year** (already in GAME_DESIGN).
- **A free-only seasonal "Ribbon Trail"** in place of a paid pass. D-050 dropped the Derby Pass because "its season clock pressures kids", and a free track with no expiry warnings keeps that safe.
- **Welcome Back Hay Bale:** after 3+ days away, the horse runs to greet you and there's a gift of food and seeds. Its size is flat, so it never grows the longer you're away (no guilt).
- **Photo Finish camera:** a pose button after a win, using CaptureService's share prompt (no custom upload).
- **Off-limits:** login streaks that reset, "ends in 2h!" timers, paid Age-Up skips for the horse's growth.

## 5. UI for 8–12 on phones

- **[NN/g physical development](https://www.nngroup.com/articles/children-ux-physical-development/):**
  - Touch targets "at least 2cm × 2cm" for young children.
  - Dragging and scrolling are hard, so prefer tapping and big swipes.
- **[NN/g cognition](https://www.nngroup.com/articles/kids-cognition/):**
  - "Give kids clear and specific instructions by stating the goal … and how to achieve it."
  - Use real-world icons and obvious feedback.
  - Pair visuals with audio.
- **[Roblox onboarding techniques](https://create.roblox.com/docs/production/game-design/onboarding-techniques):**
  - Visual cues "communicate without words".
  - Contextual just-in-time tutorials.
  - Timed hints that appear only for players who are stuck.
  - End onboarding on a joyful moment.

**For Giddy-Up:**
- Every button gets an **icon plus one word**, and nothing smaller than about 2 cm on a phone.
- A **"Next thing" pill**: one glowing suggestion at a time ("Feed Comet 🥕"), driven by the Stable Board.
- **No drag-only controls.**
- The announcer reads key tips aloud.
- Show the first race within 2 minutes of joining.
- Let Pip (the lead pony) give timed hints after 20 s of being stuck.
- Write new copy at about a Grade 3 reading level.

## Ideas that would break the hard rules

| Idea | Rule | Instead |
| --- | --- | --- |
| Injury or lameness from over-racing | Rule 3, D-039 (David confirmed) | Happy-tired cue plus Spa Day bonus |
| Horses ageing until weaker, or dying | Rule 3, D-037 | Career badges and opt-in Legend Retirement |
| Claiming races | Forced sale, close to a stake | Condition races (First Win, Rising Star) |
| Player trading or auctions | D-037, scam and paid-item gating risk | NPC sell with a 24 h buy-back |
| Paid Age-Up or paid vet cures | Rule 2 spirit, pay-to-skip pressure | Free spa |
| Picking the winner as a spectator | Rule 1 | Cheering (D-019) only |
| Streak login calendar, "last chance" timers | Rule 3 | Pausing calendar, flat welcome-back gift |

## Ranked: 12 most promising ideas

| # | Idea | Expected impact | Risk |
| --- | --- | --- | --- |
| 1 | **Visible queue**: countdown ring, gate filling with names, "bots join at 0", groom while waiting | High on D1 (answers David's queue question; waiting is where kids quit) | Low |
| 2 | **"Next thing" pill + icon-and-word buttons ≥ 2 cm**, Grade 3 copy, audio tips | High on D1 and comprehension | Low |
| 3 | **Condition races** in each league (First Win → Rising Star → Open → Cup → Derby Day) | High on D7 (clear next goal; real-racing flavour) | Low–Med (splits fields; bots cover it) |
| 4 | **Horse Book collection** (coats, rosettes, Cups, courses) | High on D7 and D30 | Low |
| 5 | **Happy-tired + Spa Day** at the vet (bonus only, no injury) | Med–High (delivers David's vet ask safely; a care loop) | Med: must never read as hurt; child-safety review |
| 6 | **Career badges + opt-in Legend Retirement** to the Hall of Fame paddock, legacy boost to a foal | High on D30 (Umamusume's replay loop) | Med: needs breeding (D-047); cap the boost; never forced |
| 7 | **Stable Tour stamps + show-off trophy wall** for friend visits | Med on D30 (social retention ~4×, third-party) | Low with D-042 settings |
| 8 | **Welcome Back Hay Bale** (flat gift after 3+ days away) | Med on reactivation | Low |
| 9 | **Free-only Ribbon Trail season** (no expiry warnings; items return) | Med–High on D30 | Med: must stay free and unpressured (D-050) |
| 10 | **Stable Star prestige** goal cards (Rival Stars style) | Med for older kids | Low |
| 11 | **Photo Finish camera** with CaptureService share | Med (word of mouth) | Low; uses Roblox's own prompts |
| 12 | **NPC sell with goodbye card + 24 h buy-back** | Low–Med (frees stalls, answers "sold") | Med: kids regret sales; never player trading |

## Open uncertainties

- Star Stable's ageing and retirement rules couldn't be confirmed from a primary page. ZED Run's class rules come from a summary.
- The RoLearn benchmarks are third-party and unverified. Roblox's dashboard shows genre benchmarks only to the owner.
- Whether a "tired horse" theme affects the maturity questionnaire is unconfirmed. Check it when filling in the questionnaire.
