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

### 4a. Autoload-context requirement (discovered during A.2)

A bare `godot --headless --script foo.gd` (SceneTree) does **not** register the autoload *global identifiers* (`GameState`, `DataManager`, …) at script-compile time. Any script that compiles a dependency referencing those globals fails with `Identifier not found: GameState`. `combat_manager.gd` references `GameState.SQUAD_UNIT_LIMIT` and `DataManager`, and `DiceManager` references `GameState.gear_by_unit` — so **the sim harness cannot run as a bare `--script`; it must run in an autoload context.** Options, in order of preference:
- **Launch `sim_runner` via a tiny scene** (`res://scenes/debug/SimRunner.tscn` with a Node script), the same reason `AbilityAuditRunner.tscn` is a scene not a `--script` (per `AI_AGENT_GAME_REFERENCE.md` §14). CLI args still arrive via `OS.get_cmdline_user_args()`.
- Or keep a `--script` entry that accesses autoloads only via `/root/GameState` node paths + `.call()` and never statically compiles a GameState-global-referencing script at its own load — brittle; the scene route is cleaner.

`SeededRollProvider`/`RollProvider` are pure (no autoload deps) and verified deterministic under a bare `--script` (A.2 gate passed). `PhysicsRollProvider` pulls in `DiceManager`→`GameState` and is therefore only exercised in the autoload context.

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

## 9. Extraction order + progress (A.1 → A.2)

`BattleEngine` = `scripts/battle/battle_engine.gd` (RefCounted, UI-free). Boundary
chosen: **rules live once in the engine as methods; each caller owns its own
battle state (roll/nudge/set dicts, protocol pool int) and passes it in.**
battle_scene keeps its dicts (no churn to the 43 `hero_rolls` / 28
`protocol_points` sites) and delegates; the sim owns parallel state and calls the
same engine methods. Dictionaries pass by reference in GDScript, so engine
methods that mutate a passed dict mutate the caller's dict directly.

**Done (each: extract → re-point battle_scene → full gate suite → commit):**
- ✅ **A.2** RollProvider seam (`roll_provider` + seeded + physics; `roll_d20`,
  `rand_index`). Verified byte-deterministic.
- ✅ **Cluster 1 — effective-roll pipeline:** `effective_hero_roll`,
  `effective_enemy_roll`, `build_effective_rolls` (Set/freeze/Nudge shaping).
- ✅ **Cluster 2 — roll sourcing:** `roll_states` (via provider),
  `apply_frozen_roll_overrides`, `record_roll_values_for_states`,
  `roll_value_for_state`.
- ✅ **Cluster 3 — protocol economy:** `max_protocol` (cap 10 / run override /
  Deep Cells), `gain_protocol` (income + Overflow Vent via `rand_index`).

**Done (cont.):**
- ✅ **BattleState** — caller-owned roll/nudge/set/pool/spend-flag state in one
  container (`battle_state.gd`) with `duplicate_for_search()` for the L2 solver;
  battle_scene members are property forwarders to `_state`.
- ✅ **Cluster 4 — protocol spends:** `apply_reroll`, `nudge_cost`/`apply_nudge`
  (Priming Charge / Reverse Gimbal), `set_cost`/`apply_set` (Root Access),
  `twin_fates_copy`. Gear-effect lookups passed in as booleans.
- ✅ **Cluster 5 — inline item effects:** `item_protocol_cost`, `item_cloak`/
  `item_cloak_all`, `item_enemy_reroll`/`_all` (via provider), `item_enemy_freeze`/
  `_all`. battle_scene keeps the effect dispatch + logging.
- ✅ **Cluster 6 — per-round resolution:** `BattleEngine.resolve_step(bs)` — the
  one round loop both the live screen and the sim run.

**Package A COMPLETE** (A.1–A.5):
- ✅ **A.3** `scenes/sim/sim_main.tscn` + `scripts/sim/sim_runner.gd` — full run,
  zero UI, byte-deterministic. Stub policy (auto-target first enemy via
  combat_manager fallback; drafts option 0; beats consumed w/o effects — SIM-TODOs).
- ✅ **A.4** `--bench N` → ~40,000 battles/min single-worker (target ≥1,000).
- ✅ **A.5** `tests/sim_determinism.sh`; legacy JS sim deleted.
- ⚠️ The human "play one manual battle, confirm nothing feels different" check is
  the one Package-A item that can't be automated — pending Kev.

**Package B COMPLETE** (built B.1 → B.4 → B.2 → B.3 — L0 random play is the
cheapest full exercise of the telemetry pipeline, and the replay printer had
to exist before anyone debugged L1):
- ✅ **B.1** telemetry schema (`telemetry_schema.md`, schema_version 1) +
  `SimTelemetry` emitter; `sim_runner` emits run_header / battle_start / round
  (raw+eff rolls both sides, spends, verbatim event stream, HP + protocol) /
  battle_end / draft / beat / progression / run_end.
- ✅ **B.4** replay printer (`replay.py`, stdlib-only): renders a run as
  readable narration; `--battle N` / `--summary`.
- ✅ **B.2** PlayerPolicy seam (`policies/player_policy.gd` = the old stub) +
  `PolicyL0Random`. Third seeded RNG stream (`seed ^ 0x51F15EED`). **All four
  A.3 SIM-TODOs cleared:** real drafts (policy → claim_reward), beat effects
  (fork roll+accept / intercept draw→choice→picks→in-card draft→apply), and
  blackout/income-debt + full battle-start setup extracted into BattleEngine
  (`end_of_round_income`, `apply_battle_start_external_effects`,
  `gear_start_protocol`) — battle_scene delegates, one rule set.
