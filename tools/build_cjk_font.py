#!/usr/bin/env python3
"""Bakes the CJK glyphs used by the translations into godot/assets/font/cjk.png and cjk.json.

The bitmap font (lantern.png) only covers Latin and Cyrillic. Chinese, Japanese and
Korean come from Fusion Pixel Font 8px (SIL OFL 1.1), one glyph set per language
because Chinese and Japanese draw the same character differently.

Run it after changing the zh, ja or ko text in godot/locale/strings.json:

    python3 tools/build_cjk_font.py <folder with the fusion-pixel-8px-proportional-*.ttf files>

The fonts are in fusion-pixel-font-8px-proportional-ttf-*.zip, from
https://github.com/TakWolf/fusion-pixel-font/releases
"""
import json
import os
import re
import sys
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'godot')
FONT_FILES = {'zh': 'zh_hans', 'ja': 'ja', 'ko': 'ko'}
COLS = 128   # glyphs per atlas row
CELL = 8     # every glyph fits in 8x8, like lantern.png
TOP = 3      # the font's glyphs start 3 pixels below the drawing point


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    fonts_dir = sys.argv[1]
    latin = json.load(open(os.path.join(ROOT, 'assets', 'font', 'glyphs.json'), encoding='utf-8'))
    strings = json.load(open(os.path.join(ROOT, 'locale', 'strings.json'), encoding='utf-8'))
    loc = open(os.path.join(ROOT, 'core', 'loc.gd'), encoding='utf-8').read()
    names = dict(re.findall(r'"(\w\w)": "([^"]+)"', loc[loc.index('const NAMES'):]))

    sets = {}
    for lang in FONT_FILES:
        text = ''.join(v[lang] for v in strings.values()) + names[lang]
        # color codes are not drawn
        text = re.sub(r'\^.', '', text)
        sets[lang] = sorted({ch for ch in text if ch != ' ' and ch not in latin})

    rows = sum((len(s) + COLS - 1) // COLS for s in sets.values())
    atlas = Image.new('RGBA', (COLS * CELL, rows * CELL), (0, 0, 0, 0))
    out = {}
    row = 0
    for lang, chars in sets.items():
        font = ImageFont.truetype(os.path.join(fonts_dir, f'fusion-pixel-8px-proportional-{FONT_FILES[lang]}.ttf'), 8)
        out[lang] = {}
        for i, ch in enumerate(chars):
            if font.getmask(ch).getbbox() is None:
                sys.exit(f'{lang}: the font has no glyph for {ch!r} (U+{ord(ch):04X})')
            x = (i % COLS) * CELL
            y = (row + i // COLS) * CELL
            # the game adds 1 pixel between glyphs, the font's advance includes it
            w = max(1, min(CELL, round(font.getlength(ch))) - 1)
            cell = Image.new('RGBA', (CELL, CELL + TOP), (0, 0, 0, 0))
            cd = ImageDraw.Draw(cell)
            cd.fontmode = '1'   # no antialiasing: whole pixels only
            cd.text((0, 0), ch, font=font, fill=(255, 255, 255, 255))
            atlas.paste(cell.crop((0, TOP, w, TOP + CELL)), (x, y))
            out[lang][ch] = [x, w, y]
        row += (len(chars) + COLS - 1) // COLS
    atlas.save(os.path.join(ROOT, 'assets', 'font', 'cjk.png'))
    with open(os.path.join(ROOT, 'assets', 'font', 'cjk.json'), 'w', encoding='utf-8') as f:
        json.dump(out, f, ensure_ascii=False, separators=(',', ':'))
        f.write('\n')
    print(', '.join(f'{lang} {len(c)}' for lang, c in sets.items()), 'glyphs;', atlas.size)


if __name__ == '__main__':
    main()
