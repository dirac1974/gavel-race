# Giddy-Up — game design (condensed)

**Giddy-Up: Tap it. Shout it. Win it.** Kids shout "Giddy-up!" as they tap to urge their horse on (D-029). Condensed from the planning doc of 2026-10-04 so agents have it in the repo. Race math lives in [V2_PROPOSAL.md](V2_PROPOSAL.md); decisions in [memory/DECISIONS.md](memory/DECISIONS.md).

## Pitch

Horse Life's care, collecting, and breeding depth plus a real skill race that no Roblox horse game has. Players come back for their horses and stay for the race. Audience: Roblox players 8–13, mostly on phones and tablets.

## Core loop

Care and feed → Train → **Race (gavel moves win chance)** → Earn Green Cash → Upgrade (stalls, tracks, food, tack) → back to Care. Bond with each horse grows every race.

## Race

- A Churchill Downs-style course (D-027): one-mile dirt oval, turf inside, grandstand and Twin Spires. Eight lanes; bots fill empty lanes within 20 seconds.
- Racing players ride their own horse (D-024) in a close chase view (zoom in for first person, D-028); bot horses carry Roblox-style jockeys in lane colours.
- Race length follows the distance: Sprint ~69 s, Mile ~94 s, Classic (the Derby) ~2 min, Marathon ~2:21. Rookie runs Sprint and Mile.
- The pace slider runs the whole race (D-026): tap as the marker crosses the glowing target, one tap per pass. The target moves every 2–3 passes; the speed meter fills from your last few passes.
- Coming off the final turn: the **Final Burst**, one tap on a big rainbow meter, worth double (40% of the rider's score); then the stretch drive on the slider to the line (D-031).
- During the race: your place ("3rd of 8") on screen and over your horse, the side board in running order, and a race map with a race strip and a small oval (D-030, D-032).
- Lobby shows each horse's Win Chance % and locked win purse. Live Win Chance updates three times during the race and after the burst.
- The horses cross the line in the drawn finish order; prizes: winner gets the locked purse; 2nd 1.2B, 3rd 0.8B, 4th 0.4B. League Points: win 10, 2nd 6, 3rd 4, 4th 2, finish 1.
- **Steering** (D-054). Posts are drawn at the gate, and every horse can change lanes from the gate to the far-turn entry.
  - **For kids:** two big buttons, ◀ In and Out ▶ (or A/D and the arrows, or the D-pad), move your horse one lane at a time. The rail is shorter on the turns, and sitting just behind a horse in your lane ("Tucked in!") helps a little. Smart Steer does it for you until you press, and it never takes you outward. Three soft bell ticks, then "Lanes locked!" at the far turn; from there it's the slider and the Final Burst. The buttons appear from your 4th race, with a one-time tip. Chips say what worked ("Saved ground!", "Tucked in!"), and a gentle tip shows if you're wide going into a turn.
  - **After the race:** "Good trip ★★☆" sits under "You rode ★★☆", and "Your trip gained you N places!" shows only when it did. The replay draws your line on the track up to the lock: a gold ribbon, green with chevrons through the turns where you saved ground, wind lines while you were tucked in, and a bar where lanes lock.
  - **For grown-ups:** the best trip is worth about 2 points of a 100-point ride (a typical tap edge is about 7 times bigger), and nothing buys it. There's no penalty for getting boxed in, and the trip never sees luck: it's fixed at the far turn. Each post's built-in advantage is removed by a per-post baseline. In a rider's first 3 races, before the buttons, the trip counts as zero. `GameConfig.steering.scale = 0` makes steering cosmetic; `enabled = false` brings back fixed lanes.

## Spectating (D-019)

Spectators cheer for one rider before the first gavel window, for free. They earn Fan XP from that rider's taps (Perfect 3, Great 2, Good 1) plus a flat 2 if the rider wins, up to 11 per race and 100 per day. Fan XP unlocks cosmetics only and stays much smaller than racing rewards. No picks of finishing order, nothing scaled by win chance, and riders can't cheer in their own race.

Optional **Clap Along** (D-020): fans clap on their horse's hoofbeats. The best fan counts in full and the next two add a small assist, so one great fan or a few good friends can max it and a big crowd adds nothing more. A Top Fans board after each race, separate from the results, shows the top 5 fans and your own rank. Fans flagged for automated clapping don't count; a 2nd flag brings a private warning and a 3rd turns off fan play for 30 days. A full crowd adds a tiny lift to the horse's win chance (12.5% → 12.8%), cash races included. Never buyable.

## Horses

Stats 0–100 with a breed Potential cap: **Speed, Acceleration, Stamina, Grit, Focus** (Focus slightly slows the gavel meter, capped small).

Race conditions shown in the lobby: Distance (Sprint, Mile, Classic, Marathon), Surface (Dirt, Turf, Sand), Weather (Sunny, Rain/Mud, Wind, seasonal events). Each sets stat weights.

`Rating = (Σ w_k(cond) · stat_k) × CareMult + Jockey + Strategy`; `q = softmax(Rating / T)`.

Care multiplier: up to +5% Rating when fed, groomed, rested. Neglect only removes the bonus. Horses never get sick, run away, or die.

## Jockey (the player's avatar)

- Balance: slightly wider green zone. Tactics: Front-runner, Stalker, Closer strategies that suit conditions. Bond: small bonus with a specific horse.
- Silks, helmets, boots are cosmetic. Jockey and Focus bonuses are capped so timing dominates.

## Side activities (each feeds the race)

Feeding and pre-race meals · feed garden that grows offline · grooming mini-game · stable chores · active training mini-games · passive training timers · rest and Energy · breeding and raising foals · stable pets with small perks · stable building and decorating · trail rides and taming wild horses · jockey drills · daily and weekly quests · visiting stables · stable clubs. No trading at launch.

## Economy

**Green Cash** (earned only): race purses and place prizes, quests, login calendar (pauses if missed, never resets), chores and selling surplus, small offline stable income capped at 8 hours. Sinks: food, training facilities, stable expansion, breeding fees, NPC horse market, tack, Hall of Fame retirement.

**Diamonds** (Robux, small amounts earnable): cosmetics, time skips, stall and stable skins, quest rerolls, Exhibition entry to a higher league (XP and ribbon, no cash), Derby Pass premium track. Never win chance, Rating, gavel, or cash-league qualification. No Green Cash for sale, no cash multipliers, no paid random items at launch, no purchase prompts during or right after a race.

League base purse B: Rookie 20, Bronze 50, Silver 120, Gold 300, Champion 750. Pace targets: Bronze ~3 hours, Silver ~3 days, Gold ~3 weeks; non-payers can reach Champion.

## Energy (D-015)

5 Energy per horse; a cash race costs 1; +1 every 20 minutes (offline too); feeding and grooming each add 1 once every 2 hours. Rookie races are free. Tired horses can't enter cash races but Practice races and other activities stay open. Energy never changes win chance, and Diamonds never refill it.

## Progression

Per-horse leagues: Rookie → Bronze → Silver → Gold → Champion. League Points unlock the league's Stakes race (D-013); a Stakes win promotes. No demotion; no entering leagues below the horse's own. Matchmaking by Rating band. Weekly Derby Day showcase per league.

Scoring is the same in every league; the gavel gets harder through meter speed and target behavior (D-010).

| League | B | Points to unlock Stakes | Gavel meter (full sweep) | Unlocks |
| --- | --- | --- | --- | --- |
| Rookie | 20 | 100 | 2.4 s, 4 s windows | Garden, grooming, first pet |
| Bronze | 50 | 110 | 2.0 s | Breeding, Tactics |
| Silver | 120 | 1,400 | 1.6 s | Pool, hill course, clubs |
| Gold | 300 | 3,000 | 1.3 s, drifting target | Rare NPC bloodlines, weather variants |
| Champion | 750 | top league | 1.1 s, drifting target, two half-size targets in the final window | Hall of Fame, seasonal trophies |

Values live in `game/src/shared/GameConfig.luau`.

## Retention (fun version of each hook)

Offline growth · rare coats and mutations · 7-day calendar that pauses · events whose items return next year · near-miss feedback with tips, never rigged · club boards and Derby Day. A good 10-minute session: garden, feed and groom, three races, start a training timer.

Live ops: weekly small drops and rotating market; monthly themed events; ~8-week Derby Pass seasons.

## Reskin

Theme-agnostic engine (Racer, Pilot, Upkeep, Facility, Companions, Conditions, gavel windows). A ThemePack holds names, stat labels, art, sounds, and condition weights. Car and boat skins later as separate experiences on the shared engine. Flower contest deferred.

## Roadmap (gated phases)

1. Prototype the race (Luau engine, gavel, bots, one track). Gate: testers can say how their taps changed the result.
2. Vertical slice (stable, care, training, Rookie and Bronze, economy, telemetry). Gate: next-day return and Bronze reached.
3. Soft launch (breeding, garden, pets, Silver, Diamond store, anti-exploit). Gate: cash created vs. destroyed in band for two weeks.
4. Launch and live ops (Gold, Champion, clubs, Derby Day, events, pass).
5. First reskin.
