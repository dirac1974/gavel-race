# 012 — How should steering move like a real horse, what happens when a horse is boxed in, and should horses bump?

Date: 2026-10-05 · Status: Decided provisionally (D-057) · Moderated by Claude. The four designers ran as separate agents. They wrote independent openings from the moderator's brief, then one rebuttal round after reading each other and the moderator's prototype results.

Suggested repo path: `docs/debates/012-natural-steering.md`.

## Question and constraints

David, after D-054 shipped: "Let's make sure the steering looks natural, sort of like a real horse moving, you can't just make them zig zag back and forth over and over, so make the movements smooth and nothing crazy. Fit both players and bots. Also if neighboring horses are surrounding you won't be able to move left or right for example "boxed in". So consult with the game designer team on the best way to implement this. Maybe the press need collision bodies etc… if they bump a horse they should potentially slow down a little should be considered by the team."

**The questions:**
1. **Natural motion:** how a lane change should look and feel (speed, easing, body turn, lean, anti zig-zag, commitment, lanes in a row, glide time), the same for players, Smart Steer and bots.
2. **Boxed in:** the definition, what the rider sees, what happens to a press, whether tuck-back stays, and whether being boxed in costs anything (and how griefing is stopped).
3. **Bumping:** collision bodies or rules, who pays, how much, the visuals, bots, after the lock.
4. **Multiplayer and latency fairness.**
5. **Kid load:** an 8-year-old on a phone, one thumb on the slider, the other on the arrows.

**Today (code at `main` c6f76c7, read for this debate):**
- One press = one lane, a **linear** 0.6 s glide: 10 ft/s sideways, starting and stopping instantly. At most one change starts per 0.6 s, and one press can wait. A queued press in the opposite direction starts the moment the glide ends, so mashing ◀ ▶ makes the horse weave 3→2→3→2 every 0.6 s.
- `RaceView` places every horse with `CFrame.lookAt(pos, pos + tangent)`, so **a horse always faces straight down the track**. A lane change is a pure sideways slide at about 10° of drift, with no body turn. The client moves lanes at a constant rate, so a reversal flips the sideways speed in one frame.
- A lane change needs 8 ft clear ahead and 10 ft behind in the new lane. Blocked toward the rail, the horse tucks back up to 3 lengths and slots in behind (visual only, and it then earns draft credit). Blocked outward, the press waits 1 s and cancels. D-054 promised a small "no room" shake on that cancel; **it isn't built**.
- **Horses never touch.** Moves are refused or turned into tuck-backs. There are no collision bodies, and race horses aren't physics parts at all.
- **No boxed-in penalty** (debate 010, 4/4: strangers could box a kid in on purpose).
- The split horse models (D-051) are a Body (head and tail included) and four legs. **There is no separate head to turn.**

