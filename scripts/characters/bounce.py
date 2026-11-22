"""Bounce the frog - eyes on top of the head, face-wide grin, webbed feet. Vehicle: lily pad glider."""
from kit import *

PAL = dict(light="#EAF3DE", main="#97C459", dark="#639922", line="#27500A", belly="#E6F4BE", iris="#86CF34")
ARMS = {"default": 8, "joy": 150, "scared": 104, "speed": 62}


def head(expr, cx=256, cy=200):
    p = PAL; L = p["line"]; G = p["main"]
    hy = cy + 28
    big = expr == "scared"
    o = ""
    for sx in (-1, 1):
        o += sh(C(cx + sx * 74, cy - 58, 60 if big else 56), G, L, dx=-6, dy=-8)
    hg = E(cx, hy, 148, 102)
    o += sh(hg, G, L, dx=-10, dy=-12)
    o += clipped(hg, flat(E(cx, hy + 84, 140, 78), p["belly"])
                 + flat(C(cx - 112, hy - 34, 11), p["dark"], op=0.75) + flat(C(cx - 128, hy - 6, 7), p["dark"], op=0.75)
                 + flat(C(cx + 116, hy - 30, 9), p["dark"], op=0.75))
    o += stroke(hg, L, 8)
    # cover the seam between eye bumps and head
    for sx in (-1, 1):
        o += flat(E(cx + sx * 74, cy - 28, 44, 26), G)
    o += gloss(cx - 104, cy - 96, 18, 9)
    m = {"default": "open"}.get(expr, expr)
    for sx in (-1, 1):
        o += eye(cx + sx * 74, cy - 56, 37, 41, L, p["iris"], m, sx, G)
    o += flat(C(cx - 10, hy + 2, 3.2), L, op=0.7) + flat(C(cx + 10, hy + 2, 3.2), L, op=0.7)
    o += blush(cx - 116, hy + 30, 22, 13, "#FFAFA6", 0.92) + blush(cx + 116, hy + 30, 22, 13, "#FFAFA6", 0.92)
    gy = hy + 24
    if expr == "default":
        o += flat(E(cx + 58, gy + 30, 15, 12, -25), TONGUE, L, 4.5)
        o += stroke(P("M%s %s Q%s %s %s %s" % (f(cx - 100), f(gy), f(cx), f(gy + 70), f(cx + 100), f(gy))), L, 7)
        o += stroke(P("M%s %s q-8 -4 -10 -12 M%s %s q8 -4 10 -12" % (f(cx - 100), f(gy), f(cx + 100), f(gy))), L, 6)
    elif expr == "joy":
        o += open_mouth(cx, gy - 4, 96, 62, L, 7)
    elif expr == "scared":
        o += o_mouth(cx, gy + 22, 22, 28, L, 6)
    else:
        o += stroke(P("M%s %s Q%s %s %s %s" % (f(cx - 96), f(gy + 6), f(cx), f(gy + 52), f(cx + 96), f(gy - 4))), L, 7)
        o += stroke(P("M%s %s q8 -4 10 -12" % (f(cx + 96), f(gy - 4))), L, 6)
    return o


def foot(side):
    p = PAL
    x = 256 + side * 108
    d = "M%s 436 Q%s 420 %s 444 Q%s 452 %s 462 Q%s 456 %s 464 Q%s 458 %s 464 Q%s 452 %s 436 Z" % (
        f(x - side * 30), f(x + side * 30), f(x + side * 52), f(x + side * 44), f(x + side * 30),
        f(x + side * 22), f(x + side * 10), f(x), f(x - side * 14), f(x - side * 34), f(x - side * 30))
    return sh(P(d), p["main"], p["line"], 7, dx=-3, dy=-4)


def fig(expr="default", arms=None):
    p = PAL; L = p["line"]; G = p["main"]
    a = ARMS[expr] if arms is None else arms
    o = ""
    for sx in (-1, 1):
        o += sh(E(256 + sx * 92, 408, 54, 42, sx * 22), G, L)
        o += foot(sx)
    bg = E(256, 380, 90, 74)
    o += sh(bg, G, L)
    o += clipped(bg, flat(E(256, 396, 62, 56), p["belly"])) + stroke(bg, L, 8)
    o += limb(180, 350, 76, 30, a, -1, G, L) + limb(332, 350, 76, 30, a, 1, G, L)
    if a < 30:
        o += sh(E(184, 440, 24, 13), G, L, 7, dx=-3, dy=-3) + sh(E(328, 440, 24, 13), G, L, 7, dx=-3, dy=-3)
    o += head(expr)
    return o


