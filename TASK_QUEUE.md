# Overload Protocol — CLAUDE CODE TASK QUEUE
*Copy-paste prompts for when you reconnect. Ordered so each task leaves the project in a stable, testable state. Do them in order; don't batch. Paste one prompt, review the diff, test, commit, move on.*

**Before anything:** open Claude Code in the repo root and confirm it's on Fable 5. First message to it should be: *"Read docs/AI_AGENT_GAME_REFERENCE.md, BATTLE_UI_V2_SPEC.md, and the offline-bundle/GROUND_TRUTH.md and CODEBASE_MAP.md I added. Treat GROUND_TRUTH.md as authoritative over the older GDD/ROADMAP/PHASE_0 docs. Don't write code yet — just confirm you understand the current state."*

---

## TASK 0 — Kill the doc drift (do this first; it's the root cause of past pain)
**Why:** three docs contradict the code. Any agent reading them will reintroduce landscape/4-unit/Systems-Medic mistakes.

> Prompt: "The docs are inconsistent with the actual code/data. Using offline-bundle/GROUND_TRUTH.md as the source of truth: (1) rewrite docs/CLAUDE.md, docs/GDD.md, and docs/ROADMAP.md so orientation=portrait 1080×2400, squad=3, healer=Splice Medic, operations=5, and remove all Phase-0/landscape/4-unit language; (2) delete or clearly mark docs/PHASE_0_STATUS.md as OBSOLETE at the top; (3) add a one-line pointer at the top of docs/CLAUDE.md telling agents to read AI_AGENT_GAME_REFERENCE.md and BATTLE_UI_V2_SPEC.md as current. Show me the diffs, change nothing in scripts/ or data/."

**Test:** read the diffs. **Commit:** `docs: reconcile to ground truth (portrait/3-unit/5-op)`.

---

## TASK 1 — Establish a known-good baseline you can return to
**Why:** before any refactor, prove the game runs and capture the current state.

> Prompt: "Walk me through running the project in Godot 4.6 from this repo on my machine, including the `-- --debug-battle` launch path in DebugBattleLauncher.gd. Then run the ability audit (scripts/debug/ability_audit_runner.gd) and report any warnings. Don't change code — I want a baseline of what currently works and what errors print on a full run from UnitSelect through one full battle to the reward screen."

**Test:** you play one full battle. Note anything broken in a scratch list. **Commit a tag:** `git tag baseline-fable-restart`.

---

## TASK 2 — Decompose battle_scene.gd (the #1 source of iteration hell)
**Why:** 4,166 lines in one file is why visual changes cascaded into breakage before. This is the highest-leverage maintainability win. Do it in SMALL steps, testing between each.

> Prompt: "battle_scene.gd is 4,166 lines and too big to iterate on safely. I want to extract it into focused scripts WITHOUT changing behavior — pure refactor. Propose a decomposition plan first (likely: a BattleLayout helper for the dice-anchor/band-rect math, a BattleCardView helper for _update_card_view + compact status/pip building, and keep orchestration/turn-flow in battle_scene.gd). List exactly which functions move where, what signals/refs need rewiring, and the risks. Don't write code yet — show me the plan."

Then, after you approve the plan, one extraction at a time:

> Prompt: "Do extraction step 1 only (the layout math). Move those functions into the new helper, rewire references, keep behavior identical. Show the diff. I'll test before we do step 2."

**Test after each step:** run a full battle, confirm layout + dice + cards look identical to baseline. **Commit each step separately.**

---

## TASK 3 — Pin the V2 band geometry to spec
**Why:** layout was a top pain point; BATTLE_UI_V2_SPEC.md gives exact pixel targets that may not be enforced in code yet.

> Prompt: "Audit battle_scene.gd's layout helpers (_get_combat_zone_rect, _get_*_result_row_rect, _layout_dice_from_combat_zone, band sizing) against the exact baseline heights in BATTLE_UI_V2_SPEC.md (header 144, enemy 768, center 432, hero 768, footer 144 at 1080×2400; header==footer; cards identical size; center button exactly centered). Report every place the code deviates from the spec. Propose fixes but show me the list before changing anything."

**Test:** preview at 450×1000, eyeball against the spec bands. **Commit:** `battle: enforce V2 band geometry`.

---

## TASK 4 — Verify ability-data integrity end to end
**Why:** the data is complete but you want confidence the JSON→resource→combat path is faithful before balancing.

