# Heroes

> Part of the [Overload Protocol wiki](INDEX.md). See also: [directives.md](directives.md), [keywords.md](keywords.md), [dice-and-rolls.md](dice-and-rolls.md), [targeting.md](targeting.md), [shields-and-ward.md](shields-and-ward.md), [statuses-and-chips.md](statuses-and-chips.md), [protocol-economy.md](protocol-economy.md).

## How it works

The roster is 8 heroes (`data/raw/heroes.data.json`, schema `data/schemas/heroes.data.schema.json`). Each hero has 5 base abilities keyed to the five D20 zones (`recharge` → `strike` → `surge` → `crit` → `overload`), plus 2 evolution paths. Each evolution is a FULL replacement 5-zone kit with its own HP, callsign, per-ability roll ranges, and 2 path-scoped [directives](directives.md). Zone brackets for base kits live in the `heroZones` table (`data/raw/heroes.data.json:3-220`); evolved kits carry their own `range` per ability (the evolution screen merges them via `scripts/ui/evolution_screen.gd:357-375`).

Progression (`scripts/autoloads/GameState.gd`): `XP_TO_EVOLVE := 100` (line 72), `XP_TO_DIRECTIVE := 250` (line 74). Per win: alive → `XP_SURVIVAL_BONUS (20) + round(avg effective roll)`; dead → `round(avg effective roll)` (`GameState.gd:996-1006`). One progression stop per win; extras defer (`_queue_evolution_after_win`, `GameState.gd:1009-1049`). A unit with a directive stops accruing XP (`GameState.gd:979`). Evolution/directive picks route through `scripts/ui/evolution_screen.gd` (1-of-2 cards, zero-options guard at line 156).

