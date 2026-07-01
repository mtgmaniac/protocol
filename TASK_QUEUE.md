# Overload Protocol — Task Queue

Pick **one item**, implement, test, commit. Don't batch unrelated work.

**Repo:** `C:\Users\Kev\Documents\protocol` · **Baseline:** `docs/BASELINE.md`, tag `baseline-fable-restart`

**Branches:** `fix/cleanup` = backend/data/combat (no UI) · `codex/*` / `feat/ui-redesign` = UI · `main` = stable

**Start here:** `AGENTS.md`, `docs/AI_AGENT_GAME_REFERENCE.md`, this file.

**During UI redo (`feat/ui-redesign`):** add tasks and design notes here only — **do not edit game code** until UI merges to `main`. Claude owns UI scenes/layout; Cursor picks up data/backend/combat after merge (mostly on `fix/cleanup`).

---

## Ongoing

Active threads — already in motion; continue when you pick them up, don't restart from scratch.

| Item | Branch | Notes |
|------|--------|-------|
| **Task 5 — Facility balance & content** | `fix/cleanup` | **Paused** — no sim runs until post-UI finalize pass. D1 target: **25–40%** skilled full-clear in real play (items/protocol/relic); flat sim ~1.7% is reference only, not tuning target. |
| **Parallel UI polish** | `feat/ui-redesign`, `codex/*` | Direction-05 UI, battle/reward/evolution/unit-select readability. Separate from backend pass. |

**Task 5 prompt (when continuing):**
> Use `scripts/sim/` + `balance_sim_facility.ts` on the facility operation. Report win rate, fight cliffs, mean depth. Propose data-only JSON diffs — don't apply until reviewed.

---

## Data

Static JSON / schema content (not sim-driven tuning). After edits: `npm run validate-data` + `AbilityAuditRunner.tscn`. **Lane:** `fix/cleanup` (or post-UI merge).

| Item | Status | Scope |
|------|--------|-------|
| **Task 13 — Picker blurbs** | **Done** | All 8 heroes have `pickerBlurb` + `pickerCategory` in JSON; DataManager loads them |
| **Task 11 — Evolution callsigns** | **Done** | 8 base + 16 evo callsigns in data; applied on evolve in `GameState.gd` |
| **Task 12 — Normalize `eff` text** | **Done** | `audit_eff_text.py --apply` → 0 mismatches |
| **Facility fight 7 roster** | **Done** | Fight 7 order: Rust Drone → Heavy Warden → Rust Drone |
| **Trench Rig — Stabilize** | **Done** | Stabilize: ally-targeted 10 heal; Avalanche `pickerBlurb` updated |
| **Splice Medic — tier-1 kit** | **Done** | Zone reshuffle + Diagnostic/Infusion heals+rolls; Shock Therapy 20 dmg overload |
| **Splice Medic — Combat Medic evo tune** | **Done** | Triage, Suppression Heal, Surge Revive (70%) |
| **Splice Medic — Synth Warden evo tune** | **Done** | Overclock, Emergency Protocol, Adrenaline Surge, Mass Revival (30%) |
| **Guard — Bulwark Link (all allies shield)** | **Done** | `shieldAllyAll: true`, single squad-wide shield |
| **Resonance Cascade — relic copy** | **Done** | Clearer player-facing `desc` |
| **Reward ladder reference doc** | **Done** | `docs/reward-draft-rarity.md` |

**Facility fight 7 prompt:**
> In `battle-modes.json`, facility operation fight 7 enemies array: `[Rust Drone, Heavy Warden, Rust Drone]`. Validate with `npm run validate-data`.

**Trench Rig — Stabilize prompt:**
> Stabilize: `heal: 10`, `healTgt: true`, `eff: "10 heal (ally)"`. Avalanche evo `pickerBlurb`: replace “self-sustain” with “targeted ally heal” where Stabilize is referenced.

