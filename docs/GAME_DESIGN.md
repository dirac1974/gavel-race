# Gavel Derby — game design

Condensed from the planning doc "Gavel Derby — Roblox Game & Economy Plan" (2026-10-03). Race math lives in [V2_PROPOSAL.md](V2_PROPOSAL.md); where the planning doc still shows v1 numbers (tiered Upset Bonus, 7% margin), v2 wins. Decisions are logged in [memory/DECISIONS.md](memory/DECISIONS.md).

## Positioning

Horse Life's care, collecting, and breeding depth, plus a real skill race that no current Roblox horse game has. Players come back for their horses and stay for the race. Research: [research/2026-10-04-baseline.md](research/2026-10-04-baseline.md).

## No-wager rule (D-001)

| Original idea | Roblox-safe version |
| --- | --- |
| Bet Green Cash on your horse | Enter free; horse spends Energy (restored by care). Purse paid by finish |
| Posted odds per player | Pre-race **Win Chance %** per horse |
| Longshot pays more | **Upset Bonus**: locked win purse `5 · round(B / 5q)` |
| Skill = delta in the odds | Unchanged: the gavel moves Win Chance live ("12% → 19%") |
| House edge | Replaced by league base purse `B` (the faucet dial) |
| Diamonds buy boosts to qualify | Diamonds buy cosmetics, time, space; Exhibition entry only (D-002a, proposed) |

UI words to use: race, entry, win chance, purse, prize, upset bonus. Never: bet, wager, odds, stake, payout, house, bookie.

## Core loop

Care for horses → train stats → enter a race (Energy) → time the gavel → win purses and League Points → spend on food, facilities, stalls, breeding → repeat. A race takes about 90 seconds. Breeding, pets, trail rides, and clubs hang off this loop.

## Race flow (8 lanes, 60–90 s)

1. Lobby shows conditions and each horse's base Win Chance and locked win purse.
2. Three gavel windows (break, backstretch, final stretch). Meter speed and zone width scale by league.
3. Live Win Chance updates after each window.
4. Server draws the finish order from final chances (Harville), then animates the race to match.
5. Bots fill empty lanes so a race starts within 20 seconds. Server-authoritative taps; flag inhuman tap patterns.
6. Quinella dropped. A free spectator "pick the winner" can award a cosmetic badge only.

## Horses, jockeys, conditions

**Race Rating** = `(Σ w_k(conditions) · stat_k) × CareMult + Jockey + Strategy`; base Win Chance `q = softmax(Rating / T)`.

| Stat (0–100, capped by breed Potential) | Effect | Trained by |
| --- | --- | --- |
| Speed | Top speed; weighs most in Mile and Classic | Sprint drills |
| Acceleration | The break and sprints | Starting-gate drills |
| Stamina | Holds pace over Classic and Marathon | Trail rides, pond |
| Grit | Mud, rain, comebacks | Hill runs, rain-day training |
| Focus | Slightly slows the gavel meter (capped small) | Calm grooming, paddock time |

Conditions: Distance (Sprint, Mile, Classic, Marathon), Surface (Dirt, Turf, Sand), Weather (Sunny, Rain/Mud, Wind, seasonal Snow or Aurora). Each combination sets stat weights.

Jockey = the player's avatar. Balance widens the green zone slightly; Tactics unlocks Front-runner / Stalker / Closer for a Strategy bonus; Bond with a horse adds a small Rating bonus; silks and boots are cosmetic. Jockey and Focus bonuses are capped so the gavel stays about timing.

Care multiplier: fed, groomed, rested horse gets up to +5% Rating. Neglect only loses the bonus. Horses never sicken, run away, or die.

## Activities (each feeds the race)

| Activity | Feeds | Cadence |
| --- | --- | --- |
| Feeding (pre-race meal buffs) | Care bonus, small buff, horse XP | Before races |
| Feed garden (grows offline) | Free food, surplus to sell | Check-ins |
| Grooming mini-game | Mood, Bond | Daily |
| Stable chores | Small cash, cleanliness bonus | Daily |
| Active training mini-games | Stat XP (fast), Energy cost | Any time |
| Passive training (facility timers) | Stat XP (slow), offline | Timer |
| Rest | Energy regen; better stalls regen faster | Continuous |
| Breeding | New racers, coat genes, rare mutations | Timer |
| Raising foals | Bond, attachment | Days |
| Stable pets | Small passive perks | Collected |
| Stable building | Capacity, regen, training options | Progression |
| Trail rides | Golden horseshoes, tame wild horses | Any time |
| Jockey drills | Jockey XP | Daily |
| Quests | Cash, food, cosmetic tokens | 3 daily, 1 weekly chain |
| Visiting stables | Social, small mutual bonus | Any time |
| Stable clubs | Team goals, club cosmetics | Weekly |

Pets sold for Diamonds are sold as specific pets, never random eggs. Trading is out at launch.

## Economy (D-002)

Green Cash: earned only, never sold, only currency won in races. Diamonds: Robux developer products, small amounts earnable. No direct conversion either way.

**Faucets (starting values, tune with telemetry):**

| Source | Amount |
| --- | --- |
| Race win | Locked purse `5 · round(B / 5q)`; expects `B` at average play |
| Race place | 2nd 1.2B, 3rd 0.8B, 4th 0.4B |
| Expected per entry | ≈ 1.13B (longshot) to 1.46B (favorite) at average play; skill lifts it |
| Daily quests | 3 per day, scaled to league |
| Login calendar | 7-day loop, day 7 big; missing a day pauses, never resets |
| Chores and selling | Surplus food, foals to NPC breeders |
| Offline stable income | Small, capped at 8 hours |