Ability resolution: `scripts/battle/combat_manager.gd:926-1152` (`_apply_hero_ability`) and `:1191-1301` (`_apply_hero_ability_damage`). Manual targeting: **max ONE manually-picked component per ability** (INVARIANTS #12) — the pick side is derived in `scripts/battle/battle_scene.gd:2050-2074` (`_get_manual_target_side`); `freezeAnyDice` counts as the pick and is the only "either side" pick. `healLowest`/`shieldLowest` auto-target the lowest-HP living hero (`battle_scene.gd:2135-2141`, `combat_manager.gd:972-976`). A nat-20 overload fires the ability-name slam animation (`scripts/battle/battle_feedback.gd:612-649`).

Unlock state (SaveManager hero ladder): starters `combat`, `engineer`, `medic`; rung 1 → `avalanche`, rung 2 → `shield`, rung 3 → `pulse`, rung 4 → `ghost`, rung 5 → `breaker`. (Batch-1 2026-07-11 swapped engineer↔avalanche between the starter set and rung 1.)

### Roster summary

| ID | Name | Callsign | Class | Category | HP | Evolutions | Availability |
|---|---|---|---|---|---|---|---|
| `pulse` | Pulse Tech | PULSE | ENERGY WIELDER | damage | 45 | Pyro Specialist / Arc Specialist | ladder rung 3 |
| `combat` | Strike Unit | STRIKE | STRIKE OPS | damage | 55 | Bladecore / Ravager | **starter** |
| `shield` | Spike Guard | SPIKE | ANTAGONIST PLATE | defense | 55 | Bulwark / Sentinel | ladder rung 2 |
| `avalanche` | Avalanche Suit | AVALANCHE | SQUAD SHELL | defense | 55 | Glacier Mantle / Trench Rig | **starter** |
| `medic` | Splice Medic | SPLICE | COMBAT AUGMENTOR | support | 50 | Combat Medic / Synth Warden | **starter** |
| `engineer` | Field Engineer | ENGINEER | SUPPORT TECH | support | 50 | Overclocked / Phantom | ladder rung 1 |
| `ghost` | Ghost Operative | GHOST | INFILTRATOR | control | 45 | Shadow Operative / Wraith | ladder rung 4 |
| `breaker` | Signal Breaker | BREAKER | COMMS INTERDICTOR | control | 45 | Noise Floor / Nullwire | ladder rung 5 |

Legacy id quirks (INVARIANTS #11, frozen): Strike Unit=`combat`, Spike Guard=`shield`, Splice Medic=`medic`, and the Combat Medic evolution id is also `medic`.

---

## Pulse Tech (pulse)

Callsign PULSE · ENERGY WIELDER · damage · 45 HP · unlock: hive best_clear ≥ 6 (rung 3). Blurb: "Plants burn on every hit, then detonates it for burst damage." Data: `data/raw/heroes.data.json:222`.

| Zone | Roll | Ability | Eff | Keyword |
|---|---|---|---|---|
| recharge | 1–3 | Static Ping | 4 dmg, chain | chain |
| strike | 4–9 | Arc Burst | 6 dmg, 2 burn, 2t | burn |
| surge | 10–15 | Plasma Lance | 9 dmg, 3 burn, 2t | burn |
| crit | 16–19 | Ion Storm | 12 dmg, detonate | detonate |
| overload | 20 | Singularity Burst | 14 dmg, 3 burn, 3t, chain | burn + chain (overload: 2 allowed) |

Ground-truth check PASSED: chain sits on Static Ping AND Singularity Burst.

### Pyro Specialist (pyro) — 60 HP, "Heavier burns, bigger detonations"

| Zone | Roll | Ability | Eff | Keyword |
|---|---|---|---|---|
| recharge | 1–5 | Ignition Flash | 6 dmg, 2 burn, 2t | burn |
| strike | 6–10 | Accelerant | 8 dmg, 3 burn, 2t | burn |
| surge | 11–15 | Meltdown | 5 dmg, 6 burn, 3t | burn |
| crit | 16–19 | Backdraft | 14 dmg, detonate | detonate |
| overload | 20 | Supernova | 12 dmg (all), 3 burn, 2t | burn (AoE burn: `combat_manager.gd:1233`) |

Directives: **Flashpoint** / **Slow Roast** — see [directives.md](directives.md).

### Arc Specialist (arc) — 60 HP, "Damage that jumps between targets"

The Cryo Specialist path is DEAD — replaced by Arc Specialist (ground-truth check PASSED; stale Cryo text survives only in the untracked `docs/ABILITY_DESCRIPTIONS_FULL.md` and a schema doc-string example, see Open findings).

| Zone | Roll | Ability | Eff | Keyword |
|---|---|---|---|---|
| recharge | 1–5 | Static Coil | 6 dmg | — |
| strike | 6–10 | Arc Whip | 9 dmg, chain | chain |
| surge | 11–15 | Fork Lightning | 12 dmg, chain | chain |
| crit | 16–19 | Cascade | 15 dmg, chain | chain |
| overload | 20 | Grid Collapse | 18 dmg (all) | — |

Directives: **Conductor** / **Amplifier**.

---

## Strike Unit (combat)

Callsign STRIKE · STRIKE OPS · damage · 55 HP · **starter**. Blurb: "Marks targets low, deletes them high. Pure single-target damage." Data: `data/raw/heroes.data.json:536`.

| Zone | Roll | Ability | Eff | Keyword |
|---|---|---|---|---|
| recharge | 1–4 | Target Lock | 3 dmg, mark | mark |
| strike | 5–10 | Suppression Fire | 7 dmg | — |
| surge | 11–15 | Rail Strike | 11 dmg | — |
| crit | 16–19 | Precision Shot | 14 dmg, pierce | pierce (`ignSh`) |
| overload | 20 | Terminal Velocity | 18 dmg, execute | execute |

### Bladecore (blade) — 70 HP, "Wide pierce and shield breaking"

| Zone | Roll | Ability | Eff | Keyword |
|---|---|---|---|---|
| recharge | 1–5 | Target Paint | 5 dmg, mark | mark |
| strike | 6–10 | Rapid Strike | 7 dmg (all) | — |
| surge | 11–15 | Blade Rush | 10 dmg, breach | breach |
| crit | 16–19 | Shred | 15 dmg, pierce | pierce |
| overload | 20 | Decimator | 15 dmg (all), pierce | pierce |

Directives: **Serrated** / **Momentum**.

### Ravager (ravager) — 65 HP, "Leech-fueled brawling"

| Zone | Roll | Ability | Eff | Keyword |
|---|---|---|---|---|
| recharge | 1–5 | Lacerate | 6 dmg, 2 burn, 2t | burn |
| strike | 6–10 | Rend | 9 dmg, leech | leech |
| surge | 11–15 | Deep Wound | 12 dmg, leech | leech |
| crit | 16–19 | Hemorrhage | 14 dmg, detonate | detonate |
| overload | 20 | Evisceration | 20 dmg, leech | leech |

Directives: **Deep Cuts** / **Open Veins**.

---

## Spike Guard (shield)

Callsign SPIKE · ANTAGONIST PLATE · defense · 55 HP · unlock: facility won (rung 2). Blurb: "Taunts hits onto itself, spikes attackers, and breaks enemy shields." Data: `data/raw/heroes.data.json:855`. (Player-visible name is Spike Guard; internal id `shield` is frozen per INVARIANTS #11.)

| Zone | Roll | Ability | Eff | Keyword |
|---|---|---|---|---|
| recharge | 1–6 | Taunt Protocol | taunt (enemies target you) | taunt |
| strike | 7–12 | Enforce | ally 6 shield | — (manual ally pick `shTgt`) |
| surge | 13–16 | Spike Stance | self 5 shield, spike 5 | spike |
| crit | 17–19 | Breach Slam | 9 dmg, breach | breach |
| overload | 20 | Total Suppression | 11 dmg (all), breach all | breach (`breachAll`, strips every enemy's shields before the AoE — `combat_manager.gd:1229-1230`) |

### Bulwark (bulwark) — 80 HP, "Squad-wide shields"

| Zone | Roll | Ability | Eff | Keyword |
|---|---|---|---|---|
| recharge | 1–6 | Fortify | self 7 shield, taunt | taunt |
| strike | 7–12 | Cover Fire | 5 dmg, lowest 7 shield | — |
| surge | 13–16 | Iron Wall | all 6 shield | — |
| crit | 17–19 | Bastion | all 8 shield | — |
| overload | 20 | Invincible | all 10 shield, self firewall | firewall (`ward`) |

**Cover Fire ground-truth check PASSED:** 5 dmg (one manual enemy pick) + automatic 7 shield to the lowest-HP living ally (`shieldLowest`, `combat_manager.gd:972-976`; pick derivation `battle_scene.gd:2064-2071`).

Directives: **Rampart** / **Bunker Doctrine**.

### Sentinel (sentinel) — 70 HP, "Taunt and spike punishment"

| Zone | Roll | Ability | Eff | Keyword |
|---|---|---|---|---|
| recharge | 1–5 | Challenge | self 4 shield, taunt | taunt |
| strike | 6–10 | Counter Stance | spike 6 | spike |
| surge | 11–15 | Punish | 10 dmg | — |
| crit | 16–19 | Repulsion Field | 8 dmg (all), self 6 shield | — |
| overload | 20 | Iron Judgment | 14 dmg, execute | execute |

Directives: **Ironclad** / **Counterweight**.

---

## Avalanche Suit (avalanche)

Callsign AVALANCHE · SQUAD SHELL · defense · 55 HP · **starter**. Blurb: "Freezes dice to lock and repeat results. Heals the squad high." Data: `data/raw/heroes.data.json:1188`. Freeze = REPEAT (DECISIONS_RESOLVED #1); hero-side freeze lives ONLY in this line (ground-truth check PASSED — `freezeAnyDice`/`freezeEnemyDice`/`freezeAllEnemyDice` appear on no other hero).

| Zone | Roll | Ability | Eff | Keyword |
|---|---|---|---|---|
| recharge | 1–6 | Glacial Lattice | freeze any (repeat 1) | freeze (`freezeAnyDice` — no damage component, so the pick is either side per rule 7) |
| strike | 7–12 | Glacial Shove | 6 dmg, freeze (repeat 1) | freeze (`freezeEnemyDice` — damaging, enemy-side rider) |
| surge | 13–16 | Whiteout Spray | 9 dmg (all) | — |
| crit | 17–19 | Crevasse Mend | all 10 heal | — |
| overload | 20 | Avalanche Protocol | 8 dmg (all), freeze all (repeat 1) | freeze (`freezeAllEnemyDice`) |

### Glacier Mantle (glacier) — 80 HP, "Freeze everything, then shatter it"

| Zone | Roll | Ability | Eff | Keyword |
|---|---|---|---|---|
| recharge | 1–6 | Permafrost Weave | self 5 shield, freeze any (repeat 1) | freeze (`freezeAnyDice`) |
| strike | 7–12 | Whiteout Salvo | 5 dmg (all), freeze (repeat 1) | freeze (enemy-side pick; AoE dmg needs no pick, so still one pick) |
| surge | 13–16 | Shatter Lance | 10 dmg, +5 vs frozen | — (`vsFrozenBonus` is a rider, not a keyword — `combat_manager.gd:1249-1255`) |
| crit | 17–19 | Permafrost Aegis | 14 dmg, +8 vs frozen | — (`vsFrozenBonus` rider; Batch-1 redesign from shield+freeze) |
| overload | 20 | Absolute Zero | 10 dmg (all), freeze all (repeat 1) | freeze |

Shatter exists ONLY here (Shatter Lance rider + Shatterpoint directive) and in the Cold Logic relic (`combat_manager.gd:1815`) — ground-truth check PASSED.

Directives: **Deep Freeze** / **Shatterpoint**.

### Trench Rig (trench) — 85 HP, "Firewalls, taunts, and deep sustain"

| Zone | Roll | Ability | Eff | Keyword |
|---|---|---|---|---|
| recharge | 1–6 | Stabilize | 10 heal (ally) | — |
| strike | 7–12 | Dig In | self 8 shield, taunt | taunt |
| surge | 13–16 | Bunker Firewall | 5 heal (self), ally firewall | firewall (`ward`+`wardTgt`, manual ally pick) |
| crit | 17–19 | Trench Breaker | 18 dmg, breach | breach |
| overload | 20 | Last Bastion | all 10 heal, all 8 shield | — |

Directives: **Field Triage** / **Entrench**.

---

## Splice Medic (medic)

Callsign SPLICE · COMBAT AUGMENTOR · support · 50 HP · **starter**. Blurb: "Heals allies low, drains enemies mid, hits shockingly hard on 20." Data: `data/raw/heroes.data.json:1521`.

| Zone | Roll | Ability | Eff | Keyword |
|---|---|---|---|---|
| recharge | 1–4 | Diagnostic Pulse | 4 heal (ally) | — |
| strike | 5–11 | Infusion | 8 heal (ally) | — |
| surge | 12–16 | Neural Override | 8 dmg, leech | leech |
| crit | 17–19 | Synaptic Overload | 12 dmg, leech | leech |
| overload | 20 | Shock Therapy | 20 dmg | — |

### Combat Medic (medic) — 65 HP, "Frontline healing and a strong revive"

(Evolution id `medic` — same string as the hero id; frozen legacy quirk.)

| Zone | Roll | Ability | Eff | Keyword |
|---|---|---|---|---|
| recharge | 1–5 | Triage | 6 heal (ally) | — |
| strike | 6–10 | Bio-Shock | 9 dmg, leech | leech |
| surge | 11–15 | Trauma Protocol | 12 heal (ally) | — |
| crit | 16–19 | Suppression Heal | 10 dmg, all 8 heal | — (one manual pick: the dmg; heal is squad-auto) |
| overload | 20 | Surge Revive | revive ally 70% | — (`revive` + `revivePct: 70`; pick side "dead_hero" — `battle_scene.gd:2058-2059`) |

Directives: **Combat Sense** / **Field Surgeon**.

### Synth Warden (synth) — 70 HP, "Squad triage and mass revival"

| Zone | Roll | Ability | Eff | Keyword |
|---|---|---|---|---|
| recharge | 1–5 | System Patch | lowest 8 heal | — (auto-lowest, no pick) |
| strike | 6–10 | Overclock Mesh | all 5 shield | — |
| surge | 11–15 | Emergency Protocol | lowest 12 heal | — |
| crit | 16–19 | Adrenaline Surge | 6 dmg (all), all 6 heal | — (zero picks) |
| overload | 20 | Mass Revival | revive all 30% | — (`reviveAll` + `revivePct: 30`, no pick) |

Directives: **Overcharge Mesh** / **Lazarus Loop**.

---

## Field Engineer (engineer)

Callsign ENGINEER · SUPPORT TECH · support · 50 HP · unlock: rung 1 (facility best_clear ≥ 6 OR 3 real runs). Blurb: "Generates Protocol and shields low, then turns to squad-wide damage." Data: `data/raw/heroes.data.json:1849`.

| Zone | Roll | Ability | Eff | Keyword |
|---|---|---|---|---|
| recharge | 1–4 | Field Patch | 4 shield (self), +1 protocol | — |
| strike | 5–10 | Barrier Deploy | ally 9 shield | — |
| surge | 11–15 | Overdrive | 11 dmg | — |
| crit | 16–19 | Missile Volley | 9 dmg (all) | — |
| overload | 20 | Scorched Earth | 12 dmg (all), +2 protocol | — |

`gainProtocol` routes through the pending-grant pipeline (`combat_manager.gd:1011-1017`).

### Overclocked (overclocked) — 65 HP, "A walking Protocol engine"

| Zone | Roll | Ability | Eff | Keyword |
|---|---|---|---|---|
| recharge | 1–5 | Bias Charge | self 4 shield, +1 protocol | — |
| strike | 6–10 | Chain Shot | 9 dmg, chain | chain |
| surge | 11–15 | Overclock Burst | 14 dmg | — |
| crit | 16–19 | Cascade Array | 11 dmg (all) | — |
| overload | 20 | Meltdown Protocol | 18 dmg, 3 burn, 2t, +2 protocol | burn |

Directives: **Deep Cells** / **Surge Wiring**.

### Phantom (phantom) — 60 HP, "Cloaked strikes that jam dice"

| Zone | Roll | Ability | Eff | Keyword |
|---|---|---|---|---|
| recharge | 1–5 | Stealth Field | Cloak | cloak |
| strike | 6–10 | EMP Pulse | 7 dmg, jam | jam |
| surge | 11–15 | Phantom Shield | self 10 shield, Cloak | cloak |
| crit | 16–19 | Ghost Volley | 14 dmg (all), pierce | pierce |
| overload | 20 | Total Blackout | 12 dmg (all), jam all | jam (`jamAll`) |

Directives: **Silent Running** / **Ambush Wiring**.

---

## Ghost Operative (ghost)

Callsign GHOST · INFILTRATOR · control · 45 HP · unlock: hive won (rung 4). Blurb: "Cloaks past big hits and strikes from stealth." Data: `data/raw/heroes.data.json:2177`.

| Zone | Roll | Ability | Eff | Keyword |
|---|---|---|---|---|
| recharge | 1–2 | Cloak Protocol | Cloak | cloak |
| strike | 3–8 | Probe Strike | 7 dmg | — |
| surge | 9–13 | System Breach | 9 dmg, breach | breach |
| crit | 14–19 | Phase Blade | 13 dmg, pierce | pierce |
| overload | 20 | Execution Protocol | 16 dmg, execute | execute |

### Shadow Operative (shadow) — 65 HP, "Hit-and-vanish burst"

| Zone | Roll | Ability | Eff | Keyword |
|---|---|---|---|---|
| recharge | 1–5 | Ghost Step | 5 dmg, Cloak | cloak (decloaks on the hit, re-cloaks after — engine order `combat_manager.gd:947`, then `:1082`) |
| strike | 6–10 | Shadow Strike | 12 dmg | — |
| surge | 11–15 | Vanishing Act | 10 dmg, Cloak | cloak |
| crit | 16–19 | Phantom Blade | 15 dmg, pierce | pierce |
| overload | 20 | Death from Shadow | 20 dmg, pierce | pierce |

Directives: **Ghostblade** / **Vanish**.

### Wraith (wraith) — 60 HP, "Mark them, then execute them"

| Zone | Roll | Ability | Eff | Keyword |
|---|---|---|---|---|
| recharge | 1–5 | Scan Weakness | 4 dmg, mark | mark |
| strike | 6–10 | Neural Hack | 8 dmg, mark | mark |
| surge | 11–15 | Assassinate | 14 dmg, execute | execute |
| crit | 16–19 | Wraith Blade | 15 dmg, pierce | pierce |
| overload | 20 | Execution Protocol | 18 dmg, pierce, execute | pierce + execute (overload: 2 allowed) |

Note: "Execution Protocol" is also the ghost BASE overload name — a harmless duplicate today (no name-keyed directive references it), but name-keyed directive effects (`abilityRevivePctOverride`, `abilityProtocolBonus`) mean new duplicates should be avoided.

Directives: **Marked for Death** / **Reaper**.

---

## Signal Breaker (breaker)

Callsign BREAKER · COMMS INTERDICTOR · control · 45 HP · unlock: veil best_clear ≥ 6 (rung 5). Blurb: "Drags every enemy roll down and jams their strongest dice." Data: `data/raw/heroes.data.json:2497`. ±Roll chips live ONLY in this line (ground-truth check PASSED — `rfe` appears on no other hero; no hero carries `rfm` at all).

| Zone | Roll | Ability | Eff | Keyword |
|---|---|---|---|---|
| recharge | 1–2 | Wideband Hiss | all -2 roll | −roll (no `rfT` in data → engine default **1t**, `combat_manager.gd:1026`; eff omits the duration — see F-heroes-04) |
| strike | 3–8 | Spike Coupler | 7 dmg, -2 roll, 2t | −roll |
| surge | 9–13 | Harmonic Glitch | all -2 roll, 2t | −roll |
| crit | 14–19 | Phase Tear | 12 dmg, jam | jam |
| overload | 20 | Total Bandkill | 14 dmg (all), all -3 roll, 2t | −roll |

### Noise Floor (noise) — 65 HP, "Tray-wide suppression"

| Zone | Roll | Ability | Eff | Keyword |
|---|---|---|---|---|
| recharge | 1–5 | Carrier Wash | 3 dmg (all), all -1 roll, 2t | −roll |
| strike | 6–11 | Scatterjam | 7 dmg (all), all -1 roll, 2t | −roll |
| surge | 12–14 | Resonant Cage | all -3 roll, 3t | −roll |
| crit | 15–19 | Collapse Field | 12 dmg, all -2 roll, 2t | −roll |
| overload | 20 | White Noise Core | 16 dmg (all), jam all | jam |

Directives: **Wall of Static** / **Feedback**.

### Nullwire (nullwire) — 60 HP, "Locks and rewrites single dice"

| Zone | Roll | Ability | Eff | Keyword |
|---|---|---|---|---|
| recharge | 1–5 | Lock Tone | 6 dmg, -2 roll, 2t | −roll |
| strike | 6–10 | Bit Spike | 9 dmg, jam | jam |
| surge | 11–15 | Deep Cut | 12 dmg, -2 roll, 2t | −roll |
| crit | 16–19 | Spectral Sever | 14 dmg, rewrite | rewrite |
| overload | 20 | Kill Carrier | 18 dmg, pierce, rewrite | pierce + rewrite (overload: 2 allowed) |

Directives: **Hard Lock** / **Signal Theft**.

---

## Why it works that way

- **One keyword per ability, two on overload** (INVARIANTS #3, audit-enforced): phone-legibility budget. All 120 hero abilities comply (audited 2026-07-07; the only two-keyword faces are Singularity Burst, Wraith's Execution Protocol, and Kill Carrier — all overloads).
- **One manual pick per ability** (INVARIANTS #12): one die tap → at most one target tap. All abilities comply; `freezeAnyDice` is the pick; `shieldLowest`/`healLowest`/`healAll`/`blastAll` components are automatic.
- **Freeze = repeat, Avalanche-line exclusive hero-side** (DECISIONS_RESOLVED #1): non-damage freezes use `freezeAnyDice` (ally-banking is intentional tech — it drove the voidCirclet +10.5 sim jump, TRUTH §Sim baseline); freeze riders on damaging abilities stay enemy-side.
- **Evolution ids = lowercased callsigns**, schema-enforced enum (`heroes.data.schema.json:119-125`), drive the portrait convention `assets/portraits/<hero_id>_<evo_id>.png` (TRUTH §Assets).
- **Directives at 250 XP, path-scoped 1-of-2** (pkg6): see [directives.md](directives.md).

## What it replaced

- **Cryo Specialist → Arc Specialist** (pulse second path). The dead Cryo kit (Frost Shard / Cryo Shell / Ice Lance / Cryogenic Lock / Permafrost Burst) survives only in the untracked `docs/ABILITY_DESCRIPTIONS_FULL.md` snapshot and the schema's "e.g. CRYO" doc-string.
- **Spite Guard → Spike Guard** (faction/name pass); internal id `shield` frozen.
- **Retaliate → spike keyword**; Sentinel had a literal "Retaliate" ability in the old dataset (see the stale doc), now Counter Stance (spike 6).
- **Freeze lineage**: bank/thaw → next-turn lockout ("1 reveal skip", still visible in the stale doc) → repeat (final).
- **Cower merged into freeze; Venom/Decay → Burn; Counterspell-% → deterministic Ward/Firewall; probabilistic Cloak ("80% evade") → untargetability** — none appear in current hero data (audited: zero occurrences).
- **Multi-round shields (`shT`) removed** (DECISIONS_RESOLVED #2): zero shield-duration fields in hero data.
- **XP consumable items removed**; XP flows only from battle wins.

## File locations

- `data/raw/heroes.data.json` — all 8 heroes, 16 evolutions, 32 directives (2831 lines)
- `data/schemas/heroes.data.schema.json` — schema (hero/evolution id enums, directive shape)
- `scripts/battle/combat_manager.gd` — ability + directive resolution
- `scripts/battle/battle_scene.gd` — manual-target derivation, auto-assign
- `scripts/battle/battle_engine.gd` — protocol cap (Deep Cells)
- `scripts/ui/evolution_screen.gd` — evolution/directive picker
- `scripts/autoloads/GameState.gd` — XP thresholds, evolution/directive state
- `docs/ABILITY_DESCRIPTIONS_FULL.md` — STALE untracked snapshot (do not trust; see findings)

## Known edge cases

- **Ghostblade's pending-execute flag** (`decloak_execute_pending`, `combat_manager.gd:954-955`) is consumed only in the single-target damage branch (`:1265-1267`). Shadow Operative's kit is all single-target so it can't strand today, but an AoE decloak attack (future kit/gear) would leave the flag set for a later hit.
- **Feedback chip damage** keys off TOTAL rfe stacks (`combat_manager.gd:2530`), not the carrier's own — see F-heroes-05.
- **Re-cloak ordering**: on "X dmg, Cloak" abilities the unit decloaks (taking Ambush Wiring/Ghostblade riders if evolved into them via the other path — impossible today since directives are path-scoped), deals damage, then re-cloaks in the same resolution.
- **Rampart + Overcharge Mesh stack**: a Bulwark shield grant with a living Synth Warden carrier gets both +2s (`:965` then `:878`).
- **Entrench** shield obeys the normal one-round expiry — it covers round 1's enemy phase only.
- **Duplicate ability names across kits** ("Execution Protocol" ×2) are safe today but interact with name-keyed directive effects.
- **`_get_manual_target_side` checks freeze before damage** (`battle_scene.gd:2052-2055`), so dmg+freeze abilities present as one enemy pick shared by both components.

## ⚠ Open findings

<!-- AUDIT-LINKS:heroes -->
- [A-036](../audit/INTERACTION_AUDIT.md#a-036) - [dead] ABILITY_DESCRIPTIONS_FULL.md fossil teaches dead mechanics
- [A-037](../audit/INTERACTION_AUDIT.md#a-037) - [confusing] schema doc-string cites the dead CRYO callsign
- [A-038](../audit/INTERACTION_AUDIT.md#a-038) - [confusing] evo-screen help says portraits are not evolved
- [A-039](../audit/INTERACTION_AUDIT.md#a-039) - [confusing] Wideband Hiss eff text omits its 1t duration
- [A-040](../audit/INTERACTION_AUDIT.md#a-040) - [confusing] heroAbility schema additionalProperties:true

Resolved (2026-07-08 fix pass): [A-041](../audit/INTERACTION_AUDIT.md#a-041)
