# Bosses

> Part of the [Overload Protocol wiki](INDEX.md). See also: [enemies.md](enemies.md), [operations.md](operations.md), [factions.md](factions.md), [combat-resolution.md](combat-resolution.md), [shields-and-ward.md](shields-and-ward.md).

## How it works

Every operation ends at battle 10 with a boss plus a fixed escort. Each boss has exactly **one standing rule, active from turn 1**, keyed by display name in `BOSS_STANDING_RULES` (`scripts/battle/combat_manager.gd:99-105`) — that string is the single source for the inspect popup and the battle-start line (`get_boss_standing_rule`, :208-209). Two firing windows:

- **Round-start rules** fire before the hero phase so they matter this round (`_apply_boss_round_start_rules`, :214-230, called at :645): THE COURT, ACCRETION.
- **Turn-cadence rules** fire at the start of the enemy phase (`_apply_boss_enemy_phase_rules`, :235-275, called at :707): ASSEMBLY LINE, THE BROOD, ROOT ACCESS.

Cadence constants are provisional pending the global balance pass (BALANCE-TODO :107-110; DECISIONS_RESOLVED #8 deferred) and sweepable via the tuning seam (:112-131, `scripts/sim/knobs.json`).

### SCRAPMASTER (facility) — ASSEMBLY LINE
- Rule text: "every 2nd enemy phase from its first activation, rebuilds one destroyed Scrap Drone at 50% HP."
- Code (`combat_manager.gd:240-252`): stamps `assembly_line_first_round` on its first live enemy phase (phase 1); rebuilds when `(round − first) % 2 == 1` → phases 2, 4, 6…; revives the **first dead "Scrap Drone"** at `SCRAPMASTER_REBUILD_PCT` = 50%.
- Cadence semantics are the DECISIONS_RESOLVED #5 ruling (counted from first activation, NOT even-numbered rounds; regression-pinned).
- Stats: 140 HP, d12–22, kit `boss`. Escort: 2× Scrap Drone (b10 comp `data/raw/battle-modes.json:83-94`).
- Signature faces: System Purge (crit) wipes all hero shields before 21 dmg; Annihilate (overload) 26 dmg AoE.

### Hive Matriarch (hive) — THE BROOD
- Rule text: "spawns a Bloodmite every 3 rounds."
- Code (`combat_manager.gd:253-262`): on rounds where `round % BROOD_CADENCE(3) == 0` **and fewer than 3 enemies live**, emits a summon event for "Bloodmite" (injected via the standard dumb-only guard, dead-slot replacement). The field-cap clause is not in the player text — finding F-enemies-08.
- Stats: 180 HP, d15–21, kit `hiveBoss`. Escort: Spine Stalker.
- Signature faces: Chitin Bulwark 22 shield; Acid Cataclysm (overload) wipe shields → 28 dmg + lifesteal 40%.

### CONCLAVE OVERSEER (veil) — THE COURT
- Rule text: "while any ally lives, gains a Firewall at the start of each round."
- Code (`combat_manager.gd:219-227`): round start, if any other living enemy exists and it is not already warded, `_apply_ward` (Firewall doesn't stack — an unbroken Firewall just stays).
- Stats: 180 HP, d19–25, kit `veilBoss`. Escort: Aegis Anchor — kill it and the Court falls, ending the Firewall stream.
- Signature faces: Veil Cataclysm (overload) wipe shields → 30 dmg, +2 roll allies 2t, summon ~30% nat20 (Prism Charger).

### ROOT HIEROPHANT (voidCirclet / Null Synod) — ROOT ACCESS
- Rule text: "every round, Rewrites the squad's highest die to 3."
- Code (`combat_manager.gd:263-275`): each enemy phase, finds the living hero with the highest roll THIS round (strict `>`, ties go to the lower slot) and applies Rewrite — the hero's **next** roll is set to 3 (standard telegraphed Rewrite, `apply_rewrite_to_state` :1336; frozen dice are immune, :1314 — which is why ally crit-banking counters this boss, TRUTH §sim baseline).
- Stats: 180 HP, d19–25, kit `voidCircletBoss`. Escort: Checksum Scribe.
- Signature faces: Hierophant Mantle (recharge) 20 shield + ally 8 + buffs + Firewall (one of the 4 Synod firewall instances); "Circlet Cataclysm" (surge) carries the dead faction name — finding F-enemies-02; Void Gate (overload) wipe shields → 30 dmg + summon ~32% (Glitch Sprite).

### MANTLE TYRANT (stellarMenagerie / The Accretion) — ACCRETION
- Rule text: "gains 6 shield at the start of every round; its shields persist and stack."
- Code: round start `+MANTLE_ROUND_SHIELD(6)` (`combat_manager.gd:228-230`); persistence comes from `shields_persist = true` stamped at battle setup by display name (:38-41), which exempts its stacks from the round-end expiry (:2518-2519). This is one half of the game's SINGLE shield-persistence exception (the other is the Mantle Core relic — TRUTH rule 5).
- Stats: 180 HP, d19–25, kit `beastTyrant`. Escort: Geode Panther.
- Signature faces: Reaver Mantle (recharge) 20 shield + rampage +1 (rampage = next damaging ability ×2, :1548-1551); Annihilation Sweep (crit) rampage ALL; Total Eclipse (overload) wipe shields → 26 dmg + rampage all + freeze-all (repeat 1) — currently rendering ICE crust instead of the faction's petrify (finding F-enemies-09).

## Why it works that way

Standing rules replaced phase-2 stat jumps so a boss's threat is a **single always-true sentence** the player can read at battle start and plan around (INVARIANTS #5/#6) — pressure ramps through the rule (persistent shields, drone rebuilds, spawns) instead of a hidden HP-threshold switch that the inspect text couldn't explain. Round-start vs enemy-phase timing exists so defensive rules (Firewall, shields) matter against THIS round's hero phase while spawn/rebuild rules resolve in the enemy phase like actions.

## What it replaced

- **Phase-2 systems** (flat stat jumps at an HP threshold): deleted in pkg4; the `phase2` feedback event was deleted with it (offline-bundle/ANIMATION.md:13). Remnants: `assets/audio/sfx/phase2.wav` + `AudioManager.gd:12` registration (F-enemies-16); `docs/ABILITY_DESCRIPTIONS_FULL.md` "(P2 34)" numbers (F-enemies-17).
- ASSEMBLY LINE's original "even-numbered rounds" reading → first-activation cadence (DECISIONS_RESOLVED #5, 2026-07-07).
- MANTLE TYRANT's display lineage: void_reaver → mantle_tyrant (portrait renames, TRUTH §Assets); its recharge is still named "Reaver Mantle" (F-enemies-15).

## File locations

- `scripts/battle/combat_manager.gd:82-275` — constants, rule text, both rule executors
- `data/raw/enemies.data.json` — boss kits (`boss`, `hiveBoss`, `veilBoss`, `voidCircletBoss`, `beastTyrant`) + defs
- `data/raw/battle-modes.json` — b10 comps (boss + escort)
- `scripts/sim/knobs.json` — sweepable cadence knobs (`brood_cadence`, `mantle_round_shield`, `scrapmaster_rebuild_pct`)

## Known edge cases

- ASSEMBLY LINE with a late-injected boss (never shipping today) counts from its own first phase — regression-pinned per #5.
- THE BROOD never fires in a full field (3 living); with the Stalker escort alive, round 3 usually spawns into the dead-slot or third slot.
- THE COURT stops the moment the last escort dies, even mid-run of the battle; it also skips the grant while a previous Firewall is unbroken.
- ROOT ACCESS reads THIS round's hero rolls — a hero whose die was frozen (repeat) can still be "highest" but the Rewrite fizzles on the frozen die.
- MANTLE TYRANT's accreted stacks survive Breach only until destroyed — Breach (destroy all shield) is the designed counter; per-round +6 resumes next round.

## ⚠ Open findings

<!-- AUDIT-LINKS:bosses -->
- [A-045](../audit/INTERACTION_AUDIT.md#a-045) - [confusing] 'Reaver Mantle' legacy name + duplicated Total Eclipse
- [A-051](../audit/INTERACTION_AUDIT.md#a-051) - [dead] phase-2 sfx leftover
- [A-052](../audit/INTERACTION_AUDIT.md#a-052) - [confusing] THE BROOD hidden field-cap condition
- [A-053](../audit/INTERACTION_AUDIT.md#a-053) - [confusing] MANTLE TYRANT freeze renders ice, not petrify

Resolved (2026-07-08 fix pass): [A-044](../audit/INTERACTION_AUDIT.md#a-044), [A-057](../audit/INTERACTION_AUDIT.md#a-057)
