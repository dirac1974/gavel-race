# Gavel Race

Skill-based 8-horse race with **prices locked before the race**. Players boost a horse by timing a moving meter (the gavel) into a green zone. The gavel changes only win probability, never the posted prices.

The repo holds two versions of the model:

| Version | For | Status |
| --- | --- | --- |
| **v2** — exponential tilt, cash purses, race-relative skill | No-wager game (Roblox). Entry is free; winners receive a purse locked before the race | **Current** — see [docs/V2_PROPOSAL.md](docs/V2_PROPOSAL.md) |
| v1 — linear shift, locked win and quinella odds, fixed house edge | Wagering design | History — see [docs/SOLUTION.md](docs/SOLUTION.md) |

Roblox prohibits both simulated and actual gambling, including bets with free currency, which is why v2 has no stakes, odds, margin, or quinella.

## v2 in six steps

1. Base win chance from Race Ratings: `q = softmax(Rating / T)`, floored at 2.5%.
2. Locked win purse: `round(B / q)` in whole cash. Every horse expects `B` at average play.
3. Gavel window score: `100 (1 − d)` on a constant-speed meter; `S` = mean of 3 windows.
4. Skill vs. this race: `R = clamp((S − mean S) / 50, −0.5, 1)`.
5. Live win chance: `p' ∝ q · e^{κR}`, `κ = 1.0`.
6. Finish order: sequential draw from `p'` (Harville).

## Run

```bash
bash scripts/setup_cloud.sh            # pytest + Lune
python -m pytest -q                    # all tests, incl. Luau parity when lune is installed
python src/gavel_race_v2.py            # v2 reference + simulations (~5 s)
python sims/economy.py                 # progression pace
python src/gavel_race_v2.py --races 50000 --seed 1
python src/gavel_race.py               # v1, kept for history
```

Stdlib only. `src/RaceMath.luau` is the same v2 model as a Roblox server ModuleScript.

## Project layout

| Path | What |
| --- | --- |
| `CLAUDE.md` | Rules and workflow for the Claude Code agent team (start here) |
| `docs/KICKOFF.md` | Prompts to run build loops, debates, and reviews |
| `.claude/agents/` | Engineering team and Roblox design council agents |
| `docs/memory/` | Decisions, status and backlog, review queue, changelog |
| `docs/debates/`, `docs/research/` | Design council records and cited research |
| `game/` | Roblox (Rojo) project: Phase 1 race prototype |
| `sims/` | Economy and progression simulations |
| `tests/` | Python tests, Luau tests (Lune), parity fixtures |

## Docs

| File | Contents |
| --- | --- |
| [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md) | Condensed game design |
| [docs/V2_PROPOSAL.md](docs/V2_PROPOSAL.md) | v2 rationale, formulas, dials, simulation results, integrity rules |
| [docs/MEMORY.md](docs/MEMORY.md) | Session memory: concept, decisions, both versions |
| [docs/CONCEPT.md](docs/CONCEPT.md) | Original game concept and player loop (v1 framing) |
| [docs/SOLUTION.md](docs/SOLUTION.md) | v1 formulas for odds, gavel adjustment, quinella |
| [docs/DISCUSSION.md](docs/DISCUSSION.md) | Condensed discussion log |

## v2 design constants

- 8 lanes; bots fill empty lanes in cash races
- `T`: Rookie 22, Bronze–Silver 18, Gold 14.4, Champion 12 (10 rating points ≈ 2× chance at 14.4)
- `κ = 1.0`, `q` floor 2.5%, `R` floor −0.5
- Place prizes: 2nd 1.2B, 3rd 0.8B, 4th 0.4B
- League base `B`: Rookie 20, Bronze 50, Silver 120, Gold 300, Champion 750
