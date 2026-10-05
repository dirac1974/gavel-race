# 007 — How should riders tap during the race, and how do we stop macros?

Date: 2026-10-04 · Status: Decided provisionally (D-022) · Moderated by Claude, panel run as separate agents.

## Question and constraints

David asked for the race to resist auto-clickers ("the target should move every couple of clicks"), for detection based on "the time between their clicks ... to the point when it's not humanly realistic before banning", and, mid-debate, for **many taps through the middle of the race, "sort of like whipping the horse"** instead of three single taps. He also noted "gavel" isn't a horse-racing term.

Constraints: CLAUDE.md hard rules (no wagering; Diamonds never affect win chance; kid safety: no public shaming, no pressure). Each stretch still yields a score `S` in 0–100 feeding the race-relative skill `R = clamp((S − mean S)/50, −0.5, 1)` (D-003/D-004), so a baseline shift is harmless if every lane is scored the same way. Equal difficulty for every lane. Server-authoritative scoring (D-021).

## Facts

- **The current meter is fully macro-able.** The marker always starts at the left edge when a window opens, so "tap 0.60 s after open" scores 100 every time in Rookie–Silver. Simulation (Rookie meter, human with 60 ms timing error):

  | Meter | Best fixed-delay macro | Human |
  | --- | --- | --- |
  | Current | 100 | 92 |
  | Random marker start each window | 49.5 (= random tapping) | 92 |
  | Target relocates each window | 75 | 92 |
  | Both | 49 | 92 |

