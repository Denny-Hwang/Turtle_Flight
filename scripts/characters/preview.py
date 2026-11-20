#!/usr/bin/env python3
"""Contact sheets for the character art -> build/character-preview/.

    python3 scripts/characters/preview.py            # all characters
    python3 scripts/characters/preview.py turbo      # one

Needs rsvg-convert (brew install librsvg) and Pillow.
  sheet_<name>.png   all 16 variants of one character at 256px
  overview.png       every character: default / flying / cloud / icon
  small.png          the in-flight frames at 96px and 160px (legibility check)
"""
import os
import subprocess
import sys
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "assets", "characters")
OUT = os.path.join(ROOT, "build", "character-preview")
SKY = (133, 183, 235)
NAMES = ["turbo", "pip", "nutty", "mochi", "bounce", "hoppy"]
EXPRS = ["default", "joy", "scared", "speed"]


def render(name, variant, px):
    src = os.path.join(SRC, name, "%s_%s.svg" % (name, variant))
    dst = os.path.join(OUT, "png", "%s_%s_%d.png" % (name, variant, px))
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    subprocess.run(["rsvg-convert", "-w", str(px), "-h", str(px), "-o", dst, src], check=True)
    return Image.open(dst).convert("RGBA")


def sheet(cells, px, cols, path, bg=SKY):
    rows = (len(cells) + cols - 1) // cols
    im = Image.new("RGB", (cols * px, rows * px), bg)
    for i, c in enumerate(cells):
        im.paste(c, ((i % cols) * px, (i // cols) * px), c)
    im.save(path)
    print(path)


def main(argv):
    names = argv or NAMES
    os.makedirs(OUT, exist_ok=True)
    for n in names:
        variants = (EXPRS + ["fly_" + e for e in EXPRS] + ["cloud_" + e for e in EXPRS]
                    + ["flying", "icon", "silhouette", "vehicle_only"])
        sheet([render(n, v, 320) for v in variants], 320, 4, os.path.join(OUT, "sheet_%s.png" % n))
    if not argv:
        cells = []
        for v in ["default", "flying", "cloud_default", "icon"]:
            cells += [render(n, v, 300) for n in NAMES]
        sheet(cells, 300, 6, os.path.join(OUT, "overview.png"))
    small = []
    for n in names:
        small += [render(n, "fly_" + e, 96) for e in EXPRS] + [render(n, "cloud_" + e, 96) for e in EXPRS]
    sheet(small, 96, 8, os.path.join(OUT, "small_96.png"))
    small = []
    for n in names:
        small += [render(n, "fly_" + e, 160) for e in EXPRS] + [render(n, "cloud_" + e, 160) for e in EXPRS]
    sheet(small, 160, 8, os.path.join(OUT, "small_160.png"))


if __name__ == "__main__":
    main(sys.argv[1:])
