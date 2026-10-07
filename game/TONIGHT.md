# Tonight's playtest (2026-10-07): about 45 minutes

Everything below was built today from debate 013 (D-058 to D-065) and has passed every automated test, but none of it has run in Roblox Studio yet. Go in order; stop and note anything that breaks (a screenshot of the Output window helps most). The full checklists are in `PLAYTEST.md`, section names in brackets.

## Setup (5 min)
1. Open `game/GiddyUp.rbxl` in Roblox Studio (or `cd game && rojo serve` and connect the Rojo plugin).
2. Game Settings → Security → turn on **Enable Studio Access to API Services** (so saving works).
3. Publish to the **LlamaWorks** group once (File → Publish to Roblox As) so today's new models and icons can load. Until Roblox moderation approves them you'll see simple placeholder shapes or emoji; that's expected.
4. Press **Play**. The Output window should have no red errors. Note any red line.

## 1. It doesn't get stuck (5 min) [Playtest-safe fixes]
- You get into the game; you are never stuck on "loading" and never kicked. (Stop and press Play again right away: you should see "Opening your stable…", not a kick.)
- The player list (top right) shows no Green Cash or Wins column.
- Device emulator → a phone in landscape: the bottom dock has 3 big buttons (horse card, RACE!, ☰ More), all fingertip-sized, words readable.

## 2. One tap to race (10 min) [One race button and the queue card]
- Tap **🏁 RACE! with Comet**: a card shows a countdown ring, 8 gate slots filling with horse names, "🤖 Bots join at 0". You're in a gate within about 20 s.
- While waiting, walk off and brush your horse: "Race time!" calls you back.
- Race 2 or 3 times: you should win some (about 1 in 4 for a new horse), not every race and not never.
- The results card is one simple row: "You rode ★★☆", plus "Your taps gained Comet N places!" only when it's good news. "🏅 New best!" appears when you beat your best.

## 3. Tired horse and Spa Day (5 min) [Spa Day and rest cues]
- After a race the dock still says **Ready** with horseshoes. Race until 0 horseshoes: it says **Napping**, and in the stall the horse yawns at 1 and lies down at 0. No word anywhere says hurt, sore or sick.
- Go to the Vet: choose **🛁 Spa Day**, then Rinse, Brush, Dry. You get +1 horseshoe, a Spa stamp and a sparkle on the next race. Try again: "🌙 Spa opens again tomorrow".

## 4. Clear screens (5 min) [Clarity pass]
- One "Next thing" pill suggests one action with a GO button; following it works.
- The Stable Board has Today / Week / Month / 🏵️ Goals tabs; jobs show there, not as a flood of pop-ups.
- Stars only ever mean "how you rode"; Energy is always the horseshoe.

## 5. Coming back, careers, classes (10 min) [Reasons to come back] [Careers, Legends and rehoming] [Classes and the Rosette Wall]
- **📖 Book** (in ☰ More on phones): coats, rosettes, courses, Passport and bests pages, with grey "?" for not-yet-earned.
- After a win: the **📷** photo button opens Roblox's own save/share prompt.
- Horse cards show a class badge (🐣 First Win → 🚀 Rising Star → 🎽 Open) and a career row; your yard has a Rosette Wall.
- Market Corral → **Sunny Meadow Riding School** sign: rehoming a bought horse (not your starter) offers half what you paid, then a goodbye card with **Undo** (72 h). Your starter and your last racing horse can't go.

## 6. Two players (5 min) [Visiting friends' barns]
- Test → Clients and Servers → 2 players (they aren't Roblox friends): Map → **👫 Friends' barns** is empty for both, and walking into the other player's plot walks you back out.
- Visiting a real friend's barn (pat for a Tour stamp, one treat, a carrot in the post box, the owner's **🚪 Close gate**) needs two friend accounts on a published server; leave it for another day if that's awkward.

## What to tell Claude afterwards
- Any red errors in Output, and what you were doing.
- Anything a kid wouldn't understand, or a button that was hard to hit on the phone emulator.
- The provisional calls to confirm or change, listed in `docs/memory/REVIEW_QUEUE.md` (top ones: no injury or ageing; rehoming at half price; Silver Cup opening at 750 points, which also brings Gold sooner).
