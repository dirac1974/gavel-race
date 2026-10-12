# Proposal: UI/UX for fun and return (2026-10-12)

Lens: phones first (667 × 375 landscape), ages 8–13. David asked that "UI and ease of understanding should be a focal point".

**The core problem:** most of the game already exists, but kids can't find it (inventory.md). Every proposal below makes a built thing visible before anything new is added.

Conventions:
- Copy is 6 words or fewer.
- Sizes are unscaled, at the D-064 floors (16 px text, 64 px buttons, scaled no lower than 0.875).
- **[TOP-8]** marks this evening's build.

## 1. Discoverability overhaul

### 1a. A Map tile for every place [TOP-8] (S–M)
**Files:** `shared/WorldLayout.luau` (`MAP`, `MAP_LABELS`, `MAP_ICONS`, `MAP_EMOJI`) and `client/WorldClient.client.luau`.

**Grid**
- 5 columns × 3 rows of 116 × 96 tiles: a 48 px icon over an 18 px word, with 8 px gaps.
- The header row is 56 px tall.
- Total 368 px, which renders at 322 px at the floor scale and fits the phone without scrolling.

**Tiles, in order**

| # | Tile | Notes |
| --- | --- | --- |
| 1 | My Stable | |
| 2 | Racetrack | |
| 3 | Race Board | |
| 4 | Fair Street | |
| 5 | Feed & Seed | |
| 6 | Barn Builder | |
| 7 | Tack & Paint | |
| 8 | Vet & Spa | |
| 9 | Market | |
| 10 | Training | was "Training Paddock" |
| 11 | Riding Ring | was "Training Ground" |
| 12 | Trail | |
| 13 | Visit barns | |

**What-to-do line**
- Each tile may show one plum line of 2 words or fewer saying what can be done there: "Spa today", "3 horses", "New shelf".
- These are facts only: no red, no counts of things owed, no badges (D-043).
- This line is the "what can I do" hub. **No separate hub screen:** that would be one more panel to find.

**Fix:** Map and Book both use dock `LayoutOrder` 4 (`Hud.client.luau`). Set Book to 6.

### 1b. GO opens the thing [TOP-8] (M)
**File:** new `client/GoTo.luau` with `GoTo.place(place, open)`.

**Walk or teleport**
- If the place is ≤ `go.walkMaxStuds` (120) away, draw hoofprints as today.
- If it's further, fade to white over 0.3 s, Map-travel there (the existing arrival), then fade in.

**Then open the feature**

| Place | Opens |
| --- | --- |
| board | `OpenBoard` |
| feedStore | Barn Builder |
| vet | Spa / Check-up card |
| market | the corral list |
| paddock | the Train menu |
| raceBoard | the picker |

**Wiring**
- Tour, Advice, job and Map GO buttons all route through `GoTo`.
- Button copy: "GO ▶" when the place is near, "Take me ▶" when it's far.
- **Never while in line or racing.** In those states GO shows "After your race!".

### 1c. First-time pointers [TOP-8] (S)
**Files:** `shared/Advice.luau` (`firstTime`) and `client/StableBoard.client.luau` (the pill).

When a feature first becomes relevant, the pill shows "New!" with GO, and the target dock button or Map tile gets a pulsing gold ring for 6 s. Reduced Motion: a static ring.

| Feature | Copy |
| --- | --- |
| Market | "New! Meet horses at Market" |
| Barn Builder | "New! Build things for your barn" |
| Visit barns | "New! Visit other barns" |
| Horse Book | "New! Your Horse Book" |
| Spa | "New! Spa Day at the Vet" |

- At most one per 3 minutes.
- Never during the tour or within 120 s of a race.
- The "seen" state is stored in `p.flags.seen[id]`.

### 1d. Phone dock: 5 items [TOP-8] (S)
**File:** `Hud.client.luau`, with `ui.dockPhoneItems = 5`.

**Order**
1. A 70 px horse portrait: a coat dot over the Energy pips. Tapping it opens My Horses.
2. 🏁 RACE!
3. 🗺️ Map
4. 📋 Jobs
5. ☰ More, which holds Ride, Book, Cash and Horses.

