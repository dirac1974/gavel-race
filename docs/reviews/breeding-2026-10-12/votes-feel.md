# Votes: breeding (D-080), feel and presentation

## Section votes

| § | Vote | Note |
| --- | --- | --- |
| 1 Who can breed | AGREE | |
| 2 Math | AGREE | Outside my lens. |
| 3 Coats | CHANGE | How the coat is revealed: see F5. |
| 4 Flow | CHANGE | F1, F3, F4 and F6. |
| 5 Economy | AGREE | |
| 6 Safety and policy | CHANGE | Copy: see F6. |
| 7 Sims | AGREE | |
| 8 Visuals | CHANGE | F2 and F3. 0 Meshy is confirmed. |
| 9 Phasing | AGREE | F1–F6 fit in phase 2. |

## Changes

**F1. The arrival moment** (`BreedingClient`, about 4 s, skippable after 1 s). When the kid enters the barn with a foal ready:
1. **Camera:** a side shot of the straw stall (the replay side rig), framing the parent.
2. **The foal steps out:** it walks out from behind the parent's flank, 4 studs over 1.2 s, in walk gait with a bob of `bobStuds × 1.4`.
3. **Greeting:** the foal turns to the parent (12° yaw) and nuzzles twice (pitch 5°, 0.25 s each).
4. **Hearts:** 8 hearts rise.
5. **Copy:** "A foal is here! 🍼".
6. **Sounds:**
   - the foal's whinny: `horse_nicker` at speed **1.45** (a higher pitch reads as young), volume 0.5;
   - the parent's answer: `horse_nicker` at speed 0.9, 0.4 s later;
   - `job_done`.
7. **No confetti, and no "stands up from lying".** It just appears beside its parent, so nothing implies a birth.
8. **Reduced Motion:** a fade-in beside the parent, the hearts kept.

**F2. Foal proportions, not a shrunken adult** (`HorseLook`).
- **The look:** the rig has split legs, so scale the parts unevenly.
  - The body part, which includes the head, goes ×0.70 uniform.
  - Each leg goes ×0.70 in X and Z, and **×0.92 in Y**. Re-seat the hips so the hooves touch the ground.
  - That gives long legs, a short body and a relatively big head. The mane and tail ride the body.
- **Growth:** the factors lerp to 1.0 by 30 races, with smoothstep on the race count.
- **In races, never a foal look.** Any horse on a race course is uniform scale ≥ 0.94 (`breeding.raceMinScale`) with the 🌱 cloth trim. A 5-stud avatar on a 0.80 horse looks silly, and foals don't race.
- **Consistency:** use the rig for every bred foal, including the 3 `foal_stand` coats, so all foals look alike. Reuse the `foal_stand_*` models as 2 NPC foals grazing in the barn's paddock (decor).

**F3. The barn must not look like a player's barn.** `stable_barn` at 0.6 reads as "someone's plot".
- **Colours:** paint it with `tint()`: walls cream `FFF4C7`, trim sky `8ED6FF`, roof `C8463D`.
- **Paddock:** a small white-rail paddock (r 12 studs) with the 2 NPC foals, 2 flower planters and a pennant line (`pennantLine`).
- **Sign:** "🍼 Foal Barn" on the SurfaceGui sign.
- **Build:** everything from `BarnDecor` helpers. 0 Meshy.

**F4. Naming ceremony.**
- **Plate:** after the chips confirm, a stall name plate drops in with `BuildFx.dropIn` (0 → 1.15 → 1), and the letters appear one every 0.05 s.
- **Foal:** nods twice.
- **Sounds:** `tap_good`, then `clap` ×2 (0.15 s apart).
- **Book:** the Horse Book Family entry gets a "New!" ring.
- **Copy:** "Hello, Pebble! 🌱".

**F5. The coat reveal must not feel like a slot.**
- The coat is simply what the foal *is* when it appears. There's no spin, no cover-reveal and no delay.
- A surprise coat gets the same celebration size as a parent coat, plus one line: "✨ A surprise coat: Dun!". It adds 6 sparkles and no extra sound.

**F6. Wording.**
- **The barn's name:** "Foaling" is the birth word, so call it the **"Foal Barn"**. Apply this to the Map tile, the sign and `GoTo("foalbarn")`.
- **Arrival:** when the foal is ready, the Advice GO teleports with the 0.3 s Paper fade (`FFF7E6`), never within 120 s of a race.

**F7. Foal behaviours** (`client/FoalLife.client.luau`, out of races only, for the first 10 races of the foal's life).
- **Tag-along:** when the parent is your active riding horse or loose in the yard, the foal follows 6 studs behind it and 2 studs to the side.
  - Its speed is capped at the parent's speed + 4 studs/s, using HorseLegs gaits.
  - It never follows into a race or a training ride.
- **Frolic:** in the yard or paddock it does a little hop (0.6 studs, 0.3 s) every 8–14 s, with a `horse_nicker` at speed 1.45 and volume 0.25. At most 1 in 3 hops gets the nicker.
- **Stall:** when idle, the foal yaws toward its parent's stall (≤ 25°).
- **Reduced Motion:** no frolic hop, and the following is kept.

## Sound map (existing SoundSheet only)

| Moment | Clips |
| --- | --- |
| Arrival | `horse_nicker` at 1.45, then 0.9, then `job_done` |
| Naming | `tap_good`, then `clap` ×2 |
| Frolic | `horse_nicker` at 1.45, volume 0.25 |
| Waiting chip tap | `ui_pop` |
| Fee confirm | `coin` at 0.8 (soft, no jackpot) |

## Meshy

**0 of 15.** Everything above is code, uneven scaling of the existing rig, existing models, and `BarnDecor`.
