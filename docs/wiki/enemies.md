# Enemies

> Part of the [Overload Protocol wiki](INDEX.md). See also: [factions.md](factions.md), [bosses.md](bosses.md), [operations.md](operations.md), [targeting.md](targeting.md), [keywords.md](keywords.md), [combat-resolution.md](combat-resolution.md).

## How it works

All enemy content lives in `data/raw/enemies.data.json`: **37 ability kits** (`enemyAbilities`, one per `type`) and **38 unit defs** (`enemyUnitDefs`, keyed by display name — Obsidian Hound and Slag Hound share the `beastWolf` kit, hence 38 ≠ 37). `DataManager._load_all_data` builds an `EnemyData` resource per def (`scripts/autoloads/DataManager.gd:346-368`): `id` = slugified display name (e.g. `scrap_drone`), faction from `ENEMY_FACTION_BY_TYPE` (:98-135), portrait from `ENEMY_PORTRAIT_BY_NAME` (:138-183, all 38 mapped).

Enemy dice zones are fixed (`DataManager.gd:68-74`): recharge 1–4 · strike 5–10 · surge 11–16 · crit 17–19 · overload 20. Enemies resolve after the hero phase, in **reverse slot order** (`combat_manager.gd:715-716`), through `_apply_enemy_ability` (`combat_manager.gd:1500-1730`). Enemy stats are **flat every fight** — the `battleEnemyScale` table in data and `trackHpScale` in battle-modes have **no consumer** (see findings). Enemies never use Protocol.

