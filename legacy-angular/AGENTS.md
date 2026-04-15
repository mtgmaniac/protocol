# AGENTS.md — context for humans & AI

Read this first when picking up **Overload Protocol**. Gameplay lives in Angular + JSON data under `src/app/data/`.

**Gameplay / systems overview for assistants:** `docs/ai-game-context.md` (short loop, services, UI map).

## Run & verify

```bash
npm install
npm start              # dev server → http://localhost:4200/
npm run build          # production build → dist/
npm run validate-data  # AJV check on game JSON vs schemas (run after data edits)
```

Other useful scripts: `npm test`, `npm run watch`, `npm run battle-sim`, `npm run build:gh-pages` / `npm run deploy:gh-pages`.

## Hero portrait asset pipeline

Raster portraits live in `public/heroes/*-portrait.png`. The in-game frame expects **240×317** assets (see `PORTRAIT_IMG_W` / `PORTRAIT_IMG_H` in `src/app/data/sprites.data.ts`). Processing uses **sharp** and `scripts/hero-portrait-normalize.mjs` (background knock-out, trim, zoom/cover into the frame).

| Step | Command / script |
|------|------------------|
| Slice a **sheet** (8×1 strip, 4×2 grid, or Gemini **8×2** + labels) | `npm run slice-hero-sheet -- <path-to-sheet.png> [--8x1 \| --4x2 \| --8x2-top \| --8x2-bottom] [--crop-bottom-pct=12]` |
| Import **style-match** busts from Cursor assets (see script for paths) | `npm run import-stylematch-heroes` |
| Re-normalize **existing** eight PNGs only | `npm run normalize-hero-portraits` |
| Generate **lossless WebP** siblings for public rasters | `npm run optimize-assets` |

**Gemini / art brief:** `docs/hero-portrait-gemini-spec.md` (layout order, panel order, prompt text).

**Enemy** portrait tooling: `npm run normalize-portraits` (different script: `normalize-enemy-portraits.cjs`).

## Non-obvious implementation notes

- **`RASTER_EXT`** in `src/app/data/sprites.data.ts` — `'.png'` or `'.webp'` after running `optimize-assets`; paths and embedded SVG `href`s follow this.
- **Portrait normalization** — `scripts/hero-portrait-normalize.mjs` (knock-out is intentionally strict so dark armor is not erased; tune `BG_THRESH2` / saturation guard there if silhouettes or halos appear).
- **Dev-only** — `app-root` can show `app-dev-hero-editor` in dev mode (`isDevMode()`); not shipped in production builds.
- **Schemas** — JSON under `src/app/data/json/` validated against `src/app/data/schemas/`.

## Intentionally not assumed done here

- **Git / CI** — not configured in-repo; add `.gitignore` (`node_modules/`, `dist/`, `.angular/`) before first commit.
- **WebP by default** — flip `RASTER_EXT` to `'.webp'` only after you are happy with optimized assets and cache behavior.

## User-facing README

See `README.md` for default Angular CLI boilerplate (serve/build/test). This file is the **project map** for contributors and assistants.
