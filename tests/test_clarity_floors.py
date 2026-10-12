"""Clarity pass (D-064, horse-life stage 3; AAA Phase 2, D-067): the new icons are in the atlas and
uploaded, and no client screen asks for a button under ui.minTouchPx (56 px) or text under
ui.minTextPx (14 px). Panels that shrink on small screens go through Ui.fitPanel, whose floor is
computed from the smallest text and button the panel declares, so the rendered sizes stay at the
floors; this lint checks every literal size in client code against those declarations."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CLIENT = ROOT / "game" / "src" / "client"
SHARED = ROOT / "game" / "src" / "shared"
PANELS = ["RacePicker.client.luau", "StableBoard.client.luau", "HorsesClient.client.luau", "RehomeClient.client.luau"]
CLARITY_ICONS = ["energy_shoe", "energy_shoe_empty", "rosette", "sprout",
                 "badge_rookie", "badge_bronze", "badge_silver", "badge_gold", "badge_champion"]

# Every client file is linted. The race screen (RaceController, RaceView, Replay) joined after the
# results card rebuild (AAA Phase 2 item 2, D-067): the card lives in ResultsCard.luau at 16 px / 64 px
# unscaled, and RaceController's own `label(parent, size, pos, text, textSize)` helper is scanned
# below too (votes-systems C29).
EXCLUDED: set[str] = set()

# (file, exact code snippet) -> why it may stay under the floor. Only for things that are not a
# tap target or not text a child needs to read; never for a fixable button or label.
ALLOW = {
    ("Ui.luau", 'Ui.button(parent, "✕"'): "the definition of Ui.closeButton itself",
}

# Panels with their own phone layout: on a phone (or any screen under 820 × 600) they fill the
# screen at full size with one column; on bigger screens they fit at full size. Never shrunk.
FULL_SCREEN_PANELS = ["StyleShop.client.luau", "HorseBookClient.client.luau"]


def ui_config() -> dict[str, int]:
    text = (SHARED / "GameConfig.luau").read_text(encoding="utf-8")
    block = re.search(r"^GameConfig\.ui = \{(.*?)^\}", text, re.S | re.M)
    assert block
    return {k: int(v) for k, v in re.findall(r"(\w+) = (\d+)", block.group(1))}


def strip_comments(src: str) -> str:
    """Code without its comments (a `--` outside a string starts one)."""
    out = []
    for line in src.split("\n"):
        quote, cut, i = None, len(line), 0
        while i < len(line):
            c = line[i]
            if quote:
                if c == "\\":
                    i += 1
                elif c == quote:
                    quote = None
            elif c in "\"'`":
                quote = c
            elif line.startswith("--", i):
                cut = i
                break
            i += 1
        out.append(line[:cut])
    return "\n".join(out)


def calls(src: str, name: str) -> list[list[str]]:
    """Top-level arguments of every `name(` call (strings and nested brackets respected)."""
    out = []
    for m in re.finditer(r"(?<![\w.])" + re.escape(name) + r"\(", src):
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


def offsets(udim: str) -> list[int]:
    """The literal pixel sides of a UDim2 that are fixed (no scale part): a button's width and height."""
    m = re.match(r"UDim2\.fromOffset\(\s*(\d+)\s*,\s*(\d+)\s*\)$", udim)
    if m:
        return [int(m.group(1)), int(m.group(2))]
    m = re.match(r"UDim2\.new\(\s*([\d.]+)\s*,\s*(-?\d+)\s*,\s*([\d.]+)\s*,\s*(-?\d+)\s*\)$", udim)
    if not m:
        return []
    out = []
    if float(m.group(1)) == 0:
        out.append(int(m.group(2)))
    if float(m.group(3)) == 0:
        out.append(int(m.group(4)))
    return out


def client_files() -> list[Path]:
    return sorted(p for p in CLIENT.glob("*.luau") if p.name not in EXCLUDED)


