# Votes: game feel (race realism, 2026-10-12)

Reviewer: feel and presentation lead. I judged both plans from the plan text, the brief and the existing code. Nothing has been run in Studio.

## racing-plan.md: AGREE-WITH-CHANGES

The direction is right: filing in, bot passes on the straights, buttons from race 1, keys always bound, and the move kept small. Six changes keep it from looking mechanical or feeling rigged.

**R1. Drift should wander, not breathe.**
- A single ±6 ft sine on every horse makes the whole pack pulse like jelly.
- Use two incommensurate sines per horse: `drift = 3.5·sin(2πt/P1 + φ1) + 2·sin(2πt/P2 + φ2)`, with P1 = 11–17 s and P2 = 5–7 s. Peak is about ±5.5 ft.
- Cap the drift-only speed difference between two neighbours at 3 ft/s, so position swaps come from passes, never from drift alone.
- Gate: in the overlap report, drift contributes ≤ 3 ft/s of relative speed.

**R2. A pass must show a "head-to-head" beat.**
- When a passer's nose reaches the passed horse's hip, keep the closing speed at ≤ 6 ft/s until it is a half-length clear. Both horses are then visible alongside for at least 0.8 s.
- The passer turns ≤ 6° outward on the swing-out and ≤ 4° on the return (SteerPose). The return starts only 10 ft clear (`returnClearFeet`), with no cut-across.
- Report row: median time alongside 0.8–1.5 s, and 0 passes that complete in under 0.5 s.

**R3. A shut door must be visible.**
- A bot that shuts the door turns its body 3° toward the rider and holds it for `shutSeconds`. Its jockey's pump goes up ×1.5. This is drawn only, using the steering pose path, and never changes lane position.
- `bump_soft` plays at 0.4 volume and speed 0.9 at the shutting horse.
- The kid then sees *who* shut the door. An invisible denial reads as a broken button.

**R4. A lit arrow is a promise.**
- 20–35% denial on a lit arrow will feel like cheating to an 8-year-old.
- Light the arrow only when the slot is clear **and** no bot that can shut the door is alongside within `brushAlongFeet`.
- Gates:
  - denied while lit: **≤ 10%**;
  - denied when pressing unlit: 30–50% (that is where "Door shut! Try again" lives);
  - the overall 20–35% target is only met through unlit presses.

**R5. The move surge: anticipation, impact, follow-through.** The numbers live in `steering.move.fx`.

| Phase | Timing | Look |
| --- | --- | --- |
| Anticipation | 0–0.15 s after the press | The jockey's crouch deepens (waist +10°, pump ×2) and the horse's nose dips 2°. The lane glide starts on the next server tick. |
| Impact | 0.15 s | A dust burst of 8 from the hind hooves, the 0.4 s flank trails, and a FOV kick of +1.5° (rise 0.06 s, fall 0.5 s) inside the 6° budget. |
| Follow-through | 1.2 s | `surgeFeet` ramps in with smoothstep (never linear) at ≤ 7.5 ft/s. The horse leans 3° into the lane. |

Sounds come from the current sheet, so no upload is needed:
- `move_ready` = `lock_tick` at speed 1.2, 0.3 volume;
- `move_go` = the first 0.6 s of `burst_whoosh` (PlaybackRegion) at speed 1.25;
- `move_shut` = `bump_soft` at speed 0.9.

Under Reduced Motion: no FOV kick, no trails, and the lean is kept.

**R6. 10 Hz smoothness.**
- Style, drift, stagger, passes and the surge all go through Trip and then Playback. Nothing is set client-side.
- The existing jerk and overlap gates must hold, with every new row included.
- No lateral move in the last 2 s before the line, as today.

## steeplechase-plan.md: AGREE-WITH-CHANGES

Fix the jump now. Hurdles in Practice first, fences on straights only, the ring in the world, never a fall: all agreed. The changes:

**S1. Free-ride jump pose: pitch from vertical speed.**
- Instead of fixed +6°/−4°, use `pitch = 10° · (vy / vy0)`, clamped to ±10°. That gives a natural bascule: nose up on takeoff, level at the apex, nose down on landing.
- The jockey takes a jump position: waist +15° on top of the crouch, arms forward (+20° shoulder) through the air.
- Landing: Y squash 0.96 for 80 ms, plus a dust puff and `bump_soft` at speed 0.8.

