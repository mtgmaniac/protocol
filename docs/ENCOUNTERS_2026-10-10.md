# Encounters, battle by battle (2026-10-10)

Read from `main` at `c161c32` (DEMO v0.3). A read-only listing: nothing was changed to make it.

Sources: `data/raw/battle-modes.json` (the ten battles of each operation), `data/raw/enemies.data.json`
(units and kits), `data/raw/traits.data.json` (who has a trait), `DataManager._classify_enemy_role` (the
slot pools), `GameState._resolve_battle_comps` and `_roll_slot_names` (how a lineup is rolled),
`GameState.BATTLE_MODIFIERS` and `INTERCEPT_CARDS` (what a beat can change), and the roll-windows table in
`docs/TRUTH.md` (G-55) for each unit's role.

## How to read it

- **A unit's tag** is `[role, trait]`. The role is the roll-windows table's (regular, elite, support, tank,
  boss). `no trait` means the unit has none.
- **A slot name in code font** (`fodder`, `elite`, `support`, `heavy`, `heavyOrElites`) is the encounter data's
  own word for a random slot. It is a different classifier from the roll-windows roles and the two disagree on
  some units (see Oddities 2).
- **Weighting.** Every pick is uniform over its pool. The pools carry no weights.
- **"Share of runs"** is how often the unit is in that battle at least once, measured over 200,000 simulated
  run rolls per operation. The simulation is a Python copy of the roll rules below, not the game's own random
  stream; figures are good to about half a point. It leaves out forks and intercepts.

## How a lineup is built

1. All ten lineups are rolled once, at run start. A battle is either **fixed** (its units are named in the
   data) or a list of **slots**.
2. **Slot pools**, per operation: `fodder` is every unit with the simple AI; `heavy` is any other unit with
   90 HP or more; `support` is any remaining unit that aids its allies in two or more of its five roll
   windows; `elite` is the rest. The five bosses are in no pool.
3. A plain slot picks one unit from its pool. Two slots of the same kind do not avoid each other, so
   `fodder, fodder` can be two of the same unit.
4. `heavyOrElites` is a coin flip: one `heavy` pick, or two `elite` picks. The second elite avoids the first
   when the pool has another unit.
5. An operation with no `support` unit draws that slot from its `elite` pool (Mantle Hunt).
6. **No back-to-back repeat:** a slot battle that rolls the same lineup as the battle before it is rolled
   again, up to 12 times. This shifts some shares below (Facility battle 2, Veil battle 5).
7. A battle fields at most 3 enemies.

## What can change who appears

- **Beats.** Each run has 3 beats, placed after 3 of battles 2, 3, 4, 6, 7, 8 (each gap has one in 50% of
  runs). Each is a route fork or an intercept, with at least one of each per run. A beat after battles 2 to 4
  is minor; after 6 to 8 it is major. So battles 1, 2 and 6 are never touched, and battle 10 only by the
  Prisoner Exchange.
- **Route fork.** The player chooses the standard route (the lineup as rolled) or the flagged route (the same
  lineup, one battle modifier, and rewards two rarity rows deeper). The modifier is drawn from the ten below,
  never the same one twice in a run. Two of them change the lineup:
  - **OVERRUN:** one more `fodder` pick joins. Offered only when the lineup has 1 or 2 units.
  - **ELITE PRESENCE:** the first unit in the lineup that is not from the `elite` pool is replaced by an
    `elite` pick. Offered only when such a unit exists.
  - The other eight leave the lineup alone: HARDENED (enemies start with 8 shield), JAMMING FIELD (hero dice
    capped at 10 on round 1), FEROCITY (+2 enemy damage), DEAD MAN'S CHARGE (4 damage to a random hero per
    enemy death), BLACKOUT (Protocol income from round 3), SEALED SUPPLIES (items cost 1 more), REGENERATIVE
    (enemies restore 3 HP each enemy phase), FIREWALLED (`support` units start with a firewall; offered only
    when the lineup has one).
