# Consult: phase 5, visiting other stables (D-079), feel

I read the code only; nothing has been run in Studio.

## Verdict

**MUST-FIX: 3 items, all small.** Everything else is signed off.

The arrival is warm:
- `gate_bell` rings and the "Welcome to Mia's barn!" card pops in and fades.
- The visitor bar fits the top slot.
- The cheers are text-free.
- The pin pays off with `job_done`.

The walkaround and the cheers need a little more world feedback to feel like a tour of someone's home.

## MUST-FIX

1. **A tour stop happens only in the HUD.**
   - `VisitTour.client.luau:246`: reaching a stop sets 2 s of bar text, "Look! …", plus `tap_ok`. Nothing happens in the world.
   - Fix: at the stop, add
     - a sparkle burst (12 particles, `FFD23F`, life 0.8 s);
     - a `Highlight` on the featured object (OutlineColor `FFD23F`, FillTransparency 1) for 1.2 s, fading out over the last 0.3 s.
   - Under Reduced Motion, keep the outline and drop the sparkles.
   - The kid's eyes then go to the owner's things, not to the top bar.
2. **A cheer gives the visitor nothing.**
   - Cheer currently plays no sound and shows nothing in the world.
   - Fix: on a sent cheer, float the emoji from 4 studs above the barn's door: a BillboardGui of 64 px that rises 3 studs over 1.2 s and fades over the last 0.4 s. Play `clap` at volume 0.4.
   - For 🎉, play `tap_good` at speed 1.2 instead.
   - This is the stranger's main verb, so it has to feel like something.
3. **Two stop names are wrong for a visitor** (`Visits.luau:47`).
   - `decor = "Barn Builder"` names our shop, not their home. Rename it "Their yard".
   - `paddock = "Legend paddock"`: most barns have no Legend, so the stop is an empty field. When the owner has no Legend, swap that stop to the **garden** (`garden = "Their garden"`) so all 4 stops always show something.

## Nice-to-have

- **Stall horses greet visitors too.** Reuse A2's yaw: 20° over 0.5 s within 14 studs, with `horse_nicker` at 0.4, once per visit. A horse saying hello is the warmest thing a stranger can get.
- **A bit more on the pin.** Add `confetti_square` (30) at the visitor and the toast "Tour pin! 📍" alongside `job_done`.
- **Owner side:** an anonymous cheer could pop the same emoji over *your* barn door when you're home. That's a nice "someone liked my barn" moment.
