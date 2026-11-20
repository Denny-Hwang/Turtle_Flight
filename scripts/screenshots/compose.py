#!/usr/bin/env python3
"""Store screenshots with captions + promo images, from the raw captures.

    python3 scripts/screenshots/compose.py

Reads   marketing/screenshots/<device>/NN_<scene>.png  (scripts/screenshots/capture.sh)
Writes  marketing/store/<device>/NN_<scene>.png         same pixel size as the raw
                                                         capture, upload-ready
        marketing/promo/*.png                            social / square / story

Only the app's own screenshots, character art and icon are used; every
caption is a plain statement of a feature that is in the build.
"""
import os
import random
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
RAW = os.path.join(ROOT, "marketing", "screenshots")
STORE = os.path.join(ROOT, "marketing", "store")
PROMO = os.path.join(ROOT, "marketing", "promo")
ASSETS = os.path.join(ROOT, "TurtleFlight", "Assets.xcassets")
FONT = "/System/Library/Fonts/SFNSRounded.ttf"

NAVY = (18, 38, 58)
NAVY_SOFT = (52, 78, 104)
ORANGE = (255, 107, 53)
CHARACTERS = ["turbo", "pip", "nutty", "mochi", "bounce", "hoppy"]

# Store order, caption (headline, sub), stickers (left, right).
SHOTS = [
    ("daily", "Tilt to fly", "Hit the center of every ring for a BULLSEYE", ("turbo", "pip")),
    ("characters", "Six flightless friends", "Pick a hero, a ride and a world to fly in", ("mochi", "bounce")),
    ("skyrun", "Sky Run", "An endless course that keeps getting tighter", ("pip", "nutty")),
    ("daily-result", "Beat your best", "Scores, combos and three stars on every course", ("hoppy", "turbo")),
    ("home", "A new course every day", "Daily quests, streaks and Today's Course", ("nutty", "hoppy")),
    ("stages", "Five hand-built missions", "From a gentle Sky Walk to the Sky Race", ("bounce", "mochi")),
]


def font(size, weight="Bold"):
    f = ImageFont.truetype(FONT, size)
    f.set_variation_by_name(weight)
    return f


def character(name, size):
    path = os.path.join(ASSETS, "Characters", f"{name}_flying.imageset", f"{name}_flying@2x.png")
    return Image.open(path).convert("RGBA").resize((size, size), Image.LANCZOS)


def app_icon(size):
    path = os.path.join(ASSETS, "AppIcon.appiconset", "AppIcon-1024.png")
    icon = Image.open(path).convert("RGBA").resize((size, size), Image.LANCZOS)
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size, size), radius=int(size * 0.225), fill=255)
    icon.putalpha(mask)
    return icon


def sky(w, h, top=(110, 196, 240), bottom=(214, 240, 252), seed=7):
    """Vertical gradient with soft clouds."""
    img = Image.new("RGBA", (w, h))
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / max(1, h - 1)
        d.line([(0, y), (w, y)], fill=tuple(round(top[i] * (1 - t) + bottom[i] * t) for i in range(3)) + (255,))
    clouds = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    cd = ImageDraw.Draw(clouds)
    rng = random.Random(seed)
    unit = min(w, h)
    for _ in range(9):
        cx, cy = rng.uniform(0, w), rng.uniform(0, h)
        cw, ch = rng.uniform(0.25, 0.5) * unit, rng.uniform(0.08, 0.14) * unit
        for k in range(4):
            ox = rng.uniform(-cw * 0.35, cw * 0.35)
            oy = rng.uniform(-ch * 0.3, ch * 0.1)
            cd.ellipse((cx + ox - cw / 2, cy + oy - ch / 2, cx + ox + cw / 2, cy + oy + ch / 2),
                       fill=(255, 255, 255, 70))
    clouds = clouds.filter(ImageFilter.GaussianBlur(unit * 0.02))
    img.alpha_composite(clouds)
    return img


def rounded(img, radius):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, img.size[0] - 1, img.size[1] - 1), radius=radius, fill=255)
    out = img.convert("RGBA")
    out.putalpha(mask)
    return out


