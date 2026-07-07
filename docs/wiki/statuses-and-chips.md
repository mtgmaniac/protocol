# Statuses and Chips

> Part of the [Overload Protocol wiki](INDEX.md). See also: [keywords.md](keywords.md), [combat-resolution.md](combat-resolution.md), [shields-and-ward.md](shields-and-ward.md), [heroes.md](heroes.md), [enemies.md](enemies.md).

## How it works

### Chip doctrine

The card chip row (`BattleCardView._build_compact_status_tokens`, `scripts/battle/battle_card_view.gd:384`) renders exactly these tokens, cap 3 with a +N overflow badge:

| Chip | Trigger | Render | Priority |
|---|---|---|---|
| Burn | `burn > 0` and `burn_turns > 0` | ☠ + summed value (numeric) | 0 |
| Shield | `shield > 0` | ⬡ + total (numeric) — RESTORED per Kev, DECISIONS_RESOLVED #16 | 1 |
| Mark | `marked` | `MARK` (named) | 1 |
| ±Roll | net `roll_buff + perm_roll_buff − rfe − perm_rfe ≠ 0` | 🎲 + signed delta (numeric) | 2 |
| Firewall | `warded` | `FIREWALL` (named) | 3 |
| Taunt | hero has `lured_by_id` (enemy-side taunt only) | `TAUNT` (named) | 3 |
| DOWN | `dead` | `DOWN` (named, replaces all others) | 99 |

Everything else keeps its own display channel (TRUTH §UI & feedback): Cloak = ghosted portrait · Freeze/Petrify = die crust (ice cyan / stone gray) · Jam = die tint + "JAM ≤10" · Rewrite/Hijack = pending die marker + readout entry · Spike = readout pip only. A self-taunting hero or enemy (`taunting`) renders **no** chip — only lured heroes get the TAUNT chip.

The persistent-chip doctrine is **six** chips (burn, mark, ±roll, firewall, shield, **Taunt**) — Kev ruled the Taunt chip canon (ruling NK-07, 2026-07-08), so TRUTH.md and the code are correct; the fix-brief's "five-chip" ground truth was the stale side. Audit finding A-028 is closed as a doc-sync artifact.

### Instance-timer model (DECISIONS_RESOLVED #3, per Kev 2026-07-06)

Roll buffs (`rfm` hero / `erb` enemy — identical), roll-downs (`rfe`) and Burn are **independent instances**: each application is its own stack with its own remaining clock; the effective value is the SUM of live stacks; nothing refreshes to max.

- **Roll buffs** (`roll_buff_stacks`, `combat_manager.gd:901-923`): every stack loses a turn at EVERY round-end tick, including the cast round. Contract: an Nt instance cast on turn T is live turns T..T+N−1. Canonical case (audit-pinned, `ability_audit.gd:2609`): +3/2t on turn 1 plus +5/2t on turn 2 → totals 3, 8, 5, 0. Consequence: a 1t buff cast mid-round never shapes a roll — the three authored 1t casualties were corrected to 2t (TRUTH rule 10).
- **RFE / roll-downs** (`rfe_stacks`, `:887-898`): same clocks but stacks carry `skip_next_tick: true` — they survive the tick of the application round, so an Nt roll-down bites N subsequent rolls.
- **Burn** (`burn_stacks`, `:2252-2285`): each stack skips its application round's tick (an Nt burn deals N ticks over the N following rounds), then decrements per tick; `turns >= PERMANENT_BURN_TURNS (9999)` marks a permanent stack (plagueProtocol relic) that never expires and Detonate can't consume. The tick damage is the sum of live non-skipped stacks (`get_expected_burn_tick :2428` — single source shared with the HP preview), plus enemy-side amplification (burnAmplified relic + the max hero `gear_burn_bonus`, `:2440`). The display aggregates ONE chip: summed value, longest remaining clock (`_refresh_burn_totals :2277`).

### Every persistent / semi-persistent state key (`_create_runtime_state`, `combat_manager.gd:761`)

