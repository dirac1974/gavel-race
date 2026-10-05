# 001 — How should the gavel meter look, feel, and get harder?

Date: 2026-10-04 · Status: Decided provisionally (D-010) · Run by Claude in the planning session, following the council protocol, before the agents existed in the repo.

## Question and constraints

What meter motion, timing, feedback, and difficulty curve make the gavel feel skillful and fair to 8–13-year-olds on phones, without changing the race math?

Constraints: hard rules in CLAUDE.md; D-003/D-004 (score `s = 100(1 − d)`, three windows, skill vs. race average); server-authoritative scoring.

## Facts (researcher)

- Score depends only on distance from the meter's center, so any difficulty change must come from motion or target, not from a different scoring formula, or the skill measure stops being comparable across leagues.
- Roblox exposes a shared clock (`workspace:GetServerTimeNow()`), so the server can score a tap from a client-reported time and check it against arrival time.
- Most Roblox players are on mobile; touch latency plus network round trip commonly lands around 100–250 ms (estimate; to confirm in playtests).

## Openings

### Engagement
The tap is the moment players will talk about. Make every tap a little celebration: a big word ("Perfect!"), a sound, the horse surging, the Win Chance number ticking up. Difficulty should climb with leagues so promotion feels like a new challenge. Add a "Perfect streak" across the three windows for a small cosmetic reward track.

### Competitive
Keep the scoring identical everywhere so a 90 means the same thing in every league. Get harder through speed, then a moving target in Gold, then two targets in Champion's final window. Constant speed (triangle wave), not easing: easing makes the center the fastest point, which punishes exactly the skill we want. Show the exact score after each tap so players learn.

### Child safety
No streak mechanic that can be lost in a way that stings, no "so close!" messaging designed to bait another race. A missed tap shouldn't feel like a disaster for a young child. Accessibility matters: reduced motion, colorblind-safe zone markings, haptics as an alternative cue.

### Young player
Kids must understand it without reading: a bar, a moving marker, a glowing middle, a big TAP button anywhere on the lower half of the screen. Rookie should be slow enough that most kids land "Good" on their first try. Three seconds is short for a distracted 8-year-old; give Rookie more time.

## Rebuttals

- **Competitive → Engagement:** a "Perfect streak" reward track is fine if cosmetic only; it must not touch win chance beyond the normal score.
- **Child safety → Competitive:** agrees on constant speed and visible scores; asks that misses show a gentle tip rather than a fail state.
- **Engagement → Child safety:** drops the streak counter in favor of a per-race "Perfect" badge count that never resets.
- **Young player → all:** "assist" settings (slower meter) can't apply in cash races without unfairness; offer them in Practice and Friend Races.

## Options

| Option | For | Against | Panel support |
| --- | --- | --- | --- |
| A. Same scoring, difficulty via speed → moving target → two targets | Comparable skill across leagues; clear progression | More states to build | 4/4 |
| B. Narrower scoring band in higher leagues | Simple to build | Breaks comparability of S; harsher misses | 0/4 |
| C. Fixed difficulty everywhere | Simplest | No sense of progression | 0/4 |

## Recommendation (adopted provisionally as D-010)

Option A, with these numbers in config:

| League | Full sweep (there and back) | Window length | Target |
| --- | --- | --- | --- |
| Rookie | 2.4 s | 4.0 s | Fixed center |
| Bronze | 2.0 s | 3.0 s | Fixed center |
| Silver | 1.6 s | 3.0 s | Fixed center |
| Gold | 1.3 s | 3.0 s | Center drifts ±0.3 of half-width |
| Champion | 1.1 s | 3.0 s | Final window: two half-width targets at ±0.5, nearest counts (distance doubled, so a random tap still averages 50) |

- Triangle-wave motion; a random tap averages 50.
- One tap per window; no tap scores 0. A dropped connection scores the race average once per race.
- Feedback after each tap: label (Perfect ≥ 95, Great ≥ 80, Good ≥ 60, Okay ≥ 30, Miss), the score, and the Win Chance change. A short tip after a Miss.
- Per-race "Perfect" count shown on results; collected into a cosmetic-only badge track that never resets.
- Accessibility: reduced motion, colorblind-safe patterns, haptics. Slower-meter assist only in Practice and Friend Races.
- Taps scored at the client-reported server time if it is no more than 300 ms before arrival and within the window; otherwise scored at arrival time.

## Minority view

None on the core choice. Engagement still prefers a visible streak counter; parked unless playtests show the badge track is too weak.

## Decision

D-010, Accepted (provisional). In REVIEW_QUEUE.
