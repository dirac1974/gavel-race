# First Studio playtest checklist

The agents can't open Roblox Studio, so the server and client scripts have only been compiled, not run. Use this the first time you play the prototype, and paste anything that fails into a session (screenshots help).

## Setup
- [ ] `cd game && rojo serve`, connect the Rojo plugin in a new Baseplate, press Play.
- [ ] Publish the place to the **LlamaWorks** group (File → Publish to Roblox As), so it can load the uploaded art.
- [ ] Publishing an update while players are on: if any T2–T4 training build is live when T5 ("This week's course") ships, publish with **Shut Down All Servers** or **Migrate to latest update**. A T2–T4 server drops training ribbons it doesn't know, so a kid hopping from a T5 server back to an old one would lose their Mud Splash layout ribbons (T5 and later keep unknown ones).
- [ ] Output window shows no red errors on start. `[AssetService] ... not loaded yet` warnings mean an asset is still in moderation or the place isn't group-owned; placeholders show meanwhile.

## Track and art
- [ ] You spawn on the grandstand apron by the finish line, facing the track; invisible walls stop you leaving the grounds.
- [ ] You can't walk through any rail (main track or turf course); you can still jump over one.
- [ ] It looks like Churchill Downs: a big one-mile dirt oval with white rails, a green turf course inside, the long grandstand with the Twin Spires on its roof, the clubhouse at the first turn, the Big Board in the infield, barns on the far side, furlong poles and the finish pole on the inside rail, a checkered strip at the finish.
- [ ] Eight horses stand in the starting gate, each with a lane badge 1–8; your horse has a YOU marker. The gate's position changes with the distance (Sprint: backstretch; Mile: just past the finish; Classic: top of the stretch).