> Prompt: "Using scripts/debug/ability_audit.gd, verify every hero ability (base + both evolution paths) and every enemy ability in data/raw/ maps to a handled keyword in combat_manager._apply_hero_ability / _apply_enemy_ability. Produce a table of any ability whose keywords aren't actually implemented (e.g. a flag in JSON that combat_manager ignores). Don't fix yet — I want the gap list."

**Test:** review the gap list; decide which to implement vs. cut. **This likely seeds several follow-up tasks.**

---

## TASK 5 — First playable-balance pass (only after 0–4 are stable)
**Why:** now the foundation is clean, balance is a data-only loop — exactly the safe, satisfying offline-friendly work.

> Prompt: "Use the battle-progress sim in `scripts/sim/` and `scripts/debug/balance_sim_*.ts` to simulate the `facility` operation (10 battles) with several 3-hero squads. Report win rate, average battle length, and any battle that's a difficulty cliff. Suggest data-only tweaks to battleEnemyScale and specific enemy HP/dmg — show me proposed JSON diffs, don't apply."

---

## TASK 6 — Implement the new gear & relic effect types from the workbook
**Why:** the expanded Gear (19) and Relics (21) in overload_protocol_data.xlsx introduce new `effect_type` values that DataManager loads but combat_manager/GameState don't yet act on. The data is the spec; the behavior needs wiring. Do them one at a time with a test between each.

**New GEAR effect types (hook in combat_manager):**
- `lifesteal` (amount = %) — heal the equipped unit for that % of damage it deals. Hook: the hero damage path in `_apply_hero_ability` / `_damage_state` resolution.
- `firstAbilityEcho` — first ability each battle resolves a 2nd time vs same target, DAMAGE ONLY. Hook: track a per-unit "first ability used" flag in the runtime state; re-run damage portion.
- `shieldPierce` (amount) — this unit's attacks ignore up to N shield. Hook: `_damage_state` shield subtraction.
- `healShieldBonus` (amount) — when this unit heals an ally, also add N shield. Hook: `_heal_state` / the hero heal path.
- `protocolOnKill` (amount) — refund N protocol when this unit kills a BASIC enemy. Hook: `_on_unit_killed` + enemy-tier check.
- `protocolOnKillAny` (amount) — refund N protocol on ANY kill by this unit. Hook: `_on_unit_killed`.

**New RELIC effect types:**
- `allyDeathHealAll` (amount) — ally dies → all other allies heal N. Hook: `_on_unit_killed` (mirror of existing chainReaction infra). [combat_manager]
- `critResolveTwice` (mult) — every natural 20 resolves its effect twice. Hook: round resolution where overload/20 abilities apply. [combat_manager]
- `rewardsNoCommon` — reward roller never offers common items. Hook: `GameState._pick_random_item_id` / `_roll_reward_item_ids` rarity filter. [GameState]
- `protocolCarryover` (amount = %) — carry N% unspent protocol between battles (overrides the per-battle reset). Hook: battle setup / protocol init. [combat_manager + battle_scene]
- `battleStartConsumable` (amount) — start each battle with N random consumable(s). Hook: battle start / GameState.consumables. [GameState + combat_manager]
- `reviveNoPenalty` — between-battle revives have no HP penalty. Hook: the revive-between-battles logic. [GameState]
- `lowHpSquadRollBuff` (amount) — first time each battle an ally drops below 50% HP, whole squad gets +N roll that turn. Hook: `_damage_state` threshold check + a once-per-battle flag + roll-buff application. [combat_manager]
- `healGrantsShieldAll` (amount) — any ally healed → all allies gain N shield. Hook: `_heal_state`. [combat_manager]

> Prompt to start: "From overload_protocol_data.xlsx Gear and Relics sheets, here are the new effect_type values that aren't yet handled. Confirm which are unhandled by grepping combat_manager.gd and GameState.gd, then implement them ONE at a time — start with `lifesteal`. For each: show me where it hooks in, the diff, and how to test it via the debug auto-battle. Don't batch."

**Test:** for each effect, equip/grant it and confirm via auto-battle + the combat log. **Commit each separately.**

---

## TASK 7 — Rename the DoT keyword to `burn` across code + data (lockstep)
**Why:** decision made — one unified damage-over-time keyword, called **burn** (drops the inconsistent `dot`/`poison` naming). Mechanic is UNCHANGED; this is a pure rename. The workbook and GROUND_TRUTH already use burn naming, so the code and regenerated data must follow to match.

