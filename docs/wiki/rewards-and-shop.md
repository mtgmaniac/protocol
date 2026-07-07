# Rewards & Shop

> Part of the [Overload Protocol wiki](INDEX.md). See also: [Items & Gear](items-and-gear.md), [Relics](relics.md), [Beats & Events](beats-and-events.md), [Protocol economy](protocol-economy.md), [Heroes](heroes.md) (evolution stops).

## How it works

### Reward draft flow (after every battle win)

1. `reward_screen.gd` (`scripts/ui/reward_screen.gd:109-110`) calls `GameState.prepare_battle_rewards()` if no offer is pending → `_roll_reward_item_ids()` (`scripts/autoloads/GameState.gd:1159-1184`).
2. **Three cards** are rolled (consumables + gear only). For each card: pick a rarity from the round's weight table, then a random un-offered item of that rarity; if the rarity pool is empty, fall back to any available consumable/gear (`_pick_any_available_reward`, `GameState.gd:1267-1272`).
3. Player single-selects a card (corner brackets light up) and presses CONFIRM (`reward_screen.gd:449-547`).
   - **Gear** pops an "EQUIP … TO" chooser listing the squad (`_show_gear_target_overlay`, `reward_screen.gd:559-634`); the equip is finalized on CONFIRM → `gear_by_unit[unit_id]` (`GameState.claim_reward`, `GameState.gd:850-856`). Mid-run re-equip is REJECTED (DECISIONS_RESOLVED #15).
   - **Consumables** go to the squad bag (cap 3). A full bag pops a discard chooser ("BAG FULL — DISCARD ONE", `reward_screen.gd:644-722`); the swap resolves in `claim_reward` (`GameState.gd:857-863`).
4. `claim_reward` clears the offer, then `award_battle_xp()` runs and the flow routes to the evolution screen (if a stop is pending) or the next battle/beat (`reward_screen.gd:740-754`).
5. **Zero-options guard**: an empty offer auto-resolves through `choice_screen_guard.gd` — XP is still awarded and the run routes on (`reward_screen.gd:215-217,886-891`).

### Rarity ladder

`DRAFT_RARITY_BY_ROUND` (`GameState.gd:85-95`), keyed by battle number; row 5 is missing because battle 5 is the relic cache:

| Round | common | uncommon | rare | legendary |
|---|---|---|---|---|
| 1 | 85 | 10 | 4 | 1 |
| 2 | 70 | 20 | 8 | 2 |
| 3 | 55 | 28 | 14 | 3 |
| 4 | 40 | 35 | 20 | 5 |
| 6 | 35 | 35 | 22 | 8 |
| 7 | 28 | 38 | 26 | 8 |
| 8 | 20 | 40 | 30 | 10 |
| 9 | 15 | 38 | 32 | 15 |
| 10 | 10 | 35 | 35 | 20 |

- Rolls use the run-seeded `_reward_rng` (`GameState.gd:97,1204-1214`) — reproducible under a sim seed.
- **SUPPLY GRADE +2** (flagged route fork reward): the ladder reads **two rows deeper**, capped at row 10; if the shifted row is 5 (the missing relic row) it steps past to 6. One-shot — consumed by the next draft; a flagged battle 5 spends it on the relic cache, which has no ladder (`GameState.gd:1161-1173`).
- **Curated Cache** relic: common items are excluded from every pick (`GameState.gd:1229,1256`); a rolled "common" upgrades via the any-available fallback.
- There is no common gear in data, so common slots are always consumables.

### Relic cache at battle 5

- `RELIC_ONLY_ROUND := 5` (`GameState.gd:81`). When `current_battle == 5` and `drafted_relic_count() == 0`, the reward roll returns **2 relic choices** instead (`RELIC_CHOICE_COUNT := 2`, `GameState.gd:83,1166-1168`) and the screen re-titles to "INTERCEPT: RELIC CACHE" in event chrome (`reward_screen.gd:814-815`).
- Boss relics never appear in the draft (`_roll_relic_choice_ids` skips `boss_relic`, `GameState.gd:1194-1199`).
- A **Starting Directive** boss relic (pkg5, picked at DEPLOY) does not count as drafted (`drafted_relic_count`, `GameState.gd:1152-1156`) and is excluded from the offer (`GameState.gd:1250-1252`) — this is the 2026-07-06 battle-5 soft-lock fix, regression-pinned. A directive run legitimately ends with two relics.
- Claiming a second drafted relic is refused (`claim_reward`, `GameState.gd:864-868`).

### XP awards (run through the reward screen)

- Awarded once per win by `award_battle_xp()` (`GameState.gd:974-1006`), including on the guard's auto-resolve path.
- Per unit: alive at battle end → `20 + round(avg effective roll)` (`XP_SURVIVAL_BONUS := 20`); dead → `round(avg effective roll)` alone. Effective rolls are recorded per resolution (`record_hero_effective_roll`, `GameState.gd:955-961`).
- Thresholds: `XP_TO_EVOLVE = 100`, `XP_TO_DIRECTIVE = 250` (`GameState.gd:72-74`). Fully progressed units (evolution + directive) stop accruing. One progression stop per win; overshoot defers (`_queue_evolution_after_win`, `GameState.gd:1009+`).

### In-battle "shop" surface (loadout menu)

There is no money shop. The Item footer button opens the **LOADOUT** menu (`scripts/ui/loadout_menu.gd`): 3 consumable slots + a display-only relic row; tapping a filled slot begins the use flow (cost 1 Protocol, see [items-and-gear.md](items-and-gear.md)); long-press opens the InspectPopup. Consumable sources beyond drafts: Field Cache relic (battle start), Scavenger Manifest relic (first kill), intercept/fork effects (`GameState.gd:581` and the INTERCEPT_CARDS/BATTLE_MODIFIERS tables).

### Protocol carryover at the seam

On victory, Overflow Buffer banks `floor(unspent × 50%)` (`battle_scene.gd:1171-1175`, `GameState.gd:757-767`); the next battle's setup withdraws it before Protocol Tap gear is added and the cap is applied (`battle_scene.gd:230,247`).

## Why it works that way

- The ladder's missing row 5 encodes "battle 5 is the relic beat" structurally rather than as a special case at roll time.
- Rewards roll from the seeded `_reward_rng` so full runs are reproducible in the balance sim (INVARIANTS #1).
- The one-choice-then-confirm card flow with the equip/discard choosers front-loaded at selection time keeps the commit button single-purpose (Direction-05 reward card spec, `reward_screen.gd:1-14`).
- The zero-options guard is a permanent fixture (TRUTH §Run structure): a playtest build must never soft-lock on a dead picker; a guard firing is always an offer-roll bug.

## What it replaced

- `relics.is_empty()` draft guards → `drafted_relic_count()` (battle-5 soft-lock fix, 2026-07-06).
- Per-unit consumable inventories → squad-wide bag with cap-3 swap flow (item roster refactor `a21eaf4`).
- XP consumable items — removed entirely; XP flows only through the per-win award above.
- Hover tooltips on reward cards → effect-pip rows + InspectPopup (`6861232`).

## File locations

- `scripts/ui/reward_screen.gd` (cards, selection, equip/discard overlays, claim/advance)
- `scripts/autoloads/GameState.gd` (ladder, rolls, claim, relic cache, XP, carryover)
- `scripts/ui/item_card.gd` / `scripts/ui/item_type_frame.gd` (card + silhouette assets)
- `scripts/ui/loadout_menu.gd` (in-battle bag)
- `scripts/ui/choice_screen_guard.gd` (zero-options guard)

## Known edge cases

- Duplicate consumables CAN be drafted; duplicate gear can be drafted and stacked on one unit (no uniqueness guard across battles — only within one 3-card offer).
- Field Cache / Scavenger Manifest drops pass the HELD bag as an exclusion list — they never duplicate a held consumable and can silently fizzle when the filtered pool is empty; Curated Cache filters commons out of these drops too, though its desc says "Rewards".
- A flagged battle 5 consumes SUPPLY GRADE on the relic cache (which ignores it) — by design, documented at `GameState.gd:1161-1163`.
- Re-entering the reward screen after the relic draft was claimed rolls an empty offer on purpose (`GameState.gd:1169`); the guard resolves it.
- Defeat skips all of this — `finish_run("defeat")` routes straight to run end; Overflow Buffer only banks on victory.

## ⚠ Open findings

<!-- AUDIT-LINKS:rewards-and-shop -->
- [A-071](../audit/INTERACTION_AUDIT.md#a-071) - [confusing] consumable drops filter differently from drafts
