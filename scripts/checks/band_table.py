"""Lays out band_table_capture.gd's crops and bands.json as one table image (G-87).

  python scripts/checks/band_table.py [capture dir]
"""
import json
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

D = Path(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).resolve().parents[2] / "debug_artifacts/art_polish/band_table")
table = json.loads((D / "bands.json").read_text(encoding="utf-8"))
try:
    font = ImageFont.truetype("C:/Windows/Fonts/consola.ttf", 15)
    bold = ImageFont.truetype("C:/Windows/Fonts/consolab.ttf", 17)
except OSError:
    font = bold = ImageFont.load_default()
crops = [Image.open(D / f"{h['id']}.png").convert("RGB") for h in table]
cw = max(c.width for c in crops)
text_w = 560
row_h = max(c.height for c in crops) + 16
W = cw + text_w + 48
H = 48 + row_h * len(table)
out = Image.new("RGB", (W, H), (14, 18, 22))
d = ImageDraw.Draw(out)
d.text((16, 14), "Squad select roll band bar (G-87): live info bar crops at 540x1200, and each band's ability / type / icon", font=bold, fill=(230, 222, 200))
colors = {"attack": (242, 88, 76), "shield": (63, 208, 226), "heal": (95, 209, 122), "utility": (110, 118, 130), "": (79, 84, 88)}
for i, (hero, crop) in enumerate(zip(table, crops)):
    y = 48 + i * row_h
    out.paste(crop, (16, y))
    x = 16 + cw + 24
    d.text((x, y), hero["callsign"], font=bold, fill=(156, 188, 255))
    for j, band in enumerate(hero["bands"]):
        ty = y + 22 + j * 17
        d.rectangle([x, ty + 3, x + 10, ty + 13], fill=colors.get(band["effect"], (255, 0, 255)))
        line = f"{band['range']:>5}  {band['ability']:<20} {band['effect'].upper() or 'NONE':<8} icon: {band['icon']}"
        d.text((x + 18, ty), line, font=font, fill=(230, 222, 200))
out.save(D.parent / "band_table.png")
print(out.size)
