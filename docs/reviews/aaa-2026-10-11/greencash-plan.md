# Green Cash plan (launch gate, D-070 provisional)

Owner: systems designer. Branch `claude/green-cash-and-taps`.

**Problem.** A casual kid earns about 106k Green Cash by week 12 (D-068 ladder), but only stalls (7,100), horses and feed cost anything. Casual cash per race is about 1.5 × B in every league.

**Goals:**
- The next thing a kid wants is affordable every 1–2 sessions.
- Feed is always affordable.
- No pile of unspent cash builds up before Champion.
- Prestige comes from what you earn, never from Diamonds.

## 1. Sink catalog: "Barn Builder" (💵 only)

**Where.** A new counter at Feed & Seed.
- Tack & Paint stays 💎 only and Barn Builder is 💵 only, so each shop has one currency.
- No item is ever sold for both currencies.

**What.** Every item is cosmetic and never touches stats, Rating, Energy or win chance.

**Tiers.** Tiers unlock by `p.bestLeague`, the highest league any of your horses has ever reached. It never goes down, and Legends count. Visitors see the barn and the yard, so a Gold item says "this stable made Gold" with no number and no ranking.

| Tier | Items (💵) | Asset |
| --- | --- | --- |
| Starter | 4 barn paints 300–450, 3 saddle cloths 300–400, wood plates 350, hay bale 250, feed bucket 200, water trough 400, wheelbarrow 450 | colours; existing models |
| Bronze | 2 apple trees 700, horseshoe over the door 600, 3 helmet colours 500, 3 cloth patterns 600, stall-door paint 800 | existing `apple_tree_small`, `horseshoe_decor`; colours |
| Silver | yard log jump to hop on your horse 1,500, silver Rosette Wall frame 1,200, fence paint 1,000, "Silver Birch" barn 1,200, photo board 1,400 | existing `log_jump`, `photo_frame_stand`; tints |
| Gold | gold-trim barn 2,000, gold wall frame 2,500, small hay barn in the yard 3,500, brass plates 1,800 | existing `training_shed` (scaled); colours |
| Champion | **weathervane** 5,000, Champion paint 4,000, grand gate arch 6,000, Champion wall frame 4,000 | **new `weathervane`**; existing `trail_gate_arch` |

- About 45k in all, plus stalls and horses: it absorbs the roughly 27k earned before Champion.
- **Never sold for 💵:** trophies, rosettes, Cups or anything that looks like a real win (D-050), coats, stats, Energy, or anything random.

**Meshy (cap 37):**
1. `weathervane`, text-to-3D, 30 credits. A county-fair horse weathervane, readable from Barn Lane.
2. Keep the other 7 credits.

## 2. Flatten purses

- **Proposal:** `leagues[*].B` changes from 20/50/120/300/750 to **20/30/45/60/80**. `cupPurseB` stays 3.
- **Casual cash per race:** about 31 / 47 / 70 / 92 / 121, so about 310–1,210 per 10-race session, which matches the tier prices.
- **Skill premium kept:** a perfect rider still earns about 1.5× per race. B only sets purses.
- **Merge only if the sim shows all of these:**
  - a casual kid's median gap between newly affordable items is ≤ 2 sessions in every league up to Gold;
  - the unspent balance at week 12 is ≤ 2× the next unowned item's price;
  - hay and seeds are always affordable.

## 3. Hard rules

- Green Cash is never sold. No paid multipliers, and no exchange with Diamonds in either direction.
- No random items, no rotating stock, no timers, and no "limited", "sale" or "deal". Every tier stays available.
- No entry fees.
- No buy suggestion while in line, while racing, on the results card, or within 120 s of a race (`DiamondProducts.afterRaceSeconds`). This applies to 💵 too.
- A 💵 item can be returned within 24 h for all of its cash.
- **Keeping the two currencies apart:**
  - Each price shows its own icon, 💵 or 💎.
  - Tack & Paint gets one line: "💎 looks. Barn Builder has 💵 things."
  - Diamond items are never league-gated and never prestige, so a paying kid's barn never outranks an earned one.

