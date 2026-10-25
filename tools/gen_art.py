"""Procedural pixel-art generator for My Samurai Way (HD-2D).

Everything is authored in code and seeded, so running this script always
produces byte-identical PNGs.

    uv run --with pillow --with numpy python tools/gen_art.py

Characters are built from layered shapes on a region map; each region has a
(base, shadow, highlight) ramp. A lighting pass shades each region from the
top-left, then an outline pass draws a coloured dark contour around the
silhouette - the classic 16-bit sprite recipe.
"""
from __future__ import annotations

import math
import os
import random

import numpy as np
from PIL import Image, ImageFilter, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPR = os.path.join(ROOT, "assets", "sprites")
TEX = os.path.join(ROOT, "assets", "textures")


TAU_F = 2 * math.pi


def hexc(h: str) -> tuple[int, int, int]:
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def ramp(base: str, shadow: str | None = None, light: str | None = None):
    b = hexc(base)
    s = hexc(shadow) if shadow else mix(b, (20, 16, 40), 0.38)
    l = hexc(light) if light else mix(b, (255, 248, 225), 0.30)
    return (b, s, l)


# ---------------------------------------------------------------------------
# Character canvas
# ---------------------------------------------------------------------------
class Sprite:
    def __init__(self, w: int, h: int):
        self.w, self.h = w, h
        self.reg = np.zeros((h, w), dtype=np.int16)   # region id per pixel, 0 = empty
        self.ramps: list = [None]
        self.names: dict[str, int] = {}
        self.flat = np.zeros((h, w), dtype=bool)      # pixels that skip shading
        self.ox = 0                                    # drawing offset (wide combat canvases)
        self.oy = 0

    def region(self, name: str, rmp) -> int:
        if name not in self.names:
            self.names[name] = len(self.ramps)
            self.ramps.append(rmp)
        return self.names[name]

    def _mask(self, draw_fn) -> np.ndarray:
        img = Image.new("L", (self.w, self.h), 0)
        draw_fn(ImageDraw.Draw(img))
        return np.array(img) > 0

    def _o(self, pts):
        return [(p[0] + self.ox, p[1] + self.oy) for p in pts]

    def poly(self, name, pts, flat=False):
        m = self._mask(lambda d: d.polygon(self._o(pts), fill=255))
        self._apply(name, m, flat)

    def rect(self, name, x0, y0, x1, y1, flat=False):
        o = self._o([(x0, y0), (x1, y1)])
        m = self._mask(lambda d: d.rectangle([o[0], o[1]], fill=255))
        self._apply(name, m, flat)

    def ellipse(self, name, cx, cy, rx, ry, flat=False):
        cx, cy = cx + self.ox, cy + self.oy
        m = self._mask(lambda d: d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=255))
        self._apply(name, m, flat)

    def line(self, name, pts, width=1, flat=False):
        m = self._mask(lambda d: d.line(self._o(pts), fill=255, width=width))
        self._apply(name, m, flat)

    def px(self, name, x, y, flat=True):
        x, y = x + self.ox, y + self.oy
        if 0 <= x < self.w and 0 <= y < self.h:
            self.reg[y, x] = self.names[name]
            self.flat[y, x] = flat

    def _apply(self, name, m, flat):
        rid = self.names[name]
        self.reg[m] = rid
        self.flat[m] = flat

    def render(self, outline=True) -> Image.Image:
        h, w = self.h, self.w
        out = np.zeros((h, w, 4), dtype=np.uint8)
        reg = self.reg
        for y in range(h):
            for x in range(w):
                r = reg[y, x]
                if r == 0:
                    continue
                base, shadow, light = self.ramps[r]
                col = base
                if not self.flat[y, x]:
                    # light comes from upper-left: pixels whose right / lower
                    # neighbours leave the region are in shade, pixels whose
                    # upper-left neighbours leave it catch the light.
                    def other(dx, dy):
                        xx, yy = x + dx, y + dy
                        if not (0 <= xx < w and 0 <= yy < h):
                            return True
                        return reg[yy, xx] != r
                    shade_r = other(1, 0) or other(2, 0)
                    shade_b = other(0, 1)
                    lit = other(-1, 0) and not other(1, 0) or (other(0, -1) and not other(0, 1))
                    if shade_r or (shade_b and other(1, 1)):
                        col = shadow
                    elif lit:
                        col = light
                out[y, x, :3] = col
                out[y, x, 3] = 255
        if outline:
            filled = reg > 0
            res = out.copy()
            for y in range(h):
                for x in range(w):
                    if filled[y, x]:
                        continue
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        xx, yy = x + dx, y + dy
                        if 0 <= xx < w and 0 <= yy < h and filled[yy, xx]:
                            base = self.ramps[reg[yy, xx]][0]
                            res[y, x, :3] = mix(base, (18, 12, 24), 0.78)
                            res[y, x, 3] = 255
                            break
            out = res
        return Image.fromarray(out, "RGBA")


# Palettes per character archetype -------------------------------------------
SKIN = ramp("#e8b48a", "#b97b5a", "#f8d4b0")
SKIN_DARK = ramp("#c98e64", "#8f5a3e", "#e2ae84")
HAIR_BLACK = ramp("#2a2230", "#16121c", "#4a4058")
HAIR_GREY = ramp("#9a96a0", "#6a6670", "#c8c4cc")
EYE = ramp("#1a1420", "#1a1420", "#1a1420")
WHITE = ramp("#ece6d6", "#b8b0a0", "#fffaf0")
STEEL = ramp("#b8c4cc", "#7c8890", "#eef4f8")
GOLD = ramp("#d8a838", "#9c7020", "#f8dc78")
SANDAL = ramp("#8a6a48", "#5a4430", "#b08c64")

