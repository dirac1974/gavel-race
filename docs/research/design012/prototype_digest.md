# Debate 012: moderator's prototype results (for the rebuttal round)

Scratch copy of `src/trip.py` (`prototype/trip012.py`) with the new rules behind switches. With the default config it reproduces `trip.py` exactly (200/200 races identical, mashers included). Every number below is Trip's own server state at 10 Hz, before the lock, in all 8 course × distance cells. "Eased" = an S-curve glide (accel-limited, speed-capped, then braking); "1.0 s" = top speed 1.5 lanes/s (9 ft/s), accel 4.5 lanes/s² (27 ft/s²).

## E1: motion and zig-zag (80 races per cell; a focal rider among 7 bots)

| Variant | One lane (press to arrival) | Two lanes chained | Masher reversals/min (shortest gap) | ◀▶ ditherer reversals/min (shortest gap) | Top sideways speed, drift | Accel p95 / max (ft/s²) |
| --- | --- | --- | --- | --- | --- | --- |
| D-054 as built (linear 0.6 s) | 0.6 s | 1.2 s | 29.3 (0.6 s) | 74 (0.6 s) | 10 ft/s, 10.1° | 125 / 200 (instant starts, stops and reversals) |
| D-054 + 0.5 s reverse gap | 0.6 | 1.2 | 16.8 (1.1) | 35 (1.1) | 10, 10.1° | 105 / 100 |
| Eased 1.0 s, no rules | 1.0 | 2.0 | 19.3 (1.0) | 42 (1.0) | 9, 9.1° | 25 / 28 |
| Eased 0.8 s, chain, 0.4 s gap (Young player / Engagement "0.9 s") | 0.8 | 1.4 | 15.3 (1.2) | 30 (1.3) | 10, 10.1° | 35 / 37 |
| Eased 1.0 s, chain, 0.5 s gap | 1.0 | 1.6 | 11.9 (1.5) | 26.5 (1.5) | 9, 9.1° | 25 / 30 |
| …same, opposite presses refused instead of waiting | 1.0 | 1.6 | 6.6 (1.5) | 2.5 (6.1) | 9 | 25 / 30 |
| Eased 1.1 s, chain, 0.8 s gap (Competitive) | 1.1 | 1.9 | 9.6 (1.9) | 21 (1.9) | 8.1, 8.2° | 15 / 20 |
| **Eased 1.0 s, chain, 0.5 s gap + weave gap** (a second reversal within 5 s waits 2.5 s) | 1.0 | 1.6 | **7.1 (3.5)** | **12.1 (3.5)** | 9, 9.1° | 25 / 30 |
| Eased 0.8 s + weave gap | 0.8 | 1.4 | 7.8 (3.3) | 12.9 (3.3) | 10, 10.1° | 35 / 37 |

