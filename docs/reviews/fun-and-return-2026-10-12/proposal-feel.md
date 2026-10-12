# Proposal: feel, presentation and world (fun and return, 2026-10-12)

Author: the feel and presentation lead.
- **Lens:** what makes the world feel alive, warm and professional, and how David's five directions look and sound.
- **What every item here follows:**
  - Reduced Motion: it has a still version.
  - Skippable: after 1 s, unless noted.
  - Config: it lives under `GameConfig.present.*`.
  - Kid safety: no wound, blood, limp, pain sound or needle anywhere (Roblox maturity: Minimal/Mild, research §3).
  - Effort: S under half a day, M about a day, L more.

**★ = my top 8 for this evening.**

## 1. A world that feels alive

**★ A1. Arrival fly-in (S).** `client/ArrivalCam.luau`
- On the first spawn of a session, a 3.0 s Scriptable camera glides from 60 studs above Fair Street, along Barn Lane, to your barn. It uses smoothstep and FOV 70 → 60.
- `vo_welcome` plays at 0.4 s. Your barn's name sign gets one sparkle burst (12) as the camera lands.
- After 3+ days away, the Welcome Back bale (D-063) is in frame for the last 0.8 s.
- Any tap skips. Under Reduced Motion it's a 0.4 s fade.
- Key: `present.arrival = { enabled, seconds = 3.0 }`.

**★ A2. Your horse says hello (S).** `client/AmbientLife.client.luau`
- **The stall horse turns toward you.**
  - Within 14 studs of its stall, your horse's model yaws up to 20° toward you over 0.5 s, then holds.
  - `horse_nicker` plays positionally at volume 0.5, at most once every 60 s per horse.
  - A napping horse doesn't turn. Its 💤 bubble bobs instead.
- **Ambient barn life:**
  - A random stall horse nickers every 25–45 s at volume 0.25 (`RollOffMaxDistance` 40).
  - Each stall horse swishes its tail: model roll ±1.5° on a 3–5 s sine.
  - Dust motes drift in each barn doorway: a ParticleEmitter, rate 3, life 4–6 s, warm white, LightEmission 0.3.
- **Ambient fair life:**
  - Butterflies near gardens and planters: 2 per bed, built-in sparkle texture tinted `FFD23F` / `8ED6FF`, a slow figure-8 path.
  - Each grandstand within 250 studs claps (`clap` at 0.15) every 8–15 s.
- Key: `present.ambient = { enabled, greetStuds = 14, greetYawDeg = 20, nickerEvery = { 25, 45 } }`.

**★ A3. Class-up and promotion ceremony at the Rosette Wall (S).** `client/Ceremony.luau`
- When you next arrive home after a promotion or class-up, the camera frames the Rosette Wall (2.5 s, the replay side rig).
- The new rosette scales in 0 → 1.15 → 1 (Back easing, 0.35 s). Confetti (`confetti_square`, 40) falls.
- Sounds: `tap_good`, then `clap` ×3 at 0.15 s intervals.
- Copy (≤ 6 words): "Comet is a Stakes horse!"

## 2. David's directions, presented

### ★ B1. The vet visit after over-running: "Cool-down Check" (M)

Files: `shared/VetPlay.luau` (pure steps), `client/VetPlay.client.luau`, the existing Vet clinic.

**Before it:**
- One race ahead, the horse card shows "Comet's legs are working hard."
- After that race: "Comet ran his heart out! Vet check time." The words hurt, injury, sick, limp and pain stay banned (copy test).
- The horse looks cheerful throughout: ears forward, tail swishing (A2). It never limps or hangs its head.

**Four tap-only steps, about 30 s.** The camera is fixed side-on at the wash bay (Spa rig). Every step shows a progress pip, 1–4.

