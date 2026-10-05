# 009 — How should training become a ride-around course on your own horse?

Date: 2026-10-05 · Status: Decided provisionally (D-053) · Moderated by Claude. The four designers ran as separate agents: independent openings, then one rebuttal round after reading each other and the researcher's brief.

Suggested repo path: `docs/debates/009-training-rides.md`.

## Question and constraints

David, after his playtest: "The training ground should be more than just the click the meter a few times. You should run around with the horse."

**Today (code):**
- The Training Paddock is a 170 × 150 stud arena on Fair Street (`WorldLayout.places.paddock`). A prompt opens a modal card.
- You pick a horse and a stat and play a 10-second meter game (`PaddockClient.client.luau`): Sprint Lane, Gate Break, Hill Climb or Mud Splash.
- **The client sends the score and the server trusts it** (`TrainingService.server.luau`).
- Gain = 0.12 × (Potential − stat) × (0.5 + 0.5 × score / 100), × 1.5 when rested (`Training.luau`).
- The weekly cap is 6 stat points per horse, reached in about 3 sessions. Sessions are 4 s apart and cost no Energy.
- Free riding already exists (`Rides.luau`, `RideClient.client.luau`): walk 16 studs/s, gallop 46. Thumbstick or WASD steers; the Gallop button or Shift gallops; Jump hops.
- The ride rig's physics is owned by the rider's client, and the server checks no movement ("free roaming wins nothing").

**Constraints:**
- Hard rules 1–3: no wagering; Diamonds never touch stats or win chance; kid safety.
- D-040: one activity per stat; gain ∝ (Potential − stat); a weekly cap reachable in ~3 sessions; rested +50%.
- D-015: Energy gates cash races only.
- D-042: no bottom-of-board rankings; strangers can't interfere with each other.
- D-044 and D-050: no Diamond skips or purchases near training.
- D-035: everything within a short ride of the grandstand.

## Facts (researcher)

