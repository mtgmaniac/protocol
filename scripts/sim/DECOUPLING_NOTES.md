# DECOUPLING NOTES — Balance Sim, Package A.1

*Combat/UI decoupling audit for the headless balance simulator. This is the map + the fix plan for making a battle resolve synchronously with zero scene-tree UI, reusing the real `combat_manager.gd` rules engine.*

## The two laws (repeated so they are never forgotten here)

1. **ONE RULES ENGINE.** The sim runs the real `combat_manager` headless. No game rule is ever reimplemented in sim code. Where a rule currently lives in `battle_scene.gd` (a UI object), the fix is **extraction into a UI-free module both `battle_scene` and the sim call** — never duplication.
2. **DETERMINISM OR IT DIDN'T HAPPEN.** Same seed + same config → byte-identical JSONL. This requires *every* RNG source to be seeded (see §4).

---

## 1. Headline finding

`combat_manager.gd` (2371 lines, `class_name CombatManager extends RefCounted`) is **already a pure, synchronous rules engine**:

- Zero `await`, `create_tween`, `Timer`, `create_timer`, `emit_signal`, or `signal` in the whole file (grep confirmed: 0 occurrences).
- It **takes rolls as inputs** — `resolve_round(hero_rolls, enemy_rolls, dice_manager, raw_enemy_rolls, raw_hero_rolls)` — and never calls the d20 RNG itself. The only RNG it touches is not present; `DiceManager.roll_d20()` is called by the *caller*.
- It returns an event/log stream: `{ "result": "victory"|"defeat"|"ongoing", "log": [...], "events": [...] }`. The UI consumes `events`/`log`; combat truth does not depend on rendering.
- Item effects are already pure methods on it (`apply_item_heal`, `apply_item_shield`, `apply_item_damage`, `apply_item_revive`, `apply_item_rfe`, `apply_item_burn`, `apply_item_mark`, `apply_item_ward`, `apply_item_roll_buff`, …).
- Between-battle run flow (comps, beats, intercepts, rewards, evolution, XP, directives) already lives in `GameState.gd` (autoload, no UI), driven by the same functions the reward/evolution/fork/intercept **screens** call.

**Therefore the sim does not instantiate `battle_scene` at all.** It builds a thin UI-free orchestrator (`BattleEngine`, below) that calls the same `CombatManager` + `GameState` + `DataManager` public API that `battle_scene` calls, and a policy layer supplies the choices a human currently makes by clicking (targets, protocol spends, item use, drafts).

The entire coupling problem is concentrated in **`battle_scene.gd` (3377 lines)**: it owns the turn/phase state machine, roll sourcing, the protocol economy, targeting selection, item usage UI, and — critically — a handful of *game rules* that are not in `combat_manager`. Those rules are the only thing standing between us and the one-rules-engine law.

---

## 2. Rules that currently live in `battle_scene.gd` (MUST be extracted, never duplicated)

These are pure combat/economy rules entangled with UI phases in `battle_scene.gd`. The sim needs all of them; reimplementing any is a law-1 violation. Extraction target: a new UI-free class **`BattleEngine`** (see §5).

