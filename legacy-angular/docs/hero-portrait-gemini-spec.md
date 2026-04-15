# Hero portrait art — tight spec + Gemini prompts

Use this with **Gemini (or any image model)**, then run your pipeline:

`npm run slice-hero-sheet -- path/to/sheet.png` → `npm run optimize-assets`

**Gemini 8×2 sheet (two variants per column + caption strip):** use the **top** row only and crop labels, e.g.  
`node scripts/slice-hero-sheet.mjs public/heroes/hero-lineup-sheet.png --8x2-top --crop-bottom-pct=12`  
(Use `--8x2-bottom` for the lower variant row; tune `--crop-bottom-pct` or `--crop-bottom-px=` if a hair of caption remains.)

---

## 1. Technical spec (non-negotiable)

| Item | Requirement |
|------|-------------|
| **Subject** | Upper body **bust** (head + shoulders + upper chest). Face readable at small UI size (~100px wide on screen). |
| **Pose** | **Straight-on or slight 3/4**, centered horizontally. **Eyes ~same height** across all eight; **shoulder line ~same height** across all eight (pipeline normalizes, but closer at source = better). |
| **Headroom** | Top of hair/helmet **near top of panel** but not cropped; leave a sliver of margin. |
| **Background** | **Flat, solid color per panel** (dark blue-gray, charcoal, etc.) — **no** busy scenes, **no** gradients that touch the character silhouette. Pipeline can knock out solids; avoid colors that appear in skin/armor. |
| **Style** | **Pixel art**: hard edges, limited palette, optional **ordered dithering**; reads as **16-bit / tactical RPG portrait**, not vector, not painterly, not 3D render. |
| **Lighting** | Simple: one key direction; **no** heavy bloom, **no** soft airbrush. |
| **Framing** | Treat each panel as **independent** — character does not span two panels. |
| **Output A (recommended)** | **One image**: **1 row × 8 columns** of **equal-width** panels, **no gaps** between panels (or hairline dividers you will crop out). |
| **Output B** | **One image**: **2 rows × 4 columns**, order below (left→right, top row then bottom). |
| **Minimum size** | Whole sheet at least **~1920px wide** (240px+ per column) and **~400px tall** so pixels survive downscale. Higher is better. |
| **Format** | **PNG** preferred. |

### Panel order (must match filenames)

**Left → right** (strip) or **row 1 then row 2** (grid):

1. **Pulse** — Pulse Tech · Energy wielder  
2. **Combat** — Strike Unit · Strike ops  
3. **Shield** — Spite Guard · Antagonist plate  
4. **Avalanche** — Avalanche Suit · Squad shell  
5. **Medic** — Systems Medic · Field support  
6. **Engineer** — Field Engineer · Support tech  
7. **Ghost** — Ghost Operative · Infiltrator  
8. **Breaker** — Signal Breaker · Comms interdictor  

---

## 2. Game vibe (for the model)

**Overload Protocol** — grimy **tactical sci-fi / cyber-military**. Operators in **worn tech armor**, visors, cables, stenciled kit — **Aliens-meets-cyberpunk**, not clean anime, not high fantasy. Colors: **steel, soot, muted teal/cyan accents**, warning amber, occasional **overload red** (Pulse). Mood: **competent, tired, dangerous**.

---

## 3. Master prompt (paste into Gemini)

Copy everything in the block:

```
Generate ONE horizontal sprite sheet image: a single row of 8 equal-width portrait panels with NO gaps between them. Each panel is the same height. Pixel art style: crisp hard-edged pixels, limited palette, tactical sci-fi / cyber-military RPG character busts (head, shoulders, upper chest only). Not 3D, not smooth digital painting, not vector.

Global rules for ALL panels:
- Upper-body bust only, centered, facing camera or slight 3/4.
- Dark flat solid background inside each panel (different dark hue per panel is OK) so the character pops; no scenery, no text, no UI frames, no watermark.
- Worn tactical tech armor, visors, cables, stenciled military sci-fi gear — gritty "colonial marine tech" vibe, not anime, not fantasy robes.
- Consistent art style, lighting, and pixel scale across all 8.
- Readable face or helmet silhouette at small size.

Panels 1–8 LEFT TO RIGHT:

1) PULSE TECH — energy wielder: sleek assault tech, hints of electricity or heat (pink/red/cyan accent OK), aggressive visor or energy goggles.
2) STRIKE UNIT — frontline DPS: battered combat helmet, cracked or heavy visor, orange/amber accent, "seen too many fights."
3) SPITE GUARD — taunt tank: bulky maroon/brown hostile armor, spikes or brutalist plates, menacing grin or aggressive helmet.
4) AVALANCHE SUIT — squad shield tech: clean white/ice-blue and navy power armor, wide visor, "mobile cover" heavy suit.
5) SYSTEMS MEDIC — field support: lighter armor, mint/teal or soft green medical tech, clear goggles, calm professional.
6) FIELD ENGINEER — support tech: black and yellow hazard tech, multi-lens goggles, tool harness vibe.
7) GHOST OPERATIVE — infiltrator: hooded cloak, shadowed face, subtle circuit marks on skin, purple/dark teal mood.
8) SIGNAL BREAKER — comms jammer: pale synthetic/cyborg face OK, cold blue eyes, white/black/cyan rig, antenna or signal gear hints.

Output: one PNG, very high resolution, 8 equal columns in one row.
```

---

## 4. Optional: single-hero refinement

If one panel is weak, regenerate **only that character** with:

```
Pixel art tactical sci-fi bust portrait, same style as a 16-bit RPG. Upper body only, centered, dark flat solid background, hard pixels, limited palette, no text. [PASTE ONE LINE FROM PANEL LIST ABOVE FOR THAT HERO]
```

Then manually composite into your sheet or replace that column in an editor, re-run slice + normalize.

---

## 5. Avoid (negative intent)

Ask the model to avoid: **text, logos, watermarks, UI frames, extra arms, duplicate heads, blurry anti-aliased edges, glossy Fortnite style, chibi proportions, full-body shots, characters crossing panel borders, busy backgrounds, lens flare.**

---

## 6. After you have the image

1. Save as PNG.  
2. `npm run slice-hero-sheet -- "<path-to-sheet.png>"`  
3. If cells already look aligned, you can skip bulk re-normalize; otherwise `npm run normalize-hero-portraits`.  
4. `npm run optimize-assets`

Intrinsic game target: **240×317** assets under `public/heroes/*-portrait.png` (handled by your scripts).