ARCHETYPES = {
    # hero: wandering samurai, indigo kimono, grey striped hakama
    "hero": dict(kimono=ramp("#3a4e8c"), trim=ramp("#c8cce0"), hakama=ramp("#5c5868"),
                 obi=ramp("#8c2a2a"), hair=HAIR_BLACK, skin=SKIN, sword=True,
                 hat=None, topknot=True, headband=None, skirt=False),
    # rival ronin: dark, straw kasa hat
    "ronin": dict(kimono=ramp("#3c3a40"), trim=ramp("#8a8490"), hakama=ramp("#2c2a30"),
                  obi=ramp("#6a5a3a"), hair=HAIR_BLACK, skin=SKIN_DARK, sword=True,
                  hat=ramp("#c8a868", "#8c7040", "#ead090"), topknot=False, headband=None, skirt=False),
    # villager: short brown kimono, bare shins, headband
    "villager": dict(kimono=ramp("#8a6440"), trim=ramp("#d8c8a0"), hakama=None,
                     obi=ramp("#4a5a6a"), hair=HAIR_BLACK, skin=SKIN_DARK, sword=False,
                     hat=None, topknot=True, headband=ramp("#e8e0d0"), skirt=False),
    # tea-house girl: red kimono to the ankles, long hair, no sword
    "girl": dict(kimono=ramp("#b8344a"), trim=ramp("#f0d8a8"), hakama=None,
                 obi=ramp("#e8b040"), hair=HAIR_BLACK, skin=SKIN, sword=False,
                 hat=None, topknot=False, headband=None, skirt=True, longhair=True),
    # magistrate's guard: brown-red armour-ish, spear-less for now
    "guard": dict(kimono=ramp("#7a2e24"), trim=ramp("#d8b070"), hakama=ramp("#3a3240"),
                  obi=ramp("#2a2a34"), hair=HAIR_BLACK, skin=SKIN, sword=True,
                  hat=ramp("#2c2c34", "#18181e", "#4c4c58"), topknot=False, headband=None,
                  skirt=False, jingasa=True),
    # old man: grey hair, faded green
    "elder": dict(kimono=ramp("#5e7258"), trim=ramp("#d0ccb8"), hakama=ramp("#6a6258"),
                  obi=ramp("#3a3430"), hair=HAIR_GREY, skin=SKIN_DARK, sword=False,
                  hat=None, topknot=True, headband=None, skirt=False),
    # Corvo thug: drab brown, blood-red headband
    "bandit": dict(kimono=ramp("#6a5a48"), trim=ramp("#a89878"), hakama=ramp("#4a4038"),
                   obi=ramp("#8a3a2a"), hair=HAIR_BLACK, skin=SKIN_DARK, sword=True,
                   hat=None, topknot=False, headband=ramp("#b83a2a"), skirt=False),
    # Kuroda Jinbei, head of the Corvo: black with red trim, long tied hair
    "kuroda": dict(kimono=ramp("#25222c", "#121016", "#45404e"), trim=ramp("#b0302a"),
                   hakama=ramp("#2e2a36"), obi=ramp("#c8a040"), hair=HAIR_BLACK, skin=SKIN,
                   sword=True, hat=None, topknot=False, headband=None, skirt=False, wild=True),
    # Magistrate Akamatsu: rich purple, gold, tall black eboshi
    "akamatsu": dict(kimono=ramp("#5a3a7a"), trim=ramp("#e0c070"), hakama=ramp("#3a2a4a"),
                     obi=ramp("#e0c070"), hair=HAIR_BLACK, skin=SKIN, sword=True,
                     hat=ramp("#1e1c22", "#0e0d10", "#3c3a44"), topknot=False, headband=None,
                     skirt=False, eboshi=True),
}

CW, CH = 32, 48


def build_character(arch: str, facing: str = "down", frame: int = 0) -> Image.Image:
    """facing: down | up | side (side faces right). frame 0 = idle, 1..4 walk."""
    a = ARCHETYPES[arch]
    s = Sprite(CW, CH)
    for name in ("kimono", "trim", "obi", "hair", "skin"):
        s.region(name, a[name])
    s.region("skin_d", (a["skin"][1], a["skin"][1], a["skin"][0]))
    s.region("hakama", a["hakama"] or a["kimono"])
    s.region("eye", EYE)
    s.region("white", WHITE)
    s.region("steel", STEEL)
    s.region("gold", GOLD)
    s.region("sandal", SANDAL)
    s.region("saya", ramp("#2a2026", "#160f14", "#4a3a44"))
    s.region("tsuka", ramp("#3a3448", "#201c2a", "#6a6080"))
    if a.get("hat"):
        s.region("hat", a["hat"])
    if a.get("headband"):
        s.region("band", a["headband"])

    # walk cycle: 0 idle, 1 left fwd, 2 pass, 3 right fwd, 4 pass
    step = {0: 0, 1: 1, 2: 0, 3: -1, 4: 0}[frame]
    bob = 1 if frame in (2, 4) else 0
    y0 = bob  # whole body bob

    if facing == "side":
        _build_side(s, a, step, y0)
    else:
        _build_front(s, a, step, y0, back=(facing == "up"))
    return s.render()