**Splice Medic tier-1 prompt:**
> Shock Therapy → **overload zone, 20 dmg** (or equivalent overload-tier entry). Neural Override → **surge** tier. Synaptic Overload → **crit** tier. Diagnostic Pulse → **3 heal (ally) + 1 roll** (`healTgt`, `rfmTgt`, positive `rfm`). Infusion → **7 heal (ally) + 2 roll** (same flags). Run `npm run validate-data` + ability audit.

**Splice Medic — Combat Medic evo tune prompt:**
> In `heroes.data.json`, `medic` → Combat Medic evolution entries only. **Triage** (recharge): **5 heal (ally)** only — `heal: 5`, `healTgt: true`, `eff: "5 heal (ally)"`. **Suppression Heal** (crit, rename from Surge Heal): **10 dmg + 8 heal all** — `name: "Suppression Heal"`, `dmg: 10`, `heal: 8`, `healAll: true`, `eff: "10 dmg, all 8 heal"`. **Surge Revive** (overload, rename from Mass Revival): **revive one friendly at 70% HP** — `name: "Surge Revive"`, remove dmg/healAll/blastAll; `revive: true`, `healTgt: true` (or target pick), **`revivePct: 70`** (new field — today combat hardcodes 50% in `combat_manager.gd`). Update `eff` text. Run `npm run validate-data` + ability audit.

**Splice Medic — Synth Warden evo tune prompt:**
> In `heroes.data.json`, `medic` → Synth Warden evolution entries only. **Overclock** (strike): **shield 4 only, 1 turn** — remove `heal`/`healAll`; `shield: 4`, `shT: 1`, `shieldAll: true`, `eff: "all 4 shield, 1t"`. **Emergency Protocol** (surge): **10 heal lowest** — `heal: 10`, `healLowest: true`, `eff: "lowest 10 heal"`. **Adrenaline Surge** (crit): **6 dmg all enemies + 6 heal all allies** — `dmg: 6`, `heal: 6`, `healAll: true`, `blastAll: true`, `eff: "6 dmg (all), all 6 heal"`. **Mass Revival** (overload, rename from Adrenaline Surge+): **revive all friendlies at 30% HP** — `name: "Mass Revival"`, remove dmg/healAll; **`reviveAll: true`**, **`revivePct: 30`** (new fields — backend follow-up in Combat section). `eff: "revive all 30%"`. Run `npm run validate-data` + ability audit.

**Guard — Bulwark Link prompt:**
> Guard Elite uses `guard` type. **Bulwark Link** today: `shield: 6` + `shieldAlly: 6` → combat shields **self + one other enemy**; UI shows **two** shield chips (6 + 6A). Change to **all living enemies** (includes caster): remove `shield`; keep `shieldAlly: 6`, `shT: 2`, add **`shieldAllyAll: true`**; `eff: "6 shield all allies, 2t"`. Model: `volt` **Grounding** recharge. UI: one chip / one icon row — see UI task **Enemy `shieldAllyAll` display**. Optional: same cleanup for `carapace` **Chitin Link** if intended identical. Validate + ability audit.

**Resonance Cascade — relic copy prompt:**
> `relics.data.json` → `resonanceCascade.desc`: replace with player-facing line like **“DoTs on enemies tick for +2 damage.”** Effect unchanged (`dotAmplified`, `bonus: 2`). Optional: align reward-screen chip tooltip if it still says generic “+2 DOT”. Run `npm run validate-data`.

**Task 13 prompt (if revisiting copy from workbook):**
> Update picker blurbs in `heroes.data.json` from workbook `picker_blurb` column.

---

## UI

Scenes, layout, cards, feedback, audio, themes. **`feat/ui-redesign` / `codex/*` only** — not `fix/cleanup`.

