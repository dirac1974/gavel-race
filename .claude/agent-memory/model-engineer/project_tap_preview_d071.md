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
- In equal Rookie fields with the bots fixed at 60, riders are boxed in a column about 77% of the time. The preview can't show gains there without overlapping, so acceptance (d) holds only with room. Possible fixes are design calls: let Smart Steer see the preview (this changes decisions), or show a message when boxed.

**Why:** these were costly to discover, and the next tuning pass will hit them again.
**How to apply:** before changing tapPreview constants, rerun `lune run tests/luau/tap_preview_report` and the tap_preview_tests, and keep the race identical with the layer on and off.

Related: [[feedback-windows-python-crlf]]