- ✅ **B.3** `PolicyL1Greedy` — focus fire + band-aware protocol spends
  (reroll ≤4, nudge only when +3 crosses a band, Set-20 when flush), rarity
  drafts, always-flag forks, scored intercept choices. Sanity baseline holds:
  L1 beat L0 58 vs 39 battles cleared over 6 facility seeds.
- Determinism gate (`tests/sim_determinism.sh`) now runs stub/l0/l1 — all
  byte-identical.

**Package C COMPLETE** (orchestration + analysis):
- ✅ `sim_runner --grant id[@unit],...` — forced content at run start for
  Stage-2 arms (relic/gear/consumable routed like claim_reward, recorded in
  the run header as `granted`). Documented caveat: granted from battle 1.
- ✅ `scripts/sim/batch.py` — parallel Godot workers (ThreadPoolExecutor),
  uniform-random squad/op per run (seeded from seed-base → reproducible),
  `results/<name>/` + `manifest.json`. ~740 runs/min at 8 workers.
- ✅ `scripts/sim/analyze.py` (pandas/statsmodels/scipy — `requirements.txt`):
  per-run aggregation from JSONL; descriptive tables (hero inclusion-adjusted
  clear rate, op clear rate, protocol spend distribution + win-corr, keyword
  realized value, enemy damage-per-appearance); Stage-1 **ridge** logistic
  (`fit_regularized`, α=2) with **bootstrap** CIs over exogenous/acquired
  content only (evo/dir dropped as survival-confounded → descriptive pick-rate
  table); Stage-2 `--ab treat ctrl` matched-seed two-proportion z-test.
- **First outlier (600-run L1 screen):** `hero__avalanche` +2.86 log-odds
  [+2.38, +3.55] (84% clear vs ~45% squad-wide) — Avalanche squad is the
  standout. Modest positive gear lifts (echo_matrix, ignition_coil, …).
- **Sim-discovered combat bug fixed en route:** Detonate vs a permanent
  (plagueProtocol 9999t) burn dealt burn×9999 ≈ 30k–120k. Capped at
  `DETONATE_MAX_TURNS` (6 = max authored +1); audit case added; DESIGN-TODO(kev)
  on the intended permanent-burn burst value.

Ridge-not-MLE + bootstrap CIs matter: plain `Logit.fit()` hit quasi-separation
on the sparse content one-hots and returned ±2e6 CIs; ridge stabilizes and the
bootstrap gives honest intervals. Stage-1 is a SCREEN; Stage-2 arms are causal
(e.g. coldLogic on an Avalanche squad: naive +0.44 lift, matched-arm +4.7%
n.s. at 150 runs — the confound the prompt names, correctly deflated).

**Package D COMPLETE** (L2 solver + archetypes + skill band + consumable use):
- ✅ **L2 exact round solver** (`policies/policy_l2_solver.gd`): searches
  (hero order × target assignment × spend plan) by snapshot → resolve → score
  → restore on the real combat_manager (`snapshot_state`/`restore_state`/
  `set_hero_order` added). One-round eval = enemy HP removed + kills − hero HP
  lost − hero deaths ± result. Global RNG reseeded per-decision (only L2) so
  candidates score consistently and runs reproduce. Reroll excluded (draws the
  provider). ~1.7s/run.
- ✅ **Skill band** (`analyze.py --skillband LOW HIGH`): L1↔L2 clear-rate gap
  per op. 80-seed sample: L1 50% → L2 85%; per-op +18% (facility) to +57%
  (veil). Both above the GDD 25–40% / 55–70% band — a calibration finding.
- ✅ **Consumable use** (the last B-deferred SIM-TODO): dispatch extracted to
  `BattleEngine.apply_consumable_effect` (battle_scene + sim share it);
  `PlayerPolicy.decide_items` triage hook on L1/L2; runner applies + records
  `kind:item` spends. Consumable lift is now measurable.
- ✅ **Archetype drafters** (`--archetype burn|control|protocol|value`):
  data-driven affinity on item effect.type biases choose_draft /
  choose_intercept_draft; ties fall back to L1 rarity. Layered on L1/L2
  (`describe()` → `l1_burn` etc.). Answers "is X OP in the build that wants
  it." Verified: control drafter picks corrosion_bomb/cascade_jammer the value
  drafter skips.

**Sim-discovered fix en route:** Detonate vs a permanent burn (see the Package
C note) — the sim's first real combat bug, caught by L0/L1 telemetry.

**Next: Package E** (CI hook — nightly smoke + balance-report baseline diff),
with the determinism gate.

`# SIM-TODO(kev)` markers flag any ambiguity taken at the smallest defensible interpretation; grep the sim tree for them.

## 10. Notes for whoever continues

- **Dice physics probe is non-deterministic:** `flyover_events` measured 2, 0, 0
  across three identical runs on an unchanged tree. It passes 0/0/0 on clean
  runs but is not a strict gate as-is (unseeded physics RNG). Not caused by the
  extraction — `DiceTrayPhysicsProbe.tscn` doesn't load battle_scene/battle_engine.
  Worth seeding the probe's RNG for a real 0/0/0 contract (out of scope here).
- **Gate note:** the ability audit instantiates `battle_scene` **bare (out of
  tree)** for regression checks (e.g. Overflow Vent), so anything battle_scene
  creates at member-init (now including `_engine` + `PhysicsRollProvider`) must
  be safe outside the tree. It is. `_max_protocol` keeps its `is_inside_tree()`
  guard in battle_scene and passes the cap override into the pure engine.
