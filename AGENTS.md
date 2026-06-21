# AGENTS.md — Overload Protocol (Godot)

**Read this first.** The live game is Godot 4.6 + GDScript under `scripts/`, `scenes/`, `assets/`, and `data/raw/`.

## DO NOT touch `legacy-angular/`

`legacy-angular/` is **not part of the game**. It only holds **raster portraits and UI PNGs** that Godot still loads from `res://legacy-angular/public/`.

- **Never** edit, sync, or “keep in parity” any Angular/TypeScript app code — it was **removed on purpose**.
- **Never** add features, balance fixes, or combat logic there.
- If you need TypeScript balance sims, use `scripts/sim/` and `scripts/debug/balance_sim_*.ts`.
- Portrait/asset pipeline scripts live in `scripts/assets/` (not under `legacy-angular/`).
- If you need game data, edit `data/raw/*.json` and `scripts/battle/combat_manager.gd`.

## Run & verify

```bash
# Godot project — open in editor or:
# Main scene: scenes/ui/UnitSelect.tscn

# Data validation (after editing data/raw/*.json)
npm install   # once, for ajv
npm run validate-data

# Balance sims (from repo root; requires Node + npx)
npx tsx scripts/debug/balance_sim_facility.ts 8000
npx tsx scripts/debug/balance_sim_roster_audit.ts 8000
npx tsx scripts/debug/balance_sim_evo_only.ts 8000
npx tsx scripts/debug/balance_sim_full_evo_team.ts 15000

# Static audits (ability keywords, gear/relic effect types)
python scripts/debug/audit_ability_keywords.py
python scripts/debug/audit_gear_relic_effects.py
```

## Data

| Path | Purpose |
|------|---------|
| `data/raw/` | **Canonical** heroes, enemies, items, gear, relics, battle modes |
| `data/schemas/` | JSON Schema for validation |
| `scripts/sim/` | Headless battle sim library (CLI tuning only) |
| `scripts/battle/combat_manager.gd` | **Authoritative** ability/combat keyword implementation |

## Balance & data conventions

- **Enemy HP** in `enemyUnitDefs` must be a **multiple of 5**.
- **Boss phase 2:** ability `dmgP2` / `shieldP2` must be **strictly higher** than phase-1 `dmg` / `shield`. Tune winability via boss HP and `pThr`, not by weakening P2.
- **Godot combat** uses **flat** `enemyUnitDefs` stats every fight. `battleEnemyScale` and `trackHpScale` are **balance-sim lab only** (`--scaled`); not applied at spawn in Godot.
- **Evolution (current):** flat +50 XP per battle, evolve at 100 XP → pending evolution after **fight 2** (one hero per milestone).
- **Facility sim** models `rfm`/`erb`/`wipeShields` and Scrapmaster `p2ReviveNames`; not items, summons, taunt, or cloak.

## Docs

- `docs/AI_AGENT_GAME_REFERENCE.md` — runtime map for assistants
- `offline-bundle/GROUND_TRUTH.md` — offline rules reference (may lag code; prefer `combat_manager.gd` for behavior)
