"""Green Cash sink (D-070, provisional): the game's Barn Builder shelf (game/src/shared/BarnCatalog.luau) parses
the way the economy sim reads it (sims/economy.py luau_cash_prices; tests/test_sims.py checks the prices tier by
tier), with a name for every price. Ids and names may differ from the sim's (the game renamed a few so no 💵 thing
looks like a 💎 one or a race prize); tiers and prices may not. The weathervane's silhouette Decal is a whole
image, not atlased."""
import re
import struct
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "sims"))
import economy  # noqa: E402

ITEM = re.compile(r'\{ id = "(bb_\w+)", name = "([^"]+)", tier = "(\w+)", price = (\d+),')


def game_catalog() -> list[tuple[str, str, str, int]]:
    text = (ROOT / "game" / "src" / "shared" / "BarnCatalog.luau").read_text(encoding="utf-8")
    return [(i, n, t, int(p)) for i, n, t, p in ITEM.findall(text)]


def by_tier(rows) -> dict[str, list[int]]:
    out: dict[str, list[int]] = defaultdict(list)
    for row in rows:
        out[row[2]].append(row[3])
    return {t: sorted(v) for t, v in out.items()}


def test_game_catalog_parses():
    rows = game_catalog()
    assert len(rows) >= 30
    assert len({r[0] for r in rows}) == len(rows)


def test_every_price_the_sim_reads_belongs_to_a_named_item():
    assert by_tier(game_catalog()) == economy.luau_cash_prices()


def test_horse_silhouette_is_a_whole_image():
    png = ROOT / "assets" / "ui" / "png" / "horse_silhouette.png"
    with png.open("rb") as f:
        head = f.read(24)
    w, h = struct.unpack(">II", head[16:24])
    assert w <= 1024 and h <= 1024
    atlas = (ROOT / "assets" / "ui" / "atlas" / "atlas.json").read_text(encoding="utf-8")
    assert "horse_silhouette" not in atlas
    assert "horse_silhouette = " in (ROOT / "game" / "src" / "shared" / "UiImages.luau").read_text(encoding="utf-8")
