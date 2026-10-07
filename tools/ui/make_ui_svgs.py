# Race and world UI art as SVG (assets/ui/<name>.svg), review sheets (assets/ui/_sheet.svg for the race set,
# assets/ui/_sheet_world.svg for the world set) and 2x PNGs (assets/ui/png/).
# Style: docs/art/ART_DIRECTION.md; council review: docs/art/ART_REVIEW.md. Chunky shapes, ink outline painted under
# the fill, every state = shape + colour. In game, words and numbers are TextLabels: use the *_blank variants; the baked
# text in the other variants is for review and placeholders.
#   python tools/ui/make_ui_svgs.py            # SVGs + sheet + PNGs (PNGs need: pip install resvg-py)
#   python tools/ui/make_ui_svgs.py --no-png
from __future__ import annotations

import argparse
import math
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
OUT = REPO / "assets" / "ui"
PNG_OUT = OUT / "png"
PNG_ZOOM = 2  # every 128 px icon exports at 256 px

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
DIRT = "#C68A52"
FONT = "Fredoka One, Arial Rounded MT Bold, Arial Black, Arial, sans-serif"

FEEDBACK = {  # label: colour (shape is in the drawing)
    "perfect": GOLD,
    "great": "#4CC3FF",
    "good": "#3CC46A",
    "okay": "#CBB89D",
    "miss": "#9A8FB0",
    "steady": "#F2A65A",
}

LANES: list[tuple[str, str, bool]] = [  # (hex, pattern, light hue -> ink pattern), fixed per lane number (council 5)
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

# Rings (council 7): every ring takes RING_CLOSE_S to close from RING_SPAWN x the hoof radius; tempo shows as spacing.
RING_SPAWN = 3.0
RING_CLOSE_S = 1.0
RING_ALPHA = [1.0, 0.7, 0.45]  # next ring to land, then the ones behind it


def solid(fill: str, *els: str, outline: float = 12) -> str:
    """Filled shapes with the ink outline painted underneath (half the stroke shows outside the shape)."""
    return (
        f'<g fill="{fill}" stroke="{INK}" stroke-width="{outline}" stroke-linejoin="round" '
        f'stroke-linecap="round" paint-order="stroke">{"".join(els)}</g>'
    )


def band(d: str, w: float, colour: str, outline: float = 12) -> str:
    """A thick coloured stroke with an ink outline."""
    return (
        f'<path d="{d}" fill="none" stroke="{INK}" stroke-width="{w + outline}" stroke-linecap="round" stroke-linejoin="round"/>'
        f'<path d="{d}" fill="none" stroke="{colour}" stroke-width="{w}" stroke-linecap="round" stroke-linejoin="round"/>'
    )


def text(x: float, y: float, s: str, size: int, fill: str = INK, stroke: str = "", sw: int = 0) -> str:
    st = f' stroke="{stroke}" stroke-width="{sw}" stroke-linejoin="round" paint-order="stroke"' if stroke else ""
    return f'<text x="{x}" y="{y}" font-family="{FONT}" font-size="{size}" font-weight="900" fill="{fill}" text-anchor="middle"{st}>{s}</text>'


def star_points(cx: float, cy: float, outer: float, inner: float, n: int = 5, rot: float = -90) -> str:
    pts = []
    for i in range(n * 2):
        r = outer if i % 2 == 0 else inner
        a = math.radians(rot + i * 180 / n)
        pts.append(f"{cx + r * math.cos(a):.1f},{cy + r * math.sin(a):.1f}")
    return " ".join(pts)


def hoof_glyph(fill: str = WHITE) -> str:
    nails = "".join(f'<circle cx="{x}" cy="{y}" r="2.6"/>' for x, y in NAILS)
    return (
        solid(fill, f'<path d="{HOOF}"/>')
        + f'<path d="{SHOE}" fill="none" stroke="{INK}" stroke-width="11" stroke-linecap="round"/>'
        + f'<g fill="{fill}">{nails}</g>'
    )


def ring_circle(cx: float, cy: float, r: float, w: float = 6, colour: str = WHITE, alpha: float = 1.0) -> str:
    """A ring with a constant on-screen stroke (what a UIStroke ring draws) and a thin ink edge each side."""
    return (
        f'<g opacity="{alpha}"><circle cx="{cx:.1f}" cy="{cy:.1f}" r="{r:.1f}" fill="none" stroke="{INK}" stroke-width="{w + 6}"/>'
        f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="{r:.1f}" fill="none" stroke="{colour}" stroke-width="{w}"/></g>'
    )


def giddyup_pad(state: str) -> str:
    """Bottom-of-screen affordance (council 6). Not an aim target: taps count anywhere."""
    label = "" if state == "blank" else text(256, 106 if state != "pressed" else 120, "GIDDY-UP!", 62, WHITE, INK, 12)
    if state == "pressed":
        return solid(ORANGE_PRESSED, '<rect x="16" y="28" width="480" height="136" rx="68"/>') + label
    return (
        solid(ORANGE_DARK, '<rect x="16" y="30" width="480" height="136" rx="68"/>')
        + solid(ORANGE, '<rect x="16" y="14" width="480" height="136" rx="68"/>')
        + f'<rect x="70" y="26" width="372" height="20" rx="10" fill="{WHITE}" opacity="0.3"/>'
        + label
    )


def burst_bar() -> str:
    ticks = "".join(
        f'<path d="M{12 + 1000 * i / 10:.0f} 48 L{12 + 1000 * i / 10:.0f} 80" stroke="{WHITE}" stroke-opacity="0.25" stroke-width="5" stroke-linecap="round"/>'
        for i in range(1, 10)
    )
    return solid(SLATE, '<rect x="12" y="28" width="1000" height="72" rx="36"/>') + f'<rect x="32" y="38" width="960" height="14" rx="7" fill="{WHITE}" opacity="0.10"/>' + ticks


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


def burst_rays(pid: str) -> str:
    """Perfect celebration behind the player's horse, own screen only, after scoring (council 4)."""
    rays = []
    for i in range(12):
        a0, a1 = math.radians(i * 30 - 6), math.radians(i * 30 + 6)
        rays.append(f'<path d="M128 128 L{128 + 124 * math.cos(a0):.1f} {128 + 124 * math.sin(a0):.1f} L{128 + 124 * math.cos(a1):.1f} {128 + 124 * math.sin(a1):.1f} Z"/>')
    return (
        f'<defs><radialGradient id="{pid}r" cx="50%" cy="50%" r="50%">'
        f'<stop offset="0" stop-color="{WHITE}" stop-opacity="1"/><stop offset="0.3" stop-color="{GOLD}" stop-opacity="1"/>'
        f'<stop offset="1" stop-color="#FFB000" stop-opacity="0"/></radialGradient></defs>'
        f'<g fill="url(#{pid}r)">{"".join(rays)}</g>'
    )


def fx_dust_puff(pid: str) -> str:
    """Particle: one puff per hoof per beat. White so ParticleEmitter.Color tints it to the track (dirt #E3B985)."""
    blobs = [(64, 74, 34), (40, 82, 22), (90, 80, 24), (58, 52, 22), (80, 58, 18)]
    return (
        f'<defs><radialGradient id="{pid}p" cx="50%" cy="45%" r="50%"><stop offset="0.55" stop-color="{WHITE}" stop-opacity="0.95"/>'
        f'<stop offset="1" stop-color="{WHITE}" stop-opacity="0"/></radialGradient></defs>'
        + "".join(f'<circle cx="{x}" cy="{y}" r="{r}" fill="url(#{pid}p)"/>' for x, y, r in blobs)
    )


def fx_mane_flick() -> str:
    """Particle: a quick hair flick from the crest on each beat (the mesh is static). White, tinted to the mane colour."""
    strokes = ["M18 104 C40 70 70 52 112 40", "M26 112 C52 86 80 72 116 66", "M14 90 C30 60 52 40 86 22"]
    return "".join(
        f'<path d="{d}" fill="none" stroke="{WHITE}" stroke-width="{w}" stroke-linecap="round" opacity="{o}"/>'
        for d, w, o in zip(strokes, (14, 10, 8), (1.0, 0.85, 0.7))
    )


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


def lane_chip(n: int, pid: str, number: bool = True) -> str:
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
        + (text(64, 78, str(n), 40) if number else "")
    )


def lane_sparkle() -> str:
    """Overlay for any lane chip: shown to other players when that rider scores a Perfect burst (council 4)."""
    spots = [(106, 20, 20), (20, 106, 14), (114, 98, 10)]
    return solid(GOLD, *(f'<polygon points="{star_points(x, y, r, r * 0.32, 4)}"/>' for x, y, r in spots), outline=7)


def you_marker(baked: bool) -> str:
    """Huge marker over the player's own horse (council 5)."""
    d = "M50 16 L206 16 Q240 16 240 50 L240 132 Q240 166 206 166 L162 166 L128 238 L94 166 L50 166 Q16 166 16 132 L16 50 Q16 16 50 16 Z"
    return solid(GOLD, f'<path d="{d}"/>', outline=16) + f'<rect x="44" y="28" width="168" height="16" rx="8" fill="{WHITE}" opacity="0.45"/>' + (text(128, 128, "YOU", 96) if baked else "")


def ribbon(pleat: str, inner: str, place: int) -> str:
    tails = solid(pleat, '<path d="M54 84 L36 150 L50 140 L60 154 L68 88 Z"/>', '<path d="M74 84 L92 150 L78 140 L68 154 L60 88 Z"/>')
    extra = solid(inner, f'<polygon points="{star_points(64, 62, 60, 50, 22)}"/>') if place == 1 else ""
    return (
        tails
        + extra
        + solid(pleat, f'<polygon points="{star_points(64, 62, 50, 40, 18)}"/>')
        + solid(inner, '<circle cx="64" cy="62" r="32"/>', outline=8)
        + solid(PAPER, '<circle cx="64" cy="62" r="22"/>', outline=6)
        + text(64, 73, str(place), 30)
    )


def chance_arrow(up: bool) -> str:
    d = "M64 14 L110 62 L82 62 L82 112 L46 112 L46 62 L18 62 Z" if up else "M64 114 L110 66 L82 66 L82 16 L46 16 L46 66 L18 66 Z"
    return solid(TEAL if up else PLUM, f'<path d="{d}"/>')


def finish_checker() -> str:
    return "".join(f'<rect x="{i * 32}" y="{j * 32}" width="32" height="32" fill="{INK if (i + j) % 2 == 0 else WHITE}"/>' for i in range(4) for j in range(4))


