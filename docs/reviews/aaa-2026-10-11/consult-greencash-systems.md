# Systems consult: Green Cash as built (D-070, lead)

I read `greencash-sim.md`, "Final prices (sim)", PLAYTEST "Green Cash: Barn Builder", `BarnCatalog.luau`, `Style.buyCash` / `giveBack`, and `Profile.syncBestLeague`.

## Verdict on what was built

- **Purses: accepted.** I accept 20/30/45/65/85 over my 20/30/45/60/80. Gold was sitting on the limit, so the change is justified, and the ladder is untouched.
- **Results:**
  - casual wait is 1 session in every league;
  - the first item is built in session 1;
  - there is no pile before Champion in any profile (p90 ≤ 0.92);
  - feed is always affordable;
  - the skill premium is about 1.53×.

  That meets every target I set.
- **Currencies stay separate:**
  - a return refunds the currency that was paid (`paidIn`);
  - Tack & Paint lists no 💵 items;
  - shelves open on a best-league mark that never goes down;
  - prompts, the pill and the shelf note respect the 120 s after-race window;
  - nothing that looks like a win is for sale.

## MUST-FIX

1. **The GAME_DESIGN "time skips" line contradicts D-050 and D-044** (Economy → Diamonds). Change it to: "Time skips: none for now (D-050). If ever added, decor builds only (D-044). Never Energy, training, garden, foals or the race queue." This is a doc fix only, but the line invites a pay-to-race route later.

## SHOULD-FIX

1. **Multi-horse sim before soft launch.** Second horses start again in Rookie, and market horses and stalls are the real mid-game sinks. Add `--greencash --horses 2,3` (rotation on Energy) and confirm the waits and piles still hold.
2. **Fix the numbering mix-up.** GameConfig labels the tap preview "D-070", but Green Cash is D-070 and tap gap is D-071. The scribe should correct the comment.
3. **`Style.buyCash` writes `p.cash -= price` directly.** Route it through `Profile.spendCash`, so any future spending rule or ledger applies in one place.
4. **Keep the friends' ✨ marker (48 h) to a single glyph.** Never add a count or a "most built" label (D-042).

## Decision: the post-Champion pile

**(a) now, and (b) designed as the post-launch plan. Reject (c).** Lowering Champion B by 5 cuts only about 6% and hurts casual kids.

- **Why (a) is safe.** A pile after Champion harms no one: nothing trades, sells or converts. The catalog's job, "something to earn toward before Champion", is done.
- **(b) Champion Workshop,** built later; log it in REVIEW_QUEUE:
  - **How it opens.** A new item opens at each stable milestone of total Champion wins (any of your horses): 10, 25, 50, 100 and 200.
  - **Prices.** Each item costs 8,000–15,000 💵. Examples: rose arbor, clock tower cupola, fountain, painted carousel horse, Champion lane-colour bunting.
  - **What it never does.** Never timed, never rotating, never "limited". Opened items stay open, and milestones count only and never reset.
  - **Visibility.** Items are visible to visitors, with no numbers.
  - **Assets.** Models come from a later Meshy budget.
- **The bigger long-term sink is breeding fees (D-047).** They are Green Cash only and scale with the parents' league. Size them in the breeding sim against this pile.

## Sign-off

**YES** for D-070 as built, once the GAME_DESIGN fix is in. The Champion Workshop and the multi-horse sim go to REVIEW_QUEUE and STATUS (before soft launch).
