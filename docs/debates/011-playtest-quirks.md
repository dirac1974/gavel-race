# 011 — Which of the play-test quirks are design calls, and how should each one feel?

Date: 2026-10-05 · Status: Decided provisionally (D-055, D-056) · Moderated by Claude. Short round: the four designers ran as separate agents and wrote independent openings from the moderator's fact sheet; no rebuttal round (no two voices conflicted hard enough to need one), so the synthesis settles the splits and keeps the minority views.

## Question and constraints

David, after his play-test: "the behavior still had some quirks, review with the game design team". Two QA engineers then audited the race and the riding world with Lune simulations (race: 16 findings; riding and world: 14). The tech lead is fixing the pure bugs. This round decides only the calls that change how the game feels:

- **Race:**
  - (a) bounce taps;
  - (b) a 3-2-1 countdown;
  - (c) "Miss" flashes;
  - (d) spectator range and what far-away players get;
  - (e) the running-order board in-race;
  - (f) which keys tap.
- **Riding and world:**
  - (g) a phone hop button;
  - (h) leg gaits;
  - (i) where the 💎 button goes;
  - (j) CLAP and cheer bar placement;
  - (k) the stall while your horse is out.
- (l) Anything else in the reports that is a design call, plus a kid's-eye priority order.

**Constraints:**
- Hard rules 1–3: no wagering; Diamonds never touch win chance; kid safety, including no purchase prompts during or right after a race and no fake urgency.
- Accepted decisions:
  - D-026: one tap per pass; two taps zero the pass.
  - D-030/D-032: David asked for the in-race board; OPEN_QUESTIONS #1 is still open.
  - D-033: never a percentage.
  - D-019: spectators see chances only after cheers lock.
  - D-050: the shop opens only by a tap; no Diamond prompts in line, racing, on results or for 2 min after.
  - D-051: legs.
  - D-052: 250-stud hearing range.
  - D-053: training rides have no failure states.
  - D-054: steering keys and the lane-lock bell ticks.

## Facts (moderator, from the QA reports, the code at `main` e4d37c5, and the moderator's own sims)

Screens: most players are on phones in landscape (844×390 and 667×375 are typical). Roblox's touch controls put the DynamicThumbstick start zone in the left 40% × bottom two-thirds of the screen and the jump button bottom-right (70 px at (1,−95,1,−90) on screens ≤ 500 px tall). These numbers come from the PlayerModule, as QA measured them in `sim_ui`. Roblox's cross-platform guide puts frequent buttons within thumb reach of those corners (sources in debate 010).

- **(a) Bounce taps.**
  - A pass with two taps scores 0 today (`PaceMeter.score`).
  - Moderator's sim (`sim_debounce.py`, 300 races per league): a kid with a 70 ms timing spread taps 85% of passes, and 15% of taps are followed by a bounce 40–140 ms later. That kid scores:

    | League | Today | Bounce within 150 ms ignored | No bounces at all |
    | --- | --- | --- | --- |
    | Rookie | 66.2 | 77.5 | 77.0 |
    | Champion | 56.6 | 66.4 | 66.8 |

  - The rule is "ignore a tap within 150 ms of the last counted tap", in any pass. Mashers at 4–12.5 Hz still score 0.1–0.3 in Rookie to Gold. The worst case is Champion at ~7 Hz: 4.2 (today 0.1).
  - A fixed-interval clicker already scores 59 (D-026), so the rule opens nothing new.
  - Measuring from the *last* tap instead would let a fast masher keep only its first tap per pass, so the clock must run from the counted tap.
- **(b) Countdown.**
  - The server waits `COUNTDOWN = 3` s between RaceStarted and the gate (`RaceService.server.luau:40,509`).
  - Riders are seated in the stall, and the camera pops into the saddle 1 s before the start (`RaceController.client.luau:623`). The first slider pass starts at the bell, and nothing on screen counts down.
  - D-054 will later use three soft bell ticks for the lane lock. D-053's Gate Break uses a random bell because it is a reaction test; races have no reaction scoring.
- **(c) "Miss".**
  - Every pass that ends with no tap shows "Miss" (word plus flat-dash icon) at mid-screen. That is every 1.2 s in Rookie and every 0.55 s in Champion while a kid looks away (`RaceController.client.luau:526`).
  - A tap scoring under 30 is also labelled "Miss".
  - The speed meter (mean of the last 5 passes) already dips.