**S2. A race jump is keyed to distance, never to a timer.**
- Each horse's arc is `y = 4h·u(1−u)`, with `u = (s − s_takeoff) / span`, `s_takeoff = s_fence − 10 ft` and `span = 22 ft`. That is about 0.39 s of air at 56 studs/s.
- Because the arc is a pure function of drawn `s`, 10 Hz playback interpolates it smoothly, and the field ripples over the fence one horse at a time.
- **Every arc clears the brush.** With a fence height of 3.5:

| Jump | Arc height | Extra |
| --- | --- | --- |
| Clean | 5.0 | — |
| Okay ("Bumpy jump!") | 4.3 | The brush top rotates 15° and springs back over 0.4 s, with green leaf particles (6) and `brush` (the grooming clip) at speed 1.3. |
| Missed ("Hop!") | 4.0 | The same flick, larger. |

  - The plan's "small hop" would pass the horse *through* the fence: never draw that.
- The clumsy-jump slow-down (≤ 3 ft) eases with smoothstep over 0.6 s.

**S3. The ring must match what you see.**
- Today your horse can be drawn up to about 17 ft ahead of the server (the tap preview plus the nudge) and drawn about 0.1 s behind (the playback delay). So the ring would close while your horse is visibly past, or short of, the fence.
- From 2 s before your first fence zone to its end, ease your own horse's draw-only offsets (`tapPreview` residual and the nudge) to 0 at ≤ 6 ft/s.
- Inside fence zones, draw your own horse at server time instead of playback time. Lanes are held there, so this is safe; run the overlap gate on it.
- Gate: at the ring's close, your horse's drawn front hoof is within 1.5 ft of the takeoff point in 99% of frames.

**S4. The camera must not swallow the jump.**
- A Follow camera rises with the horse, so the world drops instead of the horse jumping.
- During the arc, set `Humanoid.CameraOffset = Vector3.new(0, −0.7·y, 0)` on the rider, so 70% of the rise is cancelled and the horse visibly lifts.
- Keep the plan's +1.5 studs and +2° FOV on the approach.
- Under Reduced Motion: no offset change, a full lift.

**S5. Sounds: the plan's "no new upload" is wrong.**
- `fence_takeoff`, `brush_swish`, `fence_land` and a crowd "ooh" are **not** on the sheet. Map them to existing clips:

| Plan's sound | Existing clip |
| --- | --- |
| takeoff | the first 0.5 s of `burst_whoosh` at speed 1.4 |
| brush_swish | `brush` at speed 1.3 |
| land | `bump_soft` at speed 0.8 |
| crowd "ooh" | the first 1.0 s of `crowd_cheer`, 0.35 volume, clean jumps only |

  - Real clips can join the next sheet rebuild.

**S6. Meshy.** Code-built brush is enough. Hold the credits.

## The coupling: fence lane holds vs passing and the move

**Ruling: compatible, with a lead-in rule.**
- A zone runs 60 ft before the fence to 30 ft after it: 90 ft, about 1.6 s.
- Mile fences at 25/50/75% of a backstretch of about 1,100 ft leave about 3.3 s between zones. That's enough for one pass.

Required:
1. **No pass and no move may *start*** unless its glide and return can finish before the next zone: `pass.zoneLeadSeconds = 1.8`. Inside that lead, Smart Steer and bots wait. A rider's press waits, with the D-057 ring.
2. **Inside a zone and its lead,** arrows grey without lighting. The pip is kept, and "Door shut!" is **never** shown: the fence, not a horse, is what's holding you. The chip instead says "Jump first!" (2 words), at most once a race.
3. **A surge already running may continue into the zone.** It's forward only, with no lateral move.
4. **Fences inside the first `fileAfterBreak` 12 s** of a race: none on the Mile, because the backstretch comes later. Assert it in a test.
5. **Gate in `sims/steeple.py`:** drawn passes per race on Hurdles are ≥ 2, and 0 lane changes happen inside zones.
