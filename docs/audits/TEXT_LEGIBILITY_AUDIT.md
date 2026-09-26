# Text legibility audit: why the pixel text reads as blurry

**Date:** 2026-09-26 · **Branch:** `audit/text-legibility` · **Scope:** audit only. No
settings, fonts, themes, scenes or copy were changed. Kev decides what changes.

**Audited state:** committed `HEAD` (`eb319f4`). The main working tree has an
**uncommitted** `project.godot` edit that changes `viewport_width/height` from
1080×2400 to **640×960**. This audit does not use that edit, and every number below
assumes the committed 1080×2400 base. If the 640×960 edit is intentional, Part 1 §1
and all of Part 2 need recomputing.

---

## Evidence key: what was measured and what was not

| Tag | Meaning |
|---|---|
| **[file]** | Read directly from a project file (path given). |
| **[runtime]** | Read back from a running game: a windowed Godot 4.6.2 rig (D3D12, Mobile renderer) in a clean `HEAD` worktree, launched with `-s` so DevContext isolated the profile. It walks every visible Label/Button/RichTextLabel and records theme font size, color, outline, effective texture filter, and design and physical origin. Screens: home (squad select), home with 4 heroes locked, route fork, intercept, relic long-press popup (Iron Curtain), reward, run end, main menu, battle. Window 540×1200 (scale 0.5). |
| **[pixels]** | Measured from PNG captures of the same rig (viewport texture = exactly what the window shows). Includes a controlled experiment: m5x7 at 13 sizes on flat `DT_FIELD_BG`, through the real root stretch at scales 0.40, 0.45, 0.50 and 1.0, filter LINEAR vs NEAREST, origin at 0 or +0.5 physical px. |
| **[browser]** | Observed in the web export (`build/web`, exported 2026-09-21) in the desktop app's browser pane: 1280×720 CSS px, DPR 1. |
| **[computed]** | Arithmetic from the above (effective scales, letterbox sizes, WCAG ratios). |
| **[not verified]** | Stated from reading engine code or docs, not observed. |

**Not verified visually:**
- No pixel-level capture of the **web** build. The pane returns downscaled screenshots
  and cannot crop regions. DPR emulation did not reach the canvas because the pane was
  hidden and the engine loop was frozen (see memory note on the hidden-pane rAF freeze).
  Web findings at DPR ≠ 1 come from the engine's shipped JS (`build/web/index.js`,
  `updateSize`), not from observation.
- The web build renders through WebGL2 (Compatibility renderer); the rig renders through
  D3D12 (Mobile renderer). Filtering and glyph-rasterization logic is shared engine code,
  but this audit did not confirm identical pixels across the two.
- No capture on a physical phone. "CLEARED" / "BEST: BATTLE N" did not appear at
  runtime: the isolated dev profile has no clears, so that label's values are **[file]**.

---

# Part 1 — Findings (descriptive, ranked by likely contribution to blur)

## F1. Every label is downscaled by a continuous, non-integer factor, so the font's pixel lands on fractional screen pixels  — *primary cause*

**Scaling pipeline [file]** — `project.godot` at HEAD:

| Setting | Value |
|---|---|
| `display/window/size/viewport_width × height` | 1080 × 2400 |
| `window_width/height_override` (desktop preview) | 540 × 1200 |
| `display/window/stretch/mode` | `canvas_items` |
| `display/window/stretch/aspect` | `expand` |
| `display/window/stretch/scale` | not set → 1.0 **[runtime]** |
| `display/window/stretch/scale_mode` | not set → `fractional` **[runtime]** |
| `display/window/dpi/allow_hidpi` | not set → `true` **[runtime]** |
| `window/handheld/orientation` | 1 (portrait) |

**Web export [file]** `export_presets.cfg:260-263`: `html/custom_html_shell =
res://web/shell.html`, `html/canvas_resize_policy = 2` (Adaptive: the canvas takes the
whole page or iframe). In `web/shell.html`, `#canvas` has only `display:block` and no
margin, border or padding. It has **no `image-rendering` rule** (computed value `auto`,
**[browser]**) and no wrapper. The loader overlay is `position:fixed` and fades out, so
it does not affect the canvas.

**How the engine sizes the canvas [file, `build/web/index.js` `updateSize`]:**
`canvas.width = floor(innerWidth × DPR)`, `canvas.height = floor(innerHeight × DPR)`,
and the CSS size is `floor(width / DPR)` px. With `allow_hidpi = true` the backing store
is at device resolution, so the browser does not upscale the canvas. There is one edge
case: when `innerHeight × DPR` is not whole (fractional DPR only), the CSS box is
up to 1 device px smaller than the backing store, and the browser resamples the whole
frame by a factor just under 1.0 **[not verified — derived from code]**.

**Effective scale factor [computed]**, `s = min(W / 1080, H / 2400)` on the backing
store. With `expand`, the design width grows to `W / s`. The game's pixel text has a
glyph pixel of `k = font_size × s / 16` physical px (see F4 for native size 16).

