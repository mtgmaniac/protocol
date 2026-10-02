# Design audit — 2026-10-02 (read-only)

Source tree: `origin/playtest-fixes-2026-10-01` at `e3cb5e6`. No code or data was
changed; this file is the only output. Descriptive only: findings, counts and
evidence, no recommendations. Where a finding touches a closed ruling, the ruling
is cited and the finding stops there.

**How the numbers were made.** Data figures are read from the data files as the
game loads them (`DataManager`, dumped once). Sim figures come from the shipped
balance sim (`scenes/sim/sim_main.tscn`, the real `combat_manager`), policy **L1**
(greedy), Linux Godot 4.6.2, run one batch at a time with one worker:

| Batch | Runs | Squad / operation | Seeds |
|---|---|---|---|
| `audit_main` | 1,500 | uniform random squad and operation per run | 500000–501499 |
| `audit_hiero_<squad>` | 56 squads × 30 = 1,680 | every 3-hero squad, Signal Purge | 700000–700029 for every squad (matched) |

Sim caveats that apply throughout: L1 is a heuristic, not a player. It never spends
the two cloak consumables (it drafted them 384 times and used them 0 times), it
spends Nudge in 59% of rounds, and it has no round limit other than the harness's
500-round safety cap. "Live" behaviour that the sim does not model (dice physics,
the UI) is marked as code-reading.

---

## Summary — the five findings that most change the design picture

1. **Every enemy shares one dice shape, and its 1–4 band never deals damage.** All
   38 enemy units use the same bands (1–4 / 5–10 / 11–16 / 17–19 / 20; hard-coded in
   `DataManager.ENEMY_ZONE_RANGES`), and on all 38 the 1–4 ability deals no damage.
   On top of that, 12 of the 16 evolution branches share one band shape and 3 more
   share a second. Any effect that forces a die to a low value (Rewrite to 3, Deep
   Zero Pin's 1, a freeze on a 1–4 face) therefore turns any enemy into a non-attacker
   for as long as it holds.
   Combined with the boss 1–4 faces (20–22 self-shield each), that produced **ten
   permanent stalemates across 3,180 sim runs, every one a boss fight with a Glacier
   Rig holding the Deep Freeze directive** (10 of 583 such fights; 0 of 1,897 boss
   fights without that pairing). The game has no round limit (section 5).
2. **Summons are concentrated in three places.** Two final bosses add units on a
   schedule (Scrapmaster rebuilds 5.7 drones per fight, Hive Matriarch births 3.9
   Bloodmites per fight); everything else that summons does it only on a die showing
   20, and 0.06–0.32 times per appearance. Veil (5 of 7 non-boss units) and Signal
   Purge (4 of 6 working, plus one inert flag) are summon rosters; Facility and Hive
   have no summoning units at all, only their boss rule. 4 of 5 final bosses add
   units (section 1).
3. **Cloak almost never survives its holder's next turn.** Dealing damage breaks
   cloak before the damage lands, and seven of the sixteen evolution branches have no
   non-damaging face at all. Shadow Operative — the cloak branch — cloaked 7,037
   times and kept it through its next round 4 times (0.06%). Enemy cloaks last a
   full round 17–18% of the time. The payoffs for leaving cloak that exist are all
   directives at 250 XP (section 2).
4. **Units differ more by branch than by base hero, and base heroes barely differ
   in toughness.** Base HP spans 45–55 (one 10-point range across all eight); no hero
   has an innate passive before its 250 XP Directive; four branches (Ravager, Shadow
   Operative, Wraith, Nullwire) have practically the same profile — about 10.5
   damage per roll, no sustain, no no-damage faces, 60–65 HP (section 3).
5. **The Hierophant fight is a composition check, and a Medic is most of it.** Over
   all 56 squads (1,680 runs), squads with a Splice Medic beat the Hierophant 38.6% of
   the times they reached it, squads without one 18.3%; with Medic and Spike Guard
   53.4%; with none of Medic, Spike Guard or Ghost 9.1%. Six squads won 1 time or
   fewer in 16–27 attempts, none of them with a Medic. ROOT ACCESS hands the squad's
   top roller a forced 3 every round, and on 13 of 24 kits that face deals no damage
   (section 5). Repetition is the other op-5 complaint: Mantle Hunt (operation 5) has
   the most single-enemy rounds, the lowest clear rate, and Geode Panther 4.6 times
   per run; Signal Purge repeats Signal Wisp 9.75 times per run (section 6).

---

## 1. Summons

**What summons.** Three mechanisms (all `combat_manager.gd`):

* **20-face summon abilities** (`summonChance` + `summonName` on an ability). They
  fire only when the enemy's die *ends* on 20 (any route: rolled, buffed, hijacked;
  NK-02 removed the natural-20 distinction), the unit is `ai: smart` with
  `summonElite: true`, and fewer than 3 enemies are alive. Then the chance is rolled
  from the seeded stream; a frozen 20 rolls again each repeat (G-8). The summoned unit
  takes a dead slot or a new one. Kill rewards apply normally (G-8).
* **Brood** (Hive Matriarch standing rule): a Bloodmite every 3rd round while fewer
  than 3 enemies live.
