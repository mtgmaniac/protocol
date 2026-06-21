# Reward draft — sliding rarity ladder

After each battle win, the player sees a **Supply Cache** (items/gear) or a **Relic** milestone. Each of the three cache slots rolls rarity independently using the table for the **round just cleared** (1-based).

**Rules**

- Relics **never** appear before round 5.
- Round **5** is **relic-only** — two relic choices, no consumables or gear.
- Rounds **6+** resume item drafts with higher-tier weights (long ops cap at round 10 row).

## Benchmark table

Percentages per slot (three independent rolls per draft).

| Round | Common | Uncommon | Rare | Legendary | Notes |
|------:|-------:|---------:|-----:|----------:|-------|
| **1** | **85%** | **10%** | **4%** | **1%** | Baseline |
| 2 | 70% | 20% | 8% | 2% | |
| 3 | 55% | 28% | 14% | 3% | Pre-relic ramp |
| 4 | 40% | 35% | 20% | 5% | Last item milestone before relic |
| **5** | — | — | — | — | **Relic draft only** (pick 1 of 2) |
| 6 | 35% | 35% | 22% | 8% | Post-relic “hero tier” |
| 7 | 28% | 38% | 26% | 8% | |
| 8 | 20% | 40% | 30% | 10% | |
| 9 | 15% | 38% | 32% | 15% | |
| 10 | 10% | 35% | 35% | 20% | Peak item tier (boss-adjacent fights) |

Rounds **11+** on longer operations reuse the **round 10** row.

## Implementation

- Godot: `scripts/autoloads/GameState.gd` — `DRAFT_RARITY_BY_ROUND`, `RELIC_ONLY_ROUND`, `RELIC_CHOICE_COUNT`, `_pick_draft_rarity_for_round()`
- Reward flow: `GameState.prepare_battle_rewards()` → `RewardScreen.tscn` after each win (except run-complete)

## Design intent

- Early fights stay mostly common so day-one runs aren’t solved by legendaries.
- Rarity curve accelerates into the mid-op relic spike at fight 5 (evolution + relic timing).
- Post-relic drafts stay strong so the back half of a 10-fight op still feels rewarding without random early relics.