| Rule | `battle_scene.gd` location | What it does | Fix |
|---|---|---|---|
| **Protocol pool** (`protocol_points`) | var @76; income @909–922; cap `_max_protocol()` @1899–1913 | int pool, start 0 + carryover, `+1`/turn (blackout/`_income_debt` exceptions), cap 10 or `run_protocol_cap_override` or Deep Cells `protocolCapBonus` +2 | Move pool + income + cap into `BattleEngine`; `_max_protocol` reads `combat_manager.get_hero_states()` for the directive, keep that read |
| **Nudge = +3 to effective roll** | `_apply_nudge` @1318–1350; cost `_get_nudge_cost` (Priming Charge `firstNudgeFree`); applied @1803–1804 | stores `hero_roll_nudges[id]=3`; `clampi(base_eff + nudge, 1, 20)` | Extract into engine's effective-roll pipeline |
| **Set-a-die = absolute value** | `_apply_set` @1428+; cost `_get_set_cost` (Root Access `setCostZeroOncePerBattle`); applied @1798–1799 | stores `hero_roll_sets[id]=value`; overrides nudge; `clampi(value,1,20)` trumps everything | Extract into engine's effective-roll pipeline |
| **Reroll = fresh d20 + overwrite** | `_apply_reroll` @1153–1162 | `protocol_points -= 2`; `hero_rolls[id] = dice_manager.roll_d20()`; clears nudge/set | Extract; the d20 draw goes through **RollProvider** (A.2) |
| **Effective-roll pipeline** | `_build_effective_rolls()` / `_get_effective_roll_for_state()` @1793–1804 | combines set/nudge with `combat_manager.get_effective_roll(state, raw)` | Extract as `BattleEngine.effective_roll_for(state, raw)` — thin wrapper over the CM call + set/nudge |
| **Frozen-roll overrides** | `_apply_frozen_roll_overrides` @667–677 | if `die_freeze_turns>0`, force `frozen_die_value` into the rolls dict | Extract into engine roll build |
| **Protocol drain / grants plumbing** | @857 `take_pending_protocol_grants`, @861–865 `take_pending_protocol_drain` | applies CM's pending protocol to the pool (floor 0) | Extract (calls stay on CM; only the pool write moves) |
| **Overflow Vent** | `_gain_protocol` @1168–1187 | protocol over cap → `combat_manager.apply_item_damage(random_enemy, 2)`; uses `randi()` | Extract; the random pick goes through **RollProvider/seeded RNG** |
| **Inline item effects NOT on CM** | `_apply_item_effect` @3212–3318 | `cloak`/`cloakAll` (direct `state["cloaked"]=true`), `enemyRerollDie`/`enemyRerollAll` (`roll_d20()` → `enemy_rolls`), `enemyDieFreeze`/`enemyDieFreezeAll` (set `die_freeze_turns`/`frozen_die_value`), `gainProtocol` | Extract; ideally push cloak/freeze/reroll item handlers **down into `combat_manager`** as `apply_item_*` methods for symmetry, then both callers use CM |
| **Item protocol cost** | `_get_item_protocol_cost` @2939–2951 | 0 (Protocol Override / Supply Drone), 2 (Sealed Supplies), else 1 | Extract into engine |
| **Protocol carryover persist** | `_persist_protocol_carryover` @955 → `GameState.save_protocol_carryover` | saves unspent × carry_pct for next battle | Extract (calls GameState) |

Everything else in `battle_scene.gd` (dice tray, feedback, card building, targeting *UI*, item *menu*, tutorial emission, log rendering) is presentation and stays put.

---

## 3. `battle_scene.gd` → `combat_manager` call map (the wiring the engine replicates)

Ordered as a battle actually runs. Line refs are `battle_scene.gd`.

**Battle setup** (@178–188):
`setup_battle(hero_units, enemy_units)` · `setup_relics(GameState.relics)` · `setup_gear(GameState.gear_by_unit)` · `apply_battle_start_relic_effects(battle_index)` · `apply_battle_start_gear_effects()`. Also `setup_battle_modifier(mod, warded)` @194 and `set_decoy_round_one()` @1211 when armed.

**Per round:**
1. Source rolls — visual path @497–501 (`dice_tray_3d.play_rolls` → `await roll_finished` → `get_hero_rolls`/`get_enemy_rolls`); **headless fallback already exists** @505–508 `_roll_for_states()` → `dice_manager.roll_d20()` @611.
2. `_apply_frozen_roll_overrides()` @667–677.
3. Targeting: auto (`_assign_enemy_targets` @2297, `_prepare_hero_targets`/`_auto_assign_hero_target` @2312–2444) or manual (writes `state["selected_target_id"]` via `_set_state_target` @2668).
4. Protocol spends (optional, player/policy): nudge/set/reroll/item as in §2.
5. `_build_effective_rolls()` → `eff_hero_rolls`, `eff_enemy_rolls` (set/nudge applied); `raw_*` kept for crit/overload.
6. `combat_manager.resolve_round(eff_hero, eff_enemy, dice_manager, raw_enemy, raw_hero)` @837–843.
7. Drain pending protocol: `take_pending_protocol_grants()` @857, `take_pending_protocol_drain()` @861 → pool.
8. Outcome branch @881–922: victory/defeat handoff (§ below) or income `+1` + `_round_number += 1` + loop.

