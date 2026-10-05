# Draft P0 race UI art as SVG (assets/ui/<name>.svg) plus a review sheet (assets/ui/_sheet.svg).
# Style: docs/art/ART_DIRECTION.md. Chunky shapes, ink outline painted under the fill, every state = shape + colour.
# Numbers and words are drawn by Roblox TextLabels in game; the <text> here is only for review.
#   python tools/ui/make_ui_svgs.py
from __future__ import annotations

import math
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
OUT = REPO / "assets" / "ui"

INK = "#1D2433"
WHITE = "#FFFFFF"
PAPER = "#FFF7E6"
ORANGE = "#FF9F1C"
ORANGE_DARK = "#D97A00"
ORANGE_PRESSED = "#F28C00"
GOLD = "#FFD23F"
GOLD_LIGHT = "#FFE98A"
SLATE = "#2A3247"
TEAL = "#17A398"
PLUM = "#7D6B91"
FONT = "Fredoka One, Arial Rounded MT Bold, Arial Black, Arial, sans-serif"

FEEDBACK = {  # label: colour (shape is in the drawing)
    "perfect": GOLD,
    "great": "#4CC3FF",
    "good": "#3CC46A",
    "okay": "#CBB89D",
    "miss": "#9A8FB0",
    "steady": "#F2A65A",
}

LANES: list[tuple[str, str, bool]] = [  # (hex, pattern, light hue -> ink pattern)
    ("#D55E00", "solid", False),
    ("#56B4E9", "hoops", True),
    ("#F0E442", "dots", True),
    ("#009E73", "chevrons", False),
    ("#CC79A7", "sash", False),
    ("#E69F00", "checks", False),
    ("#0072B2", "stars", False),
    ("#3A3F4B", "diamonds", False),
]

RIBBONS: list[tuple[str, str, str, int]] = [  # (name, pleat, inner ring, place)
    ("blue", "#2F6FDE", "#1F55B8", 1),
    ("red", "#E0474C", "#B8323A", 2),
    ("yellow", GOLD, "#E8B21F", 3),
    ("white", WHITE, "#DDE2EA", 4),
]

HOOF = "M64 12 C94 12 112 38 112 68 C112 94 100 114 84 114 L74 114 L64 100 L54 114 L44 114 C28 114 16 94 16 68 C16 38 34 12 64 12 Z"
SHOE = "M36 104 C26 90 24 62 34 46 C42 32 54 26 64 26 C74 26 86 32 94 46 C104 62 102 90 92 104"
NAILS = [(31, 84), (30, 62), (38, 42), (97, 84), (98, 62), (90, 42)]


def solid(fill: str, *els: str, outline: int = 12) -> str:
    """Filled shapes with the ink outline painted underneath (half the stroke shows outside the shape)."""
    return (
        f'<g fill="{fill}" stroke="{INK}" stroke-width="{outline}" stroke-linejoin="round" '
        f'stroke-linecap="round" paint-order="stroke">{"".join(els)}</g>'
    )


def band(d: str, w: int, colour: str, outline: int = 12, dash: str = "") -> str:
    """A thick coloured stroke with an ink outline."""
    da = f' stroke-dasharray="{dash}"' if dash else ""
    return (
        f'<path d="{d}" fill="none" stroke="{INK}" stroke-width="{w + outline}" stroke-linecap="round" stroke-linejoin="round"{da}/>'
        f'<path d="{d}" fill="none" stroke="{colour}" stroke-width="{w}" stroke-linecap="round" stroke-linejoin="round"{da}/>'
    )


def text(x: float, y: float, s: str, size: int, fill: str = INK) -> str:
    return f'<text x="{x}" y="{y}" font-family="{FONT}" font-size="{size}" font-weight="900" fill="{fill}" text-anchor="middle">{s}</text>'


def star_points(cx: float, cy: float, outer: float, inner: float, n: int = 5, rot: float = -90) -> str:
    pts = []
    for i in range(n * 2):
        r = outer if i % 2 == 0 else inner
        a = math.radians(rot + i * 180 / n)
        pts.append(f"{cx + r * math.cos(a):.1f},{cy + r * math.sin(a):.1f}")
    return " ".join(pts)


def pleat_points(cx: float, cy: float, outer: float, inner: float, n: int) -> str:
    return star_points(cx, cy, outer, inner, n, rot=-90)


def hoof_glyph(fill: str = WHITE) -> str:
    nails = "".join(f'<circle cx="{x}" cy="{y}" r="2.6"/>' for x, y in NAILS)
    return (
        solid(fill, f'<path d="{HOOF}"/>')
        + f'<path d="{SHOE}" fill="none" stroke="{INK}" stroke-width="11" stroke-linecap="round"/>'
        + f'<g fill="{fill}">{nails}</g>'
    )


