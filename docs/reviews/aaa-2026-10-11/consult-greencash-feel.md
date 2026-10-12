# Green Cash consult: feel and presentation (2026-10-11)

I read the code for `BuildFx.luau`, `BarnDecor.luau` and `BarnBuilder.client.luau`, and looked at `horse_silhouette.png`. Nothing has been run in Studio.

## Did my required changes land?

- **Build moment: yes.**
  - After buying, "Go see it!" shows hoofprints home.
  - The new piece is hidden on your screen until you arrive.
  - It then drops in 0 → 1.15 → 1 with dust and a sparkle, plays `job_done`, and shows the toast "<name> built!".
  - A repaint shows the old colour until you arrive, then sweeps across. Reduced Motion fades instead.
- **Visitors notice: yes.** Friends' barns shows ✨ beside a fresh build, and a friend's arrival sparkles once.
- **No paying for what you already own: yes.** The catalog sells variants (a painted trough with a stripe, a flower-box wheelbarrow, a coloured horseshoe), each never added twice.
- **Hay loft is no longer `training_shed`: yes.** It's a dormer on the barn with a hay door, a pulley, a hanging bale and a "Hay Loft" sign. This is the best piece in the catalog.
- **Gold is not chrome: yes.** It's mustard `E3B341` on SmoothPlastic or Wood. The vane is matte painted iron. Nothing glints.
- **Weathervane built in code: yes.**
  - A cupola, an N/E/S/W cross with Fredoka letters, an arrow and the silhouette, with a parts fallback.
  - The silhouette is a calm walking horse, chunky and original, with a thin paper rim. It reads at roof distance.
  - Meshy spend: 0.

## MUST-FIX

1. **The build reveal can happen off screen.** `BarnBuilder.client.luau:289` fires the moment within 26 studs, whichever way the camera faces. A kid riding in backwards, or turning the camera, misses the whole payoff.
   - Also require `camera:WorldToViewportPoint(piece)` to report it on screen, and the piece to be at most about 60° off the camera's look.
   - Until then, show a "✨ Here!" BillboardGui over the hidden spot so the kid turns toward it.
2. **The Champion gate arch is the Trail's log arch** (`BarnDecor.luau:353`). The same mesh already marks the Trail Gate and the Legend paddock. "Welcome! 🏡" and pennants help, but rustic logs still say "a path to somewhere else", and nothing about it says grand.
   - After `placeModel`, run it through the existing `tint()` in barn white `FBFBF5` with the barn's trim colour on the caps.
   - It then reads as a painted show-gate, its own landmark. One line.

## SHOULD-FIX

- **Clutter check.** Add a PLAYTEST line: "every yard item bought: the gate, stalls, garden and the Rosette Wall stay visible and walkable from Barn Lane". Take one screenshot from the lane.
- **Hidden pieces still collide.** `LocalTransparencyModifier` hides a part but keeps its collision, so a kid can bump an invisible trough before the reveal fires. Set `CanCollide = false` locally while hidden.
- **The compass letters can't be read** from Barn Lane at 0.7 studs. Drop them, or put them on bigger 1.2-stud plates.
- **The silhouette's rim** is a near-white cream. Against a pale sky it is invisible, which is fine. Keep the decal at `LightInfluence` 1 so the vane silhouettes darkly the way real iron does.

## Sign-off

**Yes, once the two must-fixes land.** Both are a few lines, and I can verify them from the diff.