| Case | CSS viewport | DPR | Backing W×H | **s** | Integer? |
|---|---|---|---|---|---|
| 1080×2400 phone, full-screen canvas (Android native build) | — | 1 | 1080×2400 | **1.000** | yes |
| same phone **in a browser** (e.g. 412×780 visible) | 412×780 | 2.625 | 1081×2047 | **0.853** | **no** |
| 390×844 phone, full viewport | 390×844 | 3 | 1170×2532 | **1.055** | **no** |
| 390×844 in Safari with bars (~390×664 visible) | 390×664 | 3 | 1170×1992 | **0.830** | **no** |
| 1920×1080 desktop, fullscreen | 1920×1080 | 1.0 | 1920×1080 | **0.450** | **no** |
| 1920×1080, fullscreen | 1536×864 | 1.25 | 1920×1080 | **0.450** | **no** |
| 1920×1080, fullscreen | 1280×720 | 1.5 | 1920×1080 | **0.450** | **no** |
| 1920×1080, windowed (~130 CSS px browser chrome) | 1920×950 | 1.0 | 1920×950 | **0.396** | **no** |
| 1920×1080, windowed | 1536×734 | 1.25 | 1920×917 | **0.382** | **no** — also CSS 733 px = 916.25 device px for 917 rows (whole-frame resample) |
| 1920×1080, windowed | 1280×590 | 1.5 | 1920×885 | **0.369** | **no** |
| itch fixed 540×960 embed | 540×960 | 1 / 1.25 / 1.5 | 540×960 / 675×1200 / 810×1440 | **0.40 / 0.50 / 0.60** | **no** |
| Editor desktop preview | 540×1200 window | — | 540×1200 | **0.500** | no (exact half) |
| Browser pane, **observed** | 1280×720 | 1 | 1280×720 | **0.300** | **no** [browser] |

Only the full-screen native 1080×2400 case is integer. Every web case is fractional, and
every desktop case is a **downscale** to roughly 0.37–0.45. That matches Kev's
screenshots: a squad tile is `PORTRAIT_CELL = 238` design px, and 238 × 0.433 ≈ 103 px,
238 × 0.357 ≈ 85 px. Those are two windowed-desktop scales.

**Mechanism [runtime + pixels]:** the viewport reports `oversampling = true`, so Godot
re-rasterizes each glyph at `font_size × s` physical px rather than stretching a
1080-space glyph texture. With antialiasing off, FreeType mono rasterizes the 5×7
outline at a non-integer pixel size. Some font pixels become 1 screen px wide and some
2, so strokes come out uneven. Measured on flat background with NEAREST filtering, so
blur is excluded (share of single-font-pixel strokes not at the modal width):

| size | s=0.40 | s=0.45 | s=0.50 | s=1.0 |
|---|---|---|---|---|
| 36 | 8% (k=0.90 — below 1, strokes collapse) | 13% | **42%** | 19% |
| 42 | 9% (k=1.05) | 24% | 27% | 6% |
| 44 | 21% | 20% | **40%** | 0% |
| 48 | 15% | 26% | 2% | 0% |
| 56 | **32%** | 11% | 2% | 0% |
| 60 | 10% | **43%** | 0% | 0% |
| 64 | 10% | 11% | **0%** | **0%** |
| 72 | 20% | 2% | 19% | 0% |

Uneven strokes make glyphs look lumpy. Combined with F2 they look soft.

## F2. The project-default texture filter is LINEAR, and glyphs sit on fractional physical positions, so edges smear into half-tones  — *primary cause (confirmed)*

**[file/runtime]** `rendering/textures/canvas_textures/default_texture_filter` is not set
in `project.godot`, so it is Godot's default `1 = Linear` (read back at runtime).
**None of the 99 visible labels on the 8 sampled screens override it**, so all inherit
LINEAR. The only exceptions are the three protocol-spend button numerals, which inherit
NEAREST from their button. `PixelUI` sets `TEXTURE_FILTER_NEAREST` on art,
TextureRects and texture buttons (`pixel_ui.gd:267, 651, 693, 755, 791, 899, 955,
1108`) but never on text.

`rendering/2d/snap/snap_2d_transforms_to_pixel` = false and `snap_2d_vertices_to_pixel`
= false (defaults, read at runtime).

**Where glyphs land.** Godot rounds glyph positions in the Control's local (design)
space. A whole design px is a whole physical px only at s = 1. This is the INVARIANTS
#14 failure class applied to text: local rounding is not enough. Runtime counts of
label origins that fall off the physical grid, across the 99 labels [computed from
runtime design origins]:

| s | 1.0 | 0.5 | 0.45 | 0.40 | 0.30 |
|---|---|---|---|---|---|
| labels with a fractional physical origin | 5 | 36 | **96** | **88** | **91** |

Even from a whole origin, a font size that is not a multiple of 16 gives fractional
glyph advances (m5x7 advance = 0.375 em). The ascent is also rounded in design px, so
the baseline lands off-grid below scale 1.

**Controlled result [pixels].** Share of glyph pixels that are mid-tones (neither ink
nor background):