| Key | Meaning | Expiry |
|---|---|---|
| `shield`, `shield_stacks`, `shields_persist` | shields — see [shields-and-ward.md](shields-and-ward.md) | per-side round tick |
| `burn`, `burn_turns`, `burn_stacks` | DoT instances (chip shows sum / longest) | own clocks; perm never |
| `rfe_stacks`, `perm_rfe` | roll-downs; `perm_rfe` = Signal Jam relic (permanent) | own clocks / never* |
| `roll_buff`, `roll_buff_stacks`, `perm_roll_buff` | roll-ups; perm = gear/relic/intercept | own clocks / never |
| `marked`, `mark_consumed_this_hit` | Mark; consumption flag read by Salvage Directive | until consumed |
| `warded` | Firewall | until it blocks one ability |
| `cloaked` | Cloak | until damage dealt / AoE hit |
| `taunting` | self-taunt — **both sides cleared each round end** (ruling NK-08, 2026-07-08; hero taunt is no longer a permanent stance) | round-end tick |
| `lured_by_id`, `lure_skip_next_tick` | enemy-side taunt on a hero | exactly one hero phase |
| `spike`, `spike_skip_next_tick` | Spike (max, not sum) | end of round (per-side) |
| `jam_cap`, `jam_skip_next_tick` | Jam (lowest cap wins) | one reveal |
| `rewrite_pending`, `rewrite_skip_next_tick` | Rewrite → 3 | one reveal |
| `hijack_pending`, `hijack_skip_next_tick` | Hijack (enemy) | one reveal |
| `die_freeze_turns`, `frozen_die_value`, `die_freeze_repeat_this_round`, `freeze_flavor` | Freeze = repeat | one repeat spent per round-end tick |
| `rampage_charges` | next damaging hit ×2 per charge (`:1548`) | consumed per hit |
| `accrete` | +N shield at the start of its enemy phase (`:698`) | while alive |
| `cursed` | DEAD — cleared with no effect (`battle_scene.gd:562`) | n/a |
| `dmg_scale` | enemy damage scale (summon/elite tuning) | battle |
| `last_attacker_id` | SPITEFUL grudge (cleared when that hero dies `:2161`) | on hero death |
| `momentum_bonus`, `vanish_used`, `decloak_execute_pending`, `execute_threshold_pct`, `nat20_twice`, `forced_nat20_pending` | directive/relic one-shots | various |
| `gear_*` | gear passives (`_apply_gear_passive :328`) | battle |

*`perm_rfe` is cleared if the unit dies (`_clear_active_statuses_for_down_state :2205`) and is NOT re-applied on revive/rebuild — see findings.

### Down / revive

Death clears every active status (`:2175`); `_revive_state` (`:2064`) returns the unit at `pct%` max HP with burn/buffs/shields/freeze zeroed. Gear flags and `perm_roll_buff` survive on heroes.

### The skip-next-tick idiom

Every status granted during the enemy phase (shields, spike, lure, jam, rewrite, hijack primes) carries a skip flag so it survives the imminent round-end tick and covers exactly one hero phase (`_tick_state :2446`). This is the mechanical core of the per-side "one round" reading (DECISIONS_RESOLVED #2).

## Why it works that way

- Instance timers replaced refresh-to-max because "recast = permanent" was illegible and burn stacking unpredictable (DECISIONS #3 rationale).
- The chip cap (3 + overflow) and the one-channel-per-status rule keep a 1080×2400 card readable (INVARIANTS #5, #7).
- The Shield chip's absence was reversed by Kev (DECISIONS #16); the renderer's shield palette had survived the pkg8.1 cut, only the token source was restored.
- Jam/Rewrite/Hijack render on the die, not the card, because they are die statuses — the complexity budget for die-tampering is capped at four mechanics (INVARIANTS #4).

## What it replaced

- Refresh-to-max buff/DoT timers (dead, DECISIONS #3).
- The pkg8.1 shield-chip cut (reversed, DECISIONS #16).
- A legacy plain-text status list (`SH/BRN/RFE/CLOAK/FROZEN/RAGE/CURSED/TAUNT/...`) still assembled — but never rendered — in `battle_card_view.update_card_view` (`battle_card_view.gd:31-90`, dead code, see findings).
- Venom/Decay burn flavors (dead; a `venom` kind still lingers at `scripts/ui/compact_unit_card.gd:710`, see findings).

## File locations

- `scripts/battle/combat_manager.gd` — state keys, stacks, ticks
- `scripts/battle/battle_card_view.gd` — chip tokens (`_build_compact_status_tokens`)
- `scripts/ui/compact_unit_card.gd` — chip renderer
- `scripts/ui/effect_pip.gd` — ability readout pips (distinct from status chips)
- `data/raw/primers.data.json` — status primers

## Known edge cases

- The burn chip shows the SUM at the LONGEST clock — two stacks 4/1t + 2/3t display "6 ×3t" though next tick deals 6 and later ticks 2.
- The ±Roll chip nets buffs against debuffs into a single signed value (`battle_card_view.gd:427`) — a +3 buff and −3 debuff render no chip at all.
- Rampage stacks additively as charges but each hit consumes exactly one charge for a flat ×2 (`combat_manager.gd:1548`), not ×2 per charge.
- Feedback directive damage fires before rfe decay so a 1-turn roll-down still deals its chip damage (`:2530`); the `feedback_per_round` flag clears when the last rfe stack expires (`:2548`).
- Enemy self-taunt (`enemySelfTaunt`) shows no chip and no die marker — the only signal is the log line and targeting lines.

## ⚠ Open findings

<!-- AUDIT-LINKS:statuses-and-chips -->
- [A-026](../audit/INTERACTION_AUDIT.md#a-026) - [dead] venom/fire/bleed chip kinds no producer emits
- [A-027](../audit/INTERACTION_AUDIT.md#a-027) - [dead] write-only legacy status strings (CURSED/RAGE)

Resolved (2026-07-08 fix pass): [A-028](../audit/INTERACTION_AUDIT.md#a-028)
