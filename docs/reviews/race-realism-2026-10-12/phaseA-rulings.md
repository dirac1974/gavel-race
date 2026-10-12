
## Systems rulings on the failed phase A gates (2026-10-12)

**1. Post bias 0.0018–0.0034 (gate ≤ 0.002): CHANGE.**
- **Mostly noise, at this run size.** The report has 150 races per cell and the baseline 300 per post, with τ sd about 0.01. That puts the standard error of each post's bias near 0.001, and the maximum over 8 posts × 16 cells lands near 0.003.
- **The full write should bring the kid-among-bots case under 0.002.** It won't fully fix the all-Smart case. That one is structural: when every lane files to lane 1, the inner posts gain, and a single per-post row built from bot fields can't remove an effect that depends on who is in the field. Today's game already misses it (0.0024).
- **New gates:**
  - **Kid among bots ≤ 0.002.** This is the live case. Judge it with ≥ 1,000 report races per cell after the 2,000-race write.
  - **All-Smart ≤ 0.003,** reported. It needs 8 human riders on one card, which is rare.
- **Do not raise `BASELINE_RACES` to 4,000.** Memory is the limit.
- **If kid-among-bots still fails, the lever is composition, not race count:**
  - add a field-kind key to the baseline: post × {solo-human, mostly-human};
  - or set `pack.stagger` so lane-2 riders sit off the rail horse, which lowers the inner-post gain.

**2. Retire "rail rider beats Smart Steer by 0.01–0.03": ACCEPT, provisional.** Riders keep `file.homeLane` 1. The skilled-steering edge moves to the move. Add the replacement gate to phase C: a press-when-lit rider beats a never-press rider by +0.003 to +0.008 τ. Log it in D-072 and REVIEW_QUEUE.

**3. Inward press within 3 s at 53–67% (gate ≥ 70%): CHANGE the gate.** A crowded rail is the realism David asked for. **New gate:**
- ≥ 55% within 3 s;
- ≥ 85% within 6 s;
- "No room yet" shown on every wait longer than 1 s;
- in a rider's first 3 races, no bot shuts a door on them (as planned).

**4. Masher reversals at 8.0–8.4 a minute (gate ≤ 8): CHANGE.**
- First set `steering.weaveWindowSeconds` 7 → **8** and re-run.
- If the result is still above 8, accept ≤ 8.5 for the masher profile only, provided the griefing and brush gates hold. A masher earns no pips and no τ, so this is visual only.

**Additions:**
- **5. `file.riderRoomFeet = 6`: ACCEPT.** It's the reason the boxed share falls. Confirm ≤ 35% in Luau with `tap_preview_report` after the port.
- **6. A "rider" entry in the style baseline: ACCEPT.** This meets my vote item 1. The gate: a passive Smart Steer kid among bots nets 0 ± 0.003 τ at full size. The phase C move term must use the same row.
- **7. Draft share at 40% (Sprint):** it passes at the limit. Report it at full size.
- **8. Passes:** keep Trip passes 1–10 for the Sprint and 3–10 elsewhere. Drawn overtakes count only when a horse is 1 length clear and holds it for 2 s, with a target of 3–15 a race. 47 half-length swaps would read as churn, not racing.
