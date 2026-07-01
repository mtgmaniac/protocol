# AGENTS.md — Overload Protocol (Godot)

**Read this first.** The live game is Godot 4.6 + GDScript under `scripts/`, `scenes/`, `assets/`, and `data/raw/`.

**Resuming work?** Read **`docs/AI_AGENT_GAME_REFERENCE.md`**, **`docs/BASELINE.md`**, and **`TASK_QUEUE.md`**. Remote: [github.com/mtgmaniac/protocol](https://github.com/mtgmaniac/protocol).

## Branch split (backend vs UI)

| Branch | Use for |
|--------|---------|
| **`fix/cleanup`** | Data, `combat_manager.gd`, sim, audits — **no UI** |
| **`main`** | Stable; merge `fix/cleanup` here when backend pass is done |
| **`codex/*`** | Battle/unit-select UI polish (parallel; do not mix blindly) |

On **`fix/cleanup`**, do not edit scenes, card layout, `Theme.gd`, `compact_unit_card.gd`, or visual battle chrome unless the user explicitly asks.

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
# Main scene: scenes/ui/MainMenu.tscn (splash -> UnitSelect)

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
- **Evolution (current):** **100 XP** to evolve. Per battle win: alive heroes get **`20 + round(avg_effective_roll)`**; dead heroes get **`round(avg_effective_roll)`** only. First evo typically ~fight 3–4. **One evolution stop per win** — if multiple heroes cross 100 XP, one evolves now; others wait in `deferred_evolution_unit_ids` until a later win.
- **Facility sim** models `rfm`/`erb`/`wipeShields` and Scrapmaster `p2ReviveNames`; not items, summons, taunt, or cloak.

## Docs

- **`docs/AI_AGENT_GAME_REFERENCE.md`** — runtime map for assistants (**start here**)
- **`docs/EFFECT_PIP_GUIDE.md`** — effect pip notation, profiles, and `EffectPip` API (abilities, gear, relics, items)
- **`docs/BASELINE.md`** — verify commands and tag `baseline-fable-restart`
- `docs/BATTLE_UI_V2_SPEC.md` — battle layout contract (UI work)
- `offline-bundle/GROUND_TRUTH.md` — offline rules reference (may lag code; prefer `combat_manager.gd` for behavior)
- `TASK_QUEUE.md` — ordered task list (some items already done)
