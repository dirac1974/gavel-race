# First Studio playtest checklist

The agents can't open Roblox Studio, so the server and client scripts have only been compiled, not run. Use this the first time you play the prototype, and paste anything that fails into a session (screenshots help).

## Setup
- [ ] `cd game && rojo serve`, connect the Rojo plugin in a new Baseplate, press Play.
- [ ] Publish the place to the **LlamaWorks** group (File → Publish to Roblox As), so it can load the uploaded art.
- [ ] Output window shows no red errors on start. `[AssetService] ... not loaded yet` warnings mean an asset is still in moderation or the place isn't group-owned; placeholders show meanwhile.

## Track and art
- [ ] You spawn on the grandstand apron by the finish line, facing the track; invisible walls stop you leaving the grounds.
- [ ] You can't walk through any rail (main track or turf course); you can still jump over one.
- [ ] It looks like Churchill Downs: a big one-mile dirt oval with white rails, a green turf course inside, the long grandstand with the Twin Spires on its roof, the clubhouse at the first turn, the Big Board in the infield, barns on the far side, furlong poles and the finish pole on the inside rail, a checkered strip at the finish.
- [ ] Eight horses stand in the starting gate, each with a lane badge 1–8; your horse has a YOU marker. The gate's position changes with the distance (Sprint: backstretch; Mile: just past the finish; Classic: top of the stretch).

## Lobby
- [ ] "Next race in N" counts down from 20 (or starts at once with 8 players).
- [ ] The board lists 8 lanes: you (highlighted) plus bots, each with lane badge, Win chance % and Win purse.
- [ ] Win chances add up to about 100%.
- [ ] The status line shows the race conditions (for example "Rookie race: Sprint · Dirt · Sunny").

## Riding and the race
- [ ] When the race starts you're seated on your horse and the camera is a close chase view from just behind and above, wide enough to see the nearby horses; it turns with your horse round the bends. Scrolling (or pinching) zooms in to first person or further out.
- [ ] Every horse faces the way it's running (heads forward, not backwards).
- [ ] Every bot horse has a Roblox-style jockey in its lane's colours (shirt and helmet) with white breeches, sitting in the saddle, not standing.
- [ ] Your rider sits on the horse's back (not floating or sunk in). If not, note roughly how far off; `SADDLE_HEIGHT` and `SADDLE_BACK` in `TrackScene.luau` tune it.
- [ ] Space, clicks and taps never throw you off the horse.
- [ ] A big place badge ("3rd of 8") sits at the top right and changes as horses pass each other; the YOU marker over your horse shows the same place.
- [ ] The board on the left re-sorts by running order, each row starting with its place (1st, 2nd, ...).
- [ ] The race map (top right) has a small oval with only your dot, the distance to go ("Homestretch!" in the stretch), and a race strip below: one row per lane, the leader near the right, gaps readable, a checkered flag sliding in near the line, and your gap in lengths ("1.5 lengths behind the leader").
- [ ] The gate clears and the horses gallop (with a bob) round the course without stopping; the likelier winners edge ahead after each checkpoint.
- [ ] The race lasts about as long as its distance says (Sprint ~70 s, Mile ~95 s on Rookie).

## Pace slider
- [ ] The slider runs the whole race with no pauses; the glowing target moves every 2–3 passes and the marker's speed varies a little.
- [ ] One tap as the marker crosses the glow shows Perfect / Great / Good / Okay; a second tap on the same pass shows "Too fast!"; missing a pass shows "Miss".
- [ ] The speed meter under the slider fills up when you tap well and drops when you miss.
- [ ] A checkpoint message appears three times (e.g. "Checkpoint 1: Great 84").

## Final Burst
- [ ] "FINAL BURST ×2" appears as the horses come off the final turn, then the big rainbow meter just into the homestretch; the marker starts somewhere different each race. The horses never pause.
- [ ] After the burst the slider comes back for the stretch drive ("Stretch drive! Keep tapping to the line") until just before the finish.
- [ ] One tap scores; a great burst plays a banner on your screen (and rays); other players' great bursts show a ✦ by their name.
- [ ] The horses then cross the line one by one in finish order, "And they're home!", and the results panel with ribbons appears.
- [ ] About 3 s later you're off the horse on the apron, back in third person, and can jump again.

