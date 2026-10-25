"""UI style mockups over a real game frame (for choosing a direction).

Renders the dialogue box + name tag + clock panel in three styles onto the
same clean screenshot, plus the current style for reference.
"""
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import numpy as np

T = os.environ["TMPDIR"] + "/fonts/"
OUT = ".captures/ui_variants/"
os.makedirs(OUT, exist_ok=True)
BG = Image.open(".promo/01_tarde.png").convert("RGB").resize((1280, 720), Image.LANCZOS)
DEJA = "assets/fonts/DejaVuSans.ttf"
LINE1 = "Bem-vindo à casa de chá Yamabuki! Senta-te, viajante. O chá é quente"
LINE2 = "e as notícias são de graça. O Genzō diz que o aço voltará."
NAME = "Oyuki"
BOX = (110, 545, 1170, 690)


def font(path, size):
    return ImageFont.truetype(path, size)


def gradient(w, h, top, bottom):
    a = np.linspace(0, 1, h)[:, None, None]
    c = np.array(top, float) * (1 - a) + np.array(bottom, float) * a
    return Image.fromarray(np.repeat(c, w, axis=1).astype(np.uint8), "RGBA")


def paper(w, h, base=(236, 226, 203), seed=3):
    rng = np.random.default_rng(seed)
    n = rng.normal(0, 1, (h // 2 + 1, w // 2 + 1))
    n = np.asarray(Image.fromarray(((n - n.min()) / (n.max() - n.min()) * 255).astype(np.uint8)).resize((w, h), Image.BILINEAR).filter(ImageFilter.GaussianBlur(1.2)), float) / 255
    fib = np.zeros((h, w))
    for _ in range(int(w * h / 900)):          # washi fibres
        x, y = rng.integers(0, w), rng.integers(0, h)
        L = rng.integers(6, 22)
        ang = rng.uniform(0, np.pi)
        for t in range(L):
            xx, yy = int(x + np.cos(ang) * t), int(y + np.sin(ang) * t)
            if 0 <= xx < w and 0 <= yy < h:
                fib[yy, xx] = 1
    arr = np.zeros((h, w, 4))
    for i in range(3):
        arr[..., i] = base[i] * (0.93 + 0.1 * n) - fib * 18
    arr[..., 3] = 255
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")


def text(d, xy, s, f, fill, stroke=0, sfill=None):
    d.text(xy, s, font=f, fill=fill, stroke_width=stroke, stroke_fill=sfill)


# ---------------------------------------------------------------- current
def v0():
    im = BG.convert("RGBA")
    d = ImageDraw.Draw(im)
    x0, y0, x1, y1 = BOX
    d.rectangle(BOX, fill=(14, 16, 34, 235), outline=(214, 184, 120), width=2)
    d.rectangle((140, 525, 230, 556), fill=(120, 26, 30), outline=(214, 184, 120), width=2)
    f = font(DEJA, 22)
    text(d, (157, 528), NAME, font(DEJA, 18), (255, 240, 220))
    text(d, (140, 572), LINE1, f, (238, 234, 226))
    text(d, (140, 604), LINE2, f, (238, 234, 226))
    d.rectangle((24, 20, 278, 124), fill=(14, 16, 34, 235), outline=(214, 184, 120), width=2)
    text(d, (40, 30), "Dia 1 · Tarde", font(DEJA, 22), (255, 240, 220))
    d.rectangle((40, 82, 190, 92), fill=(200, 50, 50))
    return im


# ---------------------------------------------------------------- A: laca e ouro
def lacquer_panel(w, h):
    p = gradient(w, h, (34, 14, 18, 238), (12, 6, 10, 242))
    d = ImageDraw.Draw(p)
    gold, dark = (222, 184, 104, 255), (120, 86, 40, 255)
    d.rectangle((0, 0, w - 1, h - 1), outline=dark, width=1)
    d.rectangle((3, 3, w - 4, h - 4), outline=gold, width=2)
    d.rectangle((8, 8, w - 9, h - 9), outline=(150, 112, 56, 200), width=1)
    for cx, cy in ((3, 3), (w - 4, 3), (3, h - 4), (w - 4, h - 4)):   # corner knots
        d.rectangle((cx - 6, cy - 6, cx + 6, cy + 6), fill=(34, 14, 18, 255), outline=gold, width=2)
        d.rectangle((cx - 2, cy - 2, cx + 2, cy + 2), fill=gold)
    # faint maki-e wave band at the bottom
    for x in range(14, w - 14, 18):
        d.arc((x, h - 26, x + 18, h - 8), 200, 340, fill=(160, 120, 60, 70), width=1)
    return p


def vA():
    im = BG.convert("RGBA")
    x0, y0, x1, y1 = BOX
    im.alpha_composite(lacquer_panel(x1 - x0, y1 - y0), (x0, y0))
    im.alpha_composite(lacquer_panel(254, 104), (24, 20))
    d = ImageDraw.Draw(im)
    hm = T + "HinaMincho-Latin.ttf"
    # name: vertical red cord tag
    d.polygon([(132, 520), (262, 520), (272, 538), (262, 556), (132, 556)], fill=(150, 28, 32, 255), outline=(222, 184, 104))
    text(d, (148, 523), NAME, font(hm, 24), (255, 236, 200))
    f = font(hm, 25)
    text(d, (140, 574), LINE1, f, (246, 232, 206))
    text(d, (140, 610), LINE2, f, (246, 232, 206))
    text(d, (1136, 652), "▼", font(DEJA, 16), (222, 184, 104))
    text(d, (42, 30), "Dia 1 · Tarde", font(hm, 26), (246, 228, 190))
    for i in range(8):
        d.ellipse((42 + i * 15, 66, 52 + i * 15, 76), fill=(222, 184, 104) if i < 7 else None, outline=(222, 184, 104))
    d.rectangle((42, 86, 192, 94), fill=(70, 20, 22))
    d.rectangle((42, 86, 192, 94), fill=(196, 52, 46))
    text(d, (200, 81), "110/110", font(hm, 16), (230, 214, 186))
    return im


# ---------------------------------------------------------------- B: washi e tinta
def washi_panel(w, h, seed=3):
    p = paper(w, h, seed=seed)
    # torn / brushed edges: alpha noise at the border
    a = np.asarray(p)[..., 3].astype(float)
    rng = np.random.default_rng(seed + 1)
    edge = np.ones((h, w))
    for x in range(w):
        t1, t2 = rng.integers(0, 4), rng.integers(0, 4)
        edge[:t1, x] = 0
        edge[h - t2:, x] = 0
    for y in range(h):
        t1, t2 = rng.integers(0, 4), rng.integers(0, 4)
        edge[y, :t1] = 0
        edge[y, w - t2:] = 0
    arr = np.asarray(p).copy()
    arr[..., 3] = (a * edge * 0.96).astype(np.uint8)
    p = Image.fromarray(arr, "RGBA")
    d = ImageDraw.Draw(p)
    # ink brush rule along the top and bottom
    for yy, wd in ((10, 3), (h - 12, 2)):
        for x in range(16, w - 16):
            j = int(1.2 * np.sin(x * 0.05 + yy))
            d.line([(x, yy + j), (x, yy + j + wd)], fill=(40, 30, 28, 200))
    return p


def vB():
    im = BG.convert("RGBA")
    x0, y0, x1, y1 = BOX
    sh = Image.new("RGBA", im.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).rectangle((x0 + 6, y0 + 8, x1 + 6, y1 + 8), fill=(0, 0, 0, 110))
    im.alpha_composite(sh.filter(ImageFilter.GaussianBlur(6)))
    im.alpha_composite(washi_panel(x1 - x0, y1 - y0), (x0, y0))
    im.alpha_composite(washi_panel(254, 104, seed=9), (24, 20))
    d = ImageDraw.Draw(im)
    hm = T + "HinaMincho-Latin.ttf"
    # hanko-style red seal with the name
    d.rounded_rectangle((128, 518, 238, 556), 4, fill=(176, 34, 30, 255))
    d.rounded_rectangle((132, 522, 234, 552), 3, outline=(240, 210, 200, 200), width=1)
    text(d, (146, 522), NAME, font(hm, 24), (252, 238, 228))
    ink = (34, 26, 24)
    f = font(hm, 25)
    text(d, (142, 576), LINE1, f, ink)
    text(d, (142, 612), LINE2, f, ink)
    text(d, (1136, 652), "▼", font(DEJA, 16), (176, 34, 30))
    text(d, (42, 32), "Dia 1 · Tarde", font(hm, 26), ink)
    for i in range(8):
        d.ellipse((42 + i * 15, 68, 52 + i * 15, 78), fill=ink if i < 7 else None, outline=ink)
    d.rectangle((42, 88, 192, 95), fill=(176, 34, 30))
    text(d, (200, 82), "110/110", font(hm, 16), ink)
    return im


# ---------------------------------------------------------------- C: pixel
def pixel_panel(w, h, s=3):
    sw, shh = w // s, h // s
    p = Image.new("RGBA", (sw, shh), (0, 0, 0, 0))
    d = ImageDraw.Draw(p)
    d.rectangle((1, 1, sw - 2, shh - 2), fill=(26, 22, 44, 240))
    d.rectangle((0, 1, 0, shh - 2), fill=(10, 8, 18))
    d.rectangle((sw - 1, 1, sw - 1, shh - 2), fill=(10, 8, 18))
    d.rectangle((1, 0, sw - 2, 0), fill=(10, 8, 18))
    d.rectangle((1, shh - 1, sw - 2, shh - 1), fill=(10, 8, 18))
    d.rectangle((2, 2, sw - 3, 2), fill=(232, 200, 128))          # bevel light
    d.rectangle((2, 2, 2, shh - 3), fill=(232, 200, 128))
    d.rectangle((3, shh - 3, sw - 3, shh - 3), fill=(140, 96, 52))  # bevel shadow
    d.rectangle((sw - 3, 3, sw - 3, shh - 3), fill=(140, 96, 52))
    for y in range(4, shh - 4, 2):                                     # dithered depth
        for x in range(4 + (y // 2) % 2, sw - 4, 2):
            if y > shh * 0.55:
                p.putpixel((x, y), (20, 16, 34, 240))
    return p.resize((sw * s, shh * s), Image.NEAREST)


def vC():
    im = BG.convert("RGBA")
    x0, y0, x1, y1 = BOX
    im.alpha_composite(pixel_panel(x1 - x0, y1 - y0), (x0, y0))
    im.alpha_composite(pixel_panel(255, 105), (24, 20))
    im.alpha_composite(pixel_panel(117, 39), (128, 518))
    d = ImageDraw.Draw(im)
    px = T + "PixelifySans[wght].ttf"
    text(d, (146, 521), NAME, font(px, 24), (255, 226, 150))
    f = font(px, 24)
    text(d, (140, 574), LINE1, f, (240, 236, 226))
    text(d, (140, 608), LINE2, f, (240, 236, 226))
    text(d, (1134, 650), "▼", font(DEJA, 16), (232, 200, 128))
    text(d, (42, 30), "Dia 1 · Tarde", font(px, 26), (255, 226, 150))
    for i in range(8):
        x = 42 + i * 15
        d.rectangle((x, 66, x + 9, 75), fill=(232, 200, 128) if i < 7 else (60, 50, 80))
    d.rectangle((42, 86, 192, 95), fill=(60, 20, 30))
    d.rectangle((42, 86, 192, 95), fill=(214, 64, 60))
    text(d, (200, 81), "110/110", font(px, 16), (240, 236, 226))
    return im


for name, fn in (("0_atual", v0), ("A_laca_e_ouro", vA), ("B_washi_e_tinta", vB), ("C_pixel", vC)):
    fn().convert("RGB").save(OUT + name + ".png")
print(sorted(os.listdir(OUT)))
