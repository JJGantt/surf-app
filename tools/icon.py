# Draws the app icon: one barrel, white on deep water. `python3 tools/icon.py` writes the single
# 1024px image both asset catalogs use (Xcode derives every other size from it).
#
# Minimal on purpose: two colours, one shape, no gradient and no detail — an icon is read at 60px on a
# home screen, where anything finer than this is mud. Drawn at 4x and shrunk, which is what keeps the
# curve clean; a blur to hide jagged edges softens the whole shape instead.
from PIL import Image, ImageDraw
import os

S, SS = 1024, 4
BG, INK = '#0a1a28', '#f4f8fb'
img = Image.new('RGB', (S * SS, S * SS), BG)
d = ImageDraw.Draw(img)
k = SS

# The barrel: a thick ring, opened on the lower right by cutting the mouth out of it, and standing on
# the water line rather than floating.
cx, cy, r, t = 512 * k, 500 * k, 330 * k, 132 * k
d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=INK)
d.ellipse((cx - r + t, cy - r + t, cx + r - t, cy + r - t), fill=BG)
# The mouth: the opening the wave throws over, cut as a wedge from the centre to the lower right.
d.pieslice((cx - r - 10 * k, cy - r - 10 * k, cx + r + 10 * k, cy + r + 10 * k), start=-10, end=72, fill=BG)
# The lip, thickening the throw at the top of the mouth.
d.ellipse((cx + r - t * 1.35, cy - t * 0.62, cx + r + t * 0.1, cy + t * 0.78), fill=INK)
# The water: one flat line the barrel sits on.
d.rectangle((0, cy + r - t * 0.30, S * k, S * k), fill=BG)
d.rectangle((96 * k, cy + r - t * 0.30, (S - 96) * k, cy + r - t * 0.30 + 26 * k), fill=INK)

img = img.resize((S, S), Image.LANCZOS)
here = os.path.dirname(os.path.abspath(__file__))
for cat in ('App/Assets.xcassets/AppIcon.appiconset', 'Watch/Assets.xcassets/AppIcon.appiconset'):
    img.save(os.path.join(here, '..', cat, 'icon-1024.png'))
print('wrote the icon')
