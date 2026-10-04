# Gavel Derby — project instructions for Claude Code

Kid-friendly Roblox horse racing game built on the gavel-race model. Read this file, then `docs/memory/STATUS.md`, before doing anything.

## Hard rules (never break)

1. **No wagering of any kind.** Roblox prohibits simulated and actual gambling, including bets with free, unbuyable currency. No stakes, odds, bet slips, payouts-for-predictions, or quinella. Entry is free; prizes are purses locked before the race. Banned UI words: bet, wager, odds, stake, payout, house, bookie.
2. **Diamonds (Robux currency) never change win chance, Race Rating, or the gavel** (safeguard pending David's confirmation, D-002a). Green Cash is never sold and has no paid multipliers. No paid random items without odds disclosure and `PolicyService` gating.
3. **Kid safety first.** No streak resets to zero, no fake-urgency offers, no purchase prompts during or right after a race. Horses never die, sicken, or run away from neglect.
4. **Game-design rule changes need David's approval.** Engineering choices are yours to make and log. Anything that changes what players experience (rules, economy numbers outside tuning ranges, monetization, new systems) is recorded as `Proposed` in `docs/memory/DECISIONS.md`, added to `docs/memory/OPEN_QUESTIONS.md`, and not shipped to `main` until David marks it `Accepted`.
5. **Never mention a specific Claude model** in commits, comments, or docs. Write "Claude".
6. **Never force-push or rewrite history.** Never commit secrets.

## Source of truth

| What | Where |
| --- | --- |
| Race math spec | `docs/V2_PROPOSAL.md` |
| Game design | `docs/GAME_DESIGN.md` |
| Decisions (ADR log) | `docs/memory/DECISIONS.md` |
| Current state and backlog | `docs/memory/STATUS.md` |
| Questions for David | `docs/memory/OPEN_QUESTIONS.md` |
| Change history | `docs/memory/CHANGELOG.md` |
| Design debates | `docs/debates/` |
| Research notes | `docs/research/` |
| Python reference model | `src/gavel_race_v2.py` (v1 `src/gavel_race.py` is frozen history) |
| Roblox code | `src/RaceMath.luau` now; `game/` (Rojo project) once created |

Each subagent also keeps its own notes in `.claude/agent-memory/<agent>/` (checked in).

## The build loop (one task per loop)

You are the **tech lead**. For each loop:

1. **Pick** the top unblocked item in `STATUS.md` → Backlog. If it needs a design decision that isn't `Accepted`, skip it and note why.
2. **Plan** in 3–6 lines inside `STATUS.md` → In progress.
3. **Implement** by delegating: `model-engineer` (Python model and simulations), `roblox-engineer` (Luau/Roblox), `economy-analyst` (balance sims).
4. **Test**: delegate to `test-engineer`. All tests must pass: `python -m pytest -q`.
5. **Review**: delegate to `code-reviewer`. Fix every blocking finding, then re-test.
6. **Record**: delegate to `scribe` to update `DECISIONS.md`, `STATUS.md`, `CHANGELOG.md`, and open questions.
7. **Commit and push** to `main` with a conventional message (`feat:`, `fix:`, `test:`, `docs:`). If `main` rejects the push, push a `claude/<topic>` branch and open a pull request instead.

Stop the loop and report if tests can't be made green in three attempts.

## The design council (debates)

`design-moderator` runs debates among `designer-engagement`, `designer-competitive`, `designer-child-safety`, and `designer-young-player`, with `roblox-researcher` supplying facts. Protocol and template: `docs/debates/README.md`. Debates produce **proposals**, never shipped changes.

## Commands

```bash
python -m pytest -q                  # all tests
python src/gavel_race_v2.py          # reference model + simulations
```
