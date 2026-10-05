# Art direction: Gavel Derby

Status: council-reviewed (2026-10-04) and applied to the generated playtest assets. Review and verdicts: [ART_REVIEW.md](ART_REVIEW.md). Asset list and spend: [ASSET_PLAN.md](ASSET_PLAN.md). Studio import: [IMPORT.md](IMPORT.md). UI art lives in `assets/ui/` (review sheet `assets/ui/_sheet.svg`, PNGs in `assets/ui/png/`), made by `tools/ui/make_ui_svgs.py`.

## Style: "County Fair Toy"

A sunny countryside race day built from chunky toys: bright daylight, painted wood, bunting, soft hand-painted colour, natural horse coats on slightly chunky, friendly proportions. It has to read at thumb size on a phone first and look nice up close second.

Four pillars:

1. **Readable at 40 px.** A horse, a lane or a tap cue is identifiable as a flat silhouette at 40 px tall.
2. **Happy, healthy horses.** Every horse looks calm, fit and cared for, in every state, including a bad race.
3. **Race day, not a casino.** A fair and a sports day, not a betting hall.
4. **Original.** Shapes, faces and patterns are our own.

### Horses (council 1)

- **Proportions:** thoroughbred anatomy, simplified. Head and hooves about 10–15% larger than real, a sturdier neck and legs, a short tidy mane and a full tail.
- **Face:** small eyes set on the sides of the head. No eyelashes, no eyebrows, no big glossy eyes. Expression comes from the ears and tail: ears forward, mouth closed, no foam, no strain.
- **Coats:** natural colours and natural manes only, with no pastels and no flank symbols or marks. White face and leg markings are fine. The hero horse is a red bay with a short mane, never a buckskin mustang with a flowing black mane (Spirit).
- **The playtest set:** bay, chestnut, dapple grey (reads light grey), black, palomino.
- **No rare coats in the Phase 1 playtest** (council 3). When they come, they are natural (leopard spots, pinto, cremello), never fantasy.
- **Hooves:** dark and high-contrast on every coat, because the beat lands on the hoof. Charcoal `#26262C` against the dirt `#C68A52`. Enforced after generation by `tools/meshy/darken_hooves.py`.
- **Tack:** a bridle on the mesh, no saddle on the mesh. The saddle cloth is a separate Studio part carrying the lane pattern.
- **Scale:** about 5 studs tall and 8 studs nose to tail, next to a roughly 5-stud R15 avatar.

### Horse motion (council 2)

The mesh is static, a mid-gallop pose (Meshy rigs only humanoids). The client moves each horse along the track by CFrame every frame and adds:

- **Bob on the stride beat.** The body rises and falls once per beat. The lowest point, with a small squash (Y scale 0.96, X/Z 1.02 for about 60 ms), lands **exactly** on the beat time, with no easing past it. Out of the squash it rises smoothly. Pitch is ±3°, nose down at the landing. Amplitude is about 0.35 studs. The player's horse uses the same beat clock as the hoof ring.
- **On each beat:** one `fx_dust_puff` from the hoof Attachments, tinted dirt `#E3B985`, and one `fx_mane_flick` from the crest Attachment, tinted to the mane colour. Each particle lives about 0.2 s.
- **Surge** (on-beat taps): lean forward 3° and show speed-line Trails for 0.4 s.
- **Break stride** (mashing): a skip-hop out of phase for about 0.5 s and a small slowdown. The horse never stumbles, falls, limps or looks winded.
- **Later, not built now:** a leg cycle, splitting the legs into parts or a custom quadruped rig in Blender.

### World

A dirt oval with white rails, mown-stripe turf infield, a big sky, bunting, and painted wooden posts. Tiling pieces (rails, lane chalk, the finish banner and line) are Roblox parts with exact sizes. The finish posts and the starting gate stall are generated meshes.

## Palette

World:

| Token | Hex | Use |
| --- | --- | --- |
| Sky | `#8ED6FF` | Skybox tint, lobby backdrop |
| Turf | `#5DBB4A` | Infield, mown stripe A |
| Turf dark | `#4AA23C` | Mown stripe B |
| Dirt | `#C68A52` | Track surface |
| Dirt light | `#E3B985` | Dust puffs |
| Rail | `#FBFBF5` | Rails, posts |
| Hoof | `#26262C` | Every hoof |
| Barn red | `#C8463D` | Buildings only (never UI feedback) |

