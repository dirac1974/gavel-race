# Fun and return: gameplay proposal (2026-10-12)

Lens: the race loop and what makes a kid race again tomorrow. David's five directions are decided; this delivers them kid-safely. ★ marks the top 8 for this evening.

**The blunt summary:**
- The race is now good. What kids can't see is **progress**: League Points have no UI at all, and class badges are labels with no consequence.
- So the best-value work tonight is making progress visible, then giving it destinations: named races, life stages, the vet check.
- **The biggest design risk is ageing.**
  - Our ladder needs about **350 races on one horse** to reach Champion (casual, week 12, D-068).
  - A decline that starts at 100 races (the research's number) would bite in Silver and Gold, during the climb, and feel like punishment.
  - So decline starts late and is bounded (§2B).

## 1. Improvements to what exists

### ★1. League Points and class progress you can see (S)

**Why kids return:** every race must visibly move a bar. Today a 5th place gives +1 point that nobody ever sees.

**Results card:** one row under the stars, `+6 🏅 · Bronze Cup 46/200`. The bar fills with a tick per point.
- When the Cup opens: "🏆 Cup open!" (never "last chance").

**Horse card:** the same bar, plus the class step (§2A).

**Config:** `GameConfig.results.pointsRow = true`, `hud.pointsBar = true`.

**Files:**
- `ResultsText.luau` (`pointsLine`)
- `RaceController.client.luau` (card)
- `Hud.client.luau`, `HorsesClient.client.luau`
- `RaceService` (send `pointsBefore`/`after` in `RideReport`)

**Sims:** none.

### ★2. Recurring rivals (S–M)

**Why it's fun:** a name you beat yesterday is a reason to come back. "You beat Thunder again! 3–2" is a story.

**What it is:**
- Each league gets 3 named rival bots: fixed name, coat and silks (`GameConfig.rivals = { perLeague = 3, share = 0.5 }`).
- In half of your races, one of them takes a bot lane.
- **The rival's Rating is the league anchor ± 6, exactly as any bot today**, so the race math is unchanged and no sim is needed.

**Where it shows:**
- Results: "You beat Thunder!" / "Thunder won this time."
- The Horse Book "Rivals" page has a head-to-head per rival, private.
- Never a human. No public record.

**Files:**
- `RaceSession.fillWithBots` (rival pick from the race rng, drawn *after* existing draws)
- `NameGen`, `Profile` (`rivals` table)
- `ResultsText`, `HorseBook.luau`

### 3. Pointers that open things (S; with UX)

Advice and job GO buttons should **open** the panel or teleport to the Map tile, not just draw hoofprints (inventory headline).
- Gameplay priority: GO for Cup, picker, Practice-with-a-friend, Vet and Book.
- **Files:** `Guide.luau`, `StableBoard.client.luau`, `WorldClient` (Map tiles for Paddock, Training Ground, Market, Feed & Seed).

## 2. David's directions

### ★3. A. Classes and qualification: named prestige races (M–L)

**How it fits together:**
- **Leagues stay the Rating band.** That's matchmaking and fairness.
- **Cups stay promotion.**
- **Classes become entry rights inside a league.**
- The existing badges map onto real racing words:

| Class | Rule (wins in this league) | Today's badge |
| --- | --- | --- |
| Maiden | 0 | 🐣 First Win |
| Allowance | 1–2 | 🚀 Rising Star |
| Stakes | ≥ 3, or the Cup is open | 🎽 Open |
| Graded winner | Has won this league's named race | New title |

**Named races, one per league** (`GameConfig.graded`):

| League | Race | Grade | Entry: wins in league / races in league |
| --- | --- | --- | --- |
| Rookie | Buttercup Stakes | Listed | 1 / 8 |
| Bronze | Daisy Stakes | G3 | 2 / 15 |
| Silver | Silver Bell | G2 | 3 / 25 |
| Gold | Golden Horseshoe | G1 | 3 / 30 |
| Champion | Giddy-Up Derby | G1 | 3 / 30 |

**Schedule (always back, never urgent):**
- `graded.everyMinutes = 20`, at :00, :20 and :40 server time.
- The line opens 3 minutes before.
- The card says "Every 20 minutes". There is no ticking countdown. Missing one costs nothing.

**Field and maths:**
- The league queue key is `"graded"` (`RaceQueues`). Bots fill at 15 s, as today.
- **Same q, T and bot anchors**, so no race-math change.

**Rewards:**
- Purse 2B (between a race's B and the Cup's 3B).
- +15 League Points for a win.
- The horse's title, e.g. "Daisy Stakes winner".
- A plaque on the Rosette Wall and a Horse Book page.
- Every 3rd place or better earns a Graded rosette.
- No demotion, no claiming, no public ranking.

**Files:**
- `GameConfig`
- `Leagues.luau` (`classOf`, `gradedEligible`)
- `RaceQueues.luau`, `RaceService` (card kind `graded`, purse)
- `RacePicker`, `QueueCard`, `PickerText`, `ResultsText`
- `Career.luau` (titles), `HorseBook.luau`, `StableService` (plaques)

**Sims:** `sims/economy.py --ladder phase3 --graded`.
- Graded purses and points must not shorten casual Cup times by more than 10%.
- Cash per race within +5%.

### ★4. B. Life stages and ageing, counted in races (M)

**Stages** (`GameConfig.age`), counted on `h.record.races` (every race ridden, Practice included; nothing counts while you're away):

| Stage | Races | Effect | How it shows |
| --- | --- | --- | --- |
| Youngster | 0–24 | none | "🌱 Youngster", model at 0.94 scale growing to 1.0 (no asset) |
| Prime | 25–249 | none | "⭐ Prime" |
| Veteran | 250+ | **Rating −1 per 50 races, at most −4** (`declineFrom 250`, `declineEvery 50`, `declinePer 1`, `declineMax 4`) | "🎖️ Veteran" |
| Legend | retire | races no more (unretire stays) | existing paddock and plaque |

**Why these numbers:**
- A casual kid reaches Champion at about 350 races, which is only −2 at that point.
- −4 is reached at 450 races. That is about ×0.80 base chance at T 18 and ×0.72 at T 12.
- It's a slow slope that gives a reason to raise the next horse, never a cliff.
- The kid's tap edge is untouched.

**Warnings:**
- 10 races before each step, the card says "Comet is getting wise. Soon a little slower."
- A life bar on the horse card shows the whole path from the first race.

**Rules:**
- Age never touches Practice (equal horses), Cup-opening `bestRating` (ceiling checks ignore age), or Diamonds.
- No time-based ageing, ever.

**Where the maths goes:**
- `Rating = (Σ w·stat) × CareMult + Jockey + Strategy + Age`.
- Files: `src/race_rating.py` and `RaceRating.luau` (parity fixtures), `Horse.luau`, `HorsesClient`, `Hud`.

**Sim gates (`sims/economy.py --ladder phase3 --age`):**
- Casual Champion arrival ≤ week 13 (12.0 today).
- Average kid's entry win rate per league within −2 points.
- No profile's Cup times grow by more than 10%.

**End of career** (all exist except the loan):
- **Legend** (reversible).
- **"Sell to Sunny Meadow":** Rehome renamed, so David's "sold" is visible. Half the price, 72 h undo.
- **New: "Lend to the Riding School"** (free, take back any time; `rehome.lend = true`, S).
- **Breeding** comes later (§3).
- Still no player trading.

### ★5. C. Over-running → vet check (M)

**Trigger:** a **run** of cash races by one horse (`GameConfig.vetCheck`).
- `runLimit = 6` races.
- The run resets on any care action, a Spa, a training ride, a vet visit, or `restMinutes = 30` without racing that horse.
- Rookie counts, since Rookie races are free.

**Warning:** at race 5, the horse card shows "Comet's legs are working hard." When race 6 is done, the horse is at "🩺 Vet check".

**Effect:**
- Cash races wait: RACE! becomes 🎈 PRACTICE, as it does when the horse is napping.
- Practice, riding, care and visits stay open.
- **No Rating change.**

**Why no Rating change:**
- The stop *is* the consequence, and it's visible and avoidable.
- A hidden Rating penalty would punish twice, and it would need a stat a kid can't see.
- It would also turn a care lesson into a loss of win chance, which is exactly the "neglect hurts your horse" feeling hard rule 3 forbids.

**The vet visit** (free, about 30 s, a positive moment):
- Cold hose, leg wraps, a carrot. Tap-only, reusing the Check-up heartbeat flow.
- **Result:** +1 bond, a Passport stamp "Fresh legs!", and a sparkle on the next race (cosmetic).
- The GO on the pill teleports to the Vet.
- No Diamonds, no cash.
- Copy never uses hurt, injury, sick or limp (copy test).

**Files:**
- `Care.luau` (run counter)
- `Leagues.canEnter`, `RaceService`
- `CareService`, `CareClient` (leg check)
- `Advice` (pill), `HorsesClient`, `Words`

**Sims:** `economy.py` cadence check.
- Casual profile triggers ≤ 1 per 3 sessions.
- Engaged ≤ 1 per session.
- Races per session drop ≤ 5%.

### ★6. D. Queue clarity (S)

**Name every line on the queue card:**
- "🥉 Bronze line: horses like Comet"
- "🏆 Cup line: Cup horses only"
- "🎖️ Daisy Stakes: Stakes horses"
- "🎈 Open Practice: anyone, equal horses"

**A one-time 3-picture strip:** Join → the gate fills → bots fill at 0.

**Party follow:** a Roblox Party joining 🎈 Practice lands on one course (`SocialService:GetPlayersByPartyId`, no popup).

**Files:** `QueueCard`, `QueueView`, `RacePicker`, `RaceQueues`.

**Sims:** none.

### E. Visiting everyone (M; owned by UX and child safety)

Agree with the research's design:
- Friends by default, with an opt-in "Everyone here".
- Strangers can pat and send 4 preset cheers. No treats, no post box.
- The owner's gate walks everyone out.

**Gameplay add:** a 🎈 "Practice together" button on a visitor's card, which uses Open Practice's equal horses.

## 3. Other features

- **★7. Weekly Derby Day (M):** every Saturday (server clock), the graded race of each league runs every 10 minutes instead of 20, and the Big Board names the day's winners. It always comes back, with no "limited" copy and no exclusive items. Uses `graded.festivalDay = 6` and `festivalEveryMinutes = 10`. No sims beyond §2A.
- **★8. "Find it" for race features (S, with UX):** first-time 👇 highlights for the picker, Practice-with-a-friend, the Cup, named races and the vet check, fired through `Advice` when each is first relevant.
- **Breeding with Legend Sparks (D-047, L, not tonight):**
  - Foal Potential = 0.7 × parents + 0.3 × breed ± 5.
  - A retired Legend passes one capped Spark (+2 to one stat's Potential).
  - Free, never paid, never random-for-Robux.
  - Needs `sims/bloodline.py` first: Potential drift per generation ≤ +3, and the Champion reach of a 2nd-generation horse must not halve.
- **Returning seasonal events (M, later):** a themed course plus a free coat, back every year. Gated behind the playtest.

## 4. Where the in-flight work goes

1. **D-072 phase A** (calibration) merges first.
2. **D-072 phase B, the stored move:** next build after phase A's green gates. It's the biggest moment-to-moment win left in the race.
3. **D-073 Hurdles, Practice-only:** after phase B. It feeds the named-race calendar later (a Hurdles G3 in Silver).
4. Tonight's list touches no race maths except the ageing Rating term (parity) and none of Trip, so it doesn't collide with D-072.

## Tonight's top 8 (in build order)

1. League Points and class bar.
2. Queue clarity.
3. Vet check.
4. Life stages, with the decline behind `age.enabled` and turned on only when the sims pass.
5. Named prestige races.
6. Recurring rivals.
7. Find-it for race features.
8. Derby Day.

**Risks:**
- **Ageing** is the risky one: build the display tonight and turn the decline on only on green sims.
- **Graded races** need the economy sim before their purses go live. Ship them at purse B, then raise to 2B on green.
