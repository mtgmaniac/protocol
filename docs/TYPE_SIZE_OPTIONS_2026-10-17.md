# Type size on real phones: finding and options (UI batch A5, 2026-10-17)

**Proposal only. Nothing here changes the default look.** Kev picks; the pick
becomes a ruling and its own task. Captures: `debug_artifacts/batch_a5/type_options/`
(`A_` / `B_` / `C_<screen>_<canvas>.png`, `sheet_<canvas>.png`,
`zoom_help_<canvas>.png`). Harness: `scripts/debug/phone_canvas_capture.gd`.

## 1. The web export renders at device pixel ratio

The 2026-10-17 audit measured m5x7 at 1x CSS resolution (360 x 800, 390 x 867),
where one m5x7 font pixel is 1.33 / 1.44 screen px and strokes come out 1 and 2
px wide. **Real phones do not draw at that resolution.** The shipped engine
(`build/itch-2026-10-10/index.js`) sizes the canvas as CSS px x
`window.devicePixelRatio` whenever hidpi is on:

- `getPixelRatio: function () { return GodotDisplayScreen.hidpi ? window.devicePixelRatio || 1 : 1 }`
- hidpi comes from `display/window/dpi/allow_hidpi`, which `project.godot` does
  not set, so it is Godot's default, **true**.
- `export_presets.cfg` `html/canvas_resize_policy=2` (adaptive: the canvas
  fills the page); `web/shell.html` does not touch the canvas size.
- Stretch: `canvas_items`, aspect `expand`, base 1080 x 2400. The scale is
  min(canvas w / 1080, canvas h / 2400), and m5x7 is rasterized at that scale.

So a phone draws its **physical** canvas. One m5x7 font pixel is
size / 16 x scale physical px:

| Phone (CSS x DPR) | Canvas | Scale | LABEL / BODY 64 | SMALL 48 | 60 (tile names) |
|---|---|---|---|---|---|
| 360 x 800 @ 3 (and Pixel 7: 412 @ 2.625) | 1080 x 2400 | 1.000 | **4.00** | **3.00** | 3.75 |
| iPhone 12-14: 390 x 844 @ 3 | 1170 x 2532 | 1.055 | 4.22 | 3.17 | 3.96 |
| iPhone 15 Pro: 393 x 852 @ 3 | 1179 x 2556 | 1.065 | 4.26 | 3.20 | 3.99 |
| iPhone Pro Max: 430 x 932 @ 3 | 1290 x 2796 | 1.165 | 4.66 | 3.50 | 4.37 |
| Galaxy S (1080 x 2340) | 1080 x 2340 | 0.975 | 3.90 | 2.93 | 3.66 |
| 1x CSS (the audit) 390 x 867 | 390 x 867 | 0.361 | 1.44 | 1.08 | 1.35 |

### Measured at physical resolution (stroke runs, Help body BODY 64 and squad blurb SMALL 48)

Single-stroke ink runs (m5x7 strokes are one font pixel), horizontal and
vertical, in the default look (option A):

| Canvas | BODY 64: runs | worst stroke vs ideal | SMALL 48: runs | worst vs ideal |
|---|---|---|---|---|
| 390 x 867 (1x) | 1 px 85%, 2 px 15% | +39% (ideal 1.44) | 1 px 100% | -8% |
| 1080 x 2400 | 4 px 99%, 3 px 1% | exact (the 3s are glyph corners) | 3 px 100% | exact |
| 1170 x 2532 | 4 px 87%, 5 px 13% | **+18%** (ideal 4.22) | 3 px 92%, 4 px 8% | **+26%** (ideal 3.17) |

**Finding.** hiDPI rendering removes most of the problem: the error drops from
a 1 px vs 2 px stroke (100%) to a 4 vs 5 px stroke at about 460 ppi (one
physical pixel, 0.055 mm). On 1080-wide phones lattice sizes are exact. On
iPhones it is **not** under the ~12% bar: the occasional wider stroke is 18%
(BODY) to 26% (SMALL) over the ideal width, in 8-13% of strokes. Off-lattice
sizes (60, 56, 52, 44, 40, 36, 84, 76) are uneven on every phone. So resizing is
not made unnecessary by hiDPI, but the remaining error is small and only on
non-1080 canvases.

