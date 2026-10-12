# Tap preview consult: feel (D-071, 2026-10-11)

## Verdict

The motion reads as earned:
- `previewOwn` means only your own taps move your horse.
- Gains of 4 ft or more in 2 s are visible, and capped at 10 ft/s and 20 ft/s².
- The message is silent, kind and about gains only.
- The pressure cue lands on the beat, so it reads as effort, not a glitch.

Three things stop it reading as polished.

## MUST-FIX

1. **The pull-back can snap.**
   - `GameConfig.tapPreview.pullPerSecond = 19` lets your horse fall back at about 2.4 lengths a second. The worst case is a 6.9 ft pull-back, which takes about 0.36 s. That reads as rubber-banding, even though it is the truth arriving.
   - Add `pullBackFeetPerSecond = 6` for drawn retreat at a checkpoint close or the lock. Keep 19 only for hard-gap clearance (a horse cutting in).
   - Add a report row: the largest backward speed in pull-back events, which must be ≤ 6 ft/s.
2. **The message sits on the YOU marker.**
   - `TapCue.luau:84` puts it at 6.5 studs, and the rider's YOU marker is at 7 (`raceHud.youMarker.riderStuds`). Both are AlwaysOnTop, so they overlap over the rider's head.
   - While the message shows (1.6 s plus the fade), hide the YOU marker. The place badge pops anyway.
   - Alternatively, keep both and move the message below the saddle with `bb.ExtentsOffsetWorldSpace = (0, -2, 0)`.
3. **The billboard has no adornee.**
   - `TapCue.luau:110`: `bb.Parent = horse`, and `horse` is a Model.
   - A BillboardGui with no `Adornee` renders only when its parent is a BasePart or an Attachment, so this may never show. The rider's YOU marker uses the same pattern (`RaceController`, `bb.Parent = horse`).
   - Set `bb.Adornee = horse.PrimaryPart or horse:FindFirstChildWhichIsA("BasePart", true)` in both places. Add a PLAYTEST line: "the message is visible over your horse".

## SHOULD-FIX

- **Pressure should lean.** A bob × 1.3 (0.30 → 0.39 studs) is subtle. Add a 2° forward pitch while `tapPressure` is on, reusing the surge's pitch path. A lean is what reads as pushing.
- **Message size on phones.** At 230 × 44 px it's about a third of a 667 px screen. Scale it with `RaceState.hudScale()`, with a floor of 16 px text.
- **"Pulling away!" from the front.** A leader extending its lead gets "Pulling away!" right before luck can reorder the stretch. Accept it, but log it in REVIEW_QUEUE, because the playtest may show kids reading it as a promise.
- **The boxed share is 53%,** so half the races get the pressure cue rather than visible gains. The Smart Steer "find room" study (Ruling 2) is the real fix. Prioritise it after the playtest.

## Sign-off

**Yes, once must-fixes 1–3 land.** Each is a few lines and can be verified from the diff and the report row.
