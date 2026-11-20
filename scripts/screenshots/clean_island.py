#!/usr/bin/env python3
"""Remove the Dynamic Island pill the Simulator paints into screenshots.

On a real iPhone the island is not part of a screenshot; the Simulator's
framebuffer capture includes it as a black capsule at the short edge
(left or right in landscape). This finds that capsule near either edge and
fills it by blending, row by row, the pixels just outside it. Nothing the
app drew is changed.

    clean_island.py <png> [<png> ...]
"""
import sys
from PIL import Image


def find_pill(img, x_from, x_to):
    w, h = img.size
    px = img.load()
    xs, ys = [], []
    for x in range(x_from, x_to):
        for y in range(h // 4, 3 * h // 4, 2):
            r, g, b = px[x, y][:3]
            if r < 6 and g < 6 and b < 6:
                xs.append(x)
                ys.append(y)
    # A pill is a solid blob: require a reasonable area.
    if len(xs) < 2000:
        return None
    return min(xs), min(ys), max(xs), max(ys)


def clean(path):
    img = Image.open(path).convert("RGB")
    w, h = img.size
    if w <= h:
        return False
    edge = int(w * 0.08)
    box = find_pill(img, 0, edge) or find_pill(img, w - edge, w)
    if not box:
        return False
    x0, y0, x1, y1 = box
    pad = 4
    x0, x1 = max(1, x0 - pad), min(w - 2, x1 + pad)
    y0, y1 = max(0, y0 - pad - 2), min(h - 1, y1 + pad + 2)
    px = img.load()
    span = x1 - x0
    for y in range(y0, y1 + 1):
        left = px[x0 - 1, y]
        right = px[x1 + 1, y]
        for x in range(x0, x1 + 1):
            t = (x - x0) / span
            px[x, y] = tuple(round(left[i] * (1 - t) + right[i] * t) for i in range(3))
    img.save(path)
    return True


if __name__ == "__main__":
    for p in sys.argv[1:]:
        print(("cleaned " if clean(p) else "no island ") + p)