def lotus(cx, cy, s=1.0):
    o = ""
    PINK, PL = "#F9B8CC", "#A8456B"
    for rot in (-58, 58, -30, 30, 0):
        g = E(cx, cy - 22 * s, 15 * s, 30 * s)
        o += '<g transform="rotate(%s %s %s)">\n%s</g>\n' % (f(rot), f(cx), f(cy), sh(g, PINK, PL, 5, dx=-2, dy=-3))
    o += flat(E(cx, cy + 2 * s, 14 * s, 8 * s), "#F7B92E", "#7A4B12", 4)
    return o


def balloon_body(puff=1.0):
    """Balloon Body: the frog itself, puffed up round, with a knot and string."""
    p = PAL; L = p["line"]; G = p["main"]
    r = 136 * puff
    o = stroke(P("M256 474 q-22 14 -6 26 q14 8 4 12"), L, 5)
    g = C(256, 336, r)
    o += sh(g, G, L, dx=-12, dy=-14)
    o += clipped(g, flat(E(256, 366, r * 0.74, r * 0.72), p["belly"])
                 + flat(C(150, 300, 10), p["dark"], op=0.7) + flat(C(366, 316, 8), p["dark"], op=0.7))
    o += stroke(g, L, 8)
    o += flat(E(256 - r * 0.5, 336 - r * 0.42, r * 0.2, r * 0.1, -40), "#FFFFFF", op=0.6)
    o += stroke(P("M%s %s Q%s %s %s %s" % (f(256 + r * 0.5), f(336 + r * 0.6), f(256 + r * 0.72), f(336 + r * 0.42), f(256 + r * 0.78), f(336 + r * 0.14))),
                "#FFFFFF", 9, op=0.45)
    o += sh(P("M240 466 L272 466 L266 486 Q256 492 246 486 Z"), G, L, 6, dx=-2, dy=-3)
    return o


def ride(expr="default"):
    p = PAL; L = p["line"]; G = p["main"]
    rot = {"speed": -6, "scared": 5}.get(expr, 0)
    puff = {"joy": 1.04, "scared": 0.94}.get(expr, 1.0)
    a = {"default": 96, "joy": 128, "scared": 80, "speed": 62}[expr]
    o = ""
    for sx in (-1, 1):
        o += group(foot(sx), tx=sx * 6, ty=-6, rot=sx * -24, about=(256 + sx * 108, 450))
        o += limb(256 + sx * 118, 316, 78, 30, a, sx, G, L)
    o += balloon_body(puff)
    o += '<g transform="translate(%s %s) scale(0.8)">\n%s</g>\n' % (f(256 - 256 * 0.8), f(170 - 200 * 0.8), head(expr))
    return group(place(o, 0.98, 256, 462), rot=rot) + fx(expr, (40, 40, 472, 440))


def vehicle():
    """Tile icon: a frog balloon reduced to bumps, dot eyes, a smile, knot and string."""
    p = PAL; L = p["line"]; G = p["main"]
    o = stroke(P("M256 440 q-26 16 -6 30 q16 10 2 20"), L, 8)
    for sx in (-1, 1):
        o += sh(C(256 + sx * 72, 150, 50), G, L, 11, dx=-6, dy=-7)
    g = C(256, 284, 146)
    o += sh(g, G, L, 11, dx=-12, dy=-14)
    o += clipped(g, flat(E(256, 330, 108, 96), p["belly"])) + stroke(g, L, 11)
    for sx in (-1, 1):
        o += flat(E(256 + sx * 72, 176, 40, 22), G)
        o += flat(C(256 + sx * 72, 148, 26), "#FFFFFF", L, 7) + flat(C(256 + sx * 72, 150, 15), L)
        o += flat(C(256 + sx * 72 - 6, 143, 6), "#FFFFFF")
        o += blush(256 + sx * 104, 244, 20, 12, "#FFAFA6", 0.92)
    o += stroke(P("M176 236 Q256 296 336 236"), L, 10)
    o += flat(E(176, 214, 26, 12, -40), "#FFFFFF", op=0.55)
    o += sh(P("M236 426 L276 426 L268 452 Q256 460 244 452 Z"), G, L, 8, dx=-2, dy=-3)
    return o


