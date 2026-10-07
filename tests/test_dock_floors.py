"""Phone dock floors (D-064, horse-life stage 1): the config and the dock's own sizes keep every
dock button at 56 px or more and every label at 14 px or more, rendered, at the smallest scale."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SHARED = ROOT / "game" / "src" / "shared"
CLIENT = ROOT / "game" / "src" / "client"


def ui_config() -> dict[str, int]:
    text = (SHARED / "GameConfig.luau").read_text(encoding="utf-8")
    block = re.search(r"^GameConfig\.ui = \{(.*?)^\}", text, re.S | re.M)
    assert block, "GameConfig.ui is missing"
    return {k: int(v) for k, v in re.findall(r"(\w+) = (\d+)", block.group(1))}


def dock_sizes() -> dict[str, int]:
    text = (SHARED / "DockLayout.luau").read_text(encoding="utf-8")
    return {k: int(v) for k, v in re.findall(r"^DockLayout\.(\w+_PX) = (\d+)", text, re.M)}


def test_floor_constants():
    ui = ui_config()
    assert ui["minTouchPx"] >= 56
    assert ui["minTextPx"] >= 14
    assert ui["labelPx"] >= 16
    assert ui["dockPhoneItems"] == 3


def test_smallest_scale_keeps_the_floors():
    ui, px = ui_config(), dock_sizes()
    scale = min(1.0, max(ui["minTouchPx"] / min(px["BUTTON_PX"], px["LEAVE_PX"]), ui["minTextPx"] / px["LABEL_PX"]))
    assert scale * px["BUTTON_PX"] >= 56
    assert scale * px["LEAVE_PX"] >= 56
    assert scale * px["LABEL_PX"] >= 14


def test_hud_uses_the_floors():
    hud = (CLIENT / "Hud.client.luau").read_text(encoding="utf-8")
    assert "DockLayout.scale(" in hud, "fitDock must scale through DockLayout (the floors)"
    assert "math.clamp(room / width, if touch then 0.4" not in hud, "the old 0.4 touch floor is gone"
    assert "DockLayout.isPhone(" in hud, "phones get the 3-item dock"
