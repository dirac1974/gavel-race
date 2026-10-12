# Tonight's playtest (2026-10-12): about 70–85 minutes

Everything below was built since the last playtest (D-071 to D-079). It has passed every automated test, but none of it has run in Roblox Studio yet. Go in order; stop and note anything that breaks (a screenshot of the Output window helps most). The full checklists are in `PLAYTEST.md`, section names in brackets.

**New tonight: the Studio test block.** `GameConfig.studioTest` (in `ReplicatedStorage.Shared.GameConfig`, or `game/src/shared/GameConfig.luau` with Rojo) sets your active horse's long-term state when you join, so you don't have to race hundreds of times. It works only in Studio, never on a live server. Each change needs **Stop, then Play** (it runs on join), and the Output shows one `[StudioTest]` line saying what it set. All values start off (`0` / `false`). It writes your Studio save, so set everything back to off when you're done.

## Setup (5 min)
1. Open `game/GiddyUp.rbxl` in Roblox Studio (Claude rebuilds it after tonight's changes), or run `cd game && rojo serve` and connect the Rojo plugin.
2. Game Settings → Security → turn on **Enable Studio Access to API Services** (so saving works).
3. Press **Play**. Pick a horse if you don't have one yet.
4. Check the Output window: no red errors. Note any red line.

## 1. Forward jump (5 min) [Forward jump]
studioTest: all off.
- Ride, stop, press Space (phone: ⬆️ Hop): the horse hops **forward** about half a body length, never straight up.
- Gallop and hop: it carries about 2 lengths and lands without stopping. No stutter in the air; a second press within 0.6 s does nothing.
- In the air the legs fold and the nose tips up then down; on landing a small squash, a soft thud and a dust puff.

## 2. Race arrows, filing in and passing (15 min) [Race arrows] [Filing in and passing]
studioTest: all off. Race 3 or 4 times.
- The ◀ ▶ buttons show from race 1. After "Lanes locked!" and on the results card, ←/→ do nothing and the camera never turns. On foot after Done, the arrows turn the camera again.
- After the gate, most horses drift to the rail and run as a loose pack that wanders, not in columns.
- Bots stuck behind a slower horse move out, go by side by side for about a second, then come back in. Nothing pops or teleports.
- Press toward a bot level with you: sometimes it shuts the door (turns a little toward you, a soft knock, "No room yet!"). It never moves you.
- In Output, each race prints a `[Trip]` line ending `pack: out N, passes N, doors shut N`. Expect a few passes a race.
- **The passing calibration may still be pending.** If Output shows `[RaceService] no trip baseline for …`, the style baselines are missing (posts count as equal). Tell Claude which course it was.

## 3. Find it (10 min) [Find it]
studioTest: all off. Device emulator at 667 × 375 landscape, touch on, for the phone checks.
- 🗺️ **Map**: 14 tiles in a 5 × 3 grid (the 14th is 💞 Foal Barn, step 8), each with a picture and a short line. All fit on the phone with nothing cut off.
- **GO**: from your barn tap Market: a cream fade, you arrive, and the first horse card opens. From Fair Street tap Feed & Seed: golden hoofprints instead of a trip.
- **Phone dock**: 5 items: horse portrait, 🏁 RACE! with 🔀 Pick, 🗺️ Map, 📋 Jobs, ☰ More. Nothing covers Hop or Gallop. Dragging the thumbstick from the portrait walks you and doesn't open My Horses.
- **Queue card ❓**: join a race: the card names the line ("🟠 Bronze race line"). The first time, a 3-picture "How racing works" strip opens by itself; ❓ opens it again any time.
- **🔀 Pick**: opens "Pick a race" without putting you in line; its Join button names the line.

## 4. Visible progress (8 min) [Visible progress]
studioTest: `horseWins = 4`, `leaguePoints = 90`. Stop, Play.
- 🐴 My Horses: five chips 🐣 🚀 🎽 💐 🏆 with 🎽 Open gold, "💐 Top Horse: 1 more win", and a 🏆 Cup bar almost full with **no number**.
- Win a rated race (not Practice). The results card shows "🏆 Cup +10" and the bar fills with rising ticks. RACE! again is tappable at once.
- Ride home to your Rosette Wall: a gold sparkle, a ding and three claps, and one line about the new step. It ends by itself in under 4 s.

## 5. Legs and the vet (10 min) [Legs and the vet]
studioTest: `legsFromRaces = 0`, `legsRun = 5` (others off). Stop, Play.
- The card's Legs row: 5 sky-blue pips and "🧣 Worked hard! Cool-down soon". Nothing red.
- Race one rated race: RACE! turns sky blue and says "🩺 VET CHECK". A rated race from 🔀 Pick is turned away ("🩺 Vet check first! Practice is open."); Practice still joins.
- Tap VET CHECK: you go to the Vet and the Cool-down Check opens. Check legs, hose, wraps in a colour, carrot. About 30 s, no price anywhere.
- After it: "🩺 Comet is fresh and ready!", empty pips, coloured wraps on the horse for the next 3 races.
- Nowhere says hurt, sore, injury, limp or sick.

## 6. Life arc and the Riding School (10 min) [The life arc and the Riding School]
- studioTest `horseRaces = 345` (others off): the card says "🦉 Veteran in 5 races".
- Then `horseRaces = 400`, `nearPotential = true`: 🦉 Veteran chip, "💪 Comet is at full strength!", a frosted muzzle and a silver-and-blue rosette by the left ear (stall, ride and race), and the 👑 Legend button. The strong stats may open the Cup; that's expected.
- Then `horseRaces = 445` (keep `nearPotential`): "🦉 Comet is getting wise. Soon a little slower." No number is ever shown.
- 🏫 School on the horse card: "🏫 Lend" and "💵 Sell", each needing a second tap. Lend a horse (needs a second horse): it leaves its stall and stands by the school sign; 🏠 Home brings it back. The word "Rehome" appears nowhere.
- Set studioTest back to all off.

## 7. Visiting with 3 players (10 min) [Visiting other stables]
studioTest: all off. Test → Clients and Servers → **3 players**; each picks a starter horse.
- ⚙️ Settings: "Who can visit my stable?" with 👫 Friends (gold), 🌍 Everyone here, 🔒 Nobody.
- Player 1 sets 🌍 Everyone here. Player 2's Map → Visit barns lists that barn with a 🏡 picture. Tap it: you land outside the gate; walk in: bell, "Welcome to …'s barn!", the visitor bar.
- Follow the gold hoofprints through 4 stops for a 📍 Tour pin. Strangers get Pat only (no Treat, no post box). 🎉 Cheer floats an emoji over the door.
- Player 1's 🚪 Close gate walks everyone out; 🔒 Nobody does too.
- **The friend rows need a live server**: Studio's test accounts aren't Roblox friends, so 👫 Friend rows, Treat and the post box can't be checked here.

## 8. Breeding (10 min) [Breeding (D-080)]
studioTest: `breedReady = true` (others off). Stop, Play. Output: `[StudioTest] ... breedReady`.
- 🗺️ Map → 💞 Foal Barn: you arrive at a cream-and-sky barn east of the Vet and "Pick two parents" opens.
- Pick Comet and Maple, Next ▶: "Family 🌱", the Coat chances box (45% / 45% / ❔ Surprise 10%), "Fee 💵 400". Tap "💞 Have a foal", then "Sure? 💵 400".
- "Arrives in 8 races or tomorrow". Stop and Play again (breedReady makes it arrive at once): "💞 Your foal is here!". Back at the barn: "Meet your foal ▶": the foal steps out, nuzzles, hearts, two nickers. Name it with the word chips.
- The foal in its stall: small body, long legs. Ride its parent: it trots along behind. Its first race: "🍼 Comet's foal!" after the results. 📖 → 💞 Family lists it.
- Set `breedReady` back to false.

## What to send back
- Screenshots of any red errors in Output, and what you were doing.
- Anything confusing, or a button that was hard to hit on the phone emulator.
