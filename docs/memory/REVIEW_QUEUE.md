# Review queue for David

Provisional decisions made by the team under D-009, newest last. For each: keep, change, or reverse. Reversing is cheap because each one sits behind config or a single module.

| Decision | Summary | How to reverse |
| --- | --- | --- |
| D-002a | Diamonds buy cosmetics, time, space, and Exhibition entries only; never win chance or cash-league qualification | Change the Diamond catalog config and D-002a |
| D-010 | Gavel meter: speed per league, drifting target in Gold+, two half-width targets in Champion final window, feedback labels, per-player latency allowance capped at 0.3 s (D-021) | Edit `GameConfig.leagues` and `GameConfig.scoreLabels` |
| D-011 | Prototype rules: missed tap = 0, disconnect = window average once, bots ±6 rating and N(50,15) scores, bots unpaid | Edit `GameConfig` (missedTapScore, bot*) |
| D-013 | Stakes thresholds 100 / 110 / 1,400 / 3,000 League Points to hit the Bronze 3 h, Silver 3 days, Gold 3 weeks targets | Edit `GameConfig.stakesUnlockPoints` |
| D-014 | Race Rating formula: condition-weighted stats, +5% care, +3 pilot, +2 strategy, +2 bond; Focus excluded | Edit the weight tables and bonus constants in `race_rating.py` and `RaceRating.luau` together (parity tests enforce it) |
| D-015 | Energy: 5 per horse, 1 per cash race, +1 per 20 min, care top-ups, Rookie free, Practice races when tired | Edit `GameConfig.energy` |
| D-016 | Flat 2nd–4th prizes, ribbons in UI, no exacta prizes | Edit `GameConfig.placePrizes`, `GameConfig.ribbons` |
| D-002a (amended) | Diamonds can't buy stalls, auto-feeder, or Energy refills | Edit D-002a and the Diamond catalog |
| D-022 | Stride stretches replace single taps (tap on the horse's stride, ~8 beats per stretch, drifting tempo); detection on tap-gap vs beat-gap spread < 12 ms over 300+ beats, 5+ races, 2+ days; rider ladder: logged, private note + taps count as race average, human review then cash races paused 7/30 days; Final Burst tap after the last stretch counts double (40% of S); no whip; named Giddy-up | Revert to D-010 windows in `RaceSession`; thresholds in `GameConfig` once built |
| D-020 | Clap Along crowd boost: crowd = best fan + 0.15 and 0.10 assists from fans 2 and 3 (capped), Top Fans board after each race, strikes for flagged fans (1st quiet, 2nd private warning, 3rd fan play off 30 days, strikes expire after 90 days), boost up to 0.03 in the tilt exponent (+0.3 points on a 12.5% horse), cash races included, cheat flags on timing spread | Set the crowd boost cap to 0 in `GameConfig` once built |
| D-019 | Spectator cheering: free, cheer one rider before window 1, Fan XP from their taps (3/2/1/0) plus flat 2 for a win, max 11 per race and 100 per day, cosmetics only, ≤ 20% of a rider's progress per race | Edit `GameConfig.spectator` once built; remove the spectator UI |