def panel_floors(src: str, ui: dict[str, int]) -> tuple[int, int] | None:
    """The smallest text and button a file's fitPanel panels declare (defaults: panelMinText, panelButtonPx)."""
    fits = calls(src, "Ui.fitPanel")
    if not fits:
        return None
    text, button = 10**6, 10**6
    for args in fits:
        t = args[4] if len(args) > 4 and args[4].isdigit() else str(ui["panelMinText"])
        b = args[5] if len(args) > 5 and args[5].isdigit() else str(ui["panelButtonPx"])
        text, button = min(text, int(t)), min(button, int(b))
    return text, button


def lint(path: Path, ui: dict[str, int]) -> list[str]:
    src = strip_comments(path.read_text(encoding="utf-8"))
    name = path.name
    text_floor, button_floor = ui["minTextPx"], ui["minTouchPx"]
    panel = panel_floors(src, ui)
    if panel:  # a shrinking panel: its declared floors keep the rendered sizes at 14 / 56
        text_floor, button_floor = max(text_floor, panel[0]), max(button_floor, panel[1])
    bad = []

    def allowed(snippet: str) -> bool:
        return any(f == name and s in snippet for (f, s) in ALLOW)

    for args in calls(src, "Ui.text"):
        snippet = "Ui.text(" + ", ".join(args) + ")"
        if len(args) > 2 and args[2].isdigit() and int(args[2]) < text_floor and not allowed(snippet):
            bad.append(f"{name}: Ui.text {args[2]} px < {text_floor} ({args[1][:40]})")
    for m in re.finditer(r"TextSize\s*=\s*(\d+)\b", src):
        if int(m.group(1)) < ui["minTextPx"]:
            bad.append(f"{name}: TextSize = {m.group(1)} < {ui['minTextPx']}")
    for fn, size_arg, text_arg in (("Ui.button", 2, 5), ("Ui.iconButton", 4, None)):
        for args in calls(src, fn):
            if len(args) <= size_arg:
                continue
            for px in offsets(args[size_arg]):
                if px < button_floor:
                    bad.append(f"{name}: {fn} side {px} px < {button_floor} ({args[1][:40]})")
            if text_arg is not None and len(args) > text_arg and args[text_arg].isdigit() and int(args[text_arg]) < text_floor:
                bad.append(f"{name}: {fn} text {args[text_arg]} px < {text_floor} ({args[1][:40]})")
    # Raw buttons: `local b = Instance.new("TextButton")` then `b.Size = UDim2...`.
    for m in re.finditer(r'local\s+(\w+)\s*=\s*Instance\.new\("(?:TextButton|ImageButton)"\)', src):
        var = m.group(1)
        for s in re.finditer(re.escape(var) + r"\.Size\s*=\s*(UDim2\.[^\n]+)", src[m.end():]):
            udim = s.group(1).strip()
            for px in offsets(udim):
                if px < ui["minTouchPx"]:
                    bad.append(f"{name}: {var} (a button) side {px} px < {ui['minTouchPx']}")
    # RaceController's own text helper: label(parent, size, pos, text, textSize).
    if name == "RaceController.client.luau":
        for args in calls(src, "label"):
            if len(args) > 4 and args[4].isdigit() and int(args[4]) < ui["minTextPx"]:
                bad.append(f"{name}: label {args[4]} px < {ui['minTextPx']} ({args[3][:40]})")
    # A panel that shrinks by itself, with no floor, can put any of the above under the floors.
    if re.search(r"\.Scale\s*=\s*math\.min\(\s*1\s*,", src):
        bad.append(f"{name}: shrinks a panel with math.min(1, ...) and no floor (use Ui.fitPanel)")
    # One close button everywhere.
    for args in calls(src, "Ui.button"):
        if len(args) > 1 and args[1] in ('"✕"', '"✕ Close"') and not allowed("Ui.button(" + ", ".join(args) + ")"):
            bad.append(f"{name}: a hand-made ✕ (use Ui.closeButton)")
    return bad


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
    assert ui["closePx"] >= ui["minTouchPx"]


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


def test_no_client_button_under_56_or_text_under_14():
    ui = ui_config()
    bad = []
    for path in client_files():
        bad += lint(path, ui)
    assert not bad, "\n".join(bad)


