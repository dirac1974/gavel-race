# 008 — How should the horse set the baseline, taps move it, and luck show on the track? Plus: replays

Date: 2026-10-04 · Status: Decided provisionally (D-033, D-034); David agreed with the panel's direction · Moderated by Claude, panel run as separate agents.

## Question and constraints

David: "the chance should be based off the horses strength/attributes/care/energy/training/rest etc... That should be the baseline speed. The meter game play should adjust the speed, but only relative to the other players performance so the 'net performance' is unchanged... surprise horse comes up passing a bunch on the home stretch... but we also want the player to know they are playing well." Then: "We should also have a replay option that is either just the last 1/4 of the race, or a full race sped up... In case a player wants to bask in their victory of their lucky comeback."

Constraints: hard rules 1–3 (no wagering, Diamonds never change win chance, kid safety), base chance from Race Rating (D-014), race-relative skill `R = clamp((S − mean S)/50, −0.5, 1)` (D-003/D-004) so taps are zero-sum, purses locked before the gate (D-017), finish odds stay Harville.

## Facts

- **Already true:** the baseline comes from Race Rating (stats, care, jockey, strategy, bond); taps are compared with the other riders in the same race and chances always sum to 1.
- **Missing:** the race had no shape (positions on screen were just "who's likely to win"), so real comebacks couldn't happen. Energy and rest were deliberately kept out of speed by D-015.
- **Exponential race (verified):** give each horse a secret luck number `L ~ Exp(1)` at the gate; projected finish time `T = L / p`. Sorting by `T` gives exactly the Harville finish (P(first) = p, P(second) = Σ p_j p_k / (1 − p_j)). A 200,000-race simulation matched win and 2nd-place frequencies; a rider's taps change only their own `p`, so the other horses keep their relative order (monotone). Luck is never sent to clients.
- **Real racing (researcher):** Kentucky Derby 1903–2017, the leader at the eighth pole won 85 of 115 (74%); about 12% of winners were 3rd or worse there. Front-runners win ~55% of US dirt races, stalkers ~33%, closers ~6–15%. Comebacks come from leaders tiring, not closers suddenly speeding up. Games: Umamusume (style speed multipliers that flip late), Rival Stars (sprint meter saved for the stretch), Derby Owners Club (front runners vs stretch runners). Sources in the brief: Rees (WAVE/WDRB 2018), Ontario Racing 2024 (Quirin), America's Best Racing track trends, Mercier & Aftalion (PLOS ONE 2020), uma.guide.
- **Blend curve (our simulation, 8 horses, eighth pole = 11.8 s from the line):** smoothstep blend → stretch leader holds 89%, 1% of winners from 3rd+; `x²` → 61% and 11%; `x^1.4` → 71% and 6%.

## Openings (summary)

- **Engagement:** comebacks are the highlight reel; keep luck hidden until the last tap and reveal it hands-off (watch the run-in).
- **Competitive:** keep Harville exactly; luck must never be shaped by player input or near-miss logic; margins a fixed function of `T` ratios; show your riding separately from the result.
- **Child safety:** a hands-off reveal after your last tap has the structure of a slot machine (input ends, then you watch chance land, sometimes inches short). Blend luck in from the far turn so it is on screen by the last tap, with no separate reveal phase. Energy stays out of speed: "a tired horse never runs slower, so a kid who races a lot or misses a day never feels they hurt their horse, and nobody can buy speed." Rest instead speeds training.
- **Young player:** kids need to see their taps work straight away; a small instant nudge on a good tap, an up/down arrow, stars on the results card, never percentages.

## Rebuttals

The panel split 2–2 on when luck shows (hands-off reveal: engagement, young player; blend while tapping: child safety, competitive). The moderator sided with the blend because the reveal argument touches hard rule 1. Everyone agreed on: the exponential race, instant luck-free tap feedback, a results card that leads with your riding ("You rode ★★☆", "Your riding gained you 2 places!" only when it's a gain), energy out of speed, rest speeds training 50% inside the weekly cap.

## Options

| Option | For | Against | Panel support |
| --- | --- | --- | --- |
| A. Hands-off reveal after the last tap | Biggest drama | Slot-machine structure; luck lands after input ends | 2 |
| B. Luck blends in from the far turn while taps still count (chosen) | Comebacks visible as they happen; no reveal phase; same odds | Less suspense at the wire | 2 + moderator |
| C. No race shape (positions = chance) | Simple | No comebacks, which is David's ask | 0 |

## Recommendation (D-033)

Option B with the `x²` blend (luck mostly hidden until the stretch, then visible while taps still count). Tap feedback on your own horse is instant and luck-free. Energy stays out of speed (D-015 stands); rest speeds training. Minority view kept: test a hands-off reveal in playtests only if kids find the finish flat.

## Replay (D-034)

All four designers: offered after every race and never autoplayed; default is the final quarter at real speed, plus "Whole race ×3"; clearly a replay (REPLAY banner, letterbox, no tap pad); overlays of your own tap results, checkpoint stars, a pulse when the burst landed, "+N" where you gained places. Competitive: play back only what was recorded on this screen, end on the official result, no "ghost" horses that would reveal luck not shown live. Young player: half speed for the last 2 seconds. Child safety: slow motion only when you won (slowing a narrow loss replays the near miss); photo-finish still when 1st and 2nd were under a length apart; no race-again or shop prompt on the replay screen; Reduced Motion gets a fixed finish-line camera.
