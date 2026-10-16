"""Annotate a battle capture with its layout rhythm (ui-fix 2026-10-16).

  python scripts/checks/annotate_layout.py CAPTURE.png REPORT_LINE.txt OUT.png

REPORT_LINE.txt holds the `[LAYOUT_REPORT] {...}` line printed by
`battle_ui_capture.gd --capture-layout-report` (design px, 1080 wide). Draws
each measured band and gap on a 2x copy of the capture with its size in design
px, and prints the same numbers.
"""
import json
import sys

from PIL import Image, ImageDraw


def bands(d):
    def top(k):
        return d[k][1]

    def bottom(k):
        return d[k][1] + d[k][3]

    rows = [
        ("header bar", 0.0, bottom("header_band")),
        ("header -> enemy cards", bottom("header_band"), top("enemy_cards")),
        ("enemy cards", top("enemy_cards"), bottom("enemy_cards")),
        ("enemy cards -> tray", bottom("enemy_cards"), top("tray")),
        ("tray", top("tray"), bottom("tray")),
        ("tray -> hero cards", bottom("tray"), top("hero_cards")),
        ("hero cards", top("hero_cards"), bottom("hero_cards")),
        ("hero cards -> footer", bottom("hero_cards"), top("footer_divider")),
        ("footer bar", top("footer_divider"), 2400.0),
    ]
    if "protocol_stack" in d:
        rows.append(("footer top pad", bottom("footer_divider"), top("btn_item")))
        rows.append(("footer bottom pad", bottom("btn_item"), bottom("protocol_panel")))
    return rows


def main() -> int:
    cap, report, out = sys.argv[1], sys.argv[2], sys.argv[3]
    line = open(report, encoding="utf-8").read()
    d = json.loads(line.split("[LAYOUT_REPORT] ", 1)[1].strip().splitlines()[0])
    im = Image.open(cap).convert("RGB")
    scale = im.size[0] / 1080.0
    big = im.resize((im.size[0] * 2, im.size[1] * 2), Image.NEAREST)
    k = 2 * scale
    draw = ImageDraw.Draw(big)
    x = big.size[0] - 8
    for i, (name, y0, y1) in enumerate(bands(d)):
        h = y1 - y0
        print("%-22s %7.1f .. %7.1f  = %6.1f" % (name, y0, y1, h))
        colour = (255, 80, 200) if "->" in name or "pad" in name else (80, 220, 255)
        bx = x - (i % 2) * 14
        draw.line([(bx, y0 * k), (bx, y1 * k)], fill=colour, width=3)
        draw.line([(bx - 6, y0 * k), (bx, y0 * k)], fill=colour, width=2)
        draw.line([(bx - 6, y1 * k), (bx, y1 * k)], fill=colour, width=2)
        label = "%s %g" % (name, round(h, 1))
        tw = draw.textlength(label)
        ty = (y0 + y1) * 0.5 * k - 6
        draw.rectangle([bx - 12 - tw - 4, ty - 2, bx - 10, ty + 12], fill=(0, 0, 0))
        draw.text((bx - 12 - tw - 2, ty), label, fill=colour)
    buttons = [d[b] for b in ("btn_nudge", "btn_reroll", "btn_set", "btn_item") if b in d]
    for a, b in zip(buttons, buttons[1:]):
        gap = b[0] - (a[0] + a[2])
        print("footer button gap %.1f (buttons %.0fx%.0f)" % (gap, a[2], a[3]))
    big.save(out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