def assets() -> dict[str, tuple[int, int, str]]:
    a: dict[str, tuple[int, int, str]] = {
        "hoof": (128, 128, hoof_glyph()),
        "hoof_ring": (256, 256, ring_circle(128, 128, 118, w=10)),
        "giddyup_pad": (512, 176, giddyup_pad("idle")),
        "giddyup_pad_pressed": (512, 176, giddyup_pad("pressed")),
        "giddyup_pad_blank": (512, 176, giddyup_pad("blank")),
        "burst_bar": (1024, 128, burst_bar()),
        "burst_glow": (256, 128, burst_glow("burst_glow")),
        "burst_marker": (64, 160, burst_marker()),
        "burst_rays": (256, 256, burst_rays("burst_rays")),
        "chance_up": (128, 128, chance_arrow(True)),
        "chance_down": (128, 128, chance_arrow(False)),
        "finish_checker": (128, 128, finish_checker()),
        "you_marker": (256, 256, you_marker(True)),
        "you_marker_blank": (256, 256, you_marker(False)),
        "lane_sparkle": (128, 128, lane_sparkle()),
        "fx_dust_puff": (128, 128, fx_dust_puff("fx_dust_puff")),
        "fx_mane_flick": (128, 128, fx_mane_flick()),
    }
    for name in FEEDBACK:
        a[f"label_{name}"] = (128, 128, feedback(name))
    for n in range(1, 9):
        a[f"lane_{n}"] = (128, 128, lane_chip(n, f"lane_{n}"))
        a[f"lane_{n}_blank"] = (128, 128, lane_chip(n, f"lane_{n}_blank", number=False))
        a[f"lane_{n}_sparkle"] = (128, 128, lane_chip(n, f"lane_{n}_sparkle") + lane_sparkle())
    for name, pleat, inner, place in RIBBONS:
        a[f"ribbon_{name}"] = (128, 160, ribbon(pleat, inner, place))
    return a


# ---- World UI (docs/WORLD_DESIGN.md): wallet, care, Map, Race Board, Health Passport, Stable Board, training ----
# Same rules as the race set: ink under the fill, every state = shape + colour, no baked words or numbers, no wagering
# imagery, no whip, no cross emblem, no glow. Horses: calm, small side eyes, ears forward, natural coats (red bay hero).
GRASS = "#5DBB4A"
GRASS_DARK = "#4AA23C"
LEAF = "#3E9B4F"
SKY = "#8ED6FF"
DIRT_LIGHT = "#E3B985"
DIRT_DARK = "#8C5A2E"
WOOD = "#C98A4B"
WOOD_DARK = "#8A5530"
HAY = "#F2C14E"
HAY_LIGHT = "#FFE08A"
HAY_DARK = "#D29A2E"
TWINE = "#B5562F"
CASH = "#7CC86E"
CASH_DARK = "#3F9A54"
CASH_LIGHT = "#C8EBB8"
DIAMOND = "#5CC8F5"
DIAMOND_LIGHT = "#C4EEFF"
DIAMOND_DARK = "#2E9AD0"
CARROT = "#F7882F"
APPLE = "#E5484D"
OAT = "#F6DE96"
OAT_STEM = "#BFA94F"
GRAIN = "#E2B467"
SCOOP = "#6FA8DC"
SUGAR_SIDE = "#E3E9F2"
SUGAR_SHADE = "#C3CEDF"
ENERGY = "#FFA630"
ENERGY_DARK = "#D97A00"
EMPTY = "#B4B9C3"
HEART = "#F2607E"
MINT = "#4FCFB0"
LAVENDER = "#A996D6"
GO = "#3CC46A"
GO_DARK = "#24974B"
GO_PRESSED = "#30B25D"
BRONZE = "#D58E52"
BRONZE_DARK = "#A8642F"
SILVER = "#BCC6D3"
SILVER_DARK = "#8592A6"
GOLD_DARK = "#E0A81A"
ROYAL = "#5B5BD6"
ROYAL_DARK = "#4141AA"
STEEL = "#9AA6B6"
STEEL_LIGHT = "#CDD5E0"
BAY = "#A4532E"
BAY_LIGHT = "#C26E40"
BAY_DARK = "#2B2522"  # red bay points: mane, tail, lower legs
HOOF_DARK = "#26262C"
BARN_RED = "#C8463D"  # buildings only
WATER = "#4CA9F0"
MUD = "#9C6233"
MUD_LIGHT = "#C68A52"

SHOE0 = "M-20 24 C-29 10 -29 -8 -19 -18 C-13 -24 -7 -26 0 -26 C7 -26 13 -24 19 -18 C29 -8 29 10 20 24"  # horseshoe, centre 0,0
HEART0 = "M0 30 C-12 21 -30 10 -30 -6 C-30 -18 -21 -26 -11 -26 C-5 -26 -2 -22 0 -17 C2 -22 5 -26 11 -26 C21 -26 30 -18 30 -6 C30 10 12 21 0 30 Z"  # heart, centre 0,0


def detail(d: str, w: float = 6, colour: str = INK, extra: str = "") -> str:
    """An inner line (thinner than the 12 px silhouette outline)."""
    return f'<path d="{d}" fill="none" stroke="{colour}" stroke-width="{w}" stroke-linecap="round" stroke-linejoin="round"{extra}/>'


def shine(cx: float, cy: float, rx: float, ry: float, rot: float = -35, op: float = 0.6) -> str:
    return f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="{WHITE}" opacity="{op}" transform="rotate({rot} {cx} {cy})"/>'


def place(body: str, x: float, y: float, s: float, rot: float = 0) -> str:
    """Draw a 128-box body scaled by s with its centre at (x, y)."""
    return f'<g transform="translate({x:g} {y:g}) rotate({rot:g}) scale({s:g}) translate(-64 -64)">{body}</g>'


def merged(*parts: tuple[str, str], outline: float = 12) -> str:
    """Several shapes read as one silhouette: every ink outline first, then every fill (no seams between them)."""
    ink = "".join(el for _, el in parts)
    return (
        f'<g fill="{INK}" stroke="{INK}" stroke-width="{outline}" stroke-linejoin="round" stroke-linecap="round">{ink}</g>'
        + "".join(f'<g fill="{c}">{el}</g>' for c, el in parts)
    )


def rounded(fill: str, el: str, r: float, outline: float = 12) -> str:
    """Soft corners: the shape is stroked in its own colour (2r wide) over a wider ink stroke."""
    return (
        f'<g fill="{INK}" stroke="{INK}" stroke-width="{2 * r + outline:g}" stroke-linejoin="round">{el}</g>'
        f'<g fill="{fill}" stroke="{fill}" stroke-width="{2 * r:g}" stroke-linejoin="round">{el}</g>'
    )


def blob_path(pts: list[tuple[float, float]]) -> str:
    """A smooth closed curve through the points (Catmull-Rom as cubic Beziers)."""
    n = len(pts)
    d = f"M{pts[0][0]:.1f} {pts[0][1]:.1f}"
    for i in range(n):
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[(i + 1) % n], pts[(i + 2) % n]
        c1 = (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6)
        c2 = (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6)
        d += f" C{c1[0]:.1f} {c1[1]:.1f} {c2[0]:.1f} {c2[1]:.1f} {p2[0]:.1f} {p2[1]:.1f}"
    return d + " Z"


def scallop_path(cx: float, cy: float, r: float, n: int, bump: float) -> str:
    pts = [(cx + r * math.cos(2 * math.pi * i / n - math.pi / 2), cy + r * math.sin(2 * math.pi * i / n - math.pi / 2)) for i in range(n)]
    return f"M{pts[0][0]:.1f} {pts[0][1]:.1f}" + "".join(f" A{bump} {bump} 0 0 1 {x:.1f} {y:.1f}" for x, y in pts[1:] + pts[:1]) + " Z"


def horseshoe(cx: float, cy: float, s: float, colour: str, w: float = 12, outline: float = 8, nails: bool = False) -> str:
    """A horseshoe band (opening down); w and outline are final pixels."""
    holes = ""
    if nails:
        holes = "".join(
            f'<circle cx="{x:g}" cy="{y:g}" r="{w / s * 0.2:.1f}" fill="{INK}"/>'
            for x, y in ((-24, 12), (-25, -4), (-17, -17), (24, 12), (25, -4), (17, -17))
        )
    return f'<g transform="translate({cx:g} {cy:g}) scale({s:g})">{band(SHOE0, w / s, colour, outline / s)}{holes}</g>'


def heart_at(cx: float, cy: float, s: float, colour: str = HEART, outline: float = 12, gloss: bool = True) -> str:
    g = shine(-14, -12, 6, 3.5, -40) if gloss else ""
    shape = solid(colour, f'<path d="{HEART0}"/>', outline=outline / s)
    return f'<g transform="translate({cx:g} {cy:g}) scale({s:g})">{shape}{g}</g>'


def cash() -> str:
    """Green Cash: one note with a horseshoe medallion (one token, never a pile)."""
    return (
        '<g transform="rotate(-8 64 64)">'
        + solid(CASH, '<rect x="14" y="34" width="100" height="60" rx="10"/>')
        + f'<rect x="23" y="43" width="82" height="42" rx="6" fill="none" stroke="{CASH_DARK}" stroke-width="4"/>'
        + "".join(f'<circle cx="{x}" cy="{y}" r="4.5" fill="{CASH_DARK}"/>' for x, y in ((32, 52), (96, 52), (32, 76), (96, 76)))
        + solid(CASH_LIGHT, '<circle cx="64" cy="64" r="19"/>', outline=6)
        + horseshoe(64, 63, 0.42, CASH_DARK, w=6, outline=0.01)
        + "</g>"
    )


def diamond() -> str:
    outline = '<polygon points="38,24 90,24 114,50 64,112 14,50"/>'
    facets = [
        ("38,24 54,24 46,50 14,50", DIAMOND_LIGHT),
        ("54,24 74,24 82,50 46,50", "#E8F9FF"),
        ("74,24 90,24 114,50 82,50", DIAMOND),
        ("14,50 46,50 64,112", DIAMOND),
        ("46,50 82,50 64,112", DIAMOND_LIGHT),
        ("82,50 114,50 64,112", DIAMOND_DARK),
    ]
    return (
        solid(DIAMOND, outline)
        + "".join(f'<polygon points="{p}" fill="{c}"/>' for p, c in facets)
        + detail("M14 50 L114 50", 4)
        + shine(46, 36, 8, 4, -10, 0.85)
    )


def hay() -> str:
    front, top, side = '<polygon points="14,52 94,52 94,110 14,110"/>', '<polygon points="14,52 36,30 116,30 94,52"/>', '<polygon points="94,52 116,30 116,88 94,110"/>'
    straws = "".join(detail(f"M{x} {y} l10 0", 3, HAY_DARK) for x, y in ((22, 64), (60, 70), (26, 90), (64, 96), (44, 80), (78, 84), (40, 100)))
    wisps = band("M44 32 L38 20 M48 31 L50 18 M84 31 L82 18 M88 31 L96 20", 3, HAY_LIGHT, 5)
    return (
        wisps
        + merged((HAY, front), (HAY_LIGHT, top), (HAY_DARK, side))
        + straws
        + detail("M14 52 L94 52 L116 30 M94 52 L94 110", 5)
        + band("M38 110 L38 52 L60 30", 7, TWINE, 5)
        + band("M72 110 L72 52 L94 30", 7, TWINE, 5)
    )


