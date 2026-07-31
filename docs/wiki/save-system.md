# Save System & Cross-Run Progression

> Part of the [Overload Protocol wiki](INDEX.md). See also: [operations.md](operations.md), [heroes.md](heroes.md), [relics.md](relics.md), [beats-and-events.md](beats-and-events.md), [conventions.md](conventions.md).

## How it works

`SaveManager` autoload (`scripts/autoloads/SaveManager.gd`), persisting to `user://save.json` at `SAVE_VERSION := 1` (`SaveManager.gd:8-9`). Cross-run state ONLY — run state stays in `GameState`; persistent cross-run XP is out of scope by ruling (TRUTH §Out of scope).

**Headless rule:** `_disk_enabled = DisplayServer.get_name() != "headless"` (`SaveManager.gd:52-53`). Headless runs (sim / audits / CI) keep the profile in memory, never write disk (`save()`, `:155-157`), and **read as fully unlocked** (`_fully_unlocked_override`, `:318-331`) so any hero/op is exercisable — but `_evaluate_run_end_unlocks` deliberately guards on the raw unlock list (`_award_operation`), not the force-true query, so stored progression still advances correctly (`SaveManager.gd:255-259`).

### Schema, field by field (`default_data()`, `SaveManager.gd:57-83`)

| Field | Type / default | Written by | Meaning |
|---|---|---|---|
| `save_version` | `1` | always stamped on load | schema version; `_merge_loaded` heals older saves onto defaults (`:103-144`) |
| `tutorial_done` | `false` | `mark_tutorial_done()` — from `TutorialController._finish` (completing) or `main_menu._on_first_run_skip_pressed` (SKIP on the first-run choice overlay); one flag, two paths in (Kev 2026-07-21) | tutorial completed OR skipped at least once; read by `main_menu._on_begin_pressed` (unset → BEGIN raises the RUN TUTORIAL / SKIP question, either path continues into the squad picker) |
| `stats.runs_started` | `0` | `record_run_started()` (`:223`), from `GameState.start_run` — **skipped for tutorial runs** per [DECISIONS_RESOLVED #13](../DECISIONS_RESOLVED.md) (`GameState.gd:146-151`) | lifetime run count; feeds the rung-1 pity unlock |
| `stats.runs_won_by_op` | `{}` | `record_run_finished` on victory (`:238-242`) | op id → win count |
| `stats.best_clear` | `0` | `record_run_finished` (`:234`) | furthest battle REACHED in any run (defeat at b6 records 6) |
| `stats.best_clear_by_op` | `{}` | `record_run_finished` (`:235-237`) | per-op furthest battle reached |
| `stats.nat20s` | `0` | `record_nat20()` (`:410`) | lifetime natural 20s |
| `stats.deaths` | `0` | `record_hero_death()` (`:415`) | lifetime squad deaths |
| `unlocks.boss_relics` | `[]` | `unlock_boss_relic_for_op()` (`:426-434`) on first op win | boss relic ids available as Starting Directives |
| `unlocks.heroes` | `["combat","engineer","medic","pulse"]` (`STARTING_HEROES`, `:23`) | `_award_hero` (`:294`) | owned hero ids (legacy ids frozen per INVARIANTS #11) |
| `unlocks.operations` | `["facility"]` (`STARTING_OPERATIONS`, `:25`) | `_award_operation` (`:306`) | unlocked op ids |
| `unlocks.hero_ladder_rung` | `0` | `_evaluate_run_end_unlocks` (`:262-265`) | rungs climbed (0–4) |
| `unlocks.heroes_new` | `[]` | `_award_hero`; cleared by `acknowledge_hero()` (`:361-366`) on first squad add (`home_screen.gd:679`) | drives the NEW badge |
| `onboarding.primers_seen` | `[]` | `mark_primer_seen()` (`:190-197`), only after a primer displayed AND was dismissed (`keyword_primer.gd:236`) | one-shot keyword primer ids |
| `settings` | `{}` | loaded wholesale (`:124-125`) | reserved (audio etc.) |

### Run-end evaluation (`record_run_finished`, `SaveManager.gd:232-244`)

Called once per run end via `GameState.finish_run(result)` (`GameState.gd:893-896`, call sites in `battle_scene.gd`). Order: best-clear stats → on victory: win count + boss relic unlock → `_evaluate_run_end_unlocks` → save.

- **Operation chain** (`OPERATION_CHAIN`, `:30`): facility → hive → veil → voidCirclet → stellarMenagerie. A boss clear unlocks the next link, uncapped and independent of the hero ladder (`:255-259`).
- **Hero ladder** (`HERO_LADDER`, `:33`): at most ONE rung per run end; only the NEXT rung is checked, so overshoot defers to later runs (mirrors the evolution "one progression stop per win" rule) (`:260-265`). Conditions in `_hero_rung_satisfied` (`:269-284`):

| Rung | Hero | Condition | UI hint (`HERO_UNLOCK_HINT`, `:37-43`) |
|---|---|---|---|
| 1 | `avalanche` (Avalanche Suit) | facility best_clear ≥ 6 OR runs_started ≥ 3 (pity; real runs only per #13) | REACH BATTLE 6 |
| 2 | `shield` (Spike Guard) | facility won | CLEAR FACILITY SWEEP |
| 3 | `ghost` | hive won | CLEAR THE HIVE |
| 4 | `breaker` | veil best_clear ≥ 6 | REACH BATTLE 6 IN THE VEIL |

  NOTE: the hint API (`hero_unlock_hint` / `operation_unlock_hint`, `:348-357`) has **zero callers** — locked heroes/ops deliberately render `[ LOCKED ]` with no hint (`home_screen.gd:599-613, 724-727`; TRUTH §Save system). Dead code, finding F-meta-06.

- **Boss relics** (`BOSS_RELIC_BY_OP`, `:13-19`): facility→salvageRig, hive→chitinGraft, veil→resonantChorus, voidCirclet→rootAccess, stellarMenagerie→mantleCore. Offered as Starting Directives at DEPLOY (`home_screen.gd:819-906` → `GameState.set_starting_directive`, `GameState.gd:733-738`); excluded from normal relic drafts.
- `check_new_unlocks()` (`:370`) hands this run's awards to the run-end UNLOCKED panel (`run_end_screen.gd:107-126`); `_run_end_unlocks` is in-memory only.

### Grandfather clauses (`_merge_loaded`, `SaveManager.gd:103-144`)

1. **Unlock schema:** a loaded save WITHOUT `unlocks.heroes` that shows play (runs_started > 0 or tutorial_done) gets everything — all heroes, full op chain, ladder maxed (`:134-139`). No current player loses access. Every loaded profile also gains Pulse Tech; its rung is recomputed from its actual owned heroes under the four-rung ladder, never copied from the old numeric meaning.
2. **Primers:** a played profile WITHOUT an `onboarding` block starts with every CURRENT primer id marked seen (`:143-144`); ids are read straight from `data/raw/primers.data.json` (`_all_primer_ids`, `:171-181`) to avoid a cross-autoload init dependency on DataManager.
3. **Tutorial runs_started:** profiles that banked tutorial runs before #13 keep the count — no retroactive adjustment (ruling text in DECISIONS_RESOLVED #13).

### Dev tools (help menu SETTINGS)

- `dev_unlock_all()` (`:391-400`) — all heroes/ops/boss relics, ladder maxed.
- `dev_reset_profile()` (`:404-407`) — full first-launch wipe, stats included (two-step confirm in UI).
- `dev_reset_primers()` (`:201-203`) — clears `primers_seen` only.

### Consumer surfaces

- `home_screen.gd`: all five ops stay browsable; locked ops show their own dark boss art, real name, and `LOCKED`, while hiding their blurb and keeping DEPLOY disabled. All eight hero cards stay in the roster; locked cards use each hero's own dark silhouette, real name, and `LOCKED`, and cannot be selected or inspected. NEW badge remains until first squad add.
- `run_end_screen.gd`: SERVICE RECORD section renders lifetime stats (`_service_record_text`, `:55-67`); UNLOCKED panel from `check_new_unlocks`.
- `keyword_primer.gd`: `is_primer_seen` gates queuing (`:170`); max one primer/turn; suppressed in tutorial/headless/auto battle; failure paths never mark seen.

## Why it works that way

- One rung per run end paces the roster reveal like the evolution stop paces power (comment at `SaveManager.gd:260-261`).
- Headless full-unlock keeps sim/audit coverage total without polluting a developer's real save (file header, `:4-5`).
- Merge-onto-defaults means schema growth never needs a migration table — absent keys heal, present keys survive.
- Locked content exposes identity, not progression details: hero cards show their real names and operation cards show only their real names, but neither exposes unlock conditions, kits, bosses, rewards, descriptions, or detailed mechanics. The unused hint constants remain outside the player path.

## What it replaced

- GROUND_TRUTH marked cross-run unlocks "out of scope"; the hero ladder + operation chain shipped anyway (TRUTH adjudication table) — persistent XP remains out of scope.
- Tutorial runs used to increment `runs_started` and feed the pity rung; removed per DECISIONS_RESOLVED #13 (grandfathered).
- Pre-primer saves predate `onboarding`; the primer grandfather (2026-07) marks all current primers seen for veterans.

## File locations

- `scripts/autoloads/SaveManager.gd` — everything above
- `scripts/autoloads/GameState.gd` — `start_run`/`finish_run` call seams
- `scripts/ui/home_screen.gd`, `scripts/ui/run_end_screen.gd` — unlock UI
- `scripts/ui/keyword_primer.gd`, `data/raw/primers.data.json`, `docs/PRIMERS.md`
- `scripts/ui/tutorial_controller.gd` — `mark_tutorial_done`

## Known edge cases

- `best_clear` records the battle REACHED on defeat (dying in b6 still satisfies "REACH BATTLE 6" rungs) — consistent with the hint wording.
- Victory always records `battle_reached = 10` (finish fires on the final battle number).
- A malformed save file logs a warning and starts fresh — it is NOT overwritten until the next `save()` call.
- `heroes_new` has no headless override; irrelevant since badges are UI-only.
- Winning an op out of chain order still unlocks only its own next link (`_next_operation`, `:287-291`).
- Every stat write saves immediately (`record_nat20`/`record_hero_death` fire mid-battle) — small synchronous JSON writes.

## ⚠ Open findings

<!-- AUDIT-LINKS:save-system -->
- [A-085](../audit/INTERACTION_AUDIT.md#a-085) - [dead] unlock-hint API contradicts the no-hints doctrine
