# Concept

## Fantasy

Eight horses. Posted win prices and quinella prices are on the board before the gates open. During the race a meter sweeps back and forth. The green zone is the middle. A player hits the gavel when the indicator is in that zone to give their horse a performance bump.

The bump is not magic money. A good hit steals probability from horses whose players missed or underperformed, in proportion to those horses’ win probability and in a way that leaves the house’s expected payout on the **already posted** odds unchanged.

## Players

- Each participant is tied to one horse (or bets that horse and plays the gavel for it).
- Performance score `S` is 1–100. It is skill at centering the meter, not a separate RNG on the horse.
- `S = 50` is average: desired boost is zero. The horse still feels a small correction if other horses are far from average, because the book must stay balanced.

## Products

1. **Win** — horse finishes first. Payout is the locked decimal odds.
2. **Quinella** — two horses finish first and second in either order. Payout is the locked pair odds.

Both boards are final when the race begins.

## House

Target edge is 7% overround before rounding (`book probability = fair probability * 1.07`). Rounding uses the tiered rule and can move the realized edge a little. After the gavel, win-book expected payout (equal stake on each horse) is forced back to the same constant the locked odds implied.

## Skill as a product feature

Average and poor gavel play should lose. Strong play should sometimes beat the posted price. The design target is that a strong player’s best bets have expected return over 100% in about 20–30% of races, not every race. That comes from scaling the skill coefficient and from race-to-race noise on the meter hit, not from changing odds.