UI core:

| Token | Hex | Use |
| --- | --- | --- |
| Ink | `#1D2433` | Every outline, text stroke, dark text |
| Paper | `#FFF7E6` | Panels, number plates |
| Giddy-up orange | `#FF9F1C` / `#D97A00` rim / `#F28C00` pressed | The GIDDY-UP pad |
| Gold | `#FFD23F` / `#FFE98A` | Final Burst glow, Perfect, YOU marker, sparkles |
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
- **Value contrast:** the horse must differ from the track by at least 20 L* (CIELAB lightness, 0–100). Palomino is the closest to the dirt, so it relies on its cream mane and the lane badge. The player's horse also gets a white `Highlight` outline (fill transparent) and the YOU marker.
- **UI outline:** a 5–6 px ink outline on every UI shape at 128 px (paint-order stroke). In Roblox, use a 2–3 px `UIStroke` in Ink on all text. No outlines on 3D meshes.
- **Sizes on a phone:** the GIDDY-UP pad is about 60% of screen width (at most 520 px). Label text at least 28 px, lane numbers at least 20 px, board rows at least 18 px.
- **Fonts:** Fredoka One for labels and the pad, Builder Sans Bold/Black for numbers. In game, words and numbers are TextLabels over the `*_blank` art (crisp and translatable). The baked text in the other variants is a placeholder.
- **Shape plus colour, always:** no state is shown by colour alone. A Machado-2009 deuteranopia/protanopia simulation of the sheet confirms that colour alone fails for lane 1 vs 6, Good vs Okay vs Steady, chance up vs down, and the red ribbon; their shapes, patterns and numbers keep them distinct.
- **While tapping, only the ring is prominent** (council 6). Nothing glows near it, the pad holds steady, and labels pop above the hoof and leave quickly.
- **Sound is decoration** (D-022): every cue is on screen.

## Lanes and markers (council 5)

Each lane has a fixed colour from the Okabe–Ito colour-blind-safe set, a pattern and a big number. Adjacent lanes are never similar hues. A player's cosmetic silks never recolour the lane.

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

- **Lobby board rows:** `lane_N`.
- **Badge over each horse:** a `BillboardGui` 2.5 studs above the saddle with `LightInfluence = 0`, using `lane_N_blank` plus a TextLabel.
- **Saddle cloth part** on each horse.
- **Gate stall plate.**
- **Results and Top Fans rows.**

**YOU marker (huge):** `you_marker_blank` plus a 96 px "YOU" TextLabel, in a BillboardGui with a constant pixel size (`UDim2.fromOffset(180, 170)`, so it stays huge at any distance). It sits about 7 studs above the saddle, with `AlwaysOnTop` and `LightInfluence = 0`, bobbing ±4 px at 1 Hz. **Silks (later)** become a second, smaller marker on the rider.

Patterns are generic geometry. Never copy a real stable's registered silks or the real saddle-cloth numbering colours (1 red, 2 white, 3 blue, and so on), which call up race-day betting boards.

## UI motion

General:

- Draw every gameplay cue from the shared server clock, never from tween completion.
- `GuiService.ReducedMotionEnabled` removes sparkles, confetti, rays and the camera punch. It keeps the ring and the meter, which are the gameplay.
- No screen shake on a miss. **Nothing flashes more than 3 times a second** (WCAG 2.3.1). No full-screen flashes.

**Tap anywhere (council 6):** a tap anywhere on the screen, any key, or any gamepad button counts. The ring is the target.

**GIDDY-UP pad** (`giddyup_pad`, `_pressed`, `_blank`):

- Bottom centre, the affordance kids look for, but not an aim target.
- Before each stretch and between stretches, it pulses: scale 1.00 ↔ 1.06, 1.2 s period, Sine InOut.
- While rings are on screen, it holds steady at 85% opacity and shows the pressed frame for 80 ms on every tap, wherever the tap lands.
- Hidden during the Final Burst (the bar takes the bottom of the screen).

**Hoof ring (council 7):**

