"""Draws the Pawly app icon, notification icon and Play Store graphics."""
import os
import sys
from PIL import Image, ImageDraw, ImageFont

ROOT = sys.argv[1]
GREEN = (31, 122, 107)
GREEN_DARK = (22, 92, 80)
ORANGE = (242, 153, 74)
WHITE = (255, 255, 255)


def paw(draw, cx, cy, s, color):
    """Paw print centred at (cx, cy); s = overall size."""
    # main pad
    pw, ph = s * 0.46, s * 0.38
    py = cy + s * 0.14
    draw.ellipse([cx - pw / 2, py - ph / 2, cx + pw / 2, py + ph / 2], fill=color)
    # toes
    toes = [(-0.30, -0.10, 0.17), (-0.11, -0.28, 0.18), (0.11, -0.28, 0.18), (0.30, -0.10, 0.17)]
    for dx, dy, r in toes:
        x, y, rr = cx + dx * s, cy + dy * s, r * s / 2 * 1.05
        draw.ellipse([x - rr, y - rr * 1.2, x + rr, y + rr * 1.2], fill=color)


def app_icon(size, square=False):
    scale = 4
    S = size * scale
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, S - 1, S - 1], radius=0 if square else S * 0.22, fill=GREEN)
    d.ellipse([S * 0.62, S * 0.08, S * 0.86, S * 0.32], fill=ORANGE)  # small accent
    paw(d, S / 2, S / 2 + S * 0.02, S * 0.62, WHITE)
    return img.resize((size, size), Image.LANCZOS)


def notif_icon(size):
    scale = 4
    S = size * scale
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    paw(d, S / 2, S / 2, S * 0.92, WHITE)
    return img.resize((size, size), Image.LANCZOS)


def save(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)


res = os.path.join(ROOT, "android/app/src/main/res")
for name, px in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
    save(app_icon(px), f"{res}/mipmap-{name}/ic_launcher.png")
for name, px in {"mdpi": 24, "hdpi": 36, "xhdpi": 48, "xxhdpi": 72, "xxxhdpi": 96}.items():
    save(notif_icon(px), f"{res}/drawable-{name}/ic_stat_paw.png")

store = os.path.join(ROOT, "store")
icon512 = app_icon(512, square=True)  # Play rounds the corners itself
save(icon512, f"{store}/play-icon-512.png")

# Feature graphic 1024 x 500
W, H = 1024, 500
fg = Image.new("RGB", (W, H), GREEN)
d = ImageDraw.Draw(fg)
d.ellipse([760, -120, 1140, 260], fill=GREEN_DARK)
d.ellipse([860, 330, 1000, 470], fill=ORANGE)
d.ellipse([70, 120, 330, 380], fill=(240, 247, 245))
fg.paste(app_icon(200), (100, 150), app_icon(200))


def font(size, bold=True):
    for f in ["/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold else
              "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"]:
        if os.path.exists(f):
            return ImageFont.truetype(f, size)
    return ImageFont.load_default()


d.text((350, 150), "Pawly", font=font(96), fill=WHITE)
d.text((354, 270), "Pet care reminders that", font=font(34, False), fill=WHITE)
d.text((354, 315), "never miss a dose", font=font(34, False), fill=WHITE)
save(fg, f"{store}/feature-graphic-1024x500.png")
print("icons done")
