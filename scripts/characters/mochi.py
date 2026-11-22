"""Mochi the cat - half-lidded cool eyes, pointed ears, S-curve tail, bell collar. Vehicle: cushion balloon."""
from kit import *

PAL = dict(light="#EEEDFE", main="#CECBF6", dark="#534AB7", line="#3C3489", belly="#ED93B1", iris="#9B92F5")
FUR = "#F5F3FF"
RED, REDL = "#E8504E", "#8E1F24"
GOLD, GOLDL = "#F7B92E", "#7A4B12"
ARMS = {"default": 14, "joy": 44, "scared": 112, "speed": 58}


def ear(rot=0):
    p = PAL
    g = P("M142 152 Q134 80 158 38 Q208 60 238 106 Z")
    o = sh(g, p["main"], p["line"], dx=-5, dy=-6)
    o += clipped(g, flat(C(156, 36, 38), p["dark"]) + flat(P("M166 136 Q160 96 170 70 Q198 88 214 114 Z"), p["belly"])) + stroke(g, p["line"], 8)
    return group(o, rot=rot, about=(190, 130))


def head(expr, cx=256, cy=200):
    p = PAL; L = p["line"]; G = p["main"]
    er = -34 if expr == "scared" else (-6 if expr == "joy" else 0)
    o = ear(er) + mirror(ear(er))
    hg = E(cx, cy, 126, 108)
    o += sh(hg, G, L, dx=-10, dy=-12)
    o += clipped(hg, flat(E(cx, cy + 84, 78, 52), FUR)) + stroke(hg, L, 8)
    o += gloss(cx - 80, cy - 58, 28, 13)
    o += sparkle(cx, cy - 64, 15, "#8F86F0", "#8F86F0")
    ey = cy + 18
    m = {"default": "half"}.get(expr, expr)
    if expr == "scared":
        o += brow(cx - 52, ey - 54, 18, -6, -1, L) + brow(cx + 52, ey - 54, 18, -6, 1, L)
    for sx in (-1, 1):
        o += eye(cx + sx * 52, ey, 30, 34, L, p["iris"], m, sx, G)
        if expr != "scared":
            ox = cx + sx * 82
            yy = ey - (4 if m == "half" else 10)
            o += stroke(P("M%s %s l%s -12" % (f(ox), f(yy), f(sx * 15))), L, 6)
    o += blush(cx - 94, cy + 58, 20, 12, "#FF9CC0", 0.7) + blush(cx + 94, cy + 58, 20, 12, "#FF9CC0", 0.7)
    o += flat(P("M%s %s h18 l-9 10 Z" % (f(cx - 9), f(cy + 46))), "#F27FA6", L, 4)
    my = cy + 60
    if expr == "scared":
        o += o_mouth(cx, my + 10, 9, 12, L, 5)
    elif expr == "joy":
        o += stroke(P("M%s %s q11 14 22 0 q11 14 22 0" % (f(cx - 22), f(my))), L, 5.5)
        o += flat(E(cx, my + 12, 7, 6), TONGUE, L, 3.5)
    else:
        o += stroke(P("M%s %s q10 11 20 0 q10 11 20 0" % (f(cx - 20), f(my))), L, 5.5)
    for sx in (-1, 1):
        x = cx + sx * 104
        o += stroke(P("M%s %s l%s -8 M%s %s l%s 6" % (f(x), f(cy + 40), f(sx * 46), f(x), f(cy + 54), f(sx * 44))), L, 3, op=0.55)
    return o


def tail(expr):
    p = PAL
    if expr == "scared":
        d = "M306 426 Q420 440 412 350 Q408 300 430 270"
        return tube(d, p["main"], p["line"], 44) + stroke(P("M416 318 Q416 290 430 270"), p["dark"], 44)
    if expr == "speed":
        d = "M306 426 Q380 440 420 410 Q456 384 486 392"
    else:
        d = "M306 426 Q408 440 400 366 Q394 320 428 304"
    tip = {"speed": "M452 394 Q470 388 486 392"}.get(expr, "M404 334 Q410 312 428 304")
    return tube(d, p["main"], p["line"], 26) + stroke(P(tip), p["dark"], 26)


def collar():
    band = "M186 292 Q256 328 326 292 Q332 304 324 314 Q256 346 188 314 Q180 304 186 292 Z"
    o = sh(P(band), RED, REDL, 7, dx=-4, dy=-5)
    o += sh(C(256, 334, 17), GOLD, GOLDL, 6, dx=-3, dy=-4)
    o += stroke(P("M246 336 h20 M256 338 v8"), GOLDL, 3.5)
    return o


def fig(expr="default", arms=None, with_tail=True):
    p = PAL; L = p["line"]; G = p["main"]
    a = ARMS[expr] if arms is None else arms
    o = tail(expr) if with_tail else ""
    o += sh(E(224, 448, 29, 17), G, L, 7, dx=-4, dy=-5) + sh(E(288, 448, 29, 17), G, L, 7, dx=-4, dy=-5)
    o += limb(202, 340, 62, 32, a, -1, G, L) + limb(310, 340, 62, 32, a, 1, G, L)
    bg = E(256, 376, 72, 80)
    o += sh(bg, G, L)
    o += clipped(bg, flat(E(256, 386, 42, 56), FUR)) + stroke(bg, L, 8)
    o += collar()
    o += head(expr)
    return o


