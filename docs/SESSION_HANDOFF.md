# Session handoff — read this to resume work

**Last updated:** 2026-06-21  
**Repo (local):** `C:\Users\Kev\Documents\protocol`  
**Repo (remote):** [github.com/mtgmaniac/protocol](https://github.com/mtgmaniac/protocol)  
**Godot project:** open `project.godot` in Godot 4.6.2 — **not** the old `overload-protocol` Angular workspace.

---

## Branch workflow (important)

| Branch | Purpose | Notes |
|--------|---------|--------|
| **`main`** | Stable, pushed to GitHub | Currently `b0c83c8` |
| **`fix/cleanup`** | **Backend / data / combat only** | Recreated from `main` after merge; use for next non-UI pass |
| **`codex/compact-battle-ui-three-unit-pips`** | UI polish (parallel) | Battle, reward, evolution, unit select |
| **`codex/ui-compact-card-prototype`** | UI / card readability (parallel) | Do **not** mix with `fix/cleanup` without planning |

**Rule:** On `fix/cleanup`, **do not edit UI** — no scenes, card layout, themes, styles, HUD buttons, tooltips copy in battle chrome, or `compact_unit_card.gd` unless the user explicitly overrides.

### Backend-safe paths (`fix/cleanup`)

- `data/raw/*.json`, `data/schemas/`
- `scripts/battle/combat_manager.gd` (combat truth)
- `scripts/autoloads/DataManager.gd`, `GameState.gd` (non-UI game state)
- `scripts/resources/*.gd`
- `scripts/sim/`, `scripts/debug/balance_sim_*.ts`, `scripts/debug/ability_audit.gd`
- `scripts/assets/validate-game-data.mjs`, root `package.json`
- `AGENTS.md`, this file, `docs/AI_AGENT_GAME_REFERENCE.md`

### UI-only paths (other branches / design agent)

- `scenes/ui/`, `scenes/battle/BattleScene.tscn` layout
- `scripts/battle/battle_scene.gd` (orchestration + footer/header — **includes protocol buttons**)
- `scripts/battle/battle_layout.gd`, `battle_card_view.gd`, `battle_feedback.gd`
- `scripts/ui/compact_unit_card.gd`, `scripts/autoloads/Theme.gd`
- `assets/` UI rasters, `docs/BATTLE_UI_V2_SPEC.md`

**Exception:** `battle_scene.gd` was touched for **nudge once-per-turn** (protocol rule, not visual). Future backend work should prefer `combat_manager.gd` + data; avoid further `battle_scene.gd` unless protocol wiring is required.

---

## What landed on `main` (merged + on GitHub)

Commits through **`b0c83c8`**:

1. **`f7484f6` — Facility backend**
   - JSON validation → `data/raw/` + `npm run validate-data`
   - Schemas: `callsign`, `p2ReviveNames`, `gainProtocol`
   - Balance sim: enemy `rfm`/`erb`/`wipeShields`, Scrapmaster `p2ReviveNames` restore
   - Godot: `_apply_phase_two_revives()`, `gainProtocol` → `_pending_protocol_grants`
   - Facility enemy balance (HP ×5, boss P2 dmg/shield > P1, `pThr` tuning)
   - Field Engineer + Overclocked: `gainProtocol` (+1 recharge, +2 overload)

2. **`b0c83c8` — Battle fixes**
   - Nudge limited to **once per die per turn** (no stacking Protocol into guaranteed 20)
   - Fixed `_log()` format typo in `combat_manager.gd` (blocked battle scene parse)

**Verify after pull:**

```bash
npm run validate-data
```

Godot: open `C:\Users\Kev\Documents\protocol\project.godot`, F5 from UnitSelect or `-- --debug-battle`.

---

## Known gaps / not done yet

| Item | Status |
|------|--------|
| Sim models `gainProtocol` | **Done locally** on `fix/cleanup` (uncommitted); full protocol economy still simplified in sim |
| Task 7: rename `dot` → `burn` | Deferred — lockstep code+data |
| Task 0: doc drift (GDD/ROADMAP vs ground truth) | **Done** (2026-06-21) |
| Task 1: known-good baseline | **Done** (2026-06-21) — `docs/BASELINE.md`, tag `baseline-fable-restart` |
| Wraith Engineer protocol *efficiency* (discounts) | Design only; Overclocked = generator done |
| Mark / vulnerable damage mechanic | Discussed, **not implemented** |
| `project.godot*.tmp` on GitHub | Should `git rm --cached` (noise) |
| Local untracked | `scenes/shared/UnitCard.tscn`, `scripts/debug/flow_smoke_test.gd.uid` |

---

## Combat / data quick reference

- **Authoritative combat:** `scripts/battle/combat_manager.gd`
- **Ability keywords:** audited via `scenes/debug/AbilityAuditRunner.tscn` — gaps should be empty on `main`
- **Facility sim:** `npx tsx scripts/debug/balance_sim_facility.ts 8000`
- **Balance conventions:** enemy HP multiple of 5; boss P2 abilities strictly stronger than P1; Godot uses flat `enemyUnitDefs` (scale keys are sim-lab only)
- **Protocol economy (current):** cap 10, +1/turn, Reroll 2, Nudge 1 (+3, once/die/turn), Set 3, items flat 1
- **Picker categories (design):** damage / defense / support / control (4 groups)

---

## Suggested next tasks on `fix/cleanup` (pick one)

1. **Sim parity:** implement `gainProtocol` in `scripts/sim/battle-progress-sim.lib.ts` + re-run facility sim
2. **Balance check:** re-run facility sim after recent tuning; confirm 3–7% full-clear band still holds
3. **Mechanic spike (backend only):** `markNext` / vulnerable — keyword in `combat_manager.gd` + schema + 2–3 data abilities (no card UI beyond existing status icons)
4. **Hygiene:** remove tracked `project.godot*.tmp` from git
5. **Deferred queue items:** see `TASK_QUEUE.md` (Tasks 0, 7, 10 remainder if any relic tweaks still open)

---

## Prompt for the next conversation

Copy-paste this to start:

```
Read AGENTS.md, docs/SESSION_HANDOFF.md, and docs/AI_AGENT_GAME_REFERENCE.md first.

Repo: C:\Users\Kev\Documents\protocol (Godot 4.6). Work on branch fix/cleanup.
main is synced to GitHub at b0c83c8. UI work happens on codex/* branches — do NOT touch UI scenes, compact_unit_card, battle_layout, Theme, or visual battle chrome.

Backend/data/combat only unless I say otherwise.

[Paste your specific task here — e.g. "Add gainProtocol to the balance sim" or "Implement markNext keyword in combat_manager only"]
```

---

## For humans: does the AI remember across chats?

**No.** Each Cursor conversation starts with **no memory** of prior chats (except what you put in **rules**, **@ files**, or **docs in the repo**). Token usage in one chat does not carry to the next.

**What persists:**

- Git history and these handoff docs
- Cursor **user rules** (e.g. commit only when asked)
- Files you commit to the repo

**Best practice:** open the repo at `C:\Users\Kev\Documents\protocol`, @-mention `docs/SESSION_HANDOFF.md`, and paste the prompt above with your next task.
