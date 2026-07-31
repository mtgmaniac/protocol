# Operations

> Part of the [Overload Protocol wiki](INDEX.md). See also: [factions.md](factions.md), [enemies.md](enemies.md), [bosses.md](bosses.md), [beats-and-events.md](beats-and-events.md), [save-system.md](save-system.md).

## How it works

Five operations, defined and ordered in `data/raw/battle-modes.json` (`order`: facility → hive → veil → voidCirclet → stellarMenagerie). Each is 10 battles; a battle is either a **fixed comp** (`enemies: [{name, cloaked?}]`) or a **slot pattern** (`slots: [...]`) rolled from the faction's role pools **once at run start** (`GameState._resolve_battle_comps`, `scripts/autoloads/GameState.gd:167-178`) so previews always show exact comps (`resolved_battle_comps`).

### Roles and slot resolution

Role pools are built per faction at load (`DataManager.gd:507-556`), bosses excluded:
- **fodder** = `ai: dumb`
- **heavy** = smart with HP ≥ 90 (`HEAVY_HP_MIN`)
- **support** = remaining smart units with ally-aid fields (`shieldAlly`, `shieldAllyAll`, `erb`, `erbAll`, `grantRampage*`) in ≥ 2 distinct kit zones
- **elite** = the rest
- `heavyOrElites` slot = 50/50 one heavy OR two elites (`GameState.gd:185-191`, `_reward_rng`)
- The Accretion has no support unit → support requests fall back to the elite pool (`DataManager.gd:549-556`).

Resulting pools:

| Faction | fodder | elite | support | heavy |
|---|---|---|---|---|
| facility | Scrap Drone, Rust Drone, Static Skimmer | Patrol Elite, Volt Elite | Guard Elite | Heavy Warden |
| hive | Skitterling, Bloodmite | Spine Stalker | Carapace Beetle | Broodwarden, Caustic Spewer |
| veil | Shardmite, Prism Charger | Nullblade | Aegis Anchor, Synapse Herald | Resonance Warden, Stormweaver |
| voidCirclet | Glitch Sprite | Init Acolyte, Forked Double | Checksum Scribe | Axiom Binder, Daemon Channeler |
| stellarMenagerie | Pumice Macaque, Obsidian Hound, Slag Hound | Geode Panther, Pyroclast Raptor | — (falls back to elite) | Basalt Ape, Magma Drake |

### The five templates (anchors in **bold**)

Every op pins three anchors: **b1** (authored intro comp), one **faction signature** fixed battle, and **b10** (boss + escort). All other rows are slot patterns.

| # | facility | hive | veil | voidCirclet | stellarMenagerie |
|---|---|---|---|---|---|
| 1 | **Scrap Drone + Rust Drone** | **Skitterling** | **Shardmite + Prism Charger** | **Glitch Sprite ×3** | **Pumice Macaque** |
| 2 | fodder ×2 | fodder ×2 | fodder ×2 | fodder ×2 | fodder ×2 |
| 3 | elite + fodder | elite + fodder | elite + fodder | elite + fodder | elite + fodder |
| 4 | heavyOrElites | heavyOrElites | heavyOrElites | **Axiom Binder** (signature) | **Geode Panther (cloaked)** (signature) |
| 5 | **Guard Elite ×2** (signature) | heavyOrElites | heavyOrElites | heavyOrElites | heavyOrElites |
| 6 | elite + fodder ×2 | elite + fodder ×2 | elite + fodder ×2 | elite + fodder ×2 | elite + fodder ×2 |
| 7 | heavy + fodder | **Broodwarden** (signature) | **Aegis Anchor ×2** (signature) | heavy + fodder | heavy + fodder |
| 8 | heavy + elite | heavy + elite | heavy + elite | heavy + elite | heavy + elite |
| 9 | elite + support + fodder | elite + support + fodder | elite + support + fodder | elite + support + fodder | elite + support + fodder |
| 10 | **SCRAPMASTER + 2× Scrap Drone** | **Spine Stalker + Hive Matriarch** | **CONCLAVE OVERSEER + Aegis Anchor** | **ROOT HIEROPHANT + Checksum Scribe** | **MANTLE TYRANT + Geode Panther** |