| Step | What the kid does | Look | Sound |
| --- | --- | --- | --- |
| 1. Check | Tap each of the 4 legs. Each tap shows a soft gold ring on that leg (0.3 s), then a tick. "Warm legs! Let's cool them." | gold rings | `heartbeat` once at the start, `tap_ok` (speed 1.0 → 1.3) per leg |
| 2. Cool hose | Hold on each leg. A water Beam (white-blue, Wrap texture, width 0.4) plus droplets (rate 40, life 0.4 s) fill that leg's meter in 1.2 s. The leg part tints 8% cooler blue, then eases back. | water, droplets | `brush` looped by PlaybackRegion at speed 0.7, volume 0.4 |
| 3. Wraps | Pick 1 of 4 wrap colours (fair palette), then tap each leg. A cylinder (Fabric, 1.1 × leg width) scales up from 0 to the leg's height over 0.3 s. | wraps on the split legs | `bump_soft` at speed 1.2 per wrap |
| 4. Carrot | Drag the carrot to the muzzle. 6 hearts float up and Comet nods (pitch 4°, 0.3 s, ×2). "Comet feels great!" | hearts | `munch`, then `horse_nicker`, then `job_done` |

- **The wraps stay as a badge of care.** They stay on the horse (stall, riding, races) for the next 3 races, so the care is visible and the cause is clear.
- **Health Passport:** a "Cool-down" stamp.
- **No cost:** Free. There is no Diamond or Green Cash path, and no timer.
- **Reduced Motion:** no droplets, and the wraps appear without the scale-in.
- Key: `present.vet = { holdSeconds = 1.2, wrapRaces = 3, steps = 4 }`.

### ★ B2. How ageing looks (S/M)

| Stage (by races) | Look |
| --- | --- |
| Youngster | Model scale 0.92, a 🌱 green saddle cloth trim, and a bouncier bob (`bobStuds × 1.2`). |
| Prime | As today. |
| Veteran | **A frosted muzzle and brows** (below), a silver-and-blue **Veteran rosette** on the bridle by the left ear (code: 8 Fabric petals plus a 0.5-stud button, `C0C7D4` / `2F6FDE`), and a 0.1 stud slower bob. |
| Legend | The existing gold sheen and sparkle, plus the rosette in gold. |

**The frosted muzzle costs 0 Meshy credits.**
- Every coat shares one UV layout: `darken_hooves.py` already relies on this.
- Add `tools/meshy/frost_muzzle.py`. Paint one muzzle and eye-brow mask once, blending a 35% `D9D6CF` frost over each coat's base colour.
- Write `*_veteran` textures, upload them as images (not audio), and swap the MeshPart `TextureID` at Veteran.
- The gate is a review sheet checking that the horse looks wise, not ill: no dull coat and no sunken eyes.

### B3. Retirement ceremony (M)

Files: `client/Ceremony.luau`, `server` Legend paddock.

- **Length:** 8 s. Skippable after 1 s.
- **Camera:** side-on at the Legend arch.
- **Sequence:**
  1. The horse walks under the arch.
  2. The plaque post rises from the ground (0.8 s, smoothstep).
  3. The name letters appear one every 0.06 s.
  4. A **wildflower garland** settles over the withers: 14 ball parts in fair colours on a rope Beam, tweened down 2 studs over 0.5 s.
- **Sounds:** `finish_fanfare` at speed 0.85 (warmer), `clap` ×5 scattered over 2 s, then `crowd_cheer` at 0.3.
- **Copy:** "Thank you, Comet! A Legend forever."
- Undo stays as D-068 allows.

### ★ B4. Prestige race day: the winner's circle (M)

Files: `server/WinnersCircle.luau`, client `FinishMoment` hand-off.

**Graded race dressing:**
- the bunting tinted gold and blue;
- a "Stakes Day" banner Beam over the finish;
- the gate line-up (D-069) holds 0.4 s on each Graded runner's name.

**After a Graded win, a 7 s sequence** replaces the orbit:
- **Wide (2 s):** a white-rail octagon (r 10 studs) on the apron by the finish, ringed with flower boxes (planters exist). Your horse walks in.
- **The blanket (2 s):**
  - A blanket of **wildflowers** drops onto the withers: 3 rows × 12 balls in a Fabric-backed strip, tweened from 4 studs up over 0.6 s with Bounce. It isn't a copy of any real race's roses.
  - A presenter, an R15 NPC from HumanoidDescription in fair colours, holds out the trophy.
- **Close (3 s):** the camera pushes in. The rider raises the trophy (arms at shoulder +120°, 0.4 s). `confetti_square` (60) falls, and a 📷 Photo prompt shows.

