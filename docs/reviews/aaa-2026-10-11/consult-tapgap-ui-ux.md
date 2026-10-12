# Tap preview consult: UI/UX (D-071, 2026-10-11)

## What passes

- **Who sees what is right.** The message reaches the rider only; spectators get none. With the ◀ ▶ buttons you get the gap chip; with Smart Steer you get "Your taps still count!" once per race.
- **One message at a time:** it waits behind steering chips (`chipMinGap`) and coaching, and is dropped in the Burst and after the lock (`TapMessage.luau:33-37`).
- **Readable size:** the billboard is 230 × 44 px, Ink on Paper, `TextScaled`, so about 20 px text at every distance, above the 14 px floor.
- **No overlap with YOU:** the YOU marker is hidden in your own chase view (`riderShown = false`).

## MUST-FIX

1. **"Find a gap! ◀ ▶" shows both arrows** (`TapMessage.luau:13`, `TapCue.client:163-170`).
   - The chip fires when one side has room, but it shows both arrows. A kid presses the blocked one, gets "No room yet", and may trigger a brush (D-057).
   - "Gap" is also abstract for an 8-year-old.
   - Fix: pass the free side and show only its arrow:
     - `gapIn = "Room this way! ◀"`
     - `gapOut = "Room this way! ▶"`
     - When both sides are free, use the In side; it saves ground.
   - Briefly ring the matching button using the existing wait-ring style in `SteerHud`.

## SHOULD-FIX

- **First person.** A billboard 6.5 studs above the saddle sits above or behind the camera, so the message never shows. When zoom is under `firstPersonZoom`, put the words on the hint line instead.
- **Two texts at once.** The tap word (y 0.62) and the message over the horse can show together. While the message is up, show only the tap words for Perfect and Early/Late.
- **"Your taps still count!"** suggests they didn't count. Use "Keep tapping! Room soon." instead (under 10 words, kind).
- **Add a `UITextSizeConstraint`** (Min 14, Max 24) so `TextScaled` can't drop below the floor on a short word or an unusual DPI.

## Sign-off

**Yes, after MUST-FIX 1** (copy plus one argument; S). No re-review needed.
