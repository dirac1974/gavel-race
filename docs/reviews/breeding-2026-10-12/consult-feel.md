# Consult: breeding (D-080), feel, as built

I read the code only. Nothing has been run in Studio.

## Verdict

**MUST-FIX: 1 item.** Everything else is signed off.

What checks out against `votes-feel.md`:
- **Arrival:** the foal steps out and nuzzles twice, 8 hearts rise, and the sounds play in order: `horse_nicker` at 1.45, the parent's answer at 0.9 after 0.4 s, then `job_done`. No confetti and nothing birth-like. Any tap skips after 1 s. Reduced Motion fades it in.
- **Surprise coat:** one line ("✨ A surprise coat: …") and 6 extra sparkle-hearts. No spin and no bigger party.
- **Naming:** `tap_good` plus 2 claps.
- **"🍼 Comet's foal!" banner:** fires once.
- **Foal Barn:** cream `FFF4C7`, sky `8ED6FF`, roof `C8463D`, and named "Foal Barn".
- **`foalLook`:** body 0.70, legs 0.92, grows by 30 races, race floor 0.94 uniform. Tag-along and hops match F7.

## MUST-FIX

1. **The running legs will undo the foal shape.** This is `HorseLook.shapeFoal` (`HorseLook.luau:192-230`) against `HorseLegs` (`:164-195`).
   - **The cause:**
     - `LegRest` is stored once, at load (`AssetService` → `HorseLegs.markRest`), as an adult body-relative CFrame, and clones carry that attribute.
     - `shapeFoal` then runs `ScaleTo(0.70)` and stretches the legs. Attributes don't scale.
     - So `restOf()` places each leg at the *adult* offset from a smaller body. The legs splay outward and sink below the ground.
     - If `HorseLegs` has already built its state for that model, the cached `toHip` and `hipToLeg` are adult-sized too.
   - **The fix:** at the end of `shapeFoal`, inside the pcall:
     - call `HorseLegs.markRest(model)` to re-record the rest from the shaped legs;
     - drop the cached state with a new `HorseLegs.forget(model)` that sets `states[model] = nil`.
   - **Test:** a Lune check that after `shapeFoal`, every leg's top stays within 0.05 studs of its hip on the body.
   - **PLAYTEST line:** "a foal walking behind its parent: legs under the body, hooves on the ground".

## Studio check (already flagged)

- **One-piece stand models.** Here `shapeFoal` stretches the whole model 11% upward (`k = 1 + 0.31·0.35`), head included.
  - If the head looks tall rather than the legs looking long, set the one-piece path to `k = 1` (a uniform 0.70 foal) in a `foalLook.onePieceStretch` key, default 0.35.
  - A uniform small foal reads better than a stretched head.