* **Assembly Line** (Scrapmaster standing rule): every 2nd enemy phase from its first,
  one destroyed Scrap Drone stands back up at 50% HP (DECISIONS #5). This revives an
  existing slot rather than adding one.

**Every 20-face summon ability** (all on the 20 band, the only band any summon uses):

| Unit | Operation | Role | Ability | Chance | Summons | Fired in sim (per battle the unit started in) |
|---|---|---|---|---|---|---|
| Veil Overseer | Veil | **boss** | Veil Cataclysm | 30% | Prism Charger | 41 / 127 = 0.32 |
| Phaseblade | Veil | elite | Phase Reinforcements | 40% | Shard Drone | 121 / 1,255 = 0.10 |
| Aegis Anchor | Veil | support | Shieldline Rally | **42%** | Shard Drone | 128 / 599 = 0.21 |
| Relay Herald | Veil | support | Relay Reinforcements | 40% | Shard Drone | 14 / 72 = 0.19 |
| Resonance Warden | Veil | heavy | Veil Rally | 40% | Prism Charger | 39 / 202 = 0.19 |
| Stormweaver | Veil | heavy | Lattice Storm | **42%** | Prism Charger | 16 / 212 = 0.08 |
| Signal Hierophant | Signal Purge | **boss** | Machine Crusade | 32% | Signal Wisp | 80 / 258 = 0.31 |
| Circuit Acolyte | Signal Purge | elite | Ritual Muster | 40% | Signal Wisp | 47 / 788 = 0.06 |
| Cipher Scribe | Signal Purge | support | Summon Verse | 45% | Signal Wisp | 112 / 520 = 0.22 |
| Oath Binder | Signal Purge | heavy | Binding Decree | 35% | Signal Wisp | 41 / 545 = 0.08 |
| Ash Channeler | Signal Purge | heavy | Ashen Muster | **42%** | Signal Wisp | 33 / 365 = 0.09 |
| Cinder Raptor | Mantle Hunt | elite | Brood Call | 50% | Slag Hound | 77 / 871 = 0.09 |

Standing-rule summons in the same batch: Scrapmaster rebuilt 931 Scrap Drones in 164
fights (**5.7 per fight**); Hive Matriarch birthed 907 Bloodmites in 232 fights
(**3.9 per fight**).

**False Image** carries `summonElite: true` but no ability with a summon, so the flag
does nothing (13 flagged units, 12 that can summon).

**Share of each roster that summons** (non-boss units / boss):

| Operation | Non-boss units that summon | Boss adds units? | Battles with ≥1 summon (sim) |
|---|---|---|---|
| Facility | 0 of 7 | yes — Assembly Line (revive) | 164 / 2,331 = 7.0% (all boss fights) |
| Hive | 0 of 6 | yes — Brood | 232 / 2,823 = 8.2% (all boss fights) |
| Veil | **5 of 7** | yes — 30% on its 20 | 285 / 2,187 = **13.0%** |
| Signal Purge | **4 of 6** (+ False Image's inert flag) | yes — 32% on its 20 | 250 / 2,848 = 8.8% |
| Mantle Hunt | 1 of 7 | no | 66 / 2,917 = 2.3% |

**Final bosses: 4 of 5 add units** (Scrapmaster, Hive Matriarch on a schedule;
Veil Overseer, Signal Hierophant on their 20). The battle-10 escorts of the two
20-face bosses also summon (Aegis Anchor 42%, Cipher Scribe 45%), so in those fights
two enemies can call reinforcements. Only Mantle Tyrant adds nothing.

**The "summon (42%)" the playtest saw.** Three abilities carry exactly 42%: Aegis
Anchor's *Shieldline Rally*, Stormweaver's *Lattice Storm* and Ash Channeler's
*Ashen Muster*. (TRUTH quotes the old name: "Conclave Bulwark's long-press read
'firewall, summon (42%)'" — that is Aegis Anchor.) The 42% applies only after the
unit's die ends on 20 and the field has a free slot, so the chance per enemy turn is
5% × 42% ≈ 2.1% with no roll buffs. Veil's `+N roll (all allies)` buffs widen the
range of raw faces that end on 20 (with +2, raws 18–20 do). That is one plausible
contributor to the spread at equal chances (Aegis Anchor 0.21 vs Ash Channeler 0.09
per appearance, both 42%); battle length and how often the field is full also differ,
and the sim does not separate them.

### Questions for Kev
* Two bosses summon on a schedule (≈4–6 units per fight), two only on a 20 (≈0.3 per
  fight). Is that split intended, or should the four "boss adds units" rules read as
  one family?
* Veil and Signal Purge carry nearly all ability summons; Facility and Hive carry
  none outside the boss. Is "summoner roster" meant to be an operation identity?
* False Image's `summonElite` flag is inert. Intended, or a missing ability?

---

## 2. Cloak and stealth

**Rules (code).** Cloak has no timer: it lasts until broken. It is broken by (a) the
cloaked unit's own ability dealing damage — checked **before** the damage resolves,
on both sides (`combat_manager.gd` 1356, 2019); (b) any AoE hit (2245); (c) death.
While cloaked a unit can't be picked by hostile single-target abilities; friendly
picks stay legal (DECISIONS #12). If every hero is cloaked, enemies fall back to the
first living hero. Cloak is 2 clauses since the keyword batch (K1: pierce-from-cloak
removed).

**Every cloak source**

| Source | Kind | Who | Notes |
|---|---|---|---|
| Active Camouflage (1–2) | hero ability | Ghost Operative base | cloak only |
| Ghost Step (1–5) | hero ability | Shadow Operative | 5 damage, then cloak |
| Strike and Fade (11–15) | hero ability | Shadow Operative | 10 damage, then cloak |
| Stealth Field (1–5) | hero ability | Phantom Engineer | cloak only |
| Phantom Shield (11–15) | hero ability | Phantom Engineer | 10 shield + cloak |
| Silent Running | directive | Phantom Engineer | re-cloak after any no-damage ability |
| Vanish | directive | Shadow Operative | cloak once per battle on dropping below 50% HP |
| Ghost Veil (`ghost_veil`, uncommon) | consumable | any hero | "Cloak 1 hero" |
| Scatter Veil Array (`scatter_veil_array`, rare) | consumable | squad | "Cloak all heroes" |
| Phase Weave (`phase_weave`, uncommon) | gear | holder | battle start: cloak |
| Ghost Frequency | major intercept | one hero | starts every remaining battle cloaked, −6 max HP |
| Refork (1–4) + starts cloaked | enemy | False Image | 6 shield (self), cloak |
| Geode Veil (1–4) | enemy | Geode Panther | 10 shield (self), cloak |

**Who can benefit (non-attack faces while cloaked).** A cloak on a hero survives
that hero's next action only if the die lands on a face that deals no damage. Per
kit (raw faces, before buffs):

| No-damage faces | Kits |
|---|---|
| **0 / 20** | Pulse Tech; Pyro, Arc, Blade Trooper, Ravager, Shadow Operative, Wraith, Nullwire |
| 2–5 | Ghost Operative 2, Noise 3, Strike Unit 4, Overclock 5 |
| 6–11 | Glacier 6, Breaker 7, Avalanche 9, Engineer 10, Phantom 10, Sentinel 10, Splice Medic 11, Combat Medic 11 |
| 14–17 | Bulwark 14, Spike Guard 16, Synth 16, Trench 17 |

Seven of the sixteen branches (and Pulse Tech's base kit) can never act while staying
cloaked. **Shadow Operative**, the cloak branch, is one of them: both its cloak
abilities deal damage first, and every other face deals damage, so its next action
always breaks the cloak.

**Shield + cloak combinations.** Phantom Shield (10 shield + cloak, self), Geode
Panther's 1–4 (10 shield + cloak), False Image's 1–4 (6 shield + cloak), and any
cloak source stacked with a shield source (Phase Weave + Combat Plating at battle
start; Entrench + Phase Weave or Ghost Frequency; a cloak consumable + any shield).
Shields last one opposing action phase (DECISIONS #2); while the holder is cloaked
the only attacks that can reach it are AoE, and an AoE hit both consumes the shield
and breaks the cloak. So a shield on a cloaked unit only ever absorbs AoE.

**Payoff for leaving stealth.** Exists only as directives at 250 XP: Ambush Wiring
(Phantom Engineer: attacks from cloak +5 damage) and Ghostblade (Shadow Operative:
the first attack out of cloak also executes). Enemy cloaks have none (the code comment
reads "a plain attack"). No base kit and no item has one.

**Cloak in the sim** (1,500 runs; a cloak "survives the round" if the unit is still
cloaked after the round following the one it was cloaked in; cloaks whose battle
ended in the same round excluded):

| Cloaked unit | Cloaks | Broken next round | Still cloaked after it |
|---|---|---|---|
| Shadow Operative | 7,037 | 7,016 | **4 (0.06%)** |
| Ghost Operative (base) | 787 | 717 | 70 (8.9%) |
| Geode Panther | 1,958 | 1,605 | 353 (18.0%) |
| False Image | 962 | 796 | 166 (17.3%) |

What broke it: hero cloaks 8,494 times by the hero's own attack, 17 times by an
enemy AoE. Enemy cloaks 1,702 by their own attack, 1,643 by a hero AoE. A further
684 hero decloaks came from battle-start cloaks (Phase Weave / Ghost Frequency),
which emit no "cloak" event and are not in the table. L1 drafted Ghost Veil 136
times and Scatter Veil Array 248 times and used neither, so cloak consumables are
unmeasured.

### Questions for Kev
* Should cloak survive a hero's own *damaging* action in any case (the playtest
  complaint), given that 8 of 24 kits have no other kind of action? The current
  2-clause rule is K1.
* Is Shadow Operative meant to be a cloak branch? Its kit can't stay cloaked.
* Should a shield granted together with cloak be expected to do anything, given that
  only AoE can reach a cloaked unit?

---

## 3. Unit differentiation

**Band shapes.** All 38 enemies use one shape: 1–4 / 5–10 / 11–16 / 17–19 / 20
(widths 4/6/6/3/1, `DataManager.ENEMY_ZONE_RANGES`). **On all 38, the 1–4 ability
deals no damage** (shield, buff, cloak or hijack). Heroes: base kits vary
(3/6/6/4/1, 4/6/5/4/1, 6/6/4/3/1, 4/7/5/3/1, 2/6/5/6/1). Evolutions (extending the
existing band-shape finding rather than redoing it): **12 of 16 branches use
5/5/5/4/1**, 3 use 6/6/4/3/1 (Bulwark, Glacier Rig, Trench Rig), 1 is unique (Noise
Specialist 5/6/3/5/1). The "14 of 16" figure is not in any repo doc; the data gives
12 + 3 + 1.

**Heroes** (avg damage = expected damage of one roll, single target; AoE shown as
faces; heal+shield likewise):

| Unit | HP | Bands | Avg damage | AoE faces | Avg heal+shield | No-damage faces |
|---|---|---|---|---|---|---|
| **Pulse Tech** (base) | 45 | 3/6/6/4/1 | 8.2 | 0 | 0.0 | 0/20 |
| Pyro Specialist | 60 | 5/5/5/4/1 | 8.2 | 1 | 0.0 | 0/20 |
| Arc Specialist | 60 | 5/5/5/4/1 | 10.7 | 1 | 0.0 | 0/20 |
| **Strike Unit** (base) | 55 | 4/6/5/4/1 | 8.0 | 0 | 0.0 | 4/20 |
| Blade Trooper | 70 | 5/5/5/4/1 | 9.2 | 6 | 0.0 | 0/20 |
| Ravager | 65 | 5/5/5/4/1 | 10.6 | 0 | 0.0 | 0/20 |
| **Spike Guard** (base) | 55 | 6/6/4/3/1 | 1.9 | 1 | 2.8 | 16/20 |
| Bulwark | 80 | 6/6/4/3/1 | 1.5 | 0 | 7.1 | 14/20 |
| Sentinel | 70 | 5/5/5/4/1 | 4.8 | 4 | 2.2 | 10/20 |
| **Avalanche Suit** (base) | 55 | 6/6/4/3/1 | 4.0 | 5 | 1.5 | 9/20 |
| Glacier Rig | 80 | 6/6/4/3/1 | 6.1 | 7 | 1.5 | 6/20 |
| Trench Rig | 85 | 6/6/4/3/1 | 2.7 | 0 | 7.3 | 17/20 |
| **Splice Medic** (base) | 50 | 4/7/5/3/1 | 4.8 | 0 | 4.7 | 11/20 |
| Combat Medic | 65 | 5/5/5/4/1 | 4.2 | 0 | 6.1 | 11/20 |
| Synth Medic | 70 | 5/5/5/4/1 | 1.2 | 4 | 7.5 | 16/20 |
| **Field Engineer** (base) | 50 | 4/6/5/4/1 | 4.9 | 5 | 3.5 | 10/20 |
| Overclock Engineer | 65 | 5/5/5/4/1 | 8.8 | 4 | 1.0 | 5/20 |
| Phantom Engineer | 60 | 5/5/5/4/1 | 5.2 | 5 | 2.5 | 10/20 |
| **Ghost Operative** (base) | 45 | 2/6/5/6/1 | 7.5 | 0 | 0.0 | 2/20 |
| Shadow Operative | 65 | 5/5/5/4/1 | 10.8 | 0 | 0.0 | 0/20 |
| Wraith | 60 | 5/5/5/4/1 | 10.4 | 0 | 0.0 | 0/20 |
| **Signal Breaker** (base) | 45 | 2/6/5/6/1 | 6.4 | 1 | 0.0 | 7/20 |
| Noise Specialist | 65 | 5/6/3/5/1 | 6.7 | 12 | 0.0 | 3/20 |
| Nullwire | 60 | 5/5/5/4/1 | 10.4 | 0 | 0.0 | 0/20 |

**Spread, glassiest to tankiest.** Base heroes: HP 45 (Pulse, Ghost, Breaker) →
50 (Medic, Engineer) → 55 (Strike Unit, Spike Guard, Avalanche) — max/min 1.22. Branches:
60 → 85 (1.42). The damage axis is wider (base 1.9–8.2, branches 1.2–10.8). In the
base kits HP and damage are only loosely traded: by average damage the order is
Pulse 8.2 (45 HP), Strike Unit 8.0 (55), Ghost 7.5 (45), Breaker 6.4 (45), Engineer 4.9
(50), Medic 4.8 (50), Avalanche 4.0 (55), Spike Guard 1.9 (55) — the highest-HP tier
includes both the second-highest and the lowest damage.

**Near-identical profiles** (HP within 10%, avg damage within 1.0, heal+shield
within 1.0, same number of no-damage faces):

* Branches: **Ravager ≈ Shadow Operative ≈ Wraith ≈ Nullwire** (60–65 HP, 10.4–10.8
  damage, 0 sustain, 0 no-damage faces, single target). No base pair qualifies.
* Enemies: Scrap Drone ≈ Prism Charger ≈ Skitterling; Rust Drone ≈ Obsidian Hound ≈
  Pumice Climber; Static Skimmer ≈ Signal Wisp ≈ Pumice Climber; Shard Drone ≈ Slag
  Hound (identical numbers: 34 HP, 7.3, 0.8); Heavy Warden ≈ Resonance Warden;
  Cipher Scribe ≈ Geode Panther. **Obsidian Hound and Slag Hound share one kit**
  (`beastWolf`, 37 kits for 38 units).

**Enemies** (heal+shield includes ally shields; accrete not included):

| Enemy | Op | Role | HP | Avg damage | Heal+shield | HP ÷ damage |
|---|---|---|---|---|---|---|
| Scrap Drone | Facility | fodder | 35 | 8.3 | 1.6 | 4.2 |
| Static Skimmer | Facility | fodder | 40 | 6.2 | 1.0 | 6.5 |
| Rust Drone | Facility | fodder | 45 | 7.0 | 1.0 | 6.4 |
| Patrol Enforcer | Facility | elite | 60 | 14.2 | 1.2 | 4.2 |
| Volt Enforcer | Facility | elite | 65 | 9.5 | 1.0 | 6.8 |
| Shield Enforcer | Facility | support | 70 | 11.1 | 4.5 | 6.3 |
| Heavy Warden | Facility | heavy | 95 | 12.7 | 2.4 | 7.5 |
| Scrapmaster | Facility | boss | 140 | 13.2 | 2.4 | 10.6 |
| Bloodmite | Hive | fodder | 26 | 6.2 | 0.6 | 4.2 |
| Skitterling | Hive | fodder | 30 | 7.8 | 1.0 | 3.9 |
| Spine Stalker | Hive | elite | 49 | 12.2 | 1.2 | 4.0 |
| Carapace Beetle | Hive | support | 80 | 9.3 | 7.4 | 8.6 |
| Broodwarden | Hive | heavy | 90 | 10.1 | 2.8 | 9.0 |
| Caustic Spewer | Hive | heavy | 90 | 7.2 | 0.0 | 12.5 |
| Hive Matriarch | Hive | boss | 135 | 16.9 | 4.4 | 8.0 |
| Prism Charger | Veil | fodder | 32 | 8.7 | 1.2 | 3.7 |
| Shard Drone | Veil | fodder | 34 | 7.3 | 0.8 | 4.6 |
| Phaseblade | Veil | elite | 60 | 13.1 | 1.0 | 4.6 |
| Aegis Anchor | Veil | support | 58 | 11.5 | 8.5 | 5.0 |
| Relay Herald | Veil | support | 65 | 9.4 | 5.5 | 6.9 |
| Stormweaver | Veil | heavy | 90 | 9.5 | 0.0 | 9.5 |
| Resonance Warden | Veil | heavy | 100 | 11.9 | 3.1 | 8.4 |
| Veil Overseer | Veil | boss | 153 | 17.7 | 6.0 | 8.6 |
| Signal Wisp | Signal Purge | fodder | 38 | 6.2 | 0.0 | 6.1 |
| Circuit Acolyte | Signal Purge | elite | 62 | 11.2 | 0.0 | 5.5 |
| False Image | Signal Purge | elite | 68 | 11.0 | 1.2 | 6.2 |
| Cipher Scribe | Signal Purge | support | 74 | 9.3 | 1.8 | 7.9 |
| Ash Channeler | Signal Purge | heavy | 94 | 13.4 | 0.0 | 7.0 |
| Oath Binder | Signal Purge | heavy | 112 | 12.9 | 0.0 | 8.7 |
| Signal Hierophant | Signal Purge | boss | 180 | 17.7 | 5.6 | 10.2 |
| Slag Hound | Mantle Hunt | fodder | 34 | 7.3 | 0.8 | 4.7 |
| Pumice Climber | Mantle Hunt | fodder | 38 | 6.5 | 0.6 | 5.8 |
| Obsidian Hound | Mantle Hunt | fodder | 42 | 7.3 | 0.8 | 5.8 |
| Geode Panther | Mantle Hunt | elite | 74 | 9.9 | 2.0 | 7.5 |
| Cinder Raptor | Mantle Hunt | elite | 86 | 8.9 | 2.4 | 9.7 |
| Magma Drake | Mantle Hunt | heavy | 98 | 10.0 | 1.6 | 9.8 |
| Basalt Ape | Mantle Hunt | heavy | 112 | 10.8 | 2.8 | 10.3 |
| Mantle Tyrant | Mantle Hunt | boss | 180 | 16.6 | 4.0 | 10.8 |

Enemy spread is real but set by role, not by unit: within a role the HP ÷ damage
ratio sits in a narrow band (fodder 3.7–6.5, elites 4.0–9.7, heavies 7.0–12.5).
Mantle Hunt's elites and heavies are the slowest to kill per point of threat in the
game.

**Innate / passive abilities that exist today.**
* Heroes: none before the Directive (250 XP). `UnitData.passives` is empty and
  `directive` is `{}` for all eight base heroes.
* Enemies (unit-level, not per band): Accrete (Basalt Ape 3, Magma Drake 4),
  starts cloaked (False Image), the summon flag (13 units, 1 inert), and the five
  boss standing rules. `EnemyData.traits` exists and is empty on all 38 units.
  Ability-level riders that behave like passives: Pack Bonus (3 units), lifesteal
  (11 abilities).

### Questions for Kev
* Should base heroes differ in HP by more than 10 points, or are toughness
  differences meant to arrive only through evolutions?
* Four branches converge on the same "≈10.5 damage, no sustain" profile. Intended
  convergence or a gap?
* `EnemyData.traits` is a ready-made home for innate enemy abilities and is unused.
  Is that the place innate abilities are meant to go?

---

## 4. Beasts (Mantle Hunt / "Accretion")

**Roster:** fodder Slag Hound (34), Pumice Climber (38), Obsidian Hound (42); elites
Geode Panther (74; cloak, freezes the lowest hero die), Cinder Raptor (86; taunt,
lifesteal, 50% summon on its 20); heavies Magma Drake (98; accrete 4), Basalt Ape
(112; accrete 3, spike, strips shields); boss Mantle Tyrant (180; rampage, freeze
all, persistent shields).

**Pack Bonus.** `+1 damage per OTHER living enemy of the same kind` (kind =
`enemy_type`, so both hounds count as one kind), added after Rampage doubling.
Carried by Pumice Climber (5–10), Obsidian Hound and Slag Hound (5–10 and 20). With
at most 3 enemies on the field the ceiling is +2. **In 1,500 runs it fired on 338 of
1,640 pack attacks (20.6%) and the bonus was +1 every time; +2 never occurred.**
Per unit: Obsidian 157, Slag 131, Pumice 50.

**Rampage.** A charge: the unit's next damaging hit deals double, then the charge
is spent. No timer — charges persist until used or the unit dies; charges stack
(+1 per grant). Sources: Tyrant Mantle (Tyrant 1–4, self), Dominance Roar (17–19,
all allies), Mantle Rupture (20, all allies). In 265 Tyrant fights the Tyrant spent
1,033 charges; 2,495 Tyrant attacks dealt damage (Titan Gouge 1,100, Molten Stomp
901, Dominance Roar 365, Mantle Rupture 129), so **41% of the Tyrant's damaging
attacks were doubled**. Geode Panther spent 96 granted charges.

**Accrete.** Each enemy turn, before the enemy phase, the unit gains a flat N shield
(N = its `accrete` field: Basalt Ape 3, Magma Drake 4) as an ordinary shield stack
flagged to survive the imminent round-end tick, so it covers the next hero phase and
then expires. It does **not** accumulate: the shield present at any time is that
turn's 3 or 4 (capped at max HP). Only the Mantle Tyrant keeps shields
(`shields_persist`, its ACCRETION standing rule, +6 every 2nd round) — the single
named exception in DECISIONS #2 / TRUTH Combat rule 5.

**What the player is shown for Accrete.** The shield float and chip each enemy
turn; the Help bestiary keyword row shows "accrete" without the number; the
first-sighting primer shows the keyword definition ("gains N shield at the start
of each of its turns"), also without the number. No ability text and no inspect
line carries N. The role text says **"Grows armour every turn"** for both units,
which describes accumulation; the shield does not accumulate (DECISIONS #2).

### Questions for Kev
* Pack Bonus never reached +2 in 1,500 runs. Is +1 the intended working size of the
  mechanic, or should comps put three of a kind together?
* Should "Grows armour every turn" describe what Accrete does, or should Accrete do
  what the text says? (The latter runs into DECISIONS #2.)

---

## 5. Signal Hierophant

**ROOT ACCESS, as coded.** At the start of the enemy phase the Hierophant finds the
hero whose **raw** die was highest *this* round and sets a Rewrite on that hero: the
hero's *next* roll becomes 3, overriding every buff and Jam (G-43 presents it as a
tip-over after landing). A frozen die refuses the Rewrite, and ROOT ACCESS does not
fall back to the next-highest die. Each Rewrite also pays Mirror Plate (+2 Protocol).

**Clear rate by squad** (`audit_hiero_*`: every one of the 56 three-hero squads, 30
Signal Purge runs each, seeds 700000–700029 for every squad, L1; a squad's row
counts only the runs that reached battle 10). Overall: 1,434 of 1,680 runs reached
the Hierophant and **379 beat it (26.4%)**. With 10–30 fights per row, a single
row's 95% interval is roughly ±15–20 points; the pooled figures are firmer.

| Squad | Reached the Hierophant | Beat it | Win rate when reached | Stalemates | Median rounds |
|---|---|---|---|---|---|
| Pulse + Strike Unit + Engineer | 27 / 30 | 1 | 0.04 | 0 | 10 |
| Pulse + Strike Unit + Breaker | 26 / 30 | 1 | 0.04 | 0 | 12 |
| Spike Guard + Avalanche + Breaker | 23 / 30 | 1 | 0.04 | 0 | 16 |
| Pulse + Avalanche + Breaker | 22 / 30 | 1 | 0.05 | 0 | 11 |
| Strike Unit + Spike Guard + Avalanche | 18 / 30 | 1 | 0.06 | 1 | 17 |
| Pulse + Strike Unit + Avalanche | 16 / 30 | 1 | 0.06 | 1 | 11 |
| Pulse + Avalanche + Engineer | 28 / 30 | 2 | 0.07 | 0 | 11 |
| Spike Guard + Engineer + Breaker | 26 / 30 | 2 | 0.08 | 0 | 20 |
| Pulse + Engineer + Breaker | 25 / 30 | 2 | 0.08 | 0 | 12 |
| Pulse + Spike Guard + Avalanche | 10 / 30 | 1 | 0.10 | 0 | 14 |
| Strike Unit + Avalanche + Engineer | 27 / 30 | 3 | 0.11 | 0 | 11 |
| Pulse + Spike Guard + Engineer | 18 / 30 | 2 | 0.11 | 0 | 14 |
| Strike Unit + Avalanche + Breaker | 26 / 30 | 3 | 0.12 | 0 | 13 |
| Pulse + Engineer + Ghost | 24 / 30 | 3 | 0.12 | 0 | 10 |
| Spike Guard + Avalanche + Engineer | 30 / 30 | 4 | 0.13 | 0 | 15 |
| Avalanche + Engineer + Ghost | 29 / 30 | 4 | 0.14 | 0 | 11 |
| Strike Unit + Engineer + Breaker | 29 / 30 | 4 | 0.14 | 0 | 13 |
| Pulse + Ghost + Breaker | 27 / 30 | 4 | 0.15 | 0 | 12 |
| Strike Unit + Spike Guard + Engineer | 25 / 30 | 4 | 0.16 | 0 | 14 |
| Pulse + Strike Unit + Medic | 29 / 30 | 5 | 0.17 | 0 | 12 |
| Avalanche + Engineer + Breaker | 28 / 30 | 5 | 0.18 | 0 | 12 |
| Pulse + Strike Unit + Ghost | 27 / 30 | 5 | 0.19 | 0 | 10 |
| Engineer + Ghost + Breaker | 29 / 30 | 6 | 0.21 | 0 | 12 |
| Strike Unit + Engineer + Ghost | 28 / 30 | 6 | 0.21 | 0 | 11 |
| Spike Guard + Engineer + Ghost | 26 / 30 | 6 | 0.23 | 0 | 13 |
| Avalanche + Medic + Engineer | 28 / 30 | 7 | 0.25 | 0 | 12 |
| Strike Unit + Spike Guard + Breaker | 28 / 30 | 7 | 0.25 | 0 | 20 |
| Strike Unit + Ghost + Breaker | 27 / 30 | 7 | 0.26 | 0 | 13 |
| Pulse + Spike Guard + Ghost | 19 / 30 | 5 | 0.26 | 0 | 13 |
| Strike Unit + Avalanche + Medic | 26 / 30 | 7 | 0.27 | 1 | 13 |
| Pulse + Medic + Ghost | 26 / 30 | 7 | 0.27 | 0 | 11 |
| Avalanche + Medic + Breaker | 29 / 30 | 8 | 0.28 | 0 | 14 |
| Medic + Engineer + Breaker | 29 / 30 | 8 | 0.28 | 0 | 13 |
| Avalanche + Ghost + Breaker | 28 / 30 | 8 | 0.29 | 0 | 13 |
| Strike Unit + Spike Guard + Ghost | 28 / 30 | 8 | 0.29 | 0 | 14 |
| Pulse + Spike Guard + Breaker | 24 / 30 | 7 | 0.29 | 0 | 18 |
| Pulse + Medic + Breaker | 27 / 30 | 8 | 0.30 | 0 | 15 |
| Strike Unit + Medic + Breaker | 30 / 30 | 9 | 0.30 | 0 | 14 |
| Spike Guard + Avalanche + Ghost | 23 / 30 | 7 | 0.30 | 0 | 13 |
| Medic + Ghost + Breaker | 26 / 30 | 8 | 0.31 | 0 | 14 |
| Pulse + Avalanche + Ghost | 19 / 30 | 6 | 0.32 | 0 | 9 |
| Pulse + Avalanche + Medic | 24 / 30 | 8 | 0.33 | 1 | 13 |
| Spike Guard + Avalanche + Medic | 26 / 30 | 9 | 0.35 | 0 | 18 |
| Pulse + Strike Unit + Spike Guard | 17 / 30 | 6 | 0.35 | 0 | 14 |
| Strike Unit + Medic + Engineer | 28 / 30 | 10 | 0.36 | 0 | 11 |
| Strike Unit + Spike Guard + Medic | 25 / 30 | 9 | 0.36 | 0 | 18 |
| Strike Unit + Avalanche + Ghost | 27 / 30 | 10 | 0.37 | 0 | 11 |
| Pulse + Medic + Engineer | 27 / 30 | 10 | 0.37 | 0 | 12 |
| Medic + Engineer + Ghost | 25 / 30 | 10 | 0.40 | 0 | 12 |
| Strike Unit + Medic + Ghost | 28 / 30 | 12 | 0.43 | 0 | 12 |
| Spike Guard + Ghost + Breaker | 28 / 30 | 15 | 0.54 | 0 | 15 |
| Pulse + Spike Guard + Medic | 25 / 30 | 14 | 0.56 | 0 | 17 |
| Spike Guard + Medic + Engineer | 30 / 30 | 18 | 0.60 | 0 | 16 |
| Avalanche + Medic + Ghost | 29 / 30 | 18 | 0.62 | 0 | 13 |
| Spike Guard + Medic + Ghost | 25 / 30 | 16 | 0.64 | 0 | 17 |
| Spike Guard + Medic + Breaker | 30 / 30 | 20 | 0.67 | 0 | 24 |

**Near zero (≤ 6%):** Pulse + Strike Unit + Engineer (1 / 27), Pulse + Strike Unit + Breaker
(1 / 26), Spike Guard + Avalanche + Breaker (1 / 23), Pulse + Avalanche + Breaker
(1 / 22), Strike Unit + Spike Guard + Avalanche (1 / 18), Pulse + Strike Unit + Avalanche
(1 / 16). None of them has a Medic.

**Pooled** (each hero is in 21 of the 56 squads): Medic 38.6%, Spike Guard 32.1%,
Ghost 31.2%, Breaker 23.6%, Avalanche 22.1%, Strike Unit 22.0%, Engineer 20.7%, Pulse
20.3%. Squads **with a Medic 38.6% (221 / 572), without 18.3% (158 / 862)**; with
both Medic and Spike Guard 53.4% (86 / 161); with neither 15.8% (82 / 519); with no
Medic, Spike Guard or Ghost 9.1% (23 / 254). The six best squads (54–67%) all contain
Medic or Spike Guard: four contain both, the other two pair one of them with Ghost. This matches the
playtest report that the fight needs a defense-and-leech squad: the Medic's damage
bands carry leech, and Spike Guard brings taunt and shields.

In `audit_main` (random squads) the Hierophant was beaten in 82 of 258 battle-10
fights (31.8%).

**What each hero does on a forced 3** (the face ROOT ACCESS hands the top roller):

| Kit | Ability at 3 | Deals damage? |
|---|---|---|
| Pulse Tech / Pyro / Arc | Static Ping / Ignition Flash / Static Coil | yes |
| Strike Unit / Blade / Ravager | Target Lock (mark) / Target Paint / Thermal Cut | base no, branches yes |
| Spike Guard / Bulwark / Sentinel | Challenge Beacon / Fortify / Challenge (taunt) | no |
| Avalanche / Glacier / Trench | Cryo Lattice / Permafrost Weave / Stabilize | no |
| Splice Medic / Combat Medic / Synth | Diagnostic Pulse / Triage / System Patch | no |
| Field Engineer / Overclock / Phantom | Field Patch / Bias Charge / **Stealth Field (cloak)** | no |
| Ghost / Shadow / Wraith | Probe Strike / Ghost Step (5 dmg + cloak) / Scan Weakness | yes |
| Breaker / Noise / Nullwire | Disruptor Coupler / Carrier Wash / Lock Tone | yes |

13 of 24 kits deal no damage at 3. On the enemy side **3 falls in the 1–4 band for
all 38 enemies, which never deals damage**: every enemy Rewrite a hero lands
(Nullwire's 16–19 and 20 abilities) skips that enemy's attack, and on Geode Panther and
False Image it re-cloaks them.

**Cloak at 3.** Phantom Engineer's 3 is Stealth Field (cloak, no damage); with Silent
Running it re-cloaks after every no-damage ability. Shadow Operative's 3 is Ghost
Step (5 damage, then cloak): the damage breaks any cloak, then it re-cloaks. ROOT
ACCESS therefore cloaks a Phantom Engineer that rolled highest; cloak lasts until
broken (section 2). Cloak alone does not stall the fight: enemies fall back to the
first living hero when all are cloaked, and the other two heroes still act.

**Every forced value × threshold interaction found**

Forced values: Rewrite → 3 (ROOT ACCESS every round; Circuit Acolyte, Cipher Scribe,
Oath Binder, False Image on heroes; Nullwire on enemies) · Jam → cap 10 (Static
Skimmer ×3, Heavy Warden, Phantom ×2, Breaker, Nullwire, Noise; Static Field relic;
Wall of Static caps 15) · Set → any value (4 Protocol) · Deep Zero Pin → every enemy
die to 1 + freeze · Hijack → copy of the heroes' highest die (Caustic Spewer, Cipher
Scribe, False Image) · Freeze → repeat the locked face (many sources) · forced 20
(Martyrdom Protocol, Dead Man's Hand) · hold (Tectonic Charge round 1).

| # | Interaction | Effect | Can stall or permanently disable? |
|---|---|---|---|
| 1 | Rewrite 3 × enemy 1–4 bands | rewritten enemy never attacks that round | disables 1 round |
| 2 | Rewrite 3 × hero kits | 13/24 kits lose their attack | no (1 round, other heroes act) |
| 3 | Rewrite 3 × Phantom / Geode / False Image | forced re-cloak | no by itself |
| 4 | Freeze (repeat) × enemy 1–4 band | enemy repeats a no-damage face for N rounds | **yes — see #6** |
| 5 | Deep Zero Pin (1 + freeze) × 1–4 bands | every enemy skips this round and its repeat | 2 rounds |
| 6 | **Freeze × boss 1–4 self-shield × squad damage ≤ shield** | boss repeats 20–22 shield and never attacks; squad can't out-damage the shield | **yes — permanent stalemate, observed** |
| 7 | Jam 10 × every 20-threshold (summons, Overload Capacitor, Predator Lens, Overload Loop) | jammed unit can't reach 20 or the 11+ bands | 1 round |
| 8 | Forced 20 × Jam / Rewrite | Jam caps it to 10; Rewrite makes it 3 | no |
| 9 | Freeze × Rewrite / Jam | frozen die is immune; ROOT ACCESS fizzles that round if the top die is frozen | no |
| 10 | Rewrite 3 × Scrap Converter (pays on a landing of 1–2) | pays on the physical landing before the tip to 3 | no |
| 11 | Geode freeze × hero's lowest die | the hero repeats its lowest face of the round, which is often a no-damage face (the 1–4/1–6 bands of 13 of 24 kits deal none) | 1+ rounds; chains while Geode keeps rolling 5–10 or 17–19 |
| 12 | Freeze-any on one's own die × Deep Freeze (2 turns) | Avalanche/Glacier can alternate self-freeze and enemy-freeze so both stay frozen indefinitely | rules allow a permanent lock; Deep Freeze is also in all 10 observed #6 stalemates |

**Interaction #6 in the sim:** 10 battle-10 fights (6 in `audit_main`, 4 in the
Hierophant batch) were still running at the harness's 500-round safety cap. Every
one has a **Glacier Rig with the Deep Freeze directive** (freezes last 1 extra turn)
whose Absolute Zero (20: 10 damage to all + freeze all enemies) or Whiteout Salvo
kept freezing the boss on its 1–4 face before the previous freeze ran out: Veil
Overseer (Overseer Mantle, 22 shield + 8 ally) ×4, Signal Hierophant (Hierophant
Mantle, 20 shield + firewall) ×5, Mantle Tyrant (Tyrant Mantle, 20 shield, shields
persist) ×1. In each, the surviving heroes' damage per round stayed below the
shield; e.g. `run_500341`: a lone Glacier Rig at 80 HP against the Overseer at 117,
rounds 101–498 identical. Boss fights by squad state (both batches):

| Operation | Glacier + Deep Freeze | Glacier, other directive or none | No Glacier |
|---|---|---|---|
| Veil | **4 / 28** | 0 / 5 | 0 / 94 |
| Signal Purge | 5 / 413 | 0 / 189 | 0 / 1,090 |
| Mantle Hunt | 1 / 55 | 0 / 27 | 0 / 183 |
| Hive | 0 / 57 | 0 / 16 | 0 / 159 |
| Facility | 0 / 30 | 0 / 12 | 0 / 122 |

The game itself has no round limit, so a live battle in that state would not end
unless the player changes what they do. (L1 keeps Setting the Glacier die to 20; a
player could choose not to freeze.) Freeze = repeat is DECISIONS #1;
the shield expiry it interacts with is DECISIONS #2.

### Questions for Kev
* Is a battle allowed to reach a state no player action can end (interaction #6)?
  The game has no round cap.
* ROOT ACCESS reads the *raw* top die, ignores the frozen die without falling back,
  and pays Mirror Plate every round. All three are as coded; are all three intended?
* Self-freeze + Deep Freeze (#12) allows a permanent enemy lock. Intended?

---

## 6. Repetition and decision density

**Rosters** (unique units per operation, from data; boss counted separately):

| Operation | Fodder | Elite | Support | Heavy | Boss | Unique |
|---|---|---|---|---|---|---|
| Facility | 3 | 2 | 1 | 1 | 1 | 8 |
| Hive | 2 | **1** | 1 | 2 | 1 | 7 |
| Veil | 2 | **1** | 2 | 2 | 1 | 8 |
| Signal Purge | **1** | 2 | 1 | 2 | 1 | 7 |
| Mantle Hunt | 3 | 2 | 0 (falls back to elite) | 2 | 1 | 8 |

**Appearances per run** (sim, starting comps only; median run sees 7 distinct
enemies; the most-repeated enemy in a run appears a median 6 times, max 11):

| Operation | Most repeated (appearances per run) |
|---|---|
| Signal Purge | **Signal Wisp 9.75**, Circuit Acolyte 2.61, False Image 2.56 |
| Hive | Spine Stalker 5.50, Skitterling 4.44, Bloodmite 3.34 |
| Mantle Hunt | Geode Panther 4.56, Pumice Climber 3.16, Cinder Raptor 2.80 |
| Veil | Phaseblade 4.36, Prism Charger 3.52, Shard Drone 3.51 |
| Facility | Scrap Drone 4.03, Rust Drone 2.68, Shield Enforcer 2.36 |

Signal Wisp is also every Signal Purge summon. Hive's and Veil's single-unit elite
pools are the source of Spine Stalker's and Phaseblade's counts (the same cause the
2026-10-01 no-repeat re-roll addressed for back-to-back battles).

**Single-enemy fights** (starting comp of one unit):

| Operation | Share of battles | Where |
|---|---|---|
| Mantle Hunt | 761 / 2,917 = **26.1%** | b1 (fixed), b4, b5 |
| Hive | 722 / 2,823 = **25.6%** | b1, b7 (fixed), b5 |
| Signal Purge | 384 / 2,848 = 13.5% | b4, b5 |
| Veil | 263 / 2,187 = 12.0% | b4, b5 |
| Facility | 153 / 2,331 = 6.6% | b4 |

Rounds with exactly one enemy alive, all causes: 11.5% overall (Mantle Hunt 16.1%,
Hive 15.6%, Facility 5.3%).

**Decision density (proxies from 95,967 sim rounds).** A hero action has "one valid
target" when its ability needs a hostile pick and one enemy is alive; "no choice"
when it needs no pick at all (self, all, auto).

* Hero actions: 127,693 hostile picks with ≥2 targets, 34,479 friendly picks,
  19,065 hostile picks with exactly one target, 92,249 with no pick.
* **13.0% of rounds** had every acting hero on a no-pick or single-target ability
  (Veil 16.8%, Hive 15.8%, Mantle Hunt 14.8%, Facility 8.9%, Signal Purge 9.2%).
  Only 1.3% of rounds also started with 0 Protocol, so a spend decision was almost
  always available.
* L1 spent Protocol in 67.9% of rounds; Nudge in 59.2% (63,015 Nudges, 8,769
  Rerolls, 3,453 items, 284 Sets).

The sim can't see whether a choice was *meaningful*; these proxies only count rounds
where no choice existed.

### Questions for Kev
* Operation 5 is Mantle Hunt, where the playtest felt repetitive. In the sim it has
  the highest share of single-enemy battles (26.1%) and one-enemy rounds (16.1%), the
  lowest L1 clear rate (53 / 311 = 17.0%), and Geode Panther appears 4.56 times per
  run. Signal Purge (op 4) repeats Signal Wisp 9.75 times per run from a one-unit
  fodder pool. Which of these reads as the repetition the playtest felt?
* Single-enemy fights were the most enjoyed. They are a quarter of Hive and Mantle
  Hunt but 7% of Facility. Is that distribution intended?
* Nudge is used in most rounds by the greedy policy. Is a near-automatic Nudge the
  intended texture, or a sign the decision is too obvious?

---

## 7. Dice manipulation inventory

| Effect | Who has it | Side affected | Duration |
|---|---|---|---|
| Nudge +3 | player (1 Protocol); Priming Charge free first; Reverse Gimbal −3 | own dice | that roll |
| Firewall Hack −3 | boss relic, once per turn | enemy die | that round |
| Set (any value, plain 1–20 die) | player (4 Protocol) | own dice | that roll |
| Reroll | player (2 Protocol); Phase Scrambler (1 enemy), Cascade Jammer (all enemies); Heretic Signal (all unfrozen dice, once per battle) | both | that roll |
| Rewrite → 3 | ROOT ACCESS; Circuit Acolyte, Cipher Scribe, Oath Binder, False Image; Nullwire | both | next roll |
| Jam → cap 10 (15) | Static Skimmer, Heavy Warden; Phantom Engineer, Breaker, Nullwire, Noise; Static Field relic; Hard Lock / Wall of Static directives | both | next roll |
| Freeze (repeat N) | Avalanche line (any die / enemy / all enemies); Geode Panther (lowest hero die / all heroes); Mantle Tyrant (all heroes); Cryo Gel/Web; Deep Zero Pin (set 1 + freeze); Blood Frenzy (killer's own die) | both | N repeats |
| Hijack (copy the heroes' highest die) | Caustic Spewer, Cipher Scribe, False Image | enemy's own die | next roll |
| Roll buffs / debuffs ±N | many abilities and items (rfm/rfe/erb), Emergency Signal, Momentum/Calibration items | both | N turns |
| Forced 20 | Martyrdom Protocol, Dead Man's Hand | heroes | next roll |
| Hold (no roll) | Tectonic Charge | heroes | round 1 |

**Permanent today (run- or battle-long):**
* Gear: Neural Splice +2 rolls, Predator Lens +3 rolls (run-long, holder); Band
  Compressor (20-ability also on 19), Wide Aperture (third ability starts 2 lower).
* Relics: Coordinated Strike +2 all hero rolls, Standing Order (fourth ability 1
  lower), **Signal Jam −2 all enemy rolls** (battle-long; the only permanent
  enemy-side modifier), Tectonic Charge +3 from round 2.
* Intercepts: Overclock Chamber +1 rolls (run-long, one hero); The Splice Deal (band
  changes).

Everything permanent is hero-granted; no enemy grants itself, or the heroes, a
permanent modifier.

### Questions for Kev
* Permanent dice changes exist only as player rewards. Is a permanent enemy-side
  modifier (beyond Signal Jam) in or out of the "complexity budget" (INVARIANTS #4)?

---

## 8. Targeting clarity

**What the battle UI shows.** Each enemy card shows one target label: the hostile
pick, "Self", one ally, or "All Squad" (`battle_scene._auto_assign_enemy_target`).
The hero damage preview forecasts damage only. Riders that land somewhere else appear
only in the ability text (readout / long-press).

**Enemy abilities whose rider lands on a different target than the hero they hit**
(59 abilities; 43 put a rider on someone other than the caster, 16 only on the
caster):

* **Freeze on the hero with the lowest die, not the hero hit** — Geode Panther:
  Calcifying Bite (5–10), Stonefang Pounce (17–19). The specific hero is not shown
  before resolution; the text says "freeze lowest hero die". (Petrifying Shriek
  freezes all heroes.)
* **Shield on an ally** (which ally is not shown when the label is the hostile
  pick) — Shield Enforcer ×4 (5–10, 11–16, 17–19, 20), Carapace Beetle ×4, Aegis
  Anchor ×4, Relay Herald ×3, Cipher Scribe (5–10).
* **Remove all hero shields while damaging one hero** — Scrapmaster System Purge,
  Hive Matriarch Acid Cataclysm, Veil Overseer Veil Cataclysm, Signal Hierophant
  Machine Crusade, Mantle Tyrant Mantle Rupture, False Image Mirror Break, Basalt Ape
  Basalt Crush.
* **Buff all allies** (named "(all allies)" in text) — Shield Enforcer, Aegis Anchor
  ×4, Resonance Warden ×3, Stormweaver ×3, Relay Herald ×3, Veil Overseer ×3, Cipher
  Scribe, Signal Hierophant ×2.
* **Rampage all allies** — Mantle Tyrant Dominance Roar, Mantle Rupture.
* **Jam all heroes while damaging one** — Static Skimmer White Noise Barrage.
* **Caster-only riders** (16: heal, lifesteal, firewall, shield, hijack of own die) —
  Heavy Warden Reclamation Shot; Skitterling, Bloodmite, Spine Stalker, Broodwarden ×2,
  Caustic Spewer, Hive Matriarch Royal Mandibles, Cinder Raptor Crack Jaw, Mantle
  Tyrant Titan Gouge (lifesteal); Prism Charger Prism Drive; Phaseblade Guarded Cut,
  Circuit Acolyte Warded Lash, Oath Binder Binding Decree (firewall); Cipher Scribe
  Stolen Pattern, False Image Stolen Reflex (hijack). Several abilities above also
  carry a caster rider.
* **Protocol drain** (pool, not a unit) — Signal Wisp, Circuit Acolyte, Oath Binder,
  Ash Channeler.

**Hero abilities with a component outside the pick** (25 abilities): chain jump to
the lowest-HP other enemy (Pulse ×2, Arc ×3, Overclock Chain Shot); leech heals the
caster (Medic ×2, Combat Medic, Ravager ×3); taunt pick + self shield or spike
(Challenge Beacon, Fortify, Challenge, Dig In); Reactive Cover's spike rides the
shielded hero; AoE damage + picked freeze (Whiteout Salvo); shield + any-die freeze
(Permafrost Weave); cloak after damage (Ghost Step, Strike and Fade); Protocol gains
(Field Patch, Reactor Discharge); Recovery Salvo heals all; Collapse Field −2 all
enemies. The hero preview forecasts chain and leech exactly (UI batch B1); the rest
is text.

### Questions for Kev
* Should a rider's target (the lowest-die hero, the shielded ally) be shown before
  resolution the way the hostile pick is?

---

## 9. Bug investigation (read-only)

### 9a. Mobile web: switching apps and coming back freezes the game

**What the build does on visibility / focus change.** The game script handles none:
no `NOTIFICATION_APPLICATION_*` or focus notification is handled anywhere in
`scripts/`. The custom web shell (`web/shell.html` 389) listens for
`visibilitychange` / `pageshow` / `focus` and only calls `resume()` on suspended
AudioContexts. Godot 4.6.2's own web layer (source at the `4.6.2-stable` tag):
`window` blur → `Input.release_pressed_events()`; canvas focus/blur → window focus
notifications; and on **`webglcontextlost`**: `alert('WebGL context lost, please
reload the page')` + `preventDefault()` — there is no context restore path.

**Best hypothesis.** Mobile browsers drop the WebGL context of a backgrounded page
under GPU-memory pressure (more likely with the 3D dice tray resident). Godot 4.6.2
cannot restore it, so the canvas stops drawing while the page stays alive — the
"freeze". Its only notice is `alert()`. itch.io serves the game from a separate origin inside
an iframe, and browsers have restricted `alert()` from cross-origin iframes; whether
the alert appears inside the itch frame on the playtest phone is unverified. If it
doesn't, the player sees a frozen last frame and no message. Secondary candidates, weaker: a suspended or "interrupted" AudioContext
(the shell resumes it outside a user gesture, which iOS may refuse — this silences
audio but does not stop the main loop in a non-threaded export); a touch held during
the switch (Godot releases pressed events on blur).

**What would confirm or refute it.** A desktop browser can force the same path with
the `WEBGL_lose_context` extension; on a phone, an `alert` or console line
"WebGL context lost" after returning; or the state code (on the dev-tools branch)
showing no engine error at the freeze while the page is unresponsive.

### 9b. Re-rolled die stuck in a corner, and the 0.004 overlap in `dice face 540x1200`

**Code path (G-33).** A single-die re-throw (`DiceTray3D.reroll_die_to_result`)
turns every other die into a frozen **static** collider (the d20 hull × 1.06, around
a die drawn at 0.95 — `RESULT_SCALE`), throws the die from the side's off-corner
"hand", waits for it to settle (up to `MAX_ROLL_TIME` 6 s, damping ramps in from 3 s),
then slides it to its slot around the resting dice (`_plan_rethrow_slide`: step out,
lane, or lift over a full row). The tray walls lean inward so a die can't rest
against them in an *empty* tray.

**The gate failure.** Criterion (k) measures the moving die's **drawn** hull (scale
1.0 while moving) against each resting die's drawn hull (0.95). The physics collider
pair is 1.0 vs 1.06, a margin of roughly 0.1 at the vertices, so a 0.004-deep drawn
overlap at centres 1.83 apart implies either solver penetration beyond that margin
during a fast contact, or contact outside the physics phase (the upright turn or the
slide).

**Observed rate.** 10 sequential standalone runs of `dice_face_gate.gd -- --size=540x1200`
(Linux Godot 4.6.2, headless, nothing else running): **3 FAIL, 7 PASS** (runs 3, 7, 8).
Every failure is the same single (k) failure out of 34,112–35,590 checks:
`enemy:rust_drone#1 passed through resting enemy:scrap_drone#1 during enemy item reroll
(centres 1.83 apart, 0.004 deep)`. Earlier this session: 1 FAIL in 3 full gate runs
(under CPU load), 2 PASS standalone. Combined: 4 of 15 runs. The identical pair, phase,
distance and depth across all four failures means the gate is not deterministic for this
fixture, and the failure is not explained by CPU contention (three of four came from
standalone runs with nothing else running).

**Same issue?** Both come from the G-33 re-throw setup: the moving die meets static
copies of resting dice. They are different failure modes:
* the **overlap** is the moving die grazing a resting die (a containment check);
* the **corner stall** is the moving die confined between static dice and the sloped
  rim. The lean argument assumes an empty tray, so with five static dice in place a
  corner pocket can hold the die until the 6 s timeout and damping freeze it there,
  after which it slides to its slot.

The code does not show a single shared defect; it shows one shared precondition
(static obstacles during a single-die re-throw) and two consequences. Not reproduced
here beyond the gate run counts above.

### Questions for Kev
* 9a: is a reload prompt acceptable as the recovery, given `alert()` is blocked in
  the itch frame?
* 9b: should a die that times out wedged count as "landed" (it does today), or be
  re-thrown?
* 9b: `dice face 540x1200` failed 4 of 15 runs with one identical signature. Was it
  known to be intermittent on the Windows binary?
