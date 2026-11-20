"""Shared drawing kit for the character generator (stdlib only).

Everything is emitted as plain SVG strings on a 512x512 canvas. The look is
built from four shared ideas so the six animals read as one family:

  * thick rounded outline in the character's darkest colour
  * two-tone shading: every solid is drawn in its shade colour, then the same
    shape, nudged up-left and clipped to itself, is painted in the base
    colour - leaving a soft crescent of shadow on the lower right
  * glossy white highlights
  * one eye system (white sclera, big dark iris with a coloured glow and two
    sparkles) with joy / scared / speed / half-lidded variants
"""
import math

W = 512
_n = [0]


def reset():
    _n[0] = 0


def uid():
    _n[0] += 1
    return "c%d" % _n[0]


def f(v):
    s = ("%.1f" % v).rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def mix(a, b, t):
    a = a.lstrip("#"); b = b.lstrip("#")
    ch = [round(int(a[i:i + 2], 16) * (1 - t) + int(b[i:i + 2], 16) * t) for i in (0, 2, 4)]
    return "#%02X%02X%02X" % tuple(ch)


# ---------------------------------------------------------------- geometry
def E(cx, cy, rx, ry, rot=0):
    s = 'ellipse cx="%s" cy="%s" rx="%s" ry="%s"' % (f(cx), f(cy), f(rx), f(ry))
    if rot:
        s += ' transform="rotate(%s %s %s)"' % (f(rot), f(cx), f(cy))
    return s


def C(cx, cy, r):
    return 'circle cx="%s" cy="%s" r="%s"' % (f(cx), f(cy), f(r))


def P(d, rot=None):
    s = 'path d="%s"' % d
    if rot:
        s += ' transform="rotate(%s %s %s)"' % (f(rot[0]), f(rot[1]), f(rot[2]))
    return s


def R(x, y, w, h, r, rot=None):
    s = 'rect x="%s" y="%s" width="%s" height="%s" rx="%s"' % (f(x), f(y), f(w), f(h), f(r))
    if rot:
        s += ' transform="rotate(%s %s %s)"' % (f(rot[0]), f(rot[1]), f(rot[2]))
    return s


# ---------------------------------------------------------------- painting
def flat(geom, fill, line=None, sw=0, op=None):
    s = '<%s fill="%s"' % (geom, fill)
    if line and sw:
        s += ' stroke="%s" stroke-width="%s" stroke-linejoin="round" stroke-linecap="round"' % (line, f(sw))
    if op is not None:
        s += ' opacity="%s"' % f2(op)
    return s + "/>\n"


def f2(v):
    return ("%.2f" % v).rstrip("0").rstrip(".")


def stroke(geom, line, sw, op=None, dash=None):
    s = '<%s fill="none" stroke="%s" stroke-width="%s" stroke-linecap="round" stroke-linejoin="round"' % (geom, line, f(sw))
    if op is not None:
        s += ' opacity="%s"' % f2(op)
    return s + "/>\n"


def sh(geom, fill, line, sw=8, dx=-8, dy=-10, shade=None, t=0.2):
    """Shaded solid: shade base, base colour offset up-left, outline on top."""
    shade = shade or mix(fill, line, t)
    i = uid()
    return (
        '<clipPath id="%s"><%s/></clipPath>\n' % (i, geom)
        + '<%s fill="%s"/>\n' % (geom, shade)
        + '<g clip-path="url(#%s)"><g transform="translate(%s %s)"><%s fill="%s"/></g></g>\n' % (i, f(dx), f(dy), geom, fill)
        + (stroke(geom, line, sw) if sw else "")
    )


def clipped(geom, inner):
    """Draw `inner` clipped to `geom`."""
    i = uid()
    return '<clipPath id="%s"><%s/></clipPath>\n<g clip-path="url(#%s)">\n%s</g>\n' % (i, geom, i, inner)


def gloss(cx, cy, rx, ry, rot=-28, op=0.38):
    return flat(E(cx, cy, rx, ry, rot), "#FFFFFF", op=op)


def group(inner, tx=0, ty=0, s=1, rot=0, about=(256, 256)):
    t = []
    if tx or ty:
        t.append("translate(%s %s)" % (f(tx), f(ty)))
    if rot:
        t.append("rotate(%s %s %s)" % (f(rot), f(about[0]), f(about[1])))
    if s != 1:
        t.append("scale(%s)" % f2(s))
    if not t:
        return inner
    return '<g transform="%s">\n%s</g>\n' % (" ".join(t), inner)


def place(inner, s, cx, by, src_cx=256, src_by=462):
    """Scale a figure by `s` and put its foot point (src_cx, src_by) at (cx, by)."""
    return '<g transform="translate(%s %s) scale(%s)">\n%s</g>\n' % (
        f(cx - src_cx * s), f(by - src_by * s), f2(s), inner)


def mirror(inner):
    """Flip a drawing left-right across the canvas centre line."""
    return '<g transform="translate(512 0) scale(-1 1)">\n%s</g>\n' % inner