def ring(dash: str = "", colour: str = WHITE) -> str:
    return band("M64 10 A54 54 0 1 1 63.99 10 Z", 8, colour, outline=10, dash=dash)


def tap_button(pressed: bool) -> str:
    glyph = f'<g transform="translate({128 - 64 * 1.05:.1f},{(136 if pressed else 124) - 64 * 1.05:.1f}) scale(1.05)">{hoof_glyph()}</g>'
    if pressed:
        return solid(ORANGE_PRESSED, '<circle cx="128" cy="136" r="108"/>') + glyph
    return (
        solid(ORANGE_DARK, '<circle cx="128" cy="138" r="108"/>')
        + solid(ORANGE, '<circle cx="128" cy="124" r="108"/>')
        + f'<ellipse cx="96" cy="72" rx="44" ry="20" fill="{WHITE}" opacity="0.35" transform="rotate(-24 96 72)"/>'
        + glyph
    )


def burst_bar() -> str:
    ticks = "".join(
        f'<path d="M{12 + 1000 * i / 10:.0f} 48 L{12 + 1000 * i / 10:.0f} 80" stroke="{WHITE}" stroke-opacity="0.25" stroke-width="5" stroke-linecap="round"/>'
        for i in range(1, 10)
    )
    return solid(SLATE, '<rect x="12" y="28" width="1000" height="72" rx="36"/>', outline=12) + f'<rect x="32" y="38" width="960" height="14" rx="7" fill="{WHITE}" opacity="0.10"/>' + ticks


def burst_glow(pid: str) -> str:
    stripes = "".join(f'<path d="M{x} 110 L{x + 80} 18" stroke="{GOLD_LIGHT}" stroke-width="10"/>' for x in range(-40, 240, 26))
    return (
        f'<defs><radialGradient id="{pid}g" cx="50%" cy="50%" r="50%">'
        f'<stop offset="0" stop-color="{GOLD}" stop-opacity="0.85"/><stop offset="0.6" stop-color="{GOLD}" stop-opacity="0.35"/>'
        f'<stop offset="1" stop-color="{GOLD}" stop-opacity="0"/></radialGradient>'
        f'<clipPath id="{pid}c"><rect x="56" y="28" width="144" height="72" rx="14"/></clipPath></defs>'
        f'<ellipse cx="128" cy="64" rx="126" ry="62" fill="url(#{pid}g)"/>'
        + solid(GOLD, '<rect x="56" y="28" width="144" height="72" rx="14"/>', outline=8)
        + f'<g clip-path="url(#{pid}c)">{stripes}</g>'
        + f'<rect x="56" y="28" width="144" height="72" rx="14" fill="none" stroke="{INK}" stroke-width="4"/>'
        + f'<rect x="68" y="35" width="120" height="9" rx="4.5" fill="{WHITE}" opacity="0.55"/>'
    )


def burst_marker() -> str:
    return solid(WHITE, '<path d="M10 8 L54 8 L32 38 Z"/>', '<rect x="22" y="38" width="20" height="112" rx="10"/>')


def feedback(name: str) -> str:
    c = FEEDBACK[name]
    if name == "perfect":
        return solid(c, f'<polygon points="{star_points(64, 68, 56, 25)}"/>') + f'<ellipse cx="52" cy="52" rx="9" ry="5" fill="{WHITE}" opacity="0.7" transform="rotate(-35 52 52)"/>'
    if name == "great":
        return band("M28 72 L64 40 L100 72", 18, c) + band("M28 104 L64 72 L100 104", 18, c)
    if name == "good":
        return band("M26 66 L52 92 L104 38", 22, c)
    if name == "okay":
        return solid(c, '<circle cx="64" cy="64" r="30"/>')
    if name == "miss":
        return band("M30 64 L98 64", 22, c)
    return band("M16 64 C28 38 40 38 50 64 S74 90 84 64 S104 42 112 56", 16, c)  # steady (mashing)