## Integrity (log only)
- [ ] After each race, the Output window shows no errors from integrity tracking. (A flag prints an `[Integrity]` line; nothing is shown to players while `logOnly` is on.)

## Results
- [ ] leaderstats Green Cash and League Points increase by the right amounts.
- [ ] A new lobby starts about 5 seconds after the results.

## Your horse (Stage 1, D-037)

Turn on **Game Settings → Security → Enable Studio Access to API Services** to test saving; without it you get a temporary profile (Output says so) and nothing saves.

- [ ] First join: the starter picker opens with three turning horses (bay, palomino, dapple grey); picking one highlights it.
- [ ] Naming: word chips build the name live ("Lucky Star"); tapping a chosen chip again removes it; New words reshuffles; one word is allowed.
- [ ] "That's my horse!" closes the picker with a "Meet …!" toast; the dock shows your horse's name, coat colour and five Energy hoofs.
- [ ] Dock: Green Cash (starts at 50), horse card, RACE! button. Nothing overlaps the Roblox thumbstick or jump button on a phone.
- [ ] RACE! puts you in line ("In line! 18s"); ✕ leaves the line; a second player joining shows "· 2 riders".
- [ ] The race uses your horse: its name on the board and badge, its coat under you. Players who didn't press RACE! watch instead.
- [ ] Results pay into Green Cash (the dock number bounces) and the player list shows Green Cash and Wins.
- [ ] Leave and rejoin (with API access on): your horse, cash and wins are still there; the picker doesn't reopen.
- [ ] Two Studio test clients: each has their own horse; one leaving doesn't affect the other's save.

## The world (Stage 2, D-035, D-042)

- [ ] After picking a horse you spawn inside your own fenced plot on Barn Lane, facing your barn; your horse stands in a stall with its name over the half door (⭐ = active horse).
- [ ] Barn: one bay per stall (2 to start), red walls, white trim, hay bale, water trough, three empty garden beds. The gate sign reads "<your name>'s Stable"; empty plots say "Free stable".
- [ ] Gate 1: a tunnel through the grandstand joins the homestretch apron to Fair Street (signs at both ends).
- [ ] Fair Street: plaza with a fountain, lamps and bunting; Race Board (prompt "Join the next race" puts you in line), Feed & Seed, Vet, Training Paddock (cones and jumps), Market Corral, Trail Gate at the far end.
- [ ] The Trail: a dirt loop through woods to a flower meadow and back.
- [ ] Map button: five pictures; each one takes you there (My Stable needs a horse). Works while riding (horse comes too); not while in a race.
- [ ] Ride: the dock's Ride button brings your horse and seats you; thumbstick or WASD steers; Shift or the Gallop button gallops; Space hops; Get off sends the horse home. Other players see your horse switch between standing and galloping with a bob.
- [ ] Pressing RACE! while riding: at the gate you're moved onto your race horse and your own horse goes home.
- [ ] Privacy (needs two accounts): a stranger can't walk into your plot (invisible wall at the fence); a friend can. Your own plot always lets you in.
- [ ] Lighting: soft haze, warm colours, no harsh glare. Frame rate on a phone stays smooth around Fair Street.

## Care and food (Stage 3, D-038)

- [ ] At your barn each horse has a "Care" prompt; the card shows today's care stars, Energy, hay and a pink bond bar.
- [ ] Feed uses 1 hay (grain if you have no hay); a second meal the same day is refused kindly; first meal tops up Energy (+1, every 2 h).
- [ ] Groom opens the brushing game: swipe the mud spots away → "Shiny!" → the horse sparkles in its stall for the rest of the day.
- [ ] Treats (carrot, apple, oats, sugar cube): bond goes up, three a day; Pet always gives a nuzzle, bond once a day; hearts float up over the horse for everyone nearby.
- [ ] Full care shows ⭐⭐ on the dock's horse card; the next day it's back to none (nothing is lost).
- [ ] Garden beds: plant carrot (1 h), apple (4 h) or oat (8 h) seeds; sprouts grow in stages; ready crops sparkle; harvest gives 3/4/5; crops never wither while you're away.
- [ ] Muck out (hold F at a stall door): +1 hay, +2 Green Cash; the same stall is clean for 4 h.
- [ ] Feed & Seed: "Shop" prompt at the door; buy ×1 or ×5; can't overspend; "Sell crops" keeps 5 of each.
- [ ] Out of hay and cash: the message points to chores; nothing ever hurts the horse.
- [ ] Visitors (friends) don't see your care prompts.

