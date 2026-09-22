# Draws the app icon: a curling wave over deep water. `python3 tools/icon.py` writes the single
# 1024px image both asset catalogs use (Xcode derives every other size from it).
from PIL import Image, ImageDraw, ImageFilter
import math, os

S = 1024
img = Image.new('RGB', (S, S))
px = img.load()
top, bot = (6, 30, 58), (10, 132, 196)
for y in range(S):
    t = y / (S - 1)
    c = tuple(round(top[i] + (bot[i] - top[i]) * t) for i in range(3))
    for x in range(S):
        px[x, y] = c

wave = Image.new('RGBA', (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(wave)
WATER = 760
# The face rises out of the water on the right, arches over, and pitches down on the left into the
# lip: a band swept counter-clockwise, thick at the base and thinning to the lip.
cx, cy, r = 470, 470, 300
outer, inner = [], []
N = 240
for i in range(N + 1):
    t = i / N
    a = math.radians(-40 + 250 * t)             # from lower right, over the top, down the left
    thick = 190 * (1 - t) + 55 * t
    ro = r + 30 * (1 - t)
    outer.append((cx + ro * math.cos(a), cy - ro * math.sin(a)))
    inner.append((cx + (ro - thick) * math.cos(a), cy - (ro - thick) * math.sin(a)))
# The base carried down into the water so the wave stands on it.
base = [(outer[0][0] + 160, WATER + 30), (inner[0][0] - 40, WATER + 30)]
d.polygon([base[0]] + outer + inner[::-1] + [base[1]], fill=(255, 255, 255, 245))
# The lip's foam ball.
lx, ly = outer[-1]
d.ellipse((lx - 55, ly - 45, lx + 55, ly + 65), fill=(255, 255, 255, 245))
# Water.
d.rectangle((0, WATER, S, S), fill=(8, 60, 110, 255))
for k in range(6):
    y = WATER + 30 + k * 40
    d.line([(x, y + 10 * math.sin(x / 55 + k)) for x in range(0, S, 8)], fill=(120, 200, 240, 90), width=6)
wave = wave.filter(ImageFilter.GaussianBlur(1.2))
img.paste(wave, (0, 0), wave)

here = os.path.dirname(os.path.abspath(__file__))
for cat in ('App/Assets.xcassets/AppIcon.appiconset', 'Watch/Assets.xcassets/AppIcon.appiconset'):
    out = os.path.join(here, '..', cat)
    os.makedirs(out, exist_ok=True)
    img.save(os.path.join(out, 'icon-1024.png'))
print('wrote the icon')
