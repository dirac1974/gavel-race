# Giddy-Up — the world (stables, care, racing life, friends)

Status: Accepted (provisional), D-035 to D-047. Written 2026-10-04 by the design council from a world workshop (openings, a critique round, two research briefs). David asked for stables, care, food, the vet, things to do between races, multiplayer, spectators, race sign-up, getting new horses, and a task board "like the NYC haunt game". The team then built it in stages under David's go-ahead to "let the team decide the direction".

Hard rules still apply: no wagering, Diamonds never touch win chance, horses never sicken, die or run away, no streak resets, no fake urgency, no purchase prompts during or right after a race.

## 1. One server, one small world (D-035)

- **Server size:** 20 players. Competitors use 16–30: Horse Valley 16, Wild Horse Islands 20, Horse Life 30.
- **Layout:** everything sits within about a 20-second ride of the grandstand, on the grandstand side of the racecourse:
  - **The racecourse:** Churchill-style, already built. Everyone gathers at the homestretch rail and in the grandstand.
  - **Fair Street:** a plaza behind the grandstand. It holds the **Race Board**, **Feed & Seed** (the store), the **Vet** (a wellness clinic), the **Training Paddock**, the **Market Corral** (new horses) and the **Trail Gate**. Every building has a big picture sign.
  - **Barn Row:** 20 stable plots, one per player, assigned when you join and filled from your save. Everyone sees the outside; only the owner changes the inside.
  - **The Trail:** a loop through woods and a meadow with wild horses, picnic and photo spots, and finds (wild apples, herbs, lucky horseshoes).
- **Getting around:** ride your own horse everywhere (walk, trot, gallop button). A **Map** button with five pictures (Stable, Track, Fair Street, Vet, Trail) fast-travels you there. Glowing **hoofprints** lead to whatever the Stable Board's GO button points at.
- Spawn: your own barn. First-time players spawn at the Fair Street plaza for the starter pick.

## 2. Racing in a shared world (D-036)

- **Two courses:** the dirt oval and the turf course inside it each run their own race. Two races can run at once, and spectators see both.
- **Race Board:**
  - Each league has a card showing its league badge, a distance icon, a surface icon, the win purse and eight lane dots (filled = taken).
  - A league's race posts within 30 s of its first rider joining. Bots fill the empty lanes after 20 s (D-011).
  - The races fill the two courses in turn. Your card says "Your race: next" or "2nd in line", with horse faces showing the queue.
- **Sign-up:**
  - The **Race** button works from anywhere and opens the same cards as the board.
  - Pick a card, then pick a horse from cards showing its face, five Energy hoofprints and "Suits today: +4". Today's fit is shown as Rating, never as win chance, because chance depends on the field.
  - A tired horse naps on its card ("Resting"), with no countdown and no buy button.
  - Rookie races are free; cash races cost 1 Energy (D-015).
  - At post time you're carried to your gate, mounted on your horse.
- **Waiting:** you wait at the rail or in the grandstand, watching the race on the other course and cheering (D-019). You're never stuck in a lobby screen.
- **Fair fields:**
  - Cash fields never mix leagues.
  - Within a league, match by Rating within ±12, widening to ±20 after 10 s.
  - Friends and party members never share a cash race (extends D-006); **Friend Races** are practice races for them.
  - Each lane's score counts as at least 25 in the race average, so tanking alts can't drag the average down.
- **Cross-server:** only Stakes and Derby Day, later, as opt-in trips.

## 3. Owning horses (D-037)

- **Starter:** pick one of three Rookie horses (different coats, equal stats) and name it by tapping suggested names. Typed names come later, through Roblox's text filter.
- **Stable:**
  - Your barn starts with 2 stalls; Green Cash buys more, up to 6.
  - A free **pasture** holds extra horses for collecting; they can't race until stalled.
  - One horse is your **active** horse: it follows you, you ride it, and it's preselected on race cards.
- **Horse record:** name, coat, running style, stats (Speed, Acceleration, Stamina, Grit), hidden Potential per stat, Energy, today's care, bond, league, League Points, wins, places and races.
- **Getting more horses:**
  - **Market Corral:** Green Cash, a weekly restock, rarer bloodlines from Gold. Rare stock comes back; never "only 2 left".
  - **Taming:** wild horses on the Trail, a gentle rhythm approach with treats. Natural rare coats live here.
  - **Event horses:** their coats return the next year.
  - **Breeding:** from Bronze, later (D-047).
  - **Never sold:** horses can't be bought for Robux or Diamonds, and there's no trading (D-002).