| Item | Status | Scope |
|------|--------|-------|
| **Task 13 — Show picker blurbs on UnitSelect** | **After UI finalization** | Wire `UnitData.picker_blurb` into `home_screen.gd` detail panel — **blocked** until UnitSelect/detail chrome is locked |
| **Gear equip target — evolved name** | **Done** | Reward gear picker uses `GameState.get_run_unit_data()` + `battle_name()` |
| **Enemy `shieldAllyAll` display** | **Done** | Single `6·ALL` chip + ally tooltip in `battle_card_view.gd` / `ability_readout.gd` |
| **Ally roll buff visuals (green dice)** | **Done** | Positive `rfm` → green `roll_up` pip/text; enemy strip keeps yellow `roll_down` (`pixel_ui.gd`, `ability_readout.gd`, `compact_unit_card.gd`) |
| **Capped die for RFE (Option A)** | **Done** | Tray lands **effective** face once at settle; **raw** kept in roll dicts for crit/overload. Removed post-roll snap. |
| **Task 8 — Battle feedback / game feel** | **Tabbed** | Core primitives done (hit pause, lunge, shake, overload, death SFX). Remaining Tier 1–3 touches card layout — resume after UI chrome locks. |
| **Death SFX timing** | **Done** | Fatal `death` SFX at hit moment; skip lead/pause on kills; poison ticks own feedback group; `skip_feedback` wired |
| **Task 9 — Audio system** | **Done** | `AudioManager` wired; SFX tiers per `offline-bundle/AUDIO.md`, hooked to Task 8 events |
| **Incoming target indicators** | Open | Subtle readout of who each unit is targeting (enemy → hero intent) during player target pick — informs ally-target choices without heavy chrome |
| **HP preview — heal before damage (net damage)** | **Done (Jul 2026)** | Net-outcome projection model — single projected endpoint in resolution order, shield counterfactual in blue, `cur → net / max` label. All three handoff bugs fixed; DoT tick single-sourced from `combat_manager.get_expected_dot_tick()`. See `docs/AI_AGENT_GAME_REFERENCE.md` §9b. |
| **Ability target scope clarity (ALL vs ally vs self)** | **Done** | `resolve_ability_target_scope()` → **SELF** / **ALL** only (no **ALLY** badge — ally-targeted heals assumed); `blastAll` dmg shows **ALL** (Scorched Earth) |
| **Ability readout — bracket scope + superscript turns** | **Done** | `)value(` / `(value)` scope + superscript duration via `EffectPip` (`ability_readout.gd`, reward/card pips) |
| **Card proportion / readability** | Ongoing | Portrait vs HP vs status at 450×1000 — `compact_unit_card.gd`, `BATTLE_UI_V2_SPEC.md` §19 |
| **Reward / evolution visual consistency** | Ongoing | Shared header; polish pass |
| **V2 band geometry audit** | Dropped | Center uses **540px** not 432 by design (`battle_layout.gd`); no Task 3 pass needed |

**Optional UI follow-ups (not queued):** protocol footer chrome extract, help overlay extract.

**Ally roll buff visuals prompt:**
> On ability readouts and status pips: if the effect is a **positive ally-targeted roll shift** (`rfm` > 0 + `rfmTgt`, or combined heal+roll on same ally target), use **green** dice art and **green** label color (`roll_up` / protocol green). Reserve yellow/`roll_down` for enemy roll strip and negative RFE on heroes.

**Gear equip target — evolved name prompt:**
> When claiming **gear** on the reward screen (`EQUIP … TO` overlay + inline gear picker), unit buttons use `DataManager.get_unit()` → always **base** name (e.g. Splice Medic). Battle already uses `GameState.get_run_unit_data()` in `_build_runtime_units()`. Replace with `get_run_unit_data(unit_id)` for labels; use `display_name` (evolved kit name, e.g. Combat Medic) or `battle_name()` (callsign) — match battle card convention. Also fix `_build_reward_result_text` “equipped to %s”. Audit `home_screen.gd` squad display if same bug appears outside rewards.

**Enemy `shieldAllyAll` display prompt:**
> When `shieldAllyAll: true`, show one shield pip + label like **“6 · ALL”** or **“all allies”** in tooltip — not `6` + `6A`. Match Volt Grounding pattern after Bulwark Link data fix.