- Every ring takes the **same time to close** (client config). It spawns at 3.0× the hoof radius and shrinks **linearly** to the hoof rim. Touching the rim is the beat.
- Tempo shows as the **spacing between rings**: faster tempo means tighter rings. Several rings are on screen at once, at 100% / 70% / 45% opacity from the next ring outward.
- Build it from `UIStroke` (constant 6 px white with a thin ink edge, so the outer rings aren't fatter). `hoof_ring.png` is the fallback.
- It is an overlay unaffected by lighting: a ScreenGui, or a BillboardGui with `LightInfluence = 0` and `AlwaysOnTop = true`.
- **On a tap:**
  - The hoof stamps: scale 1.0 → 1.12 → 1.0 over 120 ms.
  - The label pops in above the hoof (scale 0.6 → 1.0, 100 ms, Back Out), holds for 350 ms and fades over 150 ms.
  - Perfect turns the landing ring gold for 80 ms. Great turns it sky blue for 80 ms.
- **No tap:** the ring shrinks past the rim to 0.8× and fades to plum over 150 ms. No sound sting, no X.
- **Mashing** (more than about 3 taps a second): the hoof wobbles ±6° for 300 ms with the "Steady!" wave label, and the horse breaks stride.
- **Haptics:** a short pulse at each beat contact on supported phones.

**Final Burst:**

- **Meter:**
  - The bar (`burst_bar`) is 80% of screen width and slides up (200 ms) before the server opens the window. The intro finishes first, so "first target pass at least 0.4 s after opening" (D-022) holds on screen too.
  - The marker (`burst_marker`) moves at constant speed with a short three-ghost trail.
  - The glow (`burst_glow`, gold with stripes) is placed by code as a 9-slice, and breathes from 85% to 100% opacity at 0.5 Hz.
- **Celebration (council 4): only after the burst is scored, and only on the rider's own screen.** Never during the live window.
  - **Perfect:** `burst_rays` behind the horse (fade in 120 ms, rotate 20°/s, fade out over 500 ms), a confetti pop, and a tiny camera punch (FOV 70 → 72 → 70 over 300 ms, off with ReducedMotion). The star label is shown at 2× size.
  - **Great:** a chevron burst.
  - **Good or Okay:** the label only.
  - **Miss:** the plum dash, no fanfare.
- **What everyone else sees:** only `lane_sparkle` on that lane's badge. Three sparkles pop one after another over 600 ms, once (no more than 3 flashes a second).

**Win chance change:** the number counts over 400 ms, with `chance_up` (teal) or `chance_down` (plum). No red.

## Do and don't

Do:

- Ride hands-and-heels: the avatar crouches and pumps along the neck in time with the stride.
- Show surges as the horse lengthening and leaning forward, with dust and speed lines.
- Keep horses calm, glossy and fit, with ears forward, mouths closed, small side eyes and dark hooves.
- Celebrate with ribbons, rosettes, bunting, confetti and gold stars, on the rider's own screen and after scoring.
- Show Green Cash as one small token icon, and the purse as a number ("Win: 464").
- Pair every colour cue with a shape, a pattern or a number.
- Use original shapes, our own patterns and plain tack.
- Keep words and numbers in TextLabels.

Don't:

- Show a whip, crop, riding stick or spurs anywhere, including icons, animations, cosmetics or tutorials.
- Show a horse that looks hurt, sick, scared or exhausted: no pinned ears, whites of the eye, flared nostrils, foam, sweat, visible ribs, bandages, limping, or a hanging head.
- Give horses eyelashes, eyebrows, big glossy eyes, pastel or fantasy coats, flank symbols, wings or horns.
- Make the hero horse a buckskin with a flowing black mane.
- Use wagering or casino imagery: odds or tote boards, tickets, bet slips, chips, dice, cards, slot reels, roulette, coin showers, cash piles, neon casino signs or "jackpot" bursts.
- Make look-alikes of Spirit, My Little Pony, Horse Life, Wild Horse Islands, real racecourses, racing brands, real silks or the real saddle-cloth colour scheme.
- Put anything glowing near the hoof ring, or let the GIDDY-UP pad compete with it during taps.
- Celebrate during the live burst window, or broadcast one rider's celebration to other screens.
- Rely on red-versus-green, colour-only states, or sound-only cues.
- Shake the screen or flash red on a miss, or put shaming text on screen.
- Generate a jockey: the player's Roblox avatar is the jockey.