- **Stride rhythm (the Clap Along scoring from D-020)** against a tempo that is set per race and drifts each stride: mashing ≈ 0, fixed-rhythm macro ≈ 3, good human ~57, average human ~30, screen-reacting bot ~50, beat-predicting bot ~82 but with ~5 ms timing spread (people: 30–50 ms).
- **Roblox policy** ([Community Standards](https://about.roblox.com/community-standards), checked 2026-10-04): exploits for unfair advantage are banned and the Ban API is the tool for proven cases; auto-clickers aren't named. "Depicting or glorifying ... animal ... abuse" is prohibited; [content maturity](https://create.roblox.com/docs/production/promotion/content-maturity) puts repeated mild violence at the Mild label.
- **Roblox ping** (`Player:GetNetworkPing`) is a round trip in seconds, readable on the server for any player, and 0 in Studio.
- **Detection limits** (researcher): no Roblox rule names auto-clickers; an InputObject has no timestamp or synthetic-input flag, so a physical tap and an automated one look identical; Roblox's own server-side "Action Cadence" heuristic flags auto-clicker-regular timing as "a signal, not as definitive proof".
- **Mobile auto-tappers** (third-party): the top Android auto-clicker has 100M+ installs and is rated Everyone; it taps blind on fixed timers. iOS has no App Store auto-tapper (unconfirmed), but accessibility features can record gestures.
- Full brief: [research/2026-10-04-autoclickers.md](../research/2026-10-04-autoclickers.md).

## Openings

### Engagement
A random marker start in every league, a relocating target from Bronze up, quiet detection, no mid-window jumps. A fixed 0.60 s rhythm goes stale by about race 50 (estimate); a random start makes every window a fresh read. Cheaters winning in plain sight is a known retention killer, so handle them quietly, with flagged riders in a separate pool.

### Competitive
A random start shared by all lanes, never reaching the target sooner than 0.4 s. No relocating target: it adds nothing on top of the random start and an off-centre target drags a random tap to ~44, breaking the D-010 baseline. No mid-window jumps: 50–100 ms phone touch lag turns an honest Perfect into a Miss. Detect on timing-error spread (device lag shifts the mean, not the spread), below 12 ms.

### Child safety
Make macros worthless by design so detection only has to catch rare scripts, slowly and gently. Flag on spread, not score, because "sustained S > 95" catches skilled kids. Log only for the first month. Ladder ends in a cash-race pause only after a person reviews the logs; never claw back Green Cash; an "Ask for a check" button.

### Young player
Keep the glow centred so Rookies lock in "tap in the glow"; a random start costs kids nothing. A target that hops as the thumb lands reads as the game cheating. A false flag on a 9-year-old who finally got good ("we think you cheated") makes her quit, so the ladder must never accuse.

## Rebuttals (after David's "many taps" change)

- **All four back M1, stride rhythm:** tap on the horse's stride beat, the same skill as fans' Clap Along. Mashing ≈ 0, fixed macros ≈ 3, and the drifting tempo does the random start's job, so the target question goes away. M2 (repeated meter) repeats at a fixed interval an interval-clicker can copy; M3 (push and breathe) rewards tap rate (thumb strain) and a steady cadence a clicker holds.
- **No whip, 4/4.** Hitting the horse as the core loop is what parents screenshot, it sits near the Community Standards line on animal abuse, and it teaches "harder = faster = mash". Show hands-and-heels riding.
- **Name, split:** "Giddy-up" (Engagement, Young player: happy, shoutable, thumbnail-friendly), "Stride" (Competitive: tells you what to do), "Kick" (Child safety: real racing term; Engagement and Young player say it reads as kicking the horse).
- **Detection, converged on David's idea measured against the beat:** on a rhythm mechanic steady gaps are the skill, so compare each tap gap to the matching beat gap (or each tap to its beat). People are off by 30–50 ms, beat-predicting bots by ~5. Child safety: 48 taps is now one race and taps within a race are correlated, so require 300+ beats over 5+ races on 2+ days; Competitive: an elite 20 ms kid trips a single 48-beat check about 1 in 60,000 times, and checks run across thousands of kids. Log only for the first month.
- **Guardrails for M1:** the on-screen beat is what counts (Bluetooth audio lags 150–250 ms, so sound is decoration); tempo changes show a beat ahead; beat shown as hooves, a closing ring, and a haptic buzz; tap anywhere; reward at most ~3 taps a second; stretches of about 8 beats (≤ 10 s) with rests; mashing makes the horse visibly break stride so a low score has a reason; Rookie starts at a steady tempo; per-beat labels so an average kid (~30) still sees "Good".
- **Engagement** keeps one random-start meter tap as a final burst, because that "Perfect!" is the clip kids share.
- **Ladder:** everyone agrees flag 1 is invisible, nothing is public, no Green Cash or items are taken back, strikes expire after 90 days, and the last step needs a person to review the logs. Split on flag 2: Competitive, Young player and Engagement want the edge removed right away (taps count as practice or as the race average); Child safety wants nothing to change before review. Friends notice a missing name, so nobody is removed from boards.

## Options

| Option | For | Against | Panel support |
| --- | --- | --- | --- |
| M1 stride rhythm, three stretches | Widest skill spread; macros ≈ 3; same skill as Clap Along; David's "many taps" | New build; bots need recalibrating; must teach the beat | 4/4 |
| M2 repeated sweeping meter | Close to today's code | Fixed interval an auto-clicker copies; eyes on a bar, not the horse | 0/4 |
| M3 push and breathe (stamina gauge) | Easy to explain | Rewards tap rate (thumb strain); steady cadence is clicker-friendly | 0/4 |
| Keep three single taps + random start | Smallest change | Not what David wants; few taps for detection | 0/4 after the change |

## Recommendation (adopted provisionally as D-022)

1. **Replace the three single taps with three stride stretches.** In each stretch (about 8 beats, ≤ 10 s, ~2 taps a second), the rider taps on the horse's stride. Each tap is scored by closeness to its beat (±80 ms, as in Clap Along); extra taps count against; stretch score = mean over beats. The stretch score replaces the window score in `S`, so the race maths is unchanged. Tempo is set per race, drifts each stride, and changes are previewed a beat ahead; Rookie starts steady, faster gallop and more drift from Silver, an off-beat lead change in Champion. Bots are recalibrated to the new score distribution.
2. **Fans and riders share one beat skill**: Clap Along (D-020) uses the same scoring.
3. **No whip anywhere.** Hands-and-heels riding animation; the horse surges on good taps and breaks stride when mashed.
4. **Detection (David's delta idea):** compare each tap gap to the matching beat gap. Flag when the spread is under 12 ms over 300+ beats across 5+ races on 2+ separate days. Log only for the first month to measure real kids before any penalty.
5. **Rider ladder:** flag 1 logged only. Flag 2: a private, neutral note with a one-tap "Ask for a check", and until a check clears them or 7 days pass, that rider's cash-race taps count as the race average (removes the edge without punishing). Flag 3: a person reviews the logs, then cash races are paused 7 days (30 on a repeat); Practice, Friend Races, care, and training stay open. No Green Cash or items taken back, strikes expire after 90 days, never public, nobody removed from boards. The Ban API only for proven modified clients.
6. **Name:** Giddy-up (David's choice).

## Minority view

- Child safety: nothing should change at flag 2 before a person has reviewed the logs.
- Engagement: keep one random-start meter tap as a final burst for the shareable "Perfect!" moment; test it.
- Name: Child safety prefers "Kick"; Competitive prefers "Stride".

## Decision

D-022, Accepted (provisional). David chose the name **Giddy-up** (2026-10-04). In REVIEW_QUEUE.