def shadow_paste(canvas, img, xy, radius, blur, offset=(0, 0), alpha=90):
    sh = Image.new("RGBA", (img.size[0] + blur * 4, img.size[1] + blur * 4), (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle(
        (blur * 2, blur * 2, blur * 2 + img.size[0], blur * 2 + img.size[1]),
        radius=radius, fill=(10, 30, 60, alpha))
    sh = sh.filter(ImageFilter.GaussianBlur(blur))
    canvas.alpha_composite(sh, (xy[0] - blur * 2 + offset[0], xy[1] - blur * 2 + offset[1]))
    canvas.alpha_composite(img, xy)


def screen_card(path, height):
    """Screenshot scaled to `height`, rounded, with a thin white bezel."""
    shot = Image.open(path).convert("RGBA")
    w = round(shot.size[0] * height / shot.size[1])
    shot = shot.resize((w, height), Image.LANCZOS)
    bezel = max(6, height // 70)
    r = height // 18
    frame = Image.new("RGBA", (w + 2 * bezel, height + 2 * bezel), (0, 0, 0, 0))
    ImageDraw.Draw(frame).rounded_rectangle((0, 0, frame.size[0] - 1, frame.size[1] - 1),
                                            radius=r + bezel, fill=(255, 255, 255, 255))
    frame.alpha_composite(rounded(shot, r), (bezel, bezel))
    return frame, r + bezel


def centered_text(d, text, y, fnt, fill, w):
    tw = d.textlength(text, font=fnt)
    d.text(((w - tw) / 2, y), text, font=fnt, fill=fill)


def store_shot(raw_path, out_path, headline, sub, stickers):
    base = Image.open(raw_path)
    W, H = base.size
    ipad = W / H < 1.6
    canvas = sky(W, H, seed=hash(headline) & 0xFFFF)
    d = ImageDraw.Draw(canvas)
    head_px = round(H * (0.072 if ipad else 0.085))
    sub_px = round(H * (0.034 if ipad else 0.040))
    top = round(H * (0.045 if ipad else 0.04))
    centered_text(d, headline, top, font(head_px, "Heavy"), NAVY, W)
    centered_text(d, sub, top + head_px * 1.22, font(sub_px, "Semibold"), NAVY_SOFT, W)
    caption_h = top + head_px * 1.22 + sub_px * 1.6
    card_h = round(H - caption_h - H * 0.05)
    card, r = screen_card(raw_path, card_h)
    x = (W - card.size[0]) // 2
    y = round(caption_h)
    shadow_paste(canvas, card, (x, y), r, blur=max(12, H // 60), offset=(0, H // 90))
    # Stickers in the side margins, overlapping the card edge a little.
    margin = x
    size = round(min(margin * 1.25, H * 0.3))
    left, right = character(stickers[0], size), character(stickers[1], size)
    canvas.alpha_composite(left, (max(0, x - round(size * 0.78)), y + round(card.size[1] * 0.52)))
    canvas.alpha_composite(right.transpose(Image.FLIP_LEFT_RIGHT),
                           (min(W - size, x + card.size[0] - round(size * 0.22)), y + round(card.size[1] * 0.08)))
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    canvas.convert("RGB").save(out_path, optimize=True)


def find_raw(device, scene):
    folder = os.path.join(RAW, device)
    for f in sorted(os.listdir(folder)):
        if f.endswith(f"_{scene}.png"):
            return os.path.join(folder, f)
    return None


def promo_social(shots, out):
    W, H = 1200, 630
    c = sky(W, H, seed=3)
    d = ImageDraw.Draw(c)
    icon = app_icon(132)
    shadow_paste(c, icon, (64, 70), 30, blur=10, offset=(0, 6))
    d.text((64, 228), "Turtle Flight", font=font(76, "Heavy"), fill=NAVY)
    d.text((66, 320), "Tilt to fly. Hit the bullseye.", font=font(34, "Semibold"), fill=NAVY_SOFT)
    d.text((66, 372), "Six flightless friends", font=font(24, "Medium"), fill=NAVY_SOFT)
    d.text((66, 404), "A new course every day", font=font(24, "Medium"), fill=NAVY_SOFT)
    pill_f = font(26, "Bold")
    label = "Free on iPhone & iPad"
    tw = d.textlength(label, font=pill_f)
    d.rounded_rectangle((64, 450, 64 + tw + 56, 510), radius=30, fill=ORANGE)
    d.text((92, 462), label, font=pill_f, fill=(255, 255, 255))
    card, r = screen_card(shots[0], 240)
    tilted = card.rotate(-4, expand=True, resample=Image.BICUBIC)
    shadow_paste(c, tilted, (W - tilted.size[0] - 16, 170), r, blur=14, offset=(0, 8), alpha=70)
    c.alpha_composite(character("turbo", 190), (W - 250, 380))
    c.alpha_composite(character("pip", 140), (W - 470, 30))
    c.convert("RGB").save(out, optimize=True)


def promo_square(shots, out):
    W = H = 1080
    c = sky(W, H, seed=11)
    d = ImageDraw.Draw(c)
    centered_text(d, "Turtle Flight", 70, font(104, "Heavy"), NAVY, W)
    centered_text(d, "Tilt to fly. Hit the bullseye.", 196, font(42, "Semibold"), NAVY_SOFT, W)
    card, r = screen_card(shots[0], 420)
    shadow_paste(c, card, ((W - card.size[0]) // 2, 300), r, blur=16, offset=(0, 10))
    row_y, size = 770, 190
    gap = (W - size * 5) // 6
    for i, name in enumerate(["turbo", "pip", "nutty", "mochi", "bounce"]):
        bob = -22 if i % 2 else 0
        c.alpha_composite(character(name, size), (gap + i * (size + gap), row_y + bob))
    c.alpha_composite(character("hoppy", 150), (W - 190, 230))
    c.convert("RGB").save(out, optimize=True)


def promo_story(shots, out):
    W, H = 1080, 1920
    c = sky(W, H, seed=21)
    d = ImageDraw.Draw(c)
    icon = app_icon(200)
    shadow_paste(c, icon, ((W - 200) // 2, 150), 45, blur=12, offset=(0, 8))
    centered_text(d, "Turtle Flight", 390, font(112, "Heavy"), NAVY, W)
    centered_text(d, "Tilt to fly. Hit the bullseye.", 530, font(48, "Semibold"), NAVY_SOFT, W)
    y = 640
    for i, p in enumerate(shots[:2]):
        card, r = screen_card(p, 400)
        if card.size[0] > W - 200:
            scale = (W - 200) / card.size[0]
            card, r = screen_card(p, round(400 * scale))
        card = card.rotate((-3, 3)[i], expand=True, resample=Image.BICUBIC)
        shadow_paste(c, card, ((W - card.size[0]) // 2, y), r, blur=14, offset=(0, 8), alpha=70)
        y += card.size[1] + 20
    c.alpha_composite(character("turbo", 220), (10, 540))
    size = 180
    gap = (W - size * 5) // 6
    for i, name in enumerate(["pip", "nutty", "mochi", "bounce", "hoppy"]):
        c.alpha_composite(character(name, size), (gap + i * (size + gap), y - 10 - (24 if i % 2 else 0)))
    pill_f = font(40, "Bold")
    label = "Free on the App Store"
    tw = d.textlength(label, font=pill_f)
    d.rounded_rectangle(((W - tw) / 2 - 44, H - 150, (W + tw) / 2 + 44, H - 62), radius=44, fill=ORANGE)
    d.text(((W - tw) / 2, H - 134), label, font=pill_f, fill=(255, 255, 255))
    c.convert("RGB").save(out, optimize=True)


def main():
    made = []
    for device in sorted(os.listdir(RAW)) if os.path.isdir(RAW) else []:
        for i, (scene, head, sub, stickers) in enumerate(SHOTS, 1):
            raw = find_raw(device, scene)
            if not raw:
                continue
            out = os.path.join(STORE, device, f"{i:02d}_{scene}.png")
            store_shot(raw, out, head, sub, stickers)
            made.append(out)
    iphone = os.path.join(RAW, "iphone-6.9")
    if os.path.isdir(iphone):
        shots = [find_raw("iphone-6.9", s) for s in ("daily", "skyrun", "characters")]
        shots = [s for s in shots if s]
        os.makedirs(PROMO, exist_ok=True)
        for fn, name in ((promo_social, "social_1200x630.png"),
                         (promo_square, "square_1080x1080.png"),
                         (promo_story, "story_1080x1920.png")):
            out = os.path.join(PROMO, name)
            fn(shots, out)
            made.append(out)
    for m in made:
        print(os.path.relpath(m, ROOT))


if __name__ == "__main__":
    main()
