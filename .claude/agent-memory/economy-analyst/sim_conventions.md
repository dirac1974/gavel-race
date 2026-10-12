---
name: sim-conventions
description: How sims/economy.py tests coexist with GameConfig values that other developers land later (strict conditional xfail pattern, whole-ladder check)
metadata:
  type: feedback
---

When I recommend config values that live under `game/`, which I may not edit while other developers are working there, follow these steps:
1. Put the values in the sim as a named dict, for example `economy.PHASE3`, and keep the live values as `CURRENT`.
2. Test the targets against the named dict.
3. Gate the live-config tests with `pytest.mark.xfail(not LANDED, strict=True)`. They fail loudly until the values land and become ordinary tests once they do.
4. Add a "whole ladder" test: GameConfig must hold all-old or all-new values, never a mix.

**Why:** the tech lead asked for tests that are parameterised to run against the values once they land in GameConfig, and for a clear mark on the tests that will pass only after the change.

**How to apply:**
- Use this for any balance change whose source of truth is GameConfig.luau.
- Pin history tests, such as the D-062 Silver tests, to their own constants so a retune doesn't break them.
- Also list the Luau tests that pin the old numbers, for example `tests/luau/class_tests.luau`.

Related: [[ladder-phase3]].
