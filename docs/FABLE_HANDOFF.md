# Fable Handoff — Combat/Data Keyword Batch

Execution guide for the combat/data tasks (3, 4, 5, 7, 8, 9). The **canonical
per-task requirements** are in Kev's task list (paste alongside this). This doc
adds the codebase-specific **order, dependencies, traps, and verification gates**
that the task text doesn't spell out.

## Status coming in
- **Task 1 (unlock system)** and **Task 6 (shield/pierce/breach copy)** are DONE and
  verified in the working tree — do not redo. `keywords.data.json` shield/pierce/breach
  defs are already corrected.
- **Task 2 (keyword primer)** is a separate large feature, NOT in this batch. It's
  unblocked by Task 1 (SaveManager has room for an `onboarding.primers_seen` key and a
  3rd "RESET PRIMERS (DEV)" dev button slot in help_menu SETTINGS). Do it in its own
  session, not mixed with this batch.

## Do it as ONE batch, in this order (Kev approved batching + you owning the baseline)
1. **Task 3 — hijack placement** (`data/raw/enemies.data.json`)
2. **Task 8 — Ward→Firewall rename + cull 17→10**  ← **AFTER 3** (Glimmer "Afterimage" becomes hijack in 3, then its firewall/ward is culled in 8)
3. **Task 5 — jam cap 12→10**
4. **Task 7 — cloak simplify** (remove pierce-from-cloak)
5. **Tasks 4 + 9 TOGETHER** — taunt/lure unify folded into the new targeting choke-point

Run `validate-data` + ability audit after each step; run the full gate (incl. sim) **once at the end**.

## Per-task key facts + traps

