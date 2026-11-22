"""Pip the penguin - sky-blue tuxedo, spiky head tuft, cheering beak. Vehicle: propeller pack with glider wings."""
from kit import *

PAL = dict(light="#E6F1FB", main="#378ADD", dark="#185FA5", line="#0C447C", belly="#FFFFFF", iris="#58B0F5")
ORANGE, ORL = "#FFAE2B", "#9A4E0B"
RED, REDL = "#E8504E", "#8E1F24"
STEEL, STEELL = "#C3C9D2", "#3D4652"
ARMS = {"default": 118, "joy": 152, "scared": 64, "speed": 14}


def beak(expr, cx, y):
    o = ""
    if expr in ("default", "joy"):
        h = 26 if expr == "default" else 34
        d = "M%s %s Q%s %s %s %s Q%s %s %s %s Z" % (f(cx - 20), f(y), f(cx), f(y + h * 1.7), f(cx + 20), f(y),
                                                    f(cx), f(y - 6), f(cx - 20), f(y))
        g = P(d)
        o += flat(g, "#C4472B") + clipped(g, flat(E(cx, y + h * 0.9, 12, 9), "#FF9A8A")) + stroke(g, ORL, 6)
    up = "M%s %s Q%s %s %s %s Q%s %s %s %s Z" % (f(cx - 26), f(y), f(cx), f(y - 26), f(cx + 26), f(y),
                                                 f(cx), f(y + (10 if expr in ("default", "joy") else 20)), f(cx - 26), f(y))
    o += sh(P(up), ORANGE, ORL, 6, dx=-3, dy=-4)
    return o


def head(expr, cx=256, cy=200):
    p = PAL; L = p["line"]; G = p["main"]
    o = ""
    for dx, top, w, rot in ((-24, 62, 15, -22), (2, 50, 17, 2), (27, 64, 15, 24)):
        o += sh(E(cx + dx, cy - 150 + top, w, 34, rot), p["dark"], L, 7, dx=-3, dy=-4)
    hg = E(cx, cy, 128, 112)
    o += sh(hg, G, L, dx=-10, dy=-12)
    mask = flat(E(cx - 50, cy + 16, 64, 72), "#DCEBFA") + flat(E(cx + 50, cy + 16, 64, 72), "#DCEBFA") + flat(E(cx, cy + 70, 92, 60), "#DCEBFA")
    mask += flat(E(cx - 54, cy + 12, 64, 72), "#FFFFFF") + flat(E(cx + 46, cy + 12, 64, 72), "#FFFFFF") + flat(E(cx - 4, cy + 66, 92, 60), "#FFFFFF")
    o += clipped(hg, mask) + stroke(hg, L, 8)
    o += gloss(cx - 82, cy - 64, 28, 13)
    ey = cy + 14
    if expr == "scared":
        o += brow(cx - 52, ey - 56, 18, -6, -1, L) + brow(cx + 52, ey - 56, 18, -6, 1, L)
    for sx in (-1, 1):
        o += eye(cx + sx * 52, ey, 28, 35, L, p["iris"], {"default": "open"}.get(expr, expr), sx, "#FFFFFF")
    o += blush(cx - 94, cy + 58, col="#FF9C9C", op=0.8) + blush(cx + 94, cy + 58, col="#FF9C9C", op=0.8)
    o += beak(expr, cx, cy + 62)
    return o


def bowtie():
    o = ""
    for sx in (-1, 1):
        d = "M256 314 L%s 296 Q%s 314 %s 334 Z" % (f(256 + sx * 36), f(256 + sx * 42), f(256 + sx * 36))
        o += sh(P(d), RED, REDL, 6, dx=-2, dy=-3)
    return o + sh(C(256, 314, 10), RED, REDL, 6, dx=-2, dy=-2)


def fig(expr="default", arms=None):
    p = PAL; L = p["line"]
    a = ARMS[expr] if arms is None else arms
    o = ""
    o += sh(E(218, 448, 34, 17), ORANGE, ORL, 7, dx=-4, dy=-5) + sh(E(294, 448, 34, 17), ORANGE, ORL, 7, dx=-4, dy=-5)
    o += limb(184, 336, 80, 42, a, -1, p["dark"], L) + limb(328, 336, 80, 42, a, 1, p["dark"], L)
    bg = E(256, 372, 86, 84)
    o += sh(bg, p["main"], L)
    o += clipped(bg, flat(E(256, 392, 62, 70), "#DCEBFA") + flat(E(251, 386, 62, 70), "#FFFFFF")) + stroke(bg, L, 8)
    o += bowtie()
    o += head(expr)
    return o


