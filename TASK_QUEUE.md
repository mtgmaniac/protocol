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
| **Task 5 — Facility balance & content** | `fix/cleanup` | Sim loop (`balance_sim_facility.ts`) → JSON diffs for `enemies.data.json`, `battle-modes.json`. 10 fights defined; enemy HP/dmg, roster, boss tuning still moving. Target full-clear band TBD (~3–7%). **In progress — don't restart.** |
| **Parallel UI polish** | `codex/compact-battle-ui-three-unit-pips`, `codex/ui-compact-card-prototype` | Battle/reward/evolution/unit-select readability. Separate from backend pass. |

**Task 5 prompt (when continuing):**
> Use `scripts/sim/` + `balance_sim_facility.ts` on the facility operation. Report win rate, fight cliffs, mean depth. Propose data-only JSON diffs — don't apply until reviewed.

---

## Data

Static JSON / schema content (not sim-driven tuning). After edits: `npm run validate-data` + `AbilityAuditRunner.tscn`.

| Item | Status | Scope |
|------|--------|-------|
| **Task 13 — Picker blurbs** | **Done** | All 8 heroes have `pickerBlurb` + `pickerCategory` in JSON; DataManager loads them |
| **Task 11 — Evolution callsigns** | **Done** | 8 base + 16 evo callsigns in data; applied on evolve in `GameState.gd` |
| **Task 12 — Normalize `eff` text** | **Done** | `audit_eff_text.py --apply` → 0 mismatches |

**Task 13 prompt (if revisiting copy from workbook):**
> Update picker blurbs in `heroes.data.json` from workbook `picker_blurb` column.

---

## UI

Scenes, layout, cards, feedback, audio, themes. **`codex/*` branches only** — not `fix/cleanup`.

| Item | Status | Scope |
|------|--------|-------|
| **Task 13 — Show picker blurbs on UnitSelect** | Open | Wire `UnitData.picker_blurb` into `home_screen.gd` detail panel |
| **Task 8 — Battle feedback / game feel** | Partial | `battle_feedback.gd` extracted; Tier 1–3 primitives per `offline-bundle/ANIMATION.md` still to build |
| **Task 9 — Audio system** | Open | `AudioManager` exists; wire SFX tiers per `offline-bundle/AUDIO.md`, hook to Task 8 events |
| **Task 14 — Enemy half-cards (4–5 enemies)** | Open | Compact enemy card mode in battle layout |
| **Incoming target indicators** | Open | Subtle readout of who each unit is targeting (enemy → hero intent) during player target pick — informs ally-target choices without heavy chrome |
| **Card proportion / readability** | Ongoing | Portrait vs HP vs status at 450×1000 — `compact_unit_card.gd`, `BATTLE_UI_V2_SPEC.md` §19 |
| **Reward / evolution visual consistency** | Ongoing | Shared header; polish pass |
| **V2 band geometry audit** | Dropped | Center uses **540px** not 432 by design (`battle_layout.gd`); no Task 3 pass needed |

**Optional UI follow-ups (not queued):** protocol footer chrome extract, help overlay extract.

**Incoming target indicators prompt:**
> During hero targeting, show low-key who each living enemy (and taunting/spite interactions) is aimed at — e.g. small target pip on cards, dim connector, or card subtitle. Must stay readable at 450×1000 without cluttering the pick phase.

**Task 8 start prompt:**
> Implement Tier 1 from `ANIMATION.md` one primitive at a time — hit_pause, then attacker lunge. Test in auto-battle between each.

---

## Combat & systems

Backend code, sim fidelity, mechanics — **`fix/cleanup`**. Not data-only JSON, not visual chrome.

**All queued combat items done.** Optional follow-up below (not blocking).

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
| `protocolOnItemUse` | protocolOverride | `battle_scene._get_item_protocol_cost` + `_apply_item_effect` |

Optional follow-up: add ability-audit regressions for the 12 above (not blocking — handlers exist and data maps cleanly).

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
| **Task 10 — Protocol economy** | Cap 10, +1/turn, nudge 1 (+3), reroll 2, set 3, item 1; Protocol Override cost 0 + grant +1 — verified vs `GROUND_TRUTH.md` |
| **Task 12 — Normalize `eff` text** | `audit_eff_text.py` → 0 mismatches |
| **Task 13 — Picker blurbs (data)** | All 8 heroes in JSON + DataManager |
| **Hygiene — `project.godot*.tmp`** | Untracked 2 Godot editor temp files from git index |
| Facility backend merge | Validation, Scrapmaster P2, boss P2 rules |

---

## Parking lot

Ideas saved for later — **not prioritized, not in progress.** Pick up only when explicitly chosen.

### Task 7 — Rename `dot` → `burn` (lockstep code + data)

Pure rename, no mechanic change. Workbook/GROUND_TRUTH already use burn naming; game still uses `dot`/`poison` in code and data.

**Why parked:** large touch surface (combat_manager, DataManager, sim, audits, status UI); must be one session with no partial loads.

**Rename map (abbreviated):** data `dot`/`dT` → `burn`/`burnT`; items `enemyDot` → `enemyBurn`; gear/relic `dot*` → `burn*`; code `combat_manager.gd`, `DataManager.gd`, sim; UI status token → "Burning". Ability flavor names (Venom Nip, etc.) unchanged.

**Future prompt:**
> Pure rename, no behavior change. Grep all sites, code first then regenerate data from workbook in same pass. One battle to verify ticks.

### Design decisions (unpinned)

| Topic | Notes |
|-------|-------|
| **Mark / vulnerable** | `markNext` keyword — combat_manager + schema + sample abilities; not scheduled |
| **Sim — full protocol economy** | Per-turn +1, nudge/set/item costs in sim — **dropped**; `gainProtocol` charge pool sufficient for balance sims |
| **ARC electric status** | Option A (force roll 1) vs B (zone bump) — not scheduled |
| **DoT naming** | Leaning **burn** keyword (Task 7) — not scheduled |
| **Difficulty target (facility)** | Sets Task 5 goal when pinned |
| **Evolution timing** | 50 XP/battle, evolve at 100 (~fight 2) — intended? |
| **Demo scope** | All 5 ops vs facility-first |
| **Third evolution / stats (STR/DEX/INT)** | Far future |
| **Wraith Engineer protocol efficiency** | Manipulation discounts; Overclocked generator done |

---

## Working rhythm

1. One prompt → diff → test in Godot (or sim for balance) → commit → next.
2. After any `data/raw/` edit: `npm run validate-data` + ability audit.
3. Reset to tag `baseline-fable-restart` if a refactor goes sideways.
4. Design in chat; implementation in agent sessions on the right branch.
