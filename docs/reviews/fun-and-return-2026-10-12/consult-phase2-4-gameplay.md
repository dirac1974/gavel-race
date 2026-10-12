# Phases 2–4 consult: gameplay (D-076 progress, D-077 legs and the vet, D-078 life arc)

Static read of `ClassPath`, `ClassUp`, `Legs`, the coolDownGame, `Ageing`, `ResultsText.nextKind`, `Advice` and the config blocks. No tests run.

## Fun, clear and fair?

### Progress
**Yes.**
- The class path, the Cup bar (a fill, never a number) and the class-up ceremony away from "Race again" turn every race into visible progress.
- An open Cup takes priority on the path (`ClassPath.luau:54`).

### Vet check
**Lands as care, not punishment.**
- The chips are kind: "💦 Worked hard!", "ran a lot today!" and "Next: a vet check".
- The reject copy is kind: "🩺 Vet check first! Practice is open."
- RACE! and "Race again" both become 🩺 VET CHECK and GO straight to the check (`ResultsText.luau:148`, `Hud.client.luau:469`). No dead-end button.
- The four tap steps, a wrap colour of the kid's choosing worn for 3 races, the carrot and "Fresh legs!" make it a small reward.
- It's free and has no Rating effect, and no hurt words appear.
- Care lowers the run by 2, so a kid who looks after the horse rarely meets the vet. That's the right lesson.

### Ageing
**Fair.**
- The decline waits until the horse is at 90% of its Potential (`peakShare`) and is at least 350 races old.
- It is −1 per 50 races, capped at −4.
- It never applies in Practice, ceilings or League Points.
- The warnings are kind: "is getting wise / Soon a little slower" and "Wise and steady".

### Stage chips 🍼 💪 🦉 👑
💪, 🦉 and 👑 read well. **🍼 doesn't.**
- It says "baby bottle / foal" on a horse that is racing.
- It reads babyish to the 11–13s.

## MUST-FIX

1. **The Star Race step promises a race that doesn't exist yet.** `ClassPath.luau:17` ("Star Race") and `:96` ("💐 {name} is Star Race ready!"), plus the class-up ceremony, tell a kid a race is ready. The named races come in the next build, so the kid goes looking for a race that isn't there.
   - **Until the graded races ship:** rename the step to `WORD.Star = "Star horse"`.
   - Change the line to `"💐 " .. name .. " is a Star horse!"`.
   - Keep the 5 wins (`classes.starRaceWins = 5`).
   - Switch back to "Star Race" when the named races land.
   - Add a key, `classes.starIsRace = false`, so it's one flip.
2. **Logged deviations.** Both need a row in DECISIONS (D-077/D-078) and in REVIEW_QUEUE with the sim figure:
   - `legs.fromRaces = 26`, where the consensus said 10;
   - `ageing.declineScale = 1`, on tonight, with the `--ageing` result.

## SHOULD-FIX

- **Young chip:** 🍼 → **🌱** in `Ageing.EMOJI.Young` and `YOUNG_LINE`.
- **Playtest checks:**
  - a kid on run 5 sees "💦 Worked hard!" before the stop;
  - feeding visibly drops the legs pips.

## Sign-off

**Yes, once MUST-FIX 1 and 2 are done.** It's fun, clear and kind.
