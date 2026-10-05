# Art direction: Gavel Derby

Status: draft for the design council (Phase 1, plan only; nothing generated yet). Asset list, Meshy queue and credit estimate are in [ASSET_PLAN.md](ASSET_PLAN.md). Draft UI art: `assets/ui/` (review sheet `assets/ui/_sheet.svg`), made by `tools/ui/make_ui_svgs.py`.

## Style: "County Fair Toy"

A sunny countryside race day built from chunky toys: bright daylight, painted wood, bunting, soft hand-painted colour, natural horse coats on slightly chunky, friendly proportions. It has to read at thumb size on a phone first and look nice up close second.

Four pillars:

1. **Readable at 40 px.** A horse, a lane or a tap cue is identifiable as a flat silhouette at 40 px tall.
2. **Happy, healthy horses.** Every horse looks calm, fit and cared for, in every state, including a bad race.
3. **Race day, not a casino.** A fair and a sports day, not a betting hall.
4. **Original.** Shapes, faces and patterns are our own.

### Horses

- **Proportions:** thoroughbred anatomy, simplified. Head and hooves about 10–15% larger than real, a sturdier neck and legs, a short tidy mane and a flowing tail. Natural eyes with one highlight, no lashes. Not a pony, not a mustang, not a toy unicorn.
- **Coats:** natural colours with white markings (blaze, star, socks), which keep faces and legs readable at a distance. The base set for the playtest is bay, chestnut, dapple grey, black (with grey highlights so it never reads as a blob or looks menacing) and palomino.
- **Expression:** ears forward or relaxed, a soft eye, mouth closed.
- **Scale:** about 5 studs at the withers and 8 studs nose to tail, next to a roughly 5-stud R15 avatar.
- **Motion:** see ASSET_PLAN.md ("How the horse moves without a rig"). A good stride surges forward; mashing makes a skip-hop and a short slowdown. The horse never stumbles, falls, limps or looks winded.

### World

A dirt oval with white rails, mown-stripe turf infield, a big sky, bunting, and painted wooden posts. Track pieces that tile (rails, lane chalk, the finish line) are Roblox parts, not generated meshes, so their sizes stay exact.

## Palette

World:

| Token | Hex | Use |
| --- | --- | --- |
| Sky | `#8ED6FF` | Skybox tint, lobby backdrop |
| Turf | `#5DBB4A` | Infield, mown stripe A |
| Turf dark | `#4AA23C` | Mown stripe B |
| Dirt | `#C68A52` | Track surface |
| Dirt dark | `#A86F3D` | Hoof prints, track edge |
| Rail | `#FBFBF5` | Rails, posts |
| Barn red | `#C8463D` | Buildings only (never UI feedback) |

UI core:

| Token | Hex | Use |
| --- | --- | --- |
| Ink | `#1D2433` | Every outline, text stroke, dark text |
| Paper | `#FFF7E6` | Panels, number plates |
| Giddy-up orange | `#FF9F1C` / `#D97A00` rim / `#F28C00` pressed | Tap button, primary buttons |
| Burst gold | `#FFD23F` / `#FFE98A` stripes | Final Burst glow, Perfect |
| Slate | `#2A3247` | Burst meter track |
| Teal | `#17A398` | Win chance up |
| Plum | `#7D6B91` | Win chance down (calm, not alarm red) |

Tap feedback (shape first, colour second):

| Label | Shape | Hex |
| --- | --- | --- |
| Perfect | Star | `#FFD23F` |
| Great | Double chevron | `#4CC3FF` |
| Good | Check | `#3CC46A` |
| Okay | Dot | `#CBB89D` |
| Miss | Flat dash | `#9A8FB0` |
| Steady! (mashing) | Wavy line | `#F2A65A` |

Ribbons (D-016): Blue `#2F6FDE` (1st, extra outer pleat), Red `#E0474C` (2nd), Yellow `#FFD23F` (3rd), White `#FFFFFF` (4th). Each shows its number on a paper button.