- **Careers:** horses don't age or decline. Retiring is the player's choice and gives a **Hall of Fame** plaque with the career record.

## 4. Care and food (D-038)

- **Feed and groom:**
  - Feeding (a hay or grain scoop) and grooming (swipe the brush) each fill half of today's **care**.
  - Full care gives the +5% Rating bonus (D-014) until the day rolls over, then it returns to baseline. Care never drops below baseline, and nothing is lost by skipping a day.
  - Each also gives +1 Energy, once every 2 hours (D-015).
- **Pet and treats:** these add **bond**, which gives a small Rating bonus (D-014) and unlocks tricks: nuzzle, follow, whinny hello.
- **Food sources:**
  - **Garden beds** at your barn grow while you're away: carrots 1 h, apples 4 h, oats 8 h. Crops never wither and wait until harvested.
  - **Feed & Seed** sells hay, grain, seeds and treats for Green Cash. It is the main daily sink.
  - **Chores** (muck out, fill water) pay hay and a little cash.
  - **Trail finds.**
- **No dead ends:** a new player gets starter hay. Even with no food and no cash, chores always give hay, and the horse never suffers either way.
- **Rest:** a horse that has rested since its last session trains 50% faster, inside the weekly cap (debate 008).

## 5. The vet is a wellness clinic (D-039)

Nothing makes a horse ill, so there's nothing to cure and nothing to buy. Hard rule 3 rules out David's "if the horse is sick, take them to the vet". The fun part survives:

- **Check-ups:** free, any time. A stethoscope game (tap on the heartbeat) gives +1 bond, at most once a day.
- **Health Passport:** collectible stamps (check-up, teeth, farrier, vaccinations, foal exam). It's a sticker book; skipping it costs nothing. One stamp reveals a horse's Potential.
- **Cool-down:** a walk and hose-down after a race, for shine and bond. Leg wraps are cosmetic tack only.

## 6. Training (D-040)

- **Mini-games:** one per stat at the Training Paddock: Sprint Lane (Speed), Gate Break (Acceleration), Hill Climb (Stamina), Mud Splash (Grit).
- **Gains:** each session gains in proportion to (Potential − stat), so training a stat gets slower as it approaches its Potential.
- **Weekly cap:** reachable in about 3 sessions per horse. Rested horses get +50% gain within the same cap.
- **The rule kids can read:** "Training moves you up leagues; riding wins races." Purses are B/q, so a stronger horse earns through place prizes and faster League Points, not bigger wins.

## 7. Spectators (D-041)

Build D-019 and D-020 as designed:

- **Cheer cards:** anyone near the rail or in the grandstand gets a card with the eight lanes for each race on either course. Pick one before the first checkpoint.
- **Clap Along:** after cheering, a two-hands button lets you clap on that horse's hoofbeats.
- **Fan XP:** cosmetic only. It is capped per race and per day, never scaled by win chance, and riders can't cheer in their own race.
- **Watching from afar:** the infield Big Board shows the race.

## 8. Friends and safety (D-042)

- **Chat:** Roblox chat only (TextChatService). Players who can't chat get preset emotes. Every player-typed name is filtered.
- **Stable visits:**
  - The owner sets visits to Friends (default), Club or Nobody; there's no "Everyone".
  - Strangers see a closed gate. They can drop a carrot in the post box, and the owner sees a count without names, plus the names of friends who left one. The count is never public.
  - Visitors can look, pet and give the one daily treat. They never take, move or buy anything.
  - Non-friends can't "join" a player.
- **Gifts:** one free treat a day per friend, from a fixed list, giving bond only. No cash transfers, no "send me" requests.
- **Friend Races and trail rides** run in parties (D-006). There are no individual bottom-of-board rankings.

## 9. Stable Board: daily, weekly and monthly jobs (D-043)

There's a noticeboard in your barn, and the same board behind a **clipboard** button on the HUD. It has no bell and no red badge.

- **Top row, one face per horse:**
  - a flag: "Comet is rested and ready to race" [GO]
  - zzz: "Maple is napping"
  - a carrot: "Carrots are ready to pick"
  - a star: "Comet's training is ready" (when rested and under the cap)