**Sounds:** `gate_bell` at speed 1.2, then `finish_fanfare`, then `crowd_cheer`, then `clap` ×4.

**Everyone nearby sees it.** The circle is server-built for 20 s, so it's a social moment that spectators come back for.

**The rest of the field:** 2nd to 4th get the usual ribbon stamps, and the card adds "Stakes Day runner! 🎀" for every finisher.

- Key: `present.winnersCircle = { enabled, seconds = 7, liveSeconds = 20 }`.

### ★ B5. Visiting other stables (M)

Extends `VisitClient`.

**Arrival:**
- At the gate, `gate_bell` plays (speed 1.3, volume 0.4, positional at the visitor bell model).
- A BillboardGui banner pops in (0.25 s Back), "Welcome to Maya's Stable!", and auto-fades after 2.5 s.
- For a non-friend, the banner shows the barn name only, never a profile.

**The walkaround: 4 glowing hoofprint stops**, using the existing Guide:
1. the horses' stalls (Pat);
2. the Rosette Wall;
3. the garden;
4. the best Barn Builder piece.

At each stop a "Look!" prompt frames it for 2 s (the side rig) with `tap_ok`. Seeing all 4 stamps a Tour pin, with `job_done`.

**The owner** later sees "A visitor waved! 👋": no names for non-friends, and no counts made public.

**No griefing surfaces:** nothing can be placed, moved or written.

## 3. Meshy (cap 15 = 25% of 60)

| Rank | Asset | Kind | Credits | Use |
| --- | --- | --- | --- | --- |
| 1 | `trophy_graded`: retexture of `trophy_cup`. Intent: "polished toy silver bowl, wide blue enamel band, gold handles and base, soft hand-painted shine, County Fair style, no text". | retexture | **10** | Winner's circle, Hall of Fame plaque post, Horse Book Graded page, Rosette Wall. Seen in 4 places. A tint can't make silver, blue and gold on one mesh. |
| — | Hold | — | 5 | Reserve for a failed retexture's reroll check. |

- **Skip text-to-3D (30):** it is over the cap.
- **Built in code instead:**
  - wraps (cylinders on the split legs);
  - the hose (a Beam);
  - the winner's circle rail;
  - the flower blanket and garland;
  - the frosted muzzle (texture script, 0 credits).

## 4. Sound map (existing SoundSheet only)

| Moment | Clip, speed, volume |
| --- | --- |
| Arrival | `vo_welcome` at 0.7 |
| Horse greets you | `horse_nicker`, 1.0, 0.5 |
| Barn ambience | `horse_nicker`, 0.9–1.1, 0.25 |
| Vet check | `heartbeat`, then `tap_ok` 1.0 → 1.3 |
| Hose | `brush` looped region, 0.7, 0.4 |
| Wrap | `bump_soft`, 1.2 |
| Carrot | `munch`, `horse_nicker`, `job_done` |
| Rosette or class-up | `tap_good`, `clap` ×3 |
| Retirement | `finish_fanfare` at 0.85, `clap` ×5, `crowd_cheer` at 0.3 |
| Winner's circle | `gate_bell` at 1.2, `finish_fanfare`, `crowd_cheer`, `clap` ×4 |
| Visitor bell | `gate_bell`, 1.3, 0.4 |
| Walkaround stop / pin | `tap_ok` / `job_done` |

No new audio upload is needed.

## ★ Top 8 for this evening (in order)

1. **B1** Cool-down Check vet mini-game (M)
2. **B2** Veteran look: frosted muzzle script plus the Veteran rosette (S/M)
3. **A1** Arrival fly-in (S)
4. **A2** Your horse says hello, plus ambient life (S)
5. **B5** Visiting arrival banner plus the 4-stop walkaround (M)
6. **B4** Winner's circle with the flower blanket and the trophy (M; trophy retexture 10 credits)
7. **A3** Rosette Wall class-up ceremony (S)
8. **B3** Retirement ceremony (M), if time allows. It reuses A3's camera and garland.

**PLAYTEST lines:**
- The vet check reads as care, not injury: a kid describes it as "cooling his legs".
- The Veteran looks wise, not sick.
- The winner's circle can be seen from the grandstand.
- Every sequence skips after 1 s and has a Reduced Motion version.
