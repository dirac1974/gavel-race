# Review queue for David

Provisional decisions made by the team under D-009, newest last. For each: keep, change, or reverse. Reversing is cheap because each one sits behind config or a single module.

| Decision | Summary | How to reverse |
| --- | --- | --- |
| D-002a | Diamonds buy cosmetics, time, space, and Exhibition entries only; never win chance or cash-league qualification | Change the Diamond catalog config and D-002a |
| D-010 | Gavel meter: speed per league, drifting target in Gold+, two half-width targets in Champion final window, feedback labels, 0.3 s latency allowance | Edit `GameConfig.leagues` and `GameConfig.scoreLabels` |
| D-011 | Prototype rules: missed tap = 0, disconnect = window average once, bots ±6 rating and N(50,15) scores, bots unpaid | Edit `GameConfig` (missedTapScore, bot*) |