**⚠ Ordering — do all of this in ONE session and don't run the game in between:** the data keys and the code that reads them must change together. Never load burn-keyed data with dot-reading code, or vice versa. Sequence: (1) rename in code, (2) regenerate `data/raw/*.json` from the burn-named workbook via the converter (the Task-0-adjacent converter — build it first if it doesn't exist), (3) run a full battle to verify.

**Complete rename map:**

Data keys (in `data/raw/*.json`, produced by the workbook converter):
- ability entries: `dot` → `burn`, `dT` → `burnT` (heroes abilities + evolutions; enemies `enemyAbilities`)
- items: effect `type` `enemyDot` → `enemyBurn`; its `dT` → `burnT`
- gear: effect `type` `dotDmgBonus` → `burnDmgBonus`
- relics: `enemyDotPermanent` → `enemyBurnPermanent`; `dotAmplified` → `burnAmplified`

Code — `scripts/autoloads/DataManager.gd`:
- `_build_hero_dice_ranges` / `_build_enemy_dice_ranges`: reads of `dot`/`dT` → `burn`/`burnT`
- gear handling: `dotDmgBonus` → `burnDmgBonus`; state var `gear_dot_bonus` → `gear_burn_bonus`
- relic `enemyDotPermanent` → `enemyBurnPermanent`
- `_get_total_dot_bonus` → `_get_total_burn_bonus`
- item `enemyDot` → `enemyBurn`

Code — `scripts/battle/combat_manager.gd`:
- `_apply_poison` → `_apply_burn`
- runtime state keys `poison` / `poison_turns` / `poison_skip_next_tick` → `burn` / `burn_turns` / `burn_skip_next_tick`
- ability reads `raw.get("dot")` / `raw.get("dT")` → `"burn"` / `"burnT"`
- effect-type strings `enemyDotPermanent`, `dotDmgBonus`, `dotAmplified` → burn equivalents
- log strings "is poisoned for" → "is burning for"; `_emit_event(state, "poison", …)` → `"burn"`

UI / docs:
- `battle_scene.gd` `_build_compact_status_tokens` (and any status-icon map): the "poison" status token → "burn" / display "Burning"; new icon if you want a flame vs the old toxin glyph
- `docs/GDD.md` and `docs/CLAUDE.md`: status "Poisoned" → "Burning"
- ability *names* stay as flavor (Venom Nip, Acid Saliva, Corrosive Hose, etc. — unchanged); only the mechanic word changes

> Prompt: "Pure rename, no behavior change: rename the damage-over-time keyword from dot/poison to `burn` everywhere. Use the map in TASK_QUEUE.md Task 7. Grep first to confirm every site (combat_manager.gd, DataManager.gd, the resources, battle_scene status tokens, docs), show me the full list before editing, then do code first. The workbook already uses burn naming, so regenerate data/raw from it via the converter in the same pass and run one full battle to confirm burn ticks behave identically to before."

**Test:** a battle where burn is applied — confirm the tick damage, stacking, and "permanent" (9999-turn) burn all behave exactly as poison did. **Commit:** `refactor: rename DoT keyword to burn (no behavior change)`.

---

## TASK 8 — Build the battle feedback / "game feel" system
**Why:** make battle feel alive. Full spec is in `offline-bundle/ANIMATION.md` (beat model, primitive library, event→primitive table, tiers). You already have the right backbone — an event-driven feedback pipeline (`combat_manager._emit_event` → `battle_scene._play_round_feedback`) — so this is enriching the presentation layer, not building from zero. Aesthetic guardrails: flat / no glow / pixel, meaning-based color, snappy timing, weight + readability over spectacle.

**Step 1 — extract the component (do alongside Task 2):**
> Prompt: "Read offline-bundle/ANIMATION.md. Extract a `BattleFeedback` node out of battle_scene.gd: move `_play_round_feedback`, `_build_action_feedback_groups`, `_play_action_feedback_group`, `_flash_card`, `_spawn_floating_text` into it, subscribed to the combat event stream, with no behavior change yet. Show me the plan (what moves, what signals rewire) before editing."