ICE, ICEL = "#BFE6FF", "#1B6FB5"
GLIDE = {"default": 98, "joy": 132, "scared": 74, "speed": 62}


def glider():
    """Belly Glider: a little ice-blue board with stubby wings."""
    wing = "M256 404 Q150 372 44 398 Q26 424 52 438 Q160 446 256 452 Z"
    o = sh(P(wing), "#E4F4FF", ICEL, 7) + mirror(sh(P(wing), "#E4F4FF", ICEL, 7))
    g = E(256, 440, 168, 46)
    o += sh(g, ICE, ICEL, 8, dx=-8, dy=-8)
    o += clipped(g, stroke(P("M100 452 Q256 500 412 452"), "#FFFFFF", 7, op=0.8)
                 + flat(E(190, 418, 70, 9, -4), "#FFFFFF", op=0.6)) + stroke(g, ICEL, 8)
    return o


def ride(expr="default"):
    """Tobogganing toward the viewer: head in front, body and feet behind."""
    rot = {"speed": -6, "scared": 5}.get(expr, 0)
    p = PAL; L = p["line"]
    a = GLIDE[expr]
    o = glider()
    # feet stay hidden behind the body (peeking over the head they read as
    # horns); a tail tip and a spray wake sell the slide instead
    for sx in (-1, 1):
        for dx, dy, r in ((196, 196, 17), (222, 176, 11), (176, 172, 8)):
            o += flat(C(256 + sx * dx, 256 + dy, r), "#FFFFFF", ICEL, 5, op=0.95)
    o += sh(P("M236 138 Q256 92 276 138 Z"), p["dark"], L, 7, dx=-3, dy=-4)
    o += limb(162, 282, 124, 50, a, -1, p["dark"], L) + limb(350, 282, 124, 50, a, 1, p["dark"], L)
    o += sh(E(256, 250, 128, 124), p["main"], L)
    o += flat(E(206, 160, 30, 13, -30), "#FFFFFF", op=0.3)
    o += group(bowtie(), ty=118)
    o += head(expr, 256, 312)
    return group(place(o, 0.97, 256, 462), rot=rot) + fx(expr, (40, 60, 472, 440))


def vehicle():
    return place(glider(), 1.0, 256, 320)


ICON = dict(s=1.3, cx=256, cy=272)
STAND = dict(s=0.94, by=462)
CLOUD = dict(s=0.9, by=420)


# --- Back view --------------------------------------------------------------

def head_back(expr, cx=256, cy=200):
    p = PAL; L = p["line"]; G = p["main"]
    o = ""
    for dx, top, w, rot in ((-24, 62, 15, -22), (2, 50, 17, 2), (27, 64, 15, 24)):
        o += sh(E(cx + dx, cy - 150 + top, w, 34, rot), p["dark"], L, 7, dx=-3, dy=-4)
    hg = E(cx, cy, 128, 112)
    o += sh(hg, G, L, dx=-10, dy=-12)
    o += clipped(hg, flat(E(cx, cy - 30, 100, 80), p["dark"], op=0.35))
    o += stroke(hg, L, 8)
    o += gloss(cx - 70, cy - 64, 28, 13)
    # bow-tie ribbon round the back of the neck
    o += stroke(P("M%s %s Q%s %s %s %s" % (f(cx - 90), f(cy + 92), f(cx), f(cy + 112), f(cx + 90), f(cy + 92))), RED, 10)
    return o


def fig_back(expr="default", arms=None):
    p = PAL; L = p["line"]
    a = ARMS[expr] if arms is None else arms
    o = sh(E(218, 452, 34, 17), ORANGE, ORL, 7, dx=-4, dy=-5) + sh(E(294, 452, 34, 17), ORANGE, ORL, 7, dx=-4, dy=-5)
    o += limb(184, 336, 80, 42, a, -1, p["dark"], L) + limb(328, 336, 80, 42, a, 1, p["dark"], L)
    bg = E(256, 372, 86, 84)
    o += sh(bg, p["main"], L)
    o += clipped(bg, flat(E(256, 352, 60, 70), p["dark"], op=0.4)) + stroke(bg, L, 8)
    o += sh(P("M240 444 L256 474 L272 444 Z"), p["dark"], L, 6, dx=-2, dy=-2)   # tail
    o += head_back(expr)
    return o


def ride_back(expr="default"):
    """Riding the glider away from the camera, flippers out for balance."""
    rot = {"speed": 6, "scared": -5}.get(expr, 0)
    a = GLIDE[expr]
    o = glider()
    o += place(fig_back(expr, arms=a), 0.86, 256, 440)
    return group(place(o, 0.97, 256, 462), rot=rot) + fx(expr, (40, 60, 472, 440))