League base `B`: Rookie 20, Bronze 50, Silver 120, Gold 300, Champion 750.

**Sinks:** food (daily), training facilities (each tier ~2.5×), stable expansion (exponential per stall), breeding stud fees, NPC horse market (rotating stock), tack (small capped perks), Hall of Fame retirement (bloodline bonus for foals).

**Balance targets:** Bronze in ~3 hours of play, Silver in ~3 days, Gold in ~3 weeks. If median balance outgrows prices, raise prices of new tiers rather than cutting purses.

## Monetization

| Diamonds buy | Examples |
| --- | --- |
| Cosmetics | Coat dyes, glowing manes, trails, silks, tack skins, decor, name plates |
| Time | Finish training, breeding, or foal timers early |
| Space and comfort | Extra stalls, auto-feeder, quest reroll |
| Exhibition entry (proposed, D-002a) | One higher-league race for XP and a ribbon, no cash purse |
| Derby Pass | Free track for all; premium adds cosmetics and some Diamonds back |

Hard rules are in `CLAUDE.md`. Also: every price shows in Robux before confirming; a few one-time game passes (VIP stable look, extra pasture); Premium playtime payouts reward long free sessions.

## Progression

| League | To enter | B | Gavel | Unlocks |
| --- | --- | --- | --- | --- |
| Rookie | Starter horse | 20 | Slow meter, wide zone | Garden, grooming, first pet |
| Bronze | Win Rookie Stakes | 50 | Medium | Breeding, Tactics |
| Silver | Win Bronze Stakes | 120 | Faster, narrower | Pool, hill course, clubs |
| Gold | Win Silver Stakes | 300 | Fast, one moving zone | Rare NPC bloodlines, weather variants |
| Champion | Win Gold Stakes | 750 | Fastest, two zones on final window | Hall of Fame, seasonal trophies |

League Points: win 10, 2nd 6, 3rd 4, 4th 2, finish 1. 100 points unlocks the Stakes race; a Stakes win promotes. No demotion; no entering leagues below your own; matchmaking by Rating band keeps most Win Chances between ~4% and 35%; weekly Derby Day showcase race per league.

## Retention (fun version, not pressure version)

| Hook | Use | Avoid |
| --- | --- | --- |
| Offline growth | Foals, gardens, timers finish while away | Timers only payers can skip in reasonable time |
| Surprise and rarity | Rare coats, mutations, upset wins | Paid random boxes |
| Daily rewards | Calendar that pauses | Streaks that reset to zero |
| Limited events | Event items that return next year | One-time-only items |
| Near misses | Show how close the tap was, with a tip | Rigged near misses |
| Social goals | Club boards, Derby Day, visiting | Shaming leaderboards |

Live ops: weekly small drop and market rotation; monthly themed event (Harvest Festival, Snow Derby, Spooky Night Race, Spring Foal Fair); ~8-week Derby Pass season. Metrics: D1/D7/D30, races per daily player, average gavel score by league, cash created vs. destroyed per day, share reaching Bronze in session one, payer conversion (watched, never optimized against the others).

## Reskin architecture (D-007)

| Core (theme-free) | Horse | Car | Boat |
| --- | --- | --- | --- |
| Racer, 5 stats | Speed, Acceleration, Stamina, Grit, Focus | Top speed, Launch, Fuel, Grip, Handling | Speed, Planing, Endurance, Chop, Steering |
| Pilot | Jockey | Driver | Skipper |
| Upkeep | Feed, groom, rest | Wash, tune, refuel | Clean hull, rig check |
| Facilities | Gallop track, pool, hills | Dyno, test track, garage | Dock, wave pool |
| New racers | Breeding | Parts crafting | Hull building |
| Companions | Stable pets | Pit crew mascots | Seabirds, dock dogs |
| Gavel windows | Whip timing | Gear shift / boost | Throttle / wave timing |

ThemePack module holds names, labels, art, sounds, condition weights. Race engine is a pure server module, tested against the Python reference. All tuning in one config table. Each skin ships as its own experience sharing the engine package.

## Roadmap (each gate is a player test, not a date)

1. **Prototype the race**: Luau engine with the tilt, gavel meter with 3 windows, 8 lanes with bots, one track, server-scored taps, playtest with a few kids. *Gate: testers can say how their gavel play changed the result.*
2. **Vertical slice**: stable plot, starter horses, feeding, grooming, training, Energy, Rookie and Bronze leagues, cash faucets and sinks, daily quests, telemetry. *Gate: closed-test players return next day and reach Bronze.*
3. **Soft launch**: breeding and foals, garden, pets, Silver league, Tactics, Diamond store, login calendar, anti-exploit checks. *Gate: cash created vs. destroyed in band for two weeks; no open exploits.*
4. **Launch and live ops**: Gold and Champion, clubs, Derby Day, first event, Derby Pass, weekly drops. *Gate: retention holds through the first event.*
5. **First reskin**: extract the ThemePack, build cars or boats as its own experience, balance from config.

Other open items (see OPEN_QUESTIONS): gavel input per device (tap anywhere on mobile, one button on PC/console); maturity questionnaire answered as no gambling content, aiming for Minimal rating.