## Stable Board (Stage 5, D-043)

- [ ] The 📋 button in the dock and the noticeboard by your gate both open the Stable Board.
- [ ] Top row: one card per stalled horse with a fact ("Comet is rested and ready to race", "napping in the straw") and a next step with GO.
- [ ] Today's jobs: three cards with picture, words, progress bar, reward and GO; GO draws golden hoofprints to the place.
- [ ] Doing the thing (feed, brush, race, pick a crop, ride…) moves the bar; a toast says the job is done; Claim pays the reward.
- [ ] All three claimed: a sleeping horse and "All done today!".
- [ ] "Swap a job" once a day replaces an unfinished job; then the button hides.
- [ ] This week / this month ribbons with a 🎁 when something's ready to claim; monthly shows ⭐ stamps.
- [ ] The pinned job above the dock shows the first unfinished job with GO; hidden while you race or with the board open.
- [ ] No bell, no red badge, no timers anywhere; no job asks you to win, spend or invite.
- [ ] Next day (or change the clock): finished but unclaimed jobs pay out with a "Welcome back" toast; the visit counts once per day.

## Training and the vet (Stage 6, D-039, D-040)

- [ ] Training Paddock: the "Train" prompt at the gate → pick a horse → four stat buttons showing value, Potential (or "?" until the vet reveals it) and room to grow; "This week: x of 6 points", "Rested ✨" when 3 h have passed since the last session.
- [ ] Sprint Lane (Speed): tap as the runner crosses the glowing zone, 5 rounds getting faster.
- [ ] Gate Break (Acceleration): wait for green, tap; tapping on red says "Too soon!".
- [ ] Hill Climb (Stamina): hold to climb, let go to slide, stay in the moving green band for 8 s.
- [ ] Mud Splash (Grit): tap as each puddle reaches the hoof, 8 puddles.
- [ ] After a game: a label and score, then a toast like "+3.2 Speed! Rested bonus ✨"; the weekly cap stops training at 6 points with a kind message.
- [ ] Vet: the "Check-up" prompt → pick a horse → Health Passport with five stamp slots → tap with the heartbeat (the heart pulses); first visit stamps "First check-up", the next day's visit reveals Potential.
- [ ] Stable Board: horse cards suggest "Next: train <stat>" when training is ready; daily and weekly jobs for training and check-ups appear in the mix.

## Training rides (D-053)

