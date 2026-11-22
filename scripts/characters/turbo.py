"""Turbo the turtle - big domed shell, aviator goggles, red scarf. Vehicle: Shell Jet."""
from kit import *

PAL = dict(light="#E1F5EE", main="#5DCAA5", dark="#1D9E75", line="#085041", belly="#FAEEDA", iris="#2FBF8F")
RED, REDL = "#E8504E", "#8E1F24"
BRASS, BRASSL = "#D9962B", "#6B4310"
ARMS = {"default": 28, "joy": 150, "scared": 100, "speed": 60}


def shell(cx=256, cy=350, rx=146, ry=118):
    p = PAL
    g = E(cx, cy, rx, ry)
    o = sh(g, p["dark"], p["line"], dx=-10, dy=-12)
    seam = "#8FE3C3"
    lite = mix(p["dark"], "#FFFFFF", 0.22)
    inner = ""
    # scute plates: a ring of rounded plates around the rim
    import math
    for k in range(12):
        a = math.radians(k * 30 + 15)
        x0, y0 = cx + math.cos(a) * rx * 0.70, cy + math.sin(a) * ry * 0.70
        x1, y1 = cx + math.cos(a) * rx * 1.02, cy + math.sin(a) * ry * 1.02
        inner += stroke(P("M%s %s L%s %s" % (f(x0), f(y0), f(x1), f(y1))), seam, 6)
    inner += stroke(E(cx, cy, rx * 0.70, ry * 0.70), seam, 6)
    inner += flat(E(cx - rx * 0.62, cy - ry * 0.52, 30, 14, -40), lite, op=0.8)
    o += clipped(g, inner)
    o += stroke(g, p["line"], 8)
    return o


def head(expr, cx=256, cy=200):
    p = PAL; L = p["line"]; G = p["main"]
    o = ""
    hg = E(cx, cy, 132, 112)
    o += sh(hg, G, L, dx=-10, dy=-12)
    # lighter jaw patch
    o += clipped(hg, flat(E(cx, cy + 92, 96, 56), mix(G, "#FFFFFF", 0.28)))
    o += stroke(hg, L, 8)
    o += gloss(cx - 78, cy - 62, 30, 14)
    # goggles pushed up on the forehead
    strap = "M%s %s Q%s %s %s %s" % (f(cx - 128), f(cy - 34), f(cx), f(cy - 112), f(cx + 128), f(cy - 34))
    o += clipped(hg, stroke(P(strap), BRASSL, 30) + stroke(P(strap), "#8A5A1E", 18))
    for sx in (-1, 1):
        gx, gy = cx + sx * 45, cy - 74
        o += sh(E(gx, gy, 40, 35, sx * 8), BRASS, BRASSL, 7, dx=-4, dy=-5)
        o += flat(E(gx, gy, 27, 23, sx * 8), "#CFE9FB", BRASSL, 5)
        o += flat(E(gx - 9, gy - 8, 9, 5, -30), "#FFFFFF", op=0.9)
    o += flat(R(cx - 10, cy - 84, 20, 16, 6), BRASS, BRASSL, 6)
    # face
    ey = cy + 22
    if expr == "scared":
        o += brow(cx - 54, ey - 60, 18, -6, -1, L) + brow(cx + 54, ey - 60, 18, -6, 1, L)
    for sx in (-1, 1):
        o += eye(cx + sx * 54, ey, 29, 36, L, p["iris"], {"default": "open"}.get(expr, expr), sx, G)
    o += blush(cx - 96, cy + 62, col="#FFAFA6", op=0.92) + blush(cx + 96, cy + 62, col="#FFAFA6", op=0.92)
    my = cy + 62
    if expr == "default":
        o += smile(cx, my, 20, L)
    elif expr == "joy":
        o += open_mouth(cx, my - 6, 26, 30, L)
    elif expr == "scared":
        o += wobble(cx, my + 6, 24, L)
    else:
        o += smile(cx + 4, my, 18, L, depth=0.3)
        o += stroke(P("M%s %s q8 -4 10 -12" % (f(cx + 22), f(my))), L, 6)
    # nostrils
    o += flat(C(cx - 7, cy + 46, 2.6), L, op=0.6) + flat(C(cx + 7, cy + 46, 2.6), L, op=0.6)
    return o


def scarf(expr):
    wind = expr in ("speed", "joy")
    if wind:
        tail = "M322 316 Q392 286 452 300 Q430 318 444 340 Q386 328 326 344 Z"
    else:
        tail = "M316 322 Q360 340 372 392 Q348 386 332 404 Q326 356 300 340 Z"
    o = sh(P(tail), RED, REDL, 7, dx=-4, dy=-5)
    band = "M170 292 Q256 336 342 292 Q352 310 338 326 Q256 362 174 326 Q160 310 170 292 Z"
    o += sh(P(band), RED, REDL, 7, dx=-5, dy=-6)
    o += sh(E(322, 326, 17, 15), RED, REDL, 7, dx=-3, dy=-4)
    return o


