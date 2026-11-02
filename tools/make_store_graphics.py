"""Draws the Play Store graphics from raw web-build screenshots (the web build carries no ads).

Takes raw-<screen>.png from the folder given as the first argument and writes, under store/:
- screenshots/<lang>/<n>_<screen>.png: 1080 x 1920 phone screenshots with a caption;
- feature-graphic-<lang>.png: the 1024 x 500 feature graphic;
- icon-512.png: the Play icon, from assets/icon/icon.png.
Run: python3 tools/make_store_graphics.py <raw folder>  (needs Pillow).
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.join(os.path.dirname(__file__), '..')
FONT = '/System/Library/Fonts/Supplemental/Arial Black.ttf'
WIDTH, HEIGHT = 1080, 1920
TOP, BOTTOM = (0x0B, 0x06, 0x20), (0x2A, 0x0B, 0x3D)
PINK, CYAN, INK = (0xFF, 0x2D, 0x95), (0x22, 0xE3, 0xFF), (0xF2, 0xEC, 0xFF)

SCREENS = {
    'en': [
        ('play', 'Smash neon brick walls'),
        ('boss', 'A boss every 5 levels'),
        ('wall', 'Levels that keep getting harder'),
        ('boss2', 'Bosses come back stronger'),
        ('home', 'Chase your best score'),
    ],
    'fr': [
        ('play', 'Pulvérisez des murs de néon'),
        ('boss', 'Un boss tous les 5 niveaux'),
        ('wall', 'Des niveaux toujours plus durs'),
        ('boss2', 'Les boss reviennent plus forts'),
        ('home', 'Battez votre meilleur score'),
    ],
}
FEATURE = {'en': 'Break the grid. Beat the bosses.', 'fr': 'Brisez la grille. Battez les boss.'}


def gradient(w, h):
    img = Image.new('RGB', (w, h))
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / h
        d.line([(0, y), (w, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(TOP, BOTTOM)))
    return img


def fitted(draw, text, width, size):
    while draw.textlength(text, font=ImageFont.truetype(FONT, size)) > width:
        size -= 2
    return ImageFont.truetype(FONT, size)


def glow_text(img, xy, text, font, color, anchor='mm'):
    layer = Image.new('RGBA', img.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).text(xy, text, font=font, fill=color + (220,), anchor=anchor)
    img.paste(layer.filter(ImageFilter.GaussianBlur(10)), (0, 0), layer.filter(ImageFilter.GaussianBlur(10)))
    ImageDraw.Draw(img).text(xy, text, font=font, fill=color, anchor=anchor)


def screenshot(raw, caption):
    img = gradient(WIDTH, HEIGHT)
    d = ImageDraw.Draw(img)
    glow_text(img, (WIDTH / 2, 150), caption, fitted(d, caption, WIDTH - 110, 64), CYAN)
    shot_h = HEIGHT - 280
    shot = raw.resize((round(raw.width * shot_h / raw.height), shot_h), Image.LANCZOS).convert('RGB')
    mask = Image.new('L', shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, shot.width - 1, shot.height - 1], radius=48, fill=255)
    img.paste(shot, ((WIDTH - shot.width) // 2, 260), mask)
    return img


def feature(lang, raw):
    img = gradient(1024, 500)
    icon = Image.open(os.path.join(ROOT, 'assets/icon/icon.png')).convert('RGB').resize((300, 300), Image.LANCZOS)
    mask = Image.new('L', icon.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, 299, 299], radius=66, fill=255)
    img.paste(icon, (64, 100), mask)
    d = ImageDraw.Draw(img)
    glow_text(img, (680, 165), 'BRICK', ImageFont.truetype(FONT, 96), PINK)
    glow_text(img, (680, 270), 'SHATTER', ImageFont.truetype(FONT, 76), CYAN)
    tag = FEATURE[lang]
    d.text((680, 355), tag, font=fitted(d, tag, 580, 34), fill=INK, anchor='mm')
    return img


def main():
    raw_dir = sys.argv[1]
    for lang, screens in SCREENS.items():
        out = os.path.join(ROOT, 'store', 'screenshots', lang)
        os.makedirs(out, exist_ok=True)
        for n, (name, caption) in enumerate(screens, 1):
            raw = Image.open(os.path.join(raw_dir, f'raw-{name}.png'))
            screenshot(raw, caption).save(os.path.join(out, f'{n}_{name}.png'))
        feature(lang, None).save(os.path.join(ROOT, 'store', f'feature-graphic-{lang}.png'))
    icon = Image.open(os.path.join(ROOT, 'assets/icon/icon.png')).convert('RGB')
    icon.resize((512, 512), Image.LANCZOS).save(os.path.join(ROOT, 'store', 'icon-512.png'))


if __name__ == '__main__':
    main()
