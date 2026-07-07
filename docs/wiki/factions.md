# Factions

> Part of the [Overload Protocol wiki](INDEX.md). See also: [enemies.md](enemies.md), [bosses.md](bosses.md), [operations.md](operations.md), [keywords.md](keywords.md).

## How it works

Five factions, one per operation. The faction is derived from the enemy's kit via `ENEMY_FACTION_BY_TYPE` (`scripts/autoloads/DataManager.gd:98-135`); the operation entry in `data/raw/battle-modes.json` carries the player-facing `label`, `callsign`, and `blurb`. Internal faction ids are the operation keys and are **frozen** (INVARIANTS #11).

| Internal id | Player name (label) | Callsign | Mechanical theme | Boss | Units |
|---|---|---|---|---|---|
| `facility` | Facility sweep | FACILITY | drones: jam, −roll, shields as breach bait | SCRAPMASTER | 8 |
| `hive` | Hive incursion | HIVE | swarm: burn, leech (lifesteal), spawns, spike | Hive Matriarch | 7 |
| `veil` | Veil Concord | VEIL | lattice: ally shields, roll buffs, 6 firewall faces, nat20 summons | CONCLAVE OVERSEER | 8 |
| `voidCirclet` | Null Synod | SYNOD | machine cult: rewrite, hijack, siphon, ±roll, 4 firewall faces | ROOT HIEROPHANT | 7 |
| `stellarMenagerie` | The Accretion | ACCRETION | igneous beasts: accrete shields, petrify freeze, spike, cloak, rampage | MANTLE TYRANT | 8 |

### Faction identities in data (verified)

- **Facility** — fodder drones debuff and jam (`rust`, `signalSkimmer`); elites shield each other (`guard`); Volt Elite is one of the game's four **spike** carriers. Wall-up-then-breach is the intended player loop (blurb: "Bank Protocol and breach through").
- **Hive** — every core kit leeches (`lifestealPct` 35–55%) and burns; Spine Stalker + Carapace Beetle carry **spike**; the Matriarch's THE BROOD is the faction's spawn engine; Caustic Spewer's "Mimic Gland" is one of exactly three **hijack** carriers. Note: TRUTH's identity line says "siphon" — no hive kit has siphon; that's the Synod's (finding F-enemies-12).
- **Veil Concord** — support lattice: nearly every kit grants ally shields and `erb` roll buffs; carries 6 of the 10 enemy **firewall** instances (Lattice Link, Fortress Lash, Conclave Bulwark, Harmonic Mend, Annulment, Synaptic Tune); five smart units summon on nat20 (Shardmite / Prism Charger).
- **Null Synod** — dice suppression: **rewrite** (4 faces), **hijack** (Checksum Copy, Afterimage), **siphon** (the ONLY siphon carriers: voidWisp, voidAcolyte, voidBinder, voidChanneler), ±roll; 4 firewall instances (Seal Sigil, Init Collar, Mass Snare, Hierophant Mantle); all five smart units summon Glitch Sprites on nat20.
- **The Accretion** — attrition beasts: `accrete` shields every enemy phase (Basalt Ape 3, Magma Drake 4), **petrify**-flavored freeze (Geode Panther), **spike** (Basalt Ape), cloak (Panther, and the b4 comp flag), pack fodder, and MANTLE TYRANT's rampage. Default targeting SPITEFUL — the faction holds grudges ([targeting.md](targeting.md)).

Keyword exclusivity across factions (audit-verified): spike = Volt Elite, Spine Stalker, Carapace Beetle, Basalt Ape only · hijack = Spewer, Scribe, Forked Double only · siphon = Synod only · firewall = exactly 10 instances (6 Veil + 4 Synod) · shatter = nowhere in enemies.

## Why it works that way

Each faction owns one slice of the mechanic space so an operation *teaches* its counterplay: Facility teaches breach/protocol banking, Hive teaches burst-before-the-swarm-scales, Veil teaches kill-the-supports, Synod teaches protecting your best dice (freeze-banking counters ROOT ACCESS — TRUTH §sim baseline), Accretion teaches cutting through compounding armor. The dice-suppression budget (INVARIANTS #4) is deliberately concentrated in the Synod so only one faction attacks the dice directly (plus the Facility's jam as the tutorial-grade version).

## What it replaced

Naming history (old → new, renamed in the master-prompt/keyword era; player-facing only — internal ids frozen):

| Old player name | New player name | Internal id (frozen) |
|---|---|---|
| Void Circlet | **Null Synod** | `voidCirclet` |
| Stellar Menagerie | **The Accretion** | `stellarMenagerie` |
| Spite Guard (hero faction name) | **Spike Guard** (hero, id `shield`) | — |

- The rename is complete in `battle-modes.json` (labels/callsigns/blurbs) and unit/ability strings with two exceptions found by this audit: the help-menu bestiary headers still say "VOID CIRCLET" / "STELLAR MENAGERIE" (`scripts/ui/help_menu.gd:41-42`, finding F-enemies-01) and the ROOT HIEROPHANT surge is still named "Circlet Cataclysm" (`data/raw/enemies.data.json:1683`, F-enemies-02).
- Unit-name lineage from the same era survives only in git history and renamed portraits (eclipse_panther→geode_panther, void_reaver→mantle_tyrant, chronicle_scribe→checksum_scribe, etc. — TRUTH §Assets). `legacy-angular/` keeps old-name art as a warehouse (INVARIANTS #11); `.godot/imported/` caches with dead names are regenerated artifacts.
- Internal-id occurrence inventory (frozen, needs-Kev-ruling ledger only): see findings F-enemies-21.

## File locations

- `data/raw/battle-modes.json` — labels, callsigns, blurbs, victory strings
- `scripts/autoloads/DataManager.gd:98-135` — kit→faction map
- `scripts/ui/help_menu.gd:36-43` — bestiary order + labels (stale labels)
- `scripts/autoloads/SaveManager.gd:17-30` — per-faction boss relic map + operation chain

## Known edge cases

- Faction is per-KIT, not per-unit: a summoned Slag Hound in any battle still reads as Accretion.
- The Accretion has **no support-role unit**; the role pool falls back to elites (`DataManager.gd:549-556`) — documented in the battle-modes schema.
- The hero "Spike Guard" (id `shield`) is unrelated to enemy factions but shares the rename family — do not "fix" the id.

## ⚠ Open findings

<!-- AUDIT-LINKS:factions -->
- [A-056](../audit/INTERACTION_AUDIT.md#a-056) - [confusing] TRUTH says Hive siphon; it is leech

Resolved (2026-07-08 fix pass): [A-043](../audit/INTERACTION_AUDIT.md#a-043), [A-060](../audit/INTERACTION_AUDIT.md#a-060)