- **(d) Range.** Distances from the dirt course's outer edge:

  | Place | Studs from the course |
  | --- | --- |
  | Grandstand and tunnel | < 140 |
  | Training Ground (D-053), west end | ~150 |
  | Race Board | ~190 |
  | Fair Street plaza | ~200 |
  | Training Paddock | ~260 |
  | Feed & Seed | ~290 |
  | Vet | ~400 |
  | Barns | ~720 |
  | Meadow | ~1,200 |

  - Two courses race at once, so a race starts every 1–2 minutes.
  - D-041 already gives far-away players the Race Board on Fair Street.
- **(e) Board.**
  - The board is 300×218 px, top-left: 56% of an 844×390 phone's height. Before the tech lead's fix it covered 36% of the burst bar.
  - Its rows show place, name, YOU, **live win chance % and purse** to riders and spectators alike (`renderBoard`). That breaks D-019 (chances only after cheers lock) and D-033 (never a percentage).
  - Child safety found that the rider's status line also prints "Win chance: 62% (+5)" at every update (`RaceController.client.luau:736`).
- **(f) Keys.**
  - Every key taps today: W, the arrows and I/O give passes two taps, and stray keys burn the Final Burst.
  - Other bindings in the game:
    - C claps for spectators;
    - E and gamepad X are the Roblox ProximityPrompt defaults, used by care, shop and wild-horse prompts;
    - Shift gallops while riding;
    - D-054 claims A/D/←/→ and the D-pad.
- **(g) Hop.**
  - Mounting disables Jumping, so Roblox hides its jump button. The dock's Ride/Get off button then covers 60–74% of that spot (667–844 px phones), so a kid who taps "jump" is thrown off.
  - Gallop is 130×60 at (1,−24,1,−210), y 120–180 on a 390 px phone.
- **(h) Legs** (`sim_gait_feel.luau`, using QA's tool):
  - The leg is 2.45 studs hip to hoof.
  - Today:
    - walk 9/18° at the 16 studs/s riding speed: 73% of each planted step slides, 1.8 Hz;
    - gallop 22/36°: 77% slide, 2.1 Hz riding, 2.5 Hz racing.
  - QA's walk 5/24° at 16 studs/s: 30% slide but **3.2 Hz**. QA's trot 7/30° at 30: 4.3 Hz.
  - Trot 7/30° *at* 16 studs/s: 38% slide, **2.3 Hz**. Walk 5/24° kept below 12 studs/s: 1.2–2.0 Hz.
  - Gallop 18/40°: 69% slide, 2.6 Hz riding, 3.1 Hz racing.
  - Real horses: walk ~1 Hz, trot ~1.5 Hz, gallop ~2.2–2.5 Hz. 16 studs/s is a real horse's trotting speed.
  - Today's bob lifts 0.45 studs: all hooves are off the ground in 72% of gallop frames, and the rider sinks into the back.
- **(i) 💎 button.**
  - It is 100% inside the thumbstick zone on every phone *and* on iPad; the My Horses card is 58–60% inside.
  - The dock, and with it the 💎 button, comes back the moment a race ends (`Hud.client.luau:254`), so the button is on screen while the server refuses Diamond prompts.
  - The shop closes itself only while the `Racing` attribute is set (`StyleShop.client.luau:284`); nothing on the client covers the results card or the 2-minute window.
- **(j) Cheering.**
  - CLAP (170×90 at (1,−24,1,−230)) covers 67% of Gallop.
  - The cheer bar (640×96) sits at y 126–222 of a 390 px phone (mid-screen) for every race everywhere. It shrinks to a 40 px "Your horse" strip after you cheer.
- **(k) Stall.** The ridden horse also stands in its stall, and so does a racing horse.
- **(l) Moderator's candidates:**
  - **Logs and cones.** QA's "make the Paddock log jumps collide" conflicts with D-053 (no refusals, knocked poles just don't count). The new shins collider would make the paddock's 2.4-stud weave cones into solid stoppers.
  - **Gamepad gallop.** QA suggests ButtonX, which is the ProximityPrompt default, and D-053 already chose R2.
  - **Taming.** "💖 Friends!" shows before the server agrees.