def fig(expr="default", arms=None):
    p = PAL; L = p["line"]; G = p["main"]
    a = ARMS[expr] if arms is None else arms
    o = ""
    o += sh(P("M352 418 Q398 410 410 436 Q380 450 348 440 Z"), G, L)          # tail
    o += shell()
    o += sh(E(204, 442, 36, 22), G, L, dx=-5, dy=-6) + sh(E(308, 442, 36, 22), G, L, dx=-5, dy=-6)
    o += limb(196, 338, 62, 40, a, -1, G, L) + limb(316, 338, 62, 40, a, 1, G, L)
    o += sh(E(256, 368, 76, 80), G, L)
    bg = E(256, 382, 54, 58)
    seam = mix(p["belly"], L, 0.3)
    o += flat(bg, p["belly"])
    o += clipped(bg, flat(E(274, 404, 54, 58), mix(p["belly"], "#D9A766", 0.0)) +
                 stroke(P("M256 320 V446 M200 366 Q256 378 312 366 M204 408 Q256 420 308 408"), seam, 4))
    o += stroke(bg, seam, 5)
    o += scarf(expr)
    o += head(expr)
    return o


def boosters(power=1.0):
    o = ""
    for sx in (-1, 1):
        x = 256 + sx * 150
        o += flame(x, 396, 22, 70 * power)
        o += sh(R(x - 27, 286, 54, 112, 24), "#B9BEC6", "#3D4652", 7, dx=-6, dy=-4)
        o += sh(P("M%s 300 Q%s 250 %s 300 Z" % (f(x - 27), f(x), f(x + 27))), RED, REDL, 7, dx=-4, dy=-4)
        o += flat(R(x - 27, 352, 54, 14, 4), BRASS, BRASSL, 5)
        o += flat(R(x - 22, 392, 44, 14, 6), "#4A525E", "#22272E", 5)
    o += flame(256, 430, 34, 78 * power)
    return o


def ride(expr="default"):
    power = {"speed": 1.25, "scared": 0.7}.get(expr, 1.0)
    rot = {"speed": -6, "scared": 5}.get(expr, 0)
    inner = boosters(power) + sh(P("M224 430 L214 462 H298 L288 430 Z"), "#B9BEC6", "#3D4652", 7) + fig(expr)
    return group(place(inner, 1.0, 256, 416), rot=rot) + fx(expr, (40, 40, 472, 440))


def vehicle():
    o = boosters() + sh(P("M224 430 L214 462 H298 L288 430 Z"), "#B9BEC6", "#3D4652", 7) + shell()
    return place(o, 1.0, 256, 440)


ICON = dict(s=1.36, cx=256, cy=262)   # head centre (256,200) lands on (cx, cy)
STAND = dict(s=0.98, by=462)
CLOUD = dict(s=0.92, by=420)


# --- Back view (flying away from the camera) -------------------------------
# The chase camera sits behind the character, so in flight we mostly see
# its back: the domed shell, the goggle strap round the back of the head,
# the scarf knot. Expressions read through the arms, tilt and fx cues.

def head_back(expr, cx=256, cy=200):
    p = PAL; L = p["line"]; G = p["main"]
    hg = E(cx, cy, 132, 112)
    o = sh(hg, G, L, dx=-10, dy=-12)
    o += clipped(hg, flat(E(cx, cy + 90, 110, 50), p["dark"], op=0.35))
    o += stroke(hg, L, 8)
    o += gloss(cx - 70, cy - 66, 30, 14)
    # goggle strap round the back, with its buckle
    strap = "M%s %s Q%s %s %s %s" % (f(cx - 130), f(cy - 30), f(cx), f(cy - 4), f(cx + 130), f(cy - 30))
    o += clipped(hg, stroke(P(strap), BRASSL, 30) + stroke(P(strap), "#8A5A1E", 18))
    o += flat(R(cx - 18, cy - 26, 36, 22, 5), BRASS, BRASSL, 6) + flat(R(cx - 8, cy - 20, 16, 10, 3), "#8A5A1E")
    # goggle rims peeking out at the sides
    for sx in (-1, 1):
        o += sh(E(cx + sx * 118, cy - 62, 16, 24, sx * 20), BRASS, BRASSL, 6, dx=-2, dy=-3)
    return o


def fig_back(expr="default", arms=None):
    p = PAL; L = p["line"]; G = p["main"]
    a = ARMS[expr] if arms is None else arms
    o = sh(E(204, 446, 36, 22), G, L, dx=-5, dy=-6) + sh(E(308, 446, 36, 22), G, L, dx=-5, dy=-6)
    o += limb(196, 338, 62, 40, a, -1, G, L) + limb(316, 338, 62, 40, a, 1, G, L)
    o += head_back(expr)
    o += shell(256, 360, 150, 124)
    # scarf knot at the nape, tails streaming in the wind
    wind = expr in ("speed", "joy")
    for sx in (-1, 1):
        tail = ("M256 282 Q%s 250 %s 236 Q%s 262 %s 290 Z" if wind else "M256 284 Q%s 320 %s 344 Q%s 340 %s 300 Z") % (
            f(256 + sx * 70), f(256 + sx * 120), f(256 + sx * 100), f(256 + sx * 20))
        o += sh(P(tail), RED, REDL, 7, dx=-3, dy=-4)
    o += sh(E(256, 284, 22, 18), RED, REDL, 7, dx=-3, dy=-4)
    o += sh(P("M236 470 Q256 500 276 470 Z"), G, L, 7, dx=-3, dy=-3)   # tail
    return o


def ride_back(expr="default"):
    power = {"speed": 1.25, "scared": 0.7}.get(expr, 1.0)
    rot = {"speed": 6, "scared": -5}.get(expr, 0)
    inner = boosters(power) + sh(P("M224 430 L214 462 H298 L288 430 Z"), "#B9BEC6", "#3D4652", 7) + fig_back(expr)
    return group(place(inner, 1.0, 256, 416), rot=rot) + fx(expr, (40, 40, 472, 440))