**Constraints:**
- Hard rules 1–3: no wagering; Diamonds never change win chance; kid safety (nothing punishes a kid for what they can't control, no griefing vectors, and horses never look hurt).
- D-054: τ is fixed at the lock and never depends on luck; the clamp is −0.02/+0.04; Smart Steer is the default.
- D-033: positions before the far turn come from skill only.
- D-012: `src/trip.py` and `Trip.luau` agree exactly.
- D-021: the server is authoritative.
- D-055: 0 overlaps, no backward jerks (> 20 ft/s on screen), the order across the line is the result.

## Facts (researcher and moderator, checked 2026-10-05)

**Real racing**
- **Gallop scale.** In races, speed fell from 17.3 to 16.0 m/s, stride frequency from 2.34 to 2.21 strides/s and stride length from 7.42 to 7.25 m between the first and second lap (Takahashi et al., *J Equine Vet Sci* 2021, PubMed 33993952). Our 56 ft/s ≈ 17 m/s, so one stride ≈ 0.43 s ≈ 24 ft. A one-lane move in 0.6 s is 1.4 strides; 0.8 s is 1.9; 1.0 s is 2.3.
- **A horse length** is about 8 ft; Equibase uses 8 ft 2 in ([Wikipedia](https://en.wikipedia.org/wiki/Horse_length)). Our `clearFeet` 8 is one length.
- **US model rule ARCI-010-035** ([PDF](https://rtip.arizona.edu/sites/rtip.arizona.edu/files/arci_010_035.pdf)):
  - E(2): a jockey shall not ride carelessly or willfully so as to let the mount "interfere with, impede or intimidate" any other horse, and shall not "jostle, strike or touch" another horse.
  - E(3)(a): "When the way is clear in a race, a horse may be ridden to any part of the course", but a horse that swerves or is ridden to either side so as to interfere commits a foul.
  - E(4)(a): the **offending** horse may be placed behind the horses it interfered with. The horse that moved pays.
- **Connecticut 12-574-A43** ([LII](https://www.law.cornell.edu/regulations/connecticut/Regs-Conn-State-Agencies-SS-12-574-A43)): "crossing or weaving in front of contender may result in disqualification"; a horse that crosses another "so as to impede" it, or jostles it, may be disqualified.
- **Australian Rule 131(a)** careless riding. A Racing NSW appeal (Bullock, 2020) upheld a charge that a rider let his mount "shift in ... when insufficiently clear" of another horse, which was checked and clipped heels ([PDF](https://www.racingnsw.com.au/wp-content/uploads/Reasons-for-Decisions-A-Bullock.pdf)).
- *Unconfirmed:* a fixed "clear by a length" crossing distance. The NZ wording ("its own length and one other clear length") came only from a search snippet, and the rule pages were blocked. US rules use "so as to impede", not a distance. Our 8 ft rule is a design choice in the same spirit.
- **Words** ([Woodbine glossary](https://woodbine.com/glossary/)):
  - BOXED IN: "surrounded by other horses in front, outside and behind it ... unable to gain a clear passage";
  - CHECKED: the jockey "has to slow or stop the motion of his horse due to close quarters or interference";
  - STEADIED: "taken in hand by his rider, usually because of being in close quarters." Our tuck-back is a steady.
- **Leads:** racehorses lead with the left leg round counter-clockwise turns and switch to the right lead on the straights ([Wikipedia](https://en.wikipedia.org/wiki/Lead_(leg))).
- *Unconfirmed:* no published sideways speed or body angle for a racehorse changing paths. Tracking systems record lateral position (TurfTrax: ±64 cm laterally at 4 Hz, per the RVC repository abstract), but we found no published lateral speeds. **Our motion limits are therefore design values.** We bounded them by geometry: on our turns (radius 417 ft at 56 ft/s) a horse feels 7.5 ft/s² sideways, and a lane change at 27 ft/s² follows a curve of about 115 ft radius for a quarter of a second.

**Roblox**
- [Network ownership](https://create.roblox.com/docs/physics/network-ownership): parts near a player tend to become client-owned, and client-owned parts can be exploited ("teleporting the BasePart ... go through walls"). `Touched` can fire without real contact. Server-owned physics would delay the player's own horse by a round trip. Physics contact is also not repeatable, so it can't be mirrored in Python (D-012).

**Moderator's prototype** (scratch copy of `src/trip.py` with every new rule behind a switch; with the default config it reproduces `trip.py` exactly, 200/200 races; scripts and tables in the session scratchpad, `prototype/`). All 8 course × distance cells, Trip's server state at 10 Hz, before the lock.

- **E1, motion and zig-zag** (80 races per cell; a focal rider among 7 bots). Masher = 4 presses a second on a random side; ditherer = In, Out, In, Out every 0.2 s.

  | Variant | One lane | Masher reversals/min (shortest gap) | Ditherer reversals/min (shortest gap) | Top sideways speed, drift | Sideways accel p95 / max |
  | --- | --- | --- | --- | --- | --- |
  | D-054 as built (linear 0.6 s) | 0.6 s | 29.3 (0.6 s) | 74 (0.6 s) | 10 ft/s, 10.1° | 125 / 200 ft/s² (instant) |
  | Eased 1.0 s, no rules | 1.0 s | 19.3 (1.0 s) | 42 (1.0 s) | 9 ft/s, 9.1° | 25 / 28 |
  | Eased 0.8 s, chain, 0.4 s reverse gap | 0.8 s | 15.3 (1.2 s) | 30 (1.3 s) | 10 ft/s, 10.1° | 35 / 37 |
  | Eased 1.1 s, chain, 0.8 s reverse gap | 1.1 s | 9.6 (1.9 s) | 21 (1.9 s) | 8.1 ft/s, 8.2° | 15 / 20 |
  | Eased 1.0 s, chain, 0.5 s gap + weave gap | 1.0 s | 7.1 (3.5 s) | 12.1 (3.5 s) | 9 ft/s, 9.1° | 25 / 30 |
  | Eased 0.8 s, chain, 0.4 s gap + weave gap | 0.8 s | 7.8 (3.3 s) | 12.9 (3.3 s) | 10 ft/s, 10.1° | 35 / 37 |

  - "Eased" is an S-curve: sideways speed builds up and brakes at a fixed rate and is capped. The 1.0 s version tops out at 9 ft/s (1.5 lanes/s) with 27 ft/s² (4.5 lanes/s²).
  - The **weave gap**: a second reversal within 5 s of the last waits 2.5 s after landing.
  - Chained presses in the same direction take 1.6 s for two lanes, 2.3 s for three and 3.0 s for four (today 1.2, 1.8 and 2.4).
  - Casual riders reverse about 1.3 times a minute in every variant.
  - A reverse gap alone still lets a masher sway every 1.5–1.9 s. The weave gap is what ends the weaving.
- **E1b, overlaps** (4,000 races per variant, three riders pressing at once): 0 overlaps and no horse falling back faster than 19 ft/s for D-054, eased 1.0 s + weave and eased 0.8 s + weave. Eased 1.0 s without the weave gap overlapped once: two horses converged on one lane from both sides while the front one was itself held. A **glide reserve** (a horse gliding into a lane keeps 6 ft more room ahead and behind) closes that.
- **E2, boxed in** (eased 1.0 s + weave; one horse at each post among 7 bots). Boxed = a horse within 12 ft ahead in your lane, AND no room inside (the rail, or a horse in the 8 ft-ahead/10 ft-behind zone), AND no room outside.
  - Share of pre-lock time boxed: Smart Steer kid 5.5% (21% of races have at least 1 s; by post 1, 2, 9, 9, 8, 6, 5, 4%); rail rider 49% (on the rail behind a horse with one outside, which is where it wants to be); never-steer 0.4%; casual 32%; bots 12%.
  - "Trapped" (boxed with no slot within the 3-length tuck reach): about 1% of the time for a Smart Steer kid, 0% for a rail rider.
  - 59–66% of casual inward presses meet a blocked lane, and tuck-back resolves most of them within a second or two.
  - **Without tuck-back** (presses only wait for a gap): rail riders reach their lane within 3 s 4% of the time (93% with tuck-back), and Smart Steer kids end 2.3–3.8 lanes out by post instead of 2.0. Steering stops working.
  - **Dropping a waiting inward press hurts.** A follow-up sweep (150 races per cell, after the rebuttals) dropped an inward press that can't tuck back after 3 s. Casual reach in dirt Miles fell from 69% to 54%, and the kid presses again. Keeping it until room, as D-054 does, restores it. Outward presses can safely drop after 1.5 s.
  - **Reach per press vs per intent** (casual rider, eased 1.0 s, inward waits until room):
    - per press (D-054's metric): 64–96% by cell (D-054 as built: 80–100%). The slower glide and the reverse gaps cost 10–18 points in the Miles and Marathons.
    - per intent (no press by that rider in the 3 s before): 75–100% in every cell.
- **E3, brushes** (60 races per cell). A brush never replaces a tuck-back the press could start, and the blocker must have been alongside for 0.3 s.
  - "Any press at a horse alongside" (0.002, first free, cap 3): casual riders brush in 72% of races, 51% charged.
  - "A second press while the first still waits" (0.002, first free, cap 3), as shown to the panel: casual 6.2% of races brush, 3.3% charged, mean cost 0.0001; wanderer 38% / 15%; rail rider 0; masher 84% / 68%, mean 0.0034; ditherer 0. At Engagement's price (0.005, cap 2) casual riders were charged in 6.2% of races and mashers paid 0.0076.
  - **After the rebuttals**, inward presses keep waiting for room (see E2). That gives a re-press many seconds later the chance to count as "insisting": casual riders were then charged in 6.5% of races (up to 10.7% in dirt Marathons).
    - **Requiring the second press within 2 s of the first** brings it back to 1.9% of races with a brush and 0.4% charged (at most 0.7% per cell), mean cost under 0.0001.
    - Wanderer 35% / 13.5% (mean 0.0004); masher 80% / 64% (mean 0.0032); rail rider and ditherer 0.
  - No brush ever caused an overlap.
- **E4, griefing.** Worst case: the strangers tapped exactly like the kid, so they sit right beside it. Kid's own trip (ground + draft) against the same strangers riding plain Smart Steer at that pace:

  | Strangers | With tuck-back: Smart Steer kid / rail kid | Without tuck-back |
  | --- | --- | --- |
  | Shadow (sits on the kid's inside) | −0.0012 / +0.0003 | −0.006 (p5 −0.04) |
  | Crew of 3 (inside, outside, ahead) | +0.0011 / −0.0001 | −0.009 (p5 −0.055) |
  | Bumper (gets beside the kid, keeps pressing into it) | −0.0005 / −0.0003 | −0.015 (p5 −0.062) |
  | Untargeted control: the same strangers just riding for the rail | 1 stranger −0.0013; 3 strangers −0.0020 | |

  - With tuck-back, targeting a kid hurts the kid no more than the same players simply riding well. The kid's τ does dip 0.002–0.005, but all of that comes from the field mean (the strangers' own good trips). Three untargeted rail riders do more (−0.009).
  - Rerun on the final rules (inward presses wait for room, brushes with the 2 s window): shadow −0.0011 / +0.0003, crew +0.0011 / −0.0001, bumper −0.0007 / −0.0004. With mover-pays the kid is charged 0. Even with bumped-pays the kid was never brushed by the bumper, because a steering kid doesn't stay alongside: Smart Steer's tuck-back drops it behind, and a stranger can't follow backwards. The bumper's brushes landed on other horses, and it paid for them.
  - **Who pays a brush** (a bumper against a Smart Steer kid):
    - mover pays: the kid is charged 0, the bumper about 3.8 bumps a race (it hits the cap);
    - bumped pays: the kid is charged 1.2 a race, own trip −0.0026, below −0.005 in 30% of races;
    - both pay: the kid is charged 0.2 a race (from its own presses);
    - nobody pays: nothing changes.
- **E5, the D-054 acceptance targets** with regenerated baselines: see the Recommendation (Targets).

## Openings (summaries of the independent statements)

### Engagement
- "The gap opened!" is the story kids tell.
- Motion: a 0.9 s S-curve peaking at 10 ft/s, body yaw up to 10°, lean 3°, no reversing mid-glide, a 0.5 s reverse gap, chains of up to two lanes.
- Boxed in: a horse within a length alongside in the target lane dims that arrow amber, and a chip says "Wait for a gap". The press stays armed 1.5 s and fires on a gap ("Gap!" with `tap_good`). Tuck-back stays automatic. No cost beyond missing the rail.
- Bumping: no physics bodies ("ramming is what players complain about most"). Pressing again while boxed plays a shoulder brush. The mover pays −0.005, capped at −0.01; the bumped horse pays nothing.
- Latency: an instant head-turn; the glide starts on the server's answer.

### Competitive
- Motion: one glide for everyone, run on the server: a 1.0 s smoothstep (9 ft/s, 9°), body yaw capped at 8°, 0.8 s of settled running before a reversal, chained lanes +0.7 s each.
- Boxed in: the target lane's clear zone is taken. The arrow dims and the promised shake plays. The press waits 1.5 s, and inward presses still tuck back. No extra cost: griefing is floored at −0.02 anyway, and "nobody can hold station beside you".
- Bumping: rule-based, never physics (exploitable, breaks parity). Pressing at a horse directly alongside brushes it and steadies the mover by 4 ft. The mover pays −0.002, first one free, capped at −0.006, inside the clamp and fixed at the lock.
- Latency: the server reserves both lanes during a glide. The ease-in hides 150 ms (6% of a lane).

### Child safety
- Motion: a 1.0 s S-curve, body yaw capped at 8°, lean ≤ 3°, a 0.4 s reverse gap.
- Boxed in: every side blocked for 1 s. An ear flick and one calm chip, "No room yet". The press waits 1.5 s and quietly drops, with no shake, buzz or red. Tuck-back stays ("the way out").
- **No boxed-in cost:** "David asked for the feel, not a fine". A penalty would let strangers and friend groups use their horses as weapons.
- Bumping: no physics. A brush only if a gap closes mid-glide. Only the mover pays, and the score cost is 0 (at most −0.005 once as a compromise). Both horses do a head-bob with a soft wooden tock and never stumble or flinch. Bots never start brushes.
- Latency: if the server is unsure, it refuses and never charges.

### Young player
- Motion: a 0.9 s S-curve (two strides), a press shows within one frame, the head turns at once, and the body turns at twice the drift (cap 15°) so a kid can see the direction. A 0.4 s settle before reversing, and the latest press wins: "mashing ◀▶◀▶ becomes a slow sway, not a wiggle".
- Boxed in: "a horse is right beside you on that side". The button turns grey with a small horse picture, so no reading. A press there gets a soft thud and the promised shake, is kept 1.5 s, and fires on a gap. Tuck-back stays, ending on "Tucked in!" so dropping back looks clever.
- **Bumping: no.** "An 8-year-old loves bumping other horses and cries when bumped."
- Latency: show only the head turn before the server answers, never a slide that snaps back.

## Rebuttals

All four moved after reading each other and the prototype.
- **The weave gap, 4/4.** Every designer adopted it: it, not the glide time, is what ends zig-zag (a masher reverses 7.1–7.8 times a minute with it, against 9.6 at Competitive's 1.1 s glide without it).
  - Competitive dropped its 0.8 s reverse gap for 0.5 s plus the weave gap. Young player kept 0.4 s.
  - Young player: "Mashers won't understand 'settle', but they know cooldown rings": the arrow refills during the wait.
- **Glide time, split 2–2.**
  - **0.8 s:** Engagement ("the glide can stay quick") and Young player ("use the glide for responsiveness").
  - **1.0 s:** Competitive (0.8 s "if re-presses exceed 20%") and Child safety.
- **Body:**
  - Engagement and Competitive: yaw 1.5× the drift, capped at 12°.
  - Child safety and Young player: the true drift, capped at 10°.
  - All four: lean 3° and an instant head turn (Young player up to 12°, Child safety 15°).
  - Young player gave up twice the drift: "kids read the head".
- **Boxed in, per arrow, 4/4.**
  - Child safety gave up "every side blocked for 1 s": a rail rider would see it 49% of the time.
  - **Young player's refinement:** the inward arrow greys only when tuck-back can't help (trapped, about 1% of the time). "Greying a button that works teaches kids not to press it." The outward arrow greys while that side has no room.
  - Chips:
    - Engagement: "No room yet" after a press waits 0.5 s, at most once per 10 s, and "Gap!" when an armed press fires.
    - Competitive: only after a refused press.
    - Child safety: "Wait for a gap", at most once per 2 s, with a 0.2 s button wobble.
- **Presses, 4/4:** inward presses tuck back at once, automatically. Outward presses wait 1.5 s, then drop. "Wait-only kills steering (4%/19%) and invites griefing" (Young player). Tuck-back is "mandatory" (Child safety).
- **No boxed-in cost, 4/4.** Child safety: "My test passed (targeting a kid hurts no more than strangers simply riding well). But a cost would mostly hit rail riders, who are making the right play, and posts 3–4, which is luck."
- **Brushes, 4/4 on the rule:**
  - Trigger: a second press while the first waits (Engagement's trigger).
  - Mover pays only, at Competitive's price: 0.002, first one free.
  - Cap: three charged (Engagement, Competitive, Young player) or two (Child safety, −0.004).
  - Competitive dropped "any press" (51% of casual races charged: "a tax on ordinary steering").
  - Young player accepted brushes at that price: "casual kids get charged in 3% of races; mashers pay."
  - Child safety added that presses within 0.2 s of each other count as one.
  - Visuals: the mover leans ≤ 1 ft, bobs its head and steadies 4 ft, with a soft wooden tock. The bumped horse only flicks an ear, and gets no chip and no name. No stumble, pinned ears or squeal. Bots never brush.
- **Latency, 4/4:** only the head turns until the server answers, and the slide starts on its answer. Young player: Child safety's 0.3 s glide-back "is exactly the snap-back I want gone."
- **The within-3 s target, 4/4:** count once per press intent, and never lower the bar to pass. Engagement: if it still misses, cut the glide to 0.7 s.

## Options

| Option | For | Against | Panel support |
| --- | --- | --- | --- |
| **Natural motion** | | | |
| A1. Eased S-curve glide on the server, chain, reverse gap + weave gap, glide reserve (chosen) | Smooth starts and stops (accel ≤ 30 ft/s² vs instant); weaving ends; same rules for every horse; 0 overlaps | Slower: one lane 1.0 s vs 0.6 s | 4/4 (glide time split) |
| A2. Keep the linear glide, add only a reverse gap | Smallest change | Instant starts and reversals (100–200 ft/s²); still sways every 1.1 s | 0/4 |
| A3. Refuse opposite presses during a glide | Fewest reversals (ditherer 2.5/min) | A press that does nothing; kids learn the button lies | 0/4 |
| A4. Client-only smoothing | No server change | Screen and server disagree about where a horse is; breaks clearance and overlap guarantees | 0/4 |
| **Boxed in** | | | |
| B1. Per-arrow "no room"; tuck-back stays automatic; presses wait for a gap; no cost (chosen) | David's "can't move left or right"; escape stays real (jockeys steady and slip in); no griefing gain (E4) | A new button state to learn | 4/4 |
| B2. Wait for a gap only, no tuck-back | Most literal "can't move" | Steering stops working (4% reach); strangers can hold a kid wide (−0.015, p5 −0.06) | 0/4 |
| B3. A boxed-in τ penalty | Real-racing drama | Hits rail riders making the right play and unlucky posts; a griefing tool | 0/4 (again) |
| **Bumping** | | | |
| C1. Rule-based brush on a second press within 2 s, mover pays 0.002 after one free, capped (chosen) | Answers David; mover pays as in real racing (ARCI E(4)); casual kids charged in 0.4% of races; griefers pay, kids don't | One more rule; a small cost a masher feels | 4/4 on the rule (cap split 3 vs 2) |
| C2. Brush on any press at a horse alongside | Simplest trigger | Charges 51% of casual races | 0/4 after rebuttals |
| C3. Bumped horse pays (or both) | Physically "realistic" | A kid's score would depend on a stranger's presses (with an any-press trigger the kid was charged 1.2 bumps a race) | 0/4 |
| C4. Roblox physics collision bodies | "Real" contact | Exploitable client-owned parts, lag on your own horse, no Python/Luau parity, overlaps and jerks back | 0/4 |
| C5. No bumping at all | Simplest; no kid ever "bumped" | Doesn't answer David; a refused press has no physical feel | 1/4 opening (Young player), 0/4 after rebuttals |

## Recommendation (D-057)

**Natural motion (players, Smart Steer and bots, all on the server)**
- **The glide is an S-curve.** Sideways speed builds up at 4.5 lanes/s² (27 ft/s²), caps at 1.5 lanes/s (9 ft/s, a 9° drift), and brakes at the same rate. One lane takes 1.0 s from press to arrival, about 2.3 strides.
- **Chaining.** A second press the same way continues the glide without stopping, so two lanes take 1.6 s, three 2.3 s and four 3.0 s. One press can wait; an opposite press cancels a waiting one (as today).
- **Commitment.** A glide always finishes; nothing reverses mid-glide.
- **Reverse gap 0.5 s** after landing before a change the other way.
- **Weave gap 2.5 s:** a second reversal within 5 s of the last one waits this long. "Changed my mind" once is fine; weaving isn't possible.
- **Presses within 0.2 s count once** (motor noise, like D-055's bounce taps).
- **Glide reserve:** a horse gliding into a lane keeps 6 ft more room ahead and behind, so two horses never converge on one lane.
- **The same motion everywhere:** Trip moves every horse this way, and the cosmetic make-room lanes after the lock use the same curve.
- **The body:**
  - It turns with its true drift (≤ 9° at full sideways speed, capped at 10°), smoothed over 0.15 s.
  - It leans into the move by at most 3°.
  - On a press it "looks" first: a 3° turn toward the press at once, before the slide. This stands in for a head turn, because the models have no separate head. A head split for a 12° head turn is an art follow-up, behind its own config switch.
  - The chase camera keeps following the track, so a body turn never swings the rider's view.
- **Latency:** the slide starts when the server's lane arrives. The S-curve covers only 0.05 lane in its first 0.15 s, so nothing visible is lost. SteerPredict's sideways draw goes (no snap-backs); the look cue is the instant answer.

**Boxed in**
- **No room on a side** means the rail or outer edge, or a horse in that lane's clear zone: 8 ft ahead to 10 ft behind, plus the 6 ft reserve if it is gliding in. This is Trip's existing rule.
- **Boxed in** means no room on either side and a horse within 12 ft ahead in your lane.
- **The arrows:**
  - **Out ▶ greys**, with a small horse icon, while that side has no room.
  - **◀ In greys only when it can't do anything now:** no room inside, and no slot within the 3-length tuck reach (trapped, about 1% of the time).
  - A grey arrow still takes a press. No buzz, no red.
- **A press:**
  - Inward with room: it glides. Inward without room: the horse steadies back (tuck-back, automatic, up to 3 lengths, as today) and slips in behind, then "Tucked in!" as today.
  - Inward and trapped: the press keeps waiting for a gap or a tuck slot, as in D-054 (dropping it after 3 s cut reach to 54% in the dirt Miles). A press Out cancels it.
  - Outward without room: it waits up to 1.5 s, then drops with a soft 0.2 s wobble of the arrow, with no sound. This is D-054's promised "no room" shake, finally built; none under Reduced Motion. All four asked for a wobble in some form.
  - A waiting press shows a ring on its arrow, so a masher sees "wait": lit while an inward press waits, filling over 1.5 s for an outward one.
  - The panel had said 1.5 s both ways. The moderator kept D-054's inward wait after the follow-up sweep. The rebuttals' common aim was a press that works: 4/4 said never lower the reach target.
- **Chips** (riders with buttons only; at most one steering chip every 2 s):
  - **"No room yet"** when a press has waited 1 s with nothing happening (no glide, no tuck-back); at most once per 10 s.
  - **"Gap!"** with `tap_good` when a press that waited at least 0.5 s fires.
- **No boxed-in cost** (4/4). Being boxed costs only what it naturally costs: you can't reach the rail until you steady back. With tuck-back, targeting a kid gains a stranger nothing (E4).

**Brushes (rule-based contact in Trip; no physics bodies)**
- **When:** a second press toward a horse alongside (within 8 ft lengthwise in the next lane, and alongside for at least 0.3 s), within 2 s of the first press, while the first press is still waiting, and only when no tuck-back is possible. A first press is never a brush. A press many seconds later is a new try, not insisting; without the 2 s window, casual riders were charged in 6.5% of races.
- **What happens (all visual except the cost):**
  - The mover leans at most 1 ft toward the other horse over 0.4 s and nods.
  - It steadies back 4 ft (in Trip's offsets, eased back at 2 ft/s) and can't steer for 1 s. Its waiting press clears.
  - The other horse gives a small nod only. It doesn't slow, gets no chip and never sees a name.
  - Both keep striding: no stumble, no pinned ears, no squeal.
  - Sound: `count_tick` (the soft wooden tick) at half volume.
- **Who pays: the mover only**, as in real racing (ARCI-010-035 E(4)). Bumped-pays and both-pay are griefing vectors (E4).
- **Cost:**
  - 0.002 τ per brush after the first free one, at most 3 charged (0.006 = 0.3 points of S);
  - its own term, subtracted after the field mean, inside the clamp, fixed at the lock;
  - at most 4 brushes a race (1 free + 3), after which presses just wait.
- **Who brushes:** Smart Steer and bots never brush (they never press twice). Nobody brushes after the lock: lanes are cosmetic there, and the make-room rules never touch.
- **At the gate:** a rider who presses twice into the horse in the next stall can brush from 0.3 s after the bell. That is real racing's most common bump ("bumped at the start"), and the first one is free.

**Server and latency**
- The server owns lanes, the no-room state, brushes and costs.
- The client's grey arrows and rings come from the 10 Hz lanes and the rider's own `SteerLane` state. They are advice; the server decides.
- A lag artefact can't cost a kid: the 0.3 s alongside rule plus "never on a first press" mean a brush only follows a press the rider made after seeing the grey arrow.
- The overlap and jerk guarantees hold (E1b). `overlap_report` gains the masher and ditherer, a zig-zag count and a sideways-acceleration check.

**Targets** (sims, every course × distance; moderator's prototype with regenerated baselines, 1,000 baseline races per cell and post, 300 report races per cell)

| Target | D-054 as built (prototype rerun) | D-057 |
| --- | --- | --- |
| Rail rider vs Smart Steer, +0.01 to +0.03 | +0.017 to +0.026 | +0.017 to +0.026 |
| Never-steer, −0.02 to −0.01 | −0.014 to −0.016 | −0.014 to −0.016 |
| Draft share of the positive trip, ≤ 40% | 19–36% | 20–36% |
| Post bias, < 0.005 (kid among bots; all-Smart) | ≤ 0.0022 | ≤ 0.0022 |
| Smart Steer kid among bots, 0 ± 0.003 | −0.0010 to +0.0008 | −0.0009 to +0.0005 |
| Inward press reaching its lane within 3 s, **per press** (D-054's metric, ≥ 70%) | 80–99.5% | 64–96%: misses dirt Mile (69%) and dirt Marathon (64%). **Replaced** |
| **Replacement:** the same, **per intent** (no press by that rider in the 3 s before), ≥ 70% in every cell | 80–100% | 74–100% (150 races per cell, final rules) |
| New: masher reversals ≤ 8 a minute, none within 3 s of the previous | 29.3 a minute, 0.6 s apart | 7.1, 3.5 s apart |
| New: sideways acceleration ≤ 30 ft/s² between 10 Hz ticks (every horse) | 200 (instant) | 30 |
| New: casual riders charged for a brush in ≤ 5% of races; Smart Steer and bots never brush | — | 0.4% (≤ 0.7% per cell) |
| New: griefing, targeted minus untargeted own trip ≥ −0.001 (shadow, crew, bumper) | — | −0.0005 to +0.0031 |
| New: 0 overlaps and no fall-back over 20 ft/s (4,000 stress races, three riders pressing) | 0; 19.0 ft/s | 0; 19.0 ft/s |

- Why the per-press figure drops: the slower glide and the reverse gaps make some presses take longer than 3 s in jammed Miles and Marathons. Kids also press again, and each re-press counts.
- Per intent, the bar stays at 70% and is met everywhere (the panel, 4/4: "never lower the target"). The per-press figure stays in the report so drift shows.

**Reversible:** every value is in `GameConfig.steering`.
- `glide = "linear"` restores D-054's 0.6 s glide.
- `weaveGapSeconds = 0` and `reverseGapSeconds = 0` remove the anti-zig-zag rules.
- `brush = "off"` removes brushes; `brushCost = 0` keeps them visual only.
- `blockedPress = "d054"` restores today's press handling.
- `steerHud.greyArrows = false` removes the new button states.

## Minority view

- **Engagement and Young player: 0.8 s glide** (peak 10 ft/s, 37 ft/s²), "use the glide for responsiveness". It passes every target too (E5: rail vs Smart +0.017 to +0.026, never-steer −0.014 to −0.016, post bias ≤ 0.0021, per-intent reach 76–100%), with weaving as low as at 1.0 s (7.8 reversals a minute). Adopted as the playtest switch: go to 0.8 s if more than 20% of glides get a second press in the same direction before they land (Competitive's and Engagement's line), or if kids can tell 0.8 s from 1.0 s in a blind test and prefer it (Young player).
- **Engagement and Competitive: body yaw 1.5× the drift, capped at 12°.** The moderator kept the true drift, because a horse drawn turning more than it moves reads as skidding. Revisit if playtesters can't tell which way a horse is moving in the chase view.
- **Child safety: brush cap two charged (−0.004)**, and brushes become visual only (`brushCost = 0`) if more than 1 in 10 bumped kids get upset even at zero cost.
- **Young player (opening): no bumping at all.** Accepted brushes at the mover-only, first-free price; the playtest line is "kids who get bumped stay as happy as the kids doing the bumping".
- **Engagement: chip "No room yet" after 0.5 s** (the moderator chose 1 s, so tuck-backs that start a beat late don't flash it).
- **Child safety: the chip says "Wait for a gap"**, shown at most once per 2 s. The moderator chose Engagement's, Competitive's and Young player's "No room yet", at most once per 10 s, because 1-second waits run 0.4–2.7 a race.

## Decision

D-057, Accepted (provisional). Listed in REVIEW_QUEUE for David. Implementation plan and risks: `plan.md`, stages N1–N6. Amends D-054: the glide shape and timing, boxed-in press handling and the brush term in τ. D-054's promised outward "no room" shake is built as a soft 0.2 s wobble when an outward press drops.