The Training Ground (T1):
- [ ] The Training Paddock's south fence has a gate in the middle; a dirt path runs south from it under a "⭐ Training Ground" board to the training oval. No trees on the path.
- [ ] Picture signs stand either side of the path near the oval: 💨 Sprint Lane ("Ride!"), ⛰️ Hill Climb and 🚦 Gate Break ("Coming soon"), and 💦 Mud Splash ("In the paddock ⬆"). Each reads from both sides.
- [ ] The oval: white rails on both sides of a 24-stud dirt track, a green infield, a gap in both rails where the path comes in. You can't ride through a rail.
- [ ] The hill on the far (south) straight is gentle: the horse rides up and over it at a gallop without leaving the ground for long or catching on anything; the rails follow it.
- [ ] Six coloured hoops (arches three horses wide) stand on the track, one on top of the hill; your horse and rider pass under the top of every arch and never bump a post.
- [ ] The practice gate stands in the infield with a dirt lane and a yellow flag 120 studs along it.
- [ ] The paddock arena holds the gymkhana: four mud puddles, three low logs (well under the horse's hop), four red-and-white poles in a darker "canter" lane, a white start line by the north-west corner and a 🏁 Finish arch near the south-west corner. Nothing in the arena stops your horse (poles and logs never collide). Walking from the street gate to the south gate never meets a log.

Riding the courses (T2: Sprint Lane and Mud Splash):
- [ ] The paddock's "Train" prompt opens "⭐ Training" with four picture tiles: Sprint Lane and Mud Splash say their stat; Gate Break and Hill Climb say "Coming soon" (tapping one only shows a toast). "⚡ Quick train" opens the old horse and stat games; a perfect Quick train game gains the same as a score of 70 (quality capped at 0.85).
- [ ] Tapping Sprint Lane (or "Ride" at its picture sign) puts you on your active horse (it's called if you weren't riding) at the white start line on the oval's north straight, facing west. Big 3, 2, 1, then "Go!" and "Giddy-up!". The horse can't move or hop during the 3-2-1.
- [ ] While riding: push the stick and the horse gallops by itself; only the next hoop glows gold; dark hoofprints lead to it; riding through gives a ✨; three lap dots at the top fill one per lap. No timer anywhere. Near a hoop the horse is nudged gently toward it, never steered without you.
- [ ] Phones: the Gallop button goes away and a big ⬆️ Jump button appears bottom-right, above the dock (not under the Ride button). It hops the horse and never throws you off. Keyboard Space and gamepad A hop as usual; gamepad R2 gallops in free riding too.
- [ ] Other riders (training or free riding) pass straight through you during a ride; rails still stop you; you never sink into the ground or the hill.
- [ ] After three laps the end card shows the stars one at a time, then the stat bar grows with "+x.x Speed!" (and "Rested bonus ✨" after 3 h away), then the ribbon: 🥉 for finishing, 🥈 from 75, 🥇 from 90 if the ride was quick; "New!" the first time. "Ride again" starts over at the start line; "Done" closes the card.
- [ ] After the week's 6 points: the card says "Speed is full this week. Ride for stars!" and the stat doesn't change. Rides never cost Energy.
- [ ] Mud Splash starts at the arena's north-west corner. The horse lopes round the lanes and slows to a canter in the darker pole lane by itself. "Splash! 💦" in a puddle, "Clean hop!" only when the horse is in the air over a log, "Nice bend!" passing a pole on the hoofprints' side. Riding through a log without hopping just doesn't score: no message, no stumble. The 🏁 Finish arch ends the ride and the card shows splashes, hops and poles.
- [ ] Ending early: "✕ Stop", Get off, riding out of the ground or the arena for a couple of seconds, or a queued race starting all end the ride with a kind note and no gain ("Your race is starting! Training paused.").
- [ ] Two rides within 4 seconds: "Your horse is catching its breath". More than 40 in an hour: a kind rest note.
- [ ] Rejoin: the tiles still show your ribbons (🥉🥈🥇) for that horse.
- [ ] During a ride and its end card, Explorer shows the attribute TrainingRide = true on your Player; it clears on Done, Stop, Get off or after 30 s.
- [ ] Output: lines like `[Training] <id> speed: 12% of 430 samples dropped (log only)` are expected only now and then; note how often they appear on a phone (the floor stays log-only, `enforceFloor = false`).

## Race Board and two courses (Stage 4, D-036)

- [ ] RACE! (or the Race Board prompt) opens the picker: two cards, Dirt course and Turf course, each with league, distance, surface, weather, eight lane dots and "Open / Filling / Starts in Ns / Racing now".
- [ ] Your stalled horses are listed with Energy and "Loves today's race (+3)" / "Not its best today (−2)"; tired horses say "Resting" and can't be picked (Rookie is free, so this shows from Bronze on).
- [ ] Join puts you in that course's line; the dock shows "In line! Turf 14s · 2 riders"; ✕ leaves.
- [ ] Two players join different courses: both races run at the same time, on the dirt and on the turf; each rider's screen follows their own race.
- [ ] A player who isn't racing sees both races animate and the HUD follows the newest race ("(watching)").
- [ ] Turf races start from a gate on the turf course and finish on the same line (a checkered strip across the turf too).
- [ ] The Race Board on Fair Street lists both courses with riders and status, updating each second.
- [ ] Replay of a turf race shows the turf horses; a race starting on the other course doesn't stop your replay.

## Spectators (Stage 7, D-019, D-020, D-041)

- [ ] Not riding when a race starts: a "Cheer for a horse!" bar with eight lane chips (number, colour, horse name) appears above the dock.
- [ ] Tap one before the first checkpoint: toast "Cheering for …", the bar shrinks to "Your horse: 3 · …", and a big 👏 CLAP! button appears above the jump button. After the first checkpoint, new cheers aren't allowed.
- [ ] The ring round CLAP! pulses on the hoofbeat; clapping on it shows Perfect / Great / Good; mashing doesn't help (extra claps count against).
- [ ] After the race: a ⭐ Top Fans panel (top five: name, horse, score) separate from the results, your own rank, and "+N Fan XP · Fan level N".
- [ ] Riders never see the cheer bar in their own race; two races at once: the bar follows the race you're watching.
- [ ] A full crowd only nudges a horse (12.5% → about 12.8%); nothing shows per-fan boosts.
- [ ] Stable Board: "Cheer for a horse in a race" can appear as a daily job; GO leads to the racetrack.

## More horses (Stage 8, D-037)

- [ ] Market Corral: five horses stand in a row facing the street with signs (name, ★ bloodline, price); the same five on every server all week.
- [ ] "Look" at one: card with coat, style, stat bars, bloodline stars ("more ★ = more room to grow"), "Bring home · 💵 price". Buying pays Green Cash; the horse goes to a free stall, or the pasture if stalls are full; buying again says it already lives with you.
- [ ] The Trail meadow: four wild horses (pinto, appaloosa, buckskin, dun) graze and wander, the same on every screen.
- [ ] "Make friends": the gentle game (tap when the heart glows 💖, not when startled 😮); three good taps = friends; uses one treat (carrot, apple or sugar cube); one new friend a day.
- [ ] Tap the horse card in the dock: My Horses with every horse (stall or pasture, stats with Potential once revealed, Energy, bond, record).
- [ ] "Ride this one" makes a stalled horse active (⭐); "Move to stall" then "Swap here" swaps a pasture horse into a stall.
- [ ] "Build a stall · 💵 300/800/2000/4000" adds a bay to your barn (up to 6); the barn grows and narrows bays to fit.
- [ ] Rename with word chips; the stall name plate updates.
- [ ] Up to three pasture horses graze in your front yard.
- [ ] 20 horses at most: the market and taming say your stable is full.

## Leagues (Stage 9, D-013, D-046)

- [ ] An empty course card says "Open · your horse's league"; the first rider's horse sets its league (and Race / 🏆 Cup / 🎈 Practice).
- [ ] Below the horses: Race, Cup ("🏆 64 pts" until unlocked) and Practice; Practice works for tired horses and pays nothing; Bronze races and up cost 1 Energy.
- [ ] A horse with 100 League Points (Rookie) can enter the Rookie Cup; winning it pays 3× the league's purse and shows "🏆 … moves up to Bronze!"; its points start again.
- [ ] A horse whose best Rating passes its league ceiling (Rookie 58) sees "too strong for Rookie races now"; its Cup opens; Practice stays open.
- [ ] Joining a card claimed by another league says "That race is for Bronze horses".
- [ ] Bronze cards can be Sprint, Mile or Classic; Silver and up every distance.
- [ ] My Horses: league line with points to the Cup or "🏆 Cup open!"; Retire asks once more, then the horse's plaque appears in the 🏅 Hall of Fame (you can't retire your last horse).
- [ ] Stable Board suggests "win the Cup to move up" when it's open.