## Silhouette and readability rules

- **Silhouette test:** fill the asset solid black. If you can't name it at 40 px (3D, mid-race camera) or 32 px (UI icon), it fails.
- **Value contrast:** the horse must differ from the track by at least 20 L* (CIELAB lightness, 0–100). Palomino is the closest to the dirt, so it relies on its cream mane and the lane badge. The player's own horse always gets a white `Highlight` outline (fill transparent) and the `you_marker`.
- **UI outline:** a 5–6 px ink outline on every UI shape at 128 px (paint-order stroke). In Roblox, use a 2–3 px `UIStroke` in Ink on all text. No outlines on 3D meshes.
- **Sizes on a phone:** tap targets of at least 88 × 88 px (the Giddy-up button is larger; tapping anywhere also counts, per D-022). Label text at least 28 px, lane numbers at least 20 px, board rows at least 18 px.
- **Fonts:** Fredoka One for labels and buttons, Builder Sans Bold/Black for numbers. Words and numbers are always Roblox `TextLabel`s, never baked into images (crisp and translatable). The `<text>` in the draft SVGs is for review only.
- **Shape plus colour, always:** no state is shown by colour alone. A Machado-2009 deuteranopia/protanopia simulation of the draft sheet (2026-10-04) confirms that colour alone fails for lane 1 vs 6, Good vs Okay vs Steady, chance up vs down, and the red ribbon; their shapes, patterns and numbers keep them distinct.
- **Screen real estate:** keep the horse visible. The beat cue and the burst meter sit in the lower third, away from the Roblox top bar. One feedback label at a time.
- **Sound is decoration** (D-022): every cue is on screen.

## Telling the 8 lanes apart

Each lane has a colour from the Okabe–Ito colour-blind-safe set, a pattern and a big number. Adjacent lanes are never similar hues.

| Lane | Colour | Hex | Pattern | Pattern ink |
| --- | --- | --- | --- | --- |
| 1 | Vermillion | `#D55E00` | Solid | (none) |
| 2 | Sky blue | `#56B4E9` | Hoops (horizontal bands) | Ink 45% |
| 3 | Yellow | `#F0E442` | Dots | Ink 45% |
| 4 | Bluish green | `#009E73` | Chevrons | White 85% |
| 5 | Reddish purple | `#CC79A7` | Diagonal sash | White 85% |
| 6 | Orange | `#E69F00` | Checks | White 85% |
| 7 | Blue | `#0072B2` | Stars | White 85% |
| 8 | Charcoal | `#3A3F4B` | Diamonds | White 85% |

Where the lane identity appears:

- **Lobby board row:** a lane chip before the horse name.
- **Badge over each horse:** a `BillboardGui` chip about 2.5 studs above the saddle, always facing the camera.
- **Saddle cloth overlay (P1):** a thin part cut from the horse mesh, carrying the lane pattern.
- **Starting gate plate (P1).**
- **Results and Top Fans rows.**

Patterns are generic geometry. Never copy a real stable's registered silks or the real saddle-cloth numbering colours (1 red, 2 white, 3 blue, and so on), which call up race-day betting boards.

## UI motion

General:

- Draw every gameplay cue from the shared server clock, as the gavel meter does, never from tween completion.
- `GuiService.ReducedMotionEnabled` removes sparkles, confetti and camera punches. It keeps the ring and the meter, which are the gameplay.
- No screen shake on a miss. Nothing flashes more than 3 times a second (WCAG 2.3.1). No full-screen white flashes.

**Hoof ring (Giddy-up stride, D-022):**

