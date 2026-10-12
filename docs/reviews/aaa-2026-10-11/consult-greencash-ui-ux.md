# Green Cash consult: UI/UX (2026-10-11)

## My vote's required changes: all landed

| Change | Where |
| --- | --- |
| Distinct shop: green 💵 band, "🔨 Barn Builder", no 💎 | `BarnBuilder.client.luau:71-85` |
| Tack & Paint line | `StyleShop.client.luau:68` |
| Wish shown as icon plus fill bar (no %, no words), in the cash card and in the phone's ☰ More cell | `Hud.client.luau:107-132, 307-315` |
| Pill ranked below race-first, prizes, feed, brush and Cup; never on tour, in line, racing, on results or within 120 s; once per item | `Advice.luau:95-104, 134` |
| Next tier only, greyed, badge plus "Opens when a horse reaches Silver", no price | `:319-346` |
| Return in two taps, "You can return it until tomorrow", no clock | `:375-395` |
| New shelf note at a calm moment | `:550-566` |
| See it ▶ on the banner and on every owned card | — |
| Floors 16/64 via `fitPanel` | `:70` |
| `textGood` for cash text | — |

Layout:
- **667×375:** the panel renders 490 px wide at 0.875 and scrolls. Every row fits. The return row (x 12–320) clears its note (x 330+).
- **1024×768:** scale 1, no issues.

## MUST-FIX

1. **🎀 means the monthly stamps (D-064), but it's the "Hay bale with a bow" icon** (`BarnCatalog.luau:84`).
   - Once it's wished, the 🎀 sits on the dock cash card and reads as stamps.
   - Fix: use 🌾 (or 🧺).

## SHOULD-FIX

- **The header scrolls away on phones.** The band, balance and ✕ scroll with the shelves (one `fitPanel` column), so deep in the list the ✕ is gone; only the dim strips beside the column close it.
  - Pin the band and ✕ above a scrolling shelf frame, or add a second ✕ at the end of the list.
- **The build banner is out of sight on phones.** After "Yes, build", `builtBanner` (`:441`) goes to the top of the list. On a scrolled phone it's off-screen, so the "Go see it!" moment is lost.
  - Render the banner in place of the item card, or scroll the column to the top on build.
- **The New shelf toast has no GO** (`:564`). A kid may not know where Barn Builder is.
  - Make it a one-time pill: "New shelf at Barn Builder!" with GO and hoofprints to Feed & Seed, with the same gating.
- **The lock line repeats.** "Opens when a horse reaches Silver" is on the header and on every locked card (`:328, :343`). Keep it on the header and drop it from the cards.
- **Tack & Paint copy** (`StyleShop.client.luau:68`): "💎 looks. Barn Builder has 💵 things." Cloths are in both shops, so "looks vs things" doesn't hold up.
  - Suggest "💎 shop. Earned 💵 builds at Barn Builder!", plus "More cloths for 💵 at Barn Builder" in the Cloth tab.
- **Icon collisions.** The Hearts cloth is 💗, close to ❤️ = care. The Red horseshoe is 🔴, a red dot that reads as an alert (`BarnCatalog.luau:91, 99`). Use the swatch colour with a cloth glyph, and a 🧲-free horseshoe drawing on the atlas.
- **Names are clear** for an 8-year-old: Hearts, Daisy and Rainbow saddle cloth, Red horseshoe, Bunting wall frame, Hay bale with a bow. Check that "Starter shelf" vs the league "Rookie" doesn't confuse; "Rookie shelf" would match the badge.

## Sign-off

**Yes, once MUST-FIX 1 (a one-line icon change) is in.** No re-review needed.