def _build_front(s: Sprite, a, step, y0, back=False):
    cx = 16
    # --- sword scabbard behind the body (viewer's left, low) ---
    if a["sword"] and not back:
        s.line("saya", [(13, 31 + y0), (4, 38 + y0)], width=2)
    if a["sword"] and back:
        s.line("saya", [(19, 30 + y0), (27, 36 + y0)], width=2)
    # --- legs / hakama ---
    lf = 43 + (-1 if step == 1 else 0)
    rf = 43 + (-1 if step == -1 else 0)
    if a["skirt"]:
        s.poly("kimono", [(10, 30 + y0), (22, 30 + y0), (22, 44), (10, 44)])
        s.rect("sandal", 11, 44, 14, 45)
        s.rect("sandal", 18, 44, 21, 45)
        s.line("trim", [(16, 31 + y0), (16, 44)])
    elif a["hakama"] is not None:
        s.poly("hakama", [(10, 30 + y0), (22, 30 + y0), (24, 43), (8, 43)])
        # darker pleat lines
        s.region("pleat", (a["hakama"][1], a["hakama"][1], a["hakama"][1]))
        s.line("pleat", [(16, 35 + y0), (16, 43)], flat=True)
        s.line("pleat", [(12, 33 + y0), (11, 43)], flat=True)
        s.line("pleat", [(20, 33 + y0), (21, 43)], flat=True)
        s.rect("sandal", 9, lf, 13, lf + 2)
        s.rect("sandal", 19, rf, 23, rf + 2)
    else:
        # short kimono, bare shins
        s.rect("skin", 11, 36 + y0, 14, lf, )
        s.rect("skin", 18, 36 + y0, 21, rf)
        s.rect("sandal", 10, lf, 14, lf + 2)
        s.rect("sandal", 18, rf, 22, rf + 2)
    # --- sleeves (behind torso edges) ---
    sw = step  # arms swing opposite to legs
    s.poly("kimono", [(5, 20 + y0), (10, 19 + y0), (10, 31 + y0 + sw), (5, 32 + y0 + sw)])
    s.poly("kimono", [(22, 19 + y0), (27, 20 + y0), (27, 32 + y0 - sw), (22, 31 + y0 - sw)])
    # --- torso ---
    bottom = 36 if (a["hakama"] is None and not a["skirt"]) else 31
    s.poly("kimono", [(9, 19 + y0), (23, 19 + y0), (23, bottom + y0), (9, bottom + y0)])
    if not back:
        # collar: undershirt V + trim lapels
        s.poly("white", [(13, 19 + y0), (19, 19 + y0), (16, 24 + y0)])
        s.line("trim", [(12, 19 + y0), (16, 25 + y0)], flat=True)
        s.line("trim", [(20, 19 + y0), (16, 25 + y0)], flat=True)
    # obi
    s.rect("obi", 9, 28 + y0, 23, 30 + y0)
    if a["skirt"] and not back:
        s.rect("obi", 13, 27 + y0, 19, 31 + y0)   # big obi bow front
    if a["skirt"] and back:
        s.poly("obi", [(11, 26 + y0), (21, 26 + y0), (19, 33 + y0), (13, 33 + y0)])
    # hands
    s.ellipse("skin", 7, 33 + y0 + sw, 1.6, 1.6)
    s.ellipse("skin", 25, 33 + y0 - sw, 1.6, 1.6)
    # --- katana hilt in front (viewer's right, at the obi) ---
    if a["sword"] and not back:
        s.line("tsuka", [(19, 28 + y0), (26, 23 + y0)], width=2)
        s.rect("gold", 18, 28 + y0, 19, 29 + y0, flat=True)
        s.px("tsuka", 26, 22 + y0)
    # --- neck & head ---
    s.rect("skin_d", 14, 17 + y0, 18, 19 + y0)
    if a.get("longhair"):
        s.poly("hair", [(8, 10 + y0), (24, 10 + y0), (25, 27 + y0), (7, 27 + y0)])
    s.ellipse("hair", cx, 11 + y0, 7.5, 7)
    if not back:
        s.ellipse("skin", cx, 13 + y0, 6, 5.2)
        # fringe
        s.poly("hair", [(9, 8 + y0), (23, 8 + y0), (22, 10 + y0), (17, 9 + y0), (14, 11 + y0), (10, 11 + y0)])
        # eyes + brows
        for ex in (13, 19):
            s.px("eye", ex, 13 + y0)
            s.px("eye", ex, 14 + y0)
        s.px("white", 13, 13 + y0)  # tiny catchlight (left eye only, reads fine)
        s.px("eye", 13, 13 + y0)
        s.region("brow", (a["hair"][1],) * 3)
        s.line("brow", [(12, 11 + y0), (14, 11 + y0)], flat=True)
        s.line("brow", [(18, 11 + y0), (20, 11 + y0)], flat=True)
        s.region("mouth", (a["skin"][1],) * 3)
        s.line("mouth", [(15, 16 + y0), (17, 16 + y0)], flat=True)
    if a.get("wild"):
        # loose, spiky mane: a boss silhouette
        s.poly("hair", [(7, 10 + y0), (8, 2 + y0), (11, 5 + y0), (13, 0 + y0), (16, 4 + y0),
                        (19, 0 + y0), (21, 5 + y0), (24, 2 + y0), (25, 10 + y0)])
        if not back:
            s.ellipse("skin", cx, 13 + y0, 6, 5.2)
            s.poly("hair", [(9, 8 + y0), (23, 8 + y0), (22, 11 + y0), (18, 9 + y0), (15, 12 + y0), (12, 9 + y0), (10, 11 + y0)])
            for ex in (13, 19):
                s.px("eye", ex, 13 + y0)
                s.px("eye", ex, 14 + y0)
            s.line("brow", [(12, 11 + y0), (14, 12 + y0)], flat=True)
            s.line("brow", [(18, 12 + y0), (20, 11 + y0)], flat=True)
            s.region("scar", ((200, 90, 90),) * 3)
            s.line("scar", [(18, 10 + y0), (20, 15 + y0)], flat=True)
    if a["topknot"]:
        s.rect("hair", 14, 2 + y0, 18, 5 + y0)
        s.line("white", [(14, 5 + y0), (18, 5 + y0)], flat=True)
    if a.get("headband"):
        s.rect("band", 8, 8 + y0, 24, 9 + y0)
        if not back:
            pass
        else:
            s.line("band", [(17, 9 + y0), (20, 13 + y0)])
    if a.get("hat"):
        if a.get("eboshi"):
            # tall court cap
            s.poly("hat", [(11, 8 + y0), (21, 8 + y0), (20, 0 + y0), (12, 1 + y0)])
            s.line("hat", [(10, 8 + y0), (22, 8 + y0)])
        elif a.get("jingasa"):
            # flat lacquered war hat
            s.poly("hat", [(4, 9 + y0), (28, 9 + y0), (24, 5 + y0), (8, 5 + y0)])
            s.ellipse("gold", 16, 6 + y0, 1.5, 1.2, flat=True)
        else:
            # conical straw kasa - hides the eyes, very ronin
            s.poly("hat", [(3, 11 + y0), (29, 11 + y0), (16, 1 + y0)])
            s.region("weave", (a["hat"][1],) * 3)
            for i in range(4):
                s.line("weave", [(16, 2 + y0), (6 + i * 7, 10 + y0)], flat=True)