def limb(sx, sy, length, width, ang, side, fill, line, sw=8):
    """Stubby arm/leg: 0 = hanging down, 90 = straight out, 180 = up."""
    a = math.radians(ang)
    dx, dy = side * math.sin(a), math.cos(a)
    cx, cy = sx + dx * length / 2, sy + dy * length / 2
    return sh(E(cx, cy, width / 2, length / 2 + width * 0.15, -side * ang), fill, line, sw, dx=-5, dy=-6)


def tube(d, fill, line, w, sw=8):
    """Outlined rounded tube along a path (tails, scarf ends, ropes)."""
    return stroke(P(d), line, w + 2 * sw) + stroke(P(d), fill, w)


# ---------------------------------------------------------------- face
def eye(cx, cy, rx, ry, line, iris, mode="open", side=-1, skin="#FFFFFF", sw=6):
    """side: -1 = the viewer's left eye, +1 = right eye."""
    if mode == "joy":
        d = "M%s %s Q%s %s %s %s" % (f(cx - rx), f(cy + ry * 0.25), f(cx), f(cy - ry * 0.95), f(cx + rx), f(cy + ry * 0.25))
        return stroke(P(d), line, 10)
    o = ""
    if mode == "scared":
        g = E(cx, cy, rx * 1.14, ry * 1.1)
        o += flat(g, "#FFFFFF", line, sw)
        o += flat(C(cx, cy + ry * 0.05, rx * 0.34), line)
        o += flat(C(cx - rx * 0.12, cy - ry * 0.05, rx * 0.12), "#FFFFFF")
        return o
    g = E(cx, cy, rx, ry)
    o += flat(g, "#FFFFFF")
    inner = flat(E(cx, cy - ry * 0.02, rx * 0.78, ry * 0.82), line)
    inner += flat(E(cx, cy + ry * 0.42, rx * 0.52, ry * 0.32), iris)
    inner += flat(C(cx - rx * 0.27, cy - ry * 0.38, rx * 0.29), "#FFFFFF")
    inner += flat(C(cx + rx * 0.3, cy + ry * 0.3, rx * 0.14), "#FFFFFF", op=0.85)
    if mode in ("half", "speed"):
        ix, ox = cx - side * rx * 1.4, cx + side * rx * 1.4
        if mode == "half":
            yi = yo = cy - ry * 0.12
        else:
            yi, yo = cy + ry * 0.02, cy - ry * 0.62
        top = cy - ry * 1.5
        d = "M%s %s L%s %s L%s %s L%s %s Z" % (f(ox), f(top), f(ix), f(top), f(ix), f(yi), f(ox), f(yo))
        inner += flat(P(d), skin)
        inner += stroke(P("M%s %s L%s %s" % (f(ox), f(yo), f(ix), f(yi))), line, 7)
    o += clipped(g, inner)
    o += stroke(g, line, sw)
    return o


def brow(cx, cy, w, tilt, side, line, sw=7, op=1.0):
    """tilt > 0: inner end lower (determined); tilt < 0: inner end higher (worried)."""
    ix, ox = cx - side * w, cx + side * w
    d = "M%s %s L%s %s" % (f(ox), f(cy - tilt), f(ix), f(cy + tilt))
    return stroke(P(d), line, sw, op=op)


def blush(cx, cy, rx=22, ry=13, col="#FF9C9C", op=0.75):
    return flat(E(cx, cy, rx, ry), col, op=op)


def smile(cx, cy, w, line, depth=0.55, sw=6):
    d = "M%s %s Q%s %s %s %s" % (f(cx - w), f(cy), f(cx), f(cy + w * depth * 2), f(cx + w), f(cy))
    return stroke(P(d), line, sw)


MOUTH_IN = "#8A2F33"
TONGUE = "#F58A8E"


def open_mouth(cx, cy, w, h, line, sw=6):
    d = "M%s %s Q%s %s %s %s Q%s %s %s %s Q%s %s %s %s Z" % (
        f(cx - w), f(cy), f(cx), f(cy + h * 0.12), f(cx + w), f(cy),
        f(cx + w * 0.95), f(cy + h), f(cx), f(cy + h),
        f(cx - w * 0.95), f(cy + h), f(cx - w), f(cy))
    g = P(d)
    return flat(g, MOUTH_IN) + clipped(g, flat(E(cx, cy + h * 0.95, w * 0.62, h * 0.5), TONGUE)) + stroke(g, line, sw)


def o_mouth(cx, cy, rx, ry, line, sw=6):
    return flat(E(cx, cy, rx, ry), MOUTH_IN, line, sw)


def wobble(cx, cy, w, line, sw=6):
    d = "M%s %s q%s %s %s 0 q%s %s %s 0 q%s %s %s 0 q%s %s %s 0" % (
        f(cx - w), f(cy), f(w / 4), f(-w * 0.35), f(w / 2), f(w / 4), f(w * 0.35), f(w / 2),
        f(w / 4), f(-w * 0.35), f(w / 2), f(w / 4), f(w * 0.35), f(w / 2))
    return stroke(P(d), line, sw)