**Ability target scope clarity prompt:**
> **Problem:** Same-looking chips hide scope — e.g. `healAll` vs `healTgt`, or enemy `shield` + `shieldAlly` showing two icons when intent is squad-wide **ALL**.
>
> **Pinned display vocabulary** (compact card + ability readout + `eff` text):
> | Label | Meaning |
> |-------|---------|
> | **SELF** | Caster only |
> | **ALLY** | One targeted ally (player pick, lowest, etc.) |
> | **ALL** | Caster **and** every living friendly on their side (`healAll`, `shieldAll`, `shieldAllyAll`, `erbAll`, squad roll buff without `rfmTgt`) |
>
> **Do not add:** `OTHERS`, `ALL·FOE`, or extra enemy-specific scope names. Abilities that hit **all enemies** are already obvious from **damage** / debuff chips — no separate target badge needed for foe-wide hits.
>
> **UI work:** One target badge per ability row when scope is SELF / ALLY / ALL (`battle_card_view.gd`, `ability_readout.gd`, chip tooltips). Drop bare **A** suffix — use **ally** vs **all** in copy. **`eff` strings:** `8 heal ally` · `13 heal all` · `6 shield all 2t` per `GROUND_TRUTH.md`.
>
> **Data pass:** Fix abilities that should be **ALL** but use split keywords (e.g. Bulwark Link → `shieldAllyAll`; see Guard task). No “others only” keyword unless combat gains one later.

**Ability readout — bracket scope + superscript turns prompt (done):**
> Implemented in `scripts/ui/effect_pip.gd` — `)value(` all, `(value)` self, plain single-target; duration as colored superscript. See `docs/EFFECT_PIP_GUIDE.md`.

**Capped die (Option A) prompt:**
> Today: tray rolls raw face, then `snap_die_to_effective_face` in feedback — feels like a double roll. **Option A:** at spawn/resolve, pick effective result once: `randi_range(1, min(20, 20 - rfe + buff))`, land die on that face, store **raw** separately for crit/overload rules. Remove `_snap_dice_to_effective_results()` / snap pass. Coordinate with dice tray physics so one landing reads as the real roll.

**Death SFX timing prompt:**
> In `battle_feedback.gd`: play `death` at the **start** of fatal effect processing (`hp_after <= 0` on damage/poison), not in `_play_event_sfx` after visuals. Skip `ACTION_EFFECT_LEAD_TIME` for fatal groups; skip trailing hit-pause and `ACTION_FEEDBACK_PAUSE` after a kill. Track per-`target_id` so multi-hit kills don’t stack. Wire `skip_feedback` path in `battle_scene.gd` so auto-resolve still plays death.

**Incoming target indicators prompt:**
> During hero targeting, show low-key who each living enemy (and taunting/spite interactions) is aimed at — e.g. small target pip on cards, dim connector, or card subtitle. Must stay readable at 450×1000 without cluttering the pick phase.