def balloon():
    p = PAL
    BAL, BALL = "#A9A2F0", "#3C3489"
    g = E(256, 112, 156, 128)
    o = stroke(P("M128 180 L168 404 M384 180 L344 404"), BALL, 6)
    o += sh(g, BAL, BALL, dx=-12, dy=-14)
    inner = flat(E(256, 112, 100, 128), "#DCD8FB") + flat(E(256, 112, 40, 128), BAL)
    inner += flat(E(256, 216, 170, 34), "#F3A6C4")
    for x, y in ((176, 84), (336, 104)):
        inner += flat(C(x, y + 10, 13), "#8F86F0", op=0.45)
        for dx, dy in ((-14, -8), (0, -16), (14, -8)):
            inner += flat(C(x + dx, y + dy, 6), "#8F86F0", op=0.45)
    o += clipped(g, inner) + stroke(g, BALL, 8)
    o += gloss(166, 40, 36, 16, -35, 0.45)
    return o


def basket():
    p = PAL
    o = sh(P("M150 402 Q146 496 256 496 Q366 496 362 402 Z"), "#8F86F0", p["line"], 8, dx=-10, dy=-6)
    o += stroke(P("M190 440 q10 26 30 34 M322 440 q-10 26 -30 34 M256 444 v40"), "#6F66D6", 5)
    rim = R(130, 380, 252, 46, 23)
    o += sh(rim, "#F7B3CF", "#8E3A5E", 8, dx=-5, dy=-6)
    o += stroke(P("M158 403 h196"), "#FFFFFF", 4, op=0.6)
    return o


def ride(expr="default"):
    p = PAL; L = p["line"]; G = p["main"]
    rot = {"speed": -5, "scared": 5}.get(expr, 0)
    o = balloon()
    o += place(fig(expr, with_tail=False), 0.82, 256, 474)
    o += basket()
    if expr in ("default", "speed"):
        o += sh(E(214, 382, 22, 16), G, L, 7, dx=-3, dy=-4) + sh(E(298, 382, 22, 16), G, L, 7, dx=-3, dy=-4)
    return group(place(o, 0.98, 256, 462), rot=rot) + fx(expr, (50, 150, 462, 440))


def vehicle():
    return place(balloon() + basket(), 0.98, 256, 462)


ICON = dict(s=1.2, cx=256, cy=282)
STAND = dict(s=0.9, by=462)
CLOUD = dict(s=0.86, by=420)


# --- Back view --------------------------------------------------------------

def ear_back(rot=0):
    p = PAL
    g = P("M142 152 Q134 80 158 38 Q208 60 238 106 Z")
    o = sh(g, p["main"], p["line"], dx=-5, dy=-6)
    o += clipped(g, flat(C(156, 36, 38), p["dark"])) + stroke(g, p["line"], 8)
    return group(o, rot=rot, about=(190, 130))


def head_back(expr, cx=256, cy=200):
    p = PAL; L = p["line"]; G = p["main"]
    er = -34 if expr == "scared" else (-6 if expr == "joy" else 0)
    hg = E(cx, cy, 126, 108)
    o = sh(hg, G, L, dx=-10, dy=-12)
    # tabby stripes on the back of the head
    stripes = ""
    for dx in (-36, 0, 36):
        stripes += stroke(P("M%s %s q%s 30 0 60" % (f(cx + dx), f(cy - 100), f(dx * 0.2 - 6))), p["iris"], 12, op=0.7)
    o += clipped(hg, stripes) + stroke(hg, L, 8)
    o += gloss(cx - 70, cy - 58, 28, 13)
    o += ear_back(er) + mirror(ear_back(er))
    return o


def fig_back(expr="default", arms=None, with_tail=True):
    p = PAL; L = p["line"]; G = p["main"]
    a = ARMS[expr] if arms is None else arms
    o = sh(E(224, 452, 29, 17), G, L, 7, dx=-4, dy=-5) + sh(E(288, 452, 29, 17), G, L, 7, dx=-4, dy=-5)
    o += limb(202, 340, 62, 32, a, -1, G, L) + limb(310, 340, 62, 32, a, 1, G, L)
    bg = E(256, 376, 72, 80)
    o += sh(bg, G, L)
    o += clipped(bg, stroke(P("M226 330 q-8 30 0 60 M286 330 q8 30 0 60"), p["iris"], 10, op=0.6)) + stroke(bg, L, 8)
    o += head_back(expr)
    band = "M190 300 Q256 270 322 300 Q330 312 322 322 Q256 296 190 322 Q182 312 190 300 Z"
    o += sh(P(band), RED, REDL, 7, dx=-4, dy=-5)
    if with_tail:
        o += mirror(tail(expr))
    return o


def ride_back(expr="default"):
    p = PAL; L = p["line"]; G = p["main"]
    rot = {"speed": 5, "scared": -5}.get(expr, 0)
    o = balloon()
    o += place(fig_back(expr, with_tail=False), 0.82, 256, 474)
    o += basket()
    if expr in ("default", "speed"):
        o += sh(E(214, 382, 22, 16), G, L, 7, dx=-3, dy=-4) + sh(E(298, 382, 22, 16), G, L, 7, dx=-3, dy=-4)
    # tail curls over the basket rim
    o += tube("M330 400 Q392 392 396 340 Q398 312 420 300", G, L, 22)
    return group(place(o, 0.98, 256, 462), rot=rot) + fx(expr, (50, 150, 462, 440))