## Openings (summaries of the independent statements, ≤ 300 words each)

### Engagement
- **a** Adopt 150 ms, measured from the counted tap: "a finger bounce shouldn't wipe out a good tap."
- **b** Centred "3 · 2 · 1 · GO!" with wood-clack ticks, plus a dim non-scoring warm-up sweep so kids find the rhythm before pass 1.
- **c** No word on an untapped pass (the marker greys). "Early"/"Late" for a tap under 30. Riders who miss the burst see "Burst's gone, finish strong!"; spectators see nothing.
- **d** 250 studs; the Big Board covers everyone else.
- **e** Hide the board for riders. Spectators get a small board: top 4 + their rider, place, name, star. Drop % and purse: together they read as a tote board.
- **f** Only Space, Enter, mouse, touch and A/R2 tap. W or an arrow shows "Tap SPACE!" once.
- **g** 70 px Hop at the jump spot; the dock shifts left.
- **h** Trot 7/30° at 16, walk 5/24° below 12, gallop 18/40°, bob 0.15. "Kids who love horses notice gaits."
- **i** 48 px 💎 top-right on touch, hidden in races. The horse card isn't tappable: "a store that opens by accident looks like a trap to parents."
- **j** CLAP to (1,−170,1,−230). Cheer bar 64 px at top centre, in range only.
- **k** A plaque: "Comet is out riding" / "Comet is racing!" A blank stall reads as "my horse ran away".
- **l** Agrees with all five candidates. Logs become trigger zones with an **auto-hop**. "Friends!" only on the server's reply, with a heart filling while it waits.
- **Top 5:** race #1, riding #2, riding #1, race #5, riding #10.

### Competitive
- **a** Adopt, server-authoritative with Luau/Python parity, across pass boundaries; the first tap counts. **No exploit opens:**
  - mashing stays ≤ 4.2;
  - a hedging double tap gains nothing because the first tap counts;
  - the fixed-interval clicker stays at 59, so kids' lead over it widens.
  - Their check: 1.2% of real taps get eaten at Champion (−0.3 pt), and 100 or 120 ms both score lower. Keep ignored taps in the integrity log.
