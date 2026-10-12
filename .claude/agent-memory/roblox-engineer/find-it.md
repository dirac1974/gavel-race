# Find it (fun-and-return phase 1, D-075)

- GO goes through `client/GoTo.luau`: `GoTo.place(place, openId?, {toast?})`. Each feature registers how it opens
  with `GoTo.register(id, fn)`. Place-to-feature mapping is `GoTo.OPENS`; the rules are in `shared/FindIt.goPlan`.
  A new feature panel needs a `register` call, plus a Map tile in `WorldLayout.MAP*` if it's a place.
- `WorldLayout.isTravelDest` gates the server's Travel. Barn Builder arrives at Feed & Seed via `MAP_ALIAS`.
  "visit" is a list, not a trip.
- The queue line is shown from the player attributes `LineKey` and `LineHorse`, which RaceService `markLine` sets.
- The test `test_clarity_floors` requires QueueCard to contain exactly one `:FireServer(`. Remote calls the card needs go in another module (HowRacing).
- StableBoard must keep exactly one `Ui.toast(` (clarity_tests). GoTo takes `{ toast = false }` so the board can toast itself.
- Profile "seen" flags are `flags.seen_<id>` booleans, saved through `SetSetting("seen", id)` and allowlisted by `FindIt.SEEN_IDS`.
- Lune can't run a long `run_all` here while the calibration holds memory. Use a throwaway runner that requires the chosen suites, then delete it.
- Bash heredocs choke on some Luau snippets. Write longer Python edit scripts to the scratchpad and run them from there.