- **Next step per horse:** the biggest weighted gain, for example "Train Stamina next: 62 of 85, and Miles use it most" [GO], or "Trained enough this week".
- **Jobs:**
  - 3 daily jobs that one 10-minute session can finish (Practice counts), then a sleeping horse: "All done today!"
  - 5 weekly and about 5 monthly jobs, shown as one progress ribbon each.
  - Jobs mix care, riding effort, exploring and cheering. They are never "win" jobs, never ask for spending, inviting friends or hours played, and never pay League Points or Energy.
- **Rewards:**
  - Seeds, hay, small Green Cash (capped near 10% of a day's expected race income) and stamps toward the month's cosmetic.
  - Rewards auto-claim at rollover. One free reroll a day.
  - The day calendar counts days played and pauses; there are no streaks and no countdowns.
- **Wording states facts about the horse, never feelings about your absence.** "Comet misses you" and "Comet is hungry" are out. After a break: "Welcome back! Comet's been napping in the sun."
- **Pinned job:** one job pinned on the HUD with GO, hidden during races. No push notifications at launch.

## 10. Money guardrails (D-044, amends D-002a)

- **Time skips:** Diamonds skip decor builds only. Skipping garden, training, Energy or foal timers would leak into food, stats, races or random rolls.
- **What Diamonds buy:** cosmetics, decor, stall and stable skins, tack looks, the Derby Pass and job rerolls beyond the free one.
- **Never sold:** horses, stats, Green Cash or paid random items.
- **Not built yet:** the Diamond store waits for David's sign-off on D-002a.

## 11. For grown-ups (D-045)

A **For grown-ups** button explains how races work (no gambling, nothing buys speed) and what Diamonds buy. It shows the visit setting and this week's play time, and points to Roblox parental controls. It has an optional break reminder and collects no personal data.

## 12. Leagues and careers (D-046)

- **Stakes:** League Points unlock the Stakes race (D-013). A Stakes win promotes the horse.
- **Over-strong horses:** once a horse's Rating passes its league's ceiling, its Stakes race opens at once and that league's regular cash races close to it (Practice stays open).
- **Distances:** Rookie runs Sprint and Mile, Bronze adds Classic, Silver adds Marathon.

## 13. Breeding (D-047, later stage)

- **From Bronze:** fees are Green Cash only, with no Diamond boosts.
- **Foal Potential:** 0.7 × the parents' average + 0.3 × the breed average, ±5, capped at 100. Foals start at 35% of their Potential, so every champion is trained.
- **Coats:** coat genes are separate from stats.
- **Check before building:** a breeding sim must show bloodlines don't climb without limit.

## Build stages

Each stage is planned, built, tested, reviewed, recorded, merged, and played in Studio before the next.

| Stage | What | Key pieces |
| --- | --- | --- |
| 1. Your horse | Saving and owning | Profile + DataStore with session lock, horse records, wallet and items, starter pick and naming, races use your horse and pay into your save, HUD (cash, horse, Energy) |
| 2. The world | Places to go | Fair Street, Barn Row plots, your barn with stalls and your horses, Map fast-travel, hoofprints, riding your horse around |
| 3. Care and food | Daily care | Feed, groom, pet, garden, Feed & Seed, chores, care bonus and bond in Rating, Energy top-ups |
| 4. Race Board | Signing up | League cards, horse picker, queue, two courses at once, Friend Races |
| 5. Stable Board | Jobs and tips | Horse status row, next step, 3/5/5 jobs, auto-claim, GO hoofprints |
| 6. Training and vet | Getting better | Four training games, Potential, weekly cap, rested bonus, vet check-up game, Health Passport |
| 7. Spectators | Watching together | Cheer cards, Clap Along, Fan XP, Top Fans |
| 8. More horses | Collecting | Market Corral, Trail, taming, pasture, buying stalls |
| 9. Leagues | Climbing | League Points, Stakes, promotion, Bronze and up, Hall of Fame |
| 10. Polish | First impressions | First 10 minutes, For grown-ups, sound, art pass, mobile pass, performance |

Art runs alongside: Meshy models for the barn, stalls, Fair Street buildings, crops, props and more horse coats, within the 75% credit budget David set.