Two independent unit fields (INVARIANTS #2):
- `ai` (`dumb`/`smart`) gates nat20 elite summons (`combat_manager.gd:2636`) and the summon-injection guard (`battle_scene.gd:2579` — only `dumb` units may be injected).
- `targeting` (optional, none currently set) overrides the kit-default personality table in `scripts/battle/targeting_personality.gd:16-61` — see [targeting.md](targeting.md). Verified: the kit table matches TRUTH exactly.

### Unit roster (all 38)

| Display name | Kit (`type`) | Faction / op | HP | dmg preview | ai | Targeting (kit default) | Notes |
|---|---|---|---|---|---|---|---|
| Scrap Drone | scrap | facility | 35 | 5–9 | dumb | SYSTEMATIC | rebuilt by ASSEMBLY LINE |
| Rust Drone | rust | facility | 40 | 5–8 | dumb | SYSTEMATIC | −roll debuffer |
| Static Skimmer | signalSkimmer | facility | 35 | 5–8 | dumb | SYSTEMATIC | jam fodder |
| Patrol Elite | patrol | facility | 55 | 12–16 | smart | PACK | |
| Guard Elite | guard | facility | 65 | 14–18 | smart | PACK | ally-shield support |
| Heavy Warden | warden | facility | 105 | 17–23 | smart | WOUNDED | jam on crit |
| Volt Elite | volt | facility | 70 | 15–21 | smart | PACK | **spike** carrier |
| SCRAPMASTER | boss | facility | 140 | 12–22 | smart | WOUNDED | boss — [bosses.md](bosses.md) |
| Skitterling | skitter | hive | 40 | 5–9 | dumb | PACK | leech |
| Bloodmite | mite | hive | 35 | 5–8 | dumb | PACK | THE BROOD spawn |
| Spine Stalker | stalker | hive | 65 | 12–16 | smart | WOUNDED | **spike** carrier |
| Carapace Beetle | carapace | hive | 80 | 14–18 | smart | PACK | **spike** carrier, ally shields |
| Broodwarden | brood | hive | 115 | 17–23 | smart | PACK | heavy leech |
| Caustic Spewer | spewer | hive | 90 | 15–21 | smart | PACK | **hijack** (Mimic Gland) |
| Hive Matriarch | hiveBoss | hive | 180 | 15–21 | smart | WOUNDED | boss |
| Shardmite | veilShard | veil | 40 | 5–9 | dumb | SYSTEMATIC | summon species |
| Prism Charger | veilPrism | veil | 38 | 6–10 | dumb | SYSTEMATIC | self-taunt wall; summon species |
| Aegis Anchor | veilAegis | veil | 68 | 12–16 | smart | WOUNDED | 3× firewall faces; summons Shardmite |
| Resonance Warden | veilResonance | veil | 118 | 17–23 | smart | WOUNDED | firewall (Harmonic Mend); summons Prism Charger |
| Nullblade | veilNull | veil | 70 | 13–17 | smart | WOUNDED | firewall (Annulment); summons Shardmite |
| Stormweaver | veilStorm | veil | 92 | 15–21 | smart | WOUNDED | burn + buffs; summons Prism Charger |
| Synapse Herald | veilSynapse | veil | 76 | 12–16 | smart | WOUNDED | firewall (Synaptic Tune); summons Shardmite |
| CONCLAVE OVERSEER | veilBoss | veil | 180 | 19–25 | smart | WOUNDED | boss |
| Glitch Sprite | voidWisp | voidCirclet (Null Synod) | 38 | 5–9 | dumb | SYSTEMATIC | siphon on overload; summon species |
| Init Acolyte | voidAcolyte | voidCirclet | 62 | 12–16 | smart | SYSTEMATIC | 2× firewall, rewrite, siphon |
| Checksum Scribe | voidScribe | voidCirclet | 74 | 12–16 | smart | SYSTEMATIC | **hijack** (Checksum Copy), rewrite |
| Axiom Binder | voidBinder | voidCirclet | 112 | 17–23 | smart | WOUNDED | firewall+rewrite overload, siphon |
| Forked Double | voidGlimmer | voidCirclet | 68 | 13–17 | smart | SPITEFUL | `startsCloaked`; **hijack** (Afterimage); inert summonElite |
| Daemon Channeler | voidChanneler | voidCirclet | 94 | 15–21 | smart | WOUNDED | siphon on crit |
| ROOT HIEROPHANT | voidCircletBoss | voidCirclet | 180 | 19–25 | smart | WOUNDED | boss |
| Pumice Macaque | beastMonkey | stellarMenagerie (The Accretion) | 38 | 5–9 | dumb | PACK | packBonus (+1 dmg per other same-kind pack member; fixed 2026-07-08) |
| Obsidian Hound | beastWolf | stellarMenagerie | 42 | 6–10 | dumb | PACK | packBonus (+1 per other beastWolf; packs with Slag Hound) |
| Slag Hound | beastWolf | stellarMenagerie | 34 | 5–9 | dumb | PACK | Raptor's summon species; shares kit |
| Geode Panther | beastLynx | stellarMenagerie | 74 | 12–17 | smart | WOUNDED | cloak + petrify freeze |
| Basalt Ape | beastBison | stellarMenagerie | 112 | 16–22 | smart | SPITEFUL | **spike** carrier, `accrete: 3` |
| Pyroclast Raptor | beastHyena | stellarMenagerie | 86 | 13–18 | smart | SPITEFUL | enemy taunt; summons Slag Hound 50% |
| Magma Drake | beastBadger | stellarMenagerie | 98 | 15–21 | smart | SPITEFUL | burn heavy, `accrete: 4` |
| MANTLE TYRANT | beastTyrant | stellarMenagerie | 180 | 19–25 | smart | SPITEFUL | boss; rampage + freeze-all |

### Ability kits (37 — name — eff, per zone)

Eff strings verbatim from data (comma grammar; generator `scripts/assets/sync-enemy-eff.mjs`).

**Facility**

| Kit | recharge (1–4) | strike (5–10) | surge (11–16) | crit (17–19) | overload (20) |
|---|---|---|---|---|---|
| scrap | ECM Shell — 8 shield | Stab — 7 dmg | Overcharge — 10 dmg, 1 burn | Overcharge+ — 15 dmg, 2 burn | Detonator — 20 dmg, 3 burn |
| rust | ECM Hiss — 5 shield, +1 roll self | Sparking Cut — 6 dmg, -1 roll | Disrupt Pulse — 9 dmg, -1 roll | EMP Spike — 12 dmg, -2 roll | Total Jam — 14 dmg, -3 roll |
| signalSkimmer | ECM Ping — 5 shield, jam | Spike Bleed — 5 dmg, -1 roll | Sideband Scrap — 8 dmg, -1 roll, 2t | Nullburst — 11 dmg, jam | Whitenoise Collapse — 13 dmg, jam all |
| patrol | Regroup — 6 shield | Assault — 15 dmg | Heavy Barrage — 18 dmg | Devastate — 21 dmg, -1 roll, 2t | Final Sweep — 23 dmg, -2 roll, 3t |
| guard | Bulwark Link — 6 shield all allies | Suppressing Fire — 12 dmg, ally 6 shield | Cover Field — 11 dmg, ally 9 shield, +2 roll to allies | Barrier Burst — 15 dmg, ally 7 shield | Fortress Protocol — 18 dmg, ally 13 shield |
| warden | Field Service — 7 heal, 7 shield | Crushing Blow — 11 dmg | Sustained Fire — 11 dmg, 3 burn, 3t | Punisher — 24 dmg, jam | Execution — 29 dmg, 6 heal |
| volt | Grounding — 5 shield all allies, spike 4 | Arc Jab — 9 dmg, 1 burn, 2t | Arc Strike — 11 dmg, 2 burn, 2t | Conduction — 13 dmg, 3 burn, 2t | Meltdown Arc — 15 dmg, 4 burn, 3t |
| boss | Shield Matrix — 12 shield | Suppressor — 12 dmg, -2 roll, 2t | Core Blast — 17 dmg | System Purge — wipe shields, then 21 dmg | Annihilate — 26 dmg (all) |

**Hive**

| Kit | recharge | strike | surge | crit | overload |
|---|---|---|---|---|---|
| skitter | Burrow Regen — 5 heal | Mandible Rake — 8 dmg, lifesteal 50% | Searing Nip — 9 dmg, 2 burn | Blood Frenzy — 12 dmg, 3 burn | Splatter Gland — 17 dmg, 4 burn |
| mite | Pheromone Surge — 3 heal | Proboscis Jab — 6 dmg, lifesteal 40% | Neural Bite — 8 dmg, 1 burn | Symbiote Spike — 10 dmg, 2 burn | Hive Latch — 11 dmg, 3 burn, 2t |
| stalker | Chitin Regroup — 6 shield, spike 4 | Spine Lunge — 14 dmg, lifesteal 45% | Impaler Volley — 15 dmg, 2 burn, 3t | Shredding Spines — 17 dmg, 3 burn, 4t | Brood Execution — 19 dmg, 4 burn, 5t |
| carapace | Chitin Link — 6 shield all allies, spike 3 | Ramming Plate — 12 dmg, ally 6 shield, lifesteal 50% | Living Bulwark — 10 dmg, 2 burn, 4t, ally 9 shield | Carapace Burst — 13 dmg, 3 burn, 5t, ally 7 shield | Fortress Beetle — 16 dmg, 2 burn, 5t, ally 13 shield |
| brood | Nutrient Share — 7 heal, 7 shield | Brood Slam — 11 dmg, lifesteal 55% | Acid Saliva — 9 dmg, 4 burn, 3t | Matriarch Crush — 18 dmg, 4 burn, 5t | Culling Feed — 27 dmg, lifesteal 35% |
| spewer | Mimic Gland — hijack | Acid Spit — 8 dmg, lifesteal 45% | Caustic Spray — 9 dmg, 3 burn, 4t | Corrosive Hose — 10 dmg, 4 burn, 5t | Melt Torrent — 12 dmg, 5 burn, 5t |
| hiveBoss | Chitin Bulwark — 22 shield | Royal Mandibles — 19 dmg, -2 roll, 2t, lifesteal 35% | Brood Nova — 20 dmg, 3 burn, 5t | Biomass Purge — 25 dmg, 2 burn, 4t, -3 roll, 2t | Acid Cataclysm — wipe shields, then 28 dmg, lifesteal 40% |

**Veil Concord**

| Kit | recharge | strike | surge | crit | overload |
|---|---|---|---|---|---|
| veilShard | Phase Shell — 4 shield | Shard Cut — 7 dmg | Lattice Flicker — 9 dmg | Crystal Break — 12 dmg | Harmonic Break — 15 dmg, 2 burn, 2t |
| veilPrism | Lattice Guard — taunt (all heroes must target this enemy) | Ram — 8 dmg | Prism Surge — 11 dmg, 4 shield | Focused Beam — 14 dmg | Overcharge Drive — 18 dmg |
| veilAegis | Lattice Link — 6 shield, ally 6 shield, +1 roll to allies, **firewall** | Aegis Bash — 12 dmg, ally 6 shield, +1 roll to allies | Bulwark Pulse — 14 dmg, ally 8 shield, +1 roll to allies | Fortress Lash — 18 dmg, ally 9 shield, +2 roll to allies, **firewall** | Conclave Bulwark — 20 dmg, ally 12 shield, +2 roll to allies, 2t, summon ~42% nat20, **firewall** |
| veilResonance | Harmonic Mend — 7 heal, 7 shield, +1 roll to allies, **firewall** | Resonant Slam — 12 dmg | Pulse Burn — 12 dmg, 3 burn, 3t, +1 roll to allies | Catastrophic Wave — 22 dmg, +2 roll to allies | Veil Collapse — 28 dmg, 6 heal, +2 roll to allies, 2t, summon ~40% nat20 |
| veilNull | Void Stillness — 5 shield, +1 roll to allies | Null Slash — 14 dmg | Erase Vector — 16 dmg | Annulment — 19 dmg, **firewall** | Total Eclipse — 24 dmg, summon ~40% nat20 |
| veilStorm | Capacitor Hum — +1 roll to allies | Arc Needle — 10 dmg, 1 burn, 2t | Storm Weave — 12 dmg, 2 burn, 2t, +1 roll to allies | Psi Tempest — 14 dmg, 3 burn, 3t, +1 roll to allies | Lattice Storm — 16 dmg, 5 burn, 4t, +2 roll to allies, 2t, summon ~42% nat20 |
| veilSynapse | Synaptic Tune — +2 roll to allies, **firewall** | Herald Strike — 11 dmg, ally 6 shield | Weave Shield — 10 dmg, ally 7 shield, +1 roll to allies | Conduit Spike — 15 dmg, ally 8 shield, +1 roll to allies, 2t | Broodlink Surge — 17 dmg, 8 heal, +2 roll to allies, 2t, summon ~40% nat20 |
| veilBoss | Overseer Mantle — 22 shield, ally 8 shield, +2 roll to allies | Decree — 19 dmg, -2 roll, 2t | Judgment Arc — 22 dmg, 2 burn, 2t, +1 roll to allies | Absolute Vector — 26 dmg, -3 roll, 2t, +1 roll to allies | Veil Cataclysm — wipe shields, then 30 dmg, +2 roll to allies, 2t, summon ~30% nat20 |

**Null Synod** (internal id `voidCirclet`)

| Kit | recharge | strike | surge | crit | overload |
|---|---|---|---|---|---|
| voidWisp | Static Hiss — -1 roll | Spark Flick — 6 dmg, -1 roll | Arc Nibble — 8 dmg, 1 burn | Bit Rot — 10 dmg, -2 roll | Stack Overflow — 11 dmg, siphon 2 |
| voidAcolyte | Seal Sigil — **firewall** | Binding Lash — 12 dmg, siphon 2 | Geas Needle — 14 dmg, rewrite | Init Collar — 17 dmg, **firewall** | Ritual Clamp — 18 dmg, summon ~40% nat20 |
| voidScribe | Checksum Pass — +1 roll to allies | Glyph Strike — 11 dmg, ally 6 shield | Checksum Copy — 10 dmg, hijack | Prophecy Spike — 15 dmg, rewrite | Summon Verse — 16 dmg, +2 roll to allies, 2t, summon ~45% nat20 |
| voidBinder | Quiet Pact — -1 roll, 2t | Compulsion — 14 dmg, -1 roll, 2t | Geas Burst — 16 dmg, siphon 2 | Dominion Mark — 19 dmg | Mass Snare — 21 dmg, summon ~35% nat20, **firewall**, rewrite |
| voidGlimmer | Refork — 6 shield, cloak | False Edge — 13 dmg | Mirror Break — wipe shields, then 12 dmg | Afterimage — 17 dmg, hijack | Fork Collapse — 19 dmg, rewrite |
| voidChanneler | Channel Focus — +2 roll | Arc Lance — 16 dmg | Storm Loom — 15 dmg, 2 burn, 3t | Starfall — 20 dmg, siphon 2 | Warp Nova — 22 dmg, 4 burn, 4t, summon ~42% nat20 |
| voidCircletBoss | Hierophant Mantle — 20 shield, ally 8 shield, +2 roll to allies, **firewall** | Decree of Stillness — 19 dmg, -2 roll, 2t | Circlet Cataclysm — 22 dmg, 2 burn, 2t, +1 roll to allies | Absolute Binding — 26 dmg, -3 roll, 2t | Void Gate — wipe shields, then 30 dmg, +2 roll to allies, 2t, summon ~32% nat20 |

**The Accretion** (internal id `stellarMenagerie`)

| Kit | recharge | strike | surge | crit | overload |
|---|---|---|---|---|---|
| beastMonkey | Still Perch — 3 heal | Pumice Grasp — 6 dmg, pack bonus | Caustic Spittle — 8 dmg, 2 burn | Arterial Bite — 11 dmg | Troop Frenzy — 13 dmg, 3 burn, 2t |
| beastWolf | Slag Coat — 4 shield | Rending Fang — 7 dmg, pack bonus | Hamstring Lunge — 9 dmg, 1 burn | Throat Lock — 12 dmg | Pack Surge — 14 dmg, pack bonus |
| beastLynx | Geode Veil — 10 shield, cloak | Silent Opening — 10 dmg, freeze (repeat 1) [petrify] | Lunar Rake — 12 dmg, 2 burn, 3t | Decloak Rake — 16 dmg, freeze (repeat 1) [petrify] | Black Sky Shriek — 18 dmg, freeze all (repeat 1) [petrify] |
| beastBison | Basalt Set — 14 shield, spike 5 | Skull Drive — 11 dmg | Fistfall — 14 dmg | Bonebreaker Line — 17 dmg | Basalt Stampede — wipe shields, then 16 dmg |
| beastHyena | Scavenge Breath — 4 heal, 8 shield | Crack Jaw — 9 dmg, lifesteal 40% | Flank Rip — 11 dmg, 2 burn, 3t | Challenge Screech — 15 dmg, taunt | Call Friends — 13 dmg, 2 burn, 3t, summon ~50% nat20 |
| beastBadger | Magma Coil — 8 shield | Magma Bite — 10 dmg, 2 burn, 2t | Lava Wake — 12 dmg, 2 burn, 4t | Molten Rake — 16 dmg, 3 burn, 3t | Eruption — 20 dmg, 4 burn, 3t |
| beastTyrant | Reaver Mantle — 20 shield, rampage +1 | Titan Gouge — 19 dmg, -2 roll, 2t, lifesteal 35% | Gravity Hoof — 20 dmg, 3 burn, 4t | Annihilation Sweep — 24 dmg, rampage all +1 | Total Eclipse — wipe shields, then 26 dmg, rampage all +1, freeze all (repeat 1) |

### Enemy-side mechanics (engine)

- **Lifesteal** (`lifestealPct`, the enemy percent form of Leech, same LC pip — `scripts/ui/effect_pip.gd:249-253`): attacker heals `floor(final_dmg × pct/100)` after shields (`combat_manager.gd:1576-1595`).
- **Siphon** (Synod only): on a connected hit, queue a Protocol drain, floored at 0 by battle_scene (`combat_manager.gd:1599-1603`).
- **Spike**: granted during the enemy phase with `spike_skip_next_tick`, so it covers exactly the next hero phase, then expires (`combat_manager.gd:1705-1710, 2511-2515`). Retaliation is flat, can't chain between two spiked units (:1879-1882).
- **Summons** (nat20 elites): fire only from the overload zone on a RAW 20, only for `ai: smart` + `summonElite: true`, at `summonChance`% (`combat_manager.gd:2628-2649`). The event injects a **dumb-only** copy (`battle_scene.gd:2568-2592`), capped at 3 living enemies, **replacing the first dead slot** before appending (`combat_manager.gd:2652-2666`). The sim mirrors this exactly (`scripts/sim/sim_runner.gd:456,580`).
- **Rampage** (MANTLE TYRANT): charges double the holder's next damaging ability, one charge per ability (`combat_manager.gd:1548-1551`).
- **Accrete** (Basalt Ape 3 / Magma Drake 4): +N shield at the start of each enemy phase, surviving the imminent tick (`combat_manager.gd:696-704`). These do NOT persist — only the Tyrant's standing-rule shields do.
- **Enemy freeze**: freeze=repeat; single-target enemy freeze always picks the hero with the **lowest revealed die** (taunt overrides, cloak skips, ties to lower slot — `combat_manager.gd:2033-2051`).
- **Enemy shields/debuffs** grant with `survives_current_tick`/skip-first-tick, so enemy-phase effects always cover exactly one hero phase ([shields-and-ward.md](shields-and-ward.md), TRUTH rule 5).

## Why it works that way

- One kit per `type` + flat stats keeps every enemy's five faces inspectable on a phone (INVARIANTS #5); difficulty comes from composition and boss standing rules, not stat inflation (INVARIANTS #6).
- `ai` vs `targeting` were split deliberately in keyword-batch Tasks 4+9 so summon gating can't be broken by targeting edits (INVARIANTS #2).
- Spike is retaliate's replacement, restricted to exactly 4 carriers; ward became deterministic Firewall (10 enemy instances: 6 Veil + 4 Synod); DoT is Burn everywhere; cower merged into freeze with petrify as the Accretion's cosmetic flavor (TRUTH adjudications).
- Summon species are all `dumb` so the injection guard can hold a hard "reinforcements are fodder" rule.

## What it replaced

- **Phase-2 stat jumps** → per-boss standing rules (pkg4; see [bosses.md](bosses.md)). Leftovers: `phase2.wav` + AudioManager registration (finding F-enemies-16), stale `docs/ABILITY_DESCRIPTIONS_FULL.md` P2 numbers (F-enemies-17).
- **Cower** → freeze (repeat) with `freeze_flavor: petrify` on beastLynx. **Venom/Decay** → Burn (the old DoT flavors; the reserved-word ability names — Venom Nip, ECM Jam, Chain Strike, Crystal Shatter — were later renamed for keyword legibility, NK-05). **Counterspell-%** → Firewall. **Retaliate** → spike. **Lure** → enemy-side Taunt (`lured_by_id` internal).
- Old unit names live on only in git history and renamed portrait files (rift_macaque→pumice_macaque, void_reaver→mantle_tyrant, whitenoise_skimmer→static_skimmer, etc. — TRUTH §Assets).

## File locations

- `data/raw/enemies.data.json` — kits, unit defs, (dead) battleEnemyScale
- `data/schemas/enemies.data.schema.json` — shape + enums
- `scripts/battle/combat_manager.gd` — enemy resolution (:1500-1730), summons (:2628-2666), boss rules (:82-275)
- `scripts/battle/targeting_personality.gd` — personalities
- `scripts/battle/battle_scene.gd:2568-2592` — summon-injection guard
- `scripts/autoloads/DataManager.gd` — registry, faction map, portraits, role pools

## Known edge cases

- A raw-20 requirement means an erb-buffed effective 20 celebrates as overload but does NOT roll a summon (`raw_roll != 20` gate, `combat_manager.gd:2638`).
- The summon chance draws from the **global RNG** — seeded per run in the sim, unseeded live (F-enemies-07).
- Hive Matriarch's Bloodmite spawn is silently capped by the 3-enemy field limit (F-enemies-08).
- `pack bonus` text on the Accretion fodder never adds damage — the counter compares unique runtime ids (F-enemies-03).
- Forked Double spawns cloaked (`startsCloaked`) AND its b4 Geode Panther counterpart uses the per-battle `cloaked: true` comp flag (battle-modes stellarMenagerie b4) — two different cloak sources, same rules.
- `enemyAbility.rfe` is schema-required but always 0 on enemies (hero-side field); harmless cruft.

## ⚠ Open findings

<!-- AUDIT-LINKS:enemies -->
- [A-046](../audit/INTERACTION_AUDIT.md#a-046) - [dead] packBonus never fires (compares unique ids)
- [A-047](../audit/INTERACTION_AUDIT.md#a-047) - [dead] battleEnemyScale schema-required dead data
- [A-049](../audit/INTERACTION_AUDIT.md#a-049) - [dead] Forked Double summonElite inert
- [A-050](../audit/INTERACTION_AUDIT.md#a-050) - [dead] commsHex dead enemyType enum entry
- [A-054](../audit/INTERACTION_AUDIT.md#a-054) - [confusing] stale 'Veil-only' summon comment
- [A-055](../audit/INTERACTION_AUDIT.md#a-055) - [confusing] grantRampageAll integer read as boolean
- [A-058](../audit/INTERACTION_AUDIT.md#a-058) - [confusing] battle-start relic effects skip summons/rebuilds

Resolved (2026-07-08 fix pass): [A-021](../audit/INTERACTION_AUDIT.md#a-021)