## Polish (Stage 10, D-045, D-049)

- [ ] New player: after naming the starter, a 🧭 card at the top says "Let's race! …" with GO (opens the race picker and hoofprints to the Race Board) and Skip.
- [ ] Each step finishes by doing it: race → feed → brush → plant → open the Stable Board → "You're all set!".
- [ ] ⚙️ (top right, hidden while racing): Settings (who can visit: Friends / Nobody; break reminder On/Off; "Show me around again") and For grown-ups (play time this week, how races work, no gambling, nothing for sale that changes a race, horses never come to harm, chat and parental controls).
- [ ] Setting visits to Nobody closes your gate to friends too; Friends lets friends in.
- [ ] Break reminder on: a gentle "time for a stretch?" note after each hour of play; off by default.

## Tack & Paint, the Diamond store (D-050)

- [ ] 💎 in the dock (next to Green Cash) and the "Browse" prompt at the Tack & Paint shop on Fair Street open the shop; it never opens by itself.
- [ ] Tabs: Tack, Jockey, Barn Look, Front Yard, Fan Gear, Diamonds. Free starters show "Wearing ✓"; fan flags say "Earned at Fan level 3/5".
- [ ] Buy asks first: "Use 75 💎? You'll have 25 left." Not enough: "You need 25 more 💎". After buying it's worn at once and shows "Return (+75💎)" for a day.
- [ ] Barn paint changes your barn's walls, roof and trim; gold plates change the stall name plates; yard pieces appear in their spots (lanterns both sides of the gate).
- [ ] Riding around the world shows your cloth on your horse and your helmet; races keep lane colours.
- [ ] Owning the stars cloth, star helmet and star flag puts a ⭐ on every name plate.
- [ ] Diamonds tab: packs show "Coming soon" until product ids are set; once set, Roblox's window confirms; buying in line, racing, on results or within 2 minutes of a race says "after your race"; past 250 Robux today it says come back tomorrow.
- [ ] Studio test purchase: Diamonds arrive once; rejoin and they're still there (with API access on).
- [ ] For grown-ups explains Diamonds, the never-sold list, the caps, this month's Diamond purchases and refunds.