def test_every_panel_fits_and_closes_the_same_way():
    # The panels the AAA review named (P6), plus the Starter, the first screen anyone sees.
    for file in ["Starter.client.luau", "CareClient.client.luau", "PaddockClient.client.luau",
                 "GrownUps.client.luau", "WildHorses.client.luau", "TrainingRideClient.client.luau",
                 "WorldClient.client.luau"] + PANELS:
        src = strip_comments((CLIENT / file).read_text(encoding="utf-8"))
        assert "Ui.fitPanel(" in src, f"{file}: goes through Ui.fitPanel"
        # (the Starter must be finished, and a training ride's card closes with Done or Ride again)
        no_close = ("Starter.client.luau", "TrainingRideClient.client.luau")
        assert "Ui.closeButton(" in src or file in no_close, f"{file}: closes with Ui.closeButton"
    for file in FULL_SCREEN_PANELS:
        src = strip_comments((CLIENT / file).read_text(encoding="utf-8"))
        assert re.findall(r"(?<![\w.])scale\.Scale\s*=\s*([^\n]+)", src) == ["1", "1"], f"{file}: never shrunk"
        assert "Ui.closeButton(" in src, file
    ui_src = (CLIENT / "Ui.luau").read_text(encoding="utf-8")
    assert "function Ui.closeButton(" in ui_src and "GameConfig.ui.closePx" in ui_src


def test_phone_queue_card_and_first_minute_config():
    text = (SHARED / "GameConfig.luau").read_text(encoding="utf-8")
    qc = re.search(r"^GameConfig\.queueCard = \{(.*?)\}\n", text, re.S | re.M).group(1)
    assert "compactPhone = true" in qc and "compactHeight = 64" in qc and "warmUpRaces = 3" in qc
    fm = re.search(r"^GameConfig\.firstMinute = \{(.*?)^\}", text, re.S | re.M).group(1)
    for key in ("tourOwnsScreen = true", "tourGoOnRace = false", "pulseRace = true", "skipConfirm = true", "hideGemPill = true"):
        assert key in fm, key
    slot = re.search(r"^GameConfig\.topSlot = \{(.*?)\}", text, re.M).group(1)
    pri = {k: int(v) for k, v in re.findall(r"(\w+) = (\d+)", slot)}
    assert pri["raceTime"] > pri["tour"] > pri["queueCard"], "Race time! > tour > queue card > toasts"
    card = strip_comments((CLIENT / "QueueCard.client.luau").read_text(encoding="utf-8"))
    # the warm-up never talks to the server: the only remote call on the card is leaving the line
    assert card.count(":FireServer(") == 1 and 'JoinRace"):FireServer(false)' in card
    assert 'Ui.slot("queueCard"' in card and "QueueView.compactLine(v)" in card
    grown = strip_comments((CLIENT / "GrownUps.client.luau").read_text(encoding="utf-8"))
    assert 'Ui.slot("tour"' in grown and "Ui.holdToasts(" in grown
    # Skip sits at the far end of the tour card from GO
    assert "Ui.closeButton(tourCard, UDim2.new(0, 10," in grown and 'UDim2.new(1, -122, 0.5, -BTN / 2)' in grown


def test_lint_catches_small_things(tmp_path):
    ui = ui_config()
    f = tmp_path / "Bad.client.luau"
    f.write_text('local a = Ui.button(p, "Go", UDim2.fromOffset(84, 44), UDim2.new(), C.orange, 18)\n'
                 'local b = Ui.text(p, "hi", 12)\n'
                 'local c = Instance.new("TextButton")\nc.Size = UDim2.new(1, 0, 0, 40)\n'
                 'l.TextSize = 11\nscale.Scale = math.min(1, v.X / 500)\n'
                 'local d = Ui.button(p, "✕", UDim2.fromOffset(64, 64), UDim2.new())\n'
                 'local ok = Ui.button(p, "Fine", UDim2.new(1, -20, 0, 64), UDim2.new(), C.orange, 18) -- Ui.text(p, "x", 9)\n',
                 encoding="utf-8")
    bad = lint(f, ui)
    assert len(bad) == 6, bad
