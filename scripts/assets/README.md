# Asset pipeline scripts

Node scripts for portrait normalization, sheet slicing, and JSON validation. Moved out of the deleted Angular app.

Run from repo root:

```bash
npm install          # once (ajv + ajv-formats)
npm run validate-data
# or: node scripts/assets/validate-game-data.mjs
```

Validates `data/raw/heroes.data.json`, `enemies.data.json`, and `battle-modes.json` against `data/schemas/`, plus spawn-name cross-checks.

Godot loads rasters from `legacy-angular/public/` until paths are migrated to `assets/`.
