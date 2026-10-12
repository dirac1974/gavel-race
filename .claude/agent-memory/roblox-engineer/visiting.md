# Visiting other stables (fun-and-return phase 5, D-079)

- The permission matrix lives in `shared/Visits.luau`: `Visits.may(setting, friend, action)` and `Visits.canVisit({ action = ... })`.
  Calling `canVisit` or `VisitAccess.check` with no action means "treat", the friends-only check. That keeps CareService's
  `VisitCare` friends-only without editing CareService. Every new caller must name its action (`enter`, `look`, `pat`, `cheer`, `treat`, `post`).
- Strangers' pats, cheers and tour stops go through `server/VisitService` (`VisitHello`), not `VisitCare`. The client's Pat prompt fires `VisitHello`.
- Strangers also need PolicyService read for both players (`VisitAccess.policyOk`, fail closed).
- The settings are Friends, Everyone and Nobody. An old "Club" stays saved and reads as Friends (`Visits.setting`).
  `settings.visitAsked` records the one-time ask.
- Tour stop positions are `GameConfig.visit.tourStops`, given as plot (inward, across) like StableService's `plotCF`.
  If the barn layout moves, update them; `visit_tests` checks that they stay inside every plot.
- `Guide.target()` lets a feature clear only its own trail.
- Review fixes:
  - PolicyService for strangers is `IsContentSharingAllowed == true` and `IsSubjectToChinaPolicies == false` (`VisitAccess.strangersAllowed`). It fails closed and retries once.
  - The server publishes the player attribute `VisitStrangersOk`, plus `AskedOutOf` and `AskedOutUntil` (Ask to leave). The shell `Visits` shows Friends while the owner can't host strangers.
  - Clients use `Visits.clientMay` on those values, so the walls and the server agree and there is no bounce loop.
  - The 4th tour stop is `Visits.stopsFor(hasLegend)`: paddock or garden. `Visits.pat` no longer awards pins.