- Casual riders reverse about 1.3 times a minute in every variant, so the rules only bite on mashing.
- A 0.4–0.8 s reverse gap alone still lets a masher sway every 1.5–1.9 s. The weave gap is what turns it into "changed my mind once, then settle".
- **Overlaps** (4,000 races per variant, three riders pressing at once: a masher, a ditherer and a casual rider): 0 for D-054, eased 1.0 s + weave and eased 0.8 s + weave. Eased 1.0 s without the weave gap had 1 overlap (two horses converging on one lane from both sides while the front one was itself held). Fixed by a "glide reserve": a horse gliding into a lane keeps 6 ft extra room ahead and behind. No horse ever falls back faster than 19 ft/s (D-055's jerk line is 20).

## E2: boxed in (eased 1.0 s + weave; one focal horse at each post among 7 bots)

"Boxed" = a horse within 12 ft ahead in your lane, AND the inside blocked (the rail, or a horse in the 8 ft-ahead / 10 ft-behind clear zone), AND the outside blocked.

| Policy | Boxed (share of pre-lock time) | Races with ≥ 1 s boxed | By post 1–8 |
| --- | --- | --- | --- |
| Smart Steer kid | 5.5% | 21% | 1, 2, 9, 9, 8, 6, 5, 4% |
| Rail rider | 49% (on the rail behind a horse, one outside: the classic box, where it wants to be anyway) | 80% | 1, 54, 57, 60, 54, 57, 53, 55% |
| Never steers | 0.4% | 2% | |
| Casual | 32% | 62% | |
| Bots | 12% | | |

- "Trapped" (boxed and no slot within the 3-length tuck reach): about 1% of the time for a Smart Steer kid, 0% for a rail rider.
- Press handling compared (rail rider / casual: inward press reaching its lane within 3 s):
  - D-054 rules (tuck at once inward; outward waits 1 s): 93% / 82%
  - wait + tuck (both wait for a gap, inward tucks at once, drop after 1.5–3 s): 93% / 67%. The casual drop is mostly a counting artefact: a press that drops gets pressed again and counted again. A fixed metric is coming with E5.
  - wait + tuck after 0.5 s: 87% / 61–63%
  - **wait only (no tuck-back): 4% / 19%**; Smart Steer kids end 2.3–3.8 lanes out by post instead of 2.0. This kills steering.
- 59–66% of casual inward presses meet a blocked lane at the moment of the press. Most of those are resolved by tuck-back within a second or two.

## E3: brushes (eased 1.0 s + weave, wait + tuck; 60 races per cell)

A brush never replaces a tuck-back the press could start, and the blocker must have been alongside for 0.3 s (lag safety).

| Trigger | Cost | Casual: races with a brush / charged / mean cost | Wanderer | Rail rider | Masher (4 presses/s) | ◀▶ ditherer |
| --- | --- | --- | --- | --- | --- | --- |
| Any press at a horse alongside (Competitive) | 0.002, first free, cap 3 | 72% / 51% / 0.0023 | 82% / 65% | 0 | 97% / 94% / 0.0053 | 85% / 77% |
| A second press while the first waits (Engagement) | 0.005, cap 2 | 6.2% / 6.2% / 0.0005 | 38% / 38% / 0.0026 | 0 | 84% / 84% / 0.0076 | 0 |
| A second press while the first waits | 0.002, first free, cap 3 | 6.2% / 3.3% / 0.0001 | 38% / 15% / 0.0004 | 0 | 84% / 68% / 0.0034 | 0 |

Brushes never caused an overlap.

## E4: griefing (worst case: strangers tap exactly like the kid, so they sit right beside it; 40 races per cell)

The kid's own trip (ground + draft) change against the same strangers riding plain Smart Steer at the same pace:

| Strangers | With tuck-back (D-054 or new rules, within 0.0005): Smart Steer kid / rail kid | Without tuck-back (wait only) |
| --- | --- | --- |
| Shadow (sits on the kid's inside) | −0.0012 / +0.0003 | −0.0062 / −0.0054 (p5 −0.04) |
| Crew of 3 (inside, outside, ahead) | +0.0011 / −0.0001 | −0.0090 / −0.0087 (p5 −0.055) |
| Bumper (gets beside, keeps pressing into the kid) | −0.0005 / −0.0003 | −0.0146 / −0.0133 (p5 −0.062) |
| **Untargeted control:** the same strangers just riding for the rail | 1 stranger −0.0013; 3 strangers −0.0020 | |

- With tuck-back, targeting a kid hurts the kid no more than the same players simply riding well. The kid's τ does drop 0.002–0.005, but all of it comes from the field mean: the strangers' own good trips. The untargeted rail control does the same (3 strangers: −0.009).
- Without tuck-back, strangers can hold a kid 1–2 lanes wide: a real griefing vector.
- Who pays a brush (a bumper against a Smart Steer kid): **mover pays**: the kid is charged 0, the griefer about 3.8 bumps a race (hits the cap). **Bumped pays**: the kid is charged 1.2 a race, own trip −0.0026, and 30% of races are below −0.005. **Both**: the kid is charged 0.2 a race (its own presses into the griefers). **Nobody**: nothing changes.

## Pending

E5: the D-054 acceptance targets (rail vs Smart, never-steer, within 3 s, draft share, post bias, Smart Steer kid mean) with regenerated baselines for eased 1.0 s + weave + wait/tuck, with and without brushes. It also brings a per-press "wait for a gap" chip frequency.
