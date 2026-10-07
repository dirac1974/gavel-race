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
