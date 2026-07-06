# AGENTS.md — Overload Protocol (Godot)

**Read this first.** The live game is Godot 4.6 + GDScript under `scripts/`, `scenes/`, `assets/`, and `data/raw/`.

**Resuming work?** Read **`docs/TRUTH.md`** first (canonical — when any doc disagrees with it, TRUTH.md wins), then **`docs/INVARIANTS.md` immediately after** (the WHY rules — non-negotiable), then **`docs/DECISIONS_RESOLVED.md`** (closed rulings: do not relitigate; pending rulings must be transcribed there before implementing), then **`docs/AI_AGENT_GAME_REFERENCE.md`** and **`TASK_QUEUE.md`**. Every task follows **`docs/TASK_TEMPLATE.md`**. Remote: [github.com/mtgmaniac/protocol](https://github.com/mtgmaniac/protocol).

**One-time setup per clone:** `git config core.hooksPath scripts/hooks` — enables the
baseline ceremony (±10 pts per-op drift needs `BASELINE-APPROVED-BY-KEV` in the commit
message) and the battle_scene.gd growth warning.

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

# Full gate, one command (validate-data + audit + smokes + freeze regression
# + sim delta table vs baseline):
python scripts/verify_gate.py            # --skip-sim for the fast pass

# Godot smoke gates (run all four after non-trivial changes):
#   AbilityAuditRunner.tscn          — 105 combat/data checks
#   flow_smoke_test.gd               — 11-step scene-flow playthrough
#   tutorial_smoke_test.gd           — 21-step tutorial playthrough
#   DiceTrayPhysicsProbe.tscn        — dice physics regression (0 penetrations/flyovers)
# See docs/AI_AGENT_GAME_REFERENCE.md §14 for the exact commands.

# Portrait pipeline (rerun when new cutout art lands; --dry-run to audit)
python scripts/assets/defringe_alpha_edges.py
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
- **Boss standing rules (pkg4):** the phase-2 system (`dmgP2`/`shieldP2`/`pThr`) is gone. Each boss has one always-on rule keyed by display name in `combat_manager.gd` `BOSS_STANDING_RULES`; tune winability via boss HP and the rule's numbers (`SCRAPMASTER_REBUILD_PCT`, `MANTLE_ROUND_SHIELD`, brood cadence).
- **Godot combat** uses **flat** `enemyUnitDefs` stats every fight. `battleEnemyScale` and `trackHpScale` are **balance-sim lab only** (`--scaled`); not applied at spawn in Godot.
- **Evolution (current):** **100 XP** to evolve. Per battle win: alive heroes get **`20 + round(avg_effective_roll)`**; dead heroes get **`round(avg_effective_roll)`** only. First evo typically ~fight 3–4. **One evolution stop per win** — if multiple heroes cross 100 XP, one evolves now; others wait in `deferred_evolution_unit_ids` until a later win.
- **Facility sim** models `rfm`/`erb`/`wipeShields`; not items, summons, taunt, cloak, or the pkg4 boss standing rules.

## Docs

- **`docs/TRUTH.md`** — **canonical reference (start here; wins every doc conflict)**; includes verify commands and the sim baseline
- **`docs/AI_AGENT_GAME_REFERENCE.md`** — runtime map for assistants
- **`docs/EFFECT_PIP_GUIDE.md`** — effect pip notation, profiles, and `EffectPip` API (abilities, gear, relics, items)
- `docs/BATTLE_UI_V2_SPEC.md` — battle layout contract (UI work)
- `TASK_QUEUE.md` — ordered task list (some items already done)
- `docs/archive/` — superseded docs (BASELINE, PHASE_0_STATUS, handoffs…); do not use for implementation decisions