def lane_pattern(pattern: str, colour: str) -> str:
    if pattern == "solid":
        return ""
    if pattern == "hoops":
        return "".join(f'<rect x="0" y="{y}" width="128" height="14" fill="{colour}"/>' for y in (22, 56, 90))
    if pattern == "dots":
        return "".join(f'<circle cx="{x}" cy="{y}" r="7" fill="{colour}"/>' for x in range(20, 128, 26) for y in range(20, 128, 26))
    if pattern == "chevrons":
        return "".join(f'<path d="M-4 {y + 24} L64 {y} L132 {y + 24}" fill="none" stroke="{colour}" stroke-width="10"/>' for y in range(4, 128, 30))
    if pattern == "sash":
        return f'<path d="M-10 138 L138 -10" stroke="{colour}" stroke-width="38"/>'
    if pattern == "checks":
        return "".join(f'<rect x="{10 + i * 27}" y="{10 + j * 27}" width="27" height="27" fill="{colour}"/>' for i in range(4) for j in range(4) if (i + j) % 2 == 0)
    if pattern == "stars":
        spots = [(30, 30), (98, 30), (30, 98), (98, 98), (64, 18), (64, 110), (18, 64), (110, 64)]
        return "".join(f'<polygon points="{star_points(x, y, 12, 5)}" fill="{colour}"/>' for x, y in spots)
    if pattern == "diamonds":
        return "".join(
            f'<path d="M{x} {y - 12} L{x + 9} {y} L{x} {y + 12} L{x - 9} {y} Z" fill="{colour}"/>'
            for x in range(16, 128, 32) for y in range(16, 128, 32)
        )
    raise ValueError(pattern)


def lane_chip(n: int, pid: str) -> str:
    colour, pattern, light = LANES[n - 1]
    pcol = INK if light else WHITE
    op = "0.45" if light else "0.85"
    body = '<rect x="10" y="10" width="108" height="108" rx="26"/>'
    return (
        f'<defs><clipPath id="{pid}c">{body}</clipPath></defs>'
        + solid(colour, body)
        + f'<g clip-path="url(#{pid}c)" opacity="{op}">{lane_pattern(pattern, pcol)}</g>'
        + f'<rect x="10" y="10" width="108" height="108" rx="26" fill="none" stroke="{INK}" stroke-width="6"/>'
        + solid(WHITE, '<circle cx="64" cy="64" r="30"/>', outline=8)
        + text(64, 78, str(n), 40)
    )


def ribbon(pleat: str, inner: str, place: int) -> str:
    tails = solid(pleat, '<path d="M54 84 L36 150 L50 140 L60 154 L68 88 Z"/>', '<path d="M74 84 L92 150 L78 140 L68 154 L60 88 Z"/>')
    extra = solid(inner, f'<polygon points="{pleat_points(64, 62, 60, 50, 22)}"/>') if place == 1 else ""
    return (
        tails
        + extra
        + solid(pleat, f'<polygon points="{pleat_points(64, 62, 50, 40, 18)}"/>')
        + solid(inner, '<circle cx="64" cy="62" r="32"/>', outline=8)
        + solid(PAPER, '<circle cx="64" cy="62" r="22"/>', outline=6)
        + text(64, 73, str(place), 30)
    )


def chance_arrow(up: bool) -> str:
    d = "M64 14 L110 62 L82 62 L82 112 L46 112 L46 62 L18 62 Z"
    if not up:
        d = "M64 114 L110 66 L82 66 L82 16 L46 16 L46 66 L18 66 Z"
    return solid(TEAL if up else PLUM, f'<path d="{d}"/>')


def finish_checker() -> str:
    return "".join(f'<rect x="{i * 32}" y="{j * 32}" width="32" height="32" fill="{INK if (i + j) % 2 == 0 else WHITE}"/>' for i in range(4) for j in range(4))


def you_marker() -> str:
    d = "M28 14 L100 14 Q112 14 112 26 L112 60 Q112 72 100 72 L82 72 L64 112 L46 72 L28 72 Q16 72 16 60 L16 26 Q16 14 28 14 Z"
    return solid(WHITE, f'<path d="{d}"/>') + f'<path d="M24 64 L104 64" stroke="{GOLD}" stroke-width="8" stroke-linecap="round"/>' + text(64, 54, "YOU", 30)


def assets() -> dict[str, tuple[int, int, str]]:
    a: dict[str, tuple[int, int, str]] = {
        "hoof": (128, 128, hoof_glyph()),
        "hoof_ring": (128, 128, ring()),
        "hoof_ring_dashed": (128, 128, ring("20 14")),
        "tap_button": (256, 256, tap_button(False)),
        "tap_button_pressed": (256, 256, tap_button(True)),
        "burst_bar": (1024, 128, burst_bar()),
        "burst_glow": (256, 128, burst_glow("burst_glow")),
        "burst_marker": (64, 160, burst_marker()),
        "chance_up": (128, 128, chance_arrow(True)),
        "chance_down": (128, 128, chance_arrow(False)),
        "finish_checker": (128, 128, finish_checker()),
        "you_marker": (128, 128, you_marker()),
    }
    for name in FEEDBACK:
        a[f"label_{name}"] = (128, 128, feedback(name))
    for n in range(1, 9):
        a[f"lane_{n}"] = (128, 128, lane_chip(n, f"lane_{n}"))
    for name, pleat, inner, place in RIBBONS:
        a[f"ribbon_{name}"] = (128, 160, ribbon(pleat, inner, place))
    return a


