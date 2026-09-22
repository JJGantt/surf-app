# Draws the app icon: a G whose stroke is a wave — thick through the crest at the top, tapering to a
# lip that curls into the letter's opening, with the G's bar as the flat water under it.
# `python3 tools/icon.py` writes the single 1024px image both asset catalogs use (Xcode derives every
# other size from it).
#
# Two colours, one shape, no gradient: an icon is read at 60px, where anything finer is mud. Drawn at
# 4x and shrunk, which is what keeps the curve clean — blurring to hide jagged edges softens the whole
# shape instead. The letter has to win: curl the lip further and it stops reading as a G at all.
from PIL import Image, ImageDraw
import math, os

S, SS = 1024, 4
BG, INK = '#0a1a28', '#f4f8fb'
HOOK, HOOK_PULL = 25, 0.16      # how far the lip carries past the crest, and how far it pulls inward
A0, A1 = -30, 20                # the bar terminal, and where the lip ends: the gap is the G's opening
CREST, TIP, START = 0.55, 0.10, 0.80

img = Image.new('RGB', (S * SS, S * SS), BG)
d = ImageDraw.Draw(img)
cx, cy, r, th = 512 * SS, 512 * SS, 292 * SS, 168 * SS
span = 360 - (A1 - A0)
out, inn = [], []
N = 700
for i in range(N + 1):
    t = i / N
    rr = r if t <= CREST else r * (1 - HOOK_PULL * (((t - CREST) / (1 - CREST)) ** 2.2))
    w = th * ((START + (1 - START) * (t / CREST)) if t < CREST
              else 1.0 + (TIP - 1.0) * (((t - CREST) / (1 - CREST)) ** 1.3))
    a = math.radians(A0 - span * t - HOOK * max(0.0, (t - CREST) / (1 - CREST)) ** 1.6)
    out.append((cx + (rr + w / 2) * math.cos(a), cy - (rr + w / 2) * math.sin(a)))
    inn.append((cx + (rr - w / 2) * math.cos(a), cy - (rr - w / 2) * math.sin(a)))
d.polygon(out + inn[::-1], fill=INK)

ay = math.radians(A0)
ex, ey = cx + r * math.cos(ay), cy - r * math.sin(ay)
h = th * 0.80
d.rounded_rectangle((cx - 0.06 * r, ey - h / 2, ex + th * 0.42, ey + h / 2), radius=h / 2, fill=INK)

img = img.resize((S, S), Image.LANCZOS)
here = os.path.dirname(os.path.abspath(__file__))
for cat in ('App/Assets.xcassets/AppIcon.appiconset', 'Watch/Assets.xcassets/AppIcon.appiconset'):
    img.save(os.path.join(here, '..', cat, 'icon-1024.png'))
print('wrote the icon')