def grain() -> str:
    """A feed scoop heaped with mixed grain (a scoop, so it never looks like the oat sheaf)."""
    heap = '<path d="M10 54 C12 34 38 20 58 24 C78 26 94 42 96 64 Z"/>'
    body = '<path d="M10 54 L96 64 L96 98 C96 104 92 108 86 108 L28 108 C20 108 16 102 15 96 Z"/>'
    cols = ("#FFF1C9", "#9C6A3A", GOLD, "#7FA650")
    dots = ""
    for i, (x, y) in enumerate(((24, 46), (36, 38), (50, 32), (64, 32), (78, 38), (88, 50), (30, 52), (44, 46), (58, 42),
                                (72, 46), (84, 58), (52, 54), (66, 56), (40, 56), (20, 54), (62, 26), (76, 30), (94, 60))):
        dots += f'<ellipse cx="{x}" cy="{y}" rx="4.6" ry="3.2" fill="{cols[i % 4]}" transform="rotate({(i * 47) % 90 - 45} {x} {y})"/>'
    return (
        solid(SCOOP, '<rect x="88" y="78" width="26" height="10" rx="5"/>', '<circle cx="114" cy="83" r="7"/>', outline=10)
        + solid(GRAIN, heap)
        + dots
        + solid(SCOOP, body)
        + f'<path d="M22 76 L86 82" stroke="{WHITE}" stroke-width="8" stroke-linecap="round" opacity="0.35"/>'
        + detail("M10 54 L96 64", 5)
    )


def carrot_body() -> str:
    leaves = solid(GRASS, '<ellipse cx="52" cy="26" rx="8" ry="17" transform="rotate(-28 52 26)"/>', '<ellipse cx="76" cy="26" rx="8" ry="17" transform="rotate(28 76 26)"/>', '<ellipse cx="64" cy="22" rx="8" ry="18"/>')
    body = solid(CARROT, '<path d="M42 46 C42 36 86 36 86 46 C86 72 74 100 64 118 C54 100 42 72 42 46 Z"/>')
    ridges = detail("M48 58 L58 60 M72 72 L80 70 M54 86 L62 88", 5)
    return leaves + body + ridges + shine(54, 52, 4, 9, 0, 0.45)


def carrot() -> str:
    return place(carrot_body(), 62, 66, 0.92, 38)


def apple() -> str:
    body = '<path d="M64 42 C50 30 18 32 18 68 C18 98 40 116 56 112 C60 111 68 111 72 112 C88 116 110 98 110 68 C110 32 78 30 64 42 Z"/>'
    return (
        band("M64 42 C64 32 66 24 70 16", 7, WOOD_DARK, 10)
        + solid(GRASS, '<path d="M70 32 C76 16 96 14 104 20 C96 34 82 38 70 32 Z"/>', outline=10)
        + solid(APPLE, body)
        + shine(38, 60, 7, 13, 25)
    )


def oats_body() -> str:
    tie = (64, 82)
    tops = [(-44, 60), (-22, 66), (0, 68), (22, 66), (44, 60)]
    stalk_d, grains = [], []
    for ang, length in tops:
        a = math.radians(ang)
        tx, ty = tie[0] + length * math.sin(a), tie[1] - length * math.cos(a)
        stalk_d.append(f"M{tie[0]} {tie[1]} L{tx:.1f} {ty:.1f}")
        ux, uy = math.sin(a), -math.cos(a)  # along the stalk, upward
        for k, dist in enumerate((0, 15, 30)):
            side = 1 if k % 2 == 0 else -1
            gx, gy = tx - ux * dist + uy * 7 * side * (k > 0), ty - uy * dist - ux * 7 * side * (k > 0)
            rot = ang + (28 * side if k else 0)
            grains.append(f'<ellipse cx="{gx:.1f}" cy="{gy:.1f}" rx="5" ry="8.5" transform="rotate({rot:.0f} {gx:.1f} {gy:.1f})"/>')
    stalk_d += ["M64 82 L50 116", "M64 82 L64 118", "M64 82 L78 116"]
    d = " ".join(stalk_d)
    return (
        f'<path d="{d}" fill="none" stroke="{INK}" stroke-width="13" stroke-linecap="round"/>'
        + f'<path d="{d}" fill="none" stroke="{OAT_STEM}" stroke-width="5" stroke-linecap="round"/>'
        + solid(OAT, *grains, outline=6)
        + solid(TWINE, '<rect x="50" y="76" width="28" height="12" rx="6"/>', outline=6)
    )


def oats() -> str:
    return oats_body()


def seed_packet(colour: str, dark: str, crop: str) -> str:
    teeth = " ".join(f"{24 + i * 8},{14 if i % 2 else 20}" for i in range(11))
    return (
        solid(colour, '<path d="M24 20 L104 20 L104 108 Q104 116 96 116 L32 116 Q24 116 24 108 Z"/>')
        + solid(dark, f'<polygon points="24,32 {teeth} 104,32"/>', outline=8)
        + solid(PAPER, '<rect x="33" y="42" width="62" height="64" rx="12"/>', outline=6)
        + place(crop, 64, 74, 0.44)
    )


def treat() -> str:
    """A sugar cube."""
    top, left, right = '<polygon points="64,20 108,42 64,64 20,42"/>', '<polygon points="20,42 64,64 64,112 20,90"/>', '<polygon points="64,64 108,42 108,90 64,112"/>'
    crystals = "".join(f'<circle cx="{x}" cy="{y}" r="2.6" fill="{SUGAR_SHADE}"/>' for x, y in ((50, 34), (76, 40), (60, 48), (34, 64), (44, 84), (30, 78), (84, 70), (94, 86), (78, 92)))
    return (
        merged((WHITE, top), (SUGAR_SIDE, left), (SUGAR_SHADE, right))
        + detail("M20 42 L64 64 L108 42 M64 64 L64 112", 5)
        + crystals
        + solid(GOLD_LIGHT, f'<polygon points="{star_points(100, 18, 13, 4.5, 4)}"/>', outline=6)
    )


def brush_body() -> str:
    bristle_lines = "".join(detail(f"M{x} 76 L{x} 100", 3, "#C9A86B") for x in range(30, 102, 9))
    return (
        band("M34 44 C34 20 94 20 94 44", 9, TEAL, 8)
        + solid("#F2DCA8", '<path d="M22 70 L106 70 L106 100 Q100 108 94 100 Q88 108 82 100 Q76 108 70 100 Q64 108 58 100 Q52 108 46 100 Q40 108 34 100 Q28 108 22 100 Z"/>')
        + bristle_lines
        + solid(WOOD, '<rect x="12" y="40" width="104" height="34" rx="17"/>')
        + f'<rect x="26" y="47" width="70" height="8" rx="4" fill="{WHITE}" opacity="0.35"/>'
    )


def brush() -> str:
    return brush_body()


def energy_hoof(full: bool) -> str:
    """Energy pip. Full: a solid warm hoofprint. Empty: a hollow grey outline (shape and colour both change)."""
    if full:
        return solid(ENERGY, f'<path d="{HOOF}"/>') + f'<path d="{SHOE}" fill="none" stroke="{ENERGY_DARK}" stroke-width="11" stroke-linecap="round"/>' + shine(46, 34, 9, 5, -30)
    return (
        f'<path d="{HOOF}" fill="none" stroke="{INK}" stroke-width="20" stroke-linejoin="round"/>'
        + f'<path d="{HOOF}" fill="none" stroke="{EMPTY}" stroke-width="10" stroke-linejoin="round"/>'
    )


def heart() -> str:
    return heart_at(64, 66, 1.7)


def care_star() -> str:
    """Care: a soft, rounded mint star with a paper heart (label_perfect is a sharp gold star)."""
    pts = star_points(64, 68, 46, 25)
    return rounded(MINT, f'<polygon points="{pts}"/>', 9) + heart_at(64, 70, 0.62, PAPER, outline=6, gloss=False) + shine(42, 46, 6, 3.5, -40, 0.5)


def flag_ready() -> str:
    """Rested and ready to race: a pennant on a pole (the checkered flag is the finish, not this)."""
    return (
        solid(GRASS, '<ellipse cx="34" cy="112" rx="22" ry="8"/>', outline=8)
        + band("M34 22 L34 110", 8, WOOD, 10)
        + solid(GO, '<path d="M38 22 C62 26 88 34 114 44 C88 54 62 62 38 66 Z"/>')
        + horseshoe(64, 45, 0.38, PAPER, w=6, outline=0.01)
        + solid(GOLD, '<circle cx="34" cy="17" r="8"/>', outline=8)
    )


def zzz_resting() -> str:
    def z(x: float, y: float, s: float) -> str:
        return band(f"M{x} {y} L{x + s} {y} L{x} {y + s} L{x + s} {y + s}", 11, LAVENDER, 11)
    return z(14, 66, 42) + z(64, 38, 28) + z(96, 14, 16)


def clipboard() -> str:
    rows = ""
    for i, y in enumerate((50, 70, 90)):
        rows += solid(WHITE, f'<rect x="40" y="{y - 6}" width="12" height="12" rx="3"/>', outline=4)
        rows += detail(f"M60 {y} L88 {y}", 5, INK)
        if i < 2:
            rows += detail(f"M41 {y} L46 {y + 5} L55 {y - 8}", 5, GO_DARK)
    return (
        solid(WOOD, '<rect x="22" y="22" width="84" height="96" rx="10"/>')
        + solid(PAPER, '<rect x="32" y="34" width="64" height="74" rx="4"/>', outline=6)
        + rows
        + solid(STEEL, '<rect x="44" y="12" width="40" height="18" rx="6"/>', outline=8)
        + f'<circle cx="64" cy="20" r="4" fill="{INK}"/>'
    )


def map_icon() -> str:
    panels = [("14,28 48,18 48,100 14,110", PAPER), ("48,18 80,28 80,110 48,100", "#EBD8AE"), ("80,28 114,18 114,100 80,110", PAPER)]
    pin = solid(ORANGE, '<path d="M98 54 C88 42 86 36 86 32 C86 25 92 20 98 20 C104 20 110 25 110 32 C110 36 108 42 98 54 Z"/>', outline=8) + f'<circle cx="98" cy="32" r="4.5" fill="{WHITE}"/>'
    return (
        merged(*((c, f'<polygon points="{p}"/>') for p, c in panels))
        + f'<ellipse cx="30" cy="50" rx="10" ry="8" fill="{GRASS}" opacity="0.7"/><ellipse cx="66" cy="84" rx="9" ry="7" fill="{GRASS}" opacity="0.7"/>'
        + f'<path d="M24 94 C36 74 50 88 62 68 C72 52 84 62 96 52" fill="none" stroke="{INK}" stroke-width="5" stroke-dasharray="8 7" stroke-linecap="round"/>'
        + detail("M48 18 L48 100 M80 28 L80 110", 4)
        + pin
    )


def map_tile(pid: str, bg: str, picture: str) -> str:
    """Map fast-travel picture: one tile shape for the family, a distinct background colour and picture each."""
    tile = '<rect x="10" y="10" width="108" height="108" rx="24"/>'
    return (
        f'<defs><clipPath id="{pid}c">{tile}</clipPath></defs>'
        + solid(bg, tile)
        + f'<g clip-path="url(#{pid}c)">{picture}</g>'
        + f'<rect x="10" y="10" width="108" height="108" rx="24" fill="none" stroke="{INK}" stroke-width="6"/>'
    )


