---
name: project-tap-preview-d071
description: D-071 draw-only pre-lock tap preview (TapPreview.luau) design findings: own-pace preview, lane-room limits, boxed-in riders, numbering clash with Green Cash D-070
metadata:
  type: project
---

The pre-lock tap preview is D-071 (Green Cash took D-070 on 2026-10-11; the tapgap plan says D-070, but D-071 is correct).

Findings from building it on 2026-10-11 that the code doesn't spell out:
- previewLive (field-wide) made steady riders slide back when bots' next-checkpoint scores were higher. The preview uses RaceSession:previewOwn instead: every other lane keeps its own pace, so only a rider's own taps move their horse. It also keeps the steady-rider pull-back near 0.
- Most of the tuning effort went into lane room. Trip only clears 8/10 ft in off-space, so residual differences break lane joins. The adjacent-lane bound (joinSlackFeet -4) and the 19 ft/s room pulls are what reach 0 overlaps and 0 jerks.
- Boxed riders are real, not a harness artifact. In a realistic Rookie field (bots at the anchor ± 6, scores sd 15), lane room holds a rider back by 4 ft or more 53% of the time, against the rulings' 40% gate. The cause is Smart Steer's lane-2 columns. The rulings answered with TapPreview.held, the pressure cue and the chip; getting under 40% needs a decision change.

**Why:** these were costly to discover, and the next tuning pass will hit them again.
**How to apply:** before changing tapPreview constants, rerun `lune run tests/luau/tap_preview_report` and the tap_preview_tests, and keep the race identical with the layer on and off.

Related: [[feedback-windows-python-crlf]]
