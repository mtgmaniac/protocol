# Targeting

> Part of the [Overload Protocol wiki](INDEX.md). See also: [enemies.md](enemies.md), [keywords.md](keywords.md), [dice-and-rolls.md](dice-and-rolls.md), [combat-resolution.md](combat-resolution.md).

## How it works

### The one choke point

Every hostile single-hero pick by an enemy flows through `TargetingPersonality.personality_pick_target(enemy_state, hero_states, assignments_so_far)` (`scripts/battle/targeting_personality.gd:125`). It is shared by:
- the battle UI's intent display (`combat_manager.assign_enemy_intents`, `scripts/battle/combat_manager.gd:153`, called from `battle_scene.gd:2003`), and
- resolve time / the headless sim (`assign_enemy_intents` re-run at `combat_manager.gd:667`; per-component resolution via `_resolve_enemy_hero_target`, :199).

Fully deterministic — no `randi()` anywhere in the choke point; ties break toward the lower slot. An already-assigned, still-legal pick is honored at resolve time so the displayed intent is never silently overwritten (:160-163, :204-206).

### Universal rules (live in the choke point and nowhere else)

1. **Taunt overrides everything** — a taunting hero is picked even if cloaked (`targeting_personality.gd:127-130`). Re-checked at resolve time (:199-201), so a hero who starts taunting after intents were drawn steals the hit.
2. **Cloaked heroes are skipped** — personalities pick among uncloaked living heroes (:131-136).
3. **Stated fallbacks only** — a dead/illegal preferred target falls to the personality's documented fallback, never hidden logic. The old "pure debuff → highest HP" special case is REMOVED (`battle_scene.gd:2148-2153` comment).

### The four personalities (INVARIANTS #6: max four, ever)

| Personality | Rule (inspect blurb) | Fallback | Code |
|---|---|---|---|
| SYSTEMATIC | "attacks the squad left to right" — first living uncloaked hero by slot | — | `targeting_personality.gd:159-160` |
| WOUNDED | "hunts the lowest-HP hero" (absolute HP, ties → lower slot) | — | :140-141, `_lowest_hp` :164 |
| PACK | "joins another attacker's target" — first hero already assigned this turn (insertion order = slot order) that is still legal | → WOUNDED | :142-150 |
| SPITEFUL | "strikes back at whoever hurt it last" (`last_attacker_id`) | → SYSTEMATIC | :151-158 |

SPITEFUL bookkeeping: `last_attacker_id` is stamped on any connecting hero hit, even fully shield-absorbed (`combat_manager.gd:1783-1786`), and cleared when that hero dies (:2163-2164). A cloaked grudge target falls through to SYSTEMATIC.

**Resolution order** (`resolve_personality`, `targeting_personality.gd:102`): unit `targeting` field in `enemies.data.json` → kit-default table (`KIT_DEFAULTS`, :16, keyed by `enemy_type`) → SYSTEMATIC. Kit defaults: Facility SYSTEMATIC (guard/patrol/volt PACK; warden/boss WOUNDED) · Hive PACK (stalker/hiveBoss WOUNDED) · Veil WOUNDED (veilShard/veilPrism SYSTEMATIC) · Synod SYSTEMATIC (voidBinder/voidChanneler/voidCircletBoss WOUNDED; voidGlimmer SPITEFUL) · Accretion SPITEFUL (beastWolf/beastMonkey PACK; beastLynx WOUNDED).

