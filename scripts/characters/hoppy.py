"""Hoppy the bunny - tall ears (one flopped), flower, cotton tail, heart chest. Vehicle: carrot jet."""
from kit import *

PAL = dict(light="#FAECE7", main="#F0997B", dark="#D85A30", line="#712B13", belly="#F5C4B3", iris="#E8703C")
WHITE = "#FFF7F2"
INNER = "#FBC3BE"
ARMS = {"default": -12, "joy": 150, "scared": 104, "speed": 60}
# (left ear rot, right ear rot); None = the flopped default ear
EARS = {"default": (-6, None), "joy": (-9, 9), "scared": (-128, 128), "speed": (54, 76)}


def ear(side, rot):
    p = PAL
    x = 256 + side * 50
    o = sh(E(x, 44, 33, 96), p["main"], p["line"], dx=-5, dy=-6)
    o += flat(E(x, 50, 15, 68), INNER)
    return group(o, rot=rot, about=(x - side * 4, 122))


def flop_ear():
    p = PAL
    o = sh(E(308, 76, 33, 64, 8), p["main"], p["line"], dx=-5, dy=-6)
    o += flat(E(308, 82, 15, 42, 8), INNER)
    o += sh(E(348, 36, 31, 56, 64), p["main"], p["line"], dx=-5, dy=-6)
    return o


def flower(cx, cy):
    o = ""
    import math
    for k in range(5):
        a = math.radians(k * 72 - 90)
        o += flat(C(cx + math.cos(a) * 15, cy + math.sin(a) * 15, 12.5), "#FF9DBE", "#B0456F", 4)
    o += flat(C(cx, cy, 9), "#F7B92E", "#7A4B12", 4)
    return o


def head(expr, cx=256, cy=200):
    p = PAL; L = p["line"]; G = p["main"]
    lr, rr = EARS[expr]
    o = ear(-1, lr)
    o += flop_ear() if rr is None else ear(1, rr)
    for sx in (-1, 1):
        o += sh(C(cx + sx * 118, cy + 34, 22), G, L, 7, dx=-4, dy=-5) + sh(C(cx + sx * 124, cy + 10, 15), G, L, 7, dx=-3, dy=-4)
    hg = E(cx, cy, 124, 108)
    o += sh(hg, G, L, dx=-10, dy=-12)
    for sx in (-1, 1):
        o += flat(C(cx + sx * 108, cy + 26, 20), G)
    o += gloss(cx - 78, cy - 60, 28, 13)
    o += flat(E(cx, cy + 56, 46, 32), WHITE)
    ey = cy + 12
    m = {"default": "open"}.get(expr, expr)
    if expr == "default":
        o += brow(cx - 52, ey - 52, 16, -4, -1, L, 5, 0.5) + brow(cx + 52, ey - 52, 16, -4, 1, L, 5, 0.5)
    if expr == "scared":
        o += brow(cx - 52, ey - 56, 18, -6, -1, L) + brow(cx + 52, ey - 56, 18, -6, 1, L)
    for sx in (-1, 1):
        o += eye(cx + sx * 52, ey, 28, 36, L, p["iris"], m, sx, G)
    o += blush(cx - 94, cy + 56, 24, 14, "#FF8FB0", 0.7) + blush(cx + 94, cy + 56, 24, 14, "#FF8FB0", 0.7)
    o += flat(P("M%s %s q10 -8 20 0 q-2 10 -10 13 q-8 -3 -10 -13 Z" % (f(cx - 10), f(cy + 42))), "#F0647E", L, 4)
    my = cy + 60
    if expr == "joy":
        o += open_mouth(cx, my - 2, 15, 20, L, 5)
    elif expr == "scared":
        o += o_mouth(cx, my + 8, 8, 10, L, 5)
    elif expr == "speed":
        o += stroke(P("M%s %s q12 6 24 0" % (f(cx - 12), f(my + 4))), L, 5.5)
    else:
        o += stroke(P("M%s %s v6 M%s %s q7 9 14 0 q7 9 14 0" % (f(cx), f(my - 6), f(cx - 14), f(my))), L, 5)
    if expr != "scared":
        o += flower(cx - 96, cy - 86)
    return o


def fig(expr="default", arms=None):
    p = PAL; L = p["line"]; G = p["main"]
    a = ARMS[expr] if arms is None else arms
    o = sh(C(340, 424, 24), WHITE, L, 7, dx=-4, dy=-5) + sh(C(356, 404, 15), WHITE, L, 7, dx=-3, dy=-4)
    o += sh(E(212, 448, 38, 18), G, L, 7, dx=-4, dy=-5) + sh(E(300, 448, 38, 18), G, L, 7, dx=-4, dy=-5)
    if a > 0:
        o += limb(204, 342, 60, 32, a, -1, G, L) + limb(308, 342, 60, 32, a, 1, G, L)
    bg = E(256, 378, 78, 78)
    o += sh(bg, G, L)
    heart = "M256 404 Q214 370 228 346 Q242 328 256 348 Q270 328 284 346 Q298 370 256 404 Z"
    o += flat(P(heart), WHITE)
    if a <= 0:
        o += limb(190, 344, 58, 28, a, -1, G, L) + limb(322, 344, 58, 28, a, 1, G, L)
    o += head(expr)
    return o


CAR, CARL = "#FF8A2B", "#8A3A0B"


