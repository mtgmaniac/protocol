# Beats & Events (Route Forks, Intercepts, Relic Cache)

> Part of the [Overload Protocol wiki](INDEX.md). See also: [rewards-and-shop.md](rewards-and-shop.md), [save-system.md](save-system.md), [operations.md](operations.md), [relics.md](relics.md), [protocol-economy.md](protocol-economy.md).

## How it works

### Beat scheduling (rolled once at run start)

`GameState._roll_run_beats()` (`scripts/autoloads/GameState.gd:222-244`) runs inside `start_run()`:

- Candidate gaps: `BEAT_GAPS := [2, 3, 4, 6, 7, 8]` (`GameState.gd:216`) — "after battle N". **Gap 5 is structurally excluded** because the battle-5 reward IS the relic cache (see below).
- Exactly `BEATS_PER_RUN := 3` distinct gaps are drawn (run-seeded `_reward_rng`).
- Each beat's type is a 50/50 fork/intercept roll; if all three came up the same, the **third** entry is flipped so the run always has ≥1 fork and ≥1 intercept (`GameState.gd:234-238`).
- Tier: gaps ≥ `MAJOR_BEAT_FROM := 6` are `major`, else `minor` (`GameState.gd:218, 241-243`).
- `run_beats` maps `after_battle -> {"type", "tier"}`; `get_beat_after_battle()` (`GameState.gd:248`) is the single query point.

**Routing:** after a non-final victory the reward (and any evolution stop) resolves first, then `SceneManager.go_to_next_battle_or_beat()` (`scripts/autoloads/SceneManager.gd:20-32`) checks for an unconsumed beat after the battle just won, marks it in `consumed_beats`, and detours to `RouteForkScreen` / `InterceptScreen`. Those screens call `GameState.advance_to_next_battle()` themselves before `go_to_battle()`.

### Battle-5 relic cache (INTERCEPT: RELIC CACHE)

Not a beat — it replaces the battle-5 reward roll. `_roll_reward_item_ids()` (`GameState.gd:1159-1184`): when `round == RELIC_ONLY_ROUND (5)` and `drafted_relic_count() == 0`, it returns `RELIC_CHOICE_COUNT (2)` relic choices; re-entry after a claimed draft returns empty on purpose.

- `drafted_relic_count()` (`GameState.gd:1152-1157`) subtracts the Starting Directive boss relic from `relics.size()` — **the 2026-07-06 soft-lock fix** (commit `b2da2b9`): the old `relics.is_empty()` guard rolled ZERO options for any run that opened with a Starting Directive. A directive run ends with two relics by design.
- Boss relics (`bossRelic: true`) never appear in the draft (`_roll_relic_choice_ids`, `GameState.gd:1187-1201`), and an owned relic is never re-offered (`_pick_random_item_id`, `GameState.gd:1241-1252`).

### Route Fork (fork beats)

`scripts/ui/route_fork_screen.gd`. Two cards: STANDARD (comp as rolled) vs FLAGGED (same slot pattern + one modifier + SUPPLY GRADE +2).

- `GameState.roll_route_modifier()` (`GameState.gd:280-298`): draws from `BATTLE_MODIFIERS` minus `used_battle_modifiers`; preconditioned entries are redrawn when their check fails (`_modifier_precondition_ok`, `GameState.gd:301`). The flagged comp is shaped ONCE at roll time and stashed (`pending_flagged_comp`, fix-1.5) so the preview can never drift from the fight.
- Accepting (`accept_flagged_route`, `GameState.gd:331-343`) arms `next_battle_modifier`, sets `next_battle_supply_grade = 2`, commits the shaped comp, and marks the modifier used. **Declining does NOT mark it used** — a declined modifier can be offered at a later fork.
- Supply grade: the reward rarity ladder rolls two rows deeper, capped at row 10, stepping past the (ladder-less) row 5 (`GameState.gd:1163-1173`). A flagged battle 5 spends the grade on the relic cache — i.e. on nothing (see finding F-meta-03).
- The armed modifier is consumed one-shot at battle start (`scripts/battle/battle_scene.gd:238-244` → `combat_manager.setup_battle_modifier`, `scripts/battle/combat_manager.gd:52-67`; sim mirror `scripts/sim/sim_runner.gd:396-400`).