def svg(w: int, h: int, body: str) -> str:
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{body}</svg>\n'


def nested(x: float, y: float, w: float, h: float, vw: int, vh: int, body: str) -> str:
    return f'<svg x="{x}" y="{y}" width="{w}" height="{h}" viewBox="0 0 {vw} {vh}">{body}</svg>'


def sheet(a: dict[str, tuple[int, int, str]]) -> str:
    rows = [
        ["hoof", "hoof_ring", "hoof_ring_dashed", "tap_button", "tap_button_pressed", "burst_glow", "burst_marker"],
        [f"label_{n}" for n in FEEDBACK] + ["chance_up", "chance_down"],
        [f"lane_{n}" for n in range(1, 9)],
        [f"ribbon_{r[0]}" for r in RIBBONS] + ["finish_checker", "you_marker"],
    ]
    cell, pad, top = 128, 24, 70
    width = pad + 8 * (cell + pad)
    out = [f'<rect width="100%" height="100%" fill="#F4EBD9"/>', text(width / 2, 44, "Gavel Derby race UI drafts (P0)", 28)]
    y = top
    for row in rows:
        x = pad
        for name in row:
            w, h, body = a[name]
            s = min(cell / w, cell / h)
            dw, dh = w * s, h * s
            out.append(nested(x + (cell - dw) / 2, y + (cell - dh) / 2, dw, dh, w, h, body))
            out.append(f'<text x="{x + cell / 2}" y="{y + cell + 18}" font-family="Arial, sans-serif" font-size="13" fill="{INK}" text-anchor="middle">{name}</text>')
            x += cell + pad
        y += cell + 40
    out.append(f'<text x="{pad}" y="{y + 4}" font-family="Arial, sans-serif" font-size="14" font-weight="bold" fill="{INK}">Hoof ring over one beat of lead (linear scale 2.4x to 1.0x; contact = the beat)</text>')
    y += 14
    frames = [(2.4, WHITE, ""), (1.9, WHITE, ""), (1.45, WHITE, ""), (1.0, GOLD, "perfect"), (1.6, WHITE, "dashed")]
    hoof_px, fcell = 56, 150
    for i, (k, colour, tag) in enumerate(frames):
        cx, cy = pad + fcell / 2 + i * (fcell + 30), y + fcell / 2 + 10
        out.append(f'<rect x="{cx - fcell / 2}" y="{y}" width="{fcell}" height="{fcell + 20}" rx="16" fill="#C68A52"/>')
        out.append(nested(cx - hoof_px / 2, cy - hoof_px / 2, hoof_px, hoof_px, 128, 128, hoof_glyph()))
        rp = hoof_px * k
        out.append(nested(cx - rp / 2, cy - rp / 2, rp, rp, 128, 128, ring("20 14" if tag == "dashed" else "", colour)))
        if tag == "perfect":
            out.append(nested(cx + 18, y + 4, 44, 44, 128, 128, feedback("perfect")))
        cap = {"perfect": "contact + tap = Perfect", "dashed": "tempo change next beat"}.get(tag, f"{k}x")
        out.append(f'<text x="{cx}" y="{y + fcell + 40}" font-family="Arial, sans-serif" font-size="13" fill="{INK}" text-anchor="middle">{cap}</text>')
    y += fcell + 70
    bw = width - 2 * pad
    bh = bw * 160 / 1024
    zone_w, zone_c, marker_x = 160, 632, 340  # bar units: glow 16% wide centred at 62%, marker at 33%
    sx = zone_w / 144
    composed = (
        a["burst_bar"][2]
        + f'<g transform="translate({zone_c - 128 * sx:.1f},0) scale({sx:.3f},1)">{burst_glow("sheet_glow")}</g>'
        + f'<g transform="translate({marker_x - 32 * 0.9:.1f},-12) scale(0.9)">{burst_marker()}</g>'
    )
    out.append(nested(pad, y, bw, bh, 1024, 160, f'<g transform="translate(0,16)">{composed}</g>'))
    out.append(f'<text x="{width / 2}" y="{y + bh + 18}" font-family="Arial, sans-serif" font-size="13" fill="{INK}" text-anchor="middle">burst_bar + burst_glow + burst_marker composed (code places the glow and moves the marker)</text>')
    height = y + bh + 40
    return svg(int(width), int(height), "".join(out))


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    a = assets()
    for name, (w, h, body) in a.items():
        (OUT / f"{name}.svg").write_text(svg(w, h, body), encoding="utf-8", newline="\n")
    (OUT / "_sheet.svg").write_text(sheet(a), encoding="utf-8", newline="\n")
    print(f"make_ui_svgs: wrote {len(a)} SVGs + _sheet.svg to {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
