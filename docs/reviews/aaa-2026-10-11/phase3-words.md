# Phase 3 item 5: one meaning per word (D-068)

Roblox engineer, 2026-10-11. Scope: player-facing strings in `game/src` (toasts, labels, cards, the Grown-ups page). Internal ids, save keys (`h.rosettes`, `p.tour.stamps`, `book.rosettes`), icon names (`stamp_checkup`, `rosette`, `badge_<league>`, `ribbon_<colour>`) and art are unchanged, so no save migration is needed.

## "career star"

No player string ever said "career star". The 25-race award was a "career badge" (🎖️). It is now a **career patch** (★ means riding only, D-064, and "badge" stays with the leagues).

## What each word meant before this pass

| Word | Meanings found in player copy | Where |
| --- | --- | --- |
| **stamp** | 1. 🎀 monthly stamps from monthly jobs (8 earn the month's cloth) | StyleShop, StableBoard, Horse Book, Jobs |
| | 2. Health Passport stamps (vet check-ups and the Spa Day) | Training.luau toast, StableStar goal, Horse Book Passport page |
| | 3. Tour stamps (pat every horse in a friend's barn) | WorldClient Map, Horse Book Friends page, CareService and StableService toasts |
| **rosette** | 1. Rosettes on the Rosette Wall (Stable Star goals, first wins) | StableBoard, Progress toast |
| | 2. Goodbye rosettes (a tamed or gifted horse goes to the riding school) | RehomeClient, HorsesClient Hall of Fame, Grown-ups |
| | 3. The Horse Book "Rosettes" page (race places 1–3 and the four training golds) | HorseBook.luau, HorseBookClient tab |
| **badge** | 1. League badges (the league's icon on cards and the picker) | art only (`badge_<league>`), no word in copy |
| | 2. Class labels (First Win, Rising Star, Open class, Cup) | PickerText.classBadge: shown as labels, the word "badge" never appears |
| | 3. 🎖️ career badges, one every 25 races | Career.line, Career.badgeToast, Grown-ups |
| **ribbon** | 1. Race place ribbons (blue, red, yellow, white for 1st–4th) | ResultsText, FinishMoment, ResultsCard (Phase 2 files) |
| | 2. Training ribbons (Bronze, Silver, Gold for a training ride) | TrainingRideClient, Grown-ups (Ride together) |

## The mapping (one meaning each)

| Word | Its one meaning | Renamed in this pass | Status |
| --- | --- | --- | --- |
| **ribbon** | Race place prizes only (blue, red, yellow, white) | Training "Bronze/Silver/Gold ribbon" → **"Bronze/Silver/Gold medal"** (the emoji were already 🥉🥈🥇); Grown-ups "stars and ribbons" → "stars and medals" | Done |
| **medal** | Training ride results (new word) | (as above) | Done |
| **badge** | The league's badge (and class labels, which never say the word) | Career "badge(s)" → **"patch(es)"**: career row "🎖️ 2 patches", toast "earned a 25-race patch!", Grown-ups "earns a career patch" | Done |
| **patch** | The 25-race career award (new word) | (as above) | Done |
| **pin** | Tour pins from friends' barns (new word) | "Tour stamp(s)" → **"Tour pin(s)"** on the Map, the Horse Book Friends page ("📍 Pin") and the three visit toasts | Done |
| **stamp** | 🎀 monthly stamps and Health Passport stamps | none | Two meanings left (see below) |
| **rosette** | The Rosette Wall | none | Two meanings left (see below) |

## Deferred (not cheap, or not clearly better)

- **Passport stamps vs 🎀 monthly stamps.** "Passport stamp" is the real-world word and reads well; the 🎀 monthly stamps are the odd one (the emoji is a bow). Renaming them touches Jobs rewards, StyleShop, StableBoard, the Horse Book and D-064's icon table. Suggestion for after the playtest: 🎀 **bows** for the monthly set, or Passport **stickers** as the systems review proposed. Needs a design call.
- **Goodbye rosettes.** They are a keepsake award like the Wall's, so the meaning is close. Renaming means new copy on the goodbye card and the Grown-ups rehoming text. Suggestion: hang goodbye rosettes on the Wall so "rosette = the Wall" holds, rather than renaming.
- **The Horse Book "Rosettes" page** lists race places and training golds. After this pass those are ribbons and medals, so the page could be called "Prizes". Not done: HorseBook tests pin the page id and entries, and the page title is shared with the Phase 2 results work.
- No new rosette types were added (CONSENSUS cross-cutting rule).

## Copy rules kept

Every changed toast stays at 10 words or fewer (`ui.toastMaxWords`); no banned words; ★ still means riding only. Checked by `tests/luau/copy_tests.luau`, `career_tests.luau` and `bash scripts/policy_guard.sh`.