- The ring (`hoof_ring.svg`, white with an ink outline, tintable) is centred on the hoof icon. It scales **linearly** from 2.4× to 1.0× over one beat of lead (two beats in Rookie). The moment it touches the hoof rim is the beat. Linear, because easing would hide where the beat is.
- About 2 beats a second means a ring lives for about 0.5 s. Keep at most two rings on screen: the current one, and the next one appearing.
- **Tempo change:** the ring for the changed beat is drawn dashed (`hoof_ring_dashed.svg`) for its whole approach, so the change is previewed a beat ahead.
- **On a tap:** the hoof stamps (scale 1.0 → 1.12 → 1.0 over 120 ms, Quad Out) and puffs dust. The label pops in above the hoof (scale 0.6 → 1.0 over 100 ms, Back Out), holds for 350 ms and fades over 150 ms. A newer label replaces the old one.
- **Perfect:** the ring turns gold for 80 ms and four sparkles pop. **Great:** the ring turns sky blue for 80 ms.
- **No tap:** the ring passes the hoof, shrinks to 0.8× and fades to plum over 150 ms. No sound sting, no buzz, no X.
- **Mashing** (more than about 3 taps a second): the hoof wobbles ±6° for 300 ms with the "Steady!" wave label. It tells the rider why the tap didn't count without calling it bad. The horse visibly breaks stride.
- **Haptics:** a short pulse at each beat contact on phones that support it.

**Final Burst (meter and glow):**

- The bar (`burst_bar.svg`) is 80% of screen width and about 64 px tall on a phone, sliding up from the bottom (200 ms, Quint Out) before the server opens the window. The intro has to finish before the open time, so D-022's "first target pass at least 0.4 s after opening" holds on screen as well as on the server.
- The marker (`burst_marker.svg`) moves at **constant speed** (linear) with a short trail of three ghost copies at 30%, 20% and 10%. The score is distance, so easing would mislead.
- The glow (`burst_glow.svg`) is gold with diagonal stripes, so it is still distinct without colour, plus a soft outer glow. It breathes from 85% to 100% opacity at 0.5 Hz, slow enough not to read as a beat. Code places it, because the target drifts in Gold and splits in two in Champion. Draw it as a 9-slice so its width can change.
- **On a tap:** the marker freezes for 250 ms. Recommended tiers, pending council question 4:
  - Perfect: gold rays behind the player's horse, a confetti burst, camera FOV 70 → 76 → 70 over 400 ms, and the star label at 2× size.
  - Great: a chevron burst.
  - Good or Okay: the label only.
  - Miss: the plum dash, no fanfare. The horse keeps galloping happily.

**Win chance change:** after each stretch the number counts up or down over 400 ms, with `chance_up` (teal) or `chance_down` (plum) beside it. No red.

## Do and don't

Do:

- Ride hands-and-heels: the avatar crouches and pumps along the neck in time with the stride.
- Show surges as the horse lengthening and leaning forward, with dust and speed lines.
- Keep horses calm, glossy and fit, with ears forward or relaxed.
- Celebrate with ribbons, rosettes, bunting, confetti and gold stars.
- Show Green Cash as one small token icon, and the purse as a number ("Win: 464").
- Pair every colour cue with a shape, a pattern or a number.
- Use original shapes, our own patterns and plain tack.
- Keep words and numbers in TextLabels.

Don't:

- Show a whip, crop, riding stick or spurs anywhere, including icons, animations, cosmetics or tutorials.
- Show a horse that looks hurt, sick, scared or exhausted: no pinned ears, whites of the eye, flared nostrils, foam, sweat, visible ribs, bandages, limping, or a hanging head.
- Use wagering or casino imagery: odds or tote boards, tickets, bet slips, chips, dice, cards, slot reels, roulette, coin showers, cash piles, neon casino signs or "jackpot" bursts.
- Make look-alikes of Spirit, My Little Pony, Horse Life, Wild Horse Islands, real racecourses, racing brands, real silks or the real saddle-cloth colour scheme.
- Use pastel rainbow manes, anime eyes, eyelashes, wings or horns on the base racehorses.
- Rely on red-versus-green, colour-only states, or sound-only cues.
- Shake the screen or flash red on a miss, or put shaming text on screen.
- Generate a jockey: the player's Roblox avatar is the jockey.