| size | s0.40 LIN | s0.40 NEAR | s0.45 LIN | s0.45 NEAR | s0.50 LIN @0 | s0.50 LIN @+0.5px | s0.50 NEAR | s1.0 LIN @0 / @+0.5 | s1.0 NEAR |
|---|---|---|---|---|---|---|---|---|---|
| 32 | 0.86 | 0.00 | 0.98 | 0.00 | **0.00** | **1.00** | 0.00 | 0.00 / 0.00 | 0.00 |
| 36 | 0.98 | 0.00 | 0.98 | 0.00 | 0.50 | 0.73 | 0.00 | 0.00 / 0.00 | 0.00 |
| 42 | 0.94 | 0.00 | 0.97 | 0.00 | 0.46 | 0.79 | 0.00 | 0.00 / 0.00 | 0.00 |
| 48 | 0.83 | 0.00 | 0.93 | 0.00 | 0.27 | 0.59 | 0.00 | 0.00 / 0.00 | 0.00 |
| 56 | 0.78 | 0.00 | 0.73 | 0.00 | 0.28 | 0.58 | 0.00 | 0.00 / 0.00 | 0.00 |
| 64 | 0.64 | 0.00 | 0.67 | 0.00 | 0.40 | 0.51 | 0.00 | 0.00 / 0.00 | 0.00 |
| 80 | 0.63 | 0.00 | 0.63 | 0.00 | 0.19 | 0.44 | 0.00 | 0.00 / 0.00 | 0.00 |
| 96 | 0.65 | 0.00 | 0.57 | 0.00 | **0.00** | 0.56 | 0.00 | 0.00 / 0.00 | 0.00 |

Read-outs:
- **At every desktop-range scale (0.40, 0.45) with LINEAR, 57–98 % of text pixels are
  smear.** This is the blur.
- NEAREST removes the smear completely (0.00 in every cell) but leaves F1's unevenness.
- At s = 1.0 nothing smears, even with a half-pixel offset. That confirms the rounding
  story: it works at 1:1 and fails below it.
- At the 0.5 preview, only sizes where `size × 0.5 / 16` is whole (32, 96) are clean,
  and only from a whole origin. A half-pixel origin ruins even those.

**Named-label confirmation [pixels, 540×1200 captures, 5–6× nearest zoom]:** "The
foundry…" blurb (64 px, whole origin) is crisp at 0.5. "LV 1" (56 px, origin
256.5/350.5), "LOCKED" (36 px), "DECISION POINT" (42 px) and the relic-popup "RELIC"
(48 px) show visible half-tone columns and rows. The relic popup's 64 px body, whose
origin is at x .6 / y .75, is visibly softer than the same 64 px blurb on the home screen.

## F3. The named small labels sit at 36–48 px, where k is near or below 1 at desktop scales

Font sizes **[runtime unless marked]**. k is the glyph pixel in screen px.

