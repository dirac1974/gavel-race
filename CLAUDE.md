# Gavel Derby — project instructions for Claude Code

Kid-friendly Roblox horse racing game built on the gavel-race model. Read this file, then `docs/memory/STATUS.md`, before doing anything.

## Hard rules (never break)

1. **No wagering of any kind.** Roblox prohibits simulated and actual gambling, including bets with free, unbuyable currency. No stakes, odds, bet slips, payouts-for-predictions, or quinella. Entry is free; prizes are purses locked before the race. Banned UI words: bet, wager, odds, stake, payout, house, bookie. Spectator cheering (D-019) is the one allowed form of backing a rider: free, cosmetic Fan XP only, earned from the rider's taps, never scaled by win chance.
2. **Diamonds (Robux currency) never change win chance, Race Rating, or the gavel** (safeguard pending David's confirmation, D-002a). Green Cash is never sold and has no paid multipliers. No paid random items without odds disclosure and `PolicyService` gating.
3. **Kid safety first.** No streak resets to zero, no fake-urgency offers, no purchase prompts during or right after a race. Horses never die, sicken, or run away from neglect.
4. **Design decisions are made by the team, provisionally.** David delegated design decisions on 2026-10-04 and will review later. Log every design decision in `docs/memory/DECISIONS.md` as `Accepted (provisional)` with the reasoning and the alternatives considered, and list it in `docs/memory/REVIEW_QUEUE.md` for David. Prefer reversible choices and keep them behind config values. Rules 1–3 are not design choices and can't be overridden this way.
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
| Provisional decisions to review | `docs/memory/REVIEW_QUEUE.md` |
| Change history | `docs/memory/CHANGELOG.md` |
| Design debates | `docs/debates/` |
| Research notes | `docs/research/` |
| Python reference model | `src/gavel_race_v2.py` (v1 `src/gavel_race.py` is frozen history) |
| Roblox code | `game/` (Rojo project); race math in `src/RaceMath.luau` |

Each subagent also keeps its own notes in `.claude/agent-memory/<agent>/` (checked in).

## The build loop (one task per loop)

You are the **tech lead**. For each loop:

1. **Pick** the top item in `STATUS.md` → Backlog. If it needs a design decision, run a short design-council debate (or decide it yourself for small calls), log it as provisional, and continue.
2. **Plan** in 3–6 lines inside `STATUS.md` → In progress.
3. **Implement** by delegating: `model-engineer` (Python model and simulations), `roblox-engineer` (Luau/Roblox), `economy-analyst` (balance sims).
4. **Test**: delegate to `test-engineer`. All tests and the policy guard must pass: `python -m pytest -q && bash scripts/policy_guard.sh`.
5. **Review**: delegate to `code-reviewer`. Fix every blocking finding, then re-test.
6. **Record**: delegate to `scribe` to update `DECISIONS.md`, `STATUS.md`, `CHANGELOG.md`, and open questions.
7. **Commit and push** to `main` with a conventional message (`feat:`, `fix:`, `test:`, `docs:`). If `main` rejects the push, push a `claude/<topic>` branch and open a pull request instead.

Stop the loop and report if tests can't be made green in three attempts.

## The design council (debates)

`design-moderator` runs debates among `designer-engagement`, `designer-competitive`, `designer-child-safety`, and `designer-young-player`, with `roblox-researcher` supplying facts. Protocol and template: `docs/debates/README.md`. The moderator's recommendation becomes an `Accepted (provisional)` decision and goes into `REVIEW_QUEUE.md`.

## Commands

```bash
bash scripts/setup_cloud.sh          # once per session: pytest + Lune
python -m pytest -q                  # all tests (Luau parity runs when lune is on PATH)
bash scripts/policy_guard.sh         # no wagering words in game code, no model names anywhere
python src/gavel_race_v2.py          # reference model + simulations
```
