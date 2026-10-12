# UI/UX votes: race realism (2026-10-12)

Lens: a phone at 667 × 375, ages 8–13, one thumb on the ◀ ▶ pad (bottom-left, 88 px) and taps anywhere else.

## racing-plan.md: AGREE-WITH-CHANGES

The keys always bound, the field filing to the rail and passing, and doors shutting all answer David directly. The required changes:

### 1. Stage the onboarding
Race 1 already teaches the slider, so adding buttons, pips and chips is too much at once.

| Race | What shows |
| --- | --- |
| 1 | Buttons visible and working (Smart Steer on). No pips, no move chips. Only "Lanes locked!". |
| 2 | Ghost-thumb steering tip. |
| 3 and later | Pips plus "Good taps fill your move!" once. |

New keys: `move.introRaces = 2`, `steering.tipRace = 2`.

### 2. Pips must not be horseshoes
The horseshoe means Energy (D-064), and the plan bans that word.
- Use three 24 × 24 gold chevron pips, atlas `move_pip`, with a 2 px Ink outline. An empty pip is a slate outline.
- They sit in one row centred over the pad, 6 px above it.
- The steering chip moves up by 30 px to clear them.
- 20 px is too small to read at a glance.

### 3. Don't relabel a button mid-race
"Go! ▶" swaps out a label the thumb has already learned. Keep "◀ In" / "Out ▶". The lit state is:
- a 4 px gold rim;
- a 2 Hz pulse (static under Reduced Motion);
- a gold chevron badge in the button's top corner.

### 4. No accidental moves
- Add a 16 px dead halo round the pad: touches there do neither a tap nor a steer.
- A pip is spent only on a press while that arrow is lit. An unlit press is a plain lane change.

### 5. One message at a time
Priority: coaching > "Lanes locked!" > move chips > steering chips > tap-preview words. Each waits at most 2.5 s, then drops.

### 6. Copy (6 words or fewer, one phrase per meaning)

| When | Copy |
| --- | --- |
| Pip filled | "Move ready!" |
| Lit | "Make your move! ▶" (only the lit side's arrow) |
| Success | "Nice move!" (not "Moved up!", which clashes with "Giddy-up! Moving up!") |
| Denied | "No room yet!" (D-057's phrase, not "Door shut!", an idiom kids miss) |
| Result | "Your move gained Comet 1 place!" |

## steeplechase-plan.md: AGREE-WITH-CHANGES

The forward jump: agree as written. Hurdles as Practice first: agree. Required changes:

### 1. The takeoff ring must be readable
- Draw it as a screen-space BillboardGui on the front hooves, AlwaysOnTop.
- It closes from 160 px to 64 px wide; gold, 6 px thick, with an Ink outline.
- The text is 1st Hurdles race only: "Tap when the ring closes!".
- A ring drawn on the ground in world space would be about 20 px on a phone.

### 2. Fence-zone buttons need their own look
Grey plus 🐎 already means "a horse beside you".
- In a fence zone the arrows fade to 50 % with a small fence glyph (atlas `hurdle_mini`). No ring.
- The card icon is an atlas `hurdle` drawing, not 🐎.

### 3. Jump words
"Clean jump!" / "Bumpy jump!" / "Hop!" all pass. Show them in the tap-word slot, not over the horse.

## Coupling ruling (fence zones vs passing and the move)

1. **The zone starts when the ring starts:** `fence.leadSeconds` × speed, about 90 ft before the fence, not 60. Lanes, the ring and the paused slider then begin together, so attention never splits. The zone ends 30 ft after.
2. **Arrows stay unlit** from 1 s before a zone until it ends.
3. **Move presses inside a zone are dropped** with "After the jump!", and no pip is spent.
4. **Plain lane presses wait,** as planned.
5. **Bots never start a pass** within 150 ft of a zone, so no glide is in progress at the zone edge.
6. **`move.onHurdles = false`** until moves and Hurdles each pass their playtests on their own.
