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
