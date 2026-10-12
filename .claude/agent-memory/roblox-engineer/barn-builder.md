---
name: barn-builder
description: Where the Green Cash sink (D-070, Barn Builder) lives and the gotchas met building it
type: reference
---
- Catalog: `game/src/shared/BarnCatalog.luau` (ids `bb_*`, tier = league, 💵 price, slot, spot). Style appends it to `Style.ITEMS` with `currency = "cash"`; `Style.shopItems("tack"|"barn")` keeps the shops apart. `sims/economy.py luau_cash_prices` reads tier/price by regex: keep `tier = "X", price = N,` adjacent.
- Style can't require Profile at load (Profile -> HorseBook -> Style cycle). The high-water mark is `Profile.syncBestLeague` (Profile owns it); StyleService's decorator syncs it every view.
- world_tests' shop sanity bans names with lucky/coat/"horse "/cash/energy/speed/trophy/rosette/reroll; greencash_tests also bans ribbon/cup/random/sale/deal/limited.
- Clarity lint: a file calling `Ui.fitPanel(..., 16, 64)` must keep every Ui.text >= 16 and Ui.button side >= 64. Ui.icon is not linted.
- Build moment is client-local: `BuildFx.hide` (LocalTransparencyModifier), `holdPaint`/`sweep` on parts tagged `Paint`; barn rebuilds make new instances, so re-hide on `DescendantAdded`.
- Whole-image Decals: add to `make_ui_svgs.py STRIP_NAMES`, `upload_assets.py TEXTURES`, `WorldArt.NAMES`, and `tests/test_ui_assets.py` texture sets; upload with `--only <name> --kind Decal`.