**HP preview — damage / heal / DoT (Claude handoff):**
> **Status:** Tabbed for Claude. Overlay experiments **reverted** to last committed `compact_unit_card.gd` (228fe4b baseline). User playtest Jun 2026 — **three distinct bugs** still open.
>
> **Bug 1 — DoT sticks on units incorrectly**
> Poison/burn tick preview persists on cards when it should not (wrong unit, wrong turn, or after `poison_turns` hits 0). `compute_preview_for_unit()` gates on `poison > 0 && poison_turns > 0` — verify state at preview time vs `_tick_state` in `combat_manager.gd`; check preview not cleared on phase/card refresh (`clear_combat_preview`, `update_card_view`).
>
> **Bug 2 — `ALL` / `blastAll` damage not shown as incoming until manual target pick**
> Squad-wide enemy hits (and possibly hero `blastAll` outgoing) do not paint incoming damage on all affected cards until **one** hero completes a manual target assignment. Suspect: `include_hero_ability_previews` in `compute_preview_for_unit()` requires `has_player_target_assignment` or `PHASE_READY_TO_END` — may be gating previews that should be unconditional for `blastAll` / `healAll` / `shieldAll`. Enemy loop uses `e_blast or e_target == target_id` and should not need player picks; confirm `_assign_enemy_targets()` runs before targeting UI refresh and cards recompute on roll settle.
>
> **Bug 3 — Heals do not stack against incoming damage**
> When a hero heal targets a unit that already has enemy damage previewed, preview should apply **heal first, then subtract incoming damage** (heroes resolve before enemies; poison ticks after). Label math in `_update_hp_label_preview()` attempts this (`post_heal` → shield absorb → dmg → dot) but bar overlays in `_layout_preview_overlays()` still fight `_hp_chip` / `forecast_hp` — net HP label and bar segments disagree. Repro: enemy dmg on hero A → pick heal on A → expect single `cur → net / max`, not independent red + green slabs.
>
> **Earlier symptoms (still valid):** Splice Medic **Infusion** (+7) / **Diagnostic Pulse** (+3) — purple DoT segment left of heal, red `_hp_chip` over current HP, wrong net (e.g. `26 → 24 / 50` when heal should win). Mint heal extension rarely visible.
>
> **Root cause (suspected):** Two competing HP bar systems — (1) `_hp_fill` + `_hp_chip` forecast animation (`forecast_hp` vs `current_hp`); (2) `_preview_rect_*` overlays in `_layout_preview_overlays()`. Setting `forecast_hp` from net preview painted red over green; hiding chip in preview layout raced with `configure()` → `_refresh()` → `_set_hp_display()`.
>
> **Combat order to mirror:** Heroes resolve first — **heal lands, then enemy damage, then poison tick** (`combat_manager.gd`). `compute_preview_for_unit()` aggregates heal/dmg/dot separately but overlay placement doesn't reliably show one net outcome.
>
> **Suggested approach for Claude:** Pick **one** preview model — either extend overlays only (never touch `forecast_hp` during preview) **or** unify into a single “projected HP” fill. Hide `_hp_chip` whenever `_preview_effects` non-empty. Heal segment: distinct mint color **right of** current fill. When heal + DoT + dmg combine, single label `cur → net / max`. **Un-gate** `blastAll`/`healAll`/`shieldAll` previews from `has_player_target_assignment`. Clear DoT preview when tick won't fire this round.
>
> **Test matrix:** (1) poison on unit with 0 turns left — no purple preview; (2) enemy `blastAll` at start of targeting — all heroes show incoming dmg before any hero pick; (3) hero `blastAll` — all enemies show outgoing dmg before any hero pick; (4) enemy dmg on A + ally heal on A same round; (5) heal + poison tick + enemy dmg on same unit; (6) self-heal, `healTgt`, `healAll`.
>
> **Files:** `scripts/ui/compact_unit_card.gd` (`_layout_preview_overlays`, `_update_hp_label_preview`, `_set_hp_display`, `_hp_chip`), `scripts/battle/battle_card_view.gd` (`compute_preview_for_unit`, `update_card_view`), `scripts/battle/battle_scene.gd` (`has_player_target_assignment`, `_assign_enemy_targets`, card refresh during `PHASE_TARGETING`).

**Task 8 start prompt:**
> Implement Tier 1 from `ANIMATION.md` one primitive at a time — hit_pause, then attacker lunge. Test in auto-battle between each.

---

## Combat & systems

Backend code, sim fidelity, mechanics — **`fix/cleanup`**. Not data-only JSON, not visual chrome. **Pick up after UI merge.**

| Item | Status | Scope |
|------|--------|-------|
| **Evolution XP (D2)** | **Done** | Avg-roll + survival bonus model in `GameState.gd`; **one evolution per battle win** (extras deferred FIFO) |
| **Revive pct + revive all (medic evos)** | **Done** | `revivePct`, `reviveAll` in schema + `combat_manager.gd`; ability audit 82/82 |
| **Gear/relic ability audit regressions** | **Done** | 12 gear/relic handlers covered in `AbilityAuditRunner.tscn` |
| **Task 5 — Facility balance** | **Paused** | Sim tuning deferred until finalize pass. |

**Evolution XP (D2) — pinned design:**