def map_stable_pic() -> str:
    walls = '<polygon points="30,64 42,44 64,32 86,44 98,64 98,102 30,102"/>'
    return (
        f'<rect x="0" y="94" width="128" height="40" fill="{GRASS}"/>' + detail("M0 94 L128 94", 5)
        + solid(BARN_RED, walls, outline=8)
        + band("M28 66 L42 44 L64 31 L86 44 L100 66", 5, WHITE, 6)
        + solid("#A8372F", '<rect x="50" y="72" width="28" height="30"/>', outline=6)
        + detail("M64 72 L64 102", 4, WHITE) + f'<rect x="50" y="72" width="28" height="30" fill="none" stroke="{WHITE}" stroke-width="3"/>'
        + solid(PAPER, '<circle cx="64" cy="54" r="7"/>', outline=5)
    )


def map_track_pic() -> str:
    return (
        solid(DIRT, '<ellipse cx="64" cy="66" rx="44" ry="32"/>', outline=6)
        + f'<ellipse cx="64" cy="66" rx="44" ry="32" fill="none" stroke="{WHITE}" stroke-width="3"/>'
        + solid(GRASS_DARK, '<ellipse cx="64" cy="66" rx="26" ry="14"/>', outline=6)
        + f'<ellipse cx="64" cy="66" rx="26" ry="14" fill="none" stroke="{WHITE}" stroke-width="2.5"/>'
        + f'<rect x="84" y="84" width="4" height="16" fill="{WHITE}"/>'
        + solid(WHITE, '<rect x="80" y="82" width="12" height="20" rx="2"/>', outline=4)
        + "".join(f'<rect x="{80 + (j % 2) * 6}" y="{82 + i * 5}" width="6" height="5" fill="{INK}"/>' for i in range(4) for j in range(2) if (i + j) % 2 == 0)
    )


def map_fair_pic() -> str:
    flags = ""
    cols = [TEAL, ORANGE, "#2F6FDE", "#CC79A7", GO, ORANGE]
    for i, c in enumerate(cols):
        x = 14 + i * 18
        y = 26 + 6 * math.sin(math.pi * (x - 10) / 108)
        flags += f'<polygon points="{x - 7},{y:.1f} {x + 7},{y:.1f} {x},{y + 14:.1f}" fill="{c}" stroke="{INK}" stroke-width="3" stroke-linejoin="round"/>'
    stripes = "".join(f'<polygon points="64,48 {30 + i * 17},82 {30 + (i + 1) * 17},82" fill="{TEAL if i % 2 == 0 else PAPER}"/>' for i in range(4))
    return (
        f'<path d="M4 24 Q64 38 124 24" fill="none" stroke="{INK}" stroke-width="3"/>' + flags
        + f'<rect x="0" y="102" width="128" height="30" fill="{DIRT_LIGHT}"/>' + detail("M0 102 L128 102", 4)
        + solid(PAPER, '<rect x="36" y="80" width="56" height="24"/>', outline=6)
        + solid(TEAL, '<polygon points="64,48 30,82 98,82"/>', outline=6) + stripes + detail("M64 48 L30 82 L98 82 Z", 5)
        + solid(SLATE, '<path d="M56 104 L56 90 Q64 82 72 90 L72 104 Z"/>', outline=4)
        + band("M64 48 L64 38", 3, INK, 0.01) + f'<polygon points="64,36 76,40 64,44" fill="{ORANGE}" stroke="{INK}" stroke-width="2.5" stroke-linejoin="round"/>'
    )


def vet_emblem(cx: float, cy: float, s: float) -> str:
    """The clinic sign: a heart inside a horseshoe (never a cross)."""
    return horseshoe(cx, cy, 0.5 * s, TEAL, w=6 * s, outline=4 * s) + heart_at(cx, cy + 1 * s, 0.28 * s, HEART, outline=4 * s, gloss=False)


def map_vet_pic() -> str:
    return (
        f'<rect x="0" y="100" width="128" height="30" fill="{GRASS}"/>' + detail("M0 100 L128 100", 4)
        + solid(WHITE, '<rect x="28" y="56" width="72" height="46"/>', outline=8)
        + solid(TEAL, '<polygon points="20,60 64,30 108,60"/>', outline=8)
        + solid(SKY, '<rect x="34" y="66" width="12" height="12" rx="2"/>', '<rect x="82" y="66" width="12" height="12" rx="2"/>', '<rect x="56" y="86" width="16" height="16" rx="2"/>', outline=4)
        + solid(PAPER, '<circle cx="64" cy="70" r="12"/>', outline=5)
        + vet_emblem(64, 70, 1.0)
    )


def map_trail_pic() -> str:
    def tree(x: float, y: float, r: float) -> str:
        return solid(WOOD_DARK, f'<rect x="{x - 3.5}" y="{y}" width="7" height="{r + 6}"/>', outline=5) + solid(LEAF, f'<circle cx="{x}" cy="{y - r * 0.4:.1f}" r="{r}"/>', outline=6)
    pine = solid(GRASS_DARK, '<polygon points="96,26 112,62 80,62"/>', '<polygon points="96,42 116,78 76,78"/>', outline=6) + solid(WOOD_DARK, '<rect x="93" y="78" width="7" height="10"/>', outline=5)
    return (
        f'<path d="M0 72 C30 64 90 62 128 70 L128 130 L0 130 Z" fill="{GRASS}"/>' + detail("M0 72 C30 64 90 62 128 70", 4)
        + solid(DIRT_LIGHT, '<path d="M60 66 C58 78 40 88 44 122 L86 122 C80 98 70 82 68 66 Z"/>', outline=5)
        + tree(30, 60, 15) + pine + tree(108, 96, 10)
    )


def go_button(pressed: bool) -> str:
    """A blank green GO pill (the word is a TextLabel), built like giddyup_pad."""
    if pressed:
        return solid(GO_PRESSED, '<rect x="10" y="22" width="236" height="80" rx="40"/>', outline=10)
    return (
        solid(GO_DARK, '<rect x="10" y="22" width="236" height="80" rx="40"/>', outline=10)
        + solid(GO, '<rect x="10" y="10" width="236" height="80" rx="40"/>', outline=10)
        + f'<rect x="46" y="19" width="164" height="12" rx="6" fill="{WHITE}" opacity="0.3"/>'
    )


def hoofprint() -> str:
    """Trail marker on the ground (GO hoofprints): a light gold shoe print with the frog, readable on grass and dirt."""
    return (
        horseshoe(64, 66, 1.62, GOLD_LIGHT, w=24, outline=12)
        + solid(GOLD_LIGHT, '<path d="M64 58 C72 70 78 82 77 92 C70 97 58 97 51 92 C50 82 56 70 64 58 Z"/>', outline=10)
    )


SHIELD = "M64 14 L104 26 L104 62 C104 88 86 106 64 116 C42 106 24 88 24 62 L24 26 Z"
SHIELD_IN = "M64 26 L93 35 L93 62 C93 82 80 96 64 103 C48 96 35 82 35 62 L35 35 Z"


def league(tier: str) -> str:
    """League badges: Rookie round + horseshoe; Bronze/Silver/Gold shields with 1/2/3 stars; Champion big shield + crown."""
    if tier == "rookie":
        return solid(GRASS, '<circle cx="64" cy="64" r="50"/>') + solid("#9EDB86", '<circle cx="64" cy="64" r="36"/>', outline=6) + horseshoe(64, 66, 0.95, GOLD, w=12, outline=8) + shine(40, 34, 9, 5, -40, 0.45)
    if tier == "champion":
        return place(champion_badge(), 64, 64, 0.93)
    metal, dark = {"bronze": (BRONZE, BRONZE_DARK), "silver": (SILVER, SILVER_DARK), "gold": (GOLD, GOLD_DARK)}[tier]
    spots = {"bronze": [(64, 62, 22)], "silver": [(48, 62, 15), (80, 62, 15)], "gold": [(42, 68, 13), (64, 50, 13), (86, 68, 13)]}[tier]
    return (
        solid(dark, f'<path d="{SHIELD}"/>')
        + solid(metal, f'<path d="{SHIELD_IN}"/>', outline=6)
        + solid(PAPER, *(f'<polygon points="{star_points(x, y, r, r * 0.45)}"/>' for x, y, r in spots), outline=6)
        + shine(48, 40, 7, 3.5, -20, 0.5)
    )


def champion_badge() -> str:
    big = "M64 32 L114 44 L114 74 C114 98 94 114 64 122 C34 114 14 98 14 74 L14 44 Z"
    inner = "M64 44 L102 53 L102 74 C102 92 88 104 64 110 C40 104 26 92 26 74 L26 53 Z"
    leaves = "".join(
        f'<ellipse cx="{64 + side * (14 + k * 4)}" cy="{104 - k * 13}" rx="5" ry="9" transform="rotate({side * (40 - k * 14)} {64 + side * (14 + k * 4)} {104 - k * 13})"/>'
        for side in (-1, 1) for k in range(4)
    )
    crown = '<path d="M38 52 L32 18 L50 34 L64 10 L78 34 L96 18 L90 52 Z"/>'
    return (
        solid(ROYAL_DARK, f'<path d="{big}"/>')
        + solid(ROYAL, f'<path d="{inner}"/>', outline=6)
        + solid(GOLD, leaves, outline=5)
        + solid(GOLD, crown, outline=10)
        + "".join(f'<circle cx="{x}" cy="{y}" r="5" fill="{GOLD}" stroke="{INK}" stroke-width="4"/>' for x, y in ((32, 18), (64, 10), (96, 18)))
        + f'<rect x="40" y="40" width="48" height="6" rx="3" fill="{GOLD_DARK}"/>'
        + solid(PAPER, f'<polygon points="{star_points(64, 82, 13, 6)}"/>', outline=5)
    )


def mini_print(x: float, y: float, s: float = 0.2, fill: str = PAPER, line: str = INK, outline: float = 5) -> str:
    """A small hoofprint: the filled hoof with its shoe line."""
    return (
        f'<g transform="translate({x:g} {y:g}) scale({s:g}) translate(-64 -64)">'
        + solid(fill, f'<path d="{HOOF}"/>', outline=outline / s)
        + f'<path d="{SHOE}" fill="none" stroke="{line}" stroke-width="{3.2 / s:.1f}" stroke-linecap="round"/></g>'
    )


def distance(long: bool) -> str:
    """Race distance: arrow length and the number of hoofprints both change."""
    if long:
        prints = "".join(mini_print(26 + i * 26, 38 if i % 2 == 0 else 52) for i in range(4))
        return prints + band("M24 92 L92 92", 18, DIRT, 12) + solid(DIRT, '<polygon points="90,72 116,92 90,112"/>')
    prints = "".join(mini_print(x, y) for x, y in ((50, 38), (76, 52)))
    return prints + band("M40 92 L70 92", 18, DIRT, 12) + solid(DIRT, '<polygon points="68,72 94,92 68,112"/>')


