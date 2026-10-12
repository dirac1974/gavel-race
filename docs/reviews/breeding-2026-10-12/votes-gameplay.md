# Gameplay votes: breeding plan (D-080)

**Overall: CHANGE (no block).**

Breeding is the right return engine. It replays the ladder with a horse the kid made, and every family gets a story. Two numbers need fixing.

| § | Vote | Note |
| --- | --- | --- |
| 1 Who can breed | **AGREE** | 30 races, one parent in Bronze, and 20 races of rest (counted in races, no clock) are right. No genders is right for 8–13: half the horses are never "the wrong kind", and the copy stays clean. Keep genders as a playtest question only. |
| 2 Math | **CHANGE** | `startShare 0.60` is right in spirit, but a 90-Potential foal starts at about 54, just under Rookie's ceiling of 55. Its Rookie races would close after a handful of wins, and it would skip the very ladder breeding is meant to replay. Add `breeding.startMax = 50` per stat: start = min(0.60 × P, 50). Good breeding still means more room to grow. |
| 3 Coats | **AGREE** | 45 / 45 / 10% Surprise with every option named is honest and fun. Required: roll the coat **on the server at confirm** and store it on the pending foal, so leaving, rejoining or waiting can't reroll it. |
| 4 Flow | **CHANGE** (small) | "8 races or the next day you play" is a good return hook with no countdown. Add the foal's **first race moment**: the race card and results say "Comet's foal!" once, and the Family page logs the first win. |
| 5 Economy | **AGREE** | Breed then sell must always lose cash: keep the test. |
| 6 Safety | **AGREE** | Add "breed" to the allowed words. "mating", "pregnan" and "birth" stay banned. |
| 7 Sims | **CHANGE** | Add a gate: a generation-3 foal with `startMax` gets **≥ 15 regular Rookie races** before its ceiling, and its Rookie win rate with an average kid is **20–30%**. |
| 8 Visuals | **AGREE, with a symbol fix** | One symbol per meaning (D-064): 🍼 is the foal and the Foaling Barn, and 🌱 is the family line. The Young stage chip can be neither. Use 🌼 for Young (`Ageing.EMOJI.Young`, `YOUNG_LINE`). |
| 9 Phasing | **AGREE** | Merge the model only on green sims. |
| 10 Config | **CHANGE** | Add `startMax = 50`. |