Checked 2026-10-05. Facts first; what they mean for us comes after.
- **Star Stable lunging:** WASD changes gait and circle, a checkpoint circle pops up, and "how much horse XP you're rewarded will be based on your accuracy with the checkpoints" ([Star Stable, Lunging take two](https://www.starstable.com/article/lunging-take-two)). Star Stable races are checkpoint courses: green arrows, some checkpoints on jumps ([starstable.wiki.gg, Races](https://starstable.wiki.gg/wiki/Category:Races)).
- **Wild Horse Islands:** Training Island quests earn training receipts that raise speed and stamina. *Unconfirmed:* only third-party guides describe it, and the one we tried returned 403.
- **Real racehorse training:**
  - A breeze is "a wind sprint in track and field", done every six to seven days; a gallop is "about half speed" ([RRP, Watching the Works](https://therrp.org/education/track-life/watching-the-works/)).
  - A pony (lead pony, pony horse) is "ridden alongside the racehorse either during the post parade or during morning training" ([NKy Tribune glossary](https://nkytribune.com/?p=55118)).
  - Gate schooling is standard practice. We found no primary source for Churchill's gate-workout rule, so it is left out.
- **Kids' riding games:** gymkhana includes barrel racing, pole bending, keyhole, flag racing and more. "These events often emphasize children's participation", and Pony Club games were "limited to children up through age 14" ([Wikipedia, Gymkhana](https://en.wikipedia.org/wiki/Gymkhana_(equestrian))).
- **Roblox security:** exploiters can "take network ownership of their character and any unanchored parts" and "modify their player's position, physics", and "all critical logic must be validated server-side" ([Creator Docs, Security tactics](https://create.roblox.com/docs/scripting/security/security-tactics)).
- **Roblox mobile:** "the majority of Roblox sessions are played on mobile devices" ([Mobile input](https://create.roblox.com/docs/input/mobile)). Default controls occupy the bottom-left and bottom-right corners; keep frequently used buttons within reach of them ([Cross-platform design](https://create.roblox.com/docs/ui/cross-platform-design)). Gamepad: Thumbstick1 = movement, ButtonA = primary or jump, L2/R2 = primary actions ([Gamepad input](https://create.roblox.com/docs/input/gamepad)).
- **Accessibility:** assist modes are "optional settings to compensate for lack of speed or precision" ([Game Accessibility Guidelines](https://gameaccessibilityguidelines.com/include-assist-modes-such-as-auto-aim-and-assisted-steering/)).
- **Space and speed (from the code):**
  - The land south of the paddock (about x 640–1140, z −145 to +190) holds only random trees.
  - A gallop crosses the paddock in about 3.5 s, so a galloping course needs its own track.
  - The ride rig's JumpPower is 42, about a 4.5-stud hop, which clears a 2-stud log.

## Openings (summaries of the independent statements)

### Engagement
- Four ride-through courses, one per stat, on the open land south of the paddock:
  - Breeze: hoops on a ~300 × 200 oval, ~17 s laps.
  - Gate School: three dashes from a practice gate.
  - Pony Pace: stay in the lead pony's glow ring.
  - Gymkhana: poles, logs, mud and water.
- Score accuracy, not raw time.
- No Energy cost, and keep the cap of 6. "Cap the stats, never the fun": courses stay open after the cap for ribbons, like Pet Simulator 99's always-open side activities.
- Your own ghost by default, up to 4 friends side by side, and a weekly gymkhana layout that rotates.
- Retire the meters except as an accessibility fallback.

### Competitive
- Score the rider against objects the server owns, never the client's number.
- The server samples the rig at 10 Hz and detects crossings itself. It discards off-course samples and any faster than 53 studs/s (gallop + 15%). Over 10% discarded scores the 0.5 floor quietly.
- Proposed seeded green-window hoops. The pony follower stays 1–3 lengths behind a server-driven pony.
- Horse stats don't change course speed, so the score measures the rider.
- The weekly cap stays the real guard: a perfect script reaches it about one session sooner than an honest rider.

### Child safety
- No failure states: a missed hoop scores zero, a knocked pole stays up, and the horse never stumbles or looks hurt.
- Par time is a ribbon, never a countdown. No Energy cost.
- Strangers pass through each other, so nobody can block or bump. No leaderboards that include strangers.
- Easy Rein (assisted steering) for kids who struggle.
- Keep the 10-second games as Quick Train under the same cap.
- Banned: "So close, try again!" auto-restarts, "your friend beat your time" alerts, and shop prompts near the paddock.

### Young player
- Same controls as free riding, no new buttons, and gallop on at the start.
- Only the next hoop glows (three horses wide), with hoofprints leading to it. The lead pony is the best "go here" that needs no reading.
- No bending poles at a gallop: "46 studs/s on a thumbstick is a crash course for an 8-year-old".
- You can't fail. The end card shows 1–3 stars, then the stat bar grows: "Speed went up!"
- A private ghost of your best. After the cap: "Speed is full this week. Ride for stars!"

## Rebuttals

- **Green-window hoops:** dropped. Competitive conceded that the speed ceiling, in-order hoops and minimum lap time already make extra speed worthless, and a script beats windows as easily as hoops. Young player: "riding through a hoop and getting nothing feels broken." Engagement wants them later as an optional gold-ribbon line. Child safety would accept them only if lit more than half the time and always lit in Rookie.
- **Bending poles:** all agree, as a slow section only. The horse drops to a canter by itself, the poles are wide apart, and a knocked pole stays up.
- **Lead pony:** Young player: the rig has two speeds (16 and 46), so no kid can match a pony's changing pace. Inside the pony's ring your horse matches its speed automatically, and the kid steers to stay in as it weaves. Adopted.
- **Bond after the cap:** dropped. Engagement withdrew it: bond feeds Race Rating (D-014, up to +2), so bond from a replayable course is an uncapped grind for win chance. Competitive and Child safety would accept +1 for the day's first ride inside the existing daily bond limits (minority).
- **Quick Train:** keep it for everyone from the course picker, under the same cap. Child safety: never label it "accessibility", because kids won't pick a mode that names them. Competitive: no client-sent score anywhere, so the server scores the meter games from its own seed, as it does race taps. Engagement: the courses own the stars, ribbons and ghost.
- **Length:** settled at 40–60 s. Engagement and Competitive said 45–60, Young player 60–70, Child safety 60–90.
- **Friends:** side by side, passing through each other. Shared results show stars and ribbons, not ranked times; your own time is private, and a friend's ghost appears only if they share it (Child safety).
- **This week's course:** Child safety accepts a rotating layout only with no countdown and no "last chance", and with ribbons still earnable whenever it comes back.

## Options

| Option | For | Against | Panel support |
| --- | --- | --- | --- |
| A. Four ride-through courses (training oval + paddock gymkhana), scored by the server from sampled positions, cap unchanged (chosen) | What David asked for; same controls as free riding; replayable; removes the client-trusted score | New world build and server sampling; kids must steer at speed | 4/4 |
| B. Keep the meter games, add a cosmetic warm-up lap | Small build | Not what David asked for; still trusts the client | 0/4 |
| C. One long mixed course for all four stats | One build | Every session the same; can't pick the stat the Stable Board suggests | 0/4 |
| D. A with seeded green-window hoops and timed scoring | Harder to script | Near-miss feel for kids; the speed ceiling already does the job | 0/4 at launch (Engagement: later, optional) |
| E. A, costing 1 Energy per session | Paces play | Training competes with racing; pushes kids toward refills | 0/4 |

## Recommendation (D-053)

**Where:** a **Training Ground** on the open land south of the paddock, with a gate in the paddock's south fence.
- It holds a small **training oval**: 160-stud straights, centre-line radius 55, 24 studs wide, so a lap is ~666 studs or ~14.5 s at a gallop.
- The paddock arena keeps the gymkhana.

**Four courses** keep the stat names players already know:

| Course (stat) | What you do | Score (server) | Length |
| --- | --- | --- | --- |
| Sprint Lane (Speed): a "breeze" | 3 laps of the oval through 18 hoops, 10 studs wide (three horses), only the next one glowing, hoofprints between them | 100 × hoops hit / 18 | ~45–50 s |
| Gate Break (Acceleration): gate school | 3 breaks from a practice starting gate on the back straight: stand, the bell rings after a random 1.5–3.5 s, gallop to the flag 120 studs on | Mean of 3 breaks; a break scores 100 at ≤ 0.5 s reaction, falling to 40 at 2 s. Going early: "Wait for the bell!" and that break runs once more (40 if early again) | ~35–45 s |
| Hill Climb (Stamina): follow the lead pony | Pip the lead pony leads 2 laps with a gentle hill on one straight, weaving and changing pace (30–42 studs/s); stay in the glowing ring 1–3 lengths behind it. Inside the ring your horse matches Pip's speed by itself | 100 × share of time in the ring (after a 3 s grace) | ~40–45 s |
| Mud Splash (Grit): gymkhana | In the paddock arena: 4 mud puddles to splash through, 3 low logs (2 studs) to hop, 4 wide bending poles in a slow zone where the horse drops to a canter (20 studs/s) by itself | Mud 4 × 7.5 + logs 3 × 12 (clean = airborne over the log) + poles 4 × 8.5 = 100 | ~45 s |

**Rules:**
- **No failure states.** A missed hoop or knocked pole just doesn't count. The horse never stumbles, refuses or looks hurt. There's no timer on screen, and par time shows only as a ribbon on the end card.
- **Gain** uses the D-040 formula unchanged, with quality = 0.5 + 0.5 × the server's score / 100. Rested ×1.5 stays.
- **Cap:** the weekly cap stays 6 points per horse. **Energy cost: 0** (D-015 unchanged).
- **After the cap** the courses stay open with no gain: "Speed is full this week. Ride for stars!" Stars, ribbons and your ghost still count.
- **Rewards:**
  - the stat gain;
  - 1–3 stars (1 always, 2 at a score of 60, 3 at 90);
  - a bronze, silver or gold ribbon per course per horse (bronze = finish, silver = score ≥ 75, gold = score ≥ 90 and under par);
  - a rosette on the stall wall for each gold;
  - the Stable Board "train" job.
  - No bond, cash, Diamonds or Energy.
- **Equal physics:** horse stats don't change course speed, so the score measures the rider and the server needs one speed limit.
- **Solo:** a private, see-through ghost of your best run on that course.
- **With friends:** Roblox friends at the same start can tap "Ride together" for a shared 3-2-1. Each is scored alone.
  - Course riders never collide with anyone (collision group), and strangers pass through each other.
  - Shared results show stars and ribbons, never ranked times; your own time stays private.
  - A friend's ghost appears only if that friend turns on sharing (off by default).
  - No leaderboards.
- **Controls:** the same as free riding, with no new buttons.
  - Touch: thumbstick steers, Gallop button, Jump button.
  - Keyboard: WASD or arrows, Shift to gallop, Space to jump.
  - Gamepad: left stick; R2 (new binding) or L3 to gallop; A to jump.
  - Courses start at a gallop, except Gate Break, which waits for the bell.
  - Hoops have a soft steering magnet within 4 studs.
  - **Easy Rein** (Settings, off by default) steers toward the next hoop or ring with no score penalty.
- **Server validation:**
  - The client sends no score. TrainStart checks the horse is yours and stalled, you're riding it inside the Training Ground, you're not racing, and the 4 s gap has passed (at most 40 sessions an hour).
  - The server samples the rig's root position at 10 Hz on its own clock and detects hoop, gate, log, pole, mud and ring events itself from those samples.
  - It discards samples faster than 53 studs/s (horizontal), jumps over 12 studs between samples, and samples outside the course bounds.
  - If more than 10% are discarded, the session scores at the 0.5 floor with a normal end card (no accusation).
  - A race starting, getting off, or leaving the ground ends the session with no gain and no penalty.
  - The weekly cap remains the real limit: a perfect script gains no more than a good rider, only sooner.
- **Quick Train:** the four 10-second games stay on the course picker for everyone, labelled "Quick train". They count toward the same cap, with quality capped at 0.85.
  - Their scoring moves to the server: the server owns the game seed, and taps are resolved with the race's latency allowance (D-021).
  - Courses own the stars, ribbons and ghosts.
- **Later:** "This week's course", a rotating Mud Splash layout with no countdown, whose ribbons can be earned whenever it returns.
- **Hard rules:** nothing here can be bought; no Diamond retries, skips or shortcuts; no shop prompts in the Training Ground.

## Minority view

- **Engagement:** Speed adds up to +8% gallop speed in the world and on courses, with par scaled per horse, so kids see their horse get faster. Also seeded green-window hoops as an optional gold-ribbon line later.
- **Competitive and Child safety:** +1 bond for the day's first ride, inside the existing daily bond limits.
- **Child safety:** rides of up to 90 s are fine. Young player prefers three short laps around 60–70 s for Sprint Lane.

## Decision

D-053, Accepted (provisional). Listed in REVIEW_QUEUE for David. Implementation plan and risks: `plan.md`, Training stages T1–T5.