Per-op strings: `label`, `callsign`, `blurb`, `victoryTitle`/`victorySub` (e.g. Synod: "Hierophant down. Gate sealed."). Each op also carries `trackHpScale` (1.05 / 1.0 / 0.94 / 0.94 / 0.94) — loaded into `OperationData.track_hp_scale` (`DataManager.gd:411`) but **read by nothing** (finding F-enemies-06); combat uses flat unit stats.

### Unlock chain

`SaveManager.OPERATION_CHAIN` (`scripts/autoloads/SaveManager.gd:30`): clearing an op's boss unlocks the next — facility → hive → veil → voidCirclet → stellarMenagerie. Uncapped (unlike the one-rung hero ladder). First clear of each op also unlocks its boss relic (`SaveManager.gd:17-18` maps voidCirclet→rootAccess, stellarMenagerie→mantleCore, etc.). All five cards stay visible: locked ops use their own dark boss-art silhouette, real name, existing blurb, and `LOCKED`, but cannot be inspected or deployed. Headless runs read as fully unlocked (TRUTH §save system).

### Interaction with beats and forks

Slot comps feed the route-fork preview (`GameState.roll_route_modifier`, :280-291 — a modifier is only offered if it observably changes the comp) and a flagged route replaces the resolved comp (`accept_flagged_route`, :331-343). Battle 5 is the relic-draft beat; the 3 random beats land in gaps after b2/b3/b4/b6/b7/b8 — see [beats-and-events.md](beats-and-events.md).

## Why it works that way

Templated anchors give every run the same skeleton (learnable difficulty curve: fodder → elites → signature → heavies → boss) while slot rolls provide variety; rolling ONCE at run start keeps previews honest — the player commits to a fork knowing the exact comp (legibility, INVARIANTS #5). The b1/signature/boss anchors are each faction's teaching beats: the signature battle forces the faction's core mechanic (Guard Elite shields, Broodwarden leech, Aegis firewalls, Axiom Binder's Mass Snare, a cloaked Panther).

## What it replaced

- "Build 1 faction first" (old GDD) → all 5 fully defined (TRUTH adjudication table).
- Fully authored per-battle comps → role-pool slot patterns (pkg7.1), keeping only the three anchors fixed.
- Per-battle enemy scaling: `battleEnemyScale` (enemies.data.json) and `trackHpScale` survive as **dead data** from the squad-4 tuning era; `AGENTS.md:79` describes a sim-only `--scaled` mode that no longer exists (findings F-enemies-05/-06).

## File locations

- `data/raw/battle-modes.json` — the five templates
- `data/schemas/battle-modes.schema.json` — shape + role docs
- `scripts/autoloads/DataManager.gd:483-556` — battle parsing + role pools
- `scripts/autoloads/GameState.gd:164-215` — comp resolution + slot rolls
- `scripts/autoloads/SaveManager.gd` — unlock chain + boss relics

## Known edge cases

- `heavyOrElites` uses `_reward_rng` (run-seeded) — comp variety is reproducible per run seed.
- Synod b1 is the only 3-enemy opener (Glitch Sprite ×3); facility b10 is the only 3-enemy boss comp, which blocks ASSEMBLY LINE rebuilds only while all three live.
- The `cloaked: true` comp flag (Accretion b4) is the only data-driven battle-start cloak besides Forked Double's `startsCloaked`.
- Support-slot requests in stellarMenagerie silently return elites — by design, documented in the schema.

## ⚠ Open findings

<!-- AUDIT-LINKS:operations -->
- [A-048](../audit/INTERACTION_AUDIT.md#a-048) - [dead] trackHpScale loaded but never read