**Correction (2026-10-17, after the census in G-82).** The off-lattice sizes
named above (60, 56, 52, 44, 40, 36, 84, 76) are constants in the screen code,
not sizes that render: every path snaps them (`style_label` / `style_ui_*`: x1.35
then the 48 / 64 / 80 ladder; raw design px: `text_px`). A census of 275 live
text nodes finds only m5x7 48 / 64 / 80 / 96 / 112 and Battle Block 96 / 144, so
nothing renders off the lattice and the "uneven on every phone" claim was wrong.

**Ruling: A** (Kev, 2026-10-17, DECISIONS_RESOLVED G-82).

Note: this assumes the page keeps hidpi on. A desktop browser at DPR 1 (the
540 x 1200 preview, scale 0.5) shows m5x7 64 at exactly 2 px per font pixel.

## 2. Options

### A. Keep sizes, rely on hiDPI (no change)
- Look: unchanged. Strokes exact on 1080-wide phones; 4/5 px (BODY) and 3/4 px
  (SMALL) mixes on iPhones; off-lattice sizes uneven everywhere.
- Cost: none. (This draft offered a pass moving the off-lattice sizes onto the
  16 lattice; see the correction above: they already render on it.)

### B. Snap every m5x7 label to a whole k per phone
Each m5x7 label keeps its layout size and is drawn at the largest whole
k screen px per font pixel at or under it (the existing `PixelUI.bind_m5x7_snap`,
G-78), recomputed per canvas.
- Measured (mock, every m5x7 Label): 1170 x 2532 BODY 4 px 100%, SMALL 3 px
  100% (exact); 1080 x 2400 unchanged (already exact); 390 x 867 1x: exact 1 px,
  but text draws at 69% (BODY) of its size, too small. The mock does not cover
  Button text.
- Look: on iPhones text draws about 5% smaller than today (64 -> 60.7 design
  px); on 1080 canvases nothing changes.
- Cost: high. Every m5x7 label (several hundred, most built as raw
  `add_theme_font_size_override` / `style_label` calls, plus Button text, which
  has no snap path) goes through one helper. The ink snap only works for labels
  in plain Controls; in containers a half-pixel origin can still double a stroke
  edge. Layout is untouched (laid out at the cap), so text never overflows.
  Needs a 1x floor rule (keep today's draw at DPR 1, snap only at scale >= 1)
  and the text legibility and stroke-run gates at physical resolution.

### C. A fixed 1080 x 2400 internal frame at a whole scale
`display/window/stretch/mode = "viewport"`, `scale_mode = "integer"`: the game
always renders 1080 x 2400 and is shown at 1x, 2x... with bars around it.
- Look: lattice sizes exact on every phone. On a 1170 x 2532 iPhone, 45 px bars
  each side and 66 top and bottom (UI_BG); on a 1290 x 2796 Pro Max, 105 and
  198 (16% and 14% of the screen unused). Below 1x there is no whole scale: a
  DPR 1 desktop window (the 540 preview) or a 1x canvas would need a fallback
  (the mock shows 1/3 nearest on 390 x 867, which drops pixels).
- Cost: medium to high. The safe-area work (insets measured against the window,
  `PixelUI.safe_*`) assumes the canvas is the screen; the bars break full-bleed
  backdrops (title, Operation Cleared); expand-aspect phones lose their extra
  height; the desktop preview needs its own path. Off-lattice sizes stay uneven
  unless moved to the lattice.

### Recommendation
A, plus moving the off-lattice m5x7 sizes onto the 16 lattice: exact on
1080-wide phones, a one-pixel mix on iPhones that reads as clean at 460 ppi,
and no new machinery. B is the only option that is exact on iPhones without
bars; it is worth it only if the iPhone mix is visible on a device.

## Mock captures

`phone_canvas_capture.gd` loads the screen, then moves it and the shared header
into a SubViewport of the phone's canvas size with a 2D override stretch at the
phone's scale (fonts oversample from it as from the window stretch). At 1080 x
2400 its squad select frame is pixel-identical to `home_screen_capture.gd`'s
(0 of 2,592,000 px differ). Known limit: the title's art-grid backdrop does not
follow the move at 1080 / 1170 (black field; text unaffected).
