#!/usr/bin/env python3
"""Generate the placeholder art in assets/placeholder/.

Flat shapes on transparent PNGs at 2x target size, per plan section 11.
The handmade art pass replaces these files by filename -- no scene edits.
Run from the project root:  python3 tools/gen_placeholders.py
"""

import os
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "assets", "placeholder")

# Flat placeholder palette. Deliberately drab so real art reads as an upgrade.
BRASS = (198, 158, 74, 255)
BRASS_DARK = (128, 98, 38, 255)
GLASS = (206, 226, 232, 255)
SAND = (226, 190, 116, 255)
STEEL = (122, 132, 142, 255)
STEEL_DARK = (74, 82, 92, 255)
PANEL = (46, 50, 60, 255)
PANEL_EDGE = (96, 104, 120, 255)
BOARD = (108, 82, 52, 255)
LCD = (28, 44, 34, 255)
LCD_EDGE = (72, 108, 84, 255)
RED = (198, 62, 58, 255)
FLAME = (240, 158, 52, 255)
WHITE = (232, 236, 244, 255)
DIM = (86, 92, 104, 255)


def new(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def save(img, name):
    img.save(os.path.join(OUT, name))
    print("  " + name, img.size)


def hourglass_frame():
    """The frame doubles as a mask.

    Everything outside the two bulbs is opaque; the bulb interiors are
    transparent. The station draws a plain sand rectangle *behind* this and
    lets the holes shape it, which is why the sand fill can be a dumb
    stretched quad instead of a custom polygon.

    Bulb geometry is mirrored in HourglassStation.TOP_BULB / BOTTOM_BULB --
    if the art pass changes these rects, change them there too.
    """
    w, h = 440, 520
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # Opaque cabinet plate.
    d.rounded_rectangle([0, 0, w - 1, h - 1], radius=28, fill=(38, 41, 50, 255))
    # Punch the two bulbs out of it.
    top = [(48, 44), (w - 48, 44), (w // 2, h // 2)]
    bottom = [(48, h - 44), (w - 48, h - 44), (w // 2, h // 2)]
    d.polygon(top, fill=(0, 0, 0, 0))
    d.polygon(bottom, fill=(0, 0, 0, 0))
    # Brass trim on top of the plate.
    d.polygon(top, outline=BRASS_DARK, width=8)
    d.polygon(bottom, outline=BRASS_DARK, width=8)
    d.rectangle([20, 8, w - 20, 44], fill=BRASS)
    d.rectangle([20, h - 44, w - 20, h - 9], fill=BRASS)
    d.rectangle([w // 2 - 22, h // 2 - 16, w // 2 + 22, h // 2 + 16], fill=BRASS_DARK)
    save(img, "hourglass_frame.png")


def hourglass_sand():
    # A plain fill swatch; the station stretches it to the drained height.
    img = new(400, 400)
    ImageDraw.Draw(img).rectangle([0, 0, 399, 399], fill=SAND)
    save(img, "hourglass_sand.png")


def clock_face():
    s = 480
    img = new(s, s)
    d = ImageDraw.Draw(img)
    d.ellipse([0, 0, s - 1, s - 1], fill=BRASS, outline=BRASS_DARK, width=16)
    d.ellipse([44, 44, s - 45, s - 45], fill=WHITE)
    for i in range(12):
        import math
        a = math.radians(i * 30 - 90)
        r0, r1 = s / 2 - 74, s / 2 - 52
        cx = cy = s / 2
        d.line([(cx + r0 * math.cos(a), cy + r0 * math.sin(a)),
                (cx + r1 * math.cos(a), cy + r1 * math.sin(a))],
               fill=STEEL_DARK, width=8)
    d.line([(s / 2, s / 2), (s / 2, 120)], fill=STEEL_DARK, width=12)
    d.line([(s / 2, s / 2), (s - 140, s / 2)], fill=STEEL_DARK, width=8)
    save(img, "clock_face.png")


def clock_key():
    s = 160
    img = new(s, s)
    d = ImageDraw.Draw(img)
    # Winding key: round bow with a square shaft.
    d.ellipse([16, 16, s - 17, s - 17], fill=BRASS, outline=BRASS_DARK, width=10)
    d.ellipse([54, 54, s - 55, s - 55], fill=(0, 0, 0, 0))
    d.rectangle([s // 2 - 14, s // 2 - 14, s // 2 + 14, s // 2 + 14], fill=BRASS_DARK)
    save(img, "clock_key.png")


def clock_gauge():
    w, h = 520, 120
    img = new(w, h)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, w - 1, h - 1], radius=18, fill=PANEL,
                        outline=BRASS_DARK, width=8)
    save(img, "clock_gauge.png")


def safe_door():
    s = 600
    img = new(s, s)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, s - 1, s - 1], radius=24, fill=STEEL,
                        outline=STEEL_DARK, width=14)
    d.rounded_rectangle([44, 44, s - 45, s - 45], radius=16, outline=STEEL_DARK,
                        width=8)
    d.ellipse([s // 2 - 70, s // 2 - 70, s // 2 + 70, s // 2 + 70], fill=STEEL_DARK)
    d.ellipse([s // 2 - 34, s // 2 - 34, s // 2 + 34, s // 2 + 34], fill=BRASS)
    save(img, "safe_door.png")


def safe_keypad_key():
    s = 140
    img = new(s, s)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, s - 1, s - 1], radius=14, fill=STEEL,
                        outline=STEEL_DARK, width=8)
    save(img, "safe_keypad_key.png")


def safe_lcd():
    w, h = 600, 100
    img = new(w, h)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, w - 1, h - 1], fill=LCD, outline=LCD_EDGE, width=8)
    save(img, "safe_lcd.png")


def safe_symbols():
    # Arcane glyphs for safe tier 2. Distinct enough to tell apart at a glance,
    # meaningless enough that you have to consult the codex.
    s = 96
    m = 18
    strokes = {
        0: [[(m, m), (s - m, s - m)], [(s - m, m), (m, s - m)]],
        1: [[(s // 2, m), (s // 2, s - m)]],
        2: [[(m, m), (s - m, m), (m, s - m), (s - m, s - m)]],
        3: [[(m, m), (s - m, s // 2), (m, s - m)]],
        4: [[(m, s // 2), (s - m, s // 2)], [(s // 2, m), (s // 2, s - m)]],
        5: [[(s - m, m), (m, m), (m, s // 2), (s - m, s // 2), (s - m, s - m),
             (m, s - m)]],
        6: [[(s - m, m), (m, s // 2), (s - m, s - m)]],
        7: [[(m, m), (s - m, m), (s // 2, s - m)]],
        8: [[(m, m), (s - m, m), (s - m, s - m), (m, s - m), (m, m)]],
        9: [[(m, s - m), (s // 2, m), (s - m, s - m)], [(m + 12, s // 2),
                                                        (s - m - 12, s // 2)]],
    }
    for digit, paths in strokes.items():
        img = new(s, s)
        d = ImageDraw.Draw(img)
        for path in paths:
            d.line(path, fill=WHITE, width=8, joint="curve")
        save(img, "safe_symbol_%d.png" % digit)


def codex_page():
    w, h = 400, 600
    img = new(w, h)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, w - 1, h - 1], fill=(226, 214, 184, 255),
                outline=BOARD, width=10)
    save(img, "codex_page.png")


def rocket_body():
    w, h = 120, 320
    img = new(w, h)
    d = ImageDraw.Draw(img)
    d.polygon([(w // 2, 0), (w - 12, 110), (12, 110)], fill=RED)
    d.rectangle([12, 100, w - 12, h - 50], fill=WHITE)
    d.polygon([(12, h - 90), (12, h - 10), (0, h - 10)], fill=RED)
    d.polygon([(w - 12, h - 90), (w - 12, h - 10), (w, h - 10)], fill=RED)
    d.rectangle([26, h - 50, w - 26, h - 10], fill=STEEL_DARK)
    d.ellipse([w // 2 - 22, 140, w // 2 + 22, 184], fill=GLASS, outline=STEEL_DARK,
              width=6)
    save(img, "rocket_body.png")


def rocket_flame():
    w, h = 100, 140
    img = new(w, h)
    d = ImageDraw.Draw(img)
    d.polygon([(w // 2, h), (w - 6, 40), (w // 2, 0), (6, 40)], fill=FLAME)
    save(img, "rocket_flame.png")


def launchpad():
    w, h = 400, 80
    img = new(w, h)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 24, w - 1, h - 1], fill=STEEL_DARK)
    d.rectangle([60, 0, 92, 30], fill=STEEL)
    d.rectangle([w - 92, 0, w - 60, 30], fill=STEEL)
    save(img, "launchpad.png")


def panel(name, fill, edge, boarded=False):
    # 9-patch source: 96x96 with a 24px border, so panels scale without smearing.
    s = 96
    img = new(s, s)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, s - 1, s - 1], fill=fill)
    d.rectangle([0, 0, s - 1, s - 1], outline=edge, width=8)
    if boarded:
        d.line([(0, 26), (s, 26)], fill=BOARD, width=14)
        d.line([(0, 68), (s, 68)], fill=BOARD, width=14)
    save(img, name)


def vignette():
    """Screen-edge falloff, tinted at runtime.

    Used for both the mistake flash (red) and the Time Dividend pulse
    (desaturated). Small and stretched -- it is a gradient, not detail.
    """
    w, h = 256, 144
    img = new(w, h)
    px = img.load()
    cx, cy = w / 2.0, h / 2.0
    for y in range(h):
        for x in range(w):
            # Normalised distance from centre, squared falloff so the middle
            # stays completely clear.
            dx = (x - cx) / cx
            dy = (y - cy) / cy
            t = min(1.0, (dx * dx + dy * dy) ** 0.5)
            a = int(255 * (t ** 2.6))
            px[x, y] = (255, 255, 255, a)
    save(img, "vignette.png")


def hearts():
    for name, color in (("heart_full.png", RED), ("heart_empty.png", DIM)):
        s = 64
        img = new(s, s)
        d = ImageDraw.Draw(img)
        d.ellipse([6, 8, s // 2 + 4, s // 2 + 12], fill=color)
        d.ellipse([s // 2 - 4, 8, s - 6, s // 2 + 12], fill=color)
        d.polygon([(6, s // 2 - 2), (s - 6, s // 2 - 2), (s // 2, s - 6)], fill=color)
        save(img, name)


def main():
    os.makedirs(OUT, exist_ok=True)
    print("writing placeholders to", OUT)
    hourglass_frame()
    hourglass_sand()
    clock_face()
    clock_key()
    clock_gauge()
    safe_door()
    safe_keypad_key()
    safe_lcd()
    safe_symbols()
    codex_page()
    rocket_body()
    rocket_flame()
    launchpad()
    panel("panel_bg.png", PANEL, PANEL_EDGE)
    panel("panel_locked.png", (32, 34, 40, 255), BOARD, boarded=True)
    vignette()
    hearts()


if __name__ == "__main__":
    main()