`ai_type` is a SEPARATE, load-bearing field (nat20 elite summons `combat_manager.gd:2637`, summon-injection guard `battle_scene.gd:2579`) — never derive targeting from it (INVARIANTS #2). The enemy inspect popup surfaces "TARGETING: NAME — definition" verbatim (`personality_blurb`, `targeting_personality.gd:96`).

### Which enemy abilities need a pick

`_ability_targets_single_hero` (`combat_manager.gd:179-192`): single-target `dmg`, `burn`, `rfm`, `freezeEnemyDice`, `jam`, `rewrite`, `taunt`, `curseDice`. AoE (`blastAll`), self-shields, ally-shields, `erb` buffs, and hijack need no hero pick (display targets labeled by `battle_scene._auto_assign_enemy_target`, :2148). **Exception:** the enemy freeze rider ignores the personality pick and always targets the hero with the LOWEST revealed die (`_freeze_pick_hero_lowest_die`, `combat_manager.gd:2033` — taunt still overrides, cloak still hides, unrevealed faces count as 21, ties to slot order).

### Hero targeting and the manual pick

`_get_manual_target_side` (`battle_scene.gd:2050-2074`) decides whether a hero's rolled ability needs a manual tap, checking in priority order: `freezeAnyDice` → "any" · `freezeEnemyDice` → "enemy" · `reviveAll` → none · `revive` → "dead_hero" · `healTgt`/`shTgt`/`wardTgt`/`rfmTgt` → "hero" · single-enemy dmg/burn/rfe → "enemy" · AoE/heal-all/shield-all → none. Because exactly ONE side is returned, an ability can never demand two different picks — the structural enforcement of **max one manual pick per hero ability** (INVARIANTS #12). Auto-assigned components (self-shields, `healLowest`/`shieldLowest` → lowest-HP ally, AoE) are labeled without a pick (`_auto_assign_hero_target`, :2124). A single legal target auto-assigns without a tap (`_try_auto_assign_single_manual_target`, :2091 — disabled in the tutorial so the taught flow actually happens).

### Manual-pick legality — `_get_legal_target_ids` (`battle_scene.gd:2241-2274`)

- **Enemy-side taunt (internal `lured_by_id`)**: a taunted hero's hostile picks are restricted to the taunter — the legal list is exactly `[taunter]` while the taunter lives (:2244-2249). Covers exactly one hero phase (`_tick_state`, `combat_manager.gd:2480-2486`).
- **Cloak blocks hostile picks only**: cloaked ENEMIES are skipped for "enemy"/"any" sides; friendly picks on cloaked allies are ALWAYS legal (:2268-2272, DECISIONS_RESOLVED #12).
- `dead_hero` (revive): only dead heroes are legal.
- `any` (freezeAnyDice, any-target items): both sides, dead skipped, cloaked enemies skipped.
- Illegal targets don't highlight and taps on them do nothing (`_is_card_clickable`, :2337; `_on_enemy_card_pressed` guard :2406-2408).

### Hero-side taunt (enemy `enemySelfTaunt`)

While any enemy is taunting, ALL living heroes are force-targeted onto it (`_prepare_hero_targets` taunt branch); re-tapping a taunt-locked hero can still move it to the end of the cast order but cannot change its target. Taunting clears at end of round. One taunter at a time — a new `enemySelfTaunt` clears all others.

### Retargeting / cast order (2026-07-20)

Assignment order IS firing order (player-chosen cast order — see TRUTH.md). During TARGETING/READY_TO_END, re-tapping an assigned hero unassigns it (`_can_unassign_hero` / `_unassign_hero_cast` in `battle_scene.gd`): manual abilities return to the pending queue and immediately re-open targeting (retarget stays two taps, the hero recommits at the END of the order); auto abilities move to the end of the order in one tap. Reroll/Nudge/Set/Twin Fates re-run target assignment because the zone may have changed (`_re_assign_hero_target`) — which also recommits the hero at the end of the order.

## Why it works that way

- "Enemy AI is a legible rule, not a mind" (INVARIANTS #6): four personalities, one deterministic choke point, blurbs surfaced verbatim in the inspect popup. Difficulty comes from composition and boss standing rules, never smarter heuristics.
- Determinism (INVARIANTS #1): the sim must reproduce targeting byte-identically; PACK's dependence on insertion order works because Godot Dictionaries preserve it (`targeting_personality.gd:123-124`).
- The pure-debuff→highest-HP special case was removed for legibility (INVARIANTS #5).
- `targeting` was split from `ai_type` deliberately (keyword batch Tasks 4+9, commit `0bd652c`); merging them silently breaks elite summons.
- One-manual-pick keeps the touch flow one die tap → at most one target tap (INVARIANTS #12).

## What it replaced

- The old `ai_type` smart/dumb targeting branch, including the pure-debuff-targets-highest-HP special case (removed in Tasks 4+9, `0bd652c`).
- Lure as a separate keyword — unified into Taunt both directions (DECISIONS_RESOLVED K3); internal `lured_by_id` split retained, every player-facing string says Taunt.

## File locations

- `scripts/battle/targeting_personality.gd` — the four personalities, kit defaults, the choke point
- `scripts/battle/combat_manager.gd` — `assign_enemy_intents`, `_resolve_enemy_hero_target`, `_freeze_pick_hero_lowest_die`, SPITEFUL bookkeeping
- `scripts/battle/battle_scene.gd` — hero manual-pick sides, legality (`_get_legal_target_ids`), taunt forcing, retarget flow
- `data/raw/enemies.data.json` — per-unit `targeting` overrides

## Known edge cases

- Two taunting heroes: the lower slot is picked (first match wins, `targeting_personality.gd:127-130`).
- PACK with no assignment yet this turn (e.g. the first enemy in slot order is PACK) falls to WOUNDED — PACK enemies effectively lead the hunt on the weakest hero.
- An intent assigned to a hero who later cloaks (Smoke Column item) is re-picked at resolve time; an intent whose hero merely dropped to low HP is NOT re-picked (still legal).
- Hero-side forced taunt targeting overrides even support abilities' picks: a healer's `selected_target_id` becomes the taunter, so targeted heals fall back to the lowest-HP ally (`combat_manager.gd:991-996`) — the taunt sentence "can only target the taunter" costs support heroes their choice, not their action.
- Frozen repeats re-pick targets fresh every repeat round (manual for heroes, personality for enemies) — only the die result is locked.
- `curseDice` is listed as needing a single-hero pick, but the curse mechanic itself is unimplemented (see findings).

## ⚠ Open findings

<!-- AUDIT-LINKS:targeting -->
- [A-008](../audit/INTERACTION_AUDIT.md#a-008) - [dead] curseDice - wired 5th die-tamper with zero data