**Targeting handoff detail:** the field is **`state["selected_target_id"]`** (combat-side default `""` in `_create_runtime_state` @combat_manager:604). Enemies **auto-target internally** inside `_apply_enemy_ability` (reads `ai`/`selected_target_id` it set itself) — so **the policy layer only ever supplies HERO targets.** `target_display` is UI-only.

**Victory/defeat handoff** (@881–905): `_persist_protocol_carryover()` · `_capture_battle_victory_for_xp()` (→ `GameState.capture_battle_end_survival`, `record_battle_hero_deaths`) · then either `GameState.finish_run("victory"/"defeat")` + `SceneManager.go_to_run_end()`, or `GameState.prepare_battle_rewards()` + `SceneManager.go_to_reward_screen()`. In the sim these become direct `GameState` calls + the policy layer; **no SceneManager, no scenes.**

**Item usage:** menu → `_on_item_button_pressed(item)` @3017 → phase pick (ally/enemy/none) → target tap → `_apply_item_effect(item, target_state)` @3212 (delegates to `combat_manager.apply_item_*` except the inline cases in §2) → `_consume_item` @3331 (`GameState.consumables.remove_at`).

---

## 4. Determinism: the RNG streams that must be seeded

For byte-identical JSONL, **all** randomness must derive from the run seed. There are exactly these sources:

| Stream | Where | Current source | Sim fix |
|---|---|---|---|
| **d20 rolls** (hero + enemy, per round) | `DiceManager.roll_d20()` → global `randi_range(1,20)` | global RNG; in the *game* the value comes from the physics tray, `roll_d20` is the headless fallback | **RollProvider** (A.2): `SeededRollProvider` draws uniform 1–20 from a per-run `RandomNumberGenerator`. Physics is presentation only — the sim never runs physics. |
| **Reroll / enemy-reroll items / Overflow Vent random enemy** | `roll_d20()` and `randi()` in `battle_scene` | global RNG | Same seeded stream via the extracted engine + RollProvider |
| **Drafts / beats / comps / rewards / relics / intercept shuffle** | `GameState._reward_rng: RandomNumberGenerator` (@97) | `_reward_rng.randomize()` in `start_run` (@102) | Sim seeds `_reward_rng.seed = <derived>` deterministically instead of randomize |

**Assumption (documented per A.2):** physics dice are presentation; the sim models rolls as **uniform d20**. The game's physics-derived value is *also* effectively uniform (the tray just animates to a `roll_d20()` result in the headless fallback and to a settled face otherwise), so the sim's uniform model is the faithful abstraction. `# SIM-TODO(kev)`: confirm the physics tray reports a uniform face distribution (not physics-biased) if we ever want the sim to match live-play roll stats exactly; for balance purposes uniform is the correct model.

Seed derivation plan: one master seed → derive `_reward_rng` seed and the RollProvider seed as fixed offsets (e.g. `seed` and `seed ^ 0x9E3779B9`) so the two streams are independent but reproducible. Never call `randomize()` anywhere in the sim path.

---

## 5. Target harness architecture

```
scripts/sim/
  DECOUPLING_NOTES.md      (this file)
  roll_provider.gd         A.2  RollProvider interface + PhysicsRollProvider + SeededRollProvider
  battle_engine.gd         A.1  BattleEngine — UI-free per-battle orchestrator (owns protocol pool,
                                 effective-roll pipeline, spend rules, calls CombatManager.resolve_round)
  sim_runner.gd            A.3  SceneTree entry: parse args → drive GameState run + BattleEngine battles
                                 via the policy layer → write JSONL
  policies/                B    PlayerPolicy interface, L0 (random), L1 (greedy), L2 (solver, D)
  telemetry.gd             B.1  JSONL event emitter (schema in telemetry_schema.md)
```

**`BattleEngine`** (the A.1 extraction target) is the shared brain. Both consumers use it:

- **`battle_scene.gd`** constructs a `BattleEngine`, feeds it rolls from the dice tray + player spend/target choices, and **renders** its `events`. Its awaits/tweens/timers stay — they animate what the engine already decided.
- **`sim_runner`/`BattleRunner`** constructs a `BattleEngine` with a `SeededRollProvider`, asks the **policy** for spend/target choices, and resolves rounds in a tight synchronous loop (no tree, no waits).