#### The 10 fork modifiers (`GameState.BATTLE_MODIFIERS`, `GameState.gd:256-267`)

| id | Name | Effect (as coded) | Precondition | Implementation |
|---|---|---|---|---|
| `hardened` | HARDENED | Enemies spawn with 8 shield (expires per the one-round shield rule — turn-1 protection only) | — | `combat_manager.gd:56-59` |
| `jammingField` | JAMMING FIELD | Hero dice Jammed (cap 10 = `JAM_CAP`) on turn 1 | — | `combat_manager.gd:60-63` |
| `overrun` | OVERRUN | One extra fodder unit joins the comp (comp shaping) | comp ≤ 2 units AND fodder pool non-empty (`GameState.gd:303-305`) | `_shape_comp_for_modifier`, `GameState.gd:353-356` |
| `elitePresence` | ELITE PRESENCE | First non-elite slot upgrades to the elite pool (comp shaping) | ≥1 non-elite slot AND elite pool non-empty (`GameState.gd:308-317`) | `GameState.gd:357-364` |
| `ferocity` | FEROCITY | Enemy damaging hits deal +2 | — | `combat_manager.gd:1510-1511` |
| `deadMansCharge` | DEAD MAN'S CHARGE | Dying enemy deals 4 to a random living hero (**raw `randi()` — determinism-fence violation, F-meta-02**) | — | `combat_manager.gd:2110-2115` |
| `blackout` | BLACKOUT | No end-of-round Protocol income before round 3 | — | `battle_engine.gd:72-74` |
| `sealedSupplies` | SEALED SUPPLIES | Items cost 2 Protocol (base 1 + 1; Protocol Override / Supply Drone still zero it) | — | `battle_engine.gd:287-294` |
| `regenerative` | REGENERATIVE | Enemies heal 3 at the start of each enemy phase | — | `combat_manager.gd:709-713` |
| `warded` | FIREWALLED | Support enemies in the comp spawn with a Firewall | comp contains a support-pool unit (`GameState.gd:306-307`) | `combat_manager.gd:64-67` (names passed from the comp's `warded` list) |

Numbers are provisional — `BALANCE-TODO` at `GameState.gd:255`, **DEFERRED to the global balance pass per [DECISIONS_RESOLVED #7](../DECISIONS_RESOLVED.md)**. Note the dict's `amount`/`cap`/`fromTurn` values are display data; the implementations hardcode duplicates (finding F-meta-07).

### Intercept events (intercept beats)

`scripts/ui/intercept_screen.gd` + `GameState.INTERCEPT_CARDS` (`GameState.gd:397-488`). Decks are split by tier and Fisher-Yates-shuffled with the run rng at run start (`_shuffle_intercept_decks`, `GameState.gd:503-515`); `draw_intercept_card(tier)` (`GameState.gd:520-534`) pops without replacement. **Memorial Protocol redraws** unless a squad hero died in the last two battles (`requires: "recent_death"`; death window kept by `record_battle_hero_deaths`, `GameState.gd:545-547`, called at `battle_scene.gd:1185`); skipped cards go to the deck's back.

Choices are fully deterministic; a skip/alternative is always listed. Pick stages: `pick: "hero" | "gear" | "consumable"` (consumable = spend the highest-rarity one, button disabled when none; `intercept_screen.gd:137-141, 212-222`). `draft` runs a follow-up 1-of-N pick from `roll_intercept_draft()` (`GameState.gd:681-698` — item kind at/above a rarity floor, relics excluded). Effects apply through `apply_intercept_effects()` (`GameState.gd:559-623`).

Armed outcomes land in: `next_battle_effects` (one-shot flags), `hero_run_mods` (per-hero, run-long), `followup_battle_effects` (battle after next), `run_protocol_per_battle`/`run_protocol_cap_override`. Battle start consumes them via `battle_scene._apply_intercept_battle_effects()` (`battle_scene.gd:1360-1378`) → `battle_engine.apply_battle_start_external_effects()` (`battle_engine.gd:94-153`); the sim shares the exact same engine call (`sim_runner.gd:402-409`). `minus_one_enemy` is read during enemy-roster build BEFORE the effects dict is cleared (`battle_scene.gd:1779`, `sim_runner.gd:562` — order pinned by comment at `sim_runner.gd:375`).

#### Minor deck — 11 cards (beats after b2–b4)

| id | Name | Choice A | Choice B | Effect wiring |
|---|---|---|---|---|
| `overclockChamber` | OVERCLOCK CHAMBER | Pick hero: +1 all rolls this op, −8 max HP | Decline | `heroRollBonus`/`heroMaxHp` → `hero_run_mods` → `battle_engine.gd:135-141` |
| `abandonedArmory` | ABANDONED ARMORY | Draft 1 of 3 uncommon+ consumables | +2 Protocol next battle | draft → `roll_intercept_draft`; `protocolNextBattle` → `battle_engine.gd:125` |
| `trainingSim` | TRAINING SIM | Pick hero: +40 XP | All heroes +15 XP | `heroXp`/`squadXp` (`GameState.gd:570-576`); may queue a progression stop, shown at the next reward screen |
| `salvageCache` | SALVAGE CACHE | Rare+ gear draft, next battle HARDENED | 1 common consumable | `armModifier` sets `next_battle_modifier` directly (`GameState.gd:584-585`) — does NOT mark it used |
| `signalDecrypt` | SIGNAL DECRYPT | Reveal boss kit + standing rule, +2 Protocol next battle | 1 uncommon consumable | `revealBoss` → `_build_boss_reveal_text` (`GameState.gd:701-716`) |
| `decoyBeacon` | DECOY BEACON | Spend highest-rarity consumable: enemies waste turn 1 | Keep it | `nextBattleFlag: decoy` → `combat_manager.set_decoy_round_one` (`combat_manager.gd:78`, skip at `:721-723`) |
| `driftingWreck` | DRIFTING WRECK | Uncommon+ gear draft, next battle DEAD MAN'S CHARGE | +2 Protocol next battle | `armModifier: deadMansCharge` |
| `loadoutSwap` | LOADOUT SWAP | Rotate all gear loadouts one hero over, +1 uncommon consumable | Skip | `rotateGear` → `_rotate_gear_loadouts` (`GameState.gd:630-639`; the permanent stand-in per [DECISIONS_RESOLVED #15](../DECISIONS_RESOLVED.md)) |
| `cryoPod` | CRYO POD | Pick hero: +10 max HP this op, next battle BLACKOUT | 1 common consumable | `heroMaxHp` + `armModifier: blackout` |
| `supplyDrone` | SUPPLY DRONE | Items cost 0 next battle | 2 common consumables | `nextBattleFlag: items_free` → `battle_engine.item_protocol_cost` (`battle_engine.gd:290-291`) |
| `firingSolution` | FIRING SOLUTION | Highest-max-HP enemy next battle starts Marked at 90% HP | +2 Protocol next battle | `nextBattleFlag: marked_highest` → `battle_engine.gd:113-122` |

#### Major deck — 11 cards (beats after b6–b8)

| id | Name | Choice A | Choice B | Effect wiring |
|---|---|---|---|---|
| `spliceDeal` | THE SPLICE DEAL | Pick hero: overload band becomes 19-20, recharge band widens by 2 | Refuse | `spliceBands` → `dice_manager.gd:50-68` |
| `blackMarketNode` | BLACK MARKET NODE | Destroy one equipped gear, draft 1 of 3 rare+ gear | Leave | `destroyPickedGear` (`GameState.gd:642-646`); button disabled with no equipped gear |
| `unstableReactor` | UNSTABLE REACTOR | Next battle enemies spawn at 70% HP; a random hero takes 10 (at next battle start, floor 1 HP, one-shot) | +3 Protocol next battle | `nextBattleEnemyHpPct` → `battle_engine.gd:106-111`; `randomHeroDamage` → `start_hp_damage`, zeroed after apply (`battle_engine.gd:142-145`) |
| `rogueEngineer` | ROGUE ENGINEER | +1 Protocol at every remaining battle start; Protocol cap becomes 8 | Decline | `runProtocolPerBattle` (`GameState.gd:599-601`) → `battle_engine.max_protocol` cap override (`battle_engine.gd:164-167`) |
| `memorialProtocol` | MEMORIAL PROTOCOL | Fallen hero starts every remaining battle with a Firewall | 1 rare consumable | `requires: recent_death` (redraw); `memorialWard` → `start_warded` (`GameState.gd:602-606`) |
| `deepCache` | DEEP CACHE | Legendary draft 1 of 2; next battle starts at −5 Protocol income debt | Leave it | `incomeDebt` → `battle_engine.end_of_round_income` (`battle_engine.gd:75-77`, each owed turn swallows the +1) |
| `theFoundry` | THE FOUNDRY | Feed one gear: receive a random gear one rarity higher | Leave | `foundryUpgrade` (`GameState.gd:652-666`; legendary→legendary re-roll, "produced nothing" when pool empty) |
| `prisonerExchange` | PRISONER EXCHANGE | Next battle −1 enemy; the battle after gains ELITE PRESENCE | 1 uncommon consumable | `minus_one_enemy` (`battle_scene.gd:1779-1781`); `followupModifier` → `promote_followup_effects` (`GameState.gd:373-380`) |
| `overloadRites` | OVERLOAD RITES | Pick hero: −12 max HP this op; natural 20s resolve twice | Decline | `heroNat20Twice` → `combat_manager.gd:685` |
| `ghostFrequency` | GHOST FREQUENCY | Pick hero: starts every remaining battle Cloaked, −6 max HP | 1 rare consumable | `heroStartCloaked` → `battle_engine.gd:146-147` |
| `deepScan` | DEEP SCAN | Reveal every remaining comp and beat this run | +3 Protocol next battle | `revealRun` → `_build_run_reveal_text` (`GameState.gd:719-728`) |

Card numbers are `BALANCE-TODO` (`GameState.gd:396`), **DEFERRED per [DECISIONS_RESOLVED #6](../DECISIONS_RESOLVED.md)**.

### Zero-options guard

`scripts/ui/choice_screen_guard.gd` — `ensure_options(screen, count, default)`: `push_error` + telemetry print, then `call_deferred` on the default. Permanent fixture (TRUTH §Run structure); a `[CHOICE_GUARD]` log line is always a bug in the offer roll. Wired in `route_fork_screen.gd:107` (default = standard route) and `intercept_screen.gd:146` (default = `SceneManager.go_to_battle` — **misses `advance_to_next_battle()`, finding F-meta-01**).

### Templated battle slots / fixed anchors

`GameState._resolve_battle_comps()` (`GameState.gd:167-178`), rolled ONCE at run start into `resolved_battle_comps` so previews always show exact comps. Battles with authored `enemy_names` (the fixed anchors: b1, the faction signature fight, b10 boss + escort) keep them verbatim; slot battles roll each slot from the op faction's role pool (`_roll_slot_names`, `GameState.gd:181-200`; `heavyOrElites` = 50/50 one heavy or two distinct elites). Role pools are derived in `DataManager._build_enemy_role_pools()` (`scripts/autoloads/DataManager.gd:519-546`): fodder = `ai_type "dumb"`; standing-rule bosses excluded; heavy = smart with HP ≥ 90; support = smart with ally-aid fields in ≥2 kit zones; elite = the rest. A missing support pool falls back to elite (The Accretion has no support unit; `DataManager.gd:551-556`). Comps are capped at 3 units (`SQUAD_UNIT_LIMIT` reused as the enemy field cap — see F-meta-10); max authored comp is also 3.

## Why it works that way

- Beats were introduced as pkg7.2 (TRUTH §Run structure); the fixed gap set keeps the relic draft's slot clean and guarantees pacing (nothing before b2, nothing after b8).
- The rolled-once comp/beat model exists so previews (fork cards, DEEP SCAN) are promises, not estimates — fix-1.5 extended this to flagged comps (`pending_flagged_comp`).
- The ≥1-of-each flip guarantees a run samples both event systems.
- The guard doctrine: auto-resolve in release, assert in debug — "fix the offer, never widen the guard" (TRUTH §Run structure).
- Modifier/card numbers deliberately untouched: DECISIONS_RESOLVED #6/#7 defer them to the global balance pass.

## What it replaced

- The battle-5 draft guard was `relics.is_empty()` before Starting Directives existed; commit `b2da2b9` replaced it with `drafted_relic_count()` after the soft-lock (zero-option relic cache on directive runs).
- Mid-run re-equip UI: REJECTED per DECISIONS_RESOLVED #15 — LOADOUT SWAP's rotate-one-slot is the permanent behavior.
- No node map exists or is planned (TRUTH §Out of scope) — beats are the between-battle structure.

## File locations

- `scripts/autoloads/GameState.gd` — beats, modifiers, intercept cards/decks/effects, comps, reward ladder
- `scripts/autoloads/SceneManager.gd` — post-victory beat routing
- `scripts/ui/route_fork_screen.gd`, `scripts/ui/intercept_screen.gd`, `scripts/ui/choice_screen_guard.gd`
- `scripts/battle/battle_scene.gd` (consumption), `scripts/battle/battle_engine.gd` (shared battle-start rules), `scripts/battle/combat_manager.gd` (modifier hooks)
- `scripts/sim/sim_runner.gd` (headless mirror)

## Known edge cases

- A beat is marked consumed BEFORE its screen shows (`SceneManager.gd:23`); run state is in-memory only, so this can't strand a save.
- Declined fork modifiers re-enter the pool; intercept-armed modifiers (`armModifier`) never enter `used_battle_modifiers` — the same modifier can hit a run twice across systems (F-meta-11, needs ruling).
- `next_battle_modifier` is a single slot: an intercept `armModifier`, a fork accept, and a Prisoner-Exchange promote can overwrite one another silently (F-meta-04).
- Prisoner Exchange's followup ELITE PRESENCE skips the fork preconditions — it can arm with zero observable delta on an all-elite comp (F-meta-04).
- A drafted consumable is silently dropped at the 3-slot cap while the result stage still prints "Acquired" (F-meta-05).
- GameState's card comment says the consumable-pick choice is "hidden" without one; the screen actually shows it disabled (`intercept_screen.gd:137`).
- HARDENED's spawn shields obey the one-round shield rule — they only cover turn 1.
- TRAINING SIM XP crossing a threshold mid-beat defers its progression stop to the next reward screen (`reward_screen.gd:751`) — one stop per win holds.

## ⚠ Open findings

<!-- AUDIT-LINKS:beats-and-events -->
- [A-059](../audit/INTERACTION_AUDIT.md#a-059) - [confusing] Decoy Beacon skips actions but not standing rules
- [A-075](../audit/INTERACTION_AUDIT.md#a-075) - [broken] intercept zero-options guard replays the battle
- [A-076](../audit/INTERACTION_AUDIT.md#a-076) - [needs-Kev] flagged b5 pays SUPPLY GRADE for nothing
- [A-077](../audit/INTERACTION_AUDIT.md#a-077) - [degenerate] single-slot modifier overwrite + precondition bypass
- [A-078](../audit/INTERACTION_AUDIT.md#a-078) - [confusing] intercept item lost at cap but 'Acquired' printed
- [A-079](../audit/INTERACTION_AUDIT.md#a-079) - [confusing] BATTLE_MODIFIERS numeric fields are display-only
- [A-080](../audit/INTERACTION_AUDIT.md#a-080) - [confusing] route-fork guard counts children, never sees 0
- [A-081](../audit/INTERACTION_AUDIT.md#a-081) - [confusing] LoadoutMenu shows only relics[0]
- [A-082](../audit/INTERACTION_AUDIT.md#a-082) - [confusing] enemy field cap reuses the hero SQUAD_UNIT_LIMIT
- [A-083](../audit/INTERACTION_AUDIT.md#a-083) - [needs-Kev] modifier 'no repeats' only binds accepted forks
- [A-084](../audit/INTERACTION_AUDIT.md#a-084) - [confusing] DECOY BEACON comment/behavior drift