| Rule | Detail |
|------|--------|
| **When** | One grant per hero per **battle win** |
| **Alive at win** | `battle_xp = 20 + round(avg_roll)` |
| **Dead at win** | `battle_xp = round(avg_roll)` only (no survival bonus) |
| **avg_roll** | Mean of **effective** d20 rolls that battle only (nudge/set/reroll applied); rounds where hero actually rolled |
| **Gate** | **100 XP** to evolve |
| **Timing** | First evo ~fight 3 for hot rollers, ~fight 4 for slower kits (emergent) |
| **Flow** | **One evolution per battle win** — if multiple heroes cross 100 XP on the same win, first evolves now; rest queue in `deferred_evolution_unit_ids` (FIFO over newly eligible) |

**Evolution XP prompt (implemented):**
> Track effective rolls per hero per battle in combat/battle flow. On win, `award_battle_xp()` uses D2 formula (`20 + round(avg_roll)` alive, `round(avg_roll)` dead). Queue one unit at ≥100 XP per win via `pending_evolution_unit_id`; defer extras to `deferred_evolution_unit_ids`.

**Static:** `python scripts/debug/audit_gear_relic_effects.py` — all gear/relic `effect.type` values in data have handlers.

**Runtime regressions** (`AbilityAuditRunner.tscn`): gear/relic handlers below — all pass.

| Effect | Item ID | Hook |
|--------|---------|------|
| `lifesteal` | blood_siphon | `_damage_state` gear lifesteal |
| `shieldPierce` | breach_tip | shield pierce on hero attacks |
| `allyDeathHealAll` | martyrdomProtocol | `_on_unit_killed` ally death |
| `firstAbilityEcho` | echo_matrix | `_apply_hero_ability` re-runs damage once |
| `healShieldBonus` | triage_gel | `_heal_state` when healer ≠ target |
| `protocolOnKill` | bounty_chip | `_on_unit_killed` + basic tier check |
| `protocolOnKillAny` | apex_collector | `_on_unit_killed` any kill |
| `critResolveTwice` | overloadLoop | `resolve_round` re-runs hero ability on raw 20 |
| `rewardsNoCommon` | curatedCache | `GameState._pick_random_item_id` |
| `protocolCarryover` | overflowBuffer | `GameState.save_protocol_carryover` |
| `battleStartConsumable` | fieldCache | `grant_battle_start_consumables` |
| `reviveNoPenalty` | mercyProtocol | `GameState.get_revive_hp_pct` → 100% |
| `lowHpSquadRollBuff` | emergencySignal | `_trigger_low_hp_squad_roll_buff` at 50% HP |
| `healGrantsShieldAll` | aegisField | `_heal_state` shields all allies |
| `protocolOnItemUse` | protocolOverride | `battle_scene._get_item_protocol_cost` → 0 |

---

## Completed (reference only)

| Item | Notes |
|------|-------|
| **Dice physics overhaul (Jul 2026)** | Hand-toss model, low flat launch, camera-matched sloped walls, engraved numerals, frozen-dice blocking verified by `DiceTrayPhysicsProbe.tscn` (regression gate) |
| **Portrait pipeline (Jul 2026)** | Defringe tool, composition-aware `PixelUI.cover_fit_portrait()`, Void Circlet portraits reconnected |
| **HP preview net-outcome model (Jul 2026)** | See UI table row; playtest-bug handoff closed |
| **Tutorial audit (Jul 2026)** | Dead protocol spotlight + wrong Set highlight fixed; `tutorial_smoke_test.gd` drives all 21 steps |
| **Dead-code purge (Jul 2026)** | ~2,400 lines: 44 dead funcs, 40 consts, 3 dead files, generated-icon folder; icon maps unified through PixelUI |
| **Architecture review (Jul 2026)** | `docs/ARCHITECTURE_REVIEW_JUL2026.md` — read before large refactors (sim-engine decision gates Task 5) |
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
| **Data batch (Jun 2026)** | Facility fight 7, medic/trench/guard/relic JSON; `revivePct`/`reviveAll` schema |
| **Evolution XP (D2)** | `GameState.gd` avg-roll grants; one evo per win + deferred queue |
| **Revive pct + reviveAll** | `combat_manager.gd`, targeting order, card/readout chips |
| **Death SFX timing** | `battle_feedback.gd` fatal moment + poison tick groups; `skip_feedback` path |
| **Gear/relic audit regressions** | 12 gear/relic handlers in `ability_audit.gd` |
| **Task 9 — Audio system** | `AudioManager` + SFX tiers per `AUDIO.md`, Task 8 hooks |
| **Ability readout — bracket scope + superscript** | `EffectPip` notation + superscript duration; `docs/EFFECT_PIP_GUIDE.md` |