## 4. UI: "what can I buy next"

- **Wish.** Tap "💭 Wish" on one Barn Builder item. The dock's cash card then shows "💵 1,240 · 💭 Red Barn Door 70%". It has no button and never appears on the results card.
- **Next-thing pill.** When the wish is affordable, the pill says "You can build the Red Barn Door!" with GO, which shows hoofprints to Feed & Seed. It shows once per item and never within 120 s of a race.

## 5. Implementation split

**Economy analyst:**
- Add `sims/economy.py --greencash`: run each ladder profile's cash against the catalog, read from `Style.luau` by regex.
  - Report item gaps, balances at weeks 4/8/12, and the skill premium.
- Choose B. Update `GameConfig.leagues[*].B`, `LEAGUE_B`, and any parity fixtures that embed B.
- Tests: the gap band, the pile cap, a premium of at least 1.33×, and B matching between Luau and Python.

**Roblox engineer:**
- **`Style.luau`:**
  - add `currency` (`"cash"` or `"diamonds"`, default diamonds) and `tier` to items;
  - add `Style.buyCash`, which spends through `Profile.spendCash` and checks the tier against `Profile.bestLeague`, a high-water mark set on promotion;
  - a return refunds the currency that was paid;
  - add `p.style.wish`.
- **`StyleService`:** a `BuyCash` remote with server-side checks for tier, cash and the race window.
- **`StyleShop`:** a Barn Builder mode, opened from a Feed & Seed prompt.
- **`StableService`:** new `YARD_SPOTS`, wall-frame tints, and the roof weathervane.
- **`Hud`:** the wish chip.
- **`Advice`:** the "You can build" line.
- **Config:** `GameConfig.greenCash = { enabled = true, wishChip = true, pillAfterRaceSeconds = 120, returnHours = 24 }`. `enabled = false` hides Barn Builder.
- **Lune tests:**
  - a cash item refuses Diamonds, and a Diamond item refuses cash;
  - no item has both prices;
  - no 💵 item is a trophy, rosette, Cup or random item;
  - tier gating uses the high-water mark;
  - a return works within 24 h and not after;
  - every yard item has a spot;
  - no suggestion appears inside the race window.

**Acceptance (PLAYTEST "Green Cash"):**
- A fresh Rookie can afford an item within 1–2 sessions.
- Each new league shows a new shelf.
- A visiting friend sees the weathervane.
- The sim bands pass and `policy_guard` passes.
- D-070 is logged and added to REVIEW_QUEUE.

## Final prices (sim)

Economy analyst, 2026-10-11, after `python sims/economy.py --greencash` (results: `greencash-sim.md`). This list replaces the table in section 1 and applies the feel vote. Items the yard already has for free (hay bale, water trough, feed bucket, wheelbarrow, horseshoe, photo board; `StableService.server.luau` 510–591) are sold only as variants. The Gold tier uses fair materials. There's no `training_shed` hay barn, and the weathervane is built in code (0 Meshy credits). Tier = the league that opens the shelf (`p.bestLeague`). All prices are 💵 only.

**Purses:** `leagues[*].B` = **20 / 30 / 45 / 65 / 85** (Rookie → Champion). That is the plan's 20/30/45/60/80 with Gold and Champion raised by 5, because the plan's values put the casual Gold wait at exactly the 2-session limit. `cupPurseB` stays 3. There are no entry fees.