def _build_side(s: Sprite, a, step, y0, arm=True, waist_hilt=True, kneel=False):
    # facing right
    # sword scabbard sticks out behind (left)
    if a["sword"]:
        s.line("saya", [(14, 30 + y0), (3, 34 + y0)], width=2)
    # legs
    if a["skirt"]:
        s.poly("kimono", [(11, 30 + y0), (21, 30 + y0), (21, 44), (11, 44)])
        s.rect("sandal", 13 + step, 44, 19 + step, 45)
    elif a["hakama"] is not None and kneel:
        s.poly("hakama", [(8, 31 + y0), (22, 31 + y0), (25, 44), (6, 44)])
        s.rect("sandal", 3, 42, 8, 44)
    elif a["hakama"] is not None:
        s.poly("hakama", [(11, 30 + y0), (21, 30 + y0), (23 + step * 2, 43), (9 - step * 2, 43)])
        s.region("pleat", (a["hakama"][1],) * 3)
        s.line("pleat", [(16, 32 + y0), (16 + step, 43)], flat=True)
        s.rect("sandal", 17 + step * 2, 43, 23 + step * 2, 45)
        s.rect("sandal", 10 - step * 2, 43, 15 - step * 2, 45)
    else:
        s.line("skin", [(14, 36 + y0), (13 - step * 2, 43)], width=3)
        s.line("skin", [(18, 36 + y0), (19 + step * 2, 43)], width=3)
        s.rect("sandal", 10 - step * 2, 43, 15 - step * 2, 45)
        s.rect("sandal", 17 + step * 2, 43, 22 + step * 2, 45)
    bottom = 36 if (a["hakama"] is None and not a["skirt"]) else 31
    s.poly("kimono", [(11, 19 + y0), (21, 19 + y0), (21, bottom + y0), (11, bottom + y0)])
    s.poly("white", [(19, 19 + y0), (22, 19 + y0), (21, 23 + y0)])
    s.rect("obi", 11, 28 + y0, 21, 30 + y0)
    if a["skirt"]:
        s.poly("obi", [(8, 26 + y0), (12, 26 + y0), (12, 32 + y0), (7, 32 + y0)])
    # arm / sleeve in front
    if arm:
        s.poly("kimono", [(13, 20 + y0), (19, 20 + y0), (19 + step, 31 + y0), (13 + step, 32 + y0)])
        s.ellipse("skin", 17 + step, 33 + y0, 1.6, 1.6)
    if a["sword"] and waist_hilt:
        s.line("tsuka", [(20, 28 + y0), (27, 25 + y0)], width=2)
        s.rect("gold", 19, 28 + y0, 20, 29 + y0, flat=True)
    # head
    s.rect("skin_d", 15, 17 + y0, 18, 19 + y0)
    if a.get("longhair"):
        s.poly("hair", [(8, 9 + y0), (16, 9 + y0), (15, 27 + y0), (9, 27 + y0)])
    s.ellipse("hair", 15, 11 + y0, 7, 7)
    s.ellipse("skin", 18, 13 + y0, 5, 5)
    s.poly("hair", [(10, 6 + y0), (22, 7 + y0), (22, 9 + y0), (15, 9 + y0), (14, 13 + y0), (10, 13 + y0)])
    s.px("eye", 20, 13 + y0)
    s.px("eye", 20, 14 + y0)
    s.region("brow", (a["hair"][1],) * 3)
    s.line("brow", [(19, 11 + y0), (21, 11 + y0)], flat=True)
    s.px("skin", 23, 14 + y0, flat=False)   # nose
    if a.get("wild"):
        s.poly("hair", [(8, 12 + y0), (5, 4 + y0), (9, 5 + y0), (10, 0 + y0), (13, 4 + y0),
                        (16, 0 + y0), (18, 4 + y0), (21, 2 + y0), (21, 9 + y0), (15, 9 + y0), (14, 13 + y0)])
        s.px("eye", 20, 13 + y0)
        s.px("eye", 20, 14 + y0)
        s.region("scar", ((200, 90, 90),) * 3)
        s.line("scar", [(19, 10 + y0), (21, 15 + y0)], flat=True)
    if a["topknot"]:
        s.rect("hair", 11, 3 + y0, 15, 6 + y0)
        s.line("white", [(14, 3 + y0), (14, 6 + y0)], flat=True)
    if a.get("headband"):
        s.rect("band", 9, 8 + y0, 22, 9 + y0)
        s.line("band", [(9, 9 + y0), (6, 13 + y0)])
    if a.get("hat"):
        if a.get("eboshi"):
            s.poly("hat", [(10, 8 + y0), (19, 8 + y0), (16, 0 + y0), (9, 2 + y0)])
        elif a.get("jingasa"):
            s.poly("hat", [(4, 9 + y0), (27, 9 + y0), (23, 5 + y0), (8, 5 + y0)])
        else:
            s.poly("hat", [(3, 11 + y0), (28, 11 + y0), (16, 1 + y0)])
            s.region("weave", (a["hat"][1],) * 3)
            for i in range(4):
                s.line("weave", [(16, 2 + y0), (6 + i * 7, 10 + y0)], flat=True)


COMBAT_POSES = ("ready", "raise", "slash", "guard", "hurt", "down")
COMBAT_W = 64


def _arm_and_blade(s: Sprite, shoulder, hand, blade_to, y0=0, hilt_len=3):
    """Sleeve from the shoulder to the hands, then hilt + guard + blade."""
    sx, sy = shoulder
    hx, hy = hand
    sy += y0
    hy += y0
    bx, by = blade_to[0], blade_to[1] + y0
    # sleeve as a thick quad
    dx, dy = hx - sx, hy - sy
    ln = max(1.0, math.hypot(dx, dy))
    nx, ny = -dy / ln * 3.0, dx / ln * 3.0
    s.poly("kimono", [(sx + nx, sy + ny), (sx - nx, sy - ny), (hx - nx * 0.6, hy - ny * 0.6), (hx + nx * 0.6, hy + ny * 0.6)])
    # blade direction
    vx, vy = bx - hx, by - hy
    vl = max(1.0, math.hypot(vx, vy))
    ux, uy = vx / vl, vy / vl
    tx, ty = hx - ux * hilt_len, hy - uy * hilt_len
    s.line("tsuka", [(round(tx), round(ty)), (round(hx + ux), round(hy + uy))], width=2)
    gx, gy = round(hx + ux * 2), round(hy + uy * 2)
    s.rect("gold", gx - 1, gy - 1, gx, gy, flat=True)
    s.line("blade", [(gx + round(ux), gy + round(uy)), (round(bx), round(by))], width=2)
    s.line("edge", [(gx + round(ux * 2), gy + round(uy * 2) - (1 if abs(ux) > abs(uy) else 0)),
                    (round(bx), round(by) - (1 if abs(ux) > abs(uy) else 0))], flat=True)
    s.ellipse("skin", hx, hy, 1.7, 1.7)


def build_combat(arch: str, pose: str) -> Image.Image:
    """Side view (facing right) on a 64x48 canvas; the body sits where it does
    in the 32-wide walk sheet (x offset 16) so both sheets share a pivot."""
    a = ARCHETYPES[arch]
    s = Sprite(COMBAT_W, CH)
    s.ox = 16
    for name in ("kimono", "trim", "obi", "hair", "skin"):
        s.region(name, a[name])
    s.region("skin_d", (a["skin"][1], a["skin"][1], a["skin"][0]))
    s.region("hakama", a["hakama"] or a["kimono"])
    for name, r in (("eye", EYE), ("white", WHITE), ("steel", STEEL), ("gold", GOLD), ("sandal", SANDAL)):
        s.region(name, r)
    s.region("saya", ramp("#2a2026", "#160f14", "#4a3a44"))
    s.region("tsuka", ramp("#3a3448", "#201c2a", "#6a6080"))
    s.region("blade", ramp("#aab6c0", "#6c7884", "#e8f0f6"))
    s.region("edge", ((246, 250, 255),) * 3)
    if a.get("hat"):
        s.region("hat", a["hat"])
    if a.get("headband"):
        s.region("band", a["headband"])
    y0 = 7 if pose == "down" else 0
    _build_side(s, a, 0, y0, arm=False, waist_hilt=False, kneel=(pose == "down"))
    sh = (16, 21)
    if pose == "ready":       # chudan: blade forward and up, aimed at the throat
        _arm_and_blade(s, sh, (23, 29), (38, 16))
    elif pose == "raise":     # jodan: hands over the head, blade back
        _arm_and_blade(s, sh, (19, 7), (2, 10))
    elif pose == "slash":     # follow-through: arms extended, blade level
        _arm_and_blade(s, sh, (28, 28), (47, 31))
    elif pose == "guard":     # vertical guard in front of the body
        _arm_and_blade(s, sh, (24, 27), (27, 6))
    elif pose == "hurt":      # recoil: blade drops
        _arm_and_blade(s, sh, (22, 31), (34, 41))
    elif pose == "down":      # kneeling, blade planted
        _arm_and_blade(s, sh, (23, 30), (31, 40), y0=y0)
    img = s.render()
    if pose == "hurt":        # lean the upper body back
        arr = np.array(img)
        top = arr[:30].copy()
        arr[:30] = 0
        arr[:30, :-3] = top[:, 3:]
        img = Image.fromarray(arr, "RGBA")
    return img


