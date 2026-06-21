# legacy-angular — assets only (do not develop here)

The Angular web prototype **was deleted**. This folder remains **only** so Godot can load raster paths like:

- `res://legacy-angular/public/heroes/*-portrait.png`
- `res://legacy-angular/public/enemies/*-portrait.png`
- `res://legacy-angular/public/ui/*`

## Rules for humans and AI

1. **Do not** restore, update, or run an Angular app in this directory.
2. **Do not** mirror `data/raw/` JSON into a duplicate tree here.
3. **Do not** implement combat or balance changes here — use `scripts/battle/` and `data/raw/`.
4. Portrait/UI asset updates belong in `public/` only (or migrate paths in Godot to `assets/` in a dedicated asset PR).

Balance simulation lives in `scripts/sim/` at the repo root.