- **b** Big 3-2-1 at y 40% with a soft drum (bells stay D-054's), "Go!" with the bell, camera into the saddle at "3": "scoring starts at the bell".
- **c** No word on an untapped pass (the glow greys 0.3 s); "Early"/"Late" under 30: "the direction tells the kid what to fix."
- **d** 250, the same as sound: "if you can hear the race, you can see it."
- **e** Remove % and purse for everyone. Hide the board for riders from gate to finish. Spectators: place, name, gap; on phones top 3 + your rider, ≤ 30% of height. Config, David decides: "a live % tells a kid mid-race they've lost, which kills upsets they could earn."
- **f** Whitelist: "with 'every key except…', each new binding becomes a tap."
- **g** Hop at the jump spot; the dock shifts left on touch.
- **h** Same values as Engagement: "pressing Gallop must visibly change the gait."
- **i** 48 px top-right below the top bar, hidden in line, racing, results and for 2 min. Remove the horse card's tap target.
- **j** Cheer bar 360×64 top centre on phones, in range only; CLAP to (1,−170,1,−230).
- **k** "Out riding" / "At the races" sign.
- **l** Agrees with all five:
  - logs are airborne-scored trigger volumes;
  - the shins go in a collision group that ignores course props;
  - gamepad gallop on R2;
  - riders see "No Burst tap", spectators nothing;
  - taming shows "Getting to know you…" until the reply.
  - Adds: "Too fast!" → **"One tap!"** ("the mistake is the second tap, not speed").
- **Top 5:** race #1, riding #2, race #6, race #5, call a.

### Child safety
- **a** Adopt: "zeroing a pass for a finger bounce punishes motor skill, not cheating."
- **b** 3-2-1-GO! top-centre, a soft hoof-clop per number, taps before the bell silently ignored: "a start nobody announced feels unfair."
- **c** No label on an untapped pass; "Early"/"Late" under 30: "a failure word every 0.55–1.2 s shames kids."
- **d** 250; races every 1–2 minutes "mustn't pull kids away from horse care"; nothing for far-away players beyond the Big Board.
- **e** Hide the board for riders in-race. Drop % and purse for everyone. Also remove the status line's "Win chance: 62% (+5)" and keep the arrow: "a live % next to prize amounts reads as a tote board."
- **f** Whitelist: "deny-lists leak keys."
- **g** Hop at the jump spot; dock moved 154 px left: "being thrown off for a habit feels like punishment."
- **h** Same gaits. Today's 0.45 bob in first person risks motion sickness.
- **i** 44 px 💎 top-right, no glow or pulse, hidden in line, racing, results and the server's 120 s window. The shop has no post-race check today.
- **j** A silent 56 px cheer strip top-centre, in range only. CLAP 100×60 at (1,−170,1,−230) while riding: "a pop-up every race pulls kids around."
- **k** Nameplate: "🏇 Out riding with you!" / "At the races!" It must never look like the horse ran away.
- **l** Agrees with all five:
  - logs pass-through with a "Clean hop!" sparkle;
  - cones ignore the shins;
  - R2 for gallop;
  - "Burst done!" for riders;
  - a failed taming says **"Not yet, try again!"**.
- **Top 5:** race #1, riding #2, call a + race #6, riding #1, race #2.

### Young player
- **a** Adopt: "thumbs bounce. Wiping out a tap the kid really made feels like cheating."
- **b** Big "3", "2", "1", "GO!" with a drum, camera in at "3": "the first pass catches kids by surprise."
- **c** No word on an untapped pass (the marker fades). "Early!"/"Late!" under 30. **Keep "Too fast!"**: "a word flashing every second while they look away nags them."
- **d** **220 studs**, so the paddock, Feed & Seed and barns are out "with room to spare"; no pop-ups while training or shopping.
- **e** Remove % and purse ("reads like a betting board"). Hide the board for riders; spectators get place and name only, 4 rows on phones. Config, since it's David's call.
- **f** Whitelist, and the slider says "SPACE" on PC: "kids press W to 'go'."
- **g** Hop at the jump spot: "every Roblox kid's thumb already goes there."
- **h** Same gaits: "kids notice 'sewing-machine' legs and a sinking rider. They won't notice slip."
- **i** 56 px top-right on touch. Only a button on the horse card responds, not the whole card: "opening the shop by steering feels like a trick."
- **j** 48 px cheer strip at the top, in range only; CLAP to (1,−170,1,−230).
- **k** "Out riding 🐴" / "At the races 🏁": "an empty stall tells a kid 'my horse is gone.'"
- **l** Agrees with all five. Logs stay visuals you hop over; cones wobble. Burst miss → "Next time!" for riders only. Taming failure → "So close, try again!"
- **Top 5:** race #1, riding #1, race #6 + a, riding #10, riding #2.

## Rebuttals

None held. The four openings agreed on direction for every call:
- 4/4 on a, f, g, h and k;
- 4/4 on hiding the board for riders and dropping % and purse;
- 4/4 on keeping the 💎 button out of the thumbstick zone and away from races.

The splits were about sizes and words, which the moderator settles below with the reasons:
- radius 220 vs 250;
- countdown sound;
- a warm-up sweep;
- strip heights;
- burst-miss wording;
- "Too fast!" vs "One tap!";
- auto-hop logs;
- the taming failure line.

Each designer named the evidence that would reopen their call (see Minority view).

## Options

| Call | Option | For | Against | Panel support |
| --- | --- | --- | --- | --- |
| a | **Ignore a tap < 150 ms after the counted tap (chosen)** | Rookie 66→77.5 with bounces; mashing ≤ 4.2 | Needs PaceMeter + Python parity | 4/4 |
| a | Keep D-026 (two taps = 0) | No change | Punishes motor noise, not cheating | 0/4 |
| b | **3-2-1-GO! over the existing 3 s, drum ticks, bell at GO (chosen)** | Kids catch pass 1; no race time added | Small UI and sound work | 4/4 |
| b | + non-scoring warm-up sweep | Rhythm before pass 1 | Taps that do nothing confuse; more to build | 1/4 (Engagement) |
| c | **No word on an untapped pass; Early/Late for a tap under 30 (chosen)** | Stops nagging; tells the fix | Kids who look away get less nudge | 4/4 |
| c | "Miss" only after N untapped passes | Some nudge kept | Still a failure word | 0/4 |
| d | **250 studs, the same as sound; nothing extra far away (chosen)** | One rule ("hear it, see it"); grandstand, plaza, Race Board inside | Paddock edge and Training Ground inside, so a "busy" rule is needed | 3/4 |
| d | 220 studs | More room around shops | Plaza edge closer; two radii to learn | 1/4 (Young player) |
| d | Toast for far-away players | Draws spectators | A pull every 1–2 minutes | 0/4 |
| e | **Riders: hidden from gate to finish; spectators: slim board; no % or purse anywhere (chosen)** | Strip + badge suffice; no tote-board look; no "you've lost" number | Reverses David's D-030 ask for riders | 4/4 |
| e | Hide on phones only | Keeps D-030 on PC | Two layouts; the % problem stays | 0/4 |
| e | Keep as is | David's ask | 56% of a phone screen; tote-board look | 0/4 |
| f | **Whitelist: Space, Enter, click, touch, gamepad A/R2 (chosen)** | Predictable; new bindings can't leak in | Kids who mash other keys must learn Space | 4/4 |
| f | Deny-list (tech lead's interim) | Any key works for kids who don't know Space | Leaks (C, E, number keys, future bindings) | 0/4 |
| g | **Hop button at Roblox's jump spot; dock fits left of the right column (chosen)** | Thumb memory; Get off no longer under the thumb | Narrower dock on phones | 4/4 |
| h | **Walk 5/24° < 12, trot 7/30° at riding speed, gallop 18/40°, leg-driven bob 0.15 (chosen)** | 2.3 Hz trot; slip 73→38%; no floating; less motion | Riding "walk" becomes a trot (amends D-051) | 4/4 |
| h | QA's walk 5/24° at 16 | Slip 30% | 3.2 Hz "sewing machine" | 0/4 |
| i | **Touch: 💎 pill top-right, hidden around races; nothing tappable in the thumbstick zone (chosen)** | Steering never opens a store; follows D-050's refusal window | Moves D-050's "dock" button | 4/4 |
| j | **CLAP at (1,−170,1,−230); cheer strip top-centre, silent, in range only (chosen)** | Movement buttons keep the right column; centre stays clear | Top area crowded on phones (board waits) | 4/4 |
| k | **Empty stall with a plaque (chosen)** | Explains where the horse is; never "ran away" | One more sign model | 4/4 |
| k | Hide the horse, no sign | Simplest | Reads as a missing horse | 0/4 |

## Recommendation

Adopt the chosen rows as **D-055** (race) and **D-056** (riding and world). Full text with values and config keys is in `decisions-quirks.md`.

**Race (D-055)**
- **(a) Bounce taps:**
  - A tap within **150 ms** of the last *counted* tap is dropped, also across a pass boundary, and the first tap counts. A real second tap later in the same pass still zeroes it.
  - Server-authoritative in `PaceMeter.score`, mirrored in `src/pace_meter.py`; the client applies the same rule for its labels.
  - Dropped taps are tallied in the integrity log but never used as timing samples. `GameConfig.pace.bounceSeconds = 0` restores D-026.
- **(b) Countdown:**
  - Big "3", "2", "1" at the centre over the existing 3 s (`GameConfig.gateCountdownSeconds = 3`), with a soft drum tick for each number. The bell keeps its job: "GO!" with the bell and "And they're off!".
  - Drum, not bell, because D-054's lane lock uses bell ticks.
  - The camera moves into the saddle at "3". The slider shows still, with the first glow lit.
  - Taps before the bell do nothing, with no message.
  - Spectators in range see smaller numbers.
  - Reduced Motion: numbers fade instead of popping.
- **(c) Missed passes:**
  - An untapped pass shows no word or icon; the glow greys for 0.3 s and the speed meter dips as today.
  - A tap scoring under 30 says **"Early"** or **"Late"** (tap time against the pass's ideal time).
  - A second tap says **"One tap!"** (was "Too fast!"); the hint is unchanged.
  - Riders who miss the Final Burst see **"Finish strong!"**; spectators see nothing.
- **(d) Spectator range:**
  - Follow a race within **250 studs** of its course's outer edge, the same range as sound (D-052), and keep it until 300 studs (no flicker at the edge).
  - **Busy rule:** no race HUD, cheer strip or results card during a training ride, a care or training game, or with a full-screen panel open (shops, My Horses, Stable Board, Map). The HUD appears when the kid is done, if still in range.
  - A spectator gets a results card only if they followed the finish.
  - Far away: nothing; the Race Board on Fair Street (D-041) is the far view.
- **(e) Board:**
  - **Riders:** hidden from the gate to the finish on every device. The status line's live "Win chance: N% (+d)" goes too, and the badge's up/down arrow stays (D-033).
  - **Spectators:** rows show place, lane badge, name, and ★ on the rider they cheered (with the same up/down arrow after cheers lock, D-019). On phones that's the top 3 plus their rider, at most 4 rows, and it appears once the cheer strip has closed; tablets and PC show 8 rows.
  - **No % or purse columns anywhere.** Prizes stay on the race picker card.
  - `GameConfig.hud.riderBoardInRace = true` restores David's D-030 layout for riders.
  - **Moderator's note:** this reverses David's own D-030 request for riders, so it is the first row for him to check, and it answers OPEN_QUESTIONS #1 provisionally.
- **(f) Tap keys:**
  - Only Space, Enter (Return and KeypadEnter), left mouse, touch, and gamepad A and R2 tap.
  - On keyboard devices the slider shows a small "SPACE" key cap.
  - The first other key pressed during a pass shows "Tap: SPACE or click" (once per race).
  - D-054's steering keys are simply not taps. `GameConfig.tapKeys` holds the list.

**Riding and world (D-056)**
- **(g) Hop button:** a touch-only **"⬆️ Hop"** button while riding outside races, at Roblox's own jump spot and size (70 px at (1,−95,1,−90) when the short side ≤ 500 px, else 120 px at (1,−170,1,−210)).
  - It uses the existing JumpRequest hop. Gallop stays above it.
  - **Right-column rule:** on touch the bottom-right column belongs to movement buttons (Hop, Gallop). The dock fits into the width to its left (about W − 154 px on phones, scale 0.55–1 as today), so Ride/Get off never sits under the jump thumb.
- **(h) Gaits:**
  - Walk {stride 5, amp 24°} below **12** studs/s; trot {7, 30°} from 12 to 36, so riding at 16 trots at 2.3 Hz; gallop {18, 40°} above 36 (2.6 Hz riding, 3.1 Hz racing).
  - Bob = 0.15·|sin 2π·phase|, driven by the legs, minus the lowest hoof's lift. The rider moves with the back.
  - Reduced Motion keeps the camera off the bob.
  - Amends D-051's walk < 20 threshold and stride values.
- **(i) 💎 on touch:**
  - A 48 px "💎 N" pill at the top-right below the Roblox top bar: no glow, pulse, badge or sound, and a tap opens Tack & Paint as before.
  - On every device, both shop doors (the 💎 button and the Fair Street counter prompt) are hidden in line, while racing, on the results card, for D-050's 2 minutes after a race, and during training rides. No countdown or "back soon" text.
  - On touch nothing tappable sits in the thumbstick zone (left 40% × bottom ⅔). The cash and horse cards there are display-only, and My Horses opens from a 🐴 button in the dock's button group, outside the zone.
  - PC keeps 💎 in the dock.
- **(j) Cheering:**
  - CLAP at **(1,−170,1,−230)** on every device: 170×90 on foot, 120×70 while riding.
  - The cheer bar becomes a silent strip at the top centre under the status line, 56 px tall with chips ≥ 48 px wide, shown only inside the (d) range and never during the busy rule.
  - After a cheer it shrinks to one 40 px line, "📣 Your horse: 3 · Comet", in the same spot.
- **(k) Stall:** the stall is empty while your horse is out, with a plaque on the door. Visitors see the same.
  - "🐴 Comet is out riding" while ridden (training rides included);
  - "🏁 Comet is at the races" while racing.
  - Care prompts at the empty stall are hidden. The horse is back the moment you get off or its race ends.
- **(l) Other calls:**
  - **Training props stay soft, against QA's "make log jumps collide":**
    - Log jumps never collide with a horse, and a hop over one while airborne shows a "Clean hop!" sparkle (D-053 scores airborne).
    - Cones and poles go in a collision group the new shins collider ignores, and wobble when touched.
    - A horse never stops at a prop.
  - **Gamepad gallop** is R2 (hold), as D-053 says, with L3 kept. Not ButtonX, which is the ProximityPrompt key for care. Shift stays the PC gallop and must not toggle Shift Lock while riding.
  - **Taming:** "Getting to know you…" with a filling heart until the server answers, then "💖 Friends!" or **"Not yet, try again!"**. Not "So close": near-miss wording.
  - **Ride or Map while still seated after a race:** "Tap Done first" instead of nothing.

## Priority: the top 10 from a kid's point of view (all findings, both reports)

The panel's top-5 votes were tallied with 5 points for 1st down to 1 for 5th:
- race #1: 20;
- riding #2: 13;
- taps (race #6 + a): 10;
- riding #1: 9;
- race #5: 4;
- riding #10: 3;
- race #2: 1.

The moderator filled places 7–10.

1. **Race #1:** you cross the line first and are told you came 2nd (every race).
2. **Riding #2:** "💖 Friends!" and then no horse arrives (56% of tamings); kids think they lost a horse.
3. **Taps that silently don't count:** finger-up timing (race #6), bounces zeroing a pass (a), and stray keys (race #7, f). This is every tap, worst on the double-weight burst.
4. **Riding #1 (g):** on phones the jump spot gets you off the horse.
5. **Race #5:** on phones the Final Burst meter is mostly hidden, and the badge covers the slider.
6. **Riding #10 (i):** steering opens the Diamond shop. It is a kid-safety exposure as well as a UX bug.
7. **Race #2 and race #10:** results-screen traps. A replay tap can leave the rider stuck for a minute, and the dock covers the card on phones.
8. **Race #8 and riding #9 (d, e, j):** every race on both courses pops a HUD, results card, "Missed the Final Burst!" and a mid-screen cheer bar over whatever the kid is doing.
9. **Race #3 and race #4:** horses lurch, brake and slide backwards at checkpoints, and the place badge flickers. This is what David saw as "the pause at the Final Burst".
10. **(b) and (c):** no countdown before pass 1, and "Miss" flashing every second.

Next in line:
- riding #5: Get off drops you inside plot walls;
- riding #3 / h: skating legs and the sinking rider;
- race #9: the next race steals your card and camera;
- riding #7 / k: the horse in two places;
- riding #8: "Ride this one" throws you off;
- race #12–13: launch and finish timing;
- riding #4/6/11–14: polish.

## Minority view

- **Engagement:**
  - Wanted a non-scoring warm-up sweep during the countdown. Not adopted: taps that do nothing confuse a first-timer.
  - Wanted logs to auto-hop. Not adopted: a horse hopping by itself hides whether *you* hopped, which D-053 scores.
  - Revisit both if kids still miss pass 1 or ride through logs as if they were ghosts.
- **Young player:**
  - Wanted a 220-stud range. The busy rule covers shops and training at 250, so one shared radius won. Revisit if playtests show pop-ups near Feed & Seed.
  - Wanted to keep "Too fast!". "One tap!" names the fix.
- **Competitive and Child safety:** wanted a gap in lengths on spectators' rows. Not adopted: the race strip already shows gaps, and one number per row is enough for an 8-year-old.
- **Child safety:** wanted CLAP at 100×60 while riding; 120×70 is the compromise for a rhythm target.
- **What would reopen calls** (from the openings):
  - phone tap logs showing more than 2% of real taps eaten, or many second taps 150–300 ms after the first (a);
  - a > 10% drop in tap rate without "Miss" (c);
  - grandstand kids missing cheers at 250 studs (d).

## Decision

D-055 (race feel and HUD fixes) and D-056 (riding feel and world fixes), Accepted (provisional), listed in REVIEW_QUEUE for David. Text ready to paste: `decisions-quirks.md`.
- Amends:
  - D-026 (bounce taps);
  - D-030 and D-032 (rider board hidden in-race; answers OPEN_QUESTIONS #1 provisionally);
  - D-033 (no live % anywhere);
  - D-041 (spectator range);
  - D-050 (💎 placement on touch; shop doors hidden around races);
  - D-051 (gaits);
  - D-054 (whitelist replaces the key carve-out).
- Constrains QA riding fix #4 (shins) and #12 (log jumps) as described in (l).