## Running legs (D-051)

- [ ] Race horses gallop with moving legs (front and hind legs reaching in turn); legs ease to standing after the run-in; replays show the legs too.
- [ ] Your ride horse walks with slow steps, trots at mid speed and gallops when you hold Gallop; other players see the same.
- [ ] Wild horses in the meadow step with their legs as they wander and stand still while grazing.
- [ ] No gaps at the hips as legs swing; the long tail doesn't swing with a hind leg.
- [ ] If a leg model hasn't loaded yet, the old one-piece gallop pose shows instead (nothing breaks).
- [ ] Gait changes are smooth (gallop to trot to walk in the run-in, Gallop button on and off): no leg snaps.
- [ ] Race horses wear a saddle cloth in their lane colour with the lane number on both sides; jockeys sit on the horse's back, not sunk into it.
- [ ] Your ride horse wears your Tack & Paint cloth fitted to its back (nothing sticks out of its sides); plain cloth is white.
- [ ] Horses look smoothly shaded (not faceted).

## Race shape and replay (D-033, D-034)

- [ ] Up to the far turn, favourites run a little ahead; from the far turn some horses charge late; nobody jumps or reshuffles at the line.
- [ ] A Great or Perfect pace tap visibly nudges your horse straight away.
- [ ] The arrow by the place badge flashes up or down when your chance moves; no percentages anywhere.
- [ ] Results card: "You rode" stars; "Your riding gained you N places!" only when positive.
- [ ] You stay in the saddle on the results card; Done puts you on the apron and restores the camera; after 60 s the server dismounts you anyway.
- [ ] "Watch the finish" starts around the far turn at real speed; "Whole race ×3" runs fast then slows for the final quarter.
- [ ] Replay shows REPLAY, letterbox, your tap labels and "+N"; Behind toggles the camera; Done returns to the results card.
- [ ] Slow motion only when you won; "PHOTO FINISH" when 1st and 2nd were close.
- [ ] Starting a new race while a replay plays cancels it.

## Network and edge cases
- [ ] Studio Test → Clients and Servers with 2–3 players: everyone sees the same lanes and chances.
- [ ] Network simulator at 200 ms latency: well-timed taps still score well.
- [ ] A player leaving mid-race doesn't break the race for others.

## Feel (write down impressions)
- Can a young player keep up with the slider for a whole Sprint (~70 s)? Is a Mile (~95 s) too long for Rookies? Would a 2-minute Classic be fun or tiring?
- Is the chase camera distance right, or should it start closer or further out?
- Is the Final Burst exciting enough, and is double weight too much or too little?
- Can you tell how your taps changed the result?
- Is anything confusing in the first 30 seconds?