**Fit:** 70 + 200 + 3 × 70 + 40 = 520 px. At 0.875 that's 455 px, which fits the 467 px space beside the right-hand Hop/Gallop column (`movementColumn`).

## 2. Queue clarity

### 2a. The card names the line and why [TOP-8] (S)
**Files:** `shared/QueueView.luau` (`lineTitle`, `lineWhy`) and `client/QueueCard.client.luau`.

| Line | Title | Why |
| --- | --- | --- |
| League race | "🥉 Bronze race line" | "Horses like Comet race here" |
| Cup | "🏆 Bronze Cup line" | "Only Cup horses" |
| Practice | "🎈 Practice line" | "Anyone! Horses all equal" |

- On a phone the compact row reads "🥉 Bronze line · 12".
- Tapping the row opens it to show the "why" line plus the gate.

### 2b. "How racing works" (S)
- A 56 px "❓" button on the queue card opens a strip of 3 pictures, each 180 × 150 with one line:
  1. "Join a line"
  2. "Riders fill the gate"
  3. "Bots fill spots at 0"
- It also shows once by itself, the first time a player is in line.
- Close: ✕, or "Got it!".

### 2c. Choose a race before joining [TOP-8] (S)
- Split the RACE! slot: 144 px main + a 56 px "🔀 Pick" strip.
- "🔀 Pick" fires `OpenRacePicker` without joining a line. The picker already works outside the queue.
- The picker's title becomes "Pick a race", and its Join button says which line it puts you in, e.g. "Join Bronze line".

## 3. UI for David's directions (decided by David)

### 3a. Class ladder and prestige (M)
**Files:** `client/HorsesClient.client.luau`, the picker cards and new atlas icons `grade_g3`, `grade_g2`, `grade_g1` (shield-ribbons with letters, made with `make_ui_svgs.py`).

**Horse card: the class path** [TOP-8 with the Cup bar]
- 5 dots joined by a line: "First Win · Winner · Stakes · G3 · G1".
- The current step is gold. Locked steps are slate outlines.
- One plum line says what's next: "Next: win 2 more".

**Cup bar**
- "🏆 Cup" next to a 160 × 12 bar that fills with League Points.
- No number. Today League Points have no UI at all.
- When full, the bar turns gold and reads "Cup open!".

**Picker: graded cards**
- The card shows its shield: "G3 Daisy Stakes".
- A locked card reads "Needs 3 wins". Never "points".

**Titles**
- "G1 winner" on the card and the nameplate.
- Earned only. No public ranking (D-042).

### 3b. Age and life stage (S)
- **Card strip:** 4 icons at 32 px with words at 16 px: "Young · Prime · Wise · Legend". The current stage is gold, with "in 12 races" under the next one.
- **Copy:** "Wise" is used instead of "Veteran".

| When | Copy |
| --- | --- |
| Before the decline (shown 10 races ahead, never as a number) | "Comet is getting wise" |
| Then, under it | "Soon a little slower" |
| In Practice | "Equal in Practice!" |

### 3c. Vet check [TOP-8] (M)
Over-running only; no hurt/sick words.

**States**
- Chip colours are sky blue or plum, never red.
- One race before:
  - chip: "💦 Worked hard!";
  - pill: "Vet check soon";
  - the next race's card adds "Then a vet check".
- At the limit:
  - RACE! becomes "🩺 VET CHECK" in sky blue;
  - the picker's cash cards say "After vet check";
  - Practice stays open: "🎈 Practice still open".
- GO uses `GoTo` (vet) to open the check card.

**Check card**
- 3 big 96 px steps with progress dots, about 30 s in total:
  1. "Cool water"
  2. "Soft wraps"
  3. "Carrot!"
- It ends with "All fresh! Ready to race!".
- Uses the wash bay. No wound, limp, blood or needle.

**Files**
- A new pure `shared/VetCheck.luau` for the state.
- `client/CareClient.client.luau` for the card.
- Add "tired-legs", "strain", "lame", "pain" and "bleed" to `Words.BANNED`.

