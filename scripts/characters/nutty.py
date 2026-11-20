"""Nutty the hamster - lopsided stuffed cheeks, round ears, sunflower seed. Vehicle: acorn copter."""
from kit import *

PAL = dict(light="#FAEEDA", main="#EF9F27", dark="#BA7517", line="#633806", belly="#FAC775", iris="#D98A1E")
CREAM = "#FFF3DC"
POUCH = "#FFDDA6"
ARMS = {"default": None, "joy": 150, "scared": 100, "speed": 60}
CHEEK = {"default": (44, 58), "joy": (54, 66), "scared": (30, 34), "speed": (40, 50)}


def seed(cx, cy, s=1.0, rot=0):
    d = "M%s %s Q%s %s %s %s Q%s %s %s %s Z" % (f(cx), f(cy - 26 * s), f(cx + 18 * s), f(cy), f(cx), f(cy + 20 * s),
                                                f(cx - 18 * s), f(cy), f(cx), f(cy - 26 * s))
    g = P(d, (rot, cx, cy))
    return flat(g, "#3B3530") + clipped(g, stroke(P("M%s %s V%s M%s %s V%s" % (
        f(cx - 5 * s), f(cy - 30 * s), f(cy + 24 * s), f(cx + 5 * s), f(cy - 30 * s), f(cy + 24 * s)), (rot, cx, cy)), "#F4EFE6", 3.5 * s)) + stroke(g, "#1E1A16", 5)


def head(expr, cx=256, cy=200):
    p = PAL; L = p["line"]; G = p["main"]
    o = ""
    for sx in (-1, 1):
        o += sh(C(cx + sx * 88, cy - 88, 36), G, L, dx=-5, dy=-6)
        o += flat(C(cx + sx * 88, cy - 84, 20), "#F9B4AE")
    hg = E(cx, cy, 134, 112)
    o += sh(hg, G, L, dx=-10, dy=-12)
    o += clipped(hg, flat(E(cx, cy + 78, 112, 78), CREAM) + flat(E(cx, cy - 20, 30, 70), CREAM)) + stroke(hg, L, 8)
    o += gloss(cx - 84, cy - 62, 28, 13)
    rl, rr = CHEEK[expr]
    sq = 0.78 if expr == "speed" else 0.92
    o += sh(E(cx - 114, cy + 64, rl, rl * sq), POUCH, L, dx=-5, dy=-6)
    o += sh(E(cx + 116, cy + 66, rr, rr * sq), POUCH, L, dx=-6, dy=-7)
    o += blush(cx - 118, cy + 70, 20, 12) + blush(cx + 122, cy + 74, 24, 14)
    ey = cy + 4
    if expr == "scared":
        o += brow(cx - 50, ey - 54, 18, -6, -1, L) + brow(cx + 52, ey - 58, 18, -6, 1, L)
    m = {"default": "open"}.get(expr, expr)
    o += eye(cx - 50, ey, 25, 32, L, p["iris"], m, -1, G)
    o += eye(cx + 52, ey - 2, 30, 38, L, p["iris"], m, 1, G)
    o += flat(E(cx, cy + 44, 10, 7), "#EE7C86", L, 4)
    my = cy + 54
    if expr in ("default", "joy"):
        o += flat(R(cx - 8, my + 4, 16, 15, 4), "#FFFFFF", L, 4) + stroke(P("M%s %s v12" % (f(cx), f(my + 6))), L, 2.5)
        o += stroke(P("M%s %s q10 12 20 0 q10 12 20 0" % (f(cx - 20), f(my))), L, 5.5)
    elif expr == "scared":
        o += o_mouth(cx, my + 12, 10, 13, L, 5)
    else:
        o += stroke(P("M%s %s q10 8 20 0 q10 8 20 0" % (f(cx - 20), f(my + 2))), L, 5.5)
    for sx in (-1, 1):
        x = cx + sx * 150
        o += stroke(P("M%s %s l%s -10 M%s %s l%s 6" % (f(x), f(cy + 40), f(sx * 30), f(x), f(cy + 58), f(sx * 30))), L, 3, op=0.45)
    return o


def fig(expr="default", arms=None):
    p = PAL; L = p["line"]; G = p["main"]
    a = ARMS[expr] if arms is None else arms
    o = sh(C(340, 430, 18), CREAM, L, 7, dx=-3, dy=-4)
    o += sh(E(214, 448, 30, 16), POUCH, L, 7, dx=-4, dy=-5) + sh(E(298, 448, 30, 16), POUCH, L, 7, dx=-4, dy=-5)
    if a is not None:
        o += limb(192, 344, 56, 34, a, -1, G, L) + limb(320, 344, 56, 34, a, 1, G, L)
    bg = E(256, 378, 90, 80)
    o += sh(bg, G, L)
    o += clipped(bg, flat(E(256, 394, 60, 60), CREAM)) + stroke(bg, L, 8)
    if a is None:
        o += seed(256, 352, 1.5, 10)
        o += sh(E(222, 378, 19, 15, -25), POUCH, L, 7, dx=-3, dy=-3) + sh(E(290, 378, 19, 15, 25), POUCH, L, 7, dx=-3, dy=-3)
    o += head(expr)
    return o


LEAF, LEAFL = "#97C459", "#3B6D11"


def rotor():
    o = flat(R(249, 26, 14, 110, 6), "#8A5A1E", "#4A2A05", 6)
    o += flat(E(256, 34, 168, 22), "#FFFFFF", op=0.38)
    blade = "M256 34 Q190 4 96 26 Q180 66 256 34 Z"
    b = sh(P(blade), LEAF, LEAFL, 6, dx=-3, dy=-3) + stroke(P("M250 34 Q180 30 112 28"), LEAFL, 3.5)
    o += b + mirror(b)
    o += sh(C(256, 34, 13), "#8A5A1E", "#4A2A05", 6, dx=-2, dy=-3)
    return o


BALLL = "#2F78C4"


def ball(front):
    """Clear hamster ball: faint tint behind, gloss and seams in front."""
    g = C(256, 312, 170)
    if not front:
        return flat(g, "#EAF6FF", op=0.45)
    o = flat(g, "#BFE3FF", op=0.05)
    inner = stroke(E(256, 312, 170, 46), "#FFFFFF", 6, op=0.55)
    inner += stroke(P("M150 190 Q110 250 108 320"), "#FFFFFF", 22, op=0.75)
    inner += flat(E(196, 176, 26, 13, -38), "#FFFFFF", op=0.85)
    inner += stroke(P("M330 452 Q384 420 404 366"), "#FFFFFF", 12, op=0.5)
    for x in (236, 256, 276):
        inner += flat(R(x - 4, 452, 8, 20, 4), BALLL, op=0.45)
    o += clipped(g, inner)
    o += stroke(g, BALLL, 9)
    o += sh(E(256, 146, 30, 12), "#8A5A1E", "#4A2A05", 6, dx=-2, dy=-3)
    return o


def ride(expr="default"):
    rot = {"speed": -6, "scared": 5}.get(expr, 0)
    o = rotor() + ball(False) + place(fig(expr), 0.7, 256, 462) + ball(True)
    return group(place(o, 0.99, 256, 486), rot=rot) + fx(expr, (60, 150, 452, 440))


def vehicle():
    return place(rotor() + ball(False) + ball(True), 0.99, 256, 486)


ICON = dict(s=1.2, cx=256, cy=262)
STAND = dict(s=0.96, by=462)
CLOUD = dict(s=0.9, by=420)