def surface_dirt() -> str:
    """Dirt course: a track strip running away from you, with hoofprints up the middle."""
    clods = "".join(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{DIRT_DARK}" opacity="0.5"/>' for x, y, r in ((34, 88, 3), (96, 84, 3), (44, 58, 2.5), (84, 62, 2.5)))
    marks = "".join(mini_print(x, y, sc, "#6E4322", DIRT, 0.01) for x, y, sc in ((58, 90, 0.2), (72, 68, 0.16), (60, 50, 0.12)))
    return (
        solid(DIRT, '<path d="M38 38 L90 38 L118 104 L10 104 Z"/>')
        + detail("M40 44 L18 98 M88 44 L110 98", 4, DIRT_LIGHT)
        + clods
        + marks
    )


def surface_turf() -> str:
    blades = "M14 110 L26 58 L38 96 L46 32 L58 92 L66 16 L74 92 L84 36 L92 96 L102 56 L114 110 Z"
    inner = "M34 108 L46 70 L54 104 Z M74 104 L84 62 L94 108 Z"
    return solid(GRASS, f'<path d="{blades}"/>') + f'<path d="{inner}" fill="{GRASS_DARK}"/>' + shine(62, 52, 2.5, 12, 4, 0.4)


def weather_sunny() -> str:
    rays = "".join(
        f'<path d="M{64 + 38 * math.cos(math.radians(a)):.1f} {64 + 38 * math.sin(math.radians(a)):.1f} L{64 + 50 * math.cos(math.radians(a)):.1f} {64 + 50 * math.sin(math.radians(a)):.1f}"/>'
        for a in range(0, 360, 45)
    )
    return (
        f'<g fill="none" stroke="{INK}" stroke-width="22" stroke-linecap="round">{rays}</g><g fill="none" stroke="{GOLD}" stroke-width="10" stroke-linecap="round">{rays}</g>'
        + solid(GOLD, '<circle cx="64" cy="64" r="27"/>')
        + shine(54, 54, 7, 4, -40, 0.55)
    )


def cloud(fill: str = "#EEF3FA") -> str:
    return merged((fill, '<circle cx="40" cy="58" r="18"/><circle cx="64" cy="44" r="22"/><circle cx="90" cy="56" r="18"/><rect x="22" y="54" width="86" height="24" rx="12"/>'))


def weather_rain() -> str:
    def drop(x: float, y: float) -> str:
        return f'<path d="M{x} {y - 13} C{x + 9} {y - 2} {x + 9} {y + 6} {x} {y + 6} C{x - 9} {y + 6} {x - 9} {y - 2} {x} {y - 13} Z"/>'
    return place(cloud(), 64, 52, 0.95) + solid(WATER, drop(40, 102), drop(64, 110), drop(88, 102), outline=8)


def weather_wind() -> str:
    c = "#D6F0FF"
    return (
        band("M14 44 L76 44 C92 44 96 24 82 20 C74 18 68 24 70 32", 11, c, 11)
        + band("M14 70 L96 70 C114 70 118 92 104 96 C96 98 88 92 90 84", 11, c, 11)
        + band("M28 96 L64 96", 11, c, 11)
    )


def lane_dot(full: bool) -> str:
    """Race card lane dot (64x64): taken = filled dot, open = hollow ring."""
    if full:
        return solid(ORANGE, '<circle cx="32" cy="32" r="22"/>', outline=10) + shine(25, 24, 6, 3.5, -40, 0.6)
    return f'<circle cx="32" cy="32" r="20" fill="none" stroke="{INK}" stroke-width="16"/><circle cx="32" cy="32" r="20" fill="none" stroke="{EMPTY}" stroke-width="7"/>'


def stethoscope_body() -> str:
    return (
        band("M40 24 C38 52 48 64 64 66", 8, TEAL, 8)
        + band("M88 24 C90 52 80 64 64 66", 8, TEAL, 8)
        + band("M64 66 C64 96 74 108 88 106 C100 104 102 92 98 84", 8, TEAL, 8)
        + solid(STEEL, '<circle cx="40" cy="20" r="7"/>', '<circle cx="88" cy="20" r="7"/>', outline=8)
        + solid(STEEL, '<circle cx="98" cy="74" r="15"/>', outline=10)
        + solid(STEEL_LIGHT, '<circle cx="98" cy="74" r="8"/>', outline=5)
    )


def tooth_body() -> str:
    d = "M34 30 C34 16 50 14 64 22 C78 14 94 16 94 30 C96 52 90 62 88 78 C86 96 82 110 74 110 C68 110 68 92 64 92 C60 92 60 110 54 110 C46 110 42 96 40 78 C38 62 32 52 34 30 Z"
    return (
        solid(WHITE, f'<path d="{d}"/>')
        + f'<circle cx="52" cy="50" r="4.5" fill="{INK}"/><circle cx="76" cy="50" r="4.5" fill="{INK}"/>'
        + detail("M54 62 C60 68 68 68 74 62", 5)
        + f'<ellipse cx="44" cy="62" rx="5" ry="3.5" fill="{HEART}" opacity="0.45"/><ellipse cx="84" cy="62" rx="5" ry="3.5" fill="{HEART}" opacity="0.45"/>'
        + solid(GOLD_LIGHT, f'<polygon points="{star_points(102, 22, 12, 4, 4)}"/>', outline=6)
    )


def farrier_body() -> str:
    return horseshoe(64, 64, 1.55, STEEL_LIGHT, w=22, outline=12, nails=True)


def vaccine_body() -> str:
    """Vaccinations stamp: a shield with a check (never a needle or a syringe)."""
    return (
        solid(GO, f'<path d="{SHIELD}"/>')
        + band("M44 64 L58 78 L86 46", 12, WHITE, 8)
        + solid(GOLD_LIGHT, f'<polygon points="{star_points(102, 20, 14, 5, 4)}"/>', outline=6)
    )


def potential_body() -> str:
    """Potential revealed: a magnifier over a gold star."""
    return (
        band("M78 78 L108 108", 16, WOOD, 12)
        + solid("#DDF4FF", '<circle cx="54" cy="54" r="34"/>', outline=12)
        + f'<circle cx="54" cy="54" r="34" fill="none" stroke="{STEEL}" stroke-width="7"/>'
        + solid(GOLD, f'<polygon points="{star_points(54, 57, 20, 9)}"/>', outline=6)
        + shine(38, 36, 7, 4, -40, 0.7)
    )


STAMPS: dict[str, tuple[str, str]] = {  # name: (rim colour, inner ring) - one scalloped outline for the whole family
    "checkup": ("#56B4E9", "#2F8FCB"),
    "teeth": ("#6CCB8C", "#3FA463"),
    "farrier": ("#F2A65A", "#D27F2E"),
    "vaccine": (LAVENDER, "#8670BE"),
    "potential": ("#F28CB1", "#D7638E"),
}
STAMP_PICS = {"checkup": stethoscope_body, "teeth": tooth_body, "farrier": farrier_body, "vaccine": vaccine_body, "potential": potential_body}


def stamp(name: str) -> str:
    rim, ring = STAMPS[name]
    return (
        solid(rim, f'<path d="{scallop_path(64, 64, 50, 18, 10)}"/>')
        + f'<circle cx="64" cy="64" r="45" fill="none" stroke="{ring}" stroke-width="3" stroke-dasharray="5 4"/>'
        + solid(PAPER, '<circle cx="64" cy="64" r="38"/>', outline=6)
        + place(STAMP_PICS[name](), 64, 64, 0.52)
    )


def horse_head() -> str:
    """Red bay, calm: small side eye, ears forward, closed mouth (no rider, no whip)."""
    head = ("M20 122 C22 80 34 46 52 30 C52 20 56 12 62 6 C66 12 70 18 70 26 C84 38 98 56 106 72 "
            "C112 82 112 96 102 100 C96 103 88 102 82 99 C74 102 64 100 58 92 C52 86 50 80 52 76 C54 92 60 110 66 122 Z")
    mane = "M52 30 C34 46 22 80 20 122 L34 122 C34 90 42 60 58 38 Z"
    return (
        solid(BAY_DARK, '<path d="M42 30 C42 22 46 14 52 8 C55 16 56 24 54 32 Z"/>', outline=8)
        + solid(BAY, f'<path d="{head}"/>')
        + f'<path d="{mane}" fill="{BAY_DARK}"/>'
        + f'<path d="M60 24 C70 28 74 36 70 44 C66 38 62 32 60 24 Z" fill="{BAY_DARK}"/>'
        + f'<ellipse cx="76" cy="50" rx="3.6" ry="4.6" fill="{INK}"/>'
        + detail("M101 82 C105 83 106 87 104 90", 4) + detail("M88 99 C92 100 95 100 98 98", 3.5)
    )


def compass() -> str:
    needle_n, needle_s = '<polygon points="64,28 74,64 54,64"/>', '<polygon points="54,64 74,64 64,100"/>'
    ticks = "".join(f'<circle cx="{64 + 30 * math.cos(math.radians(a)):.1f}" cy="{64 + 30 * math.sin(math.radians(a)):.1f}" r="{3.5 if a % 90 == 0 else 2}" fill="{INK}"/>' for a in range(0, 360, 45))
    return (
        solid(GOLD_DARK, '<circle cx="64" cy="64" r="50"/>')
        + solid(PAPER, '<circle cx="64" cy="64" r="39"/>', outline=6)
        + ticks
        + f'<g transform="rotate(40 64 64)">' + solid(ORANGE, needle_n, outline=6) + solid(STEEL, needle_s, outline=6) + "</g>"
        + solid(PAPER, '<circle cx="64" cy="64" r="6"/>', outline=5)
        + shine(40, 36, 8, 4, -40, 0.5)
    )


def megaphone() -> str:
    return (
        band("M100 40 C108 46 110 54 108 62 M104 24 C120 36 122 60 112 76", 6, ORANGE, 8)
        + solid(ORANGE, '<rect x="36" y="74" width="14" height="30" rx="5" transform="rotate(-14 43 89)"/>', outline=10)
        + solid(ORANGE, '<path d="M14 54 L84 26 L84 102 L14 74 Z"/>')
        + f'<path d="M40 46 L40 82 M58 39 L58 89" stroke="{WHITE}" stroke-width="7" opacity="0.75"/>'
        + solid(PAPER, '<ellipse cx="86" cy="64" rx="10" ry="38"/>', outline=10)
        + solid(SLATE, '<rect x="8" y="54" width="10" height="20" rx="4"/>', outline=8)
    )


def job_care() -> str:
    return place(brush_body(), 54, 74, 0.78) + heart_at(96, 30, 0.72, outline=9)


def trophy() -> str:
    return (
        band("M36 32 C14 30 14 62 40 64", 8, GOLD, 10) + band("M92 32 C114 30 114 62 88 64", 8, GOLD, 10)
        + solid(GOLD_DARK, '<path d="M56 78 L72 78 L74 96 L54 96 Z"/>', outline=10)
        + solid(GOLD, '<path d="M32 18 L96 18 L96 40 C96 64 82 80 64 80 C46 80 32 64 32 40 Z"/>')
        + solid(WOOD, '<rect x="34" y="94" width="60" height="22" rx="6"/>')
        + f'<rect x="50" y="100" width="28" height="10" rx="3" fill="{PAPER}" opacity="0.9"/>'
        + shine(46, 36, 5, 11, 0, 0.6)
    )


def ribbon_progress() -> str:
    """Blank banner ribbon for the weekly and monthly job progress (code fills the paper track)."""
    dark, fold = "#0F7D74", "#0A5C55"
    return (
        solid(dark, '<path d="M8 24 L46 24 L46 58 L8 58 L20 41 Z"/>', '<path d="M248 24 L210 24 L210 58 L248 58 L236 41 Z"/>', outline=10)
        + f'<path d="M30 50 L46 58 L46 50 Z M226 50 L210 58 L210 50 Z" fill="{fold}"/>'
        + solid(TEAL, '<rect x="26" y="9" width="204" height="41" rx="10"/>', outline=10)
        + solid(PAPER, '<rect x="40" y="20" width="176" height="19" rx="9.5"/>', outline=4)
    )


def stat_icon(stat: str) -> str:
    """Training stats: Sprint Lane (speed) bolt, Gate Break (acceleration) gate + arrow, Hill Climb (stamina) hill + flag,
    Mud Splash (grit) splash. Distinct shape and colour each; none uses label_great's double chevron."""
    if stat == "speed":
        return solid("#FFB020", '<polygon points="76,10 28,70 60,70 46,118 102,50 70,50 88,10"/>') + shine(66, 30, 4, 10, 38, 0.55)
    if stat == "accel":
        return (
            solid("#4CC3FF", '<polygon points="46,48 78,48 78,26 118,62 78,98 78,76 46,76"/>')
            + merged((DIRT_LIGHT, '<circle cx="30" cy="64" r="17"/><circle cx="40" cy="86" r="11"/><circle cx="38" cy="42" r="11"/><circle cx="16" cy="84" r="8"/>'))
            + shine(66, 56, 10, 3, 0, 0.5)
        )
    if stat == "stamina":
        return (
            solid(GRASS, '<path d="M10 110 C28 110 44 52 70 46 C92 42 104 74 118 110 Z"/>')
            + f'<path d="M30 104 C46 96 50 80 62 72" fill="none" stroke="{PAPER}" stroke-width="5" stroke-dasharray="7 6" stroke-linecap="round"/>'
            + band("M70 46 L70 14", 5, WOOD_DARK, 8)
            + solid(GOLD, '<polygon points="73,14 96,22 73,30"/>', outline=7)
        )
    pts = []
    for i in range(48):
        a = 2 * math.pi * i / 48
        r = 30 + 10 * max(0.0, math.cos(6 * a + 0.5)) ** 3 * 1.6 + 3 * math.sin(11 * a)
        pts.append((64 + r * math.cos(a), 66 + r * math.sin(a)))
    drops = [(110, 40, 7), (18, 46, 6), (100, 108, 6), (24, 104, 8), (64, 14, 6)]
    return (
        solid(MUD, f'<path d="{blob_path(pts)}"/>', *(f'<circle cx="{x}" cy="{y}" r="{r}"/>' for x, y, r in drops))
        + f'<path d="{blob_path([(64 + 18 * math.cos(a / 8 * 2 * math.pi) * (1 + 0.15 * math.sin(a * 3)), 62 + 14 * math.sin(a / 8 * 2 * math.pi)) for a in range(8)])}" fill="{MUD_LIGHT}"/>'
        + shine(56, 54, 7, 4, -30, 0.45)
    )


def sleeping_horse() -> str:
    """'All done today!': a red bay lying down asleep (legs tucked, eyes closed, ears up) on straw, small lavender zzz."""
    body = ("M168 86 C150 80 100 80 76 86 C50 92 40 116 46 136 C50 148 62 152 78 152 L182 152 C192 152 198 140 196 124 "
            "C200 116 206 104 210 92 C210 100 218 104 224 102 C228 104 232 106 238 106 C248 106 252 96 246 86 "
            "C242 74 234 60 224 50 C222 44 220 38 216 32 C212 38 210 46 210 54 C196 60 180 72 168 86 Z")
    mane = "M210 54 C196 60 180 72 168 86 L180 90 C188 80 198 70 213 63 Z"
    horse = (
        band("M54 102 C34 106 26 124 30 148", 16, BAY_DARK, 12)
        + solid(BAY_DARK, '<path d="M206 54 C206 46 208 40 212 34 C215 40 216 46 214 54 Z"/>', outline=8)
        + solid(HOOF_DARK, '<rect x="190" y="138" width="22" height="16" rx="6"/>', '<rect x="84" y="144" width="22" height="15" rx="6"/>', outline=8)
        + solid(BAY, f'<path d="{body}"/>')
        + f'<path d="{mane}" fill="{BAY_DARK}"/>'
        + f'<path d="M214 50 C222 52 227 58 225 65 C219 61 215 56 214 50 Z" fill="{BAY_DARK}"/>'
        + detail("M76 128 C82 114 96 108 108 112", 4, "#7E3D20")
        + detail("M220 70 C223 74 228 74 231 70", 4)
        + detail("M242 90 C245 92 245 96 242 98", 3.5)
    )
    straw = solid(HAY, '<ellipse cx="130" cy="156" rx="118" ry="13"/>', outline=8) + "".join(detail(f"M{x} {y} l12 -2", 3, HAY_DARK) for x, y in ((24, 158), (60, 164), (150, 164), (196, 160), (226, 156)))
    mirrored = f'<g transform="translate(262 0) scale(-1 1)">{horse}</g>'

    def z(x: float, y: float, s: float) -> str:
        return band(f"M{x} {y} L{x + s} {y} L{x} {y + s} L{x + s} {y + s}", 6, LAVENDER, 7)
    return straw + mirrored + z(58, 44, 12) + z(78, 26, 15) + z(102, 10, 18)


def welcome_sun() -> str:
    """'Welcome back!': a friendly sun (weather_sunny has bar rays and no face)."""
    rays = "".join(
        f'<polygon points="{64 + 38 * math.cos(math.radians(a - 12)):.1f},{64 + 38 * math.sin(math.radians(a - 12)):.1f} '
        f'{64 + (54 if i % 2 == 0 else 48) * math.cos(math.radians(a)):.1f},{64 + (54 if i % 2 == 0 else 48) * math.sin(math.radians(a)):.1f} '
        f'{64 + 38 * math.cos(math.radians(a + 12)):.1f},{64 + 38 * math.sin(math.radians(a + 12)):.1f}"/>'
        for i, a in enumerate(range(0, 360, 30))
    )
    return (
        solid(ORANGE, rays, outline=10)
        + solid(GOLD, '<circle cx="64" cy="64" r="38"/>')
        + detail("M46 60 C49 54 55 54 58 60 M70 60 C73 54 79 54 82 60", 5)
        + detail("M50 72 C56 82 72 82 78 72", 5)
        + f'<ellipse cx="42" cy="72" rx="6" ry="4" fill="#FF8A65" opacity="0.6"/><ellipse cx="86" cy="72" rx="6" ry="4" fill="#FF8A65" opacity="0.6"/>'
    )


def camera() -> str:
    body = "#5A6B8C"
    return (
        solid(body, '<rect x="24" y="28" width="28" height="16" rx="5"/>', '<rect x="82" y="30" width="18" height="10" rx="3"/>', outline=10)
        + solid(body, '<rect x="12" y="38" width="104" height="70" rx="16"/>')
        + f'<rect x="20" y="46" width="88" height="10" rx="5" fill="{WHITE}" opacity="0.18"/>'
        + solid(STEEL_LIGHT, '<circle cx="64" cy="74" r="26"/>', outline=8)
        + solid("#2B3A5C", '<circle cx="64" cy="74" r="15"/>', outline=5)
        + f'<circle cx="58" cy="68" r="5" fill="{SKY}" opacity="0.9"/>'
        + solid(GOLD_LIGHT, '<rect x="92" y="48" width="14" height="9" rx="3"/>', outline=4)
    )


def gift() -> str:
    box, lid = "#8E7CC3", "#7462AE"
    return (
        solid(GOLD, '<ellipse cx="47" cy="32" rx="17" ry="10" transform="rotate(-22 47 32)"/>', '<ellipse cx="81" cy="32" rx="17" ry="10" transform="rotate(22 81 32)"/>', outline=10)
        + solid(box, '<rect x="22" y="60" width="84" height="54" rx="6"/>')
        + solid(lid, '<rect x="16" y="44" width="96" height="22" rx="6"/>')
        + f'<rect x="56" y="44" width="16" height="70" fill="{GOLD}"/>'
        + detail("M56 44 L56 114 M72 44 L72 114", 4)
        + detail("M16 66 L112 66", 5)
        + solid(GOLD, '<circle cx="64" cy="40" r="8"/>', outline=8)
    )


def lock() -> str:
    return (
        band("M40 60 L40 44 C40 18 88 18 88 44 L88 60", 13, STEEL, 12)
        + solid(GOLD, '<rect x="24" y="54" width="80" height="60" rx="14"/>')
        + f'<circle cx="64" cy="78" r="8" fill="{INK}"/><path d="M59 80 L69 80 L71 98 L57 98 Z" fill="{INK}"/>'
        + shine(38, 66, 4, 8, 0, 0.6)
    )


def person(cx: float, top: float, h: float, colour: str, smile: bool = True) -> str:
    """A friendly figure: head and rounded shoulders, height h from top."""
    r = h * 0.16
    hy = top + r
    body_top = top + 2 * r + h * 0.06
    w = h * 0.30
    body = f'<path d="M{cx - w:.1f} {top + h:.1f} C{cx - w:.1f} {body_top + h * 0.12:.1f} {cx - w * 0.6:.1f} {body_top:.1f} {cx:.1f} {body_top:.1f} C{cx + w * 0.6:.1f} {body_top:.1f} {cx + w:.1f} {body_top + h * 0.12:.1f} {cx + w:.1f} {top + h:.1f} Z"/>'
    face = detail(f"M{cx - r * 0.4:.1f} {hy + r * 0.25:.1f} C{cx - r * 0.2:.1f} {hy + r * 0.55:.1f} {cx + r * 0.2:.1f} {hy + r * 0.55:.1f} {cx + r * 0.4:.1f} {hy + r * 0.25:.1f}", 3.5) if smile else ""
    return solid(colour, body) + solid(colour, f'<circle cx="{cx:.1f}" cy="{hy:.1f}" r="{r:.1f}"/>') + face


def friends() -> str:
    return person(42, 22, 90, TEAL) + person(86, 30, 86, ORANGE)


def settings() -> str:
    n, tip, root = 8, 52, 40
    pts = []
    for i in range(n):
        a = 2 * math.pi * i / n
        for da, r in ((-0.30, root), (-0.17, tip), (0.17, tip), (0.30, root)):
            pts.append(f"{64 + r * math.cos(a + da):.1f} {64 + r * math.sin(a + da):.1f}")
    gear = "M" + " L".join(pts) + " Z M64 48 A16 16 0 1 0 64 80 A16 16 0 1 0 64 48 Z"
    return (
        f'<path d="{gear}" fill="{STEEL}" fill-rule="evenodd" stroke="{INK}" stroke-width="12" stroke-linejoin="round" paint-order="stroke"/>'
        + f'<circle cx="64" cy="64" r="26" fill="none" stroke="{STEEL_LIGHT}" stroke-width="5"/>'
    )


def grownups() -> str:
    """'For grown-ups': an adult and a child holding hands."""
    return (
        band("M58 82 C66 92 72 94 80 92", 7, "#4C6FB8", 8)
        + person(44, 14, 104, "#4C6FB8")
        + person(90, 52, 66, GOLD)
    )


# Clarity pass (D-064, horse-life stage 3): one symbol per meaning. Energy is a horseshoe, monthly stamps a
# rosette, a good family line a sprout, and league badges count with dots (★ means only how you rode).
def energy_shoe(full: bool) -> str:
    """Energy pip: a horseshoe. Full: warm orange with nail holes. Spent: a thin hollow grey shoe (shape and colour change)."""
    if full:
        return horseshoe(64, 66, 1.65, ENERGY, w=22, outline=12, nails=True) + shine(36, 52, 4, 9, 20, 0.55)
    return horseshoe(64, 66, 1.65, EMPTY, w=12, outline=10)


ROSETTE = "#F27BB0"
ROSETTE_DARK = "#C9508A"


def rosette() -> str:
    """Monthly stamp (🎀): a pleated rosette with two tails and a paper middle (no star)."""
    return (
        solid(ROSETTE_DARK, '<path d="M46 66 L30 118 L44 110 L52 122 L62 74 Z"/>', '<path d="M82 66 L98 118 L84 110 L76 122 L66 74 Z"/>', outline=10)
        + solid(ROSETTE, f'<path d="{scallop_path(64, 54, 44, 16, 9)}"/>')
        + f'<circle cx="64" cy="54" r="34" fill="none" stroke="{ROSETTE_DARK}" stroke-width="4" stroke-dasharray="6 5"/>'
        + solid(PAPER, '<circle cx="64" cy="54" r="22"/>', outline=6)
        + solid(GOLD, '<circle cx="64" cy="54" r="9"/>', outline=4)
        + shine(46, 34, 7, 4, -35, 0.5)
    )


def sprout() -> str:
    """Good family line in the market (🌱): two round leaves on a stem in a mound of soil."""
    return (
        solid(DIRT_DARK, '<ellipse cx="64" cy="106" rx="40" ry="14"/>', outline=10)
        + band("M64 104 C64 86 64 72 66 58", 9, LEAF, 10)
        + solid(GRASS, '<path d="M64 66 C46 70 22 60 18 36 C40 30 60 42 64 66 Z"/>')
        + solid(GRASS, '<path d="M66 58 C74 36 98 22 114 30 C112 52 90 64 66 58 Z"/>')
        + detail("M60 62 C48 56 36 48 28 40", 4, GRASS_DARK)
        + detail("M70 54 C82 44 96 36 106 34", 4, GRASS_DARK)
        + shine(36, 44, 6, 3, -30, 0.5)
    )


def badge(tier: str) -> str:
    """League badges without stars: Rookie round + horseshoe; Bronze/Silver/Gold shields with 1/2/3 paper dots; Champion crown + dot."""
    if tier == "rookie":  # no horseshoe here: the horseshoe means Energy
        return (solid(GRASS, '<circle cx="64" cy="64" r="50"/>') + solid("#9EDB86", '<circle cx="64" cy="64" r="36"/>', outline=6)
                + f'<circle cx="64" cy="64" r="16" fill="none" stroke="{INK}" stroke-width="12"/>'
                + f'<circle cx="64" cy="64" r="16" fill="none" stroke="{PAPER}" stroke-width="6"/>' + shine(40, 34, 9, 5, -40, 0.45))
    if tier == "champion":
        return league("champion").replace(
            f'<polygon points="{star_points(64, 82, 13, 6)}"/>', '<circle cx="64" cy="82" r="11"/>')
    metal, dark = {"bronze": (BRONZE, BRONZE_DARK), "silver": (SILVER, SILVER_DARK), "gold": (GOLD, GOLD_DARK)}[tier]
    spots = {"bronze": [(64, 62, 16)], "silver": [(48, 62, 12), (80, 62, 12)], "gold": [(42, 68, 10), (64, 50, 10), (86, 68, 10)]}[tier]
    return (
        solid(dark, f'<path d="{SHIELD}"/>')
        + solid(metal, f'<path d="{SHIELD_IN}"/>', outline=6)
        + solid(PAPER, *(f'<circle cx="{x}" cy="{y}" r="{r}"/>' for x, y, r in spots), outline=6)
        + shine(48, 40, 7, 3.5, -20, 0.5)
    )


CLARITY_NAMES = ["energy_shoe", "energy_shoe_empty", "rosette", "sprout"] + [f"badge_{t}" for t in ("rookie", "bronze", "silver", "gold", "champion")]


def clarity_assets() -> dict[str, tuple[int, int, str]]:
    c: dict[str, tuple[int, int, str]] = {
        "energy_shoe": (128, 128, energy_shoe(True)),
        "energy_shoe_empty": (128, 128, energy_shoe(False)),
        "rosette": (128, 128, rosette()),
        "sprout": (128, 128, sprout()),
    }
    for tier in ("rookie", "bronze", "silver", "gold", "champion"):
        c[f"badge_{tier}"] = (128, 128, badge(tier))
    return c


def world_assets() -> dict[str, tuple[int, int, str]]:
    w: dict[str, tuple[int, int, str]] = {
        "cash": (128, 128, cash()),
        "diamond": (128, 128, diamond()),
        "hay": (128, 128, hay()),
        "grain": (128, 128, grain()),
        "carrot": (128, 128, carrot()),
        "apple": (128, 128, apple()),
        "oats": (128, 128, oats()),
        "seed_carrot": (128, 128, seed_packet(GRASS, GRASS_DARK, carrot())),
        "seed_apple": (128, 128, seed_packet("#62B8F0", "#3A92CF", apple())),
        "seed_oats": (128, 128, seed_packet("#A58FD0", "#8270B4", oats())),
        "treat": (128, 128, treat()),
        "brush": (128, 128, brush()),
        "energy_hoof": (128, 128, energy_hoof(True)),
        "energy_hoof_empty": (128, 128, energy_hoof(False)),
        "heart": (128, 128, heart()),
        "care_star": (128, 128, care_star()),
        "flag_ready": (128, 128, flag_ready()),
        "zzz_resting": (128, 128, zzz_resting()),
        "clipboard": (128, 128, clipboard()),
        "map": (128, 128, map_icon()),
        "map_stable": (128, 128, map_tile("map_stable", SKY, map_stable_pic())),
        "map_track": (128, 128, map_tile("map_track", "#7CCB62", map_track_pic())),
        "map_fair": (128, 128, map_tile("map_fair", "#FFCF5C", map_fair_pic())),
        "map_vet": (128, 128, map_tile("map_vet", "#C8B6EC", map_vet_pic())),
        "map_trail": (128, 128, map_tile("map_trail", "#FFC48C", map_trail_pic())),
        "go_button": (256, 112, go_button(False)),
        "go_button_pressed": (256, 112, go_button(True)),
        "hoofprint": (128, 128, hoofprint()),
        "dist_short": (128, 128, distance(False)),
        "dist_long": (128, 128, distance(True)),
        "surface_dirt": (128, 128, surface_dirt()),
        "surface_turf": (128, 128, surface_turf()),
        "weather_sunny": (128, 128, weather_sunny()),
        "weather_rain": (128, 128, weather_rain()),
        "weather_wind": (128, 128, weather_wind()),
        "lane_dot_empty": (64, 64, lane_dot(False)),
        "lane_dot_full": (64, 64, lane_dot(True)),
        "job_care": (128, 128, job_care()),
        "job_ride": (128, 128, place(horse_head(), 64, 64, 0.88)),
        "job_explore": (128, 128, compass()),
        "job_cheer": (128, 128, megaphone()),
        "trophy": (128, 128, trophy()),
        "ribbon_progress": (256, 64, ribbon_progress()),
        "stethoscope": (128, 128, stethoscope_body()),
        "sleeping_horse": (256, 176, sleeping_horse()),
        "welcome_sun": (128, 128, welcome_sun()),
        "camera": (128, 128, camera()),
        "gift": (128, 128, gift()),
        "lock": (128, 128, lock()),
        "friends": (128, 128, friends()),
        "settings": (128, 128, settings()),
        "grownups": (128, 128, grownups()),
    }
    for tier in ("rookie", "bronze", "silver", "gold", "champion"):
        w[f"league_{tier}"] = (128, 128, league(tier))
    for name in STAMPS:
        w[f"stamp_{name}"] = (128, 128, stamp(name))
    for stat in ("speed", "accel", "stamina", "grit"):
        w[f"stat_{stat}"] = (128, 128, stat_icon(stat))
    w.update(clarity_assets())
    return w


WORLD_SECTIONS: list[tuple[str, list[str]]] = [
    ("Wallet, food and care items (Feed and Seed, garden, chores)", ["cash", "diamond", "hay", "grain", "carrot", "apple", "oats", "treat", "brush"]),
    ("Garden seeds: one packet shape, crop picture + packet colour per crop", ["seed_carrot", "seed_apple", "seed_oats"]),
    ("Horse status: Energy full vs empty (filled vs hollow), bond, care, Stable Board faces", ["energy_hoof", "energy_hoof_empty", "heart", "care_star", "flag_ready", "zzz_resting"]),
    ("HUD buttons", ["clipboard", "map", "camera", "gift", "lock", "friends", "settings", "grownups", "go_button", "go_button_pressed"]),
    ("Map fast-travel pictures (one tile shape, distinct colour + picture) and the GO trail hoofprint", ["map_stable", "map_track", "map_fair", "map_vet", "map_trail", "hoofprint"]),
    ("Race Board: league (shape + star count), distance (length + prints), surface, weather, lane dots (ring vs dot)",
     ["league_rookie", "league_bronze", "league_silver", "league_gold", "league_champion", "dist_short", "dist_long", "surface_dirt", "surface_turf",
      "weather_sunny", "weather_rain", "weather_wind", "lane_dot_empty", "lane_dot_full"]),
    ("Health Passport stamps (one scalloped outline, distinct colour + picture) and the check-up tool", ["stamp_checkup", "stamp_teeth", "stamp_farrier", "stamp_vaccine", "stamp_potential", "stethoscope"]),
    ("Stable Board: jobs, rewards, progress ribbon, all done, welcome back", ["job_care", "job_ride", "job_explore", "job_cheer", "trophy", "ribbon_progress", "sleeping_horse", "welcome_sun"]),
    ("Training stats: Sprint Lane (Speed), Gate Break (Acceleration), Hill Climb (Stamina), Mud Splash (Grit)", ["stat_speed", "stat_accel", "stat_stamina", "stat_grit"]),
    ("Clarity pass (D-064): Energy horseshoe full vs spent, monthly-stamp rosette, family-line sprout, league badges with dots (no stars)", CLARITY_NAMES),
]


def world_sheet(w: dict[str, tuple[int, int, str]]) -> str:
    """Review sheet for the world set: every icon at size, then 32 px and solid-black silhouettes (the 32 px test)."""
    width, pad, row_h = 1240, 24, 112
    out = [
        '<defs><filter id="sil" color-interpolation-filters="sRGB"><feFlood flood-color="#000"/><feComposite in2="SourceAlpha" operator="in"/></filter></defs>',
        caption(width / 2, 44, "Giddy-Up world UI (stables, care, Race Board, Stable Board, Health Passport)", 24, True),
    ]
    y = 70.0
    for title, names in WORLD_SECTIONS:
        out.append(caption(pad, y + 6, title, 15, True, "start"))
        y += 18
        x = float(pad)
        for name in names:
            vw, vh, body = w[name]
            s = min(row_h / vh, 1.0, 256 / vw)
            dw, dh = vw * s, vh * s
            cell = max(dw, 112)
            if x + cell > width - pad:
                x, y = float(pad), y + row_h + 34
            out.append(nested(x + (cell - dw) / 2, y + (row_h - dh) / 2, dw, dh, vw, vh, body))
            out.append(caption(x + cell / 2, y + row_h + 16, name, 12))
            x += cell + 16
        if title.startswith("Map"):
            for bg in (GRASS, DIRT):
                out.append(f'<rect x="{x}" y="{y}" width="{row_h}" height="{row_h}" rx="14" fill="{bg}"/>')
                out.append(nested(x + 12, y + 12, row_h - 24, row_h - 24, 128, 128, w["hoofprint"][2]))
                out.append(caption(x + row_h / 2, y + row_h + 16, "hoofprint (on grass)" if bg == GRASS else "hoofprint (on dirt)", 12))
                x += row_h + 16
        y += row_h + 44
    out.append(caption(pad, y + 6, "Readability: every icon at 32 px, and as a solid black silhouette at 32 px", 15, True, "start"))
    y += 22
    for filt in ("", ' filter="url(#sil)"'):
        x = float(pad)
        for name in [n for _, names in WORLD_SECTIONS for n in names]:
            vw, vh, body = w[name]
            s = 32 / max(vw, vh)
            if x + 40 > width - pad:
                x, y = float(pad), y + 44
            out.append(f'<g{filt}>{nested(x, y + (32 - vh * s) / 2, vw * s, vh * s, vw, vh, body)}</g>')
            x += 40
        y += 52
    body = f'<rect width="100%" height="100%" fill="#F4EBD9"/>' + "".join(out)
    return svg(width, int(y + 10), body)


def svg(w: int, h: int, body: str) -> str:
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{body}</svg>\n'


def nested(x: float, y: float, w: float, h: float, vw: int, vh: int, body: str) -> str:
    return f'<svg x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" viewBox="0 0 {vw} {vh}">{body}</svg>'


def caption(x: float, y: float, s: str, size: int = 13, bold: bool = False, anchor: str = "middle") -> str:
    fw = ' font-weight="bold"' if bold else ""
    return f'<text x="{x:.1f}" y="{y:.1f}" font-family="Arial, sans-serif" font-size="{size}"{fw} fill="{INK}" text-anchor="{anchor}">{s}</text>'


def ring_panel(x: float, y: float, w: float, h: float, beats_per_s: float, title: str, contact: bool = False) -> str:
    """Several rings at once: each closes in RING_CLOSE_S, so faster tempo = tighter spacing."""
    cx, cy, hoof_px = x + w / 2, y + h / 2 + 4, 48
    rc = hoof_px * 0.47  # ring radius at contact (sits on the hoof rim)
    out = [f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="16" fill="{DIRT}"/>', nested(cx - hoof_px / 2, cy - hoof_px / 2, hoof_px, hoof_px, 128, 128, hoof_glyph())]
    gap = 1 / beats_per_s
    first = 0.0 if contact else 0.12
    rings = [first + k * gap for k in range(6) if first + k * gap < RING_CLOSE_S]
    for k, t in reversed(list(enumerate(rings))):
        r = rc * (1 + (RING_SPAWN - 1) * t / RING_CLOSE_S)
        colour = GOLD if contact and k == 0 else WHITE
        out.append(ring_circle(cx, cy, r, 6, colour, RING_ALPHA[min(k, len(RING_ALPHA) - 1)]))
    if contact:
        out.append(nested(cx + 26, y + 8, 42, 42, 128, 128, feedback("perfect")))
    out.append(caption(cx, y + h + 18, title))
    return "".join(out)


def sheet(a: dict[str, tuple[int, int, str]]) -> str:
    width, pad, row_h = 1240, 24, 128
    out = [caption(width / 2, 44, "Giddy-Up race UI (council-reviewed set)", 26, True)]
    y = 70.0

    def section(title: str) -> None:
        nonlocal y
        out.append(caption(pad, y + 6, title, 15, True, "start"))
        y += 18

    def flow(names: list[str], max_h: float = row_h) -> None:
        nonlocal y
        x = float(pad)
        for name in names:
            w, h, body = a[name]
            s = min(max_h / h, (row_h * 3) / w, 1.0 if w > 256 else max_h / h)
            dw, dh = w * s, h * s
            cell = max(dw, 110)
            if x + cell > width - pad:
                x, y = float(pad), y + max_h + 34
            out.append(nested(x + (cell - dw) / 2, y + (max_h - dh) / 2, dw, dh, w, h, body))
            out.append(caption(x + cell / 2, y + max_h + 16, name, 12))
            x += cell + 18
        y += max_h + 40

    section("Giddy-up stride: tap anywhere; the ring is the target, the pad is only the affordance")
    flow(["hoof", "hoof_ring", "giddyup_pad", "giddyup_pad_pressed"])
    flow([f"label_{n}" for n in FEEDBACK] + ["chance_up", "chance_down"], 100)
    section(f"Several rings at once (each closes in {RING_CLOSE_S:g} s from {RING_SPAWN:g}x; tempo shows as spacing; next ring opaque, later ones faded)")
    pw, ph = 270, 190
    panels = [(2.0, "2 beats/s (Rookie steady)", False), (2.6, "2.6 beats/s (faster: tighter)", False), (1.6, "1.6 beats/s (slower: wider)", False), (2.0, "contact + tap = Perfect", True)]
    for i, (bps, title, contact) in enumerate(panels):
        out.append(ring_panel(pad + i * (pw + 26), y, pw, ph, bps, title, contact))
    y += ph + 44
    section("Lanes: fixed colour + pattern + number; sparkle overlay = another rider's Perfect burst")
    flow([f"lane_{n}" for n in range(1, 9)], 100)
    flow([f"lane_{n}_sparkle" for n in range(1, 9)], 100)
    section("Race and results")
    flow(["you_marker"] + [f"ribbon_{r[0]}" for r in RIBBONS] + ["finish_checker"], 150)
    section("Beat effects (particle textures, white so the emitter tints them; shown on dirt)")
    x0 = pad
    for name, tint in (("fx_dust_puff", "#E3B985"), ("fx_mane_flick", "#1D2433")):
        out.append(f'<rect x="{x0}" y="{y}" width="128" height="128" rx="14" fill="{DIRT}"/>')
        body = a[name][2].replace(f'stop-color="{WHITE}"', f'stop-color="{tint}"').replace(f'stroke="{WHITE}"', f'stroke="{tint}"')
        out.append(nested(x0, y, 128, 128, 128, 128, body))
        out.append(caption(x0 + 64, y + 146, f"{name} (tinted {tint})", 12))
        x0 += 200
    y += 172
    section("Final Burst (bar, glow and marker composed; rays play after scoring, own screen only)")
    bw = width - 2 * pad - 200
    bh = bw * 160 / 1024
    sx = 160 / 144
    composed = (
        burst_bar()
        + f'<g transform="translate({632 - 128 * sx:.1f},0) scale({sx:.3f},1)">{burst_glow("sheet_glow")}</g>'
        + f'<g transform="translate({340 - 32 * 0.9:.1f},-12) scale(0.9)">{burst_marker()}</g>'
    )
    out.append(nested(pad, y, bw, bh, 1024, 160, f'<g transform="translate(0,16)">{composed}</g>'))
    out.append(f'<rect x="{pad + bw + 30}" y="{y - 10}" width="170" height="170" rx="16" fill="#8ED6FF"/>')
    out.append(nested(pad + bw + 35, y - 5, 160, 160, 256, 256, burst_rays("sheet_rays")))
    out.append(caption(pad + bw + 115, y + 178, "burst_rays", 12))
    y += max(bh, 170) + 40
    body = f'<rect width="100%" height="100%" fill="#F4EBD9"/>' + "".join(out)
    return svg(width, int(y), body)


def write_if_changed(path: Path, data: str | bytes) -> bool:
    """Leave a file alone when its content is unchanged (text compared without line-ending noise)."""
    if path.exists():
        if isinstance(data, bytes):
            if path.read_bytes() == data:
                return False
        elif path.read_text(encoding="utf-8").replace("\r\n", "\n") == data:
            return False
    if isinstance(data, bytes):
        path.write_bytes(data)
    else:
        path.write_text(data, encoding="utf-8", newline="\n")
    return True


def export_pngs(names: list[str]) -> str:
    try:
        import resvg_py
    except ImportError:
        return "PNG export skipped: pip install resvg-py, then rerun"
    PNG_OUT.mkdir(parents=True, exist_ok=True)
    changed = 0
    for name in names:
        data = resvg_py.svg_to_bytes(svg_path=str(OUT / f"{name}.svg"), zoom=PNG_ZOOM)
        changed += write_if_changed(PNG_OUT / f"{name}.png", bytes(data))
    return f"rendered {len(names)} PNGs at {PNG_ZOOM}x to {PNG_OUT} ({changed} changed)"


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--no-png", action="store_true")
    args = ap.parse_args(argv)
    OUT.mkdir(parents=True, exist_ok=True)
    race, world = assets(), world_assets()
    clash = set(race) & set(world)
    if clash:
        raise SystemExit(f"world icon names clash with race icons: {sorted(clash)}")
    a = {**race, **world}
    for stale in OUT.glob("*.svg"):
        if stale.stem not in a and not stale.name.startswith("_sheet"):
            stale.unlink()
    for name, (w, h, body) in a.items():
        write_if_changed(OUT / f"{name}.svg", svg(w, h, body))
    write_if_changed(OUT / "_sheet.svg", sheet(race))
    write_if_changed(OUT / "_sheet_world.svg", world_sheet(world))
    print(f"make_ui_svgs: {len(race)} race + {len(world)} world SVGs, _sheet.svg and _sheet_world.svg in {OUT}")
    if not args.no_png:
        if PNG_OUT.is_dir():
            for stale in PNG_OUT.glob("*.png"):
                if stale.stem not in a:
                    stale.unlink()
        print(export_pngs(sorted(a)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
