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
