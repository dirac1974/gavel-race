# Review queue for David

Provisional decisions made by the team under D-009, newest last. For each: keep, change, or reverse. Reversing is cheap because each one sits behind config or a single module.

| Decision | Summary | How to reverse |
| --- | --- | --- |
| D-002a | Diamonds buy cosmetics, time, space, and Exhibition entries only; never win chance or cash-league qualification | Change the Diamond catalog config and D-002a |
| D-010 | Gavel meter: speed per league, drifting target in Gold+, two half-width targets in Champion final window, feedback labels, per-player latency allowance capped at 0.3 s (D-021) | Edit `GameConfig.leagues` and `GameConfig.scoreLabels` |
| D-011 | Prototype rules: missed tap = 0, disconnect = window average once, bots ±6 rating, scores N(40,15) per stretch and N(55,15) for the burst (D-022), bots unpaid | Edit `GameConfig` (missedTapScore, bot*) |
| D-013 | Stakes thresholds 100 / 110 / 1,400 / 3,000 League Points to hit the Bronze 3 h, Silver 3 days, Gold 3 weeks targets | Edit `GameConfig.stakesUnlockPoints` |
| D-014 | Race Rating formula: condition-weighted stats, +5% care, +3 pilot, +2 strategy, +2 bond; Focus excluded | Edit the weight tables and bonus constants in `race_rating.py` and `RaceRating.luau` together (parity tests enforce it) |
| D-015 | Energy: 5 per horse, 1 per cash race, +1 per 20 min, care top-ups, Rookie free, Practice races when tired | Edit `GameConfig.energy` |
| D-016 | Flat 2nd–4th prizes, ribbons in UI, no exacta prizes | Edit `GameConfig.placePrizes`, `GameConfig.ribbons` |
| D-002a (amended) | Diamonds can't buy stalls, auto-feeder, or Energy refills | Edit D-002a and the Diamond catalog |
| D-032 | Race strip (lane rows, zoomed to the field, finish flag, gap in lengths) plus a small still oval with only your dot; designers suggest hiding the running-order board during the race | Revert `Minimap.client.luau` to the oval with all dots |
| D-022 | Stride stretches replace single taps (tap on the horse's stride, ~8 beats per stretch, drifting tempo); detection on tap-gap vs beat-gap spread < 12 ms over 300+ beats, 5+ races, 2+ days; rider ladder: logged, private note + taps count as race average, human review then cash races paused 7/30 days; Final Burst tap after the last stretch counts double (40% of S); no whip; named Giddy-up | Revert to D-010 windows in `RaceSession`; thresholds in `GameConfig` once built |
| D-023 | Playtest art "County Fair Toy": chunky natural horses with no-pony guardrails, dark hooves, fixed gallop pose bobbing on the beat, fixed lane colours, own-screen burst celebration, natural rare coats later | Re-prompt `tools/meshy/queue.json` and regenerate (credits) |
| D-020 | Clap Along crowd boost: crowd = best fan + 0.15 and 0.10 assists from fans 2 and 3 (capped), Top Fans board after each race, strikes for flagged fans (1st quiet, 2nd private warning, 3rd fan play off 30 days, strikes expire after 90 days), boost up to 0.03 in the tilt exponent (+0.3 points on a 12.5% horse), cash races included, cheat flags on timing spread | Set the crowd boost cap to 0 in `GameConfig` once built |
| D-019 | Spectator cheering: free, cheer one rider before window 1, Fan XP from their taps (3/2/1/0) plus flat 2 for a win, max 11 per race and 100 per day, cosmetics only, ≤ 20% of a rider's progress per race | Edit `GameConfig.spectator` once built; remove the spectator UI |
| D-033 | Exponential race (secret luck at the gate, same Harville odds); luck blends in from the far turn with `x²` while taps still count; instant 2 ft nudge on good taps; up/down chance arrow; "You rode ★★☆" and places gained on the results card; energy stays out of speed, rest speeds training | Set `GameConfig.raceShape.blendPower` (higher = later reveal) or `leaderFeet`/`feetPerLog`; for a hands-off reveal move the blend end to the line |
| D-034 | Replays: final quarter at 1x or whole race at 3x, offered never autoplayed; recorded frames only; slow motion only on wins; photo-finish still; riders stay seated until Done (60 s timeout) | Hide the two buttons in `RaceController`; `GameConfig.dismountTimeoutSeconds` |
| D-035 | One server, one small world: 20-player servers | See docs/WORLD_DESIGN.md; values in `GameConfig` once built |
| D-036 | Racing in a shared world: Two courses (dirt and turf) run a race each, so two run at once | See docs/WORLD_DESIGN.md; values in `GameConfig` once built |
| D-037 | Owning horses: Pick 1 of 3 starters (coats differ, stats equal), name by tapping suggestions | See docs/WORLD_DESIGN.md; values in `GameConfig` once built |
| D-038 | Care and food: Feeding and grooming each fill half of today's care (full care = +5% Rating until rollover, then back to baseline, never below) | See docs/WORLD_DESIGN.md; values in `GameConfig` once built |
| D-039 | The vet is a wellness clinic: Free check-ups with a heartbeat tapping game (+1 bond a day), Health Passport stamps (one reveals Potential), cool-down hose after races | See docs/WORLD_DESIGN.md; values in `GameConfig` once built |
| D-040 | Training: One mini-game per stat at the Training Paddock (Sprint Lane, Gate Break, Hill Climb, Mud Splash) | See docs/WORLD_DESIGN.md; values in `GameConfig` once built |
| D-041 | Spectators: Cheer cards for anyone near the rail or in the grandstand, for either course | See docs/WORLD_DESIGN.md; values in `GameConfig` once built |
| D-042 | Friends and safety: Roblox chat only, preset emotes for players who can't chat, every typed name filtered | See docs/WORLD_DESIGN.md; values in `GameConfig` once built |
| D-043 | Stable Board: daily, weekly and monthly jobs: Noticeboard in the barn and a clipboard button | See docs/WORLD_DESIGN.md; values in `GameConfig` once built |
| D-044 | Money guardrails (amends D-002a): Diamond time skips apply to decor builds only | See docs/WORLD_DESIGN.md; values in `GameConfig` once built |
| D-045 | For grown-ups: A button explaining races (no gambling, nothing buys speed), Diamonds, the visit setting and weekly play time, with a pointer to Roblox parental controls and an optional break reminder. | See docs/WORLD_DESIGN.md; values in `GameConfig` once built |
| D-046 | Leagues and careers: Stakes unlock by League Points and a win promotes | See docs/WORLD_DESIGN.md; values in `GameConfig` once built |
| D-047 | Breeding (later): From Bronze, Green Cash fees only | See docs/WORLD_DESIGN.md; values in `GameConfig` once built |
| D-048 | Promotion (Stakes) races are called Cups in the game: "Rookie Cup"; same rules | Rename the UI strings in `RacePicker`, `HorsesClient`, `Advice`, `RaceService` |
| D-049 | First ten minutes: five-step tour (race, feed, brush, plant, Stable Board) with GO and Skip; settings can replay it | Empty `Tour.STEPS` or hide the card in `GrownUps.client.luau` |
| D-050 | Diamond store (Tack & Paint): 1 Diamond = 1 Robux packs 50/100/250, looks only, caps 250 per 24 h and 1,000 per 30 days, 24 h returns, no prompts around races, free Diamonds from promotions and monthly jobs only | Prices and caps in `DiamondProducts.luau`, items in `Style.luau`; set every productId to 0 to switch packs off |
