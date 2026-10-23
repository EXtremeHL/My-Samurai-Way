"""Procedural pixel-art generator for O Caminho do Ronin (HD-2D).

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
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPR = os.path.join(ROOT, "assets", "sprites")
TEX = os.path.join(ROOT, "assets", "textures")


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
        if a.get("jingasa"):
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
    if a["topknot"]:
        s.rect("hair", 11, 3 + y0, 15, 6 + y0)
        s.line("white", [(14, 3 + y0), (14, 6 + y0)], flat=True)
    if a.get("headband"):
        s.rect("band", 9, 8 + y0, 22, 9 + y0)
        s.line("band", [(9, 9 + y0), (6, 13 + y0)])
    if a.get("hat"):
        if a.get("jingasa"):
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
    sakura().save(os.path.join(SPR, "tree_sakura.png"))
    pine().save(os.path.join(SPR, "tree_pine.png"))
    maple().save(os.path.join(SPR, "tree_maple.png"))
    bush().save(os.path.join(SPR, "bush.png"))
    for name, fn in (("grass", tex_grass), ("dirt", tex_dirt), ("plaster", tex_plaster),
                     ("wood", tex_wood), ("roof", tex_roof), ("stone", tex_stone),
                     ("shoji", tex_shoji), ("water", tex_water)):
        fn().save(os.path.join(TEX, f"{name}.png"))
    print("art generated:", sorted(os.listdir(SPR)), sorted(os.listdir(TEX)))


if __name__ == "__main__":
    main()