**Step 2 — primitive library:** implement `lunge`, `shake`, `hit_pause`, `tracer`, `spawn_particles`, `drain_hp` (+chip bar), `punch_number`, `die_settle`, generalized `flash` — each tiny and generic. Test each in isolation via auto-battle.

**Step 3 — data-driven event→primitive table:** wire the mapping table from ANIMATION.md so each event fires its primitives (and names an optional SFX key for later). New effects become new rows, not new branches.

**Step 4 — build in tiers, testing between each:**
- Tier 1: hit_pause · attacker lunge · drain_hp + chip bar · punch_number · idle bob.
- Tier 2: card/screen shake · ranged tracers · natural-20 celebration · shield-shatter.
- Tier 3: pixel-particle system · death animations · camera flourishes · per-faction flavor.

> Prompt to start Tier 1: "Implement Tier 1 from ANIMATION.md one primitive at a time — start with hit_pause, then the attacker lunge on the existing play_action_feedback hook. Show the diff for each and let me see it in an auto-battle before the next."

**Test:** run auto-battle and watch a full fight — every hit should read as cause→effect with weight; the natural-20 should feel like an event. **Commit each primitive/tier separately.**

**Note:** keep `BattleFeedback` sound-aware (each table row can name an SFX key) even though audio clips are out of scope for the demo — wiring the hook now is free; the clips slot in later.

---

## TASK 9 — Basic audio system
**Why:** sound is half of "alive," and it rides the same event hooks as Task 8. Full spec in `offline-bundle/AUDIO.md`. Aesthetic: chiptune/synthetic/mechanical, dice as the star. Layered model — base sound per action *category* (not per ability), pitch/sample variation for polish, one bespoke `overload` stinger, faction toppers deferred.

**You provide the clips; Claude Code builds the system.** Generate the SFX set yourself with ChipTone / Bfxr / jsfxr (royalty-free, on-aesthetic, ~an afternoon), supplement richer ones from Sonniss / Freesound (filter CC0). Claude Code stubs each key with a placeholder so the wiring is testable before real files land.

**Step 1 — system:**
> Prompt: "Read offline-bundle/AUDIO.md. Build an `AudioManager` autoload: `play_sfx(key)` with pitch/volume randomization and voice limiting, routed through a SFX bus (Master → SFX, Music). Stub every sfx key from the AUDIO.md table with a silent placeholder under assets/audio/sfx/ so it's testable now. Show me the bus setup and the autoload."

**Step 2 — wire to events:** add an `sfx` column to the BattleFeedback event table (Task 8) and call `AudioManager.play_sfx(key)` on the same hook as each visual primitive.

**Step 3 — tiers:** Tier 1 = dice_roll, dice_lock, hit, ui_click (+ pitch variation). Tier 2 = heal, shield_up, shield_break, buff, freeze, burn_tick, death, and the bespoke overload stinger. Tier 3 = faction toppers, music, ambience, volume sliders.

**Test:** auto-battle with audio on — hits vary in pitch (no machine-gun sameness), the natural-20 stinger lands, nothing clips when several effects fire at once. **Commit per tier.**

---

## TASK 10 — Protocol economy (implement the decided baseline)
**Why:** the protocol numbers are decided (see GROUND_TRUTH "Protocol economy") but only half-implemented, and parts of the current code conflict with the decisions. Pure tuning + one new action.

**Current state in code:** `MAX_PROTOCOL = 7`; reroll costs 2 and nudge costs 1 (nudge adds **+5** to effective roll); **no per-turn income** (protocol only comes from Protocol Tap at battle start); **no set-a-die action exists**; items cost by rarity (`_get_item_protocol_cost`: common 0 / uncommon 1 / rare 2 / legendary 3).

