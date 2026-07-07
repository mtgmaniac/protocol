# Shields and Ward (Firewall)

> Part of the [Overload Protocol wiki](INDEX.md). See also: [statuses-and-chips.md](statuses-and-chips.md), [keywords.md](keywords.md), [combat-resolution.md](combat-resolution.md), [bosses.md](bosses.md), [relics.md](relics.md).

## How it works

### Shields — the per-side one-round model (DECISIONS_RESOLVED #2)

A shield is a stack `{amt, skip_next_tick}` appended by `_add_shield_stack` (`scripts/battle/combat_manager.gd:873`); `state["shield"]` is the derived total. **Shields last one opposing action phase:**

- **Hero-phase grants** (hero abilities, items): `skip_next_tick = false` → they absorb through the same round's enemy phase and expire at that round's end tick.
- **Enemy-phase grants** (enemy abilities `shield`/`shieldAlly`/`shieldAllyAll`, Accrete, Bulwark Aura, MANTLE TYRANT's plate): passed `survives_current_tick = true` → they skip the imminent tick and cover exactly one hero phase (`:1518-1531`, `:698-704`, `:230`).
- Expiry lives in `_tick_state` (`:2517-2526`): every stack not flagged (and not owned by a `shields_persist` state) dies at the round-end tick.

No shield duration field exists in data — the 2026-07-07 audit found zero `shT` offenders (TRUTH rule 5).

**The single named exception — `shieldsPersist`:** the Mantle Core relic sets `shields_persist` on every hero (`:397-408` — note the block is duplicated, see findings) and `setup_battle` sets it on MANTLE TYRANT (`:38-41`). Persistent shields skip expiry entirely and stack round over round; only damage (or Breach/wipeShields) removes them. Audit-pinned: `_run_shield_timing_regression` (`ability_audit.gd:671`), boss Tyrant 6/12 stacking (`:1546`).

### Absorption (`_damage_state`, `combat_manager.gd:1843-1874`)

Damage walks the stacks in grant order, draining each; emptied stacks are removed and the total recomputed. Gear `shieldPierce` gives the attacker a budget of N points that skim past shields before absorption (`:1849`). Absorbed damage emits a `block` event ("absorbs N with shields"). Salvage Rig (boss relic): +1 Protocol when a hit fully breaks an enemy's shield (`:1867`).

Shield-relevant modifiers resolve BEFORE absorption: the Mark ×1.5 multiplier and the flat vs-frozen/vs-burning bonuses are applied to the amount first, so shields eat the boosted number.

### Pierce vs Breach vs wipeShields (kept distinct, DECISIONS_RESOLVED K2)

| Verb | Effect on shield | Where |
|---|---|---|
| **Pierce** (`ignSh`) | ignored, stays up, still blocks others | `:1841` |
| **Breach** | destroyed on the target BEFORE the damage | `_breach_shields :1392` |
| **breachAll** | every enemy stripped first, even on single-target hits | `:1241` |
| **wipeShields** (enemy/boss) | every hero shield cleared before the hit | `_wipe_all_hero_shields :1967` |

Breach against a `shields_persist` target destroys the accumulated plate — Breach and Pierce are the sanctioned counterplay to MANTLE TYRANT.

### Grant-side riders

- Overcharge Mesh directive: +2 on every shield any squad member gains while the carrier lives (`:876`).
- Rampart: +2 on shields THIS hero grants (`:963`).
- Bunker Doctrine: allies receiving this hero's shields also gain Spike 3 (`:1156`).
- Field Triage / heal-shield gear / Aegis Field: heals also plate the target (`:2233-2249`).
- Entrench directive / Combat Plating gear: battle-start shields (`:451-464`).

### Ward — displayed "Firewall" (internal field `ward`)

**Rule:** blocks the next ABILITY that targets the unit, then breaks. Not damage-based — one Firewall eats the entire ability including riders.

- Application: `_apply_ward` (`:1987`) — hero `ward`/`wardTgt`, enemy `ward`, items, intercepts, Overseer's THE COURT round-start rule (`:219-227`, no double-stack: skipped while already warded).
- Consumption: `_ward_blocks_hostile` (`:1995`). The per-ability set `_ability_ward_blocked_ids` (`:1984`, cleared at the start of every ability, `:927`, `:1501`) makes every hostile component of the SAME ability (damage, burn, debuff, jam, freeze, taunt…) fail together against that carrier while consuming only one Firewall.
- AoE: a blast including a warded unit is blocked for that unit only; other targets take full damage (`:1226-1231`, audit `:792`).
- Chain: jumps continue past a ward-blocked primary — the ward protects its carrier only (`:1278-1280`); a warded jump target consumes its own Firewall.
- What Firewall does NOT stop: burn ticks, aura/chip damage, Spike retaliation (no targeting), Siphon riding a blocked hit (the hit didn't connect, so no drain either — `attack_connected` stays false), and boss standing rules (Root Access rewrites through it, `:1336`).
- Enemy Firewall census (TRUTH): exactly 10 instances (6 Veil, 4 Synod). Hero-side: 3 abilities plus items/gear.

Feedback: ward consume = hex flash + "✕ NEGATED" (`battle_feedback.gd:447, 521`); `block` events carry amount 0 for a ward vs amount N for shield absorption (`_build_floating_text :337`).

## Why it works that way

- Per-side expiry (rather than strict same-round) exists so enemy-granted shields can ever absorb anything — they'd otherwise die at the tick before the next hero phase (comment at `:863-872`; CONFIRMED by Kev, DECISIONS #2).
- Ward became deterministic (from Counterspell-%) so a player can count blocks; "blocks the next ability, then breaks" is the one-sentence rule (INVARIANTS #5).
- Naming: internal `ward` field is frozen; display says Firewall everywhere (TRUTH doc adjudications).

## What it replaced

- Counterspell-% → deterministic Ward → renamed Firewall (TRUTH).
- Multi-round `shT` shield durations — never present in current data; the rule is doc-enforced (DECISIONS #2, zero offenders).
- The pkg8.1 shield-chip cut — reversed; the ⬡ chip is canon and drops at the per-side tick (DECISIONS #16).

## File locations

- `scripts/battle/combat_manager.gd` — grant/absorb/expiry, ward, breach, wipe
- `scripts/battle/battle_card_view.gd` — shield chip + shield-aware previews (`compute_preview_for_unit :196`)
- `scripts/battle/battle_feedback.gd` — block/hex-flash feedback
- `data/raw/keywords.data.json` — shield / pierce / breach / ward defs

## Known edge cases

- The Overseer keeps its Firewall while an ally lives but never stacks a second one; killing the escort turns the rule off (`:219`).
- MANTLE TYRANT's plate is granted with `survives_current_tick = true` AND `shields_persist` — either alone would suffice; belt-and-suspenders.
- Preview code intentionally omits enemy shields being cast this turn (they can't absorb hero damage this round, `battle_card_view.gd:294-299`).
- A hit fully absorbed by shields still: consumes Mark, triggers Spike, stamps SPITEFUL, and counts as "connected" for Siphon.
- Breach on a shieldless target is a silent no-op (`destroyed <= 0` early return, `:1396`) — no event, no log.
- `wipeShields` fires before the damage when the ability also deals damage (`:1563`), and alone when it doesn't (`:1605`).

## ⚠ Open findings

<!-- AUDIT-LINKS:shields-and-ward -->
- [A-032](../audit/INTERACTION_AUDIT.md#a-032) - [dead] duplicated shieldsPersist battle-start block
- [A-033](../audit/INTERACTION_AUDIT.md#a-033) - [degenerate] Aegis Field triggers on enemy heals
- [A-034](../audit/INTERACTION_AUDIT.md#a-034) - [degenerate] Mantle Core makes per-round shields unbounded
- [A-035](../audit/INTERACTION_AUDIT.md#a-035) - [confusing] Salvage Rig never fires on breach-destroyed shields
