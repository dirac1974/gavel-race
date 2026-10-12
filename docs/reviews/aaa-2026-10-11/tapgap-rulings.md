# Tap gap rulings (D-071, plan owner, gameplay)

**Plan changes: both approved.**
- `previewOwn`: only your own taps move your horse, and the field's true scores arrive at the close. That's honest and readable.
- `previewBots = false`.

## (1) Boxed in

**Artifact or real.** Mostly an artifact of the harness. With equal horses and bots at sd 0, every skill offset is 0, so Smart Steer packs the field into two tight columns.
- **Required:** re-run (d) with a realistic Rookie field: bots at anchor ± 6, scores sd 15, equal-horse rider. Report the boxed share.
- **Target:** ≤ 40%.

**Fix: (b) plus (c).** (a) is rejected because it changes race decisions.
- **`TapPreview.held(tp, i)`:** returns `max(0, target − d)` when lane room limits the drawn horse, else 0.
- **Server to the rider:** an unreliable `TapHeld(feet, course)` at most 2 Hz, sent only when the value changes by ≥ 1 ft.
- **(c) Pressure cue, own screen:**
  - **Trigger:** held ≥ `heldCue.minFeet` (4) for ≥ `minSeconds` (1.0).
  - **Effect:** bob amplitude × 1.3 and one dust puff per stride.
  - Off under Reduced Motion.
- **(b) Chip:** held ≥ `chipMinFeet` (6) for ≥ `chipMinSeconds` (1.5).
  - **Riders with the buttons:** "Find a gap! ◀ ▶". Only when `SteerLane` says a side has room, at most once every `chipEverySeconds` (10), and never after the lock.
  - **Smart Steer riders:** "Your taps still count!", at most once per race.
  - Never the words "boxed in" (D-057).
- **Config:**
  ```
  tapPreview.heldCue = { minFeet = 4, minSeconds = 1.0, chipMinFeet = 6, chipMinSeconds = 1.5, chipEverySeconds = 10 }
  ```

## (2) Residual jerks and own-screen overlaps

- **Try `joinSlackFeet = -7.5`.**
  - Adopt it if the acceptance races with room stay 7/7 and the boxed share rises by ≤ 5 points.
  - Otherwise keep −4 and accept.
- **Don't give TapPreview Trip's tuck state.** It would couple the two modules.
- **Report gates:** shared jerks in ≤ 3 races and own-screen overlaps in ≤ 1 race per 3,840.

## (3) Pull-back in mixed fields

- **Accept `lead = 1.2`.** The pull-back is the truth arriving (the field did ride better), it's under half a length, and it comes after a gain of 8 ft or more.
- **Gates:** p99 ≤ 4 ft, worst ≤ 8 ft.
- No message on a pull-back.

## (4) Lock fade

- **Accept**, with the gate changed to median ≤ 1.5 s, p95 ≤ 2.5 s, worst ≤ 3.0 s.
- Wiring step 5 (refreshing `shownLive` at the lock) should shorten it. Re-measure after the wiring.

## The report

- Update the thresholds above so `tap_preview_report` exits 0 only when they all pass, and add it to CI.
- Log the threshold changes in D-071 and REVIEW_QUEUE.
