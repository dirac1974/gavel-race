# Race dynamics: stretch leaders, running styles, comebacks

Brief by `roblox-researcher`, 2026-10-04, for debate 008. The researcher found no open, large-sample figure for how often the stretch-call leader wins across all US dirt races (Brisnet's pace articles timed out); the closest confirmed number is from the Kentucky Derby.

## 1. Stretch-call leader
- Kentucky Derby (US dirt, 1¼ miles), 1903–2017: the horse in front with an eighth of a mile left won 85 of 115 times (74%). Of the other 30 winners, 16 were second at that point (13 within half a length), so about 14 of 115 (12%) won from 3rd or worse. One big-field race, so treat it as a proxy. [Rees]
- The horse leading at the first call wins 26% of races (William Quirin, 15,000+ races). [Ontario Racing]

## 2. Running styles (2025 dirt; speed = leading or within 1 length early, stalkers 1–4 back, closers 4+)

| Track | Sprints (speed/stalk/close, %) | Routes (speed/stalk/close, %) |
|---|---|---|
| Santa Anita | 58/32/10 (279 races) | 58/35/6 (141) |
| Monmouth | 57/34/9 (173) | 59/28/13 (110) |
| Saratoga | 47/~38/15 (155) | 45/40/15 (89) |

Closers win 6–15% of dirt races; routes are only slightly kinder to them.

## 3. Leaders, favourites, longshots
- Favourites win about 33% overall: about 40% in 6-horse fields, 27% in 12-horse fields; the second choice wins 21%. Smaller modern fields push it higher (38.7% over 1,171 races in January 2022, average field 7.8).
- Morning-line 30/1 horses win about 1%; even-money horses nearly 2 in 3.
- No public count of lead changes per race was found.
- Physics: every horse slows down late; the winner slows the least (PLOS ONE 2020).

## 4. How broadcasts and games show it
- **Trakus "chiclets":** moving program numbers on the toteboard and TV, 2006 to Dec 2022; Equibase E-GPS replaced it.
- **Umamusume:** 4 running styles and 4 race phases, each style with its own speed multiplier that flips late (early: front-runners 1.0, end closers 0.931; late: front-runners 0.962, end closers 1.0). Stamina is checked when the final leg starts.
- **Rival Stars:** a sprint meter saved for the home stretch; some traits refill stamina in the final stretch.
- **Derby Owners Club** (Sega, 1999): front runners or stretch runners; whipping too much costs the horse's confidence.

## What it means for the game
- Comebacks should come from leaders tiring, not closers suddenly speeding up: per-phase speed shapes by style.
- Targets: speed horses ~55% of wins, stalkers ~33%, closers ~10%; the stretch leader holds about 3 in 4; about 1 in 8 winners comes from 3rd or worse at the eighth pole; an 8-horse favourite wins 35–40%; 30/1 types about 1%.
- Make surprises readable: a position strip and late cues from the far turn, so a closer's win can be seen coming.

Our simulation (debate 008): with the `x²` luck blend the eighth-pole leader wins 61% and 11% of winners come from 3rd or worse there; smoothstep gave 89% and 1%.

## Sources
- [Rees, WAVE/WDRB 2018](https://www.wdrbwave.com/story/38021484/final-fractions-theory-jennie-rees-breaks-down-contenders-final-derby-prep-splits)
- [Ontario Racing 2024 (Quirin)](https://ontarioracing.com/news-and-results/top-racing-headlines/2024/why-a-study-in-speed-makes-mister-banjoman-a-horse)
- America's Best Racing: [Santa Anita](https://www.americasbestracing.net/node/72524), [Monmouth](https://www.americasbestracing.net/gambling/2026-born-run-fast-tips-and-trends-betting-monmouth-park-2026), [Saratoga](https://www.americasbestracing.net/node/71345)
- [Predictem (Strong 2025)](https://www.predictem.com/?p=8368)
- [Horse Racing Nation 2022](https://www.horseracingnation.com/news/Favorites_are_winning_at_the_same_percentage_two_weeks_in_123)
- [Green, Lee & Rothschild, Wharton 2018](https://jacobslevycenter.wharton.upenn.edu/wp-content/uploads/2018/08/The-Favorite-Longshot-Midas.pdf)
- [Mercier & Aftalion, PLOS ONE 2020](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0235024)
- [Trakus, BloodHorse via TrueNicks](https://www.truenicks.com/articles/265672/trakus-winds-down-operations-amid-shift-to-e-gps)
- [uma.guide race phases](https://uma.guide/guides/race-phases)
- [PocketGamer, Rival Stars](https://www.pocketgamer.com/rival-stars-horse-racing/rival-stars-horse-racing-tips-to-help-you-flying-out-of-the-gate/)
- [Rival Stars traits guide](https://www.rivalstarshorseracing.com/traits-guide)
- [Wikipedia, Derby Owners Club](https://en.wikipedia.org/wiki/Derby_Owners_Club)
