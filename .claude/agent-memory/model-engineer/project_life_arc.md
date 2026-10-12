---
name: project-life-arc
description: Life arc sims (ageing decline, Riding School sell cap, vet run counter) 2026-10-12: non-obvious results and where the Champion plateau really is
metadata:
  type: project
---

Findings from `sims/lifearc.py` (src/life_arc.py reference, Ageing.luau mirror), 2026-10-12:
- The "54% Champion plateau" is reached only at ~1,200-1,500 counted races (horse trained out to Potential), not at Champion arrival (~330-350 races, ~18-28% wins). Race-counted ageing vs week-capped training means keen kids (60 races/wk) have the weakest horse per race; decline bites them hardest (keen 650-900: 34% -> 27%).
- With 350/50/-4 the plateau goes 55% -> 47% (average kid), not the systems designer's 38-45%. declineScale 1 chosen on the plateau reading; the strict all-windows 30% floor fails even with decline off.
- Systems ruling fixed the early bite: decline counts from a stored declineFrom (350+ races AND stats >= 90% of Potential); declineFrom median 630 casual / 1020 keen; all gates pass, scale 1.
- Youngster training x1.25 changes nothing: the weekly cap (6) already binds for every profile.
- Win-cash invariant means decline barely moves cash/race (B/q rises as q falls).
- Sell bonus cap must stay < half the cheapest Market price (250) -> 100.
- Vet run (6 in a row) fired mostly in free Rookie races; fromRaces 26 + care -2 once per kind per 2 h gives keen 1.09 per 20+ race session, casual 0.03.

**Why:** these reframe any future ageing/endgame tuning (D-068 Champion endgame, Legend, breeding).
**How to apply:** judge Champion win-rate gates by race window, not one number; reuse `economy.career(ageing=, trace=, start=, min_played=)`.

Related: [[project-race-realism-d072]]
