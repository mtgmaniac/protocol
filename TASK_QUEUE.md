# Overload Protocol — Task Queue

Pick **one item**, implement, test, commit. Don't batch unrelated work.

**Repo:** `C:\Users\Kev\Documents\protocol` · **Baseline:** `docs/BASELINE.md`, tag `baseline-fable-restart`

**Branches:** `fix/cleanup` = backend/data/combat (no UI) · `codex/*` = UI polish · `main` = stable

**Start here:** `AGENTS.md`, `docs/AI_AGENT_GAME_REFERENCE.md`, this file.

---

## Ongoing

Active threads — already in motion; continue when you pick them up, don't restart from scratch.

| Item | Branch | Notes |
|------|--------|-------|
| **Task 5 — Facility balance pass** | `fix/cleanup` | Sim-driven tuning loop. Run `balance_sim_facility.ts`, report cliffs, propose `data/raw/` JSON diffs. Target full-clear band TBD (~3–7% in recent sims). **In progress — don't restart.** |
| **Parallel UI polish** | `codex/compact-battle-ui-three-unit-pips`, `codex/ui-compact-card-prototype` | Battle/reward/evolution/unit-select readability. Separate from backend pass. |

---

## Data

JSON / workbook / balance content. After edits: `npm run validate-data` + `AbilityAuditRunner.tscn`.

| Item | Status | Scope |
|------|--------|-------|
| **Task 5 outputs** | Ongoing | Enemy HP/dmg, roster composition, boss tuning in `enemies.data.json` / `battle-modes.json` from sim reports |
| **Task 12 — Normalize `eff` text** | Open | Regenerate `heroes.data.json` + `enemies.data.json` from workbook; canonical `[value type] [target] [duration]` syntax |
| **Task 13 — Picker blurbs** | Open | Update hero blurbs in `heroes.data.json` from workbook; verify UnitSelect display |
| **Task 11 — Evolution callsigns** | Done | In data + DataManager |
| **Facility operation content** | Mostly done | 10 fights defined; balance numbers still move with Task 5 |

**Task 5 prompt (when continuing):**
> Use `scripts/sim/` + `balance_sim_facility.ts` on the facility operation. Report win rate, fight cliffs, mean depth. Propose data-only JSON diffs — don't apply until reviewed.

**Task 12 prompt:**
> Regenerate `data/raw/heroes.data.json` and `enemies.data.json` with normalized `eff` fields from the workbook. Confirm tooltips read `eff` from data.

**Task 13 prompt:**
> Update picker blurbs in `heroes.data.json` from workbook `picker_blurb` column. Verify on UnitSelect.

---

## UI

Scenes, layout, cards, feedback, audio, themes. **`codex/*` branches only** — not `fix/cleanup`.

| Item | Status | Scope |
|------|--------|-------|
| **Task 8 — Battle feedback / game feel** | Partial | `battle_feedback.gd` extracted; Tier 1–3 primitives per `offline-bundle/ANIMATION.md` still to build |
| **Task 9 — Audio system** | Open | `AudioManager` exists; wire SFX tiers per `offline-bundle/AUDIO.md`, hook to Task 8 events |
| **Task 14 — Enemy half-cards (4–5 enemies)** | Open | Compact enemy card mode in battle layout |
| **Card proportion / readability** | Ongoing | Portrait vs HP vs status at 450×1000 — `compact_unit_card.gd`, `BATTLE_UI_V2_SPEC.md` §19 |
| **Reward / evolution visual consistency** | Ongoing | Shared header; polish pass |
| **V2 band geometry audit** | Dropped | Center uses **540px** not 432 by design (`battle_layout.gd`); no Task 3 pass needed |

**Optional UI follow-ups (not queued):** protocol footer chrome extract, help overlay extract, targeting UI helper.

**Task 8 start prompt:**
> Implement Tier 1 from `ANIMATION.md` one primitive at a time — hit_pause, then attacker lunge. Test in auto-battle between each.

---

## Combat & systems

Backend code, sim fidelity, mechanics — **`fix/cleanup`**. Not data-only JSON, not visual chrome.