This is exactly architecture-review §1.1 ("extract the protocol-spend subsystem") and §2 option (b) ("make GDScript the only engine, run balance sims headlessly"), finished.

**`RollProvider` (A.2)** — the roll seam:
```
class_name RollProvider (RefCounted)
  roll_d20() -> int
  # Freeze/Jam/Rewrite/Hijack operate on roll VALUES + reveal-skips (already in
  # combat_manager / battle_scene), NOT on physics, so they are identical under
  # both providers.
PhysicsRollProvider — wraps the tray (game); or, headless-fallback, wraps DiceManager.roll_d20()
SeededRollProvider  — RandomNumberGenerator.randi_range(1,20) from the run seed
```
`DiceManager.get_ability_for_roll()` / `get_adjusted_ranges()` are pure band lookups (no RNG) and stay as-is — the provider only replaces the *value source*, i.e. `roll_d20()`.

---

## 6. Synchronous headless path (awaits to bypass)

`battle_scene` already has the seams — the sim just never enters the visual branch. The awaits that must **not** exist on the sim path (all in `battle_scene.gd`, listed for completeness; the sim reimplements the loop in `BattleEngine` and simply omits them):

- @501 `await dice_tray_3d.roll_finished` — visual only; sim uses RollProvider.
- @874 `await _feedback.play_round_feedback(events)` — VFX/SFX; sim consumes `events` as data.
- @494/@496/@532/@604/@878 `await get_tree().process_frame` — layout sync.
- @588/@600 `await get_tree().create_timer(AUTO_TURN_TARGET_PAUSE)` — auto-target pacing.
- @1162 `await dice_tray_3d.reroll_die_to_result(...)` — reroll animation.
- @3137–3144 `create_timer(...).timeout.connect(...)` — item-card arming.

`battle_scene` retains all of these for real players; the extraction changes *wiring*, not behavior. Regression proof: the four gates + one manual battle after A.1.

---

## 7. Legacy JS sim to delete (Package A.5)

The "second rules engine" (architecture-review §2). All TypeScript, reference-only, deleted in A.5:

- `scripts/sim/*.ts` — `battle-progress-sim.lib.ts`, `consumable-sim.lib.ts`, `gear-sim.lib.ts`, `hero-ability-normalize.ts`, `models/` (4), `utils/` (2). *(Keep this dir; it becomes the GDScript sim home.)*
- `scripts/sim/README.md` — **rewrite** (E.2), don't just delete; today it describes the dead JS sim.
- `scripts/debug/balance_sim_*.ts` (8): `evo_fullclear`, `evo_only`, `facility`, `full_evo_team`, `gear_audit`, `item_audit`, `per_hero`, `roster_audit`.
- Update `AGENTS.md` §"Run & verify" + §"Data" and `docs/AI_AGENT_GAME_REFERENCE.md` which point at the `.ts` sims (E.3).

---

## 8. Verification gates (run after every game-code refactor)

- `npm run validate-data` (baseline: **passing** as of this audit).
- `AbilityAuditRunner.tscn` (105 checks) — run as a scene, not `--script`.
- `flow_smoke_test.gd`, `tutorial_smoke_test.gd`.
- `DiceTrayPhysicsProbe.tscn` (0/0/0).
- Godot: `C:\Users\Kev\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe` (4.6.2). Note: `--check-only`/headless quit misses parser errors outside the launched scene chain — always launch a runner and watch the console.

---

## 9. Extraction order (A.1 → A.2)

1. Add `scripts/sim/roll_provider.gd` (A.2 seam) first — smallest, isolated, lets the engine take a provider from day one.
2. Create `BattleEngine` and move the §2 rules into it **one cluster at a time**, re-pointing `battle_scene` at the engine after each so the gates stay green:
   a. Effective-roll pipeline (nudge/set/frozen overrides) + RollProvider-backed reroll.
   b. Protocol pool (income/cap/spend/drain/carryover/overflow).
   c. Per-round orchestration (`resolve_round` wrapper + pending-protocol plumbing).
   d. Inline item effects → prefer pushing down into `combat_manager` as `apply_item_*`.
3. Verify: full gate suite + one manual battle (nothing feels different).

`# SIM-TODO(kev)` markers flag any ambiguity taken at the smallest defensible interpretation; grep the sim tree for them.