**Changes:**
1. `MAX_PROTOCOL` 7 → **10**.
2. Add **per-turn income**: start battle at 0, **+1 at end of every turn** (this is the missing core mechanic — find the end-of-turn hook in `battle_scene.gd` round resolution and add it, clamped to MAX_PROTOCOL).
3. Nudge effect **+5 → +3** (cost stays 1).
4. **Items flat cost 1**: rewrite `_get_item_protocol_cost` to return 1 for all rarities (keep the `protocolFree`/override branch — see #6).
5. **Build the Set-a-die action** (cost 3) — prompt below.
6. **Redesign Protocol Override relic** (`protocolFree` → `protocolOnItemUse`): instead of making items cost 0, using an item now **costs 0 AND grants +1 Protocol** (net +1 per item). Verify net feel; dial to net 0 (cost 1, gain 1) if +1 proves too strong.

> Prompt for the Set-a-die action: "Add a third protocol manipulation action, 'Set' (a.k.a. pick-a-number), alongside the existing Reroll and Nudge in battle_scene.gd. Cost: 3 Protocol. Behavior: the player taps one of their dice, then chooses any value 1–20, and that die's effective roll becomes that value for this turn (respects the same targeting/availability rules as Reroll). Mirror how `_on_reroll_button_pressed` / `_on_nudge_button_pressed` are wired (button creation, tooltip 'Set\\nSpend 3 Protocol to set a hero's die to any value.', cost check, `protocol_points -= 3`, refresh). Show me the diff and how to trigger it in an auto-battle."

**Field Engineer protocol anchor (design note for a follow-up content task):** Field Engineer's blurb promises protocol plays + roll-spikes but his kit delivers neither. Plan: base unit generates protocol on its low/utility zones and adds the promised ally roll-spike; **Overclocked** = protocol *generator* (battery), **Wraith Engineer** = protocol *efficiency* (discounts/free manipulations). Requires a new `gainProtocol N` ability keyword (and a manipulation-discount modifier for Wraith). Scope detailed separately.

**Test:** a battle confirming income ticks +1/turn to a cap of 10, nudge is +3, set-a-die works at cost 3, every item costs 1, and Protocol Override nets +1 per item. **Commit per change.**

---

## TASK 11 — Evolution callsigns + data cleanup
**Why:** evolved units currently repeat the base callsign; the workbook now has correct callsigns for all 16 paths. Also cleans the data structure so evolutions don't redundantly repeat per ability slot.

> Prompt: "Evolution units are missing their own callsigns. The workbook at design/overload_protocol_data.xlsx Hero_Evolutions sheet now has a 'callsign' column with the correct values (CRYO, PYRO, BLADE, RAVAGER, BULWARK, SENTINEL, GLACIER, TRENCH, MEDIC, SYNTH, OVERCLOCKED, PHANTOM, SHADOW, WRAITH, NOISE, NULLWIRE — note Wraith Engineer is PHANTOM to avoid collision with Ghost's WRAITH). Update data/raw/heroes.data.json so each evolution has a single top-level callsign field, and DataManager serves it correctly so battle_scene uses the evolved callsign once a unit evolves. Show me the data diff and the DataManager change before touching anything else."

**Test:** evolve a unit in-game and confirm the callsign on the battle card updates to the evolution callsign. **Commit:** `data: add evolution callsigns`.

---

## TASK 12 — Normalize eff text across all abilities
**Why:** the workbook now contains normalized eff fields for all 8 heroes (base + evolutions) and all enemy ability sets, using the canonical syntax: `[value type] [modifier] [target] [duration]`, effects joined by ` + `. This is the source of truth for all tooltip text.

> Prompt: "The workbook at design/overload_protocol_data.xlsx (Heroes_Abilities, Hero_Evolutions, Enemy_Abilities sheets) now has normalized 'eff' text for every ability using a consistent syntax. Use the workbook→JSON converter to regenerate data/raw/heroes.data.json and data/raw/enemies.data.json with the updated eff fields. Then confirm the ability tooltip display in battle_scene.gd reads the eff field directly (not hardcoded strings). Show me two sample tooltips in-game after the change — one hero, one enemy."

**Test:** check tooltips for a variety of abilities in battle. **Commit:** `data: normalize all eff tooltip text`.

---

## TASK 13 — Picker blurbs update
**Why:** main unit blurbs are now in the short mechanical format matching evolution focus descriptions. Updated in workbook.

> Prompt: "Update the picker blurb for each hero in data/raw/heroes.data.json to match the workbook Heroes_Abilities 'picker_blurb' column. The new blurbs are short and mechanical (e.g. 'Elemental damage / evolve-dependent'). Confirm they display correctly on the unit select screen. Show me the UnitSelect screen with the new blurbs — a screenshot or description of how they render."

**Test:** run UnitSelect, read all 8 blurbs. **Commit:** `data: update picker blurbs to mechanical short form`.

---

## TASK 14 — Enemy half-card layout for larger squads
**Why:** some battles may have 4–5 enemies. The current layout assumes 3 max. Need a compact half-card that shows HP + die + ability name, with tap-to-expand for the full card.

> Prompt: "Design a 'compact enemy half-card' mode for the enemy zone in battle_scene.gd. When 4 or more enemies are present, enemy cards should shrink to approximately half height, showing only: portrait thumbnail, HP bar, current die value, current ability name. Tapping a half-card expands it to full size (or opens a modal overlay). When 3 or fewer enemies are present, use the existing full card layout. Propose the layout math against the BATTLE_UI_V2_SPEC.md enemy rail height (768px at 1080×2400) before writing any code — show me how 4 and 5 cards fit."

**Test:** use DebugBattleLauncher to load a battle with 4 enemies and confirm layout. **Commit:** `battle: half-card layout for 4+ enemies`.

---

## NEAR-FUTURE DESIGN QUESTIONS (finalize before implementing)

### A — Arc / electric mechanic
Agreed to add an electric status keyword called **ARC**. Two mechanical options to decide:
- **Option A (control):** ARC forces the target to roll a 1 next turn (opposite of freeze — freeze locks a good result, arc forces a bad one). Clean, legible, earns its slot.
- **Option B (buff/energize):** ARC energizes a die — the unit's next roll is treated as the next zone up regardless of actual value. More interesting, pairs well with a buff-support unit. Potential RFM replacement.
Don't add zap counters yet (stacking adds balance complexity). Don't replace protocol actions with arc theming (breaks color meaning). Decide option A or B, then scope which units/enemies use it and what the status icon looks like (flat pixel electric bolt, cyan or gold).

### B — DoT naming / flavor
Currently: generic `dot` keyword in data/code; the word "burn" appears in some item names as flavor only. Two paths:
- **Simple:** keep `dot` as the single keyword everywhere, add a `dot_flavor` field (cosmetic only — controls status icon label: BURN / VENOM / DECAY etc.) with no change to mechanics. The Hive shows "VENOM", Pyro shows "BURN", all tick identically.
- **Split:** two distinct mechanics (burn = short/intense, poison = long/stacking). Only worth it if fire/thermal becomes a full pillar.
Recommendation is the simple path (`dot` + `dot_flavor`). Decide before Task 7 is run so the rename target is clear.

### C — Third evolution / hybrid evolutions
Parked for far future. Revisit after the base game is complete and tested. Near-future alternative to consider: a small **mid-run specialization** around battle 3–4 that modifies one ability (not a full path fork). Simpler, adds a decision point, doesn't require doubling content.

### D — Stats system (STR/DEX/INT + rock-paper-scissors damage modifiers)
Parked for far future. Only revisit after core loop is proven fun. If units feel undifferentiated, sharpen ability identities first before adding a stat layer.

---

## OFFLINE PARKING LOT (things to think through on the plane — no code needed)
Decide these so the prompts above go faster when you land. Jot answers in a notes file:

1. **battle_scene.gd split:** do you agree with the 3-way split (Layout / CardView / Orchestration)? Any other natural seam you'd prefer?
2. **Operation scope for the demo:** ship all 5 operations, or polish `facility` to perfection first and gate the rest? (GROUND_TRUTH says all 5 exist in data; demo doesn't have to expose all.)
3. **Difficulty target:** what win rate do you want a competent first-time player to have on `facility`? (sets the Task 5 balance goal)
4. **Protocol economy:** how much Protocol per turn, and Reroll/Nudge/Item costs? (not fully pinned in data I saw — worth deciding)
5. **Evolution timing:** XP_TO_EVOLVE=100 with 50/battle means evolve ~battle 2. Is evolving that early intended, or do you want it later (battle 4–5)?
6. **What "done" looks like for this session's return:** pick ONE — clean refactor, or first balanced operation. Don't try for both at once.
7. **DoT identity:** DECIDED — single damage-over-time keyword renamed to **burn** (no poison/burn split; mechanic unchanged). Workbook + GROUND_TRUTH already use burn naming. The code/data key rename is Task 7. (If fire/thermal ever becomes a pillar, fire simply becomes another source of burn — consistent.)

---

## Working rhythm (this is what prevents the old frustration)
- One prompt → review diff → test in Godot → commit → next. Never let the agent make 5 changes before you run it.
- After any data edit, run the ability audit.
- Keep `baseline-fable-restart` tag as your safety net; if a refactor goes sideways, reset to it.
- Design decisions stay in Claude chat (this UI); implementation in Claude Code. You already know this split works for you.
