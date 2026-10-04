# Decisions

Every decision, newest last. Never delete an entry; mark replaced ones `Superseded by D-NNN`.

**Status:** `Accepted` (in force) · `Proposed` (awaiting David) · `Rejected` · `Superseded`.
Engineering choices may be `Accepted` by the team. Anything players experience needs David.

Template:

```
## D-NNN — Title
- Date: YYYY-MM-DD
- Status: Proposed | Accepted | Rejected | Superseded by D-NNN
- Decided by: David | team (engineering only)
- Context: why this came up
- Decision: what we do
- Consequences: what it changes, risks
- Links: debate, research, commit
```

## D-001 — No wagering; prizes are locked purses
- Date: 2026-10-04
- Status: Accepted
- Decided by: David (plan approved in chat)
- Context: Roblox prohibits simulated and actual gambling, including bets with free currency.
- Decision: free entry (Energy-gated), purses locked before the race and paid by finish. No odds display, no quinella, no prediction payouts.
- Links: docs/V2_PROPOSAL.md, docs/GAME_DESIGN.md

## D-002 — Two currencies
- Date: 2026-10-04
- Status: Accepted
- Decided by: David
- Decision: Green Cash is the main currency, earned from races, stable care, quests, and daily login, and never sold. Diamonds are bought with Robux and used for boosts and extras.

## D-002a — What Diamonds may buy
- Date: 2026-10-04
- Status: Accepted (provisional)
- Decided by: team, under D-009
- Context: David's original idea included Diamond boosts to qualify for higher races. Buying win chance in a skill race undermines fairness, and paid probability modifiers fall under Roblox's paid random item rules.
- Decision: Diamonds buy cosmetics, time skips, and space only; never win chance, Race Rating, or the gavel. Qualifying for cash leagues is earned; Diamonds can buy an Exhibition entry to a higher league for XP and a cosmetic ribbon, with no cash purse.

## D-003 — Race model v2 replaces v1
- Date: 2026-10-04
- Status: Accepted
- Decided by: David
- Decision: exponential tilt `p' ∝ q · e^{κR}`, cash purses `5 · round(B / 5q)`, no margin, no tiered rounding, no skill noise, Harville finish order, flat place prizes 2nd 1.2B / 3rd 0.8B / 4th 0.4B.
- Consequences: exact per-race cash invariance traded for ~0.2–0.5% drift.
- Links: docs/V2_PROPOSAL.md

## D-004 — Skill measured against the race average
- Date: 2026-10-04
- Status: Accepted
- Decided by: David
- Decision: `R = clamp((S − mean S of this race) / 50, −0.5, 1)`.
- Consequences: same chances as league-median centering except at clamp edges; no league statistic to game; lower collusion gain. Upsets are tuned with T (frequency) and κ (who earns them).

## D-005 — Starting dials
- Date: 2026-10-04
- Status: Accepted (tunable within ranges by the team, logged here)
- Decided by: David
- Decision: T by league Rookie 22, Bronze–Silver 18, Gold 14.4, Champion 12; κ 1.0 (range 1.0–1.2); q floor 2.5%; R floor −0.5; B Rookie 20, Bronze 50, Silver 120, Gold 300, Champion 750.

## D-006 — Party members never share a cash race
- Date: 2026-10-04
- Status: Accepted
- Decided by: team (integrity), consistent with D-001
- Decision: friends in a party race each other only in Friend Races that pay XP and cosmetics.

## D-007 — Theme-agnostic engine for reskins
- Date: 2026-10-04
- Status: Accepted
- Decided by: David
- Decision: engine code uses generic terms (Racer, Pilot, Upkeep, Facility); a ThemePack holds names, art, and condition weights. Car and boat skins later, flower contest deferred.

## D-008 — Autonomous agent team workflow
- Date: 2026-10-04
- Status: Accepted
- Decided by: David
- Decision: Claude Code agents implement, test, review, and record work, pushing to `main` when green. Design debates produce proposals only. Workflow in CLAUDE.md.

## D-009 — Design decisions delegated to the team
- Date: 2026-10-04
- Status: Accepted
- Decided by: David ("make all decisions yourself and we can review later")
- Decision: the team makes design decisions as `Accepted (provisional)`, logs reasoning and alternatives, and lists each in `REVIEW_QUEUE.md`. Hard rules 1–3 in CLAUDE.md (no wagering, Diamond limits as policy safeguards, kid safety) are not open to this delegation.