def carrot_body():
    g = P("M26 410 Q110 344 300 340 Q440 338 462 396 Q444 462 300 462 Q110 466 26 410 Z")
    o = sh(g, CAR, CARL, 8, dx=-6, dy=-12)
    inner = flat(P("M26 410 Q70 380 110 372 Q96 410 112 450 Q60 436 26 410 Z"), "#E06A12")
    inner += stroke(P("M170 352 q16 26 2 50 M250 344 q18 40 2 70 M340 400 q12 30 0 58 M400 346 q14 26 4 50"), CARL, 4.5, op=0.5)
    inner += flat(E(220, 366, 110, 9, -3), "#FFFFFF", op=0.3)
    return o, g, inner


def leaves():
    o = ""
    for rot, l in ((-38, 92), (-8, 104), (24, 88)):
        g = E(462 + l / 2 - 10, 396, l / 2, 24)
        o += '<g transform="rotate(%s 456 396)">\n%s%s</g>\n' % (
            f(rot), sh(g, "#8BCB4C", "#2F6A12", 7, dx=-3, dy=-5),
            stroke(P("M462 396 h%s" % f(l - 30)), "#2F6A12", 3.5, op=0.6))
    return o


def ride(expr="default"):
    rot = {"speed": -9, "scared": 2}.get(expr, -4)
    body, g, inner = carrot_body()
    o = leaves() + body + clipped(g, inner) + stroke(g, CARL, 8)
    o += flat(E(262, 352, 104, 20), "#B3500F", CARL, 7)
    o += place(fig(expr), 0.86, 262, 432)
    kit_lip = clipped(P("M0 366 H512 V512 H0 Z"), '<%s fill="%s"/>\n' % (g, CAR) + clipped(g, inner) + stroke(g, CARL, 8))
    o += kit_lip
    o += stroke(P("M158 354 Q262 388 366 354"), CARL, 7)
    o += sh(P("M300 458 Q330 500 392 492 Q372 470 372 452 Z"), "#E06A12", CARL, 7, dx=-3, dy=-4)
    return group(place(o, 0.95, 250, 474), rot=rot) + fx(expr, (50, 60, 462, 440))


def vehicle():
    body, g, inner = carrot_body()
    o = leaves() + body + clipped(g, inner) + stroke(g, CARL, 8)
    o += flat(E(262, 352, 104, 20), "#B3500F", CARL, 7)
    o += sh(P("M300 458 Q330 500 392 492 Q372 470 372 452 Z"), "#E06A12", CARL, 7, dx=-3, dy=-4)
    return place(o, 0.86, 232, 380)


ICON = dict(s=1.0, cx=256, cy=312)
STAND = dict(s=0.84, by=462)
CLOUD = dict(s=0.78, by=420)


# --- Back view --------------------------------------------------------------

def ear_back(side, rot):
    p = PAL
    x = 256 + side * 50
    return group(sh(E(x, 44, 33, 96), p["main"], p["line"], dx=-5, dy=-6), rot=rot, about=(x - side * 4, 122))


def flop_ear_back():
    p = PAL
    return (sh(E(308, 76, 33, 64, 8), p["main"], p["line"], dx=-5, dy=-6)
            + sh(E(348, 36, 31, 56, 64), p["main"], p["line"], dx=-5, dy=-6))


def head_back(expr, cx=256, cy=200):
    p = PAL; L = p["line"]; G = p["main"]
    lr, rr = EARS[expr]
    # From behind the flopped ear is on the other side.
    ears = ear_back(-1, lr) + (flop_ear_back() if rr is None else ear_back(1, rr))
    o = mirror(ears) if rr is None else ears
    for sx in (-1, 1):
        o += sh(C(cx + sx * 118, cy + 34, 22), G, L, 7, dx=-4, dy=-5)
    hg = E(cx, cy, 124, 108)
    o += sh(hg, G, L, dx=-10, dy=-12)
    o += clipped(hg, flat(E(cx, cy - 20, 60, 70), p["light"], op=0.35)) + stroke(hg, L, 8)
    o += gloss(cx - 70, cy - 60, 28, 13)
    if expr != "scared":
        o += flower(cx + 96, cy - 86)
    return o


def fig_back(expr="default", arms=None):
    p = PAL; L = p["line"]; G = p["main"]
    a = ARMS[expr] if arms is None else arms
    o = sh(E(212, 452, 38, 18), G, L, 7, dx=-4, dy=-5) + sh(E(300, 452, 38, 18), G, L, 7, dx=-4, dy=-5)
    o += limb(204, 342, 60, 32, a, -1, G, L) + limb(308, 342, 60, 32, a, 1, G, L)
    bg = E(256, 378, 78, 78)
    o += sh(bg, G, L)
    o += head_back(expr)
    # the cotton tail is the star of the back view
    o += sh(C(256, 426, 30), WHITE, L, 7, dx=-4, dy=-5) + sh(C(240, 414, 14), WHITE, L, 0, dx=-2, dy=-2)
    return o


def ride_back(expr="default"):
    rot = {"speed": 9, "scared": -2}.get(expr, 4)
    body, g, inner = carrot_body()
    o = leaves() + body + clipped(g, inner) + stroke(g, CARL, 8)
    o += flat(E(262, 352, 104, 20), "#B3500F", CARL, 7)
    o += place(fig_back(expr), 0.86, 262, 432)
    kit_lip = clipped(P("M0 366 H512 V512 H0 Z"), '<%s fill="%s"/>\n' % (g, CAR) + clipped(g, inner) + stroke(g, CARL, 8))
    o += kit_lip
    o += stroke(P("M158 354 Q262 388 366 354"), CARL, 7)
    o += sh(P("M300 458 Q330 500 392 492 Q372 470 372 452 Z"), "#E06A12", CARL, 7, dx=-3, dy=-4)
    # Seen from behind the carrot points the other way.
    return group(place(mirror(o), 0.95, 262, 474), rot=rot) + fx(expr, (50, 60, 462, 440))
