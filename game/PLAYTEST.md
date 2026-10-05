# First Studio playtest checklist

The agents can't open Roblox Studio, so the server and client scripts have only been compiled, not run. Use this the first time you play the prototype, and paste anything that fails into a session (screenshots help).

## Setup
- [ ] `cd game && rojo serve`, connect the Rojo plugin in a new Baseplate, press Play.
- [ ] Output window shows no red errors on start.

## Lobby
- [ ] "Next race in N" counts down from 20 (or starts at once with 8 players).
- [ ] The board lists 8 lanes: you (highlighted) plus bots, each with Win chance % and Win purse.
- [ ] Win chances add up to about 100%.
- [ ] The status line shows the race conditions (for example "Rookie race: Mile · Dirt · Sunny").

## Gavel windows (×3)
- [ ] The window name appears (The Break, Backstretch, Final Stretch).
- [ ] The marker sweeps smoothly at constant speed; the green zone is in the middle.
- [ ] Tapping the big button, Space, or gamepad A sends one tap; the button hides after tapping.
- [ ] Feedback shows a label and score (Perfect 95+, Great 80+, Good 60+, Okay 30+, Miss).
- [ ] Not tapping shows "Missed!" when the window ends.
- [ ] After each window your Win chance updates with a +/− change.
- [ ] Perfect taps raise your chance; misses lower it.

## Results
- [ ] Results list the top 4 and your place, with Green Cash for 1st–4th.
- [ ] leaderstats Green Cash and League Points increase by the right amounts.
- [ ] A new lobby starts about 5 seconds later.

## Network and edge cases
- [ ] Studio Test → Clients and Servers with 2–3 players: everyone sees the same lanes and chances.
- [ ] Network simulator at 200 ms latency: well-timed taps still score well.
- [ ] A player leaving mid-race doesn't break the race for others.

## Feel (write down impressions)
- Is the Rookie meter speed (2.4 s sweep) easy enough for a young player's first race?
- Can you tell how your taps changed the result?
- Is anything confusing in the first 30 seconds?
