"""Draws the Play Store phone screenshots and feature graphic for every listing language.

Takes raw-<name>.png gameplay captures (1080 x 1920, no ads) from the folder given as the
first argument and writes store/screenshots/<lang>/<n>_<name>.png and the 1024 x 500
store/feature-graphic-<lang>.png, plus store/icon-512.png.
Run: python3 tools/make_store_graphics.py <raw folder>  (needs Pillow and the Inter font).
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.join(os.path.dirname(__file__), '..')
FONT_DIRS = ['/usr/share/fonts/opentype/inter', os.path.expanduser('~/Library/Fonts'), '/Library/Fonts']
WIDTH, HEIGHT = 1080, 1920
TOP, BOTTOM = (0x0B, 0x06, 0x20), (0x2A, 0x0B, 0x3D)
PINK, CYAN, YELLOW, INK = (0xFF, 0x2D, 0x95), (0x22, 0xE3, 0xFF), (0xFF, 0xD6, 0x0A), (0xF2, 0xEC, 0xFF)

# (raw name, headline, subline, headline color). The first one is the boss collage.
SCREENS = {
    'en': [
        ('bosses', 'BEAT 4 EPIC BOSSES', 'Can you beat them all?', PINK),
        ('titan-warning', 'A BOSS EVERY 5 LEVELS', 'Sentinel, Hive, Prism, Titan…', CYAN),
        ('wall', 'SMASH NEON BRICKS', 'Fast, glowing arcade action', CYAN),
        ('lasers', 'LASERS & MULTI-BALL', 'Grab power-ups, dodge red capsules', YELLOW),
        ('prism-warning', 'EVERY BOSS IS DIFFERENT', 'Learn its moves, find the weak spot', PINK),
        ('titan-angry', 'THEY FIGHT BACK', 'Bosses get angry when they are hurt', PINK),
        ('maze', 'NEW WALLS EVERY LEVEL', 'Steel, explosive and armored bricks', CYAN),
        ('short', 'PERFECT FOR THE COMMUTE', 'Short levels, progress always saved', YELLOW),
    ],
    'fr': [
        ('bosses', 'BATTEZ 4 BOSS ÉPIQUES', 'Vous les battrez tous ?', PINK),
        ('titan-warning', 'UN BOSS TOUS LES 5 NIVEAUX', 'Sentinel, Hive, Prism, Titan…', CYAN),
        ('wall', 'CASSEZ DES BRIQUES NÉON', 'De l’action arcade rapide et lumineuse', CYAN),
        ('lasers', 'LASERS ET MULTI-BALLES', 'Attrapez les bonus, évitez le rouge', YELLOW),
        ('prism-warning', 'CHAQUE BOSS EST UNIQUE', 'Apprenez ses attaques, trouvez la faille', PINK),
        ('titan-angry', 'ILS RIPOSTENT', 'Blessés, les boss deviennent enragés', PINK),
        ('maze', 'DE NOUVEAUX MURS', 'Briques d’acier, explosives et blindées', CYAN),
        ('short', 'PARFAIT DANS LES TRANSPORTS', 'Niveaux courts, progression sauvegardée', YELLOW),
    ],
}
BOSSES = [('sentinel', 'SENTINEL'), ('hive', 'HIVE'), ('prism', 'PRISM'), ('titan-angry', 'TITAN')]


def font(weight, size):
    for d in FONT_DIRS:
        for name in (f'InterDisplay-{weight}.otf', f'Inter-{weight}.otf'):
            path = os.path.join(d, name)
            if os.path.exists(path):
                return ImageFont.truetype(path, size)
    raise SystemExit('Inter font not found: install it (fonts-inter) or add its folder to FONT_DIRS')


def gradient(w, h):
    img = Image.new('RGB', (w, h))
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / h
        d.line([(0, y), (w, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(TOP, BOTTOM)))
    return img


def fitted(text, width, size, weight='Black'):
    probe = ImageDraw.Draw(Image.new('RGB', (1, 1)))
    while probe.textlength(text, font=font(weight, size)) > width:
        size -= 2
    return font(weight, size)


def glow_text(img, xy, text, fnt, color, blur=12):
    layer = Image.new('RGBA', img.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).text(xy, text, font=fnt, fill=color + (230,), anchor='mm')
    halo = layer.filter(ImageFilter.GaussianBlur(blur))
    img.paste(halo, (0, 0), halo)
    img.paste(halo, (0, 0), halo)
    ImageDraw.Draw(img).text(xy, text, font=fnt, fill=color, anchor='mm')


def rounded(im, radius):
    mask = Image.new('L', im.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, im.width - 1, im.height - 1], radius=radius, fill=255)
    return mask


def framed(img, shot, box, color, radius=44):
    """Pastes [shot] into [box] (x, y, w, h) with rounded corners and a neon outline."""
    x, y, w, h = box
    shot = shot.resize((w, h), Image.LANCZOS).convert('RGB')
    glow = Image.new('RGBA', img.size, (0, 0, 0, 0))
    ImageDraw.Draw(glow).rounded_rectangle([x - 6, y - 6, x + w + 5, y + h + 5], radius=radius + 6, outline=color + (255,), width=6)
    glow = glow.filter(ImageFilter.GaussianBlur(14))
    img.paste(glow, (0, 0), glow)
    img.paste(shot, (x, y), rounded(shot, radius))
    ImageDraw.Draw(img).rounded_rectangle([x - 3, y - 3, x + w + 2, y + h + 2], radius=radius + 3, outline=color, width=4)


def header(img, headline, sub, color):
    glow_text(img, (WIDTH / 2, 150), headline, fitted(headline, WIDTH - 100, 104), color)
    ImageDraw.Draw(img).text((WIDTH / 2, 262), sub, font=fitted(sub, WIDTH - 140, 50, 'Bold'), fill=INK, anchor='mm')


def boss_center(raw):
    """Center of the boss sprite: the pink/red pixels in the upper field."""
    px = raw.convert('RGB').load()
    xs, ys = [], []
    for y in range(180, 1300, 4):
        for x in range(0, raw.width, 4):
            r, g, b = px[x, y]
            if r > 170 and g < 110 and r - b > 40:
                xs.append(x)
                ys.append(y)
    xs.sort()
    ys.sort()
    return xs[len(xs) // 2], ys[len(ys) // 2]


def collage(raw_dir, headline, sub, color):
    img = gradient(WIDTH, HEIGHT)
    header(img, headline, sub, color)
    tile_w, tile_h, gap = 470, 600, 40
    left = (WIDTH - 2 * tile_w - gap) // 2
    for i, (name, label) in enumerate(BOSSES):
        raw = Image.open(os.path.join(raw_dir, f'raw-{name}.png'))
        cx, cy = boss_center(raw)
        cw, ch = 470, 600  # same aspect as the tile: the boss fills it
        x0 = min(max(cx - cw // 2, 0), raw.width - cw)
        y0 = min(max(cy - ch // 2, 130), raw.height - ch)  # below the HUD and boss HP bar
        tile = raw.crop((x0, y0, x0 + cw, y0 + ch))
        x = left + (i % 2) * (tile_w + gap)
        y = 400 + (i // 2) * (tile_h + 150)
        framed(img, tile, (x, y, tile_w, tile_h), PINK if i % 2 == 0 else CYAN, radius=36)
        glow_text(img, (x + tile_w / 2, y + tile_h + 62), label, font('Black', 58), INK, blur=8)
    return img


def screenshot(raw, headline, sub, color):
    img = gradient(WIDTH, HEIGHT)
    header(img, headline, sub, color)
    h = HEIGHT - 380 - 70
    w = round(raw.width * h / raw.height)
    framed(img, raw, ((WIDTH - w) // 2, 380, w, h), color)
    return img


def main():
    raw_dir = sys.argv[1]
    for lang, screens in SCREENS.items():
        out = os.path.join(ROOT, 'store', 'screenshots', lang)
        os.makedirs(out, exist_ok=True)
        for f in os.listdir(out):
            if f.endswith('.png'):
                os.remove(os.path.join(out, f))
        for n, (name, headline, sub, color) in enumerate(screens, 1):
            if name == 'bosses':
                img = collage(raw_dir, headline, sub, color)
            else:
                img = screenshot(Image.open(os.path.join(raw_dir, f'raw-{name}.png')), headline, sub, color)
            img.save(os.path.join(out, f'{n}_{name}.png'), optimize=True)
        feature_graphic(raw_dir, lang).save(os.path.join(ROOT, 'store', f'feature-graphic-{lang}.png'), optimize=True)
    icon = Image.open(os.path.join(ROOT, 'assets/icon/icon.png')).convert('RGB')
    icon.resize((512, 512), Image.LANCZOS).save(os.path.join(ROOT, 'store', 'icon-512.png'))


FEATURE = {'en': ('Beat the bosses.', 'Free arcade brick breaker'), 'fr': ('Battez les boss.', 'Casse-briques arcade gratuit')}


def feature_graphic(raw_dir, lang):
    """1024 x 500 feature graphic: also the cover of the promo video on the store page."""
    img = gradient(1024, 500)
    icon = Image.open(os.path.join(ROOT, 'assets/icon/icon.png')).convert('RGB').resize((120, 120), Image.LANCZOS)
    img.paste(icon, (56, 50), rounded(icon, 28))
    glow_text(img, (300, 225), 'BRICK SHATTER', fitted('BRICK SHATTER', 500, 72), PINK, blur=10)
    glow_text(img, (300, 300), 'NEON BREAKER', fitted('NEON BREAKER', 440, 56), CYAN, blur=10)
    tag, sub = FEATURE[lang]
    d = ImageDraw.Draw(img)
    d.text((300, 380), tag, font=font('Black', 40), fill=INK, anchor='mm')
    d.text((300, 428), sub, font=font('Bold', 28), fill=(0xB8, 0xAE, 0xD6), anchor='mm')
    for (name, x, y, w, h, color) in [('titan-angry', 600, 40, 380, 260, PINK), ('prism', 600, 320, 180, 150, CYAN), ('hive', 800, 320, 180, 150, CYAN)]:
        raw = Image.open(os.path.join(raw_dir, f'raw-{name}.png'))
        cx, cy = boss_center(raw)
        cw = 560 if name == 'titan-angry' else 520
        ch = round(cw * h / w)
        x0 = min(max(cx - cw // 2, 0), raw.width - cw)
        y0 = min(max(cy - ch // 2, 130), raw.height - ch)
        framed(img, raw.crop((x0, y0, x0 + cw, y0 + ch)), (x, y, w, h), color, radius=22)
    return img


if __name__ == '__main__':
    main()