# ---------------------------------------------------------------- effects
def sparkle(cx, cy, r, col="#FFD84D", line=None):
    k = r * 0.28
    d = "M%s %s Q%s %s %s %s Q%s %s %s %s Q%s %s %s %s Q%s %s %s %s Z" % (
        f(cx), f(cy - r), f(cx + k), f(cy - k), f(cx + r), f(cy),
        f(cx + k), f(cy + k), f(cx), f(cy + r),
        f(cx - k), f(cy + k), f(cx - r), f(cy),
        f(cx - k), f(cy - k), f(cx), f(cy - r))
    return flat(P(d), col, line or "#FFFFFF", 3)


def drop(cx, cy, r, rot=0, col="#BFE3FF", line="#4D8FD1"):
    d = "M%s %s Q%s %s %s %s A%s %s 0 1 1 %s %s Q%s %s %s %s Z" % (
        f(cx), f(cy - r * 1.9), f(cx + r * 0.9), f(cy - r * 0.7), f(cx + r), f(cy),
        f(r), f(r), f(cx - r), f(cy),
        f(cx - r * 0.9), f(cy - r * 0.7), f(cx), f(cy - r * 1.9))
    return flat(P(d, (rot, cx, cy)), col, line, 4)


def flame(cx, y, w, h, op=1.0):
    """Teardrop flame pointing down from (cx, y)."""
    def tear(ww, hh, col):
        d = "M%s %s Q%s %s %s %s Q%s %s %s %s Z" % (
            f(cx - ww), f(y), f(cx - ww * 1.1), f(y + hh * 0.55), f(cx), f(y + hh),
            f(cx + ww * 1.1), f(y + hh * 0.55), f(cx + ww), f(y))
        return flat(P(d), col, op=op)
    return tear(w, h, "#F26B3A") + tear(w * 0.68, h * 0.74, "#FFA62B") + tear(w * 0.36, h * 0.46, "#FFE27A")


def fx(expr, box=(60, 60, 452, 440)):
    """Expression cue drawn around the figure so frames differ at a glance."""
    x0, y0, x1, y1 = box
    if expr == "joy":
        return (sparkle(x0 + 6, y0 + 40, 26) + sparkle(x1 - 4, y0 + 20, 20)
                + sparkle(x1 + 10, y0 + 150, 14) + sparkle(x0 - 8, y0 + 170, 12))
    if expr == "scared":
        return (drop(x1 - 6, y0 + 40, 15, 28) + drop(x1 + 22, y0 + 100, 11, 40)
                + drop(x0 + 8, y0 + 50, 13, -28)
                + stroke(P("M%s %s l-26 -14 M%s %s l-30 2 M%s %s l26 -14 M%s %s l30 2" % (
                    f(x0 - 4), f(y0 + 120), f(x0 - 8), f(y0 + 150), f(x1 + 4), f(y0 + 160), f(x1 + 8), f(y0 + 190))),
                    "#FFFFFF", 6, op=0.9))
    if expr == "speed":
        # short horizontal wind lines hugging both edges, always inside the canvas
        o = ""
        for x, y, l in ((10, 150, 64), (6, 232, 84), (18, 314, 54), (438, 118, 64), (422, 200, 84), (440, 284, 54)):
            o += stroke(P("M%s %s q%s -7 %s 0" % (f(x), f(y), f(l / 2), f(l))), "#FFFFFF", 8, op=0.88)
        return o
    return ""


def ground(cx=256, cy=462, rx=118, ry=15):
    return flat(E(cx, cy, rx, ry), "#0B2B4A", op=0.14)


def cloud(cx, cy, s=1.0, back=False):
    """Fluffy Cloud Surf cloud. `back` = the puffs behind the rider."""
    line = "#7FA6D6"
    if back:
        puffs = [(-120, -12, 56), (-40, -38, 64), (50, -40, 62), (128, -10, 54)]
    else:
        puffs = [(-168, 18, 50), (-98, 30, 62), (-18, 36, 68), (66, 32, 64), (142, 22, 54), (186, 12, 36)]
    o = ""
    for dx, dy, r in puffs:
        o += stroke(C(cx + dx * s, cy + dy * s, r * s), line, 14)
    for dx, dy, r in puffs:
        o += flat(C(cx + dx * s, cy + dy * s, r * s), "#DCEBFA")
    for dx, dy, r in puffs:
        o += flat(C(cx + dx * s - 5 * s, cy + dy * s - 9 * s, r * s * 0.9), "#FFFFFF")
    if not back:
        o += stroke(P("M%s %s q30 26 62 4 M%s %s q24 20 50 2" % (
            f(cx - 96 * s), f(cy + 52 * s), f(cx + 38 * s), f(cy + 56 * s))), "#B7D2F0", 6)
    return o


def svg(body, title):
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" fill="none">\n'
            "<!-- %s - generated by scripts/characters/generate.py; edit the generator, not this file -->\n"
            "%s</svg>\n" % (title, body))