| Tier | id (shipped) | Item | 💵 |
| --- | --- | --- | --- |
| Rookie | `bb_paint_cherry` | 🍒 Cherry barn paint | 300 |
| Rookie | `bb_paint_sky` | 🩵 Sky barn paint | 350 |
| Rookie | `bb_paint_mint` | 🌱 Mint barn paint | 400 |
| Rookie | `bb_paint_sunny` | 🌻 Sunny barn paint | 450 |
| Rookie | `bb_cloth_sun` | 🟨 Sunny saddle cloth | 300 |
| Rookie | `bb_cloth_sky` | 🟦 Sky saddle cloth | 350 |
| Rookie | `bb_cloth_berry` | 🫐 Berry saddle cloth | 400 |
| Rookie | `bb_plates_wood` | 🪵 Carved wood name plates | 350 |
| Rookie | `bb_trough_painted` | 💧 Painted water trough | 300 |
| Rookie | `bb_barrow_flowers` | 🌷 Flower-box wheelbarrow | 400 |
| Rookie | `bb_bucket_painted` | 🪣 Painted feed bucket | 250 |
| Rookie | `bb_hay_bow` | 🌾 Hay bale with a bow | 250 |
| Bronze | `bb_apple_tree_1` | 🍎 Apple tree | 700 |
| Bronze | `bb_apple_tree_2` | 🍏 Second apple tree | 700 |
| Bronze | `bb_horseshoe_red` | 🐴 Red horseshoe | 600 |
| Bronze | `bb_helmet_orange` | 🟠 Orange helmet | 500 |
| Bronze | `bb_helmet_sky` | 🔵 Sky helmet | 500 |
| Bronze | `bb_helmet_grass` | 🟢 Grass helmet | 500 |
| Bronze | `bb_cloth_hearts` | 🧵 Hearts saddle cloth | 600 |
| Bronze | `bb_cloth_daisy` | 🌼 Daisy saddle cloth | 600 |
| Bronze | `bb_cloth_rainbow` | 🌈 Rainbow saddle cloth | 600 |
| Bronze | `bb_stall_doors` | 🚪 Stall-door paint | 800 |
| Silver | `bb_log_jump` | 🪵 Yard log jump | 1,500 |
| Silver | `bb_frame_silver` | 🖼️ Silver wall frame | 1,200 |
| Silver | `bb_fence_paint` | 🎨 Sky fence paint | 1,000 |
| Silver | `bb_paint_birch` | 🌳 Silver Birch barn | 1,200 |
| Silver | `bb_photo_flowers` | 🌸 Flower photo board | 1,400 |
| Gold | `bb_trim_gold` | 🟡 Gold-painted barn trim | 2,000 |
| Gold | `bb_frame_bunting` | 🎪 Bunting wall frame | 2,500 |
| Gold | `bb_hayloft` | 🪜 Hay-loft doors and sign | 3,500 |
| Gold | `bb_bunting` | 🎏 County-fair bunting | 1,800 |
| Champion | `bb_weathervane` | 🧭 Weathervane | 5,000 |
| Champion | `bb_paint_champion` | 👑 Champion barn paint | 4,000 |
| Champion | `bb_gate_arch` | 🏛️ Grand gate arch | 6,000 |
| Champion | `bb_frame_champion` | 🖼️ Champion wall frame | 4,000 |

Ids and names above are what ships in `game/src/shared/BarnCatalog.luau` (updated after the code review). The sim (`sims/economy.py` CATALOG) keeps its own ids; tiers and prices match item for item (`test_greencash_barn_catalog_matches_sim_catalog`). Renamed so no 💵 thing looks like a 💎 look or a race prize: no "Lucky", "Rosette" or "ribbon" names, the 💵 cloths are Hearts / Daisy / Rainbow (💎 already sells Stars and Checks), and the 💵 helmets are Orange / Sky / Grass (the free helmet is red). Shelves are labelled by league ("Rookie shelf").

**Totals by tier:**

| Tier | 💵 |
| --- | --- |
| Starter | 4,100 |
| Bronze | 6,100 |
| Silver | 6,300 |
| Gold | 9,800 |
| Champion | 19,000 |
| **All** | **45,300** |

Stalls (`Market.STALL_PRICES`, unchanged: 300 / 800 / 2,000 / 4,000) add 7,100.

`sims/economy.py` holds this list as `CATALOG`. `test_greencash_barn_catalog_matches_sim_catalog` checks that `game/src/shared/BarnCatalog.luau` matches this list, tier by tier and price by price. It is a strict xfail until that module exists.
