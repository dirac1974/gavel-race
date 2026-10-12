# Discoverability inventory (2026-10-12)

Paths are relative to `game/src/`.

## Headline findings

**Most places can only be found by walking.** Most meta features are reached by walking to a ProximityPrompt at a building.
- The Map has only 6 tiles: My Stable, Racetrack, Fair Street, Vet, Trail and Friends' barns (`shared/WorldLayout.luau:132`, `client/WorldClient.client.luau:141`).
- **Not on the Map:** Training Paddock, Training Ground, Market Corral, Feed & Seed / Barn Builder, and Tack & Paint (`WorldLayout.luau:74-85`).

**Pointers never open anything.** Tour, Advice and job GO buttons only draw golden hoofprints (`client/Guide.luau`, `StableBoard.client.luau:112-129`). None of them opens a feature.

**Rookie races cost no Energy** (`GameConfig.luau:623`, `RaceService:355`). So a new player never sees napping or the Spa.

**Dock** (`client/Hud.client.luau`):
- **PC:** cash card (with the 💎 button and the wish bar), horse card (Energy horseshoes, Ready/Napping), 📋 Jobs, 🗺️ Map and 📖 Book, 🏁 RACE!, 🐴 Ride.
  - Map and Book share LayoutOrder 4, so their order is undefined.
- **Phone:** the dock shows the horse card, RACE! and ☰ More.
  - ☰ More holds Cash, Horses, Jobs, Map, Ride and Book, so each is 2 taps away.
  - 💎 moves to a top-right pill, with ⚙️ under it.

**Tour** (`shared/Tour.luau:13-21`): race → feed → groom → plant → board. It points at nothing else.

**Advice order** (`Advice.nextThing`):
1. starter
2. race first, until 3 races
3. job prize to claim
4. feed
5. groom
6. Cup
7. Barn Builder pill
8. daily job
9. train
10. race
11. Spa (napping)
12. crops
13. "Great day!"

**Advice never points to:** Market, rehome, Legend, Tack & Paint, visits, Horse Book, Photo, Gymkhana by name, Fans.

## Features

| Feature | Decision | How a player reaches it | Pointed to by | Status |
|---|---|---|---|---|
| Care and food | D-038 | "Care" prompt at the stall; Feed & Seed (not on the Map) | Tour 2–4, Advice, jobs | Built |
| Energy and napping | D-015, D-058 | Horse card. A tired horse's RACE! becomes 🎈 PRACTICE. | Invisible in Rookie (free) | Built |
| Spa Day | D-058 | Map → Vet → "Spa Day" prompt | Advice only while napping; `d_spa` | Built |
| Vet check-up | D-039 | Map → Vet → "Check-up" | `d_vet` | Built |
| Training rides | D-040, D-053 | "Train" prompt at the paddock (not on the Map); Ride together is inside the Train menu | Advice "train" (hoofprints) | Built |
| Gymkhana (Mud Splash) | D-053 | Train menu "This week's course" | Never named | Built |
| RACE! and queue card | D-061 | Dock RACE!. One queue per league and kind (race / cup / practice); "Bots join at 0" after 15 s. ✕ leaves; "🔀 More" opens the picker. | Tour 1, Advice | Built |
| RacePicker | D-036, D-061 | Only via queue card → More (you must already be in line), or the Race Board prompt | Never | Built |
| Open Practice / Race with a friend | D-068 | Picker → Practice / 👫 Friends | Never | Built |
| Leagues and Cups | D-046, D-048 | RACE! turns into 🏆 CUP!; picker Cup 🔒 | Advice Cup | Built |
| Class badges | D-062 | Label text on the horse card and the picker | Never | Label only |
| League Points | D-013, D-062 | **No UI at all** | Never | Invisible |
| Careers and Legend | D-059, D-068 | My Horses → 👑 Legend (after 100 races); Hall of Fame button | Never; `career.suggest = false` | Built |
| Rehoming | D-059 | Market Corral sign (not on the Map) | Never | Built |
| Market Corral (buy horses) | D-037 | Walk to the corral → "For sale" | **Never: no Map tile, job, Advice or tour step** | Built |
| Wild horses | D-037 | Map → Trail → meadow → "Make friends" | `m_tame`, `d_trail` | Built |
| Visiting friends' barns | D-060 | Map → Friends' barns → face → Visit (3 taps). Empty unless a Roblox friend is in the server. | Never | Built |
| Rosette Wall | D-062 | In your barn; Jobs → Goals → GO | Never | Built |
| Stable Star goals | D-062 | Jobs → 🏵️ Goals (cards have no GO) | Never | Built |
| Horse Book | D-063 | 📖 Book (☰ More on a phone) | Never | Built |
| Welcome Back hay | D-063 | Automatic after 3+ days away | n/a | Built |
| Monthly stamps | D-063 | Jobs → 🎀 Month | Never | Built |
| Photo Finish | D-063 | 📷 on the results card **only on a win**; yard photo board | Never | Built |
| Personal bests | D-063 | Automatic pill; Book → Bests | n/a | Built |
| Stable Board jobs | D-043 | 📋 Jobs | Tour 5, Advice | Built |
| Tack & Paint (💎) | D-050 | 💎 button; shop building (not on the Map) | Never (by design) | Built |
| Barn Builder (💵) | D-070 | Feed & Seed counter (not on the Map); wish bar | Build pills | Built |
| Fans and cheering | D-019/20/41 | Stand near a running race; Map → Racetrack or picker 👀 Watch | Jobs | Built |
| Replays, Minimap | D-034, D-030 | Results card; automatic | n/a | Built |
| Grown-ups and settings | D-045, D-049 | ⚙️ at the top right | Never | Built |

## Off or not built
- **Hurdles (D-073):** only `fixedLanes` exists.
- **Config switches that are off:**
  - `career.suggest = false`;
  - `spa.muddyLook = false`;
  - `audio.music.id = 0` (no music);
  - `results.tripRow = false`;
  - `training.enforceFloor = false`.
- **`corePlaytest`:** if true, it turns off the Spa, visits, careers, rehome, Photo and the Book.
- **Breeding (D-047):** "later", not built.
- **Ageing:** none (D-059 says no ageing).
- **Injury:** none (D-058).
- **Visiting:** friends only (D-060).
