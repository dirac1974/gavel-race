# 010 — Should riders steer during the race, and how much should it change the result?

Date: 2026-10-05 · Status: Decided provisionally (D-054) · Moderated by Claude. The four designers ran as separate agents: independent openings, then one rebuttal round after reading each other, the researcher's brief and the moderator's prototype results.

Suggested repo path: `docs/debates/010-race-steering.md`.

## Question and constraints

David, after his playtest: "Maybe we should add some steering to the race too, but its constrained to look realistic where they can affect the outcome slightly since we are going away from the gambling concept it would probably be more fun."

**Today (code):**
- Every horse stays in its own lane for the whole race.
- Lane geometry is only visual. Each lane runs its own loop (`TrackLayout.lanePoint`), and all lanes reach the line together, so the lane has no effect on the result.
- Lanes are assigned humans first, then bots (`RaceSession.fillWithBots`).
- Win chance: p ∝ q · exp(κR + c), κ = 1, with c the crowd boost (≤ 0.03). The finish is the exponential race (D-033): secret luck L ~ Exp(1), sorted by L / p.
- Before the far turn, on-screen gaps come only from live chance. From the far turn, luck blends in (x²).
- Controls: **any** touch, key or gamepad button is a slider tap (`RaceController.client.luau`).
- The Final Burst opens 0.5 s into the homestretch.

**Constraints:**
- Hard rules 1–3: no wagering; Diamonds never touch win chance; kid safety.
- D-004: skill is measured against the race.
- D-033: luck is secret, the finish is exactly Harville, and no hands-off reveal.
- D-034: replays play back only what this screen recorded.
- D-021: the server is authoritative, with a latency allowance.
- D-006: friends never share cash races.
- Two courses race at once.

## Facts (researcher)

