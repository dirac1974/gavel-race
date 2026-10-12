---
name: aaa-review-process
description: AAA review run (2026-10-11) on branch claude/aaa-review: phased builds, reviewer writes phaseN-code-review.md, scribe logs D-066..D-069 after review
metadata:
  type: project
---

The AAA review build (docs/reviews/aaa-2026-10-11/CONSENSUS.md) runs in 4 phases (D-066 to D-069) on branch `claude/aaa-review`. For each phase the code-reviewer writes `docs/reviews/aaa-2026-10-11/phaseN-code-review.md` with BLOCKING / NON-BLOCKING sections (file:line plus a concrete fix), and does not edit game code.

**Why:** the process per phase is developers, then test-engineer, then code-reviewer, then fixes, then the four reviewers consult, then the scribe. DECISIONS and REVIEW_QUEUE entries normally land after review, so missing D-06x entries at review time are flagged as non-blocking but required before commit.

**How to apply:** check the cross-cutting rules (draw-only, one FOV owner at most +6°, Reduced Motion off, no longer races, kind copy) for every phase. Client Roblox code here is written without Studio access, so look for Roblox API ordering pitfalls (for example, an Attachment's WorldPosition set before it is parented). Phase 1 review: [[phase1-findings]] lives in the repo file itself.

Useful check (Phase 2): pytest does not compile client scripts, so compile every `game/src/**/*.luau` with a Lune script using `require("@lune/luau").compile` — catches syntax errors and the 200-local/register limit (RaceController was at 195/200 top-level locals after Phase 2). Also check every consumer of a remote whose firing pattern changed (Phase 2's post-lock preview re-fired `LiveChances` and broke FanClient's cheer-close rule).

Phase 3 lesson: "🔀 More choices" (RacePicker) is only reachable from the queue card, i.e. while the player is already in line. Any new picker action that passes a course to `JoinRace` must survive `joinQueue`'s early returns (same key → keep course; alone in line → card follows the pick). Phase 3's Race-with-friend broke on exactly that. Also, `pytest` now includes `tests/test_compile_all.py`, but still run the Lune compile when client files change.
