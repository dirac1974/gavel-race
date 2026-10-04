# Gavel Race

Skill-based 8-horse race with **locked pre-race odds**. Players boost a horse by timing a moving meter (the gavel) into a green zone. Performance redistributes win probability among horses so the **house edge stays fixed** even though payouts never move after the race starts.

This repository records the design discussion, the solution formulas, and a reference implementation.

## What is locked

- Win odds and quinella (1st and 2nd, either order) odds are computed **before** the race and never change once it begins.
- The gavel only changes **outcome probabilities**, not posted payouts.
- House expected return on the win book is preserved exactly by two constraints: probability mass sums to 1, and odds-weighted expected payout stays at the pre-race constant.

## Docs

| File | Contents |
| --- | --- |
| [docs/MEMORY.md](docs/MEMORY.md) | Session memory: concept, decisions, solution |
| [docs/CONCEPT.md](docs/CONCEPT.md) | Game concept and player loop |
| [docs/SOLUTION.md](docs/SOLUTION.md) | Formulas for odds, gavel adjustment, quinella, and +EV scaling |
| [docs/DISCUSSION.md](docs/DISCUSSION.md) | Condensed discussion log |

## Run

```bash
python src/gavel_race.py
```

Stdlib only. Prints base locked odds, a skill scenario (win EV), and the full 28-pair quinella board under those same locked odds.

## Design constants (current)

- 8 horses, base win probabilities sum to 1
- House overround 7% (`r = q * 1.07`) before rounding
- Rounding: `>= 5` nearest integer, `> 2` nearest 0.5, `<= 2` nearest 0.2
- Performance score `S` in 1–100; average `S = 50` has zero desired boost
- Skill scale `gamma = 0.80` plus realized noise so strong players are +EV on their best bets about 20–30% of races
- Odds are fixed; only `p'` moves
