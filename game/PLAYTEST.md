# First Studio playtest checklist

The agents can't open Roblox Studio, so the server and client scripts have only been compiled, not run. Use this the first time you play the prototype, and paste anything that fails into a session (screenshots help).

## Setup
- [ ] `cd game && rojo serve`, connect the Rojo plugin in a new Baseplate, press Play.
- [ ] Publish the place to the **LlamaWorks** group (File → Publish to Roblox As), so it can load the uploaded art.
- [ ] Output window shows no red errors on start. `[AssetService] ... not loaded yet` warnings mean an asset is still in moderation or the place isn't group-owned; placeholders show meanwhile.

## Track and art
- [ ] You spawn on grass outside the home straight, beside the finish line, facing the track; invisible walls stop you leaving the field.
- [ ] An eight-lane dirt oval: two straights and two smooth turns, white inner and outer rails, a checkered start/finish line with the finish post outside it.
- [ ] Eight horses (bay, chestnut, grey, black, palomino, then repeats) stand in starting stalls at the line, each with a lane badge 1–8. Without the models, brown block horses stand in.
- [ ] Your horse has a YOU marker above it.
- [ ] When the race starts you're seated on your horse as its jockey and the camera rides along; Space or tapping doesn't throw you off.
- [ ] Your rider sits on the horse's back (not floating or sunk in). If not, note roughly how far off; `SADDLE_HEIGHT` and `SADDLE_BACK` in `TrackScene.luau` tune it.
- [ ] When the countdown ends the stalls disappear and the horses gallop (with a bob) round the oval, smoothly; the likelier winners edge ahead as chances change.
- [ ] After the Final Burst the horses cross the line one by one in the finish order, then the results panel shows. About 3 s later you're back on the grass by the finish line and can jump again. Players who join mid-race stay on the grass.
- [ ] The hoof, rings, GIDDY-UP pad, burst meter, tap-result shapes, board lane badges and result ribbons show the drawn art.

## Lobby
- [ ] "Next race in N" counts down from 20 (or starts at once with 8 players).
- [ ] The board lists 8 lanes: you (highlighted) plus bots, each with Win chance % and Win purse.
- [ ] Win chances add up to about 100%.
- [ ] The status line shows the race conditions (for example "Rookie race: Mile · Dirt · Sunny").

## Giddy-up stretches (×3)
- [ ] The stretch name appears with "GIDDY-UP!" (The Break, Backstretch, Final Stretch).
- [ ] Each beat sends a ring that closes on the dark hoof in the same time (0.9 s), so two rings are often on screen; the hoof flashes on the beat.
- [ ] The board dims during taps so the ring stands out; the yellow GIDDY-UP pad pulses at the bottom before the first ring, then holds steady while rings are on screen.
- [ ] Tapping anywhere on the screen (or any key, or any gamepad button) counts, but not while typing in chat; each tap shows Perfect / Great / Good / Okay / Off beat.
- [ ] Tapping twice on one beat shows "Broke stride!" and the too-fast hint.
- [ ] Rookie tempo is steady (0.6 s per beat); there are 8 beats.
- [ ] At the end of each stretch a summary appears (Perfect stretch 70+, Great 45+, Good 20+, Keep the beat).
- [ ] Mashing the screen gives a stretch score near 0; tapping on the beat scores well.
- [ ] After each stretch your Win chance updates with a +/− change.

## Final Burst
- [ ] "Final Burst" appears with the meter; the marker starts somewhere different each race.
- [ ] One tap scores (Perfect 95+, Great 80+, Good 60+, Okay 30+, Miss); the tap area hides after tapping.
- [ ] Not tapping shows "Missed!" when the window ends.
- [ ] Win chance swings more after the burst than after a stretch (it counts double).
- [ ] Your burst result plays as a big banner on your screen only; a Great+ burst adds a tiny camera punch (none with Reduced Motion on).
- [ ] Other players' Great+ bursts show only a small ✦ next to their name on the board.

## Integrity (log only)
- [ ] After each race, the Output window shows no errors from integrity tracking. (A flag prints an `[Integrity]` line; nothing is shown to players while `logOnly` is on.)

## Results
- [ ] Results list the top 4 and your place, with Green Cash for 1st–4th.
- [ ] leaderstats Green Cash and League Points increase by the right amounts.
- [ ] A new lobby starts about 5 seconds later.

## Network and edge cases
- [ ] Studio Test → Clients and Servers with 2–3 players: everyone sees the same lanes and chances.
- [ ] Network simulator at 200 ms latency: well-timed taps still score well.
- [ ] A player leaving mid-race doesn't break the race for others.

## Feel (write down impressions)
- Can a young player find the beat in their first stretch, or do they mash? Is 0.6 s per beat comfortable?
- Is the Final Burst exciting enough, and is double weight too much or too little?
- Can you tell how your taps changed the result?
- Is anything confusing in the first 30 seconds?