Checked 2026-10-05, plus the moderator's simulations.
- **Drafting:** Spence et al. (Biology Letters 2012; GPS once a second, 3,357 races): "For a horse that drafts for 75 per cent of a race, this effect is worth three to four finish places." Also: "Small margins in average speed (0.13 m s−1 or 0.9% between 1st and 5th place)" ([PMC3391435](https://pmc.ncbi.nlm.nih.gov/articles/PMC3391435)).
- **Ground:** a horse "six or seven paths wide ... will have to cover more ground" and "runs the risk of losing some momentum" on the turn ([ABR, ground loss](https://www.americasbestracing.net/gambling/2020-considering-ground-loss-when-evaluating-racehorses-chances)). Geometry: every 6 ft lane further out adds π × 6 ≈ 19 ft per 180° turn, about 2⅓ lengths, on any radius.
  - *Correction to the brief:* "one length per path per turn" came from a search snippet and isn't on the cited page, so it's dropped. The geometry gives the same order of size.
- **Boxed in:** "Perhaps the toughest 'bad' trip ... is one where a horse lacks room and never gets a chance to run" ([ABR, trip handicapping](https://www.americasbestracing.net/gambling/2019-beginners-guide-trip-handicapping)).
- **Interference:** US racing rules make it a foul to cross or weave in front of a horse so as to impede it. *Unconfirmed:* the state rule pages we tried were blocked or unreadable.
- **Real scale would swamp the race:** converted into our exponent, one lane wide on one turn would be worth about as much as a perfect ride. Any steering effect must be scaled far below real life.
- **Precedents:**
  - Rival Stars Horse Racing: "only two controls ... steering and sprint"; horses that prefer the middle or the rail get modest advantages ([Pocket Gamer](https://www.pocketgamer.com/rival-stars-horse-racing/rival-stars-horse-racing-tips-to-help-you-flying-out-of-the-gate/)).
  - Mario Kart 8 Deluxe Smart Steering keeps you on the track, but with it "Ultra Mini-Turbo cannot be achieved", so turning it off is a small skill edge ([Super Mario Wiki](https://www.mariowiki.com/Smart_Steering)).
  - Assist modes let players "take part on a level playing field" ([Game Accessibility Guidelines](https://gameaccessibilityguidelines.com/include-assist-modes-such-as-auto-aim-and-assisted-steering/)).
- **Roblox:**
  - Most sessions are on mobile ([Mobile input](https://create.roblox.com/docs/input/mobile)).
  - Default controls sit in the bottom-left and bottom-right corners; frequently used buttons belong within thumb reach of them ([Cross-platform design](https://create.roblox.com/docs/ui/cross-platform-design)).
  - Gamepad conventions: Thumbstick1 = movement, A = primary action ([Gamepad input](https://create.roblox.com/docs/input/gamepad)).
  - Never trust the client; validate on the server ([Security tactics](https://create.roblox.com/docs/scripting/security/security-tactics)).
- **What an exponent bonus δ for one horse does** (200,000 races, 8 horses, Rookie T = 22, taps N(60,15), same luck; 0.02 = 1 point of riding score S):

  | δ | win chance | gains ≥ 1 place | winner changes |
  | --- | --- | --- | --- |
  | 0.02 | +0.22 pp | 3.3% of races | 0.23% |
  | 0.04 | +0.44 pp | 6.5% | 0.45% |
  | 0.06 | +0.66 pp | 9.5% | 0.69% |
  | 0.10 | +1.1 pp | 15% | 1.1% |

  A typical tap edge (S 65 vs 50) is 0.3.
- **Moderator's prototype** (Python, 8 horses, lane changes with clearance, 300–500 races per row; scripts in the session scratchpad):
  - **The field jams.** Before the far turn the on-screen field is bunched within about ±12 ft. With "the target lane must be clear for ±1 length", most lane-change attempts were refused. Auto horses reached only lane ~2.1 (Mile) or ~3.2 (Sprint) by the far turn.
  - **Tuck-in fixes it.** Blocked toward the rail, the horse eases back about a length and slots in behind. Auto horses then reach lane ~1.5–2.1.
  - **Post bias is real.** With random posts and no correction, inside posts gain up to +0.02 and outside posts lose up to −0.02 (Mile). Subtracting a per-post baseline from all-auto simulations leaves at most 0.003.
  - **Final shape.** Smart Steer riding one off the rail, ground 0.012 per lane per turn, tuck-in credited as drafting, clamp −0.02 / +0.04:
    - a skilled steerer (takes the rail early) gains +0.011 to +0.023 over Smart Steer;
    - a rider who never steers with Smart Steer off (stays in the post lane) loses −0.014 to −0.016;
    - Smart Steer itself averages 0 by construction.

## Openings (summaries of the independent statements)

### Engagement
- Yes: steering is the riding fantasy, and Rival Stars ships with only steer and sprint.
- Size: rail on turns up to 0.05, drafting up to 0.05, 0.10 at most. Smart Steer earns ~0.04, so perfect steering beats it by 0.06.
- No boxed-in penalty: you tuck in behind instead, which is a draft.
- Lane choice counts through the last turn. Drafting stops at the far turn, where positions start to carry luck. Lanes lock in the homestretch.
- Discrete lane changes with a 0.4 s glide; arrow buttons bottom-left; A/D and arrow keys taken out of "any key taps"; D-pad.
- Smart Steer on by default, overridden for 5 s by any input.

### Competitive
- Exponent κR + λ·Tr + c, with Tr relative to the field like R and λ = 0.12; the best trip is worth 6 points. trip = 60% ground + 40% draft.
- No boxed-in penalty: being stuck behind earns draft, so blocking, griefing and collusion gain nothing.
- Steering runs from the gate to the far turn. A 3-2-1 bell there locks your lane for that turn; then trip freezes and the stretch is taps only.
- Trip never depends on luck. Test: swap the luck vectors and p stays identical.
- Discrete lanes, at most one change per 0.6 s, ±1 length clearance. Intents apply on 10 Hz server ticks, so lag only delays your own move.
- Rail Helper by default; bots use it plus noise.
- Post bias must stay under 0.005. Parity: a Python trip module against Luau over 1,000 scripted races.

### Child safety
- Small: perfect steering beats auto by 0.02; best line vs worst 0.08. Ground only, so the line score never depends on who is beside you.
- Auto on by default, so a kid who never steers loses at most 1 point.
- No lane changes in the homestretch or during the Final Burst, and a swipe never counts as a tap.
- No boxed-in penalty, because a stranger's position must never lower your chance; horses slide through each other.
- Positions that luck reveals after the far turn must not open or close a gap ("a near-miss reveal by another name").
- Words: "Saved ground on 2 turns!", never "Went wide, lost a place". Replays show your line as a ribbon with green chevrons and no "ideal line" ghost.

### Young player
- A small extra, never a second job; "the tap is the game".
- Two big buttons bottom-left, ◀ In and Out ▶. One press = one lane. They never count as taps; the rest of the screen still does.
- No swipe: "a swipe is a touch, and kids swipe through their taps."
- Lanes from the gate to the top of the stretch, locked before the Final Burst.
- Auto ON. Steering earns at most +0.04 over auto and costs at most 0.02.
- Kids won't feel 1 race in 15, so feedback is the reward: "Saved ground!", "Drafting!", "Good trip ★★☆".
- Auto only for the first three Rookie races, then a ghost-thumb tip.

## Rebuttals

All four moved after reading each other and the prototype.
- **Effect size, converged:** at most **+0.04 above auto, at most −0.02 below it**, an asymmetric clamp like R's.
  - Engagement came down from 0.06 over auto.
  - Child safety came up from 0.02: "kids won't feel my 0.02, and the uneven split protects kids who don't steer."
  - Competitive moved from 0.06 relative: "0.02 makes the control decoration, and kids learn that inputs lie."
- **Far turn, unanimous:** a soft 3-2-1 bell locks lanes at far-turn entry. The far turn's ground is booked from the lane you held at the bell, so Sprints keep their one turn. No lane changes after it, because whether a lane is clear would then depend on positions luck is moving.
  - Engagement and Young player gave up "through the far turn" and "until the top of the stretch".
  - Child safety: steering could stay live through the far turn only if clearance used skill-only positions.
- **Boxed in, unanimous:** no penalty. Held behind a horse counts as tucked in (draft credit), so being blocked is never worse than running free, and a blocker gains nothing.
  - Child safety accepted the tuck-in rule in place of sliding through: "the horse that moves always gives way and never pushes".
- **Drafting, 3–1 to keep it:** credited only while tucked in, before the far turn, capped at 40% of the trip, costing the horse in front nothing, and bots count.
  - Young player conceded to ground only at launch: "no kid believes being stuck was good".
  - The wording answers that: "Tucked in!" rather than "Drafting".
- **Controls, unanimous:** buttons on phones, no swipe. A/D and the arrow keys are carved out of "any key taps"; the D-pad and left stick are carved out of "any button taps".
  - Glide: Young player 0.4–0.5 s, Engagement 0.6 s, Competitive ~0.9 s. Moderator: **0.6 s, starting instantly**.
- **Smart Steer:** any input pauses it for 5 s, then it resumes by itself, so no kid is stranded wide (Engagement, Child safety, Young player). The arrows are hidden for the first three races.
- **Post positions:** drawn at random, never animated (a draw reveal is a lottery moment) and never mentioned.
  - Competitive's fix, adopted: score each trip against the per-post baseline from all-auto simulations, so every post expects zero and q and the locked purses stay untouched.

## Options

| Option | For | Against | Panel support |
| --- | --- | --- | --- |
| A. Lane steering from the gate to far-turn entry, lock with a bell; trip = ground + tuck-in draft, relative to the field and post baseline, clamp −0.02 / +0.04; Smart Steer default (chosen) | Realistic, luck-free, small and readable; Final Burst keeps one job; blocking can't hurt | New per-tick server state; must teach two buttons | 4/4 after rebuttals |
| B. Cosmetic steering only (no effect on chance) | Zero risk | Kids learn the input does nothing; not what David asked | 0/4 (kept as the `scale = 0` fallback) |
| C. Steering live through the far turn | More decisions at the key moment | Clearance would depend on luck-moved positions | 0/4 after rebuttals |
| D. Real-scale ground loss | Most realistic | Steering would outweigh taps | 0/4 |
| E. Boxed-in penalty | Real racing drama | Strangers could hurt each other; invites griefing and collusion | 0/4 |
| F. Continuous steering (stick or tilt) | Fine control | Too much load next to the slider; free positions are hard to keep realistic | 0/4 |

## Recommendation (D-054)

**When**
- Steering is live from the gate to the far-turn entry. That phase lasts about 24 s in a Sprint (backstretch only), ~49 s in a Mile, ~71 s in a Classic and ~96 s in a Marathon.
- Three soft bell ticks lead into the far turn, then "Lanes locked!" From then on lanes are cosmetic, and the stretch is the slider and the Final Burst only.

**What you do**
- One press moves one lane. The horse glides over in **0.6 s**, starting instantly on your screen. At most one change is accepted per 0.6 s, with one queued at most.
- **Tuck-in:** if a horse alongside blocks a move toward the rail, your horse eases back up to ~1.5 lengths and slots in behind it. This is visual only and never lowers your chance.
- A blocked move outward waits up to 1 s, then cancels with a small "no room" shake.
- Horses never overlap or bump. The horse that moves always gives way.
- A horse held behind another in its lane is drawn there, tucked in.

**What it's worth (the trip)**
- **Ground:** 0.012 per lane off the rail per 180° of turn. This uses angle, so it is the same on dirt and turf. Turns before the lock count live; the far turn is booked from the locked lane.
- **Tucked in:** 0.0012 per second while 0.5–3 lengths behind a horse in your lane, before the lock only, capped at 0.016 (40% of the top).
- **No boxed-in penalty.**
- **Formula:** τ_i = clamp(scale × (trip_i − postBaseline[course][distance][post_i] − field mean of the same), −0.02, +0.04), with scale = 1.
- **How it enters the race:** p ∝ q · exp(κR + c + τ).
- **When it counts:** τ is fixed at the lock and enters the live chances at that moment, then at checkpoint 2, the Final Burst, the stretch previews and the finish. Before the lock τ = 0, so trip never depends on luck.
- **Size:**
  - The best trip, +0.04 (2 points of S), gives +0.44 pp win chance and gains a place in about 1 race in 15.
  - The worst, −0.02, costs 1 point.
  - A typical tap edge is still about 7× the best trip.

**Smart Steer (auto)**
- On by default for everyone.
- It rides one lane off the rail and heads in before turns (about 8 s ahead), tucking in when blocked. It never seeks a draft and never moves out before the lock.
- Any manual input pauses it for 5 s. It then resumes, but never moves you outward, so a rider who took the rail keeps it.
- Settings: "Smart Steer" on (default) or off.
- The arrows are hidden for the first 3 races; then a ghost-thumb tip appears on the first straight: "Steer to the rail before the turn ◀".

**Controls**
- Phone: two big buttons bottom-left (◀ In toward the rail, Out ▶), at least 88 px, inside the thumb zone. The default touch thumbstick is off during races. Every other touch is still a slider tap.
- Keyboard: A or ← in, D or → out, taken out of "any key taps".
- Gamepad: D-pad left/right or a left-stick flick (fires past 0.6, re-arms below 0.3), taken out of "any button taps".
- Mouse: click the on-screen arrows.

**Server and latency**
- The server owns every lane.
- Clients send intents only (`SteerRequest(dir, seq)`). They are applied on the next 10 Hz server tick in arrival order, with ties going leader first, then the inside horse. Nothing is rewound.
- The rider's own glide is predicted and eased to the server state. Lag only delays your own move. Spam is rate-limited, and requests after the lock are ignored.
- A rider who disconnects goes to Smart Steer.
- Lateral positions go out with the gaps at 10 Hz until the lock (unreliable; a dropped packet is harmless).

**Bots and posts**
- Bots use Smart Steer with variety drawn from the race's random generator after all existing draws: lead time 4–12 s before turns, and 25% ride the rail.
- Posts are a random draw from the server's generator. Lanes are no longer humans first. Posts are never shown as a draw.

**Feedback**
- Small chips: "Saved ground!" at turn exits, "Tucked in!" with wind lines, and a soft lock bell.
- If you stay wide into a turn, a gentle tip ("The rail is shorter on turns ◀"), never "lost a place".
- Results: "Good trip ★★☆" under "You rode ★★☆" (★★★ at τ ≥ +0.015, ★★ at ≥ −0.005, ★ otherwise, never zero), and "Your trip gained you N places!" only when positive.

**Replays**
- Replays record each horse's lane per frame on this screen.
- Overlays show your line as a ribbon with green chevrons where you saved ground, wind lines while tucked in, and the lock marker. No ideal-line ghost.

**Python and parity**
- `live_chances` takes an optional extra exponent vector. A new `src/trip.py` mirrors `game/src/shared/Trip.luau` exactly.
- A calibration sim generates the post baseline table and checks the targets.
- See `plan.md`, stages S0–S4.

**Reversible:** `GameConfig.steering.enabled` turns lanes back to today's fixed lanes; `scale = 0` makes steering cosmetic; the clamp bounds and every constant are config.

## Minority view

- **Young player:** ground only at launch, no drafting credit. Revisit if kids can't say what "Tucked in!" did after five races.
- **Competitive:** raise the ceiling to 0.06 if kids can't tell what their trip did at 0.04.
- **Engagement:** wanted steering live through the far turn. Accepted the lock as long as Sprints keep their turn, which they do via the locked lane.
- **Child safety:** steering could stay live through the far turn only if far-turn clearance used skill-only positions. Not adopted because the screen would then disagree with the server.

## Decision

D-054, Accepted (provisional). Listed in REVIEW_QUEUE for David. Implementation plan and risks: `plan.md`, Steering stages S0–S4. Amends D-026 (steering inputs are no longer slider taps), D-033 (lane holds on screen before the far turn; τ in the exponent from the lock) and V2_PROPOSAL step 5.