ICON = dict(s=1.2, cx=256, cy=250)
STAND = dict(s=0.98, by=462)
CLOUD = dict(s=0.9, by=420)


# --- Back view --------------------------------------------------------------

def head_back(expr, cx=256, cy=200):
    p = PAL; L = p["line"]; G = p["main"]
    hy = cy + 28
    big = expr == "scared"
    hg = E(cx, hy, 148, 102)
    o = sh(hg, G, L, dx=-10, dy=-12)
    o += clipped(hg, flat(C(cx - 60, hy - 10, 16), p["dark"], op=0.75) + flat(C(cx + 40, hy + 30, 12), p["dark"], op=0.75)
                 + flat(C(cx + 96, hy - 26, 9), p["dark"], op=0.75) + flat(C(cx - 20, hy + 56, 8), p["dark"], op=0.75))
    o += stroke(hg, L, 8)
    # the eye bumps, seen from behind
    for sx in (-1, 1):
        o += sh(C(cx + sx * 74, cy - 58, 60 if big else 56), G, L, dx=-6, dy=-8)
        o += flat(E(cx + sx * 74, cy - 28, 44, 22), G)
    o += gloss(cx - 104, cy - 96, 18, 9)
    return o


def balloon_body_back(puff=1.0):
    p = PAL; L = p["line"]; G = p["main"]
    r = 136 * puff
    o = stroke(P("M256 474 q-22 14 -6 26 q14 8 4 12"), L, 5)
    g = C(256, 336, r)
    o += sh(g, G, L, dx=-12, dy=-14)
    spots = ""
    for x, y, s in ((180, 300, 16), (330, 280, 12), (290, 390, 14), (196, 404, 10), (366, 360, 9), (250, 250, 8)):
        spots += flat(C(x, y, s * puff), p["dark"], op=0.7)
    o += clipped(g, spots) + stroke(g, L, 8)
    o += flat(E(256 - r * 0.5, 336 - r * 0.42, r * 0.2, r * 0.1, -40), "#FFFFFF", op=0.6)
    o += sh(P("M240 466 L272 466 L266 486 Q256 492 246 486 Z"), G, L, 6, dx=-2, dy=-3)
    return o


def fig_back(expr="default", arms=None):
    p = PAL; L = p["line"]; G = p["main"]
    a = ARMS[expr] if arms is None else arms
    o = ""
    for sx in (-1, 1):
        o += sh(E(256 + sx * 92, 408, 54, 42, sx * 22), G, L)
        o += foot(sx)
    bg = E(256, 380, 90, 74)
    o += sh(bg, G, L)
    o += clipped(bg, flat(C(226, 370, 12), p["dark"], op=0.75) + flat(C(288, 400, 10), p["dark"], op=0.75)) + stroke(bg, L, 8)
    o += limb(180, 350, 76, 30, a, -1, G, L) + limb(332, 350, 76, 30, a, 1, G, L)
    o += head_back(expr)
    return o


def ride_back(expr="default"):
    p = PAL; L = p["line"]; G = p["main"]
    rot = {"speed": 6, "scared": -5}.get(expr, 0)
    puff = {"joy": 1.04, "scared": 0.94}.get(expr, 1.0)
    a = {"default": 96, "joy": 128, "scared": 80, "speed": 62}[expr]
    o = ""
    for sx in (-1, 1):
        o += group(foot(sx), tx=sx * 6, ty=-6, rot=sx * -24, about=(256 + sx * 108, 450))
        o += limb(256 + sx * 118, 316, 78, 30, a, sx, G, L)
    o += balloon_body_back(puff)
    o += '<g transform="translate(%s %s) scale(0.8)">\n%s</g>\n' % (f(256 - 256 * 0.8), f(170 - 200 * 0.8), head_back(expr))
    return group(place(o, 0.98, 256, 462), rot=rot) + fx(expr, (40, 40, 472, 440))