### 3 — Hijack
- `keywords.data.json`: hijack id=`hijack`, code `HJ`, def "Enemy-only: this enemy's next roll copies the value of the hero's highest die." (already exists — don't touch the def).
- voidScribe **Checksum Scribe**: replace ONE mid-zone (surge OR strike) ability's effect payload with hijack, keep its damage component; rename "Checksum Copy". voidGlimmer **Forked Double**: change crit **Afterimage** from ward→hijack (17 dmg + hijack).
- Leave **Mimic Gland** on Caustic Spewer (flag in commit as future Hive-identity candidate). Do NOT add hijack to ROOT HIEROPHANT (Root Access owns its dice-attack slot).
- Respect one-keyword-per-ability (2 allowed in overload).

### 8 — Ward → Firewall (+ cull)
- Rename surfaces to **Firewall / code FW** (id may stay `ward` internally if migration is risky). Def: "Blocks the next ability that targets this unit, then breaks. An AoE that includes the unit is blocked for that unit only." Sweep: keywords.data.json, all `eff` text, hero ability text, status chips, tooltips, intent markers, **Memorial Protocol** intercept card, **CONCLAVE OVERSEER** standing rule, GROUND_TRUTH.md.
- **Cull to exactly 10** (remove the ward/firewall field from the other 7, keep the rest of each ability's payload, fix eff text): KEEP — all 6 Veil (veilAegis Lattice Link/Fortress Lash/Conclave Bulwark, veilResonance Harmonic Mend, veilNull Annulment, veilSynapse Synaptic Tune) + 4 Synod (voidAcolyte Seal Sigil & Init Collar, voidBinder Mass Snare, voidCircletBoss Hierophant Mantle). REMOVE — voidAcolyte Ritual Clamp, voidBinder Dominion Mark, voidGlimmer Afterimage & Fork Collapse, voidChanneler Warp Nova, voidCircletBoss Decree of Stillness & Absolute Binding. **Hero-side ward (3) is renamed, NOT culled.**
- **Trap:** Afterimage's ward is already gone if Task 3 ran first — that's fine, still remove Fork Collapse's.
- Report the Synod/Veil clear-rate delta; call out whether voidCirclet got meaningfully easier (loses boss wards).

### 5 — Jam cap 12 → 10
- `combat_manager.gd`: `const JAM_CAP := 12` at **line ~1172** → 10. (Callers use the const; no per-call literals to change.)
- Sweep the number in strings: `keywords.data.json` jam def ("...capped at 12." → 10), any `eff` text spelling the number, tooltips/rollovers, GROUND_TRUTH.md. **Leave Wall of Static's own "cap 15" clause unchanged** (separate).

### 7 — Cloak simplify (remove pierce-from-cloak)
- `combat_manager.gd`: remove the "first attack from Cloak gains Pierce" logic in the attack-resolution path. Final cloak rule (2 clauses): "Untargetable by hostile single target abilities. Breaks when this unit deals damage or is hit by an AoE." Update keyword def + sweep eff/tooltips/help/docs.
- **TRAP (must fix):** `ability_audit.gd` has a regression **"Regression / attack from cloak pierces and decloaks"** (~line 753) that asserts the removed behavior — update/remove it or the audit fails. Verify **Ghostblade** and **Ambush Wiring** directives still work on their own terms (don't silently rely on the removed clause).
- Run **freeze regression** (cloak+freeze share reveal handling). **Report the ghost-hero sim clear-rate delta; if ghost drops >~3 pts, note it in the commit for a follow-up buff — do NOT compensate now.**

### 4 + 9 — Taunt/Lure unify + Targeting personalities (do together)
- **Task 9 is the spine.** New enum `scripts/battle/targeting_personality.gd`: SYSTEMATIC / WOUNDED / PACK / SPITEFUL (see task list for exact rules + kit-default table + per-unit exceptions). One shared choke-point `personality_pick_target(enemy_state, hero_states, assignments_so_far)` used by BOTH `_auto_assign_enemy_target` (battle_scene.gd) and the sim/engine path. **No `randi` in it.**
- **HARD CONSTRAINT:** do NOT remove/rename/repurpose `ai_type` — it gates nat20 elite summons (combat_manager `ai_type=="smart"`) and the summon-injection guard in battle_scene (rejects non-"dumb"). Targeting is a **new independent `targeting` field**.
- Universal rules applied in that one choke-point: **taunt overrides everything**; cloaked heroes skipped; dead/illegal preferred target → stated fallback only. **Remove** the existing "pure debuff → targets highest HP" special case.
- SPITEFUL needs a new per-enemy `last_attacker_id`, written where hero damage lands in combat_manager, cleared on the attacker's death; register it in the state-key fence/constants if one exists.
- **Task 4 folds in here:** the "taunt overrides everything" universal rule IS the enemy-side of Task 4. Also: delete the `lure` keyword entry, unify `taunt` def to "The taunted unit can only target the taunter." (category control, code T), migrate enemy `lure` field usage in enemies.data.json to the enemy-side taunt representation (keep whatever internal field split combat_manager needs, but every player-facing string says Taunt), update Accretion **Pyroclast Raptor** eff text lure→taunt.
- **UI obligation (not optional):** when a hero is taunted by an enemy, the targeting flow must visibly restrict that hero's legal targets to the taunter (illegal targets don't highlight, tapping them does nothing) + the hero's card shows the taunt status chip.
- **Determinism check (must pass):** two sim runs, same seed → **byte-identical JSONL**. PACK assignment order + SPITEFUL must be deterministic (iterate enemies in slot order). Report per-op clear-rate deltas; **flag whether hive drops further** (PACK focus-fire is a threat increase and hive is already hardest).

## Verification commands
Godot: `C:/Users/Kev/Downloads/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64_console.exe`
```
npm run validate-data
<godot> --headless scenes/debug/AbilityAuditRunner.tscn      # ability audit (expect 214+ pass, 0 fail)
<godot> --headless -s scripts/debug/flow_smoke_test.gd        # flow smoke ("PASS")
<godot> --headless -s scripts/debug/tutorial_smoke_test.gd    # tutorial smoke ("PASS")
<godot> --headless scenes/debug/freeze_engine_regression.tscn # freeze regression (Task 7)
python scripts/sim/ci_smoke.py                                # diff vs baseline; drift is expected
python scripts/sim/ci_smoke.py --update-baseline              # accept after reviewing the delta
```
- Sim baseline lives at `scripts/sim/baseline.json`; an UNCHANGED tree reproduces it exactly (tolerances only absorb trivial noise), so any diff you see is your intended balance change — review it, note the deltas in the commit message, then `--update-baseline`.
- `--check-only -s file.gd` gives false "Identifier not found: <Autoload>" errors; to truly compile-check, `load()` the scripts from a tiny headless SceneTree (autoloads register) or just run the audit/smokes.

## Data shapes (quick orient)
- `keywords.data.json` = `{ "keywords": [ {id, term, category, def, syntax, code} ] }`.
- `enemies.data.json` — inspect the ability/zone/effect structure before editing; abilities carry a zone (recharge/strike/surge/crit/overload) and an effect payload + `eff` display text. Keep the one-keyword-per-ability rule (2 in overload).
