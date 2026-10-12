# Phase 3 consult: gameplay (2026-10-11)

## Weaker bots (38/48/56): rivalry and skill gate

**Rivalry: fine.** Kids see win rates, not bot Ratings. An average kid enters each league at 22–25% and leaves at about 33–36%, a healthy band. Keeping κ 1.0 is fine.

**Skill gate: harsher than tuned.**
- Leagues get harder only through the slider (2.4 → 1.1 s sweep, a drifting target, two targets in Champion).
- Bots score `botPaceMean 60` and `botBurstMean 55` in every league.
- Skill is measured against the field average, so in Gold and Champion the kid's scores fall while the bots' don't. The real entry win rates are probably below the sim's (its own model limit).

**Champion goes flat.** As the horse plateaus, the average kid wins about 54% against flat bots. That's a lap of honour, and the taps matter less.

## Mixed-Rating Open Practice: fair and fun?

**No, as built.** The card takes the first rider's league: its T, sweep, distance and bots.
- On a Gold card (T 14.4), a Rating-75 horse has about 7× the base chance of a fresh 47.
- Perfect taps are worth at most about 2×, so the new friend almost never wins.
- The new friend also gets a 1.3 s drifting slider they've never seen, and possibly a 2-minute Classic.

## MUST-FIX (before the friend playtest)

1. **`GameConfig.queue.practiceEqualHorses = true`.** Every lane gets the same Rating when `RaceService` builds a Practice session, so everyone's chance is 1/8. Taps, steering and luck decide, and the lobby honestly shows 12.5%. No purse, points or Energy, so nothing touches the economy or the hard rules. Log it as provisional.
2. **`GameConfig.queue.practiceLeague = "Rookie"`.** Practice always runs at Rookie settings (2.4 s sweep, 4 s burst, Sprint or Mile, Rookie bots), never the first rider's league. The expert still wins on taps, which is honest.

If these miss the build, PLAYTEST must say to test Open Practice with friends in the same league only.

## SHOULD-FIX

- **Per-league bot scores** (`leagues[*].botPaceMean` and `botBurstMean`) from `src/pace_meter.py` at each league's sweep, then re-run `--ladder phase3`.
- **Champion bots rated `max(anchor, rating − 9)`.**
- **`Training.raceGain`** after the freeze, for engaged kids who enter Gold and Champion at 17–19%.
- **Playtest:** measure the same kid's slider score by league. A drop of more than about 10 points at 1.3 s means the per-league bot scores are needed.

## Sign-off

**Ladder: yes.**

**Open Practice: yes only with MUST-FIX 1–2**, or the same-league note in PLAYTEST.