def combat_sheet(arch: str) -> Image.Image:
    sheet = Image.new("RGBA", (COMBAT_W * len(COMBAT_POSES), CH), (0, 0, 0, 0))
    for i, pose in enumerate(COMBAT_POSES):
        sheet.paste(build_combat(arch, pose), (i * COMBAT_W, 0))
    return sheet


def fx_slash() -> Image.Image:
    """Crescent sword-trail, white core fading to steel blue."""
    w, h = 64, 64
    arr = np.zeros((h, w, 4), dtype=np.uint8)
    cx, cy = 18, 32
    for y in range(h):
        for x in range(w):
            r = math.hypot(x - cx, y - cy)
            ang = math.degrees(math.atan2(y - cy, x - cx))
            if -75 <= ang <= 75:
                t = 1 - abs(ang) / 75.0                      # thick in the middle
                inner, outer = 34 - 6 * t, 36 + 3 * t
                if inner <= r <= outer:
                    k = (r - inner) / max(0.1, outer - inner)
                    col = (255, 255, 255) if k > 0.45 else (190, 220, 255)
                    arr[y, x, :3] = col
                    arr[y, x, 3] = 255
    return Image.fromarray(arr, "RGBA")


SLASH_STYLES = {
    # core, rim, thickness, arc span (deg)
    "light": ((255, 255, 255), (170, 205, 255), 3.0, 120),
    "heavy": ((255, 250, 225), (255, 196, 92), 6.0, 150),
    "tech": ((235, 250, 255), (90, 170, 255), 6.0, 160),
}


def fx_slash_strip(kind: str, frames: int = 5, size: int = 72) -> Image.Image:
    """Sword trail that sweeps across `frames` columns: the leading edge is a
    bright core, the tail thins and fades into the rim colour; the last
    frame is a dissolving afterimage. Banded, not smooth, to stay pixel art."""
    core, rim, thick, span = SLASH_STYLES[kind]
    sheet = np.zeros((size, size * frames, 4), dtype=np.uint8)
    cx, cy, rad = size * 0.3, size * 0.5, size * 0.4
    a0 = -span / 2
    for f in range(frames):
        head = a0 + span * min(1.0, (f + 1) / (frames - 1))      # leading angle
        fade_out = 1.0 if f < frames - 1 else 0.45
        for y in range(size):
            for x in range(size):
                r = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
                ang = math.degrees(math.atan2(y + 0.5 - cy, x + 0.5 - cx))
                if not (a0 <= ang <= head):
                    continue
                behind = (head - ang) / span                          # 0 at the head
                w = thick * max(0.0, 1.0 - behind * 1.15)
                if w < 0.6 or abs(r - rad) > w:
                    continue
                if f == frames - 1 and (x * 7 + y * 13) % 3 == 0:      # dissolve
                    continue
                k = 1.0 - abs(r - rad) / w
                col = core if (k > 0.45 and behind < 0.55) else rim
                sheet[y, f * size + x, :3] = col
                sheet[y, f * size + x, 3] = int(255 * fade_out * (1.0 if behind < 0.7 else 0.6))
    # 1 px dark ink outline so the arc reads even over a sprite flashing white
    solid = sheet[..., 3] > 0
    ring = np.zeros_like(solid)
    for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
        ring |= np.roll(np.roll(solid, dy, 0), dx, 1)
    ring &= ~solid
    for f in range(frames):                       # no bleed across frame borders
        ring[:, f * size] &= solid[:, f * size]
        ring[:, f * size + size - 1] &= solid[:, f * size + size - 1]
    sheet[ring] = (34, 24, 40, 210)
    return Image.fromarray(sheet, "RGBA")


def fx_spark() -> Image.Image:
    """Tiny 4x4 spark (white core) for particle bursts."""
    arr = np.zeros((4, 4, 4), dtype=np.uint8)
    for (x, y), c in {(1, 1): 255, (2, 1): 255, (1, 2): 255, (2, 2): 255,
                      (0, 1): 180, (3, 2): 180, (1, 0): 180, (2, 3): 180}.items():
        arr[y, x] = (255, 255, 255, c)
    return Image.fromarray(arr, "RGBA")


def fx_hit() -> Image.Image:
    """Four-point impact star."""
    w = 24
    arr = np.zeros((w, w, 4), dtype=np.uint8)
    c = w // 2
    for y in range(w):
        for x in range(w):
            dx, dy = abs(x - c), abs(y - c)
            if (dx <= 1 and dy <= 10 - dx * 3) or (dy <= 1 and dx <= 10 - dy * 3) or (dx == dy and dx <= 4):
                core = dx <= 1 and dy <= 1 or dx + dy <= 3
                arr[y, x, :3] = (255, 255, 255) if core else (255, 214, 120)
                arr[y, x, 3] = 255
    return Image.fromarray(arr, "RGBA")


def fx_fire(frames: int = 6, w: int = 24, h: int = 34) -> Image.Image:
    """Campfire flame strip: `frames` columns, a looping flicker.

    A teardrop silhouette whose edge wobbles with two travelling sine waves,
    banded into a 5-colour palette (ember red -> white core) so it reads as
    pixel art, not a gradient. Tongues break off near the top and drift up."""
    pal = [(120, 24, 18), (196, 52, 22), (240, 110, 30), (255, 182, 60), (255, 236, 170)]
    sheet = np.zeros((h, w * frames, 4), dtype=np.uint8)
    rng = np.random.default_rng(7)
    for f in range(frames):
        ph = TAU_F * f / frames
        for y in range(h):
            v = y / (h - 1)                           # image y grows down: 1 at the base, 0 at the tip
            base_half = 9.0 * (v ** 0.8) * (1 - 0.35 * max(0.0, v - 0.8) / 0.2)
            sway = 1.6 * (1 - v) * math.sin(ph + y * 0.38) + 0.6 * math.sin(2 * ph + y * 0.9)
            for x in range(w):
                dx = x + 0.5 - (w / 2 + sway)
                edge = base_half + 1.1 * math.sin(ph * 2 + y * 0.7 + (1 if dx > 0 else 0) * 2.1)
                if abs(dx) > edge or edge <= 0.3:
                    continue
                heat = (1 - abs(dx) / max(edge, 0.5)) * 0.65 + v * 0.55
                k = int(min(4, max(0, heat * 4.2 - 0.6)))
                sheet[y, f * w + x, :3] = pal[k]
                sheet[y, f * w + x, 3] = 255
        # a detached tongue drifting up through the loop
        ty = int((h * 0.3) - (f / frames) * h * 0.28)
        tx = int(w / 2 + 2 * math.sin(ph))
        for yy in range(max(0, ty - 2), max(0, ty + 1)):
            for xx in (tx, tx + 1):
                if 0 <= yy < h and sheet[yy, f * w + xx, 3] == 0:
                    sheet[yy, f * w + xx, :3] = pal[2]
                    sheet[yy, f * w + xx, 3] = 255
    return Image.fromarray(sheet, "RGBA")