## Lobby
- [ ] "Next race in N" counts down from 15 (D-061; or starts at once with 8 players).
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
- [ ] Picture signs stand either side of the path near the oval: 💨 Sprint Lane ("Ride!"), ⛰️ Hill Climb and 🚦 Gate Break (all "Ride!"), and 💦 Mud Splash ("In the paddock ⬆"). Each reads from both sides.
- [ ] The oval: white rails on both sides of a 24-stud dirt track, a green infield, a gap in both rails where the path comes in. You can't ride through a rail.
- [ ] The hill on the far (south) straight is gentle: the horse rides up and over it at a gallop without leaving the ground for long or catching on anything; the rails follow it.
- [ ] Six coloured hoops (arches three horses wide) stand on the track, one on top of the hill; your horse and rider pass under the top of every arch and never bump a post.
- [ ] The practice gate stands in the infield with a dirt lane and a yellow flag 120 studs along it.
- [ ] The paddock arena holds the gymkhana: four mud puddles, three low logs (well under the horse's hop), four red-and-white poles in a darker "canter" lane, a white start line by the north-west corner and a 🏁 Finish arch near the south-west corner. Nothing in the arena stops your horse (poles and logs never collide). Walking from the street gate to the south gate never meets a log.

Riding the courses (T2: Sprint Lane and Mud Splash):
- [ ] The paddock's "Train" prompt opens "⭐ Training" with four picture tiles: all four say their stat (and your ribbon on that course). "⚡ Quick train" opens the old horse and stat games; a perfect Quick train game gains the same as a score of 70 (quality capped at 0.85).
- [ ] Tapping Sprint Lane (or "Ride" at its picture sign) puts you on your active horse (it's called if you weren't riding) at the white start line on the oval's north straight, facing west. Big 3, 2, 1, then "Go!" and "Giddy-up!". The horse can't move or hop during the 3-2-1.
- [ ] While riding: push the stick (even half-way) and the horse gallops by itself at full course speed; only the next hoop glows gold; dark hoofprints lead to it; riding through gives a ✨; three lap dots at the top: done laps gold, the lap you're on orange. No timer anywhere. Near a hoop the horse is nudged gently toward it, never steered without you.
- [ ] After the last hoop: "🏁 To the finish line!", the start/finish line glows gold and hoofprints lead to it; the ride ends as you cross it. On Mud Splash, after the last piece the 🏁 Finish arch glows and the prints lead there.
- [ ] Phones: the Gallop button goes away and a big ⬆️ Jump button appears bottom-right, above the dock (not under the Ride button). It hops the horse and never throws you off. Keyboard Space and gamepad A hop as usual; gamepad R2 gallops in free riding too.
- [ ] Other riders (training or free riding) and players on foot pass straight through you during a ride; rails still stop you; you never sink into the ground or the hill. Off a course, walkers and ride horses bump as before.
- [ ] After three laps the end card shows the stars one at a time, then the stat bar grows with "+x.x Speed!" (and "Rested bonus ✨" after 3 h away), then the ribbon: 🥉 for finishing, 🥈 from 75, 🥇 from 90 if the ride was quick; "New!" the first time. "Ride again" starts over at the start line; "Done" closes the card.
- [ ] After the week's 6 points: the card says "Speed is full this week. Ride for stars!" and the stat doesn't change. Rides never cost Energy.
- [ ] Mud Splash starts at the arena's north-west corner. The horse lopes round the lanes and slows to a canter in the darker pole lane by itself. "Splash! 💦" in a puddle, "Clean hop!" only when the horse is in the air over a log, "Nice bend!" passing a pole on the hoofprints' side. Riding through a log without hopping just doesn't score: no message, no stumble. The 🏁 Finish arch ends the ride and the card shows splashes, hops and poles.
- [ ] Ending early: "✕ Stop", Get off, riding out of the ground or the arena for a couple of seconds, or a queued race starting all end the ride with a kind note and no gain ("Your race is starting! Training paused.").
- [ ] Standing at the start for two minutes without riding ends with "Let's try that one again!": no stars, no gain, no job progress.
- [ ] Two rides within 4 seconds: "Your horse is catching its breath". More than 40 in an hour: a kind rest note.
- [ ] Rejoin: the tiles still show your ribbons (🥉🥈🥇) for that horse.

Gate Break, Hill Climb and Easy Rein (T3):
- [ ] Gate Break puts you in the practice gate in the oval's infield, facing the flag; two red doors close in front of you on your screen. The 3-2-1 has no "Go!" for Gate Break; the horse stands by itself; "Ready…" shows and stays; after 1.5–3.5 s the doors swing open, "GO!" (and the bell, once its sound is uploaded). Push and the horse gallops down the lane to the yellow flag. "Great start!" for a quick go, "Good start!" or "Off you go!" otherwise; never a time on screen.
- [ ] Riding into the gate with the stick still pushed never launches you out: the horse stops in the middle of the stall and waits until you let go of the stick once. Pushing before the bell after that (or edging out of the gate): "Wait for the bell!", the doors glow gold and hoofprints lead round the loop back to the gate; the horse canters back and stops by itself in the stall; that break runs once more. Early again: "Off you go! Ride to the flag!", the doors open and the flag glows (an easy start, no fail).
- [ ] After each flag: "Back to the gate!", canter round the loop (hoofprints), the horse stops in the stall, "Ready…" again. Three dots fill, one per break; the ride ends at the third flag (about 40 s).
- [ ] You can ride into and out of the practice gate without ever catching on it (it never collides).
- [ ] Hill Climb: Pip, a small palomino in a teal "Pip" cloth, stands a little ahead of you at the start line; only you see him. After "Go!" he gallops two laps, weaving and changing pace, over the hill. A glowing ring sits behind him: inside it the ring turns gold and your horse keeps Pip's pace by itself; drop back (however far) and a gallop catches you up. Pip is where the server says he is: on a laggy connection the ring still turns gold when you follow him. Riding into the infield counts as out of the ring. Out of the ring for a while: "Stay with Pip!" (gently, now and then). The ride ends when Pip finishes; two dots for his laps.
- [ ] Settings (For grown-ups → Settings): "Easy Rein" On/Off, off at first. On: on every course the horse steers itself strongly toward the next hoop, piece, flag, gate or Pip's ring while you push forward (pull the other way and you can still turn round); stars and gains are the same as without it. It stays as you set it after a rejoin.

- [ ] During a ride and its end card, Explorer shows the attribute TrainingRide = true on your Player; it stays while the card is up and clears on Done, Stop or an early end (or after 90 s as a safety net).
- [ ] Output: lines like `[Training] <id> speed: 12% of 430 samples too fast or teleported (3 stale, 0 off course) (log only)` are expected only now and then; note how often they appear on a phone and the stale count (freezes) (the floor stays log-only, `enforceFloor = false`).

Ghosts, Ride together, rosettes and Quick train (T4):
- [ ] Ride Sprint Lane or Mud Splash, then ride it again: a see-through horse (your best ride, "👻 Your best", in the coat you rode it on) runs the course beside you in time with your ride, legs moving, and disappears when its ride ends. It only changes when you beat your best (more stars, or as good and quicker). Gate Break and Hill Climb have no ghosts. Rejoin later: it's still there (needs API access in Studio; without it ghosts last until you leave).
- [ ] Settings → "Share my ghost with friends" (off at first). With it on (and visits not Nobody), a Roblox friend in the same server who rides that course alone sees your ghost labelled with your name; with it off they never do.
- [ ] Course picker → "👫 Ride together": lists Roblox friends at the paddock, path or Training Ground who aren't racing or riding; strangers never show. Pick a friend and a course: "Invite sent!".
- [ ] The friend sees a card at the top right (not over the thumbstick): "🐴 <name> would like to ride <course> with you!" with "👫 Ride together" and "Not now"; no countdown on it, and a tap in its first half second does nothing. "Not now" (or 20 s with no answer) closes it and the inviter hears "<name> will ride another time"; "Ride together" tells the inviter "<name> said yes!" first. After "Not now" the same friend can't invite again for a minute; nobody gets more than three cards in five minutes. A friend in Tack & Paint or another shop or game panel is answered "busy" automatically.
- [ ] "Ride together": both of you are put at the start side by side (both in the practice gate for Gate Break, where your friend fades while you wait in the stall), one shared 3-2-1, the same Pip in Hill Climb; you ride through each other. Each end card shows your own stars, gain and ribbon, plus a line for your friend with their stars and ribbon only ("still riding…" until they finish, "is taking a rest" if they stop or leave); never times or who was first. A later solo ride's card never shows that line.
- [ ] Settings → visits "Nobody" (either of you): no Ride together list or invites ("Ride together is off").
- [ ] A gold ribbon puts a gold rosette on that horse's stall under its name plate, one per course; four golds, four rosettes.
- [ ] Quick train (T4, unchanged by T5): the four games look and feel as before (the reaction time and the hold game's countdown are no longer shown: no timers on screen); "Get ready…" for a second, then play (holding HOLD during "Get ready…" starts the climb at GO); "Next one!" when a Sprint Lane round passes, "All done!" when the climb ends; mashing Mud Splash scores low. The score shown at the end is the server's; a perfect game still gains like a score of 70. Closing the card mid-game (✕, tapping outside, or a race starting) gains nothing and toasts nothing, and you can start another game straight away; a game with no taps gains nothing.

This week's course (T5):
- [ ] The "⭐ Training" picker's Mud Splash tile says "This week's course" with four small ribbon icons under it, one per layout: the ribbon you've earned on that layout (🥉🥈🥇) or a faint 🎀, and this week's ringed in orange. No dates, days, timers or "last chance" anywhere.
- [ ] The arena shows this week's layout: for the week starting Monday 2026-10-05 that's layout 3 (two puddles in the first lane, two logs in the second, the poles and the darker canter lane in the fifth). Ride it: the dots, glowing pieces, hoofprints and finish arch all match what you see, and a clean, quick ride is gold. A ribbon lands on this week's icon only.
- [ ] The other layouts: before pressing Play, set `GameConfig.training.grit.layoutPin` to 1, 2, 3 or 4 (0 = by the week). Each has its canter lane in a different place (lanes 4, 2, 5, 3), 4 puddles, 3 logs and 4 poles, nothing on the turns and no log on the walk from the street gate to the south gate; the start line is always in the same corner. A perfect ride is gold on each. Layout 1 is the Mud Splash from before T5, and an older save's Mud Splash ribbon shows on its icon.
- [ ] Each layout has its own ghost ("👻 Your best" on that layout only). A gold on any layout puts one Mud Splash rosette on the stall, not one per layout.
- [ ] Riding together: both riders get the same layout. Quick train's Mud Splash game is unchanged.
- [ ] If you're riding Mud Splash when the week turns over (Monday 00:00 UTC: Sunday evening in the US), your ride keeps its layout to the finish; the arena changes to the new one as the end card opens. Everyone else sees the new layout straight away.

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
- [ ] A horse whose best Rating passes its league ceiling (Rookie 58) sees "Comet is too good for Rookie now. Win the Cup!"; its Cup opens; Practice stays open.
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

## Race quirk fixes and race feel (D-055)
- [ ] The horse that crosses the line first is the winner on the results card, every race. Riding in lane 1, you are not always out in front.
- [ ] No horse slows down, stops or slides backwards at the checkpoints or the Final Burst. Legs stay in a gallop the whole race.
- [ ] Horses ease out of the gate, and the stalls clear as the bell rings.
- [ ] "3", "2", "1", then "GO!" with the bell. The camera is in the saddle from "3". Taps before the bell do nothing. (The drum tick is silent until the sound effects are uploaded.)
- [ ] A quick double tap (a finger bounce) still scores; a real second tap later in the pass says "One tap!". A pass you don't tap shows no word, only a grey glow; a very early or late tap says "Early" or "Late".
- [ ] Only Space, Enter, click, touch, gamepad A or R2 tap. W, the arrow keys, I and O don't; the first other key shows "Tap: SPACE or click" once.
- [ ] Riding: no running-order board, no win %; the race map, place badge and badge arrow show where you are. The place badge doesn't flicker after a Great tap.
- [ ] Phone (Device emulator, 844×390 and 667×375): the Final Burst bar is fully visible (board, map and badge step aside); the race map and badge are smaller and don't cover the slider; the results card and its replay buttons are on screen and not under the dock.
- [ ] Results: "Watch the finish" works straight away (even while horses are pulling up). Done, or the next race on that course, gives you back the normal camera and jumping.
- [ ] Watching: near the course you get the cheer strip at the top and a slim board (top 3 plus your rider on a phone, no %). Walk to the barn or open a shop: the race HUD hides, and no results card or burst text appears for races you didn't watch.
- [ ] The first race after a server start has running legs on every horse.

## Riding feel and world fixes (D-056)
- [ ] Phone: while riding, a ⬆️ Hop button sits where Roblox's jump button was (Gallop above it) and hops the horse; the Get off button is never under your right thumb.
- [ ] Riding at normal speed the horse trots; hooves don't slide along the ground and the gallop doesn't float.
- [ ] Ride into a water trough, a garden bed and the fountain: the horse stops at them. Ride through the training course poles and logs: they never stop you.
- [ ] Get off next to a fence or a closed plot: you land where the horse was, not on the other side.
- [ ] Call your horse facing a wall: it turns to find room, or says "Find an open spot".
- [ ] Your horse's stall is empty with "🐴 … is out riding" (or "🏁 … is at the races") while it's out, with no Care prompt; it's back when you get off or the race ends.
- [ ] Phone: 💎 is a small pill at the top right; steering with the thumbstick never opens a panel; 🐴 in the dock opens My Horses. The 💎 button and the Tack & Paint counter are gone in line, in a race, on the results card, for 2 minutes after and during a training ride.
- [ ] Taming: "Getting to know you…" then "💖 Friends!" (a new horse arrives) or "Not yet, try again!"; the wild horse walks back into the meadow, never bolts; wild horses turn smoothly.
- [ ] PC: holding Shift while riding gallops and doesn't switch Shift Lock on.
- [ ] The Trail bridge sits on the ground; the Race Board's board fits its wooden frame.
- [ ] Still on a race horse after your race: Ride or Map says "Tap Done first".

## Rail coordinates and drawn posts (steering S1, D-054)
- [ ] Posts are drawn: over a few races your horse starts from different stalls, not always the inside one, and other riders too. Lane badges, saddle-cloth numbers and the race strip's numbers still match the stall each horse left from. Nothing on screen announces a draw.
- [ ] Horses level with each other stay side by side through the turns (abreast across the track), instead of outer horses drifting ahead or behind on the bends. On the straights nothing changes.
- [ ] Everything else looks and plays as before: the gate, horses easing out, gaps, the order across the line (the result), the race map's oval dot following your horse, and replays showing each horse in its own lane.

## Steering on the server (steering S2, D-054)
- [ ] From the gate, horses hold their posts, then head toward the rail before each turn. Most settle one off the rail (lane 2); about a quarter of the bots take the rail, a few sit one lane wider.
- [ ] A horse blocked from moving in eases back (up to about 3 lengths) and slots in behind; horses never overlap or bump. Often a line of horses forms in lane 2 and others wait outside it.
- [ ] If you don't press anything, your own horse steers itself the same way (Smart Steer).
- [ ] At the far turn lanes lock. After it, horses never run through each other: a horse catching another in its lane swings out to pass, or waits a moment behind it until there's room. Lane changes glide smoothly (no stutter); nothing pops or jumps.
- [ ] The order across the line is still the result, and the results card looks as before (the trip line comes in S4).
- [ ] Output shows no RaceService errors around the far turn. With `GameConfig.steering.enabled = false` the horses stay in their posts all race, exactly as before.

## Steering controls (steering S3, D-054)
To see the buttons on a new profile, ride 3 races first (or set `totals.races` to 3 in the saved profile).
- [ ] **First three races:** no ◀ ▶ buttons, no bell, no chips; your horse uses Smart Steer even if Settings has it Off, and the `[Trip]` line shows `intro` with tau 0 for you.
- [ ] **Fourth race:** ◀ In and Out ▶ appear bottom-left at "GO!", with a see-through thumb pressing ◀ In and "Steer to the rail before the turn ◀" for about 5 s. The tip shows once, never again.
- [ ] **Phone, two thumbs:** the buttons are big (at least 88 px), sit above where the thumbstick would be and clear of a notch, and nothing hides behind them: on a narrow phone the tap words move to the right of them. There's no thumbstick or jump button during the race; both come back after the race, and after a respawn. Every other touch still taps the slider.
- [ ] **Keyboard:** A or ← moves you in, D or → out, while you tap Space. Your character never walks, steering keys never show "Tap: SPACE or click", and **the camera stays put** when you press ← or → (they steer instead of turning the camera). In your first three races, ← → turn the camera as before.
- [ ] **Gamepad:** D-pad left and right steer, and so does a flick of the left stick (one lane per flick; let the stick come back to the middle before the next). A and R2 still tap.
- [ ] **No steering press ever scores as a tap:** press only ◀ ▶ (or A/D, or the D-pad) through a few passes: no tap word, the speed meter dips as for untapped passes, and the Final Burst is never spent.
- [ ] How your horse answers a press (the look cue, smooth glides, waits, brushes) is checked in "Natural steering (D-057)" below.
- [ ] **Smart Steer:** after a press your horse is left alone for 5 s, then heads in before the turns again, never out (a rider who took the rail keeps it). With Settings → Smart Steer Off, your horse changes lane only when you press.
- [ ] **The lock:** three soft bell ticks (silent until `lock_tick` is uploaded), then "Lanes locked!" at the far turn on every distance. The buttons grey, then fade before the Final Burst. With Reduced Motion on, nothing pops or shakes.
- [ ] **Chips:** "Saved ground!" leaving a turn on the rail (after you've steered that race); "Tucked in!" with wind lines while you sit behind a horse in your lane (at most 3 a race); "The rail is shorter on turns ◀" when you steer yourself and are wide going into a turn (at most twice a race). No chip ever says you lost a place, and nothing counts down.
- [ ] Steering counts now (`GameConfig.steering.scale = 1`): at the lock the arrow on your place badge may move a little. The results card's trip line is checked in the next section.
- [ ] Output prints one `[Trip]` line per race at the lock (riders' posts, Smart Steer or not, tau, how presses were answered). A rider leaving mid-race goes to Smart Steer, with no errors.

## Natural steering (D-057)
D-057 is on for every horse: players, Smart Steer and bots. It brings S-curve lane changes, a body turn, no zig-zag, the boxed-in arrows and chips, and brushes. The pass and fail lines come from the plan (`docs/plans/natural-steering.md`, section D).
- **Who:** kids aged 8–11 on phones first, then keyboard and gamepad.
- **Profiles:** testers need the buttons. Ride 3 races first, or set `totals.races` to 3.
- **How to test:** don't explain the arrows before the first races; ask the questions after.

### 1. Kids on phones (ages 8–11)
- [ ] **Natural look** (playtest 1): three races with mashing riders, in the chase view and a 3x replay.
  - **Pass:** no tester says "zig-zag", "wiggle", "slide" or "snap", and at least 2 of 3 say it looks "like real horses".
  - **Fail:** a tester points out a horse swerving a whole lane just before the line.
- [ ] **Blind 0.8 vs 1.0 s** (playtest 2): the same kid rides two races at each glide, in random order.
  - The 0.8 s glide is `laneSpeedMax = 1.667` and `laneAccel = 5.56`, set in a test place's `GameConfig.steering`.
  - **Pass for 1.0 s:** kids can't tell the two apart better than chance, or don't prefer 0.8 s. Otherwise switch: set both values in `GameConfig.steering` and `trip.CONFIG`, then run `python sims/steering.py --write`.
- [ ] **Boxed in** (playtest 3): after 3 races with the buttons, ask "What does the grey arrow mean?" and "What happened when you were stuck?".
  - **Pass:** at least 60% answer "can't go that way", "a horse is there", or "waited or eased back for a gap", and nobody says they were "punished".
  - **Fail:** more than 30% of kids press again while the ring fills, or any kid says the arrows "stopped working".
- [ ] **Brushes** (playtest 4): two kids side by side; one keeps pressing into the other (three presses).
  - **Pass:** the bumper can say "I bumped, I slowed down".
  - The first brush shows "Bump! Press once, then wait for a gap", once per player.
  - **Fail:** more than 1 in 10 bumped kids get upset (watch, or ask), even at no cost. Then set `brushCost = 0`, and `brush = "off"` if it persists.
  - **Fail:** kids call the bumper's cost unfair.
- [ ] **Load** (playtest 5): the same kids race on D-057 and on D-054 (the switch-back below, in a test place).
  - **Fail:** the slider score S drops more than 2 points on average with D-057.
- [ ] **Latency** (playtest 6): a phone on a throttled link, 0.25 s each way.
  - **Pass:** the look cue shows on the press frame, and there's no sideways snap-back in 50 presses.
  - **Fail:** a tester notices a "fake start" in 50 presses into blocked lanes.
- [ ] **Phone layout:**
  - the grey look, the 🐎 icon and the wait ring fit inside the buttons' safe area (no clipping near a notch);
  - the chips ("No room yet", "Gap!", the bump tip) sit above the buttons and can be read at a glance.

### 2. Keyboard and gamepad
- [ ] A/D, the arrows, the D-pad and stick flicks give the same look cue, ring, wobble and chips as the on-screen buttons. A press into a blocked side shows on the on-screen arrow.
- [ ] Mashing a key or the D-pad is as calm as mashing the buttons: one quick change of mind, then the horse holds its line.
- [ ] Two quick presses into a horse beside you never brush; a third does.

### 3. In Studio
Watch from the chase view, from the side, and in a 3x replay. Brushes need Studio Test with 2 players.

**Motion**
- [ ] **Smooth lane changes:** a horse eases into a lane change, glides, and eases out (about 1 s a lane, 1.6 s for two). No horse slides sideways at a constant speed, starts or stops with a jerk, or reverses in the middle of a glide.
- [ ] **Two lanes at once:** press ◀ twice quickly; the horse glides two lanes in one smooth move, with no stop in between.
- [ ] **The body turns into the move:** a few degrees toward where the horse is going (never more than 10), with a slight lean, then it straightens as it lands. It never looks like it's skidding or drifting sideways. Nothing snaps: not at the far-turn bell, as a glide lands, when a replay starts, or at the line.
- [ ] **Your press:**
  - Your horse's head and body turn about 3 degrees toward the press at once, on your screen only.
  - If the lane is free, the move follows smoothly, even with the network simulator at 200 ms. If it must wait, the turn relaxes within a moment.
  - Presses the horse can't act on yet show no look: again within a blink, against a lane change under way, straight back after landing, or in the second after your own brush. So mashing never shakes the head.
  - Your horse never ends up in a lane the server didn't give it, and never snaps back.
- [ ] **No zig-zag:** mash ◀ ▶ as fast as you can for 10 s. The horse makes at most one quick change of mind, then holds its line for a few seconds while the ring fills; it never wiggles back and forth.
- [ ] **At the lock:**
  - A press made just before "Lanes locked!" may start its slide just after the chip, because your screen shows the server a moment late. That's expected.
  - After the lock, horses that need room move over early in one smooth move. Watch the last 2 s before the line in a dozen races: none swerves a whole lane, and a horse that moved over doesn't swing back within a few seconds.
- [ ] **Lag:** with the network simulator at 200 ms and packet jitter, lane changes still look smooth on every screen: no stutter, no stall-then-catch-up, no horse jerking back.
- [ ] **Chase-camera yaw:** the camera follows the track's heading, not the horse's body.
  - On the backstretch, change lanes a few times while watching the rail and the horizon in the chase view.
  - **Fail:** the camera visibly swings more than 3 degrees on a lane change.
  - To measure it, paste this into the command bar in the client view during a Test, then change lanes on a straight: `local c=workspace.CurrentCamera local l game:GetService("RunService").RenderStepped:Connect(function() local v=c.CFrame.LookVector local y=math.deg(math.atan2(-v.X,-v.Z)) if l and math.abs(y-l)>0.2 then print(("camera yaw %.1f"):format(y)) end l=y end)`. On a straight, the printed yaw must stay within 3 degrees through the glide.
  - If it fails, try `steerView.yawGain = 0.7`, or a track-aligned camera subject (plan N3).

**Boxed in** (riders with the buttons only; spectators and a rider's first 3 races see none of this)
- [ ] **Out ▶ greys** (soft grey, a small 🐎 on its top edge) a moment after a horse settles beside you on the outside, and comes back as soon as there's room. A horse sweeping past doesn't make it blink. It never turns red or buzzes, and pressing it still works (the press waits).
- [ ] **◀ In greys only when you're truly trapped:** a horse inside and no gap to ease back into, which is rare. When you could ease back behind the horse inside, ◀ In stays normal, and pressing it eases you back and slips you in ("Tucked in!"). Nothing greys at the rail or the outside lane.
- [ ] **Waiting:**
  - **Inward:** press ◀ with a horse inside and no gap. A thin ring lights round ◀ while it waits, then the horse moves in when a gap opens, with "Gap!" and a soft chime if it waited half a second or more. There's no "Gap!" after easing back, because "Tucked in!" says it.
  - **Outward:** press Out ▶ with a horse outside. The ring fills across Out ▶ over 1.5 s; if no gap comes, the arrow wobbles gently once and the press is forgotten, silently.
  - Mashing never earns a string of "Gap!" chimes.
  - With Reduced Motion on: no wobble, no breathing ring.
- [ ] **"No room yet"** shows above the buttons after a second of waiting, at most once every 10 s, and never right after another chip. It never says "boxed in", mentions points or a cost, or hurries you.
- [ ] **At "Lanes locked!"** the boxed-in look clears and the buttons go the usual locked grey.

**Brushes** (two riders side by side)
- [ ] **A brush:** with a horse right beside you and no gap to slip into behind it, press toward it three times within 2 s. The first press waits; the second is the same try.
  - Your horse leans about a foot toward the other horse, nods, eases back a few feet and can't steer for a second. The lean starts and ends softly.
  - The other horse only nods and keeps its place.
  - A soft tick plays at your horse (silent until `count_tick` is uploaded).
  - Nothing stumbles, flinches or looks hurt; no flash, no text over the horses.
- [ ] **Pressing again never brushes:** press toward the horse, then once more half a second or a second later, as a kid does when nothing seems to happen. The press just waits. One press never brushes, nor does pressing again many seconds later. Bots and Smart Steer never brush.
- [ ] **Your screen:**
  - Your first brush ever shows "Bump! Press once, then wait for a gap", once per player, never again (not in a new session either). After that, "No room yet" at most, under its limits.
  - The chip shows as your horse leans, not before. No blame, no cost words; the other rider sees nothing.
  - A brush that clears a waiting press doesn't wobble the arrow.
- [ ] **No brush starts after the lock.** One from the last moment before it can still be drawn just after "Lanes locked!" shows, never later.
- [ ] **A late brush** (network simulator at 300 ms with jitter): a brush that reaches your screen late still starts from the beginning, with no horse snapping a foot sideways. One that arrives after its moment has passed isn't drawn at all.
- [ ] **Smooth:** the horse that brushed eases back without a jerk, and horses never draw through each other.
- [ ] **Results:** no brush line on the card; "Good trip" may be a star lower after several brushes. The bumped rider's card is unchanged.

**Replays, logs, grown-ups**
- [ ] **Replays:** "Whole race ×3" and "Watch the finish" show the same smooth glides, the turn and lean, and the brushes' lean and nods, slowed down too, with no text.
- [ ] **Logs:** the `[Trip]` line at the lock gives each rider's post, tau, brushes with how many went into each other horse (`brushes 3 (into post 4 x2, post 6 x1)`) and cost. It ends with the presses' answers, "held by the reverse or weave gap N, waits dropped N".
- [ ] **Grown-ups page** (right under the steering line, after "How races work" and before the Diamonds lines):
  - "Horses can get boxed in, like in real racing: they wait for a gap or ease back to find one. There's no penalty for being boxed in; a horse held wide just runs a little farther."
  - "A rider who keeps pressing into a horse alongside makes the two brush shoulders. A brush costs the horse that bumped a tiny bit (a third of a point at most), never the horse that was bumped. Bots and Smart Steer never bump."

### 4. A week of logs (playtest 7 and the plan's risk lines)
- [ ] **Brush charges:** fail if riders with the buttons are charged in more than 5% of races (a `[Trip]` cost above 0). The sims expect under 1% for kids who press once and again, and about half for mashers.
- [ ] **Griefing:** fail if one rider brushes the same horse 3 or more times (`into post N x3`) in more than 1% of races.
- [ ] **Chip spam:** fail if riders with the buttons see more than 2 "No room yet" per race on average. Count them in the phone sessions, since the chip is client-only.
- [ ] **Sluggish glide:** fail if more than 20% of glides get a second same-way press before they land. Watch it in the sessions; the `[Trip]` line's queued answers are a rough guide. Then try the 0.8 s glide.
- [ ] **Also record:** reversals held by the gaps per race, waits dropped, brushes and charges per race, τ by post, the Smart Steer kid's mean, and how often τ hits the clamp.

### 5. The switch-back to D-054
Try it in a test place first. The quick switches:
- **Brushes off:** `brush = "off"`. The baseline doesn't change (Smart Steer never brushes).
- **Visual-only brushes:** `brushCost = 0`.
- **The 0.8 s glide:** see playtest 2.

The whole switch-back:
1. In `GameConfig.steering` (`game/src/shared/GameConfig.luau`) **and** `CONFIG` (`src/trip.py`), set eight keys (exactly what `Trip.d054Config` and `trip.d054_config()` build):
   - `glide = "linear"`, `chainWindow = 0`, `reverseGapSeconds = 0`, `weaveGapSeconds = 0`;
   - `pressBounceSeconds = 0`, `glideReserveFeet = 0`, `blockedPress = "d054"`, `brush = "off"`.
2. Regenerate:
   - `python sims/steering.py --write` (about 50 minutes on 12 cores). `TripBaseline.luau` then equals the table in `tests/fixtures/trip_baseline_d054.json`.
   - `python tests/fixtures/make_fixtures.py --d057`.
   - `tests/test_trip_d057.py`'s game-config tests then need pointing at D-054. `tests/test_trip.py` already holds the D-054 config to every D-054 promise.
3. Check in Studio:
   - glides are 0.6 s and linear again; bodies don't turn or lean; there's no look cue; your own glide starts on the press, as before D-057.
   - The boxed-in arrows still read the server's side states. `steerHud.greyArrows = false` and `steerHud.waitRing = false` turn them off.

## Replays and results (steering S4, D-054)
Plan section D, from your 4th race on (the buttons are shown):
- [ ] **Results:** under "You rode ★★☆" comes "Good trip ★★☆" (one to three stars, never none). "Your trip gained you N places!" shows inside the card only when your trip gained places, with "Your riding gained you N places!" above it when riding did too. No line ever says you lost a place.
- [ ] **First three races:** there's no trip line at all.
- [ ] **Replay lanes:** "Watch the finish" and "Whole race ×3" show every horse in the lane it ran on your screen: the moves to the rail, the tuck-ins and the make-room passes after the lock. Nothing jumps or overlaps.
- [ ] **Your line:** a gold ribbon on the track follows your horse up to the lock, green with chevrons through turns where you saw "Saved ground!". Wind lines show while you were tucked in. A bar across the track marks where lanes lock ("🔔 Lanes lock"), and "Lanes locked!" shows as you pass it in "Whole race". There's no ghost of an ideal line. Done clears the ribbon and the bar.
- [ ] **Watching or first races:** a race watched, or ridden without the buttons, shows the lock bar but no ribbon.
- [ ] **The camera** still follows your horse (side or behind); with Reduced Motion it stays fixed at the finish. Legs rest when the replay ends.
- [ ] **The finish:** two horses close together in one lane at the line finish staggered (one edges half a lane over in the last moment), never through each other.
- [ ] **No jerks:** after the lock, no horse ever snaps backwards. Watch horses swinging out to pass, two horses moving into the same lane, and the last second before the line.
- [ ] **Understanding** (plan section D): after 5 races, ask "What do the arrows do?" and "What does Tucked in mean?". Do kids who never touch the arrows end with "Good trip ★★☆"?

## Playtest-safe fixes (horse life stage 1: D-065, D-061 core, D-058 label, D-064 basics)
Use Play Solo, or Test → Clients and Servers with 2 players, plus Device emulator → a phone in landscape. No tools needed.
- [ ] **No league lockout.** Two players: player 1 (a Bronze save, or the Studio cheat) taps RACE on dirt; player 2 (new, Rookie) taps RACE. Player 2 never sees "That race is for Bronze horses"; they get the turf course, or wait ("In line! next race") and race next.
- [ ] In the picker, a card another league has claimed is grey, shows that league's badge and "👀 Watch · for Bronze horses", and is never preselected; tapping it lays hoofprints to the grandstand. With no card for your horse, the button says **Join the line!**
- [ ] Tap ✕ while waiting in the line: the RACE! button comes back and the card stays as it was.
- [ ] **Ready / Napping.** After one Bronze race the dock still says **Ready** and shows 4 horseshoes; after 5 it says **Napping**. The Stable Board says "napping" only then.
- [ ] Energy is the same horseshoe in the dock, the race picker's horse cards and My Horses; no ⚡ next to Energy. The picker's shortest race reads **🐇 Short**.
- [ ] **Phone dock.** On the phone emulator the dock is just your horse card, 🏁 RACE! and ☰; every dock button is at least the size of a fingertip (about 1 cm on a laptop screen) and the words are readable. ☰ opens Green Cash, My Horses, the Stable Board, the Map and Ride; any of them closes it. On a laptop the dock is unchanged.
- [ ] The player list shows no Green Cash or Wins column.
- [ ] **Sync can't stall.** In the command bar, `require(game.ServerScriptService.Server.Profiles).decorators[1] = function() error("x") end`, then do anything (feed, ride, race): the client still updates (no "loading" forever). Output shows one `[Profiles] decorator ... failed (skipped)` warning, not one per update.
- [ ] **Retire.** Ride your horse, open My Horses, tap Retire on it: it says you can't while riding. The same while in line for a race or on a training ride. Another horse at home still retires.
- [ ] **Locked save (needs API access and a published place).** Join, then leave and rejoin within a few seconds from another server: you see "🐴 Opening your stable…" with **Try again**, never a kick; the stable opens within about 5 minutes at most (as soon as the old server lets go). Leaving while it waits is fine.

## One race button and the queue card (horse life stage 2, D-061)
Use Play Solo, or Test → Clients and Servers with 2 players, plus Device emulator → a phone in landscape. No tools needed.
- [ ] **One tap.** A new player picks a starter, then taps the big **🏁 RACE!** button ("with Comet ▶" under it) once: no picker opens, and they are in a gate within 20 seconds (15 s countdown plus the 3, 2, 1).
- [ ] **The queue card.** While in line a card sits at the top: a ring of dots that empties as the big number counts down from 15, the gate's 8 slots with your horse's name and coat dot in gold (▶), and "🤖 Bots join at 0". With 2 players, the second player's horse name and coat dot appear in the next slot on both screens.
- [ ] **Wait away from the track.** After tapping RACE!, walk to your barn and brush your horse (Care → Groom): it works, and the card stays on top. About 3 seconds before the gate, the card turns gold and says **Race time!** with hoofprints stepping to **GO!**; the care card closes and you are in the gate for the 3, 2, 1. The same while riding your own horse or walking on Fair Street.
- [ ] Waiting while the other course's race runs: the card says "You race next!" (🏇); with no course free, "Finding a race…". The ring's dots chase each other while you wait (still under Reduced Motion).
- [ ] ✕ on the card leaves the line (the RACE! button comes back). 🔀 **More** opens "More choices" (another horse, Practice, the Cup, a course); joining there moves you.
- [ ] A horse at 0 Energy outside Rookie shows **🎈 PRACTICE** "with Comet ▶" on the button and joins a Practice race; a horse past its league's ceiling shows **🏆 CUP!**.
- [ ] Bots have horse names made of the name-chip words ("Lucky Star", "Pepper Socks"), never anything like "Player123".
- [ ] **Training shows.** A fresh Rookie horse wins roughly 1 race in 4 against bots on your own; after a few days of training (Rating near 58) it wins noticeably more, about 1 in 3. (The sim's numbers: `python sims/economy.py --solo`.)
- [ ] On the phone emulator the card fits across the top without covering the dock, every word on it is readable, and ✕ and More are fingertip-sized.

## Visiting friends' barns (horse life stage 5: D-060, D-042)
Use Test → Clients and Servers with 2 players, plus Device emulator → a phone in landscape. Studio's test players are **not** Roblox friends, so the first block needs no tools; the second needs two accounts that are friends on a published test server.

**Two players who aren't friends (Studio):**
- [ ] Player 2 opens the Map: a sixth big button, **👫 Friends' barns**. Tapping it shows "No friends' barns here yet" and the Tour stamp line. **Player 1's barn is not on the list.**
- [ ] Player 2 walks Barn Lane to player 1's gate: the gate stays closed (can't walk in). Standing at the post box from the lane shows no "Drop a carrot" prompt.
- [ ] Nothing anywhere shows how many people visited, liked or toured a barn.

**Two friend accounts (published test server):**
- [ ] Player 2: Map → 👫 Friends' barns shows player 1's **face and name** with "🏡 Visit ▶". Tap it: player 2 lands on Barn Lane **just outside player 1's gate**, facing in (never inside the barn), with "Welcome to …'s barn! Pat each horse for a stamp".
- [ ] At each stall door, **Pat** works: hearts over the horse, "Comet nuzzles you! 1 more to pat for a stamp", then "Tour stamp! You toured …'s barn". Player 1's horses gain **no bond** from pats (My Horses). Patting again later never gives a second stamp; the Map's line reads "Tour stamps: 1 barn toured".
- [ ] **Treat** once: "+1 bond". A second treat the same day says "You gave a treat here today. Come back tomorrow!". Player 2's own bag is unchanged.
- [ ] At the post box, **Drop a carrot**: player 2 has one fewer carrot; player 1 gets "A friend left you a carrot! (1 today)" (no name), one more carrot, and a little carrot pile appears on the post box. A second drop the same day is refused.
- [ ] Player 2 can't feed, groom, muck out, plant or harvest at player 1's barn (no prompts, and the server says no).
- [ ] While player 2 is in the yard, player 1 sees a big **🚪 Close gate** button over the dock (on the phone emulator: over the dock at the left, clear of Hop and Gallop). One tap: player 2 is walked out to Barn Lane with "…'s gate is closing. Bye for now!", a wooden bar crosses the gate, and the button turns into **🔓 Open gate**. Player 2's list now shows player 1 greyed with "🔒 Gate closed" and can't travel there. Tap **Open gate**: the bar goes, the list shows "Visit ▶" again.
- [ ] Player 1 sets Settings → "Who can visit my stable?" to **Nobody**: player 2 (in the yard) is walked out, and player 1 disappears from player 2's list.
- [ ] A horse out riding or at the races has an empty stall: no Pat or Treat prompt on that door.
- [ ] For grown-ups page: the 🏡 Visiting friends' barns paragraph reads clearly.

## Spa Day and rest cues (horse life stage 4, D-058)
Use Play Solo (or 2 players), plus Device emulator → a phone in landscape. No tools needed. Spa Days count by the server's UTC day.
- [ ] **Yawn.** Race a Bronze horse until it has 1 Energy (4 cash races from full): in its stall it has a **🥱 Yawn!** bubble, and the dock still says **Ready**.
- [ ] **Nap.** One more race (0 Energy): it lies down in the straw with **💤 Napping** over it, and the dock says **Napping**. A bay, palomino or grey horse lies down (the new model, once Roblox approves it); other coats sink into a straw bed. While it's out riding or racing, its stall is empty and no bubble floats there.
- [ ] If that race left every one of your horses napping, a toast after the results says "Great day! Comet's dreaming of tomorrow."
- [ ] **Spa Day.** Walk to the Vet: a pale-blue wash bay with a "🛁 Spa Day" sign stands beside it, with a towel rack. Its prompt says **Spa Day**. Pick the napping horse: tap to rinse, brush and dry (the chips along the top go Rinse → Brush → Dry). The whole Spa takes under a minute.
- [ ] Afterwards: a toast "✨ Comet is squeaky clean! +1 Energy", the dock shows one horseshoe back and says **Ready**, the stall's bubble changes from Napping to Yawn, and the horse can race once more. Its next race shows sparkles drifting off it; the race after that, none.
- [ ] **Opens again tomorrow.** Go back to the Spa with the same horse: the button says **🌙 Spa opens again tomorrow**, with no clock or countdown anywhere. Another horse can still have its Spa today.
- [ ] At the Vet's door (Check-up) pick a horse: the card shows the Health Passport with a 🛁 Spa Day stamp, and two buttons, 🩺 Check-up and 🛁 Spa Day.
- [ ] The Stable Board can show the job "Give a horse a Spa Day", and a napping horse's tip says "Next: a Spa Day at the Vet" with GO taking you there.
- [ ] Nothing anywhere says hurt, sore, injured, limping or sick, and the horse never looks unwell: tired means a yawn and a happy nap.
- [ ] On the phone emulator the Spa's tap button, the chips and the Check-up / Spa Day buttons are fingertip-sized and every word is readable.
- [ ] Studio check: the wash bay doesn't block the street or the Vet's door, and the "Spa Day" prompt and the Vet's "Check-up" prompt don't overlap.

## Clarity pass (horse life stage 3, D-064)
Use Play Solo plus Device emulator → a phone in landscape (iPhone SE or similar, 375 px high). No tools needed. The new icons (horseshoe, rosette, sprout, dotted league badges) are on their own uploaded sheet; until Roblox moderation approves it they show as emoji (∩, 🎀, 🌱, 🏅).
- [ ] **One symbol each.** Ask a child "what does the star mean?" and "what does the horseshoe mean?": one answer each ("how well I rode", "how much energy my horse has"). Look for stars anywhere else: the dock, My Horses, the Stable Board, the picker, the market, the queue card, league badges and your stall plaque have none (🏇 marks the horse you ride, 📣 the horse you cheer for, ❤️ care, 🎀 monthly stamps, 🌱 a market horse's family line).
- [ ] **One results row.** After a race the card has **one** row of stars, "You rode ★★☆", and only when your taps helped: "Your taps gained Comet 2 places!" (from race 4, with the ◀ ▶ buttons: "Your taps and steering gained …"). No "Good trip" row, no % or purse.
- [ ] **The Next-thing pill.** Just above the dock a pill always shows **one** thing to do with a picture and a few words: "Feed Comet some hay", then "Brush Comet", then a job ("Ride in a race"), then "Race with Comet!". Tapping **GO ▶** takes you there (golden hoofprints to your barn, or straight into the race line for a race). A finished job shows "Get your job prize!" and GO opens the Stable Board. A napping horse with its Spa still open gets "Spa Day for Comet at the Vet"; after that, "Great day! Comet's dreaming of tomorrow." with no GO.
- [ ] **Pip's hint.** Leave the pill up and stand still for 20 seconds: a bubble "🐴 Pip says: tap GO and follow me!" appears once and the pill bounces. Walking around resets the wait.
- [ ] **Race cards.** Open RACE! → More choices: each course card is its league's colour with a dotted badge and one line ("Bronze · 🐇 Short · Dirt ☀️"), lane dots and a short status ("⏱ 12s", "👀 Watch"). Horse cards say "👍 Loves this race", "An okay day" or "Not its best" (no numbers). The Cup button says "🏆 Cup 🔒" until the Cup opens (no "pts").
- [ ] **Jobs inline.** Stable Board: three tabs, 📋 Today, 📅 Week, 🎀 Month (with your stamp count). Week and Month show every job with its progress on the board itself: no toasts. With finished week jobs, "🎁 Get N prizes" collects them; the tab shows 🎁 while prizes wait.
- [ ] **Words.** Every toast you see is short (10 words or fewer): try feeding with no hay ("No hay! Muck out a stall or visit Feed & Seed"), joining a race ("You're in line! You race when a course is free.").
- [ ] **Phone sizes.** On the phone emulator: the dock buttons show a picture and a word (Horses, Map, Jobs, More); every button on the picker, Stable Board and My Horses is at least fingertip size and every word readable; a panel taller than the screen scrolls up and down instead of shrinking its words (My Horses gets shorter and its list scrolls). The pill sits left of Hop and Gallop.

## Reasons to come back (horse life stage 6, D-063)
Use Play Solo (or 2 players), plus Device emulator → a phone in landscape. Months and days are the server's UTC calendar.
- [ ] **Monthly cloth.** Finish 4 monthly jobs on the Stable Board (each gives 🎀 ×2) and claim them. Shortcut in Studio: set `GameConfig.comeback.studioMonthStamps = 6`, Play, then finish and claim one monthly job. A toast says "🎀 You earned the Pumpkin cloth!" (October's), the Stable Board's tab says **🎀 Month 8/8**, and in Tack & Paint → 🐴 Tack the cloth shows **🎀 Earned!** with **Wear**: no price, no Buy, no Return. Wear it and ride: the cloth shows its 🎃 on both sides. Before you earn it, the shop shows only this month's cloth with "🎀 6 of 8 stamps. Do monthly jobs!"; other months' cloths are not in the shop.
- [ ] **Welcome Back Hay Bale.** Set `GameConfig.comeback.studioAwayDays = 4` and Play: a few seconds after you arrive, your horse trots up beside you next to a hay bale with a red bow, and a card says "🐴 Welcome back! Comet has a gift for you!" with 🌾 5 hay, 🥕 2 carrot seeds, 🍬 1 treat. Tap **💛 Thanks!**: the card goes, the items are already in your stable. Set it to 30 and Play again: the same gift, no bigger. Set it back to 0: no gift. (With saving on, changing `lastSeen` in the save to 4 days ago does the same.) Nothing says "we missed you", counts days, or mentions a streak.
- [ ] **Personal bests.** Race a Mile, then another Mile riding better (more Great taps): beside the results card a gold **🏅 New best! Mile 78** pill appears (not after the first race at a distance, and not when you ride worse). Open 📖 Book → **🏅 Bests**: each distance shows its stars and score, or "Race one!".
- [ ] **Photo Finish.** Win a race (a Rookie race with good taps): beside the results card a **📷 Photo** button. Tap it: the game's buttons vanish for a moment, then "📷 Nice photo!" with **💾 Save** and **📤 Share**. Each opens Roblox's own prompt (the game never uploads anything). Lose a race: no camera button.
- [ ] **Photo board.** In your yard, left of the Rosette Wall, a blue photo board with bunting: walk up, its prompt says **📷 Photo**; it takes the same picture. Stand your horse in front of it for a good one.
- [ ] **Horse Book.** The dock has **📖 Book** (on the phone emulator it is in ☰ More). It opens on Coats: your horse's coat in colour, the others grey with "?". Tabs (icon + word, fingertip-sized): Coats, Rosettes (1st/2nd/3rd places and training golds), Courses (dirt, grass and the four training courses), Cups, Passport (vet stamps and the Spa Day), Friends (your Tour stamps with faces, from visiting friends' barns), Bests, Cloths (this month's shows 🎀 n/8). The title shows how many you have found. Race on the dirt track: Courses → Dirt track turns bright.
- [ ] **First five minutes.** With a new profile (or `flags.tourDone` cleared), pick a starter: the tour card says "Let's race! Tap GO to race with Comet." and **GO ▶** puts you straight in the race line (the queue card appears), no picker.
- [ ] On the phone emulator every Book tab, card, the Thanks!, Photo, Save and Share buttons are fingertip-sized and every word is readable; the Book fills the screen rather than shrinking.
- [ ] Studio check: the photo board doesn't overlap the Rosette Wall, the garden beds or the hay cart (if placed), and its prompt doesn't fight the Stable Board's.

## Careers, Legends and rehoming (horse life stage 7, D-059)
Use Play Solo (or 2 players), plus Device emulator → a phone in landscape. No tools needed beyond Studio's command bar for the race count. To skip the 100 races: in Studio's command bar during Play, set a horse's races, e.g. `require(game.ServerScriptService.Server.Profiles).get(game.Players:GetPlayers()[1]).horses[2].record.races = 99`, then run one race.
- [ ] **Career row.** Open 🐴 My Horses: each card has a line like "🎖️ 0 badges · next in 25". Race once with a horse at 24 races: after the results a toast says "🎖️ Comet earned a 25-race badge!" and the card shows "🎖️ 1 badge". Nothing ever gets slower or older.
- [ ] **Veteran and the Legend card.** Set a horse's races to 99 and race once: a toast says it's a Veteran, and back in the world (never in the race or the line) a card says "🎖️ Comet is a Veteran!" with **👑 Show me** and **Not now**. Tap either; the card never comes back for that horse (rejoin to check).
- [ ] **Legend Retirement.** On that horse's card tap **👑 Legend**, then **Sure? 👑**: a toast "👑 Comet is a Legend! See the Hall of Fame paddock." Walk to your barn: beside it, on the garden side, a white-fenced paddock with an arch ("👑 Hall of Fame"), the horse with a soft gold glow and a few sparkles, and a plaque post with its name and races. Its old stall now holds your pasture horse (if you had one); no other horse changed stall.
- [ ] **Still rideable.** Walk up to the Legend in the paddock: a **Ride** prompt brings it and you ride it around; it leaves the paddock while you ride and is back when you hop off. It doesn't appear on the race picker and can't race. With Reduced Motion on (Roblox settings), no sparkles, only the glow.
- [ ] Your only racing horse has no 👑 Legend button working ("Keep one horse racing with you!").
- [ ] **Rehome a bought horse.** Buy a horse at the Market Corral, then walk to the cream-and-blue **Sunny Meadow Riding School** sign by the corral gate: its prompt "Rehome a horse" opens a list. The bought horse says "School pays 💵 N" (half its price). Tap **🏫 Rehome**, then **Sure? ✓**: the goodbye card says "Comet is joining Sunny Meadow Riding School!" with "+💵 N Green Cash" and "Changed your mind? Undo for 3 days." Nothing says farm or sold.
- [ ] **Undo at once.** Tap **↩️ Undo**: the horse is back with the same name and stats, and the Green Cash goes back. Rehome it again and open My Horses → 🏅 Hall of Fame: it's listed "at Sunny Meadow" with "3 days to change your mind" and **↩️ Undo · 💵 N**; that works too.
- [ ] **Who stays.** The starter horse's row says it stays ("was your first horse. Friends forever!") with no Rehome button; so does your last racing horse and any Legend. While you're in a race line or riding a horse, rehoming that horse says to do it after.
- [ ] A tamed horse's row says "🏵️ Goodbye rosette"; rehoming it pays nothing and the Hall of Fame page counts the rosette.
- [ ] On the phone emulator the rehome list, the goodbye card and the Legend card have fingertip-sized buttons and readable words; the For grown-ups page explains careers and rehoming.
- [ ] Studio check: the paddock doesn't overlap the garden beds, the trough or the pasture horses; the riding school sign doesn't block the corral gate or the market horses.
## Classes and the Rosette Wall (horse life stage 8, D-062)
Use Play Solo, then 2 friend accounts on a published server for the visitor check, plus Device emulator → a phone in landscape.
- [ ] **First Win badge.** With a new horse, open RACE! → 🔀 More choices: its horse card says **🐣 First Win** under the Energy row. My Horses says "Stall · Rookie · 🐣 First Win".
- [ ] **First win.** Win a Rookie race (good taps; solo Rookie wins about a quarter of races). After the results a toast says **"🐣 First Rookie win! +10 League Points"**, and the League Points jump by 10 once on top of the 10 for 1st. The badge now says **🚀 Rising Star**. Win again: no second +10. After a third Rookie win it says **🎽 Open class**; once the Cup opens it says **🏆 Cup** (My Horses: "🏆 Cup open!").
- [ ] **New league.** Win the Rookie Cup: in Bronze the horse is **🐣 First Win** again, and its first Bronze win gives the +10 and the toast again.
- [ ] **Practice doesn't count.** A Practice race win gives no +10, no badge change, no rosette.
- [ ] **Rosette Wall.** Walk to the wall in your yard (beside the photo board): after the first Rookie win a **green** rosette hangs on the dark felt panel (Bronze's is tan, Silver's pale grey, Gold's yellow). A Cup won shows the gold Cup on a shelf in that league's colour. Check in Studio that the panel sits on the front of the `rosette_wall` model (not inside it or floating behind it) and that the rosettes are coloured, not the uploaded texture.
- [ ] **A visiting friend sees it.** A friend visits your barn (Map → 👫 Friends' barns): the same rosettes and Cups on your wall. They never see your goal cards.
- [ ] **Stable Star goals.** Stable Board → **🏵️ Goals**: three cards, Care / Collect / Riding, each with a coloured strip, a goal ("Brush your horses 10 times", "Find 2 coats for your Horse Book", "3 races with Great taps") and n/target. Finish one (brush 10 times): "🏵️ New rosette on your Rosette Wall!", the card moves on to the next goal of that kind, and a rosette in that colour (care pink, collect blue, riding orange) appears on the wall. **🏵️ See my wall** walks you home. No card ever asks you to win or place in a race.
- [ ] **Nothing is lost.** Rehome or retire a horse (stage 7): its rosettes and Cups stay on the wall.
- [ ] On the phone emulator the picker's horse card shows name, Energy, badge and "suits" line without overlapping; the Goals tab's four tabs and cards are fingertip-sized and readable.

## AAA Phase 1: race feel (D-066)
- [ ] **Taps show on the horse.** A Great or Perfect pace tap moves your horse forward about 4 to 5 ft, easing in over half a second. Tapping well twice in a row carries it on; the horse never snaps back. It never goes into the horse right ahead in your lane, and when a horse cuts in ahead the nudge eases back instead of jumping. The place badge doesn't flicker.
- [ ] **Perfect surge.** A Perfect tap: your horse dips forward briefly, two short white streaks come off its flanks, dust bursts from its hooves, the view widens a touch (no more than once every 0.8 s), and a chime plays over the tick. Every 3rd Great-or-better tap in a row surges too (without the view kick). The word pops in each time. Other riders' screens show none of this on your horse.
- [ ] **Dust appears at the hooves**, not somewhere else on the track or in the sky: one small dirt-coloured puff each stride, in time with the front hooves, staying behind and fading quickly. The flank streaks start at the horse's sides. Check the frame rate on the phone emulator.
- [ ] **Tap tick.** Every counted tap ticks, one step higher for Okay, Good, Great and Perfect, and clearly over the hoofbeats. The hoofbeats sit lower while the slider runs and come back up for the Final Burst. They're in step with the legs (about 3 beats a second). A second tap in the same pass ("One tap!") and finger bounces don't tick.
- [ ] **Final Burst arms.** The burst bar opens grey, with the marker already moving from a random spot (on Champion both glows are grey). After half a second it turns rainbow with the pulsing gold rim and the whoosh plays. A tap while it's grey shakes the bar a little and says "Wait for the rainbow!"; your one tap is still there, and the hint goes back as the colours come on. A tap once it's armed scores and celebrates, and the view widens more than for a Perfect.
- [ ] **Reduced Motion on** (Roblox settings): no view kicks, no dip, no streaks, no dust, no bar shake. Taps still nudge the horse, and the word still shows (without the pop). Turning it on mid-race takes effect at once.
- [ ] **Bob in step.** Watch a horse side-on, or in the replay at ×0.5: the body is lowest as the front hooves land, once a stride, and never drifts out of step with the legs. Out of the gate and pulling up, the bob grows and fades smoothly with no jump as the gait changes. Replays bob the same way, fading past the line.
- [ ] **Pad and slider** (from the 4th race, when ◀ ▶ show) on 667×375, 844×390, 1024×768 and 1280×720: the slider and the bar under it sit right of the buttons for the whole race, and nothing jumps when the buttons fade at the far turn. The glow is never under a thumb on Out ▶. The bar under the slider says **RIDING**, fills gold over slate, and the marker's top doesn't touch it.
- [ ] **Burst on a short screen:** "FINAL BURST ×2" and your result banner sit just above the burst bar, never on it. The result shape, the word and the hint sit below it, and the hint stays on screen. After your burst tap, the title gives way to your result banner.
- [ ] Switch-backs: `GameConfig.raceFx.enabled = false` (no pop, surge, dust, kicks, tick or duck), `burstArmSeconds = 0`, `raceView.bobFromLegs = false`, `hud.sliderClearOfPad = false`, `tapNudgeFeet = 2`, `raceFx.surgeOnGreatStreak = 0`.

## AAA Phase 2: first minute and phone layout (D-067)
Use a fresh save (or ⚙️ → "Show me around again") and the phone emulator at 667×375, then 568×320 and 1280×720.
- [ ] **Starter at the floors.** The pick-your-horse screen never shrinks under 0.875: word chips and buttons are 64 px (56 rendered), the blurb is readable. On 568×320 it scrolls instead of shrinking. The chosen name is dark orange and easy to read.
- [ ] **One voice.** Right after naming the horse: no "Meet Comet!" toast, no Next-thing pill, no 💎 pill. Only the tour card at the top ("Let's race! Tap 🏁 RACE! down below.") with no GO of its own, and RACE! glowing gold under a bobbing 🐾👇. Reduced Motion: the glow and arrow hold still.
- [ ] **Toasts wait.** Any notice that arrives during the race step shows after you join the line (or after 60 s), the newest three only.
- [ ] **Skip is far from GO.** The tour's ✕ sits at the left end of the card. One tap turns it gold and says "Skip the tour? Tap ✕ again."; it forgets after 4 s. A second tap skips. On steps with a GO (feed, groom, plant), GO is at the right end.
- [ ] **In line.** Tap RACE!: the tour card goes away (the queue card has the news), RACE! reads "In line!" over "⏳ 12s" with nothing clipped, and the pill (once the tour is done) says "You're in line! Race soon." whatever it said before.
- [ ] **Compact queue card (phone).** One 64 px row under the top bar: the seconds in a ring, "Race in 12 · 3 riders", ✕. The world and your horse stay in view while you groom. It never covers the 💎 pill or the ⚙️. Tap the row: the gate's 8 slots and 🔀 More open under it; tap again to close.
- [ ] **Warm up** (first 3 races only): "🎯 Warm up" on the row opens a practice slider in place of the gate. Tapping the bar says Perfect!/Great!/Good!/Early/Late, never "Miss", and nothing changes anywhere (no score, no server call). "Race time!" closes it. After the 3rd race the button is gone.
- [ ] **One top card at a time.** With the tour up and in line for a later step, the tour shows and the queue card waits; at "Race time!" the queue card takes over. Toasts always stack just under whichever card is up, never on it.
- [ ] **Gear under the 💎 pill** on touch, both 56 px, not overlapping; on PC the gear is top right. Both hide in races and training rides (the ✕ Stop is there).
- [ ] **Next-thing pill for a new player** says "Race with Comet!" before "Feed Comet some hay" until 3 races are run, then the usual order. A napping horse is never sent to race.
- [ ] **Floors everywhere.** Every panel's ✕ is the same 64 px button (Care, Paddock, Taming, Map, Tack & Paint, Horse Book, Settings, Stable Board, My Horses, Race picker). Tack & Paint tabs are 56 px. Settings never shrinks: on a phone it gets shorter and its page scrolls. Grooming fits a 375 px phone without scrolling (a swipe brushes, never scrolls the card).
- [ ] **Race map on a phone:** no lap oval or title, coloured dots without digits, and "2 lengths behind the leader" readable (14 px or more).
- [ ] **Contrast.** "Loves this race" (green) and "not its favourite" (orange) on the race picker, Green Cash amounts, "✓ Done!" and the training gain line are dark enough to read on cream and on the gold selected card.
- [ ] Switch-backs: `firstMinute.tourOwnsScreen = false`, `firstMinute.tourGoOnRace = true` (the old GO), `firstMinute.pulseRace = false`, `firstMinute.skipConfirm = false`, `firstMinute.hideGemPill = false`, `nextThing.raceFirstUntilRaces = 0`, `queueCard.compactPhone = false`, `queueCard.warmUp = false`, `touchLayout.gearBelowGem = false`.

## AAA Phase 2: finish and results (D-067)
Ride races to 1st, 2nd–4th and 5th–8th (Practice with bots is fine), on the phone emulator at 667×375 and 568×320, then 1280×720.
- [ ] **Gallop-out.** Past the line every horse keeps galloping and slows smoothly over about 150 ft (2–3 s), legs and bob fading with it, then stands. No horse stops dead at the post or slides on with its legs still. The same in a Short race and a Longest one.
- [ ] **The orbit.** As your horse crosses, the camera swings from behind it round to the side view (the replay's broadcast angle, outside the outer rail) in 2.5 s, smoothly, never through a horse or the rail, and holds there behind the card. Nothing jumps when it starts.
- [ ] **1st:** confetti bursts over your horse and falls (about 3 s), and the horse gets a gold outline until Done. **1st–4th:** the ribbon (blue, red, yellow, white) stamps onto the screen with its place on it, then gives way to the card. **5th–8th:** no stamp, the orbit only.
- [ ] **Skip.** Tap anywhere (or Space) during the orbit: the card comes up at once and the camera finishes its swing behind it. That tap never presses a card button.
- [ ] **On time.** With a stopwatch from the leader crossing the line: the card is up within 4 s every time, whatever your place (about 2.5 s when you win).
- [ ] **Reduced Motion on:** no orbit, no confetti, the stamp just appears (no zoom), the world dims and the card fades in, still within 4 s.
- [ ] **The card at the floors.** Under the Roblox top bar (never behind it), text easy to read on 568×320, buttons thumb-sized (64 px, never under 56 rendered). On a short screen it scrolls rather than shrinking. From the top: the ribbon and "1st! You won!" (or "3rd place!"), one kind line, "You rode ★★☆", "Your taps gained Comet N places!" only on a gain, the top four and your own place, then the buttons.
- [ ] **Kind words for every place.** 1st–4th: "Blue ribbon for Comet!" and so on. 5th–8th: praise for the ride ("Great riding! Comet felt every tap."), never "so close", "almost" or "unlucky".
- [ ] **Best ride.** Ride really well and lose: "Best ride in the race!" (or "2nd best ride!", "3rd best ride!") under the headline. Ride badly: no line at all, never "7th best". Nobody else sees yours; there's no list anywhere.
- [ ] **🏁 Race again** (64 px, orange): you get off the race horse and join the same league's line at once, like RACE!. When the horse is napping it says "🎈 Practice race" and joins Practice. Never a 💎 button or a shop prompt on the card or right after it.
- [ ] **Replays.** ↺ Finish and ↺ Whole race take the camera from the side view, play, and come back to the card (dimmed world, camera behind your horse). Done gets you off the horse with the normal camera.
- [ ] **First race (fresh save).** "Tap once every time the marker passes the glow" stays up for the first 3 passes. A see-through 👇 points at the glow for 4 passes and presses as the marker crosses it, with "NOW!" on the glow. "Big tap coming!" shows as FINAL BURST comes up. From the second race, none of this.
- [ ] **The word at the marker.** Every counted tap shows its word small just under the slider where the marker was (gold Perfect, green Great), sinking and fading in about half a second; the big word still shows in the middle. Reduced Motion: it fades without moving.
- [ ] **Taps move horses sooner** (from the far-turn lock to checkpoint 2): your horse's place on screen and the badge arrow respond about once a second to how well you tap, not only at the checkpoint. The finish order and the results are the same as before (watch the `[Trip]` log and the card).
- [ ] **Words match.** The race status line reads like the picker: "Bronze · 🐇 Short · Dirt ☀️", never "Sprint".
- [ ] **Short race, spectating:** the cheer strip stays until checkpoint 1 closes, even when the lanes lock before it (the once-a-second previews never close it).
- [ ] **No arrow flicker.** From the lock to checkpoint 2 the horses move about once a second, but the up or down arrow on your place badge (and on a cheered rider) shows only as a checkpoint closes.
- [ ] **A reflex tap doesn't skip.** Keep tapping in rhythm through the line: the orbit, the stamp and the confetti still play; a tap a second or more after the crossing skips to the card.
- [ ] **Stamp clear of your horse** on 667×375: the ribbon stamp sits in the upper-left third, smaller on a phone, never over your horse in the side view. It chimes (not the button click); a win adds a crowd cheer. The YOU marker hides during the orbit and comes back after. "3rd" and "4th" are ink on the yellow and white ribbons.
- [ ] **Two-column card on a phone (667×375, 844×390):** headline, lines and 🏁 Race again on the left; the places and ↺ Finish, ↺ Whole race, Done on the right; everything visible without scrolling, under the top bar. Rotate to portrait: one column again.
- [ ] **5th–8th** lead with praise ("Great riding!") and then "Comet came 6th and felt every tap." "Best ride" shows only with ★★ or more.
- [ ] **Napping, no other horse ready:** the card's button says "🌾 Feed Comet" and walks you to your stall. With another horse ready it says "🎈 Practice race".
- [ ] **Dim:** a light warm tint behind the card (not grey-black). With Reduced Motion, abort or leave during the fade: the tint never stays on screen without the card.
- [ ] **Starter on 667×375:** both steps fit without scrolling, Next ▶ (and Back, 🔀 New words on the naming step) fully visible at the bottom.
- [ ] Switch-backs: `finish.enabled = false` (the card after 3.5 s, no orbit, stamp or confetti), `finish.orbit = false`, `finish.confetti = false`, `finish.stamp = false`, `finish.gallopOutFeet = 46` (the old near stop), `results.raceAgain = false`, `results.riderRank = false`, `results.headline = false`, `raceFx.coachRaces = 0`, `raceFx.judgeAtMarker = false`, `pacePreviewAfterLock.enabled = false`, `hud.arrowOnPreview = true`, `finish.skipAfterSeconds = 0`, `results.twoColumnBelowPx = 0`, `results.rankMinStars = 0`, `results.feedWhenNapping = false`, `ui.starterCompactBelowPx = 0`.

## AAA Phase 3: progression and friends (D-068)
**Core-playtest switch.** To playtest the race loop alone, set `GameConfig.corePlaytest = true` (in `game/src/shared/GameConfig.luau`, at the bottom). When the module loads it turns off, through their own flags: the Spa (`spa.enabled`), friends' barn visits (`visit.enabled`), careers and Legends (`career.enabled`), rehoming (`rehome.enabled`), the Photo Finish camera (`comeback.photo`) and the Horse Book (`comeback.horseBook`). Racing, Practice, "Race with a friend", training, care, jobs and the Welcome Back gift stay on. Set it back to `false` (the default) afterwards; nothing in a save changes either way.

**Existing test saves.** The ladder is retuned (Cup points 100/200/450/900, bot anchors 32/35/38/48/56, ceilings 55/57/60/66). A test horse that is already highly Rated (about 60+ in Bronze, 70 in Silver) is now over its league's ceiling, so RACE! becomes CUP! and it runs a string of Cups, one league after another, until it reaches a league whose ceiling it's under. That's expected: nothing is lost, and Practice stays open the whole time. Use a fresh save to judge the ladder's pace.

- [ ] **Ladder, fresh save.** A new starter (Rating about 47) wins roughly 1 in 4 or 5 Rookie races with average tapping. After its Rookie Cup it still wins about 1 in 4 or 5 in Bronze: promotion doesn't feel like a punishment. The Cup button unlocks at 100 points in Rookie and 200 in Bronze.
- [ ] **Old save over the ceiling.** Load a save with a horse around Rating 70 in Silver: the picker says the Cup is open and regular Silver races are closed; win the Cup and it moves to Gold (ceiling 66, so the Gold Cup again), then Champion, where regular races are open. No error, no lost cash or horses.
- [ ] **Open Practice.** Two players in different leagues (for example Rookie and Gold; set one save's `league` in Studio) both pick 🎈 Practice: they end up in the same race on the same course. The card always runs at Rookie settings (`queue.openPracticeLeague`: Rookie's 2.4 s slider, Sprint or Mile, Rookie bots), even when the Gold player joined first. Every horse in a Practice race has the same chance (`queue.practiceEqualHorses`): a fresh starter beats a trained Gold horse when its rider taps better. Practice pays no Green Cash and no League Points to anyone, and Energy isn't spent.
- [ ] **Another league's Practice card** on More choices is joinable (not "👀 Watch"). Another league's regular race or Cup card still says "👀 Watch".
- [ ] **Race with a friend.** Two Roblox friends in one server. Player A taps RACE! → 🔀 More choices → 👫 Friends: B's name shows as "🎈 Race with B" (only Roblox friends who are in this server; a non-friend never shows). Tap it: A joins Practice; if B is already in a Practice line, A goes to B's course, also when A was already in line alone on the other course or in Practice there. A gets one notice: "🎈 You're in B's race!" when it found B's race, or "Ask B to tap 🎈 Practice too!" when it didn't. B gets no invite, popup or sound from it. If B's stable visits are set to 🔒 Nobody, A still joins Practice but is never moved to B's course. With no horse picked, the active horse is used. With no friends in the server, the page says so kindly. "◀ Races" goes back to the race cards.
- [ ] **Cash races still keep leagues apart.** A Bronze horse can't join a Rookie race or Cup card by any route (picker, Race Board, friend button).
- [ ] **No Legend suggestion.** Take a horse to 100 races (`record.races` in Studio): it becomes a Veteran, gets the career patch toast, and no "can retire as a Legend" card pops up. The 👑 Legend button is still on its card in My Horses.
- [ ] **Back to the races.** Retire a Veteran as a Legend (two taps), then on its card in My Horses tap "🏁 Back to races" and "Sure? 🏁". It's racing again in the same league with the same League Points, record and Cup status; it takes a free stall (or the pasture if the barn is full, with "Free a stall to race."); its Legend plaque leaves the Hall of Fame and the Rosette Wall; it leaves the Legend paddock. Not allowed while you're in a race line, on a training ride or riding that Legend (a kind toast says why). Retire it again: one plaque, never two.
- [ ] **Your last racer stays.** With only the starter racing, the 👑 Legend button refuses ("Keep one horse racing with you!").
- [ ] **Words.** The career row reads "🎖️ 2 patches" and the toast "earned a 25-race patch!"; training results say "Gold medal" (never "ribbon"); friends' barns give "Tour pins" ("📍 Pin" in the Horse Book). Race places keep their ribbons. Every toast is 10 words or fewer.
- [ ] **Core-playtest switch on:** no Spa in the Vet, no Friends' barns button on the Map and nobody can enter your barn, no career patch toasts, career row or 👑 Legend button, the Riding School sign offers no rehoming, no 📸 Photo Finish button, no Horse Book. Racing, Practice and Race with a friend all still work.
- [ ] Switch-backs: `queue.openPractice = false` (Practice per league again; the 👫 Friends button hides), `queue.openPracticeLeague` (another league's settings for Open Practice), `queue.practiceEqualHorses = false` (Practice uses each horse's Rating again), `career.suggest = true` (the stage 7 Legend card at 100 races), and the old ladder values in the GameConfig comments (stakesUnlockPoints, leagueCeiling and botRatingAnchor change together; `tests/test_sims.py` checks that they never mix).

## AAA Phase 4: world and jockey (D-069)

- [ ] **Jockey crouch.** In a race (chase camera), your rider and every bot jockey crouch: back well under 45° from horizontal, hips back, knees bent, arms forward along the horse's neck to the reins. No arm is ever raised and nobody holds a whip or crop. Feet don't sink into the horse; if they do, tune `jockeyPose.seatDropStuds` (and `pelvisDeg`, `hipDeg`, `kneeDeg`).
- [ ] **Studio pose tuning.** The joint directions (`JockeyPose.SIGN`) and the knee bend can only be checked in Studio: feet near the horse's flanks, not inside it; the back about 40° from horizontal; thighs forward, shins back; hands forward at the neck. If a joint bends the wrong way, flip its sign in `JockeyPose.SIGN`; if feet sink, set `jockeyPose.seatDropStuds` below 0 (that lifts the rider) and adjust `kneeDeg`/`hipDeg`. Hop off mid-lobby: the crouch drops at once.
- [ ] **The pump.** Each stride the rider reaches forward and rises a little between landings, on the same beat as your horse's hoof dust and body bob, at any speed. It fades in out of the gate and out as the horse pulls up. Under Reduced Motion the crouch stays and the pump stops.
- [ ] **Everyone poses.** Watch a race as a spectator: bots and other riders crouch too. Open the replay: the jockeys pose the same way, slow motion included. An R6 avatar keeps the plain sit (no broken limbs).
- [ ] **Bunting.** On the homestretch in the chase view: fair bunting (orange, gold, sky, teal, paper) hangs along the grandstand roof edge and on posts outside the outer rail from a furlong out to past the line, and strings of pennants run from the Twin Spires down to the roof. The pennants hang point down (if they're upside down, set `trackDressing.buntingFlip = true`). The rail bunting never crosses the replay side view or the finish orbit.
- [ ] **Flags.** Orange pennants fly from poles along the roof and on top of each spire, and flutter gently. Under Reduced Motion they hang still.
- [ ] **Crowd.** Every grandstand riser shows a row of cheerful toy fans (no tickets or paper slips). They bounce gently in the lobby and harder from the Final Burst until your results card shows; rows bounce a little out of step, and each riser's fans start at a different point (no grid of identical columns). Walk to the barn: the bounce and flutter stop ticking (they resume within a second back at the track; 15 Hz on phones). Under Reduced Motion they don't move.
- [ ] **Fallbacks.** Before the images load (or with them missing), the bunting shows as plain colour blocks and the flags as orange strips; nothing errors in the output.
- [ ] **Big Board.** During a race the infield board shows "🏁 Top 4": place, lane chip and horse name for the race you follow, matching your place badge at every checkpoint (and the official order once the result is in). Never a win %, a purse or any money. Between races it shows "GIDDY-UP!" again.
- [ ] **Practice with a friend.** Two Roblox friends in the same 🎈 Practice race: each sees a small 👫 under the other's lane badge. Strangers and bots get none, nor does anyone in a cash race.
- [ ] **Budget.** Studio part count rises by at most 350 with the dressing on (expect about 35 parts and about 60 Beams), and phone frame time is unchanged within 1 ms.
- [ ] Switches: `jockeyPose.enabled`, `trackDressing.enabled` / `.bunting` / `.flags` / `.crowd`, `trackLife.enabled` / `.crowdBounce` / `.flagFlutter`, `bigBoard.live`, `friendRace.badge`: each off removes only its piece.

## AAA Phase 4: HUD, camera and finish polish (D-069)

- [ ] **Gate line-up.** Join a race as a rider. Nothing takes the camera during the lobby wait (you can keep grooming). As "3" shows, the camera glides along the front of the gate from the outside lane to lane 1, about head height, looking at the horses' faces (the glide eases in and out), then a quick soft cream flash cuts to the chase view behind your horse: no swing through the horses. The chase camera is yours again before "1" (at least 0.8 s before GO), and you can tap the first pass. "3, 2, 1, GO!" shows the whole time.
- [ ] **Gate edge cases.** Spectators never get the pass. With Reduced Motion on it never runs. Seated late (for example a slow phone), you go straight to the chase view. Leave the seat, respawn or have the race cancelled mid-pass: the normal camera comes back at once and never sticks. If horses' faces are hidden by the stall doors, tune `gateIntro.frontStuds` / `.heightStuds`; if the cut lands far from where the chase camera settles, tune `.chaseBackStuds` / `.chaseUpStuds`. `gateIntro.handOff = "blend"` brings back the old glide (switch-back).
- [ ] **HUD colours.** The place badge (and the running-order board, if on) is a cream Paper panel with a dark Ink outline and dark text, your row in dark orange; no dark green boxes anywhere. The pace slider is slate with a gold glow; the "3, 2, 1" is gold with a dark outline; words are in the rounded Fredoka font and the place number in Builder Sans. The first-race hint says "Tap once every time the marker passes the glow" (the glow is gold now, not green), and the warm-up says "Tap on the glow!".
- [ ] **YOU marker.** In your own chase view (and the gate line-up) there's no YOU marker by default (`raceHud.youMarker.riderShown = false`; your place badge says where you are). Spectators watching your race and replays show the big one; during the finish orbit it's hidden. With `riderShown = true`: on a 667 × 375 phone emulator it's small, just above your rider, never in the middle third, hidden in first person, the same size through the gate pass (no pop at GO).
- [ ] **Small HUD text.** On a 667 × 375 phone the place badge's "of 8" and the board rows (spectators) are readable, never tiny (at least 14 px on screen).
- [ ] **Music (needs a track id).** With `audio.music.id = 0` (default) there's no music at all. Set a beatless track from the Roblox music library: it plays softly in the lobby, drops well under the tap ticks while your slider runs (every tick still clearly heard), dips further whenever the announcer speaks, is quieter still while you only watch, and swells a little for the finish and results card. Each change fades in about half a second. Sound Off in ⚙️ silences it at once; On brings it back. If the track has a steady beat, set `audio.music.race = 0` (kids tap to the marker, never a beat).
- [ ] **Paper confetti.** Win a race: the confetti looks like little square paper pieces in orange, gold, sky, teal, blue and red, fluttering down (before `confetti_square` is uploaded it's the old sparkles; nothing errors).
- [ ] **Ribbons.** Before the ribbon art loads, the stamp and card discs are the ribbon colours: Blue 1st, Red 2nd, Yellow 3rd (dark "3rd"), White 4th (dark "4th").
- [ ] **Stars count in.** On the results card, "You rode ☆☆☆" fills one star every 0.2 s with a tick that rises each time. 0 stars: no ticks, the kind line still shows. Reduced Motion: the stars just show. Tap a replay mid-count, come back: the full stars are there.
- [ ] **RACE! reason.** As a brand-new player on the tour's race step (toasts are held), make RACE! fail (both races full, or a napping horse): the reason toast shows straight away, not a minute later. With the picker (one-tap off), the reason shows as the picker closes; other toasts while the picker is open still wait.
- [ ] **Warm-up tick.** On the queue card's Warm up, each tap plays the race's soft tick, higher for a better tap (not the button pop).
- [ ] **Tour ✕.** Double-tap the tour's ✕ quickly: it only asks "Skip the tour? Tap ✕ again." A second tap after a moment skips.
- [ ] **One leave ✕.** In line with the queue card showing its ✕, the dock's ✕ above RACE! is hidden; when the queue card steps aside (for example the tour holds the top), the dock's ✕ comes back.
- [ ] Switches: `gateIntro.enabled` / `.handOff`, `raceHud.youMarker.riderShown`, `raceHud.enabled` (fonts, outlines and slider colours; panels stay Paper with dark text), `audio.music.id`, `finish.starTickSpeeds` / `.starStepSeconds`, `firstMinute.skipGuardSeconds` / `.raceReasonSeconds`.

## Green Cash: Barn Builder (D-070)

Barn Builder is a new 💵-only counter beside the Feed & Seed counter on Fair Street. To test a shelf quickly in Studio, set the profile's `bestLeague` (and `cash`) in the command bar on the server, then rejoin or make any change (feed a horse) so the barn and the view refresh.

- [ ] **Its own shop.** Walk to Feed & Seed: a green "🔨 Barn Builder 💵" counter stands to its right, with a "Build" prompt. The panel has a 🔨 header on a green band, "💵 1,240 Green Cash" in dark green, 💵 on every price, and no 💎 anywhere. Tap the 💎 pill: Tack & Paint lists no Barn Builder item and says "💎 Tack & Paint looks. 🔨 Barn Builder uses 💵."
- [ ] **Shelves.** A Rookie stable sees the Rookie shelf and, below it, the Bronze shelf greyed with its badge and "Opens when a horse reaches Bronze" once, on its header. Locked cards show no price. The Silver, Gold and Champion shelves don't show at all. With `bestLeague = "Gold"`: Rookie to Gold open, Champion greyed. No item icon is a 🎀, a rosette, a medal or a cup.
- [ ] **Floors.** On a 667 × 375 phone emulator the panel never shrinks text under 14 px or buttons under 56 px; every button is 64 px tall unscaled. Scroll deep into the shelves: the 🔨 band, the balance and the ✕ stay pinned at the top (only the shelves scroll).
- [ ] **Building.** Tap Build on a 300 item with 1,240 cash: it asks "Use 💵 300? You'll have 💵 940 left." Yes, build: the cash drops by exactly 300, the card turns to "Yours ✓", and the shelves jump to the top where a gold banner says "🔨 Cherry barn paint built! Go see it!" with See it ▶ (also when you were scrolled far down on a phone). Not enough cash: "You need 💵 60 more", 💭 Wish and OK. Spam Yes, build: one buy only (the server's gap is `greenCash.buyGapSeconds`).
- [ ] **The build moment.** Tap See it ▶: the panel closes, "Go see it! Follow the hoofprints" shows, and golden hoofprints lead to the spot in your yard. Until you get there, the new piece is not on your screen and you can walk straight through its spot (a friend standing in your yard already sees it). Arrive facing away from it: a "✨ Here!" bubble floats over the spot and nothing plays yet; turn the camera toward it and, once it is on screen and roughly ahead of you, the piece drops in from above with a bounce past full size, a dust puff and a sparkle burst, `job_done` plays and "Apple tree built!" shows. A paint, trim, stall-door or name-plate look sweeps across the barn from one side over about half a second instead. A saddle cloth or helmet: a sparkle on you and "Sunny saddle cloth is ready to ride!". Never go home: after `greenCash.pendingBuildSeconds` it just shows.
- [ ] **Reduced Motion.** With Reduced Motion on (or `greenCash.buildFx = false`), the piece fades in and the paint fades over, with the same toast and sound. With Reduced Motion on there are no sparkles or dust anywhere (your build, a friend's fresh build) and the weathervane holds still.
- [ ] **Every piece at its spot.** Build each item once (`bestLeague = "Champion"`, lots of cash) and walk the yard: two apple trees on the right side, the log jump between the picnic table and the paddock (ride over it), the painted trough, flower-box wheelbarrow, painted bucket and hay bale with a red bow each *replacing* the free one (never two troughs), the red horseshoe over the barn, the flower photo board (its 📷 prompt still works), the hay-loft dormer with "Hay Loft" sign and a bale on a rope, bunting along the barn front (sagging strips of the track's bunting art; plain colour strips before it loads), the painted front fence both sides of the gate, the wall frame round the Rosette Wall, and the grand gate arch over your gate, painted barn white with caps in your trim colour (walk *and ride* through it: nothing in it blocks the gate). Nothing overlaps a garden bed, the Hall of Fame paddock, the Tack & Paint yard pieces or the path in from the gate. Gold and Champion pieces look like painted wood, rope and bunting, never shiny metal.
- [ ] **Clutter check (Champion yard).** With every item built, stand on Barn Lane outside the gate and take one screenshot: the gate, the stalls, the garden beds and the Rosette Wall are all still visible, and you can walk from the gate to each of them. Attach the screenshot to the playtest notes. Studio part count for the full yard stays modest (bunting is Beams, not parts).
- [ ] **Weathervane.** On the ridge: a little cupola, a pole, a fixed N/E/S/W cross (letters on 1.2-stud plates, readable from Barn Lane) and an arrow under a trotting-horse silhouette that turns slowly (held still with Reduced Motion). Before the `horse_silhouette` image loads the horse is built from dark parts; after, it's the drawn silhouette on both sides. If the horse faces backwards against the arrow, swap the Decal faces in `BarnDecor.weathervane`. Visit from a friend's account: the vane turns there too.
- [ ] **Return.** An item built today shows "↩️ Return" and "You can return it until tomorrow" (no clock). Tap it: "Sure? ↩️" and "You get 💵 300 back". Tap again: all the cash comes back, the look comes off and the free one returns. Wait a day (or move `boughtAt` back 24 h): no Return button.
- [ ] **Wish.** Tap 💭 Wish on one item: it turns gold ("💭 Wished"), and the dock's cash card shows that item's emoji and a bar under the number, filling with your cash (no % or words). On a phone, open ☰ More: the cash cell has the same bar. The bar never shows on the results card. Tap 💭 Wished to clear it.
- [ ] **"You can build" pill.** Once your wish is affordable, the Next-thing pill says "You can build the Mint barn paint!" with GO, which draws hoofprints to Feed & Seed. It never shows while the tour runs, in line, racing, on a training ride, on the results card (where Race again lives), or within 120 s of your race; racing first (first 3 races), job prizes, feeding, brushing and the Cup all come first. After about 45 s on screen or one GO it never shows for that item again.
- [ ] **New shelf.** Win a Cup and move up: nothing on the results card or for 2 minutes after. At the next calm moment the Next-thing pill says "New shelf at Barn Builder!" with GO (hoofprints to Feed & Seed). After one GO or about 45 s on screen it never comes back; rejoin: still gone. Retire or rehome that horse: the shelf stays open.
- [ ] **Around races.** In line, racing, on a training ride, on your results and for 2 minutes after your race, the Build prompt is gone and the panel closes; a hand-sent BuyCash in that window is refused ("Barn Builder opens a little after your race.").
- [ ] **Friends' barns.** As a friend, open the Map's Friends' barns: a barn that built something in the last 48 hours has "✨" by the owner's name (no numbers, no ranking). Walk into that yard: the new piece sparkles once (once per build per server). After 48 hours both stop, even if the owner changed nothing (the plot refreshes every 20 s).
- [ ] **Old saves.** Load a profile from before D-070 with a Gold horse: Rookie to Gold are open at once and "New shelf" never shows for them.
- [ ] Switches: `greenCash.enabled = false` hides the counter and the pill (owned pieces stay in the yard); `greenCash.wishChip = false` hides the bar; `greenCash.buildFx = false` uses the fade; `greenCash.shelfNote = false` drops the new-shelf pill; `greenCash.pillAfterRaceSeconds`, `.pillShowSeconds`, `.returnHours`, `.newBuildHours`, `.pendingBuildSeconds` and `.buyGapSeconds` tune the rest. Prices and spots live in `game/src/shared/BarnCatalog.luau` only.

## Tap preview (D-071)

Draw-only: your taps move your horse on screen before a checkpoint closes. The result, the scores, the lanes and the chances are the same with it on or off.

- [ ] **Three Perfects early.** Rookie Mile, ride with Smart Steer, tap at the field's pace, then three Perfects in a row: your horse moves up within about 2 s, and nothing jumps back at checkpoint 1 or at the lane lock (the far turn). Keep tapping Perfect: it keeps edging up, never more than about a length and a half ahead of where it would be.
- [ ] **Late taps count.** With the network simulator at 150 ms, Perfects near the end of a pass still move your horse (the preview waits `maxTapRewindSeconds` for late taps); it never jitters back after a good tap.
- [ ] **No phantom motion.** Tap steadily at an average rhythm: your horse barely moves against the others. Mash the button (two taps a pass): it drifts back a little and never gets a message.
- [ ] **The message is visible over your horse.** After several clean, good passes that gain ground: "Giddy-up! Moving up!" floats just above your saddle for about 1.5 s, silently, and the place badge pops at the same moment. If it never appears in the chase view, the billboard's Adornee is wrong. Even when drawn 1st it says the same words: never "Pulling away", "leading" or "winning", never a number, never on a loss, never more often than every 4 s. It waits behind a steering chip ("Gap!", "Tucked in!", the turn tip) or first-race coaching, and never shows after "Lanes locked!" or in the Final Burst. While it shows, the tap word says only Perfect, Early or Late. With `raceHud.youMarker.riderShown = true`, the YOU marker steps aside while it shows and comes back after (check the YOU marker is visible over your horse too). In first person (zoom all the way in) the words show on the hint line instead. On a phone the text stays readable (14 px or more).
- [ ] **Spectators.** Watch the same race from a second account (not riding): you see the horses move the same way, but no message over anyone and no badge pop. The rider's screen and yours agree on the places.
- [ ] **Held behind a horse.** Get stuck behind a horse in your lane while tapping Perfect. After about a second held 4+ ft back, your horse bobs a little harder, leans forward a touch and kicks up an extra dust puff each stride. After 1.5 s held 6+ ft: with the ◀ ▶ buttons and a side free, "Room this way! ◀" (or ▶, toward the free side; both free: ◀) with that button's ring lit for about 1.5 s, at most once every 10 s, never after the lock, never when no side is free; without the buttons, "Keep tapping! Room soon." once in the race. It never says "boxed in" or "gap". Reduced Motion: no harder bob, lean or extra dust (the chip still shows).
- [ ] **Steering off** (`steering.enabled = false`): good taps move your horse at every pass end from the gate (only your own taps move it; the others' scores arrive at each checkpoint); the order on screen at the last tap is the result.
- [ ] **Own-screen nudge.** A Perfect's nudge on your own horse never makes it jump back faster than the rest of the field as the preview eases out (RaceView passes `baseFall` into the nudge).
- [ ] **Server cost.** In a Studio Test with 20 players (or 20 test clients) and both courses racing, open the MicroProfiler on the server: the `RaceSend` label stays under 1 ms per race, and `TripStep` (the trip's 10 Hz ticks, D-072 learners' passive races included) stays under 2 ms a tick with 8 fresh accounts pressing the arrows. Nothing is computed for a race without a human rider.
- [ ] Switches: `tapPreview.enabled = false` is today's race exactly (no layer, no pass-end previews, no late-tap grace, no TapNote or TapHeld, RaceView's nudge as before). `tapPreview.messageEnabled = false` drops the message only; `tapPreview.steeringOffWholeRace = false` drops the steering-off previews; `tapPreview.heldCue` tunes the held cue and chip and `tapPreview.heldSend` when TapHeld is sent; `tapCue.enabled = false` hides the message, the pressure cue and the chip on screen; `tapCue.messageSeconds`, `.waitSeconds`, `.studsAbove`, `.minTextPx` / `.maxTextPx`, `.badgePopScale`, `.bobScale`, `.leanDeg`, `.pressureDust`, `.ringSeconds` tune the rest.

## Forward jump (D-074)

- [ ] **Standing hop.** Ride your horse, stop, press Space (phone: ⬆️ Hop): it hops forward about half a body length (about 5.5 studs), never straight up. Peak about 3.7 studs (lower than before).
- [ ] **Galloping hop.** Gallop and hop: it carries forward about 2.4 lengths (about 19.5 studs) and lands without slowing to a stop, with no stutter or saw-tooth in the air (WalkSpeed holds the hop's speed). Hop with no stick held: it still keeps going forward through the air. A second press within 0.6 s does nothing.
- [ ] **Air pose and landing.** In the air the legs stop cycling and fold (forelegs forward, hind legs back), the nose tips up on the way up and down on the way down. On landing the body squashes a touch (0.96 for 80 ms), a soft thud plays and a small dust puff rises at the hooves. Watch a friend's hop from a second account: the same pose and landing. Walking off a step or over a bump never flickers the legs. Reduced Motion on: no nose tip, squash or dust; the folded legs and the thud stay.
- [ ] **Training.** No hop during the 3-2-1. Mud Splash: hop 1 to 4 studs before each log and every log counts ("Clean hop!"); at exactly 1 stud before a log, about 1 hop in 50 can miss (the 10 Hz sampling). Sprint Lane: hopping never makes the horse faster than the course pace, and a ride full of hops is never flagged (no low-score floor). Gate Break: press Space while waiting in the stall (after "Ready…", stick let go) and after the bell: the horse hops straight up, never moves forward, and it is never an early go or a rerun.
- [ ] Switches: `riding.hop.forwardMin`, `.forwardBoost`, `.forwardCap`, `.cooldownSeconds`, `.tuckLegs`, `.pitchUpDeg` / `.pitchDownDeg`, `.landSquash`, `.thudVolume`, `.dustPuff`, `.remoteAirVy`; `jumpPower` also sets `TC.RIDE_HOP`.

## Race arrows (D-072)

- [ ] **Arrows in your first races.** (Only with `steering.introRaces = 3`, the switch-back: since D-072 phase A the buttons show from race 1.) On a fresh account (fewer than 3 races, no ◀ ▶ buttons), press ←/→, A/D and the D-pad during the race: the camera never turns and the horse doesn't move lanes. The first press shows "Smart Steer is steering for you" once; later presses show nothing.
- [ ] **Steering off.** With `steering.enabled = false`, arrows during a race do nothing at all (no chip) and never turn the camera.
- [ ] **Arrows with the buttons.** On an account with the buttons, ←/→ steer one lane as before; after "Lanes locked!" and through the results the arrows do nothing and the camera never turns. With a gamepad, the results card opens with Done selected and the D-pad moves between its buttons. After Done, on foot, the arrows turn the camera again.

## Filing in and passing (D-072 phase A)

The field now races like a field: horses file to the rail after the break, run in a loose pack, move out to pass (mostly on the straights) and sometimes shut the door on a horse moving into their lane. All of it is Trip's lane model (server, 10 Hz), so every screen sees the same race.

- [ ] **Buttons from race 1, staged.** Fresh account, race 1: the ◀ ▶ buttons show, with no ghost-thumb tip (the slider coaching owns race 1). Race 2: the ghost thumb shows once, about 1.5 s after the gate. Race 3: nothing new yet (the move pips come in phase B). The button labels never change during a race.
- [ ] **Learner safety.** In your first 3 counted races no bot ever shuts the door on you (press into a lane next to a bot: the press moves or waits for a horse, never for a door), and pressing never costs you trip (your tau is never below what it would have been without your presses).
- [ ] **Filing in.** From about 2 s to 12 s after the gate, most horses drift toward the rail (half the bots aim for lane 1, a third for lane 2). Smart Steer takes you to the rail only when there's clear run ahead (about a length past the hold gap), so you aren't parked in a column.
- [ ] **A pack, not columns.** Through the backstretch the horses keep shifting by half-lengths (two mixed waves). It should wander, never pulse or breathe in time; nobody slides fore or aft faster than a slow jog relative to their neighbour. Front-runners sit a little ahead and closers a little back early; that fades to nothing by the far-turn bell.
- [ ] **Passing.** Bots held behind a slower horse move out one lane, go by, and head back in once clear (about 10 ft). Watch a few: the two horses are side by side for about a second (never a blink), the passer turns slightly outward on the way out and inward on the way back, and nothing pops or teleports. Most passes are on the straights; a few on turns.
- [ ] **Shut doors.** With a non-learner account, press toward a lane with a bot level with you (within about two lengths): sometimes the bot holds its line. Watch it: its body turns a little toward you for about 1.5 s and a soft knock plays at it; your arrow on that side greys while a door would shut, a press waits (the ring) and "No room yet!" may show. It never brushes and never moves you.
- [ ] **After the lock.** From "Lanes locked!" on, lanes move only to make room (as before); the drift and styles are already faded out at the bell, so no horse jumps there. Watch the far turn at 10 Hz on a weak link (network simulator 200 ms): no pops.
- [ ] **Log line.** The `[Trip]` line ends with `pack: out N, passes N, doors shut N`. Expect a few passes a race (Sprint fewer) and a handful of shut doors.
- [ ] **Fixed lanes (for Hurdles later).** With `card.fixedLanes = true` on a course card (set by hand in Studio), nobody changes lanes, no buttons show, the arrow keys do nothing (camera still), and every tau is 0 in the log.
- [ ] Switches: `steering.file.enabled`, `pack.enabled`, `pass.enabled`, `doors.enabled` each turn one part off; all four off plus `introRaces = 3` is the game before D-072. `steerHud.tipRace` (2) and `pipsRace` (3) stage the onboarding; `steerView.shutYawDeg`, `shutEaseSeconds`, `shutVolume`, `shutSoundSpeed` tune the shut-door look.

## Find it (fun-and-return phase 1)
Map, GO, the phone dock, the queue card and "New!" pointers (D-075). Do the phone checks in the Device Emulator at 667 × 375 landscape with touch on.
- [ ] **Map: 13 tiles.**
  - 🗺️ Map shows a 5 × 3 grid of 13 tiles: My Stable, Racetrack, Race Board, Fair Street, Feed & Seed, Barn Builder, Tack & Paint, Vet & Spa, Market, Training, Riding Ring, Trail, Visit barns.
  - Each tile has a picture, its name and a plum line of 2 words or fewer ("Buy food", "Meet horses").
  - On a 667 × 375 phone the whole grid fits with no scrolling, and no word is cut off ("Barn Builder" and "Tack & Paint" shrink a little to fit whole).
- [ ] **Map lines that change.**
  - With 2 or more horses, My Stable says "2 horses".
  - With a napping horse, Vet & Spa says "Spa today".
  - After a horse moves up a league, Barn Builder says "New shelf".
- [ ] **GO from far away.** Stand at your barn, open the Map and tap Market.
  - The screen fades to cream (not a hard cut) and you arrive at the corral.
  - The card for the first horse for sale opens by itself.
  - Repeat for Feed & Seed (the shop card), Barn Builder (its panel), Tack & Paint (the 💎 shop), Vet & Spa (the vet card), Training and Riding Ring (the Train menu) and Race Board (the race picker, and you are not put in line).
- [ ] **GO from nearby.** Stand on Fair Street and tap Feed & Seed on the Map (it's under 120 studs away).
  - Golden hoofprints appear instead of a trip.
  - When you walk to the shop, its card opens by itself.
- [ ] **Never a trip from a line.** Join a race, then tap a far Map tile, a Stable Board GO or a pill GO.
  - You only get hoofprints.
  - Nothing opens when you arrive, and you stay in line.
  - During your race the dock is hidden; if a GO is reached, it says "After your race!".
- [ ] **Every GO uses it.** The tour's GO, the Next-thing pill's GO, and the Stable Board's horse and job GO buttons behave like the Map tiles.
  - A far place reads "Take me ▶"; a near one reads "GO ▶".
- [ ] **Visit barns.**
  - The Visit barns tile opens the Friends' barns list, with ◀ Back to the grid.
  - With no horse, it says "Pick your first horse…".
- [ ] **Dock on PC.**
  - The order is: cash, horse card, Jobs, Map, Book, RACE! with 🔀 Pick, Ride.
  - Map and Book no longer swap places between sessions.
- [ ] **Dock on a phone: 5 items.**
  - The order is: the horse portrait (coat dot over the Energy pips), 🏁 RACE! with 🔀 Pick, 🗺️ Map, 📋 Jobs, ☰ More.
  - Nothing covers Hop or Gallop.
  - Tapping the portrait opens My Horses.
  - Start a thumbstick drag on the portrait: you walk, and My Horses stays shut (D-056 reversal, D-075). If it fails, set `ui.portraitTap = false`; Horses stays in ☰ More.
  - ☰ More holds Ride, Book, Cash and Horses.
  - At 640 px wide, Jobs moves into ☰ More; at 568 × 320, Map moves too. Hop and Gallop are never covered.
  - "🎈 PRACTICE" fits on one line above "with Comet ▶".
- [ ] **🔀 Pick.** Tap 🔀 Pick when you're not in line.
  - The picker opens with the title "Pick a race", and you are not in line.
  - Its Join button names the line, e.g. "Join Bronze line" or "Join Practice line".
- [ ] **Queue card, race line.** Join a league race.
  - The card's second row names the line, e.g. "🟠 Bronze race line".
  - The third row says "Horses like Comet race here", with your horse's name.
  - Open gate slots read "🤖 at 0" during the countdown.
  - On a phone the row reads "🟠 Bronze line · 1 rider".
- [ ] **Queue card, other lines.**
  - In the Cup line it reads "🏆 Bronze Cup line" / "Only Cup horses".
  - In Practice it reads "🎈 Open Practice line" / "Anyone! Horses all equal".
- [ ] **❓ How racing works.**
  - The first time a new player is in line, a 3-picture strip opens by itself: "Join a line", "Riders fill the gate", "Bots fill spots at 0".
  - "Got it!" or ✕ closes it, and it closes by itself at "Race time!".
  - It never opens by itself again, even after rejoining the game.
  - ❓ on the queue card (full card and phone row) opens it any time.
- [ ] **"New!" pointers.**
  - After 3 races, and at least 2 minutes after your last race, the pill says "New! Pick your own race" and the RACE! slot glows gold for about 6 s, pulsing gently.
  - With Reduced Motion on, the glow holds still.
  - The next pointer ("New! Your Horse Book", Market, Barn Builder, Visit barns...) comes no sooner than 3 minutes later.
  - Pointers never show during the tour, in line, in a race, on the results card or within 2 minutes after a race. A pointer that was up before you raced does not come back on the results card or right after it.
  - Tap RACE!, then fire `Travel` or `VisitFriend` while in line (or tap Visit barns): no trip, just "Follow the hoofprints after your race!".
  - Each pointer shows once per profile: after 20 s on screen, or after its GO.
  - None of them points at Tack & Paint.
- [ ] **Signpost.**
  - A new player arriving on Fair Street sees a wooden signpost past the fountain.
  - It has 6 arms: Racetrack, My Stable, Feed & Seed, Vet & Spa, Market, Training.
  - Each arm points toward its place, has a pointed tip, and has readable words on both faces.
  - A rider on a horse can pass under or through the arms without getting stuck.
  - **Studio check:** that the tips point outward and the words aren't mirrored.

## Visible progress (fun-and-return phase 2, D-076)

Switches: `GameConfig.classes.path`, `GameConfig.cupBar` (`enabled`, `results`), `GameConfig.classUp.enabled`. Step wins: `classes.topWins` (5); `classes.starIsRace` false (true = "💐 Big Race").

1. Open 🐴 My Horses. Each racing horse shows five chips 🐣 🚀 🎽 💐 🏆 with the current one gold and wider with its word, then one goal line ("Next: win a race!", "🎽 Open: 2 more wins", "💐 Top Horse: 2 more wins", "Next: fill the 🏆 Cup bar"), then "🏆 Cup" with a bar and **no number**. A Champion horse has four chips and no bar.
2. Race a Rookie race and finish in the top four. The results card shows "🏆 Cup +6" (or +10, +4...) and the bar fills from where it was with rising ticks (at most 10). Under Reduced Motion the bar just shows full-length, no ticks. The goal line sits under it.
3. Practice race: no Cup row. A Cup win that moves you up: no Cup row (the move-up toast says it).
4. 🏁 Race again is tappable as soon as the card shows; nothing waits for the bar.
5. Win your first race in a league, then ride home to your Rosette Wall. Within about 40 studs: a gold sparkle burst on the wall, a ding then three claps, and "🚀 Comet is a Rising Star!". It ends by itself in under 4 s; tapping anywhere ends it at once. It never plays while racing, in line or on the results card.
6. Rejoin the game: no ceremony replays for steps you already had.
7. On a phone, My Horses cards are short with a "📈 Progress" button; tapping it opens the path, Cup bar, stages and Legs rows on every card ("📈 Hide" folds them). The buttons never scroll out of reach.
8. Win a Cup and move up, then win in the new league: the ceremony still plays (it's counted per league).

## Legs and the vet (fun-and-return phase 3, D-077, David's decision)

Switches: `GameConfig.legs.enabled`, `GameConfig.vetCheck.enabled`. Numbers: `legs.runLimit` 6, `warnAt` 5, `careLowers` 2, `restSeconds` 1800, `fromRaces` 26, `careCooldownSeconds` 7200, `wrapRaces` 3; `vetCheck.minSeconds` 12. For a quick test in Studio set `legs.fromRaces = 0`.

1. A horse with fewer than 27 counted races never builds a run (the Legs pips stay empty).
2. Race the same horse 5 rated races in a row: the card's Legs row has 5 sky-blue pips and "🧣 Worked hard! Cool-down soon". Nothing red anywhere.
3. One more: RACE! turns sky blue and says "🩺 VET CHECK". The results card's button says "🩺 Vet check". The Next-thing pill says "Vet check for Comet!".
4. Tap VET CHECK: you travel to the Vet (fade) and the Cool-down Check opens. Practice from 🔀 Pick still joins.
5. Try a rated race from 🔀 Pick with that horse: the toast "🩺 Vet check first! Practice is open." and you are **not** put in line (the server turns it away).
6. The check: tap each of the 4 legs (gold ring, rising tick), hose each leg 3 taps (💧 then ❄️, water sound), pick a colour then tap each leg (🧶), tap the 🥕 Carrot (munch, nicker, chime, hearts). About 30 s. No price, no 💎, no 💵 anywhere. Closing early does nothing to the horse.
7. After it: "🩺 Comet is fresh and ready!", RACE! is back, the pips are empty, and the stall horse wears coloured wraps on its legs. They show in the next 3 races (check they follow the running legs; if not, set `horseLook.wrapsInRace = false`) and then come off.
8. Feed then brush a horse at 6: the run drops to 4 then 2. Brushing again within 2 h doesn't lower it again. A Spa Day, a training ride, or 30 min without racing that horse empties it.
9. Words: nowhere does any screen say hurt, sore, injury, limp or sick (the lint test checks every string; also read the Grown-ups page).

## The life arc and the Riding School (fun-and-return phase 4, D-078; ageing is David's decision)

Switches: `GameConfig.ageing.declineScale` (1 = real decline; 0 = stages only), `GameConfig.horseLook.veteranLook`, `GameConfig.lend.enabled`, `GameConfig.rehome.enabled`. Sell bonus cap `sell.recordBonusCap` 100.

1. Stage chips 🍼 Young · 💪 Prime · 🦉 Veteran · 👑 Legend on every card, the current one gold and wide enough for its word ("🦉 Veteran" fits). 🍼, not 🌱: 🌱 is the garden seeds and the Market family line. A horse under 30 races says "🍼 Young: training grows faster!" and a training ride gains about a quarter more (never past Potential or the week's cap).
2. In Studio, set a horse's `record.races` to 345: "🦉 Veteran in 5 races". At 350 with stats near Potential: "💪 Comet is at full strength!". At 390-399: "🦉 Comet is getting wise. Soon a little slower." No number is ever shown.
3. A Veteran (350+ races) in its stall, on a ride and in a race has a frosted (pale) muzzle and brows and a silver-and-blue rosette by its left ear; a Legend's rosette is gold. **Studio check:** the frost sits on the nose (tune `horseLook.muzzle`, `brow`, `rosette` fractions per coat model), and the horse looks wise, not ill.
4. The 👑 Legend button appears only at 350 races (`career.veteranAt`).
5. 🏫 School on a horse card (or the school sign at the Market Corral, prompt "Lend or sell") opens the Riding School card with that horse first. Two buttons per horse: "🏫 Lend" and "💵 Sell"; each needs a second tap ("Sure? 🏫" / "Sure? 💵").
6. A lent horse shows only 🏠 Home (no Sell over it); selling it is refused with "Bring Comet home first!".
7. Lend: free. The horse leaves its stall (a pasture horse moves in), can't race, its card says "🏫 At Sunny Meadow Riding School" with "🏠 Home", and it stands by the school sign at the corral with its name. 🏠 Home brings it back to a free stall (or the pasture). Your last racing horse can't be lent.
8. Sell a Market horse: the card shows "Sell for 💵 N" = half the price paid plus 5 a win and 100 a Cup, at most +100; never more than you paid. A tamed or gifted horse shows "🏵️ Goodbye rosette" and sells for 0. The first horse never shows Sell. Undo still works for 3 days.
9. The word "Rehome" appears nowhere on screen.

## Visiting other stables (D-079)
Setup: Studio → Test → Clients and Servers with **3 players**, or a live private server with 3 accounts. Account **A** owns the barn. Account **F** is A's Roblox friend. Account **S** is not friends with A or F. Each account picks a starter horse first, so each has a barn. Studio's local test accounts aren't Roblox friends, so the friend rows need a live server with two real accounts that are friends (or a TrainingFriends stub for Studio only).

**Permission matrix** (what the server allows; a closed gate blocks every cell):

| A's setting | Visitor | Come in / Map list | Tour + pin | Pat | Cheer | Treat | Post box |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 👫 Friends (default) | F (friend) | yes | yes | yes | yes | yes | yes |
| 👫 Friends | S (stranger) | no | no | no | no | no | no |
| 🌍 Everyone here | F | yes | yes | yes | yes | yes | yes |
| 🌍 Everyone here | S | yes | yes | yes | yes | **no** | **no** |
| 🔒 Nobody | F or S | no | no | no | no | no | no |

Strangers also need Roblox to allow content sharing for **both** accounts (PolicyService `IsContentSharingAllowed`, and not `IsSubjectToChinaPolicies`). If it doesn't, A's barn reads as Friends for S: S sees solid walls and no listing, and is never bounced back to the gate.

- [ ] **The setting.** On A, open ⚙️ → Settings. "Who can visit my stable?" shows three buttons: 👫 Friends, 🌍 Everyone here and 🔒 Nobody. Friends is gold on a new profile. All three fit beside the label.
- [ ] **Old saves.** A profile saved before D-079 with "Club" shows Friends as gold and works as Friends.
- [ ] **The one-time ask.** On S, open Map → Visit barns for the first time. Under the list (the list stays visible), a strip says "Let other riders visit?" and "Who can come to your barn?", with 👫 Friends (gold, the current choice), 🌍 Everyone and Not now. Not now keeps Friends; it asks again after a rejoin. Pick Friends or Everyone: close and reopen shows no ask, and rejoining still shows none. If you set Nobody in ⚙️ on a new profile first, the ask never shows and Nobody stays.
- [ ] **Friends, the default.** A on Friends. On S: Visit barns shows no A, and A's walls are solid. On F: A shows with A's face and "👫 Friend ▶".
- [ ] **Everyone here.** Set A to 🌍 Everyone here. On S: within a second, A's barn shows with a 🏡 picture (never A's avatar face) and "🌍 Open ▶". Friends' barns are listed first. There are no numbers, likes or rankings on any row.
- [ ] **Teleport to the gate.** On S, tap A's barn. S lands on Barn Lane outside A's gate, facing in, never inside the fence.
- [ ] **Arrival banner.** On S, walk through the gate. The gate bell rings once and "Welcome to A's barn!" pops in and fades after about 2.5 s. With Reduced Motion on, it shows without the pop. The top bar shows "🏡 A's barn", 4 pips, 🎉 Cheer and 🏠 Home. On F the bar also shows 👫.
- [ ] **Walkaround.** Gold hoofprints lead to the Rosette Wall. Standing there plays a tap sound and shows "Look! Rosette Wall", and the first pip turns 📍. Each stop gives the featured thing (the wall, a stall horse, a yard piece, the paddock or the garden) a gold outline for 1.2 s and a small gold sparkle (outline only with Reduced Motion). Then the trail goes to the horses, then their yard, then the Legend paddock if A has a Legend, otherwise their garden ("Look! Their garden"). On the 4th stop, "📍 Tour pin! You toured A's barn" shows with the job-done sound and the trail stops. Visit barns and the Horse Book show one more Tour pin.
- [ ] **Pin once per barn.** On S, leave, come back and walk all 4 stops again, even on another day: no second pin. A different open barn gives a second pin.
- [ ] **Stranger actions.** On S at A's barn: the stall doors show **Pat** only (no Treat). The post box shows no "Drop a carrot". Pat gives "Comet nuzzles you!" with hearts, and A's horse gets no bond.
- [ ] **Server refuses a stranger's treat.** From S's command bar, fire `VisitCare` with A's id, a horse id and "treat", and `PostBox` with A's id. Nothing happens: no bond, no carrot.
- [ ] **Cheers.** On S, tap 🎉 Cheer: 4 buttons (👏 🎉 😍 🌈) replace the name. Tap 👏: a 👏 floats up about 3 studs from A's barn door and fades, with a clap. 🎉 plays the tap_good sound instead. S sees "Cheer sent! 👏". A sees "A visitor cheered! 👏", with no name, and the same emoji over the door if A is home. The 4th cheer in total that day says "You cheered here today. Thank you!". A sees at most one cheer toast every 30 s.
- [ ] **Friend actions.** On F at A's barn: Pat, Treat (+1 bond, once a day) and Drop a carrot (one a day) all work, as before D-079.
- [ ] **The owner's gate works for everyone.** With S (or F) in A's yard, A sees 🚪 Close gate. Tap it: everyone is walked out to the lane, the walls go solid, and S's barns list drops A. Tap 🔓 Open gate: "Gate open. Visitors welcome." and A is listed again.
- [ ] **Ask to leave.** With S in A's yard, A sees 👋 Ask to leave beside 🚪 Close gate. Tap it: a list of who's in the yard. Tap S's name: S is walked out to the lane and sees "Time to head home!". For 2 minutes A's walls stay solid for S and S's barns list drops A, then A is back. F stays inside the whole time. Firing `AskToLeave` from a non-owner, or for someone outside A's yard, does nothing.
- [ ] **No second bell.** Walk out of A's gate and straight back in: no bell and no banner, but the bar returns. After 20 s outside, it rings again.
- [ ] **Nobody blocks all.** Set A to 🔒 Nobody while S and F are inside: both are walked out within a second, neither lists A, and every remote (VisitHello pat, cheer and stop; VisitCare; PostBox; VisitFriend) does nothing.
- [ ] **Rate limits.** Spam VisitHello from S's command bar: at most one call each 0.5 s does anything. Spam VisitFriend: one trip each 3 s.
- [ ] **Stop spoofing.** From S's command bar, fire `VisitHello` with A's id, "stop" and "paddock" while standing at the gate: nothing counts. Only standing at the stop does.
- [ ] **No text anywhere.** There's no text box or typed field in any visit screen.
- [ ] **Racing.** Join a race while visiting: the visitor bar hides, and no pats or cheers send during the race.
- [ ] **Home.** 🏠 Home takes S back to S's own stable and clears the trail.
- **Studio check:** PolicyService must answer for both players, or strangers are kept out (fail closed). If S can't see A on Everyone here in Studio, try a live private server. The yard stop (inward 72, across 28) and the paddock stop should stand in open ground; move them in `GameConfig.visit.tourStops` if a prop is in the way. A barn with no Legends still has the paddock stop (an empty fenced spot).

## Breeding (D-080)
Switches: `GameConfig.breeding.enabled` (with `career.suggest`; false hides the Foal Barn, its Map tile and the Family page), `GameConfig.foalLook` (the foal's shape, the tag-along). Fast setup: `GameConfig.studioTest.breedReady = true` (Studio only), then Stop and Play: the Output says `[StudioTest] ... breedReady: Comet and Maple at 30 races` and you have two parents, the Bronze fee, no wait, and a foal on the way arrives at once.

- [ ] **The Map.** 🗺️ shows 14 tiles in the 5 × 3 grid; tile 14 is "💞 Foal Barn" with "Foal soon" (or "Foal here!" when a foal waits). Everything fits at 667 × 375. GO takes you to the cream-and-sky barn east of the Vet (red roof, white-rail paddock with two grazing foals, planters) and opens the panel.
- [ ] **Pick two parents.** Two slots over your horses. Horses that can't be parents are grey with a short reason ("Needs 30 races", "Lent", "Out riding"). Tap two ready ones, then Next ▶.
- [ ] **Your foal.** "Family 🌱🌱" (sprouts, no numbers). The Coat chances box: one row per parent coat (swatch, name, bar, 45%) and one row per Surprise coat with its own swatch and chance ("❔ Surprise: Dun 2.5%"; all rows add to 100%). Two parents with the same coat: one row at 90%. The word is "chance" everywhere. "Fee 💵 400" (higher parent's league). The confirm takes two taps: "💞 Have a foal" then "Sure? 💵 400". Diamonds are never mentioned.
- [ ] **Refusals.** Neither parent in Bronze: "One parent needs Bronze". Not enough Green Cash: refused, nothing taken. Stable at 20: "Make room first" with "🏫 Lend or Sell". After one foal: "Next foal in N races" (counted in races, no clock).
- [ ] **Waiting.** The panel shows both parents and "Arrives in 8 races or tomorrow" (it counts down in races). A second confirm is refused. Rejoin: the same foal is still on the way (the roll was made once at confirm).
- [ ] **Here.** After the races (or the next day) a toast "💞 Your foal is here!", shown only once the results card is closed; the Map hint says "Foal here!". At the barn: "Meet your foal ▶".
- [ ] **The meeting.** A side shot of the paddock: the parent stands, the foal steps out from behind its flank, turns and nuzzles twice, hearts rise; a high nicker then a lower answer, then the job-done chime. No confetti. A Surprise coat adds only "❔ A surprise coat: Dun!" and a few sparkles. Tap skips after 1 s. Reduced Motion: the foal fades in, hearts kept.
- [ ] **Naming.** Exactly like the Starter: word chips, "🔀 New words", "That's the name!". The ✕ closes it and the foal waits at the barn. Then the name plate drops in over the foal letter by letter, it nods twice, a ding and two claps, "Hello, Pebble! 🌱".
- [ ] **The foal.** In My Horses as a 🍼 Young Rookie, in a free stall (or the pasture). In the stall it has long legs, a small body and a big head, growing to adult size by 30 races. **Studio check:** hooves on the ground, nothing floating or sunk; the one-piece stand models look leggy, not stretched.
- [ ] **Running legs.** A foal walking behind its parent, and riding the foal itself: legs under the body, hooves on the ground (no splayed or sunken legs). Same after it grows a step (a few races later) and in its races. If the one-piece stand foal's head looks tall instead of its legs long, set `foalLook.onePieceStretch = 0` (a uniform small foal).
- [ ] **Tag-along.** For its first 10 races the foal stands at its parent's flank, and trots 6 studs behind when you ride the parent (never faster than the parent + 4), with a little hop every 8–14 s (no hops with Reduced Motion). Never during a race, in line or on a training ride.
- [ ] **First race.** The foal's first counted race: once, after the results, a gold "🍼 Comet's foal!" banner (tap to skip). In the race the foal is near full size (never under 0.94).
- [ ] **Horse Book.** 📖 → 💞 Family: the foal with "Comet + Maple", the first one marked "First foal". With no foals: "Two horses can start a family".
- [ ] **Selling.** The foal's Sell price at the school is less than the fee paid.
- [ ] **Legends.** A Veteran's Legend card now says "Legends can be parents!"; a Legend can be picked as a parent.
- [ ] **Grown-ups.** ⚙️ → For grown-ups has the 💞 Foals paragraph (after Riding School, before the Parental Controls line).
- [ ] **Words.** Nowhere: odds, mare, stallion, birth, blood.

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