---

## Parking lot

Ideas saved for later — **not prioritized, not in progress.** Pick up only when explicitly chosen.

### Task 14 — Enemy half-cards (4–5 enemies)

Compact enemy card mode when battle layout has 4–5 enemies — smaller/half-height enemy cards so the field fits at 450×1000.

**Why parked:** current 3-enemy layout is the priority; revisit when multi-enemy fights need dedicated layout work.

**Future prompt:**
> In `battle_layout.gd` + `compact_unit_card.gd`, add a half-card variant for enemy strip when `enemy_count >= 4`. Preserve readable HP, status, and portrait at preview scale.

### Task 7 — Rename `dot` → `burn` (lockstep code + data)

Pure rename, no mechanic change. Workbook/GROUND_TRUTH already use burn naming; game still uses `dot`/`poison` in code and data.

**Why parked:** large touch surface (combat_manager, DataManager, sim, audits, status UI); must be one session with no partial loads.

**Rename map (abbreviated):** data `dot`/`dT` → `burn`/`burnT`; items `enemyDot` → `enemyBurn`; gear/relic `dot*` → `burn*`; code `combat_manager.gd`, `DataManager.gd`, sim; UI status token → "Burning". Ability flavor names (Venom Nip, etc.) unchanged.

**Future prompt:**
> Pure rename, no behavior change. Grep all sites, code first then regenerate data from workbook in same pass. One battle to verify ticks.

### Design decisions

| Topic | Status | Notes |
|-------|--------|-------|
| **Facility full-clear target (D1)** | **Pinned** | 25–40% skilled full-clear in real play; flat sim ~1.7% is reference only |
| **Evolution XP (D2)** | **Done** | Avg-roll model, 100 XP gate, one evo per win + deferred queue |
| **Shield hero viability (D3)** | **Deferred** | Leave kit as-is until finalize + richer sim |
| **Synth Warden vs Combat Medic** | **In tune queue** | See Data → Synth Warden / Combat Medic evo tune (Jun 2026 playtest feedback) |
| **Sim expansion (items/protocol/relic)** | **Deferred** | No new sim tasks until later finalize pass |
| **Round 5 relic duplicate** | **Not an issue** | Relics only drop after fight 5; one relic per run |
| **Ability target scope (ALL vs ally vs self)** | **Pinned** | **SELF / ALLY / ALL** only — see UI task; no OTHERS or ALL·FOE labels |
| **Mark / vulnerable** | Not scheduled | `markNext` keyword — combat_manager + schema + sample abilities |
| **Sim — full protocol economy** | Dropped | `gainProtocol` charge pool sufficient for balance sims |
| **ARC electric status** | Not scheduled | Option A (force roll 1) vs B (zone bump) |
| **DoT naming** | Leaning burn | Task 7 — not scheduled |
| **Demo scope** | Open | All 5 ops vs facility-first |
| **Third evolution / stats (STR/DEX/INT)** | Far future | |
| **Wraith Engineer protocol efficiency** | Partial | Manipulation discounts; Overclocked generator done |

---

## Working rhythm

1. One prompt → diff → test in Godot (or sim for balance) → commit → next.
2. After any `data/raw/` edit: `npm run validate-data` + ability audit.
3. Reset to tag `baseline-fable-restart` if a refactor goes sideways.
4. **During UI redo:** design in chat + update this file; implementation waits for merge unless explicitly green-lit.
5. Backend/data → `fix/cleanup`. UI → `feat/ui-redesign` / `codex/*`.