### 3d. Visiting any barn (M)
**Map → Visit barns:** a list of barns in this server.
- Each row: the owner's display name and the gate state, either "👫 Friends" (friends only) or "🌍 Open".
- Closed barns aren't listed.

**Owner setting**
- 3 buttons on your gate sign and in ⚙️: "👫 Friends", "🌍 Everyone here", "🚪 Nobody".
- The default is Friends.

**Visitor top card** (`Ui.slot`, 64 px): "Sam's barn" plus a "🏠 Go home" button.

**What strangers can do**
- "👋 Pat".
- "🎉 Cheer": 4 preset icons, shown to the owner anonymously.
- Treats and the post box stay friends-only.

**Owner, while visitors are in**
- A "👥 2 visiting" chip with a list of names.
- A per-name "👋 Ask to leave" button.
- "🚪 Close gate" for everyone (it exists).

### 3e. Selling (S)
On the My Horses card (not only at the corral):

| Step | Copy |
| --- | --- |
| Button | "🏫 Riding School" |
| First tap | "Comet goes to Sunny Meadow" |
| Two-tap confirm | "Sure? 🏫" |
| Money line | "Get 💵 600 back" |
| Undo (72 h) | "Bring Comet home" |

- No player trading.

## 4. Professional polish

| Item | Spec | Effort |
|---|---|---|
| **Iconography** | Core concepts use atlas art only: Energy shoe, ★ ride, ❤️ care, 🩺 vet, league badges, grade shields, 🎀 stamps. Emoji only inside sentences. `Ui.SYMBOL` table plus a copy test: one meaning per symbol. Fix the open collisions: 🐴 (Horses / Ride / Pip), 🎖️ patch → a stitched patch, 💗 cloth. | S |
| **Typography** | Fredoka One for words, Builder Sans Bold for numbers. Scale: 32 titles, 24 sections, 20 body, 16 minimum. 14 px only for single words, never sentences. Lines ≤ 40 characters. Every `TextScaled` gets a `UITextSizeConstraint` (min 14). | S |
| **Panel transitions** | One `Ui.openPanel` / `closePanel`. Open: the dim fades in over 0.15 s and the panel slides up 24 px over 0.22 s (Back ease). Close: 0.15 s fade. Reduced Motion: fades only. One panel at a time: opening one closes the others (`Ui.panelStack`). | S |
| **Empty states** | Every list gets a picture, one line and one action. My Horses with 1 horse: "Find more at the Market" + GO. Visit barns empty: "No open barns yet". Book pages: "Race to find these!". Jobs: "All done today! 🎉". | S |
| **Buttons** | Primary orange, secondary white, gold = selected only, and ✕ is always `Ui.closeButton` at 64 px. | S |
| **Art fallback** | Never show "∩". Until the atlas loads, use a drawn shoe frame. | S |

## 5. Meshy

**Budget:** balance 150, so the cap is 37.

| Asset | Type | Credits | Why |
| --- | --- | --- | --- |
| `fair_signpost` | text-to-3D | 30 | A big county-fair signpost at the spawn on Fair Street. Its arms carry SurfaceGui labels for every Map place, so places can be found by walking too. |
| `grade_trophy` | retexture of `trophy_cup` | 10 | G1–G3 trophies for the Rosette Wall. Only if the signpost costs ≤ 27; otherwise tint the existing cup in code (0). |
| Vet wraps / cold hose | code | 0 | Parts on the existing wash bay. |
| Signage, "Open barn" flags, Market | code | 0 | SurfaceGui and pennant (`flag_pennant`, already made). |

**Total:** 30–37 of 37.

## Top 8 for tonight

1. Every place on the Map, plus the what-to-do lines.
2. GO opens the thing (teleport when far).
3. The queue card names the line and why.
4. Choose a race before joining (🔀 Pick).
5. A 5-item phone dock.
6. Cup bar and class path on the horse card.
7. Vet-check states, copy and check card.
8. First-time "New!" pointers.