# ---------------------------------------------------------------------------
# UI: washi paper + hanko seal (9-slice textures for StyleBoxTexture)
# ---------------------------------------------------------------------------
UI_MARGIN = 24          # 9-slice margin in px (must match UiStyle.PAPER_MARGIN)


def _soft(mask: np.ndarray, radius: int) -> np.ndarray:
    im = Image.fromarray((mask * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(radius))
    return np.asarray(im, float) / 255


def ui_washi(size: int = 128, seed: int = 21, base=(232, 220, 194)) -> Image.Image:
    """Washi sheet with deckled edges, fibres, two ink brush rules and a soft
    drop shadow baked into the margin (StyleBoxTexture has no shadow).

    Godot tiles the 9-slice centre and edges (TILE_FIT), so every pattern
    that crosses them is periodic with the centre width c = size - 2*margin:
    the paper grain is one c x c periodic tile repeated, and the deckle and
    the brush rules use whole-number frequencies over c. No seams."""
    rng = np.random.default_rng(seed)
    n, M = size, UI_MARGIN
    c = n - 2 * M
    # --- periodic grain tile (c x c) ---
    yy, xx = np.mgrid[0:c, 0:c] / c
    blot = np.zeros((c, c))
    for fx, fy in ((1, 0), (0, 1), (1, 1), (2, 1), (1, 2), (3, 2)):
        blot += rng.uniform(0.3, 1.0) * np.sin(TAU_F * (fx * xx + fy * yy) + rng.uniform(0, TAU_F))
    blot = (blot - blot.min()) / np.ptp(blot)
    fib = np.zeros((c, c))
    for _ in range(int(c * c / 240)):
        x, y = rng.integers(0, c), rng.integers(0, c)
        L, ang = rng.integers(4, 14), rng.uniform(0, np.pi)
        v = rng.uniform(0.4, 1.0)
        for k in range(L):
            fib[int(y + np.sin(ang) * k) % c, int(x + np.cos(ang) * k) % c] = v
    tile = np.zeros((c, c, 3))
    for ch in range(3):
        tile[..., ch] = base[ch] * (0.975 + 0.025 * blot) - fib * 15
    idx = (np.arange(n) - M) % c
    grain = tile[idx][:, idx]
    # --- paper shape with a periodic deckle ---
    lo, hi = 6, n - 10
    paper = np.zeros((n, n))
    paper[lo:hi, lo:hi] = 1
    for side in range(4):
        ph = rng.uniform(0, TAU_F, 3)
        for i in range(lo, hi):
            u = (i - M) / c
            s = np.sin(TAU_F * 2 * u + ph[0]) + 0.6 * np.sin(TAU_F * 5 * u + ph[1]) + 0.3 * np.sin(TAU_F * 11 * u + ph[2])
            d = max(0, min(3, int(round(1.2 + 0.9 * s))))
            if side == 0: paper[lo:lo + d, i] = 0
            if side == 1: paper[hi - d:hi, i] = 0
            if side == 2: paper[i, lo:lo + d] = 0
            if side == 3: paper[i, hi - d:hi] = 0
    shadow = _soft(np.roll(np.roll(paper, 5, 0), 4, 1), 4) * 0.42
    out = np.zeros((n, n, 4))
    out[..., :3] = grain
    # --- ink brush rules (top and bottom margins), wobble periodic over c ---
    for y0, w in ((13, 2), (n - 21, 2)):
        for x in range(lo + 6, hi - 6):
            fade = min(1.0, (x - lo - 6) / 10, (hi - 6 - x) / 10)
            j = int(round(0.7 * np.sin(TAU_F * 3 * (x - M) / c + y0)))
            for yv in range(y0 + j, y0 + j + w):
                a = 0.75 * fade
                out[yv, x, :3] = out[yv, x, :3] * (1 - a) + np.array([44, 34, 30]) * a
    alpha = np.maximum(paper, shadow)
    for ch in range(3):
        out[..., ch] = np.where(paper > 0, out[..., ch], 18)
    out[..., 3] = alpha * 255
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA")


def ui_seal(w: int = 48, h: int = 40, seed: int = 5) -> Image.Image:
    """Vermilion hanko block: rough stamped edge, paler inner frame, ink speckle."""
    rng = np.random.default_rng(seed)
    red = np.array([176, 36, 30], float)
    out = np.zeros((h, w, 4))
    for y in range(h):
        for x in range(w):
            edge = min(x, y, w - 1 - x, h - 1 - y)
            if edge < 1 or (edge < 2 and rng.random() < 0.35):
                continue
            k = 0.95 + 0.06 * rng.random()
            col = red * k
            if edge in (4,) and rng.random() < 0.85:        # inner frame line
                col = np.array([236, 196, 180])
            if rng.random() < 0.015:                         # missing ink
                col = col * 0.0 + np.array([214, 120, 100])
            out[y, x, :3] = col
            out[y, x, 3] = 255
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA")


def character_sheet(arch: str) -> Image.Image:
    """Rows: down, up, side. Columns: idle, walk1..4."""
    sheet = Image.new("RGBA", (CW * 5, CH * 3), (0, 0, 0, 0))
    for r, facing in enumerate(("down", "up", "side")):
        for f in range(5):
            sheet.paste(build_character(arch, facing, f), (f * CW, r * CH))
    return sheet


# ---------------------------------------------------------------------------
# Foliage: canopy built from shaded spheres -> clumpy pixel leaves
# ---------------------------------------------------------------------------
def foliage_sprite(w, h, seed, trunk, leaves_ramp, blobs, trunk_pts, petals=None,
                   light=(-0.55, -0.7)):
    rng = random.Random(seed)
    img = np.zeros((h, w, 4), dtype=np.uint8)
    # trunk
    t = Sprite(w, h)
    t.region("trunk", trunk)
    for pts, width in trunk_pts:
        t.line("trunk", pts, width=width)
    timg = np.array(t.render(outline=True))
    img[timg[..., 3] > 0] = timg[timg[..., 3] > 0]
    # canopy: per pixel, the sphere that is "frontmost" (largest local height) wins
    hgt = np.full((h, w), -1.0)
    nx = np.zeros((h, w))
    ny = np.zeros((h, w))
    lx, ly = light
    ln = math.hypot(lx, ly)
    lx, ly = lx / ln, ly / ln
    for (bx, by, br) in blobs:
        for _ in range(int(br * 1.6)):
            cx = bx + rng.uniform(-br * 0.7, br * 0.7)
            cy = by + rng.uniform(-br * 0.5, br * 0.5)
            r = rng.uniform(br * 0.35, br * 0.6)
            x0, x1 = int(max(0, cx - r)), int(min(w - 1, cx + r))
            y0, y1 = int(max(0, cy - r)), int(min(h - 1, cy + r))
            for y in range(y0, y1 + 1):
                for x in range(x0, x1 + 1):
                    dx, dy = (x - cx) / r, (y - cy) / r
                    d2 = dx * dx + dy * dy
                    if d2 > 1:
                        continue
                    z = math.sqrt(1 - d2) * r + cy * 0.02 * r
                    if z > hgt[y, x]:
                        hgt[y, x] = z
                        nx[y, x], ny[y, x] = dx, dy
    base, shadow, lit = leaves_ramp
    deep = mix(shadow, (16, 12, 30), 0.45)
    hi = mix(lit, (255, 255, 240), 0.25)
    for y in range(h):
        for x in range(w):
            if hgt[y, x] < 0:
                continue
            ndl = -(nx[y, x] * lx + ny[y, x] * ly)  # facing the light
            # dither band edges with a 2x2 Bayer for a hand-pixelled feel
            bay = ((0, 2), (3, 1))[y % 2][x % 2] / 4.0 - 0.375
            v = ndl + bay * 0.35
            if v > 0.55:
                c = hi
            elif v > 0.15:
                c = lit
            elif v > -0.3:
                c = base
            elif v > -0.65:
                c = shadow
            else:
                c = deep
            img[y, x, :3] = c
            img[y, x, 3] = 255
    # outline canopy
    filled = img[..., 3] > 0
    res = img.copy()
    for y in range(h):
        for x in range(w):
            if filled[y, x]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                xx, yy = x + dx, y + dy
                if 0 <= xx < w and 0 <= yy < h and filled[yy, xx]:
                    res[y, x, :3] = mix(tuple(int(v) for v in img[yy, xx, :3]), (18, 10, 28), 0.7)
                    res[y, x, 3] = 255
                    break
    img = res
    if petals:
        for _ in range(petals[0]):
            x, y = rng.randrange(w), rng.randrange(h)
            if img[y, x, 3] and hgt[y, x] >= 0:
                img[y, x, :3] = petals[1]
    return Image.fromarray(img, "RGBA")


def sakura():
    blobs = [(48, 40, 22), (28, 52, 16), (70, 52, 16), (48, 22, 14), (36, 32, 12), (62, 30, 12)]
    trunk = [([(47, 127), (46, 96), (44, 70), (40, 52)], 7), ([(46, 90), (60, 66), (68, 52)], 4),
             ([(45, 80), (30, 62), (26, 54)], 4)]
    return foliage_sprite(96, 128, 7, ramp("#5a3a34", "#3a2420", "#7a5248"),
                          ramp("#f0a8c0", "#c87090", "#ffd6e2"), blobs, trunk,
                          petals=(60, (255, 240, 246)))


def pine():
    blobs = [(40, 26, 12), (28, 44, 14), (54, 46, 14), (40, 62, 16), (22, 70, 12), (60, 72, 12)]
    trunk = [([(40, 127), (41, 100), (38, 60), (40, 30)], 6), ([(39, 70), (24, 66)], 3), ([(40, 76), (58, 70)], 3)]
    return foliage_sprite(80, 128, 11, ramp("#6a4a3a", "#43302a", "#8c6a54"),
                          ramp("#3c6a48", "#22412e", "#64945c"), blobs, trunk)


def bush(seed=3):
    blobs = [(24, 20, 12), (12, 24, 9), (36, 24, 9)]
    return foliage_sprite(48, 32, seed, ramp("#4a3a2a"), ramp("#4a7a44", "#2a4a2e", "#78a456"), blobs, [])


def maple():
    blobs = [(40, 34, 18), (24, 46, 13), (58, 46, 13), (40, 18, 11)]
    trunk = [([(40, 96), (40, 60), (38, 40)], 5), ([(40, 64), (54, 48)], 3)]
    return foliage_sprite(80, 96, 21, ramp("#5a3a30"), ramp("#d0562c", "#8c2e22", "#f0904a"), blobs, trunk)


# ---------------------------------------------------------------------------
# Tileable textures (32 px == 1 metre in the world)
# ---------------------------------------------------------------------------
def noise_tile(size, seed, cells=4):
    rng = np.random.default_rng(seed)
    lat = rng.random((cells, cells))
    ys = np.arange(size) / size * cells
    xs = np.arange(size) / size * cells
    x0 = np.floor(xs).astype(int)
    y0 = np.floor(ys).astype(int)
    fx = xs - x0
    fy = ys - y0
    fx = fx * fx * (3 - 2 * fx)
    fy = fy * fy * (3 - 2 * fy)
    a = lat[y0[:, None] % cells, x0[None, :] % cells]
    b = lat[y0[:, None] % cells, (x0[None, :] + 1) % cells]
    c = lat[(y0[:, None] + 1) % cells, x0[None, :] % cells]
    d = lat[(y0[:, None] + 1) % cells, (x0[None, :] + 1) % cells]
    top = a + (b - a) * fx[None, :]
    bot = c + (d - c) * fx[None, :]
    return top + (bot - top) * fy[:, None]


def palette_tile(size, seed, cols, cells=(4, 8), weights=(0.6, 0.4)):
    n = noise_tile(size, seed, cells[0]) * weights[0] + noise_tile(size, seed + 1, cells[1]) * weights[1]
    n = (n - n.min()) / (n.max() - n.min() + 1e-9)
    bay = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 - 0.47
    yy, xx = np.mgrid[0:size, 0:size]
    n = np.clip(n + bay[yy % 4, xx % 4] * (1.2 / len(cols)), 0, 0.999)
    idx = (n * len(cols)).astype(int)
    arr = np.array([hexc(c) for c in cols], dtype=np.uint8)[idx]
    return arr


def tex_grass():
    size = 64
    arr = palette_tile(size, 101, ["#3e6a36", "#4c7c3c", "#5a8c44", "#6c9c4c"])
    rng = random.Random(5)
    for _ in range(90):  # blades
        x, y = rng.randrange(size), rng.randrange(size)
        arr[y, x] = hexc("#86b45a")
        arr[(y + 1) % size, x] = hexc("#5a8c44")
    for _ in range(10):  # tiny flowers
        x, y = rng.randrange(size), rng.randrange(size)
        arr[y, x] = hexc(rng.choice(["#f0e8c8", "#f0b8c8", "#e8d060"]))
    return Image.fromarray(arr, "RGB")


def tex_dirt():
    size = 64
    arr = palette_tile(size, 202, ["#8a6a4a", "#9c7a54", "#ac8a60", "#b89a6c"])
    rng = random.Random(9)
    for _ in range(26):
        x, y = rng.randrange(size - 1), rng.randrange(size - 1)
        arr[y, x] = hexc("#cdb48a")
        arr[y + 1, x + 1] = hexc("#6e5238")
    return Image.fromarray(arr, "RGB")


def tex_plaster():
    size = 32
    arr = palette_tile(size, 303, ["#d8ccb0", "#e2d8be", "#ece4cc"], cells=(2, 4))
    return Image.fromarray(arr, "RGB")


def tex_wood():
    """Vertical dark planks."""
    size = 32
    arr = palette_tile(size, 404, ["#4a3428", "#5a4030", "#664a36"], cells=(2, 8))
    for x in range(0, size, 8):
        arr[:, x] = hexc("#2c1e18")
    rng = random.Random(4)
    for _ in range(10):
        x, y = rng.randrange(size), rng.randrange(size - 3)
        if x % 8:
            for k in range(3):
                arr[y + k, x] = hexc("#3a2a20")
    return Image.fromarray(arr, "RGB")


def tex_roof():
    """Kawara clay roof tiles: rows of rounded tiles with dark grooves."""
    size = 32
    arr = np.zeros((size, size, 3), dtype=np.uint8)
    cols = [hexc(c) for c in ("#3c4458", "#4e5870", "#64708a", "#8490a8")]
    for y in range(size):
        for x in range(size):
            u = (x % 8) / 8.0            # across one tile column
            v = (y % 16) / 16.0          # down one course
            curve = math.sin(u * math.pi)  # rounded tile
            shade = curve * 0.85 + (1 - v) * 0.25
            if x % 8 == 0:
                shade = -1
            if y % 16 >= 14:
                shade = -0.5 if y % 16 == 14 else 0.0
            idx = 0 if shade < 0 else min(3, int(shade * 3.2) + 0)
            arr[y, x] = cols[idx]
    return Image.fromarray(arr, "RGB")


def tex_stone():
    size = 32
    arr = palette_tile(size, 505, ["#6a6a70", "#7c7c84", "#8e8e96", "#a0a0a8"], cells=(4, 8))
    # mortar courses
    for y in (0, 10, 21):
        arr[y, :] = hexc("#4a4a52")
    for y0, y1, xs in ((0, 10, (0, 14)), (10, 21, (7, 23)), (21, 32, (3, 18, 28))):
        for x in xs:
            arr[y0:y1, x] = hexc("#4a4a52")
    return Image.fromarray(arr, "RGB")


def tex_shoji():
    size = 32
    arr = np.full((size, size, 3), hexc("#f2ead4"), dtype=np.uint8)
    for k in range(0, size, 8):
        arr[k, :] = hexc("#6a4a34")
        arr[:, k] = hexc("#6a4a34")
    return Image.fromarray(arr, "RGB")


def tex_water():
    size = 32
    arr = palette_tile(size, 606, ["#2a5a78", "#336a88", "#3e7a98", "#5a98b4"], cells=(2, 4))
    return Image.fromarray(arr, "RGB")


def tex_banner():
    """Corvo war banner: black cloth, white circle, black crow."""
    w, h = 32, 64
    arr = np.zeros((h, w, 3), dtype=np.uint8)
    arr[:] = hexc("#1c1a20")
    for y in range(h):
        for x in range(w):
            if (x - 16) ** 2 + (y - 22) ** 2 <= 11 ** 2:
                arr[y, x] = hexc("#e8e0d0")
    crow = [
        "......XXX.......",
        ".....XXXXX......",
        "XXX..XXXXXX.....",
        ".XXXXXXXXXXXX...",
        "..XXXXXXXXXXXXX.",
        "...XXXXXXXXX..XX",
        "....XXXXXX......",
        ".....X...X......",
        ".....X...X......",
    ]
    for j, row in enumerate(crow):
        for i, ch in enumerate(row):
            if ch == "X":
                arr[17 + j, 8 + i] = hexc("#141216")
    arr[:, 0] = hexc("#a02a24")
    arr[:, w - 1] = hexc("#a02a24")
    for y in range(44, 64, 4):
        arr[y, :] = hexc("#2a262e")
    return Image.fromarray(arr, "RGB")


def tex_canvas():
    size = 32
    arr = palette_tile(size, 707, ["#8a7a62", "#9a8a70", "#a8987c"], cells=(2, 8))
    for x in range(0, size, 6):
        arr[:, x] = hexc("#7a6a54")
    return Image.fromarray(arr, "RGB")


def preview(img: Image.Image, scale: int, path: str):
    img.resize((img.width * scale, img.height * scale), Image.NEAREST).save(path)


def main():
    os.makedirs(SPR, exist_ok=True)
    os.makedirs(TEX, exist_ok=True)
    for arch in ARCHETYPES:
        character_sheet(arch).save(os.path.join(SPR, f"char_{arch}.png"))
        if ARCHETYPES[arch]["sword"]:
            combat_sheet(arch).save(os.path.join(SPR, f"combat_{arch}.png"))
    fx_slash().save(os.path.join(SPR, "fx_slash.png"))
    fx_hit().save(os.path.join(SPR, "fx_hit.png"))
    fx_fire().save(os.path.join(SPR, "fx_fire.png"))
    for kind in SLASH_STYLES:
        fx_slash_strip(kind).save(os.path.join(SPR, f"fx_slash_{kind}.png"))
    fx_spark().save(os.path.join(SPR, "fx_spark.png"))
    ui_dir = os.path.join(os.path.dirname(SPR), "ui")
    os.makedirs(ui_dir, exist_ok=True)
    ui_washi().save(os.path.join(ui_dir, "washi.png"))
    ui_seal().save(os.path.join(ui_dir, "seal.png"))
    sakura().save(os.path.join(SPR, "tree_sakura.png"))
    pine().save(os.path.join(SPR, "tree_pine.png"))
    maple().save(os.path.join(SPR, "tree_maple.png"))
    bush().save(os.path.join(SPR, "bush.png"))
    for name, fn in (("grass", tex_grass), ("dirt", tex_dirt), ("plaster", tex_plaster),
                     ("wood", tex_wood), ("roof", tex_roof), ("stone", tex_stone),
                     ("shoji", tex_shoji), ("water", tex_water), ("banner", tex_banner),
                     ("canvas", tex_canvas)):
        fn().save(os.path.join(TEX, f"{name}.png"))
    print("art generated:", sorted(os.listdir(SPR)), sorted(os.listdir(TEX)))


if __name__ == "__main__":
    main()