| Label (Kev's list) | Source | Declared → rendered | Color / bg | k @0.50 / 0.45 / 0.40 / 0.37 | Physical origin @0.5 |
|---|---|---|---|---|---|
| "LOCKED" (locked squad tile) | `home_screen.gd:807` `FONT_INFO_MIN` via raw `_make_pixel_label` | 36 → **36** | TEXT_MUTED on #000000 | 1.13 / 1.01 / **0.90** / **0.83** | whole |
| "LOCKED" (encounter card) | `home_screen.gd:490` `PROGRESS_FONT` | 44 → **44** [file] | TEXT_MUTED | 1.38 / 1.24 / 1.10 / 1.01 | — |
| "CLEARED" / "BEST: BATTLE N" | `home_screen.gd:300, 504-508` `PROGRESS_FONT` | 44 → **44** [file] | TEXT_MUTED on #0a141c | 1.38 / 1.24 / 1.10 / 1.01 | — |
| "LV 1" | `home_screen.gd:396` `ENC_META_FONT` | 56 → **56** | DT_AMBER on #0a141c | 1.75 / 1.58 / 1.40 / 1.29 | **256.5, 350.5** |
| "DECISION POINT" | `route_fork_screen.gd:97-99` `TYPE_FONT` via `style_label` | 28 → **42** | DT_AMBER, outline 2 | 1.31 / 1.18 / 1.05 / 0.97 | 45, **448.5** |
| "INTERCEPT" (event type) | `intercept_screen.gd` `TYPE_FONT` | 28 → **42** | DT_AMBER, outline 2 | same | 45, 612 |
| "RELIC" (relic popup subtitle) | `inspect_popup.gd:255` `SUBTITLE_FONT` | 32 → **48** | INSPECT_TEXT_MUTED, outline 2 | 1.50 / 1.35 / 1.20 / 1.11 | **81.6, 540.25** |
| "RELIC" (boxed type chip: reward/loadout/gear) | `item_card.gd:100` `TYPE_CHIP_FONT` | 28 → **42** [file] | rarity accent, outline 0 | 1.31 / 1.18 / 1.05 / 0.97 | — |
| "Tap anywhere to close" | `inspect_popup.gd:204` `HINT_FONT` | 34 → **48** | **INSPECT_TEXT_DIM**, outline 2 | 1.50 / 1.35 / 1.20 / 1.11 | **32.6, 670.25** |
| Squad-detail unit blurb | `home_screen.gd:661` `DETAIL_DESC_FONT = scale_font_size(42)` | → **64** | TEXT_MUTED on #06080a | 2.00 / 1.80 / 1.60 / 1.48 | whole |

At k < 1 (36 px at 0.40, 36–42 px at 0.37), whole font pixels have no screen pixel of
their own, and letterforms lose strokes. The captures show "LOCKED" with broken C/K
strokes at 0.5 already.

**Rendered-size inventory [runtime, 99 labels / 8 screens]:**

| rendered px | count | multiple of 16 (native)? | where (examples) |
|---|---|---|---|
| 32 | 1 | yes | main-menu version stamp |
| 36 | 2 | **no** | LOCKED tiles |
| 42 | 4 | **no** | DECISION POINT, INTERCEPT, ABANDON RUN |
| 48 | 12 | yes (but k = 1.5 at 0.5) | RELIC subtitle, Tap anywhere, rarity lines, section heads, protocol numerals |
| 52 | 3 | **no** | encounter site subtitle, THREATS line |
| 56 | 8 | **no** | LV, fork/intercept buttons, run-end meta |
| 58 | 1 | **no** | run-end service record |
| 60 | 10 | **no** | squad tile names, PROTOCOL label |
| 64 | 25 | yes | body tier, route-card text |
| 72 | 19 | **no** | battle card names/HP, headers |
| 76, 84, 113, 150 | 1, 4, 2, 1 | **no** | detail name, titles, DEPLOY/CONFIRM, RUN FAILED |
| 80, 112 | 1, 5 | yes | encounter name, header run label |

No rendered size is below the native 16 in design px. Measured in **screen** px,
though, anything under `16 / s` is sub-native: under 36 px at s = 0.45, under 40 px at
0.40, under 43 px at 0.37 and under 53 px at 0.30.

**The ladder itself [file]** `pixel_ui.gd:144-147, 808-814`: `UI_FONT_SCALE = 1.35`,
`UI_FONT_STEPS = [20, 24, 28, 32, 36, 42, 48, 56, 64, 72]`. Only 32, 48 and 64 are
multiples of 16. Sizes above 72 pass through unrounded (e.g. 84 → 113). Screens that
author raw px (`home_screen.gd` `_make_pixel_label`, `battle_scene.gd`
`add_theme_font_size_override`, `compact_unit_card.gd`, `PersistentHeader.gd`) bypass
the ladder. The comment at `home_screen.gd:4-6` says those raw sizes are "m5x7 at clean
multiples", but most of its sizes (36, 44, 52, 56, 60, 72, 76, 84) are not multiples of 16.

**Declared font-size constants [file]:** 110 `*FONT*` constants across 24 scripts.
Values range 24–150 before scaling, and 32–202 after `scale_font_size` where it applies.
The full list, with the routing function each one feeds, was generated by
`re.finditer(r'(const|static var|var) *FONT* := N')` over `scripts/` (debug/checks
excluded). Routing was traced by call-site grep and was not verified per constant, so
the runtime table above is authoritative for the sampled screens. Screens not sampled at
runtime: help, evolution, unlock, loadout, operation briefing, spotlight coaches, battle
inspect, floating combat text.

## F4. Font resource and import settings: correct for a pixel font, not a cause

**[file]** One font: `assets/fonts/m5x7.ttf` (+ `.import`, `importer=font_data_dynamic`).

| Import param | Value | Note |
|---|---|---|
| `antialiasing` | 0 (None) | correct for pixel font |
| `hinting` | 0 (None) | correct |
| `subpixel_positioning` | 0 (Disabled) | correct |
| `generate_mipmaps` | false | correct |
| `multichannel_signed_distance_field` | false | correct (MSDF off) |
| `oversampling` | 0.0 = follow viewport; viewport `oversampling = true`, override 0 **[runtime]** | glyphs re-rasterize at the final scale (F1) |
| `keep_rounding_remainders` | true | carries sub-pixel advance remainders; contributes to uneven gaps below s = 1 |
| `disable_embedded_bitmaps` | true | — |
| `allow_system_fallback` | false | — |

**Native design size [file, measured from the TTF with fontTools]:** unitsPerEm 1024,
glyph grid 64 units (H = 320×448 units = 5×7 cells). One font pixel is one screen pixel
at **size 16**, so crisp sizes are integer multiples of 16 **in physical px**.

Loaded through `PixelUI.get_pixel_font()` (`pixel_ui.gd:274`), and the theme default
`assets/ui/theme_overload.tres:170-171` sets `default_font = m5x7`,
`default_font_size = 32`. There is no second font. The web loader uses its own
m5x7 subset as a CSS webfont, which is out of scope since it is gone before the game
paints.

## F5. Off-grid layout sources that put labels on fractional physical positions

**[file + runtime]:**
- **InspectPopup width fraction.** `inspect_popup.gd:15` `PANEL_WIDTH_FRACTION = 0.92`,
  applied at `:401` (`viewport_size.x × 0.92` = 993.6 design px at width 1080) and
  centered at `:422` (`(viewport − size) × 0.5`). Every long-press reveal (relic, gear,
  unit, status, encounter) starts at x = 43.2 design px, and all its labels inherit that
  (runtime: 163.2 / 65.2). An odd content height adds a .5 in y. These are the only
  **non-integer design** origins in the sample, and they are off-grid at every scale
  including 1.0.
- **Center alignment with odd leftover:** half-design-px origins on centered text
  ("LV 1" 256.5 / 350.5 phys = 513 / 701 design; route/intercept stacks at y .5; battle
  enemy name/HP at x .5). At s = 0.5 an odd design px is half a screen px.
- **Everything, at non-0.5 scales:** at s = 0.45 / 0.40 / 0.30, a whole design px is a
  whole screen px only on multiples of 20 / 5 / 10, so 88–96 % of labels are off-grid
  (table in F2). No layout fix alone can put all text on-grid while s is free-floating.
- **Tweened positions:** not sampled. Floating combat text (`battle_feedback.gd`,
  `FLOAT_FONT_SIZE` 96), header and screen transitions, and coach spotlights animate
  positions, so any frame mid-tween is off-grid by construction **[not verified]**.

## F6. Contrast: one failing token family. The dim-blurb hypothesis is not supported

**[computed]** WCAG 2.x ratios of each text token against the real panel backgrounds
(`DT_FIELD_BG #07090b` darkest … `DT_BTN_BG #11161a` / `BG_PANEL_ALT` lightest):

| Token | Range across panels | Verdict (4.5 body / 3.0 large) | Text uses |
|---|---|---|---|
| TEXT_PRIMARY | 14.4–15.9 | pass | most body |
| **TEXT_MUTED** `#8599b3` | **6.2–6.8** | **pass** | squad blurb, CLEARED/BEST/LOCKED, SELECT ENCOUNTER, fork blurbs (36 text sites) |
| INSPECT_TEXT | 14.6–16.2 | pass | popup titles |
| INSPECT_TEXT_MUTED `#8a99a6` | 6.2–6.8 | pass | RELIC subtitle, popup body |
| **INSPECT_TEXT_DIM** `#57646e` | **2.97–3.28** | **FAIL body; borderline large** | "Tap anywhere to close", section heads GEAR / ACTIVE EFFECTS / ITEMS / RELICS / HELD, ability zone labels (rendered 36 px), empty loadout slot names, version stamp, help-menu line (`help_menu.gd:812`), protocol-action title (`protocol_actions.gd:606`) — 9 text sites |
| DT_AMBER / DT_AMBER_TEXT | 7.2–7.9 / 5.6–6.2 | pass | DECISION POINT, LV, section heads |
| DT_HERO_NAME / DT_CYAN / DT_CYAN_BRIGHT | 9.1–12.9 | pass | |
| DT_ENEMY_NAME | 5.3–5.9 | pass | |
| DT_RUST `#c25d3f` | 4.24–4.68 | **marginal** (fails 4.5 on lighter panels; passes as large) | FLAGGED ROUTE 4.55, RUN FAILED 4.68 (both large text) |
| BTN_TEAL_TEXT(_BRIGHT), BTN_AMBER_TEXT | 10.2–15.5 | pass | buttons |
| BTN_DISABLED_TEXT (40 % α) | 2.2–2.45 | fails, but WCAG exempts disabled controls | "SELECT AN ITEM" ghost: 2.29 measured |
| ENEMY_ACCENT | 3.55–3.92 | fails | **0** text references |
| RARITY_RARE | 3.99–4.40 | fails body | **0** direct `PixelUI.` text refs (reaches text via `rarity_color` accent on type chips) |
| COLOR_DAMAGE / DEBUFF | 4.72–5.40 | pass (DEBUFF 4.89 on alt panel) | pips |
| HP numbers `#fafcff` on HP-green `#57854b` | 4.20 | fails without outline | carries a 2-design-px black outline by design (INVARIANTS #14) |

**Measured pairs [runtime color × pixels bg]:** of the distinct label/color pairs measured, the
only sub-4.5 cases are INSPECT_TEXT_DIM ("Tap anywhere to close" 3.16, "DEMO v0.1.1"
3.28), the disabled confirm button (2.29) and the outlined HP numerals (4.20 before
outline).

**The squad-detail blurb measures 6.88:1** (TEXT_MUTED on `#06080a`). It passes AA.
At 0.5 it renders crisp from a whole origin. Its softness at desktop scales is F1 + F2
(k = 1.5–1.8, LINEAR smear 64–67 %), not contrast. The same holds for CLEARED / BEST /
LOCKED (TEXT_MUTED, 6.4–7.2:1).

## F7. Effects on text: outlines are present, shaders and shadows are not

**[runtime + file]:**
- **Outlines:** `PixelUI.style_label` defaults to `outline_size = 2`
  (`pixel_ui.gd:1348-1353`), color `(0.02, 0.03, 0.05, 0.98)`. `style_button` and
  labeled texture buttons use 3; protocol-spend numerals use 5; `style_hp_number` uses
  `HP_NUMBER_OUTLINE_PX`. Home screen, primary buttons and item type chips use 0. On
  these near-black panels the outline has about 1.05:1 contrast with the background, so
  it is mostly invisible. Under F2 it adds one more smeared ring around the glyph, and an
  odd design width (3 on buttons, route titles, run-end) is a half screen px at s = 0.5.
  **Likely a minor contributor.** Not isolated in the experiment.
- **Shadows:** no label draws one (Label `font_shadow_color` alpha 0). Buttons have no
  font-shadow theme item.
- **Shaders / materials on text:** none. 0 of 99 labels has a material, rotation or
  non-1 scale. The only `.gdshader`s (`assets/shaders/dither_dissolve`, `power_down`) are
  used by `TransitionManager.gd` and `TitleLogo.tscn`, so they affect transitions only.
- **Whole-frame effects:** none in the game (no WorldEnvironment glow or BackBufferCopy
  in UI). The web canvas has no CSS filter. The only whole-frame resample is the
  fractional-DPR CSS/backing mismatch in F1 **[not verified]**.

---

# Part 2 — Options (for Kev to decide)

Constraints that bear on every option:
- **G-21 / TRUTH "Web presentation" (Kev, 2026-09-20):** the web build takes the full
  viewport; there is no page-side letterbox, width cap or fixed size. Any option that
  adds bars **needs a new ruling**.
- **INVARIANTS #14** (pixel snap law) and its integer-icon corollary already require
  physical-pixel alignment for strokes and icons. Text is the one surface it does not
  cover yet.
- The m5x7 glyph pixel is `k = size × s / 16` screen px. Crisp needs whole-number k
  **and** a glyph on the physical grid (or NEAREST sampling).

## O1. Sample text with NEAREST instead of LINEAR  — cheap, removes the smear

**What changes:** text-bearing Controls sample glyphs with NEAREST. Either the
project-wide `default_texture_filter = Nearest`, or per-node
`texture_filter = NEAREST` on Label / Button / RichTextLabel. Per-node needs one owner
(a `PixelUI` helper that `style_label`, `_make_pixel_label` and the other raw-px paths
all route through), not scattered call sites.
**Measured effect:** 0 % mid-tones at every size and scale tested (F2 table).
**Costs:** small. The project-wide switch is one setting. Per-node needs a helper plus a
sweep of the raw-px label factories.
**Risks:** (a) F1's unevenness remains and becomes more visible as hard 1 px / 2 px
stroke jitter (up to about 40 % of strokes at some sizes/scales). (b) Project-wide
NEAREST also hits every texture still relying on the LINEAR default: dither overlays,
glows, any down-scaled non-pixel art, and anything else not already set to NEAREST.
Downscaled art aliases and shimmers under NEAREST. That needs a visual sweep; the
per-node route avoids it. (c) A Control's `texture_filter` is inherited by its
children, so setting it on a Button also affects its icon.

## O2. Minimum-size rule and a 16-lattice for pixel text  — cheap to write down, medium to apply

**Proposed rule:**
1. **Floor:** no player-facing m5x7 text below **48 design px** (after
   `scale_font_size`). That keeps k ≥ 1 down to s = 1/3, which covers every desktop case
   in F1 including DPR 1.5 windowed (0.369 → k = 1.1), but not the 0.30 browser pane.
   This raises today's `FONT_INFO_MIN` (36, 56 after scaling) and `FONT_ACCENT_MIN` (28,
   42 after scaling) where raw-px screens use them directly, and every 36 / 42 / 44 site
   in F3.
2. **Lattice:** rendered sizes are multiples of 16. Prefer multiples of 32 (32 / 64 /
   96 / 128), which give whole k at s = 1, 0.5 and 0.25. 48 and 80 are whole only at
   s = 1. Replace `UI_FONT_STEPS` with `[48, 64, 80, 96, 112, 128]` (or `[48, 64, 96,
   128]`) and round sizes above the ladder instead of passing them through.
3. **Body:** paragraphs stay at the 64 tier (`FONT_BODY_MIN` 42 → 64 already).

**Costs:** medium. About 110 constants; every screen reflows. 36/42/44 labels grow by
up to 33 %, and 52–60 labels land on 48 or 64. Layouts sized around text (tiles, chips,
the 2-line detail block, header 144 px) need re-fitting.
**Risks:** the lattice alone does **not** make text crisp while s floats (at s = 0.40
only multiples of 40 give whole k, and the baseline still rounds off-grid). It only pays
off with O1 (less jitter) or with O4 (fully crisp). Larger small-text also risks
overflow in tight rails. Run the wording-fit / layout gates.

## O3. Pin text origins to the physical grid  — medium, partial

**What changes:** extend INVARIANTS #14 to text. Fix the known off-grid sources: round
the InspectPopup width and position to even design px (`inspect_popup.gd:401, 422`),
use even leftovers in centered stacks, and optionally snap each label's global position
via `PixelUI.snap_to_physical_px` on `size_changed`. Also worth one A/B test:
`rendering/2d/snap/snap_2d_transforms_to_pixel = true`. Whether it snaps in final
(screen) space under `canvas_items` stretch was **not verified**.
**Costs:** the popup fix is small. Per-label snapping is medium (a hook on every text
node, redone on resize and during tweens).
**Risks:** fixes origins only. Fractional advances and baseline rounding remain when k
is fractional, so under LINEAR it only reduces the smear (at 0.5: 32 px goes from 1.00
to 0.00 mid-tones, 64 px from 0.51 to 0.40). With O1, origin snapping mostly just moves
which pixel a stroke rounds to.

## O4. Integer scaling — true crispness, at the cost of bars or re-basing

A native m5x7 glyph pixel must be at least one base pixel, so **a base of 1080/n wide
sets the minimum text size at 16·n design px** (n = 3 → 48, matching O2's floor).

**O4a — integer scale on the current 1080×2400 base (`scale_mode = integer`):**
Godot floors the scale, and below 1080×2400 physical it stays at 1 and **clips** (Godot
docs; not tried).

| Target (backing) | s → integer | Result |
|---|---|---|
| 1080×2400 native | 1 | exact, no border |
| 1170×2532 (390×844 @3) | 1 | 1080×2400; 45 px L/R, 66 px T/B spare |
| any phone **browser** (e.g. 1081×2047) | 0 → 1 | **clipped**: 353 design px of height off-screen |
| 1920×1080 fullscreen (DPR 1 / 1.25 / 1.5) | 0 → 1 | **clipped**: 1320 of 2400 design px off-screen |
| 1920×950 / 917 / 885 windowed | 0 → 1 | **clipped** (1450 / 1483 / 1515 off-screen) |
| itch 540×960 @1 / 675×1200 / 810×1440 | 0 → 1 | **clipped** |

**Unusable on web.** The only integer case is the native Android build, which is
already s = 1.

**O4b — re-base to a smaller logical resolution, integer-scaled, with bars (aspect
`keep`).** Border sizes are physical px per side:

| Target (backing) | ½ base 540×1200 | ⅓ base 360×800 |
|---|---|---|
| 1080×2400 native | ×2, **0 / 0** | ×3, **0 / 0** |
| 1170×2532 (390×844 @3) | ×2, 45 L/R · 66 T/B | ×3, 45 L/R · 66 T/B |
| 1081×2047 (phone browser) | ×1, 270 L/R · 423 T/B | ×2, 180 L/R · 223 T/B |
| 1170×1992 (Safari with bars) | ×1, 315 L/R · 396 T/B | ×2, 225 L/R · 196 T/B |
| 1920×1080 fullscreen, DPR 1 / 1.25 / 1.5 (same backing) | **×0 → clips** | ×1, 780 L/R · **140 T/B** |
| 1920×950 windowed, DPR 1 | clips | ×1, 780 L/R · 75 T/B |
| 1920×917 windowed, DPR 1.25 | clips | ×1, 780 L/R · 58–59 T/B |
| 1920×885 windowed, DPR 1.5 | clips | ×1, 780 L/R · 42–43 T/B |
| itch 540×960, DPR 1 | clips | ×1, 90 L/R · 80 T/B |
| itch 675×1200, DPR 1.25 | ×1, 67–68 L/R · 0 T/B | ×1, 157–158 L/R · 200 T/B |
| itch 810×1440, DPR 1.5 | ×1, 135 L/R · 120 T/B | ×1, 225 L/R · 320 T/B |

The ½ base fails every 1080p desktop, since it needs at least 1200 physical px of
height. The ⅓ base works everywhere but gives up 10–26 % of height on desktop and 20–22 % on
phone browsers. Its 780 px side bars on desktop are the same empty sides the
current `expand` already produces.
**Costs:** very high if taken literally. Every authored px value (144 header, 238 cells,
portrait region 328×380, strokes, icon integer scales, safe-area insets) would be
re-authored in base units. **Risks:** re-opens G-21 (bars); breaks the portrait-region
and icon-integer laws unless re-derived; large regression surface.

**O4c — the same ⅓ lattice without re-authoring and without bars ("integer-scaled grid
+ expand fill").** Keep authoring in 1080×2400 units. On every root resize, snap the
final scale **down** to the lattice {1/3, 2/3, 1, 4/3, …} by setting
`Window.content_scale_factor = snapped_s / auto_s`. Keep `aspect = expand`, so the
leftover becomes extra design space rather than black bars. Put all text on multiples
of 48 (k = 1 at 1/3, 2 at 2/3, 3 at 1). With O1 NEAREST, text is then fully
crisp: whole k, no smear, and off-grid origins only shift a whole-pixel stroke.

| Target | auto s | snapped s | Extra design space instead of bars |
|---|---|---|---|
| 1080×2400 | 1.000 | 1 | none |
| 1170×2532 | 1.055 | 1 | design viewport 1170×2532 (+90 w, +132 h) |
| 1081×2047 phone browser | 0.853 | 2/3 | 1621×3070 design (+670 h) — content drawn about 22 % smaller than today |
| 1920×1080 fullscreen (any DPR) | 0.450 | 1/3 | 5760×3240 design (+840 h); about 26 % smaller |
| 1920×950 / 917 / 885 windowed | 0.396 / 0.382 / 0.369 | 1/3 | +450 / +351 / +255 design h; 16 / 13 / 10 % smaller |
| itch 540×960 / 675×1200 / 810×1440 | 0.40 / 0.50 / 0.60 | 1/3 / 1/3 / 1/3 | 1620×2880 / 2025×3600 / 2430×4320 |

**Costs:** medium to high. A scale-snap hook (one owner, alongside PersistentHeader's
resize cadence), a 48-lattice font ladder (collapses today's 36–72 range to 48 / 96:
the jump from 72 to 96 or 48 is coarse), and every screen must tolerate design height
above 2400. The battle rails already flex. Other screens assume 2400 and would show
empty space.
**Risks:** content shrinks by up to about 26 % on desktop. Small-text legibility trades
blur for size (48 px at 1/3 is 7-px-tall caps). The "design height is always 2400" line
in TRUTH changes (needs a ruling). Long-press tolerance and safe-area math already use
the final transform, so they should adapt **[not verified]**.

## O5. Scale-aware font sizes (no lattice)  — medium to high, speculative

**What changes:** on each resize, re-derive each label's size as
`16 · round(k_target) / s`, rounded to an int, so the raster size `size × s` lands
within about 0.5 % of a whole k. Combine with O1.
**Costs:** every label must re-query its size on `size_changed`, and layout reflows on
every resize. **Risks:** int rounding leaves about 1 px of drift over long strings, text
size changes step-wise as the window resizes, and there is no precedent in the codebase.
Listed for completeness; **not tested**.

## O6. Make the web canvas's CSS size exactly match its backing store at fractional DPR  — small to medium

**What changes:** ensure `canvas CSS px × DPR == canvas.width/height`, so the browser
never resamples the frame. For example, a shell-side resize observer that sizes the
canvas to whole device pixels with `canvas_resize_policy = 0`, or trimming the viewport
to a DPR-divisible height. Adding `image-rendering: pixelated` to `#canvas` would make
any residual resample nearest instead of bilinear.
**Costs:** small (shell CSS/JS). **Risks:** only matters at fractional DPR, and the
effect is **not verified**, derived from `updateSize`. Page-side canvas sizing must not
become a width cap (G-21). Re-run `web_loader_test.cjs` and the desktop browser test.

## O7. Contrast floor for text tokens  — cheap

**Proposed floor:** every text-color token is at least **4.5:1 against the lightest
panel it can sit on** (`DT_BTN_BG #11161a` / `BG_PANEL_ALT`). Accent-only tokens that
never color body text are at least 3:1. Disabled text is exempt, but should stay at
least 3:1 so it still reads as present.

| Token | Now (worst panel) | Smallest same-hue value reaching 4.5:1 on `#11161a` |
|---|---|---|
| INSPECT_TEXT_DIM `#57646e` | 2.97 | `#70818e` (4.52) |
| DT_RUST `#c25d3f` (if used for small text) | 4.28 | `#c86041` (4.51) |
| RARITY_RARE `#9d52d8` (via type chips) | 4.02 | `#a858e7` (4.52) |
| ENEMY_ACCENT (no text use today) | 3.58 | `#d95244` (4.54), only if it ever becomes text |

**Costs:** a token edit plus the mirrored `theme_overload.tres` and web-loader palette
gate if a mirrored token moves. **Risks:** INSPECT_TEXT_DIM carries the "dim / tertiary"
hierarchy in popups. Lifting it to about `#70818e` narrows the gap to
INSPECT_TEXT_MUTED `#8a99a6`, so the hierarchy may need spacing or case instead of
lightness. This fixes "Tap anywhere to close" and the popup section heads. It does
**not** fix the squad blurb, CLEARED, BEST or LOCKED, which already pass (F6).

## Cost and effect summary

| Option | Kills smear | Kills uneven strokes | Cost | Needs a ruling |
|---|---|---|---|---|
| O1 NEAREST text | **yes (measured)** | no | small | no |
| O2 size floor + 16-lattice | no | partly (only at s = 1, 0.5) | medium | no |
| O3 origin snapping | partly | no | small (popup) → medium | no |
| O4a integer, current base | — | — | — | unusable (clips) |
| O4b re-base + bars | yes | yes | very high | **yes (G-21)** |
| O4c ⅓ scale lattice + expand fill + 48-lattice + O1 | yes | yes | medium–high | **yes (design height 2400)** |
| O5 scale-aware sizes | with O1 | mostly | medium–high | no |
| O6 canvas DPR match | whole-frame only | no | small | check G-21 |
| O7 contrast floor | — | — | small | token change |

---

## Appendix — reproduction

The rigs lived in a throwaway worktree and are **not committed**.
- **Probe** (extends SceneTree, run with `-s`): for each screen, start a run as
  `scripts/debug/choice_screen_capture.gd` does, `change_scene_to_file`, wait 1.5 s,
  walk `root`, and for every visible text Control record `get_theme_font_size`, the
  `get_theme_color` font color, `outline_size`, the first non-PARENT `texture_filter` up
  the tree, `get_global_transform_with_canvas().origin` and
  `PixelUI.physical_transform(c).origin`. Then save the viewport image. The relic case
  opens `InspectPopup.open(scene, InspectResolver.resolve_item(DataManager.get_item("ironCurtain")))`.
  Load InspectPopup, InspectResolver and PixelUI with `load()` at runtime: a bare class
  reference fails compile under `-s` (see TRUTH's `-s` autoload convention).
- **Matrix** (extends SceneTree, `-s`): hide `PersistentHeader` (its band otherwise
  covers the top rows), set `DisplayServer.window_set_size`, and for the 1:1 case set
  `root.content_scale_mode = DISABLED`. Place a flat `#07090b` ColorRect and one Label
  per size (m5x7, white, outline 0) at `(whole + frac) / s` design px, under a parent
  with the chosen `texture_filter`. Mid-tone share = pixels with mean channel in
  (15, 245) ÷ all pixels > 15. Stroke unevenness = 1 − (modal share of horizontal ink
  runs ≤ ⌈k⌉ + 1).
- Web measurement: `document.getElementById('canvas')` → `width/height`, `style`,
  `getBoundingClientRect()`, `devicePixelRatio`, `getComputedStyle().imageRendering`.
