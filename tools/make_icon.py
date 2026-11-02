"""Draws the Brick Shatter app icon: the game's bricks plus the Kallistesoft brand marks.

Brand marks, the same on every Kallistesoft game icon: the gold sun (top right), the light-blue
waves (bottom), and K / S in navy on the hero's top-left and bottom-right elements. Only the hero
(here a wall of neon bricks with one knocked out, a ball and the paddle) and the background color
change between games.

Writes assets/icon/icon.png (iOS, web, legacy Android, 512 px Play icon) and, for the Android
adaptive icon, assets/icon/background.png (background + waves) and assets/icon/foreground.png
(hero + sun), with the design shrunk into the area Android never crops.
Run: python3 tools/make_icon.py  (needs Pillow), then regenerate sizes as in flutter_launcher_icons.yaml.
"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

SIZE = 1024
SS = 4  # supersampling for smooth edges
S = SIZE * SS

# Kallistesoft brand (from kallistesoft.ca/assets/logo.svg).
SUN = (0xF2, 0xB1, 0x34)
WAVE = (0x63, 0xB6, 0xE6)
INK = (0x16, 0x21, 0x3E)  # K and S
FONT = '/System/Library/Fonts/Supplemental/Arial Black.ttf'

# Brick Shatter.
BACKGROUND = (0x1B, 0x09, 0x30)
PINK, ORANGE, YELLOW, GREEN, CYAN = (0xFF, 0x4F, 0xA3), (0xFF, 0x96, 0x3C), (0xFF, 0xDE, 0x4F), (0x4A, 0xDE, 0x80), (0x22, 0xE3, 0xFF)
GRID = [
    [PINK, ORANGE, YELLOW],
    [GREEN, None, CYAN],
]

# Android shows only the middle 72/108 of an adaptive icon, sometimes as a circle.
ADAPTIVE_SCALE = 72 / 108


class Canvas:
    """Draws in design units (0..1 of the full icon), optionally shrunk around the center."""

    def __init__(self, img, scale=1.0):
        self.img, self.draw, self.scale = img, ImageDraw.Draw(img), scale

    def p(self, v, axis_center=0.5):
        return (axis_center + (v - axis_center) * self.scale) * S

    def len(self, v):
        return v * self.scale * S


def waves(cv, top):
    # Gentle sine along the top edge, filled down to the bottom of the canvas.
    amp, pts = 0.02, []
    for i in range(0, 201):
        x = i / 200
        pts.append((cv.p(x), cv.p(top + amp * math.sin(x * 2 * math.pi * 2.5))))
    # Stretch the band across the whole canvas even when the design is shrunk.
    pts[0], pts[-1] = (0, pts[0][1]), (S, pts[-1][1])
    cv.draw.polygon(pts + [(S, S), (0, S)], fill=WAVE)


def sun(cv):
    cx, cy, r = cv.p(0.79), cv.p(0.19), cv.len(0.055)
    cv.draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=SUN)


def letter(cv, box, ch):
    x0, y0, x1, y1 = box
    font = ImageFont.truetype(FONT, int((y1 - y0) * 0.78))
    b = cv.draw.textbbox((0, 0), ch, font=font)
    cv.draw.text(((x0 + x1) / 2 - (b[0] + b[2]) / 2, (y0 + y1) / 2 - (b[1] + b[3]) / 2), ch, font=font, fill=INK)


def hero(cv):
    # The neon glow goes on its own layer, blurred, under the sharp shapes.
    w, h, gap = cv.len(0.235), cv.len(0.15), cv.len(0.02)
    left, top = cv.p(0.5) - (3 * w + 2 * gap) / 2, cv.p(0.28)
    shapes = []
    for r, row in enumerate(GRID):
        for q, color in enumerate(row):
            if color is not None:
                x, y = left + q * (w + gap), top + r * (h + gap)
                shapes.append(('brick', [x, y, x + w, y + h], color))
    cx, ball = cv.p(0.5), cv.len(0.042)
    by = cv.p(0.625)
    shapes.append(('ball', [cx - ball, by - ball, cx + ball, by + ball], (255, 255, 255)))
    pw, ph, py = cv.len(0.36), cv.len(0.052), cv.p(0.70)
    shapes.append(('brick', [cx - pw / 2, py, cx + pw / 2, py + ph], CYAN))

    glow = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for kind, box, color in shapes:
        if kind == 'ball':
            gd.ellipse(box, fill=color + (170,))
        else:
            gd.rounded_rectangle(box, radius=cv.len(0.03), fill=color + (170,))
    cv.img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(cv.len(0.022))))
    cv.draw = ImageDraw.Draw(cv.img)

    for kind, box, color in shapes:
        if kind == 'ball':
            cv.draw.ellipse(box, fill=color)
        else:
            cv.draw.rounded_rectangle(box, radius=cv.len(0.03), fill=color)
    letter(cv, shapes[0][1], 'K')  # top-left brick
    letter(cv, shapes[4][1], 'S')  # bottom-right brick


def save(img, path, rgb=True):
    img = img.resize((SIZE, SIZE), Image.LANCZOS)
    (img.convert('RGB') if rgb else img).save(path)


def main():
    out = os.path.join(os.path.dirname(__file__), '..', 'assets', 'icon')
    os.makedirs(out, exist_ok=True)

    full = Canvas(Image.new('RGBA', (S, S), BACKGROUND + (255,)))
    waves(full, 0.80)
    sun(full)
    hero(full)
    save(full.img, os.path.join(out, 'icon.png'))

    back = Canvas(Image.new('RGBA', (S, S), BACKGROUND + (255,)), ADAPTIVE_SCALE)
    waves(back, 0.80)
    save(back.img, os.path.join(out, 'background.png'))

    front = Canvas(Image.new('RGBA', (S, S), (0, 0, 0, 0)), ADAPTIVE_SCALE)
    sun(front)
    hero(front)
    save(front.img, os.path.join(out, 'foreground.png'), rgb=False)


if __name__ == '__main__':
    main()
