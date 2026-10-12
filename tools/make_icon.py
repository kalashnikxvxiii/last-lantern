#!/usr/bin/env python3
"""Generates the game icon (pixel-art lantern) as PNG and ICO."""
import os
import sys
from PIL import Image

OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), '..', 'desktop', 'build')
os.makedirs(OUT, exist_ok=True)

PAL = {
    '.': None,
    'k': (11, 8, 16, 255),     # outline
    'g': (59, 53, 70, 255),    # dark iron
    'G': (107, 100, 120, 255), # iron
    'y': (246, 207, 87, 255),  # glass
    'Y': (255, 242, 168, 255), # light glass
    'W': (255, 255, 255, 255), # flame
    'o': (242, 156, 56, 255),  # glow
}
ART = [
    '................',
    '.......kk.......',
    '......kGGk......',
    '.......kk.......',
    '.....kkkkkk.....',
    '....kGGGGGGk....',
    '....kkkkkkkk....',
    '....kgyyyygk....',
    '....kgyYYygk....',
    '....kgyWWygk....',
    '....kgyWWygk....',
    '....kgoyyogk....',
    '....kkkkkkkk....',
    '....kGGGGGGk....',
    '.....kkkkkk.....',
    '................',
]

def render(size):
    n = len(ART)
    base = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    for y, row in enumerate(ART):
        for x, ch in enumerate(row):
            c = PAL[ch]
            if c:
                base.putpixel((x, y), c)
    # dark background with warm halo
    bg = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    r = size // 2
    for yy in range(size):
        for xx in range(size):
            dx, dy = xx - r + 0.5, yy - r + 0.5
            d = (dx * dx + dy * dy) ** 0.5 / r
            if d <= 1.0:
                glow = max(0.0, 1.0 - d * 1.4)
                bg.putpixel((xx, yy), (int(20 + 120 * glow), int(13 + 70 * glow), int(26 + 10 * glow), 255))
    art = base.resize((size, size), Image.NEAREST)
    bg.alpha_composite(art)
    return bg

big = render(512)
big.save(os.path.join(OUT, 'icon.png'))
render(256).save(os.path.join(OUT, 'icon.ico'), sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
print('icon generated in', os.path.abspath(OUT))