- **Intercepts.** One card changes the lineup: **PRISONER EXCHANGE** (major deck, so after battle 6, 7 or 8).
  Releasing the prisoner removes the last-listed unit from the next battle (when it has more than one) and
  puts ELITE PRESENCE on the battle after that. Five more cards change the enemies' state but not who they
  are: SALVAGE CACHE (HARDENED), WRECKED TRANSPORT (DEAD MAN'S CHARGE), CRYO POD (BLACKOUT), DECOY BEACON
  (enemies skip their first phase), FIRING SOLUTION (highest-HP enemy starts marked at 90% HP), UNSTABLE
  REACTOR (enemies start at 70% HP).
- **Summons, during a battle.** A unit with a summon line calls its unit when it rolls a 20, at the chance
  shown in the roster, if fewer than 3 enemies are alive. The summoned unit takes a dead unit's place or a
  free one. Summoned units keep their trait (a summoned Slag Hound has Feral).
- **Boss rules, during battle 10.** The Scrapmaster stands a destroyed Scrap Drone back up at 50% HP every
  2nd enemy phase. The Hive Matriarch adds a Bloodmite every 3 rounds while fewer than 3 enemies are alive.
- **Tutorial.** Not part of an operation: one Scrap Drone, then two.

## Facility Sweep (`facility`)

Slot pools: `fodder` = Scrap Drone, Rust Drone, Static Skimmer; `elite` = Patrol Enforcer, Volt Enforcer; `support` = Shield Enforcer; `heavy` = Heavy Warden.

| Unit | Role (roll windows) | Slot pool | HP | Trait | Summons on a 20 | Fixed in battle | Units per run | Runs with one or more |
|---|---|---|--:|---|---|---|--:|--:|
| Scrap Drone | regular | `fodder` | 35 | none | none | 1, 10 | 5.24 | 100% |
| Rust Drone | regular | `fodder` | 45 | none | none | 1 | 3.24 | 100% |
| Static Skimmer | regular | `fodder` | 40 | none | none | none | 2.53 | 96% |
| Patrol Enforcer | elite | `elite` | 60 | **Vigilant**: When an ally is hit, gains 2 shield. | none | none | 2.50 | 97% |
| Shield Enforcer | support | `support` | 70 | none | none | 5 | 3.00 | 100% |
| Heavy Warden | tank | `heavy` | 95 | none | none | none | 2.50 | 100% |
| Volt Enforcer | elite | `elite` | 65 | **Volatile**: When it dies, deals 4 damage to each hero. | none | none | 2.50 | 97% |
| Scrapmaster | boss | none (boss) | 140 | none | none | 10 | 1.00 | 100% |

A run fields 22.5 enemy units in all, 5.0 of them with a trait, and 4.5 of its 10 battles hold at least one
trait unit (before beats and summons).

| Battle | Kind | Enemy slots, in order | Share of runs with the unit | Beats that can change it |
|--:|---|---|---|---|
| 1 | fixed | 1. Fixed: Scrap Drone [regular, no trait]<br>2. Fixed: Rust Drone [regular, no trait] | Rust Drone 100%<br>Scrap Drone 100% | None: no beat can come before this battle. |
| 2 | slots: `fodder`, `fodder` | 1. `fodder`: Scrap Drone [regular, no trait] / Rust Drone [regular, no trait] / Static Skimmer [regular, no trait], 1 in 3 each<br>2. `fodder`: Scrap Drone [regular, no trait] / Rust Drone [regular, no trait] / Static Skimmer [regular, no trait], 1 in 3 each | Static Skimmer 71%<br>Rust Drone 43%<br>Scrap Drone 43% | None: no beat can come before this battle. |
| 3 | slots: `elite`, `fodder` | 1. `elite`: Patrol Enforcer [elite, Vigilant] / Volt Enforcer [elite, Volatile], 1 in 2 each<br>2. `fodder`: Scrap Drone [regular, no trait] / Rust Drone [regular, no trait] / Static Skimmer [regular, no trait], 1 in 3 each | Volt Enforcer 50%<br>Patrol Enforcer 50%<br>Scrap Drone 33%<br>Static Skimmer 33%<br>Rust Drone 33% | A minor beat lands before it in 50% of runs (fork or intercept).<br>Fork, OVERRUN: adds one more `fodder` pick (Scrap Drone / Rust Drone / Static Skimmer).<br>Fork, ELITE PRESENCE: replaces the `fodder` pick with Patrol Enforcer / Volt Enforcer. |
| 4 | slots: `heavyOrElites` | 1. `heavyOrElites`, 50/50: ONE `heavy` pick (Heavy Warden [tank, no trait], always); or TWO `elite` picks (Patrol Enforcer [elite, Vigilant] / Volt Enforcer [elite, Volatile], 1 in 2 each; the second differs from the first) | Heavy Warden 50%<br>Patrol Enforcer 50%<br>Volt Enforcer 50%<br>Lineup size: 1 unit 50%, 2 units 50% | A minor beat lands before it in 50% of runs (fork or intercept).<br>Fork, OVERRUN: adds one more `fodder` pick (Scrap Drone / Rust Drone / Static Skimmer).<br>Fork, ELITE PRESENCE: replaces the heavy with Patrol Enforcer / Volt Enforcer on a heavy roll; not offered on a two-elite roll. |
| 5 | fixed | 1. Fixed: Shield Enforcer [support, no trait]<br>2. Fixed: Shield Enforcer [support, no trait] | Shield Enforcer 100% | A minor beat lands before it in 50% of runs (fork or intercept).<br>Fork, OVERRUN: adds one more `fodder` pick (Scrap Drone / Rust Drone / Static Skimmer).<br>Fork, ELITE PRESENCE: replaces Shield Enforcer with Patrol Enforcer / Volt Enforcer. |
| 6 | slots: `elite`, `fodder`, `fodder` | 1. `elite`: Patrol Enforcer [elite, Vigilant] / Volt Enforcer [elite, Volatile], 1 in 2 each<br>2. `fodder`: Scrap Drone [regular, no trait] / Rust Drone [regular, no trait] / Static Skimmer [regular, no trait], 1 in 3 each<br>3. `fodder`: Scrap Drone [regular, no trait] / Rust Drone [regular, no trait] / Static Skimmer [regular, no trait], 1 in 3 each | Static Skimmer 56%<br>Scrap Drone 56%<br>Rust Drone 55%<br>Volt Enforcer 50%<br>Patrol Enforcer 50% | None: no beat can come before this battle. |
| 7 | slots: `heavy`, `fodder` | 1. `heavy`: Heavy Warden [tank, no trait], always<br>2. `fodder`: Scrap Drone [regular, no trait] / Rust Drone [regular, no trait] / Static Skimmer [regular, no trait], 1 in 3 each | Heavy Warden 100%<br>Static Skimmer 33%<br>Scrap Drone 33%<br>Rust Drone 33% | A major beat lands before it in 50% of runs (fork or intercept).<br>Fork, OVERRUN: adds one more `fodder` pick (Scrap Drone / Rust Drone / Static Skimmer).<br>Fork, ELITE PRESENCE: replaces the `heavy` pick with Patrol Enforcer / Volt Enforcer.<br>Prisoner Exchange taken after battle 6: drops the `fodder` pick (the last slot). |
| 8 | slots: `heavy`, `elite` | 1. `heavy`: Heavy Warden [tank, no trait], always<br>2. `elite`: Patrol Enforcer [elite, Vigilant] / Volt Enforcer [elite, Volatile], 1 in 2 each | Heavy Warden 100%<br>Patrol Enforcer 50%<br>Volt Enforcer 50% | A major beat lands before it in 50% of runs (fork or intercept).<br>Fork, OVERRUN: adds one more `fodder` pick (Scrap Drone / Rust Drone / Static Skimmer).<br>Fork, ELITE PRESENCE: replaces the `heavy` pick with Patrol Enforcer / Volt Enforcer.<br>Prisoner Exchange taken after battle 7: drops the `elite` pick (the last slot).<br>Prisoner Exchange taken after battle 6: ELITE PRESENCE, replaces the `heavy` pick with Patrol Enforcer / Volt Enforcer. |
| 9 | slots: `elite`, `support`, `fodder` | 1. `elite`: Patrol Enforcer [elite, Vigilant] / Volt Enforcer [elite, Volatile], 1 in 2 each<br>2. `support`: Shield Enforcer [support, no trait], always<br>3. `fodder`: Scrap Drone [regular, no trait] / Rust Drone [regular, no trait] / Static Skimmer [regular, no trait], 1 in 3 each | Shield Enforcer 100%<br>Patrol Enforcer 50%<br>Volt Enforcer 50%<br>Rust Drone 33%<br>Scrap Drone 33%<br>Static Skimmer 33% | A major beat lands before it in 50% of runs (fork or intercept).<br>Fork, OVERRUN: not offered (3 units already).<br>Fork, ELITE PRESENCE: replaces the `support` pick with Patrol Enforcer / Volt Enforcer.<br>Prisoner Exchange taken after battle 8: drops the `fodder` pick (the last slot).<br>Prisoner Exchange taken after battle 7: ELITE PRESENCE, replaces the `support` pick with Patrol Enforcer / Volt Enforcer. |
| 10 | fixed | 1. Fixed: Scrap Drone [regular, no trait]<br>2. Fixed: Scrapmaster [boss, no trait]<br>3. Fixed: Scrap Drone [regular, no trait] | Scrap Drone 100%<br>Scrapmaster 100% | Prisoner Exchange taken after battle 8: ELITE PRESENCE, replaces Scrap Drone with Patrol Enforcer / Volt Enforcer. |

## Hive Incursion (`hive`)

Slot pools: `fodder` = Skitterling, Bloodmite; `elite` = Spine Stalker; `support` = Carapace Beetle; `heavy` = Broodwarden, Caustic Spewer.

| Unit | Role (roll windows) | Slot pool | HP | Trait | Summons on a 20 | Fixed in battle | Units per run | Runs with one or more |
|---|---|---|--:|---|---|---|--:|--:|
| Skitterling | regular | `fodder` | 30 | none | none | 1 | 4.50 | 100% |
| Bloodmite | regular | `fodder` | 26 | none | none | none | 3.50 | 99% |
| Spine Stalker | elite | `elite` | 49 | **Barbed**: Heroes that hit it take 2 damage. | none | 10 | 6.00 | 100% |
| Carapace Beetle | support | `support` | 80 | none | none | none | 1.00 | 100% |
| Broodwarden | tank | `heavy` | 90 | none | none | 7 | 2.25 | 100% |
| Caustic Spewer | elite | `heavy` | 90 | **Corrosive**: Its burns ignore shields. | none | none | 1.25 | 81% |
| Hive Matriarch | boss | none (boss) | 135 | none | none | 10 | 1.00 | 100% |

A run fields 19.5 enemy units in all, 7.3 of them with a trait, and 6.3 of its 10 battles hold at least one
trait unit (before beats and summons).

| Battle | Kind | Enemy slots, in order | Share of runs with the unit | Beats that can change it |
|--:|---|---|---|---|
| 1 | fixed | 1. Fixed: Skitterling [regular, no trait] | Skitterling 100% | None: no beat can come before this battle. |
| 2 | slots: `fodder`, `fodder` | 1. `fodder`: Skitterling [regular, no trait] / Bloodmite [regular, no trait], 1 in 2 each<br>2. `fodder`: Skitterling [regular, no trait] / Bloodmite [regular, no trait], 1 in 2 each | Bloodmite 75%<br>Skitterling 75% | None: no beat can come before this battle. |
| 3 | slots: `elite`, `fodder` | 1. `elite`: Spine Stalker [elite, Barbed], always<br>2. `fodder`: Skitterling [regular, no trait] / Bloodmite [regular, no trait], 1 in 2 each | Spine Stalker 100%<br>Skitterling 50%<br>Bloodmite 50% | A minor beat lands before it in 50% of runs (fork or intercept).<br>Fork, OVERRUN: adds one more `fodder` pick (Skitterling / Bloodmite).<br>Fork, ELITE PRESENCE: replaces the `fodder` pick with Spine Stalker. |
| 4 | slots: `heavy`, `fodder` | 1. `heavy`: Broodwarden [tank, no trait] / Caustic Spewer [elite, Corrosive], 1 in 2 each<br>2. `fodder`: Skitterling [regular, no trait] / Bloodmite [regular, no trait], 1 in 2 each | Bloodmite 50%<br>Caustic Spewer 50%<br>Broodwarden 50%<br>Skitterling 50% | A minor beat lands before it in 50% of runs (fork or intercept).<br>Fork, OVERRUN: adds one more `fodder` pick (Skitterling / Bloodmite).<br>Fork, ELITE PRESENCE: replaces the `heavy` pick with Spine Stalker. |
| 5 | slots: `heavyOrElites` | 1. `heavyOrElites`, 50/50: ONE `heavy` pick (Broodwarden [tank, no trait] / Caustic Spewer [elite, Corrosive], 1 in 2 each); or TWO `elite` picks (Spine Stalker [elite, Barbed], always; the pool has one unit, so both are Spine Stalker) | Spine Stalker 50%<br>Caustic Spewer 25%<br>Broodwarden 25%<br>Lineup size: 1 unit 50%, 2 units 50% | A minor beat lands before it in 50% of runs (fork or intercept).<br>Fork, OVERRUN: adds one more `fodder` pick (Skitterling / Bloodmite).<br>Fork, ELITE PRESENCE: replaces the heavy with Spine Stalker on a heavy roll; not offered on a two-elite roll. |
| 6 | slots: `elite`, `fodder`, `fodder` | 1. `elite`: Spine Stalker [elite, Barbed], always<br>2. `fodder`: Skitterling [regular, no trait] / Bloodmite [regular, no trait], 1 in 2 each<br>3. `fodder`: Skitterling [regular, no trait] / Bloodmite [regular, no trait], 1 in 2 each | Spine Stalker 100%<br>Skitterling 75%<br>Bloodmite 75% | None: no beat can come before this battle. |
| 7 | fixed | 1. Fixed: Broodwarden [tank, no trait] | Broodwarden 100% | A major beat lands before it in 50% of runs (fork or intercept).<br>Fork, OVERRUN: adds one more `fodder` pick (Skitterling / Bloodmite).<br>Fork, ELITE PRESENCE: replaces Broodwarden with Spine Stalker.<br>Prisoner Exchange taken after battle 6: drops nothing (one unit). |
| 8 | slots: `heavy`, `elite` | 1. `heavy`: Broodwarden [tank, no trait] / Caustic Spewer [elite, Corrosive], 1 in 2 each<br>2. `elite`: Spine Stalker [elite, Barbed], always | Spine Stalker 100%<br>Broodwarden 50%<br>Caustic Spewer 50% | A major beat lands before it in 50% of runs (fork or intercept).<br>Fork, OVERRUN: adds one more `fodder` pick (Skitterling / Bloodmite).<br>Fork, ELITE PRESENCE: replaces the `heavy` pick with Spine Stalker.<br>Prisoner Exchange taken after battle 7: drops the `elite` pick (the last slot).<br>Prisoner Exchange taken after battle 6: ELITE PRESENCE, replaces the `heavy` pick with Spine Stalker. |
| 9 | slots: `elite`, `support`, `fodder` | 1. `elite`: Spine Stalker [elite, Barbed], always<br>2. `support`: Carapace Beetle [support, no trait], always<br>3. `fodder`: Skitterling [regular, no trait] / Bloodmite [regular, no trait], 1 in 2 each | Carapace Beetle 100%<br>Spine Stalker 100%<br>Skitterling 50%<br>Bloodmite 50% | A major beat lands before it in 50% of runs (fork or intercept).<br>Fork, OVERRUN: not offered (3 units already).<br>Fork, ELITE PRESENCE: replaces the `support` pick with Spine Stalker.<br>Prisoner Exchange taken after battle 8: drops the `fodder` pick (the last slot).<br>Prisoner Exchange taken after battle 7: ELITE PRESENCE, replaces the `support` pick with Spine Stalker. |
| 10 | fixed | 1. Fixed: Spine Stalker [elite, Barbed]<br>2. Fixed: Hive Matriarch [boss, no trait] | Hive Matriarch 100%<br>Spine Stalker 100% | Prisoner Exchange taken after battle 8: ELITE PRESENCE, replaces Hive Matriarch with Spine Stalker. |

## Veil Breach (`veil`)

Slot pools: `fodder` = Shard Drone, Prism Charger; `elite` = Phaseblade; `support` = Aegis Anchor, Relay Herald; `heavy` = Resonance Warden, Stormweaver.

| Unit | Role (roll windows) | Slot pool | HP | Trait | Summons on a 20 | Fixed in battle | Units per run | Runs with one or more |
|---|---|---|--:|---|---|---|--:|--:|
| Shard Drone | regular | `fodder` | 34 | none | none | 1 | 4.00 | 100% |
| Prism Charger | regular | `fodder` | 32 | none | none | 1 | 4.00 | 100% |
| Aegis Anchor | support | `support` | 58 | none | Shard Drone, 42% | 7, 10 | 3.50 | 100% |
| Resonance Warden | tank | `heavy` | 100 | none | Prism Charger, 40% | none | 1.08 | 79% |
| Phaseblade | elite | `elite` | 60 | **Flickering**: After rolling 1-3, it cloaks. | Shard Drone, 40% | none | 5.67 | 100% |
| Stormweaver | tank | `heavy` | 90 | none | Prism Charger, 42% | none | 1.08 | 79% |
| Relay Herald | support | `support` | 65 | none | Shard Drone, 40% | none | 0.50 | 50% |
| Veil Overseer | boss | none (boss) | 153 | none | Prism Charger, 30% | 10 | 1.00 | 100% |

A run fields 20.8 enemy units in all, 5.7 of them with a trait, and 4.8 of its 10 battles hold at least one
trait unit (before beats and summons).

| Battle | Kind | Enemy slots, in order | Share of runs with the unit | Beats that can change it |
|--:|---|---|---|---|
| 1 | fixed | 1. Fixed: Shard Drone [regular, no trait]<br>2. Fixed: Prism Charger [regular, no trait] | Prism Charger 100%<br>Shard Drone 100% | None: no beat can come before this battle. |
| 2 | slots: `fodder`, `fodder` | 1. `fodder`: Shard Drone [regular, no trait] / Prism Charger [regular, no trait], 1 in 2 each<br>2. `fodder`: Shard Drone [regular, no trait] / Prism Charger [regular, no trait], 1 in 2 each | Prism Charger 50%<br>Shard Drone 50% | None: no beat can come before this battle. |
| 3 | slots: `elite`, `fodder` | 1. `elite`: Phaseblade [elite, Flickering], always<br>2. `fodder`: Shard Drone [regular, no trait] / Prism Charger [regular, no trait], 1 in 2 each | Phaseblade 100%<br>Prism Charger 50%<br>Shard Drone 50% | A minor beat lands before it in 50% of runs (fork or intercept).<br>Fork, OVERRUN: adds one more `fodder` pick (Shard Drone / Prism Charger).<br>Fork, ELITE PRESENCE: replaces the `fodder` pick with Phaseblade. |
| 4 | slots: `heavyOrElites` | 1. `heavyOrElites`, 50/50: ONE `heavy` pick (Resonance Warden [tank, no trait] / Stormweaver [tank, no trait], 1 in 2 each); or TWO `elite` picks (Phaseblade [elite, Flickering], always; the pool has one unit, so both are Phaseblade) | Phaseblade 50%<br>Resonance Warden 25%<br>Stormweaver 25%<br>Lineup size: 1 unit 50%, 2 units 50% | A minor beat lands before it in 50% of runs (fork or intercept).<br>Fork, OVERRUN: adds one more `fodder` pick (Shard Drone / Prism Charger).<br>Fork, ELITE PRESENCE: replaces the heavy with Phaseblade on a heavy roll; not offered on a two-elite roll. |
| 5 | slots: `heavyOrElites` | 1. `heavyOrElites`, 50/50: ONE `heavy` pick (Resonance Warden [tank, no trait] / Stormweaver [tank, no trait], 1 in 2 each); or TWO `elite` picks (Phaseblade [elite, Flickering], always; the pool has one unit, so both are Phaseblade) | Stormweaver 33%<br>Resonance Warden 33%<br>Phaseblade 33%<br>Lineup size: 1 unit 67%, 2 units 33% | A minor beat lands before it in 50% of runs (fork or intercept).<br>Fork, OVERRUN: adds one more `fodder` pick (Shard Drone / Prism Charger).<br>Fork, ELITE PRESENCE: replaces the heavy with Phaseblade on a heavy roll; not offered on a two-elite roll. |
| 6 | slots: `elite`, `fodder`, `fodder` | 1. `elite`: Phaseblade [elite, Flickering], always<br>2. `fodder`: Shard Drone [regular, no trait] / Prism Charger [regular, no trait], 1 in 2 each<br>3. `fodder`: Shard Drone [regular, no trait] / Prism Charger [regular, no trait], 1 in 2 each | Phaseblade 100%<br>Prism Charger 75%<br>Shard Drone 75% | None: no beat can come before this battle. |
| 7 | fixed | 1. Fixed: Aegis Anchor [support, no trait]<br>2. Fixed: Aegis Anchor [support, no trait] | Aegis Anchor 100% | A major beat lands before it in 50% of runs (fork or intercept).<br>Fork, OVERRUN: adds one more `fodder` pick (Shard Drone / Prism Charger).<br>Fork, ELITE PRESENCE: replaces Aegis Anchor with Phaseblade.<br>Prisoner Exchange taken after battle 6: drops the last-listed Aegis Anchor. |
| 8 | slots: `heavy`, `elite` | 1. `heavy`: Resonance Warden [tank, no trait] / Stormweaver [tank, no trait], 1 in 2 each<br>2. `elite`: Phaseblade [elite, Flickering], always | Phaseblade 100%<br>Stormweaver 50%<br>Resonance Warden 50% | A major beat lands before it in 50% of runs (fork or intercept).<br>Fork, OVERRUN: adds one more `fodder` pick (Shard Drone / Prism Charger).<br>Fork, ELITE PRESENCE: replaces the `heavy` pick with Phaseblade.<br>Prisoner Exchange taken after battle 7: drops the `elite` pick (the last slot).<br>Prisoner Exchange taken after battle 6: ELITE PRESENCE, replaces the `heavy` pick with Phaseblade. |
| 9 | slots: `elite`, `support`, `fodder` | 1. `elite`: Phaseblade [elite, Flickering], always<br>2. `support`: Aegis Anchor [support, no trait] / Relay Herald [support, no trait], 1 in 2 each<br>3. `fodder`: Shard Drone [regular, no trait] / Prism Charger [regular, no trait], 1 in 2 each | Phaseblade 100%<br>Relay Herald 50%<br>Prism Charger 50%<br>Shard Drone 50%<br>Aegis Anchor 50% | A major beat lands before it in 50% of runs (fork or intercept).<br>Fork, OVERRUN: not offered (3 units already).<br>Fork, ELITE PRESENCE: replaces the `support` pick with Phaseblade.<br>Prisoner Exchange taken after battle 8: drops the `fodder` pick (the last slot).<br>Prisoner Exchange taken after battle 7: ELITE PRESENCE, replaces the `support` pick with Phaseblade. |
| 10 | fixed | 1. Fixed: Veil Overseer [boss, no trait]<br>2. Fixed: Aegis Anchor [support, no trait] | Aegis Anchor 100%<br>Veil Overseer 100% | Prisoner Exchange taken after battle 8: ELITE PRESENCE, replaces Veil Overseer with Phaseblade. |

## Signal Purge (`voidCirclet`)

Slot pools: `fodder` = Signal Wisp; `elite` = Circuit Acolyte, False Image; `support` = Cipher Scribe; `heavy` = Oath Binder, Ash Channeler.

| Unit | Role (roll windows) | Slot pool | HP | Trait | Summons on a 20 | Fixed in battle | Units per run | Runs with one or more |
|---|---|---|--:|---|---|---|--:|--:|
| Signal Wisp | regular | `fodder` | 38 | none | none | 1 | 10.00 | 100% |
| Circuit Acolyte | elite | `elite` | 62 | **Zealous**: At round start, the lowest enemy die rises by 2. | Signal Wisp, 40% | none | 2.67 | 98% |
| Cipher Scribe | support | `support` | 74 | none | Signal Wisp, 45% | 10 | 2.00 | 100% |
| Oath Binder | elite | `heavy` | 112 | **Commanding**: Its roll penalties last 1 extra round. | Signal Wisp, 35% | 4 | 2.00 | 100% |
| False Image | elite | `elite` | 68 | **Illusory**: The first hit against it each battle is negated. [always starts cloaked] | none | none | 2.67 | 98% |
| Ash Channeler | elite | `heavy` | 94 | **Fervent**: Heals 3 whenever any burn ticks. | Signal Wisp, 42% | none | 1.33 | 83% |
| Signal Hierarch | boss | none (boss) | 180 | none | Signal Wisp, 32% | 10 | 1.00 | 100% |

A run fields 21.7 enemy units in all, 8.7 of them with a trait, and 7.0 of its 10 battles hold at least one
trait unit (before beats and summons).

| Battle | Kind | Enemy slots, in order | Share of runs with the unit | Beats that can change it |
|--:|---|---|---|---|
| 1 | fixed | 1. Fixed: Signal Wisp [regular, no trait]<br>2. Fixed: Signal Wisp [regular, no trait]<br>3. Fixed: Signal Wisp [regular, no trait] | Signal Wisp 100% | None: no beat can come before this battle. |
| 2 | slots: `fodder`, `fodder` | 1. `fodder`: Signal Wisp [regular, no trait], always<br>2. `fodder`: Signal Wisp [regular, no trait], always | Signal Wisp 100% | None: no beat can come before this battle. |
| 3 | slots: `elite`, `fodder` | 1. `elite`: Circuit Acolyte [elite, Zealous] / False Image [elite, Illusory], 1 in 2 each<br>2. `fodder`: Signal Wisp [regular, no trait], always | Signal Wisp 100%<br>Circuit Acolyte 50%<br>False Image 50% | A minor beat lands before it in 50% of runs (fork or intercept).<br>Fork, OVERRUN: adds one more `fodder` pick (Signal Wisp).<br>Fork, ELITE PRESENCE: replaces the `fodder` pick with Circuit Acolyte / False Image. |
| 4 | fixed | 1. Fixed: Oath Binder [elite, Commanding] | Oath Binder 100% | A minor beat lands before it in 50% of runs (fork or intercept).<br>Fork, OVERRUN: adds one more `fodder` pick (Signal Wisp).<br>Fork, ELITE PRESENCE: replaces Oath Binder with Circuit Acolyte / False Image. |
| 5 | slots: `heavyOrElites` | 1. `heavyOrElites`, 50/50: ONE `heavy` pick (Oath Binder [elite, Commanding] / Ash Channeler [elite, Fervent], 1 in 2 each); or TWO `elite` picks (Circuit Acolyte [elite, Zealous] / False Image [elite, Illusory], 1 in 2 each; the second differs from the first) | Circuit Acolyte 67%<br>False Image 67%<br>Ash Channeler 33%<br>Lineup size: 1 unit 33%, 2 units 67% | A minor beat lands before it in 50% of runs (fork or intercept).<br>Fork, OVERRUN: adds one more `fodder` pick (Signal Wisp).<br>Fork, ELITE PRESENCE: replaces the heavy with Circuit Acolyte / False Image on a heavy roll; not offered on a two-elite roll. |
| 6 | slots: `elite`, `fodder`, `fodder` | 1. `elite`: Circuit Acolyte [elite, Zealous] / False Image [elite, Illusory], 1 in 2 each<br>2. `fodder`: Signal Wisp [regular, no trait], always<br>3. `fodder`: Signal Wisp [regular, no trait], always | Signal Wisp 100%<br>Circuit Acolyte 50%<br>False Image 50% | None: no beat can come before this battle. |
| 7 | slots: `heavy`, `fodder` | 1. `heavy`: Oath Binder [elite, Commanding] / Ash Channeler [elite, Fervent], 1 in 2 each<br>2. `fodder`: Signal Wisp [regular, no trait], always | Signal Wisp 100%<br>Oath Binder 50%<br>Ash Channeler 50% | A major beat lands before it in 50% of runs (fork or intercept).<br>Fork, OVERRUN: adds one more `fodder` pick (Signal Wisp).<br>Fork, ELITE PRESENCE: replaces the `heavy` pick with Circuit Acolyte / False Image.<br>Prisoner Exchange taken after battle 6: drops the `fodder` pick (the last slot). |
| 8 | slots: `heavy`, `elite` | 1. `heavy`: Oath Binder [elite, Commanding] / Ash Channeler [elite, Fervent], 1 in 2 each<br>2. `elite`: Circuit Acolyte [elite, Zealous] / False Image [elite, Illusory], 1 in 2 each | False Image 50%<br>Oath Binder 50%<br>Ash Channeler 50%<br>Circuit Acolyte 50% | A major beat lands before it in 50% of runs (fork or intercept).<br>Fork, OVERRUN: adds one more `fodder` pick (Signal Wisp).<br>Fork, ELITE PRESENCE: replaces the `heavy` pick with Circuit Acolyte / False Image.<br>Prisoner Exchange taken after battle 7: drops the `elite` pick (the last slot).<br>Prisoner Exchange taken after battle 6: ELITE PRESENCE, replaces the `heavy` pick with Circuit Acolyte / False Image. |
| 9 | slots: `elite`, `support`, `fodder` | 1. `elite`: Circuit Acolyte [elite, Zealous] / False Image [elite, Illusory], 1 in 2 each<br>2. `support`: Cipher Scribe [support, no trait], always<br>3. `fodder`: Signal Wisp [regular, no trait], always | Cipher Scribe 100%<br>Signal Wisp 100%<br>False Image 50%<br>Circuit Acolyte 50% | A major beat lands before it in 50% of runs (fork or intercept).<br>Fork, OVERRUN: not offered (3 units already).<br>Fork, ELITE PRESENCE: replaces the `support` pick with Circuit Acolyte / False Image.<br>Prisoner Exchange taken after battle 8: drops the `fodder` pick (the last slot).<br>Prisoner Exchange taken after battle 7: ELITE PRESENCE, replaces the `support` pick with Circuit Acolyte / False Image. |
| 10 | fixed | 1. Fixed: Signal Hierarch [boss, no trait]<br>2. Fixed: Cipher Scribe [support, no trait] | Cipher Scribe 100%<br>Signal Hierarch 100% | Prisoner Exchange taken after battle 8: ELITE PRESENCE, replaces Signal Hierarch with Circuit Acolyte / False Image. |

## Mantle Hunt (`stellarMenagerie`)

Slot pools: `fodder` = Pumice Climber, Obsidian Hound, Slag Hound; `elite` = Geode Panther, Cinder Raptor; `support` = none; `heavy` = Basalt Ape, Magma Drake.

| Unit | Role (roll windows) | Slot pool | HP | Trait | Summons on a 20 | Fixed in battle | Units per run | Runs with one or more |
|---|---|---|--:|---|---|---|--:|--:|
| Pumice Climber | regular | `fodder` | 38 | **Feral**: When an ally dies, gains rampage. | none | 1 | 3.32 | 100% |
| Obsidian Hound | regular | `fodder` | 42 | **Feral**: When an ally dies, gains rampage. | none | none | 2.34 | 94% |
| Slag Hound | regular | `fodder` | 34 | **Feral**: When an ally dies, gains rampage. | none | none | 2.34 | 94% |
| Geode Panther | elite | `elite` | 74 | **Feral**: When an ally dies, gains rampage. | none | 4, 10 | 5.00 | 100% |
| Basalt Ape | tank | `heavy` | 112 | **Feral**: When an ally dies, gains rampage. [plus the Accrete 3 keyword] | none | none | 1.25 | 81% |
| Cinder Raptor | elite | `elite` | 86 | **Feral**: When an ally dies, gains rampage. | Slag Hound, 50% | none | 3.00 | 98% |
| Magma Drake | tank | `heavy` | 98 | **Feral**: When an ally dies, gains rampage. [plus the Accrete 4 keyword] | none | none | 1.25 | 81% |
| Mantle Tyrant | boss | none (boss) | 180 | none | none | 10 | 1.00 | 100% |

A run fields 19.5 enemy units in all, 18.5 of them with a trait, and 10.0 of its 10 battles hold at least one
trait unit (before beats and summons).

| Battle | Kind | Enemy slots, in order | Share of runs with the unit | Beats that can change it |
|--:|---|---|---|---|
| 1 | fixed | 1. Fixed: Pumice Climber [regular, Feral] | Pumice Climber 100% | None: no beat can come before this battle. |
| 2 | slots: `fodder`, `fodder` | 1. `fodder`: Pumice Climber [regular, Feral] / Obsidian Hound [regular, Feral] / Slag Hound [regular, Feral], 1 in 3 each<br>2. `fodder`: Pumice Climber [regular, Feral] / Obsidian Hound [regular, Feral] / Slag Hound [regular, Feral], 1 in 3 each | Obsidian Hound 56%<br>Slag Hound 56%<br>Pumice Climber 55% | None: no beat can come before this battle. |
| 3 | slots: `elite`, `fodder` | 1. `elite`: Geode Panther [elite, Feral] / Cinder Raptor [elite, Feral], 1 in 2 each<br>2. `fodder`: Pumice Climber [regular, Feral] / Obsidian Hound [regular, Feral] / Slag Hound [regular, Feral], 1 in 3 each | Cinder Raptor 50%<br>Geode Panther 50%<br>Obsidian Hound 33%<br>Slag Hound 33%<br>Pumice Climber 33% | A minor beat lands before it in 50% of runs (fork or intercept).<br>Fork, OVERRUN: adds one more `fodder` pick (Pumice Climber / Obsidian Hound / Slag Hound).<br>Fork, ELITE PRESENCE: replaces the `fodder` pick with Geode Panther / Cinder Raptor. |
| 4 | fixed | 1. Fixed: Geode Panther [elite, Feral], starts cloaked (battle data) | Geode Panther 100% | A minor beat lands before it in 50% of runs (fork or intercept).<br>Fork, OVERRUN: adds one more `fodder` pick (Pumice Climber / Obsidian Hound / Slag Hound).<br>Fork, ELITE PRESENCE: not offered (every unit is already from the elite pool). |
| 5 | slots: `heavyOrElites` | 1. `heavyOrElites`, 50/50: ONE `heavy` pick (Basalt Ape [tank, Feral] / Magma Drake [tank, Feral], 1 in 2 each); or TWO `elite` picks (Geode Panther [elite, Feral] / Cinder Raptor [elite, Feral], 1 in 2 each; the second differs from the first) | Cinder Raptor 50%<br>Geode Panther 50%<br>Basalt Ape 25%<br>Magma Drake 25%<br>Lineup size: 1 unit 50%, 2 units 50% | A minor beat lands before it in 50% of runs (fork or intercept).<br>Fork, OVERRUN: adds one more `fodder` pick (Pumice Climber / Obsidian Hound / Slag Hound).<br>Fork, ELITE PRESENCE: replaces the heavy with Geode Panther / Cinder Raptor on a heavy roll; not offered on a two-elite roll. |
| 6 | slots: `elite`, `fodder`, `fodder` | 1. `elite`: Geode Panther [elite, Feral] / Cinder Raptor [elite, Feral], 1 in 2 each<br>2. `fodder`: Pumice Climber [regular, Feral] / Obsidian Hound [regular, Feral] / Slag Hound [regular, Feral], 1 in 3 each<br>3. `fodder`: Pumice Climber [regular, Feral] / Obsidian Hound [regular, Feral] / Slag Hound [regular, Feral], 1 in 3 each | Obsidian Hound 56%<br>Slag Hound 56%<br>Pumice Climber 55%<br>Cinder Raptor 50%<br>Geode Panther 50% | None: no beat can come before this battle. |
| 7 | slots: `heavy`, `fodder` | 1. `heavy`: Basalt Ape [tank, Feral] / Magma Drake [tank, Feral], 1 in 2 each<br>2. `fodder`: Pumice Climber [regular, Feral] / Obsidian Hound [regular, Feral] / Slag Hound [regular, Feral], 1 in 3 each | Magma Drake 50%<br>Basalt Ape 50%<br>Pumice Climber 33%<br>Obsidian Hound 33%<br>Slag Hound 33% | A major beat lands before it in 50% of runs (fork or intercept).<br>Fork, OVERRUN: adds one more `fodder` pick (Pumice Climber / Obsidian Hound / Slag Hound).<br>Fork, ELITE PRESENCE: replaces the `heavy` pick with Geode Panther / Cinder Raptor.<br>Prisoner Exchange taken after battle 6: drops the `fodder` pick (the last slot). |
| 8 | slots: `heavy`, `elite` | 1. `heavy`: Basalt Ape [tank, Feral] / Magma Drake [tank, Feral], 1 in 2 each<br>2. `elite`: Geode Panther [elite, Feral] / Cinder Raptor [elite, Feral], 1 in 2 each | Cinder Raptor 50%<br>Basalt Ape 50%<br>Magma Drake 50%<br>Geode Panther 50% | A major beat lands before it in 50% of runs (fork or intercept).<br>Fork, OVERRUN: adds one more `fodder` pick (Pumice Climber / Obsidian Hound / Slag Hound).<br>Fork, ELITE PRESENCE: replaces the `heavy` pick with Geode Panther / Cinder Raptor.<br>Prisoner Exchange taken after battle 7: drops the `elite` pick (the last slot).<br>Prisoner Exchange taken after battle 6: ELITE PRESENCE, replaces the `heavy` pick with Geode Panther / Cinder Raptor. |
| 9 | slots: `elite`, `support`, `fodder` | 1. `elite`: Geode Panther [elite, Feral] / Cinder Raptor [elite, Feral], 1 in 2 each<br>2. `support`: Geode Panther [elite, Feral] / Cinder Raptor [elite, Feral], 1 in 2 each (no support pool: falls back to the elite pool)<br>3. `fodder`: Pumice Climber [regular, Feral] / Obsidian Hound [regular, Feral] / Slag Hound [regular, Feral], 1 in 3 each | Geode Panther 75%<br>Cinder Raptor 75%<br>Slag Hound 34%<br>Obsidian Hound 33%<br>Pumice Climber 33% | A major beat lands before it in 50% of runs (fork or intercept).<br>Fork, OVERRUN: not offered (3 units already).<br>Fork, ELITE PRESENCE: replaces the `fodder` pick with Geode Panther / Cinder Raptor.<br>Prisoner Exchange taken after battle 8: drops the `fodder` pick (the last slot).<br>Prisoner Exchange taken after battle 7: ELITE PRESENCE, replaces the `fodder` pick with Geode Panther / Cinder Raptor. |
| 10 | fixed | 1. Fixed: Mantle Tyrant [boss, no trait]<br>2. Fixed: Geode Panther [elite, Feral] | Geode Panther 100%<br>Mantle Tyrant 100% | Prisoner Exchange taken after battle 8: ELITE PRESENCE, replaces Mantle Tyrant with Geode Panther / Cinder Raptor. |

## Oddities

Noted, not fixed. Each is read from the data and code named above; none was run in the game.

1. **Prisoner Exchange can remove the boss from battle 10.** Taken after battle 8, its ELITE PRESENCE lands
   on battle 10 and replaces the first unit that is not from the `elite` pool. No rule excludes a boss
   (`GameState._shape_comp_for_modifier`, `promote_followup_effects`). By the lineups in the data that unit is
   the Hive Matriarch, the Veil Overseer, the Signal Hierarch and the Mantle Tyrant; in Facility it is the
   first Scrap Drone and the Scrapmaster stays. It needs a beat after battle 8 that is an intercept, that
   card drawn from the 11-card major deck, and the player releasing the prisoner. Read from the code only: not
   reproduced in a run.
2. **The slot pools and the roll-windows roles disagree on three units.** The slot classifier calls any unit
   with 90 HP or more `heavy`; the roll-windows table goes by kit. Caustic Spewer, Oath Binder and Ash
   Channeler are elites with a trait in the table and `heavy` in the slots. So Signal Purge's `heavy` slot
   always fields a trait elite (it has no tank at all), and the Hive's fields one half the time. TRUTH already
   records that the two classifiers differ; the effect on trait exposure is the new part.
3. **Traits are met more often than "a few times" in three operations.** Battles per run with at least one
   trait unit: Facility 4.5, Veil 4.8, Hive 6.3, Signal Purge 7.0, Mantle Hunt 10. Barbed (Spine Stalker) is
   in battles 3, 6, 8, 9 and 10 of every Hive run. A first run on Facility meets a trait elite in battle 3
   every time.
4. **One-unit pools make some units constant and some lineups doubled.**
   - Hive `elite` is Spine Stalker alone: 6.0 per run, and the two-elite roll is two Spine Stalkers.
   - Veil `elite` is Phaseblade alone: 5.7 per run, and the two-elite roll is two Phaseblades.
   - Signal Purge `fodder` is Signal Wisp alone: exactly 10 per run. Battles 1 and 2 are three Wisps, then
     two.
   - Facility `support` (Shield Enforcer) and `heavy` (Heavy Warden), Hive `support` (Carapace Beetle) and
     Signal Purge `support` (Cipher Scribe) are one-unit pools too.
5. **Units seen least.** Relay Herald appears only in Veil battle 9, in half of runs (0.5 per run). Carapace
   Beetle appears exactly once per Hive run, in battle 9. Resonance Warden and Stormweaver average 1.1 per run
   and each is missing from 21% of Veil runs. Caustic Spewer, Basalt Ape and Magma Drake average 1.25 and are
   each missing from 19% of their runs; Ash Channeler averages 1.3 and is missing from 17%. No unit is
   unreachable.
6. **Units seen most.** Signal Wisp 10.0 per run, Spine Stalker 6.0, Phaseblade 5.7, Scrap Drone 5.2, Geode
   Panther 5.0. The same list is the heaviest trait exposure: Barbed, Flickering and Feral.
7. **The no-repeat rule bends three battles.** Facility battle 2 cannot be Scrap Drone plus Rust Drone
   (battle 1's lineup), so Static Skimmer is in it 71% of the time. Signal Purge battle 5 never fields a lone
   Oath Binder (battle 4's lineup), so its `heavy` roll is always Ash Channeler and the two-elite roll rises
   to 67%. Veil battle 5 cannot repeat battle 4, so two Phaseblades fall to 33% there.
8. **Mantle Hunt has no `support` unit.** Battle 9's `support` slot draws from the `elite` pool, so the fight
   is two elites and a regular, and FIREWALLED is never offered in that operation.
9. **ELITE PRESENCE often swaps a bigger unit for a smaller one.** On a lineup that leads with a `heavy` pick
   it replaces that unit: Heavy Warden (95 HP) for a 60 or 65 HP elite, Broodwarden (90) for Spine Stalker
   (49), Oath Binder (112) for a 62 or 68 HP elite. The flagged route still pays two rarity rows deeper.
10. **Two same-kind slots can roll the same unit.** `fodder, fodder` does not avoid a repeat; only the
    two-elite roll does.
11. **False Image has the summon flag and no summon line.** `summonElite: true` with no ability that summons,
    so the flag does nothing for it.
12. **Cloak comes from two places.** Geode Panther starts cloaked in battle 4 by that battle's data and not in
    battle 10; False Image starts cloaked everywhere by its unit data.

The ranges in `enemies.data.json` match the role each unit has in the roll-windows table, for all 38 units.