| Item | Status | Scope |
|------|--------|-------|
| **Task 7 — `dot` → `burn` rename** | Open | Lockstep code + data + status labels. One session; see rename map below |
| **Mark / vulnerable mechanic** | Open | `markNext` keyword in `combat_manager.gd` + schema + sample abilities |
| **Wraith Engineer protocol efficiency** | Design | Manipulation discounts; Overclocked generator (`gainProtocol`) done |
| **Sim — full protocol economy** | Open | Per-turn +1, nudge/set/item costs in `battle-progress-sim.lib.ts` ( `gainProtocol` charge pool done) |
| **Task 6 — Gear & relic effects** | **Done** (verified 2026-06-21) | Static audit 16/16 gear + 21/21 relic types OK; 3 runtime regressions in ability audit; 11 effects code-only verified — see below |
| **Task 10 — Protocol economy** | Mostly done | Cap 10, +1/turn, nudge +3 once/die, Set 3, flat item cost — **verify Protocol Override relic** |
| **Hygiene — `project.godot*.tmp`** | Open | `git rm --cached` tracked Godot temp files |
| **ARC electric status** | Design | Option A (force roll 1) vs B (zone bump) — decide before implementing |

**Task 7 rename map (abbreviated):** data `dot`/`dT` → `burn`/`burnT`; items `enemyDot` → `enemyBurn`; gear/relic dot* → burn*; code `combat_manager.gd`, `DataManager.gd`, sim; UI status token "Burning". Ability flavor names unchanged.

**Task 7 prompt:**
> Pure rename, no behavior change. Grep all sites, code first then regenerate data from workbook in same pass. One battle to verify ticks.

### Task 6 verification detail (2026-06-21)

**Static:** `python scripts/debug/audit_gear_relic_effects.py` — all gear/relic `effect.type` values in data have handlers.

**Runtime regressions** (`AbilityAuditRunner.tscn`): `lifesteal`, `shieldPierce`, `allyDeathHealAll` — pass.

**Code-verified (no dedicated regression test yet):**

| Effect | Item ID | Hook |
|--------|---------|------|
| `firstAbilityEcho` | echo_matrix | `_apply_hero_ability` re-runs damage once |
| `healShieldBonus` | triage_gel | `_heal_state` when healer ≠ target |
| `protocolOnKill` | bounty_chip | `_on_unit_killed` + basic tier check |
| `protocolOnKillAny` | apex_collector | `_on_unit_killed` any kill |
| `critResolveTwice` | overloadLoop | `resolve_round` re-runs hero ability on raw 20 |
| `rewardsNoCommon` | curatedCache | `GameState._pick_random_item_id` |
| `protocolCarryover` | overflowBuffer | `battle_scene._persist_protocol_carryover` |
| `battleStartConsumable` | fieldCache | battle start → `grant_battle_start_consumables` |
| `reviveNoPenalty` | mercyProtocol | `GameState.get_revive_hp_pct` → 100% |
| `lowHpSquadRollBuff` | emergencySignal | `_trigger_low_hp_squad_roll_buff` at 50% HP |
| `healGrantsShieldAll` | aegisField | `_heal_state` shields all allies |

Optional follow-up: add ability-audit regressions for the 11 above (not blocking — handlers exist and data maps cleanly).

---

## Completed (reference only)

| Item | Notes |
|------|-------|
| Doc drift (Task 0) | `CLAUDE.md`, `GDD.md`, `ROADMAP.md` reconciled |
| Baseline (Task 1) | `docs/BASELINE.md`, tag `baseline-fable-restart`, 78/78 ability audit |
| **Task 2 — battle_scene split** | `battle_layout.gd`, `battle_card_view.gd`, `battle_feedback.gd` |
| **Task 4 — Ability audit** | 78 passed Godot; 0 Python keyword gaps |
| Sim `gainProtocol` | Charge pool in `battle-progress-sim.lib.ts` |
| **Task 6 — Gear & relic effects** | All 14 Task-6 types wired; `audit_gear_relic_effects.py` clean; ability audit regressions pass for lifesteal, shieldPierce, allyDeathHealAll |
| Facility backend merge | Validation, Scrapmaster P2, boss P2 rules |

---

## Design parking lot

Decide before coding; jot answers anywhere convenient.

| Topic | State |
|-------|-------|
| **DoT identity** | Decided → rename to **burn** (Task 7) |
| **ARC mechanic** | A vs B — see Combat & systems |
| **Difficulty target (facility)** | Sets Task 5 goal when pinned |
| **Evolution timing** | 50 XP/battle, evolve at 100 (~fight 2) — intended? |
| **Demo scope** | All 5 ops vs facility-first |
| **Third evolution / stats** | Parked far future |

---

## Working rhythm

1. One prompt → diff → test in Godot (or sim for balance) → commit → next.
2. After any `data/raw/` edit: `npm run validate-data` + ability audit.
3. Reset to tag `baseline-fable-restart` if a refactor goes sideways.
4. Design in chat; implementation in agent sessions on the right branch.
