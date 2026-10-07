"""Clarity pass (D-064, horse-life stage 3): the new icons are in the atlas and uploaded, and the big
panels (race picker, Stable Board, My Horses) never ask for text under ui.panelMinText or buttons
under ui.panelButtonPx, so PanelFit's floor keeps them at 14 px text and 56 px buttons rendered."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CLIENT = ROOT / "game" / "src" / "client"
SHARED = ROOT / "game" / "src" / "shared"
PANELS = ["RacePicker.client.luau", "StableBoard.client.luau", "HorsesClient.client.luau"]
CLARITY_ICONS = ["energy_shoe", "energy_shoe_empty", "rosette", "sprout",
                 "badge_rookie", "badge_bronze", "badge_silver", "badge_gold", "badge_champion"]


def ui_config() -> dict[str, int]:
    text = (SHARED / "GameConfig.luau").read_text(encoding="utf-8")
    block = re.search(r"^GameConfig\.ui = \{(.*?)^\}", text, re.S | re.M)
    assert block
    return {k: int(v) for k, v in re.findall(r"(\w+) = (\d+)", block.group(1))}


def calls(src: str, name: str) -> list[list[str]]:
    """Top-level arguments of every `name(` call (strings and nested brackets respected)."""
    out = []
    for m in re.finditer(re.escape(name) + r"\(", src):
        i, depth, args, cur, quote = m.end(), 1, [], "", None
        while i < len(src) and depth:
            c = src[i]
            if quote:
                cur += c
                if c == "\\":
                    cur += src[i + 1]
                    i += 1
                elif c == quote:
                    quote = None
            elif c in "\"'`":
                quote, cur = c, cur + c
            elif c in "([{":
                depth, cur = depth + 1, cur + c
            elif c in ")]}":
                depth -= 1
                if depth:
                    cur += c
            elif c == "," and depth == 1:
                args.append(cur.strip())
                cur = ""
            else:
                cur += c
            i += 1
        args.append(cur.strip())
        out.append(args)
    return out


def size_ok(arg: str, floor: int, names: tuple[str, ...]) -> bool:
    if arg.isdigit():
        return int(arg) >= floor
    return any(n in arg for n in names)


def height_of(udim: str) -> str:
    m = re.match(r"UDim2\.fromOffset\((.*),\s*(.+)\)$", udim, re.S)
    if m:
        return m.group(2).strip()
    m = re.match(r"UDim2\.new\((.*),\s*(.*),\s*(.*),\s*(.+)\)$", udim, re.S)
    return m.group(4).strip() if m else udim


def test_clarity_icons_in_atlas_and_uploaded():
    atlas = json.loads((ROOT / "assets" / "ui" / "atlas" / "atlas.json").read_text())
    for name in CLARITY_ICONS:
        assert name in atlas, name
        assert atlas[name]["sheet"].startswith("ui_atlas_clarity_"), name
        assert (ROOT / "assets" / "ui" / f"{name}.svg").exists(), name
    images = (SHARED / "UiImages.luau").read_text()
    assert re.search(r"^\tui_atlas_clarity_1 = \d+,$", images, re.M), "the clarity sheet is uploaded"


def test_panel_floors_config():
    ui = ui_config()
    assert ui["panelMinText"] >= 16 and ui["panelButtonPx"] >= 64
    floor = min(1.0, max(ui["minTextPx"] / ui["panelMinText"], ui["minTouchPx"] / ui["panelButtonPx"]))
    assert floor * ui["panelMinText"] >= 14 and floor * ui["panelButtonPx"] >= 56


def test_panels_ask_for_no_small_text_or_buttons():
    ui = ui_config()
    for file in PANELS:
        src = (CLIENT / file).read_text(encoding="utf-8")
        assert "Ui.fitPanel(" in src, file
        for args in calls(src, "Ui.text"):
            assert size_ok(args[2], ui["panelMinText"], ("TEXT", "px", "math.floor")), f"{file}: Ui.text size {args[2]} ({args[1][:40]})"
        for args in calls(src, "Ui.button"):
            h = height_of(args[2])
            # The Next-thing pill's GO sits in the HUD (unscaled): the HUD floor applies there.
            assert size_ok(h, ui["panelButtonPx"], ("TAP", "minTouchPx")), f"{file}: Ui.button height {h} ({args[1][:40]})"
            if len(args) > 5:
                assert size_ok(args[5], ui["panelMinText"], ("TEXT",)), f"{file}: Ui.button text {args[5]} ({args[1][:40]})"
