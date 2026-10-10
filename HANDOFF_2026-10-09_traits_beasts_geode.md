# Handoff 2026-10-09: traits, beasts and Geode

Rulings: G-59 (Part A, on `main`), G-60, G-61, G-62 (Part B, on branch
`claude/traits-beasts-geode`, pushed, not merged). No itch build. Nothing
tuned. Sim pins not touched.

## Follow-ups on the branch, same day (G-63 to G-66)

Four commits after this handoff was written. Where they differ, they replace
what is below; TRUTH has the current state.

| Ruling | Change | What it replaces below |
|---|---|---|
| G-63 | Trait names are titles (Smoldering, Feral, Volatile...). 21 renamed, 5 kept | The names in "Trait copy". Volt Enforcer's card reads VOLATILE in red, not DEATH: 4 TO ALL |
| G-64 | Each trait says what it needs from the kit; `validate-data` enforces it | New |
| G-65 | The HP preview dry-runs the whole round, so traits, Rampage and the pack bonus are in a hero's bar. Gate `trait preview` | "The HP preview on a hero's card still sums the enemies' printed damage" |
| G-66 | Feral is on Basalt Ape and Magma Drake too (seven units); they keep Accrete | Decision 1, and "Pack Rage is on five Mantle Hunt units" |

Decision 4 is closed: the pins were re-pinned on 2026-10-10 with Kev's
sign-off (G-67; the table is in TRUTH). Still open: decision 3 (the readings)
and tuning, which Kev does after playing.

## Part A, on `main` (`55f4ff3`)

- The two-tier sim gate was already merged and pushed (`5519f2c`); nothing to do.
- **`sim size break` runs its real leg only when `scripts/sim/ci_smoke.py`,
  `baseline.json` or `baseline_pins.json` changes.** A pass writes those three
  files' fingerprint to `scripts/sim/size_break_stamp.json`. With a matching
  stamp the gate takes under a second and says the real leg was skipped.
  `--real` forces it.
- **Working rules** are in the root `CLAUDE.md`. The older line there ("run
  the full gate once at the end of every task") now defers to them, and
  `docs/TASK_TEMPLATE.md` says the same.

## Part B commits

| Commit | Change |
|---|---|
| `ab222c4` | Beasts rework: rampage and pack bonus (G-60). Also `verify_gate.py --only` |
| `05046b7` | Geode Panther hits the hero whose die it freezes (G-61) |
| the commit this file is in | Unit traits (G-62) |

## Trait copy, as shown in the game

Format everywhere: `NAME: line`. The battle card shows the name only.

| Unit | Trait | Line |
|---|---|---|
| Pyro Specialist | Afterburn | Detonating leaves 1 burn for 2 turns. |
| Arc Specialist | Live Wire | Each chain jump deals +1 damage. |
| Blade Trooper | Exposed | Its area attacks deal +2 to marked enemies. |
| Ravager | Bloodlust | After rolling 1-7, its next leech heals 50% more. |
| Bulwark | Anchor | Takes 2 less damage while taunting. |
| Sentinel | Retaliate | When hit while taunting, its spike deals +2. |
| Glacier Rig | Glacial Armor | At round start, gains 1 shield per frozen enemy. |
| Trench Rig | Dug In | At round start, gains 3 shield while below half HP. |
| Combat Medic | Triage | Its heals restore +3 on the lowest-HP ally. |
| Synth Medic | Overflow | Its healing past full HP becomes shield. |
| Overclock Engineer | Redline | +2 damage on every attack while you have 5 or more Protocol. |
| Phantom Engineer | Ghost Signal | Jams it applies from cloak last 1 extra round. |
| Shadow Operative | Silent Kill | An ambush that kills its target keeps the cloak. |
| Wraith | Clean Kill | When it kills, the lowest-HP enemy becomes marked. |
| Noise Specialist | Static | At round start, the highest enemy die drops by 1. |
| Nullwire | Zero Day | Enemies it rewrites take +2 damage until the rewrite ends. |
| Patrol Enforcer | Backup | When an ally is hit, gains 2 shield. |
| Volt Enforcer | Discharge | When it dies, deals 4 damage to each hero. |
| Spine Stalker | Barbed | Heroes that hit it take 2 damage. |
| Caustic Spewer | Corrosive | Its burns ignore shields. |
| Phaseblade | Blink | After rolling 1-3, it cloaks. |
| Circuit Acolyte | Litany | At round start, the lowest enemy die rises by 2. |
| False Image | Decoy | The first hit against it each battle is negated. |
| Ash Channeler | Kindle | Heals 3 whenever any burn ticks. |
| Oath Binder | Compel | Its roll penalties last 1 extra round. |
| Pumice Climber, Obsidian Hound, Slag Hound, Geode Panther, Cinder Raptor | Pack Rage | When an ally dies, gains rampage. |

- Volt Enforcer's card marker is **DEATH: 4 TO ALL**, in the warning colour,
  instead of its trait name.
- Other new copy. Rampage keyword: "On its next turn, this unit's attack deals
  double damage. Rampage ends after that turn and does not stack." Rampage
  inspect: "Its next turn's attack deals double damage. Ends after that turn."
  Rampage primer: "RAMPAGE: double damage on its next turn, then it ends."
  Pack bonus: "+3 damage per other pack member". Geode Panther: "10 damage,
  freeze 1 turn (lowest hero die)" and "15 damage, freeze 1 turn (lowest hero
  die)".

## Static and Litany in the same round

**Static fires first, then Litany.** All four round-start traits fire heroes
first, as the round does. So Litany raises whichever die is lowest after
Static's drop: on 8 and 7, Static makes them 7 and 7 and Litany makes them 9
and 7. The other order would give 8 and 8. One line to flip if it plays wrong.

## Pack bonus, proposed

+3 per other living pack member of the same kind (was +1).

| Ability | Rolls | Alone | One packmate, was -> now | Two packmates, was -> now |
|---|---|--:|--:|--:|
| Pumice Grasp (Pumice Climber) | 13-19 | 6 | 7 -> 9 | 8 -> 12 |
| Rending Fang (both Hounds) | 13-19 | 7 | 8 -> 10 | 9 -> 13 |
| Pack Assault (both Hounds) | 20 | 14 | 15 -> 17 | 16 -> 20 |

At +1 a full pack's bonus attack was weaker than the same unit's plain attack
on 7-9 (11 and 12). At +3 a full pack beats it by 1. One constant
(`PACK_BONUS_PER_MEMBER`), sweepable as `pack_bonus_per_member`.

## Decisions for you

1. **Pack Rage is on five Mantle Hunt units.** "Regular and elite" by the
   roll-windows role table leaves out Basalt Ape and Magma Drake (tanks; they
   keep Accrete). Say if they should have it: two lines of data.
2. **Combat Medic has an ability and a trait both named Triage.** I kept your
   name for the trait.
3. **Thirteen readings of the trait rules** are numbered in G-62. The ones
   most likely to matter in play: Bloodlust waits for the next attack that
   leeches; Retaliate and Barbed hit back even with no spike up; Zero Day
   lasts until the rewrite ends (about a round and a half); Kindle heals once
   per burning unit per round; Afterburn's burn lasts 2 turns.
4. **The sim pins are not re-pinned.** Combat changed, so the tripwire will
   report a move on the next sim leg. On these 1,500 runs the move is beyond the size line
   (8 on an operation, 4 overall) on both policies: first evolutions overall
   +5.7, Facility +8.2, Mantle Hunt +8.8; second evolutions Facility +9.2,
   Mantle Hunt +8.1. So the next sim leg will exit 3 and a re-pin needs
   `BASELINE-APPROVED-BY-KEV`. I did not run the gate's sim leg or re-pin.

## Sim

1,500 pinned runs per policy, seed base 900000. "Main" is the size pin written
on `main`; "branch" is the same seeds on this branch. One operation is about
300 runs, so a rate moves about 3 points between seed sets by itself. Not
tuned. No second seed base was run (nothing was tuned to a target).

**Clear rate by operation**

| Operation | First evolutions: main | branch | change | Second evolutions: main | branch | change |
|---|--:|--:|--:|--:|--:|--:|
| Facility | 32.5% | 40.7% | +8.2 | 37.7% | 46.9% | +9.2 |
| Hive | 30.8% | 36.2% | +5.4 | 32.4% | 33.7% | +1.3 |
| Veil | 26.1% | 26.4% | +0.3 | 28.7% | 27.4% | -1.3 |
| Signal Purge | 23.9% | 29.7% | +5.8 | 20.3% | 20.6% | +0.4 |
| Mantle Hunt | 18.9% | 27.6% | +8.8 | 17.8% | 25.9% | +8.1 |
| **Overall** | 26.5% | 32.2% | +5.7 | 27.6% | 31.1% | +3.5 |

**Win rate of runs that include the hero** (the sim evolves every hero, so each row is the evolution named)

| Hero | First evolution | main | branch | change | Second evolution | main | branch | change |
|---|---|--:|--:|--:|---|--:|--:|--:|
| Pulse Tech | Pyro Specialist | 26.2% | 31.2% | +5.0 | Arc Specialist | 28.9% | 30.6% | +1.7 |
| Strike Unit | Blade Trooper | 31.5% | 35.1% | +3.6 | Ravager | 34.9% | 38.0% | +3.1 |
| Spike Guard | Bulwark | 15.0% | 19.7% | +4.7 | Sentinel | 16.3% | 21.6% | +5.3 |
| Avalanche Suit | Glacier Rig | 20.3% | 24.9% | +4.6 | Trench Rig | 20.9% | 22.3% | +1.4 |
| Splice Medic | Combat Medic | 35.8% | 42.5% | +6.7 | Synth Medic | 33.7% | 40.8% | +7.1 |
| Field Engineer | Overclock Engineer | 24.8% | 30.2% | +5.4 | Phantom Engineer | 25.0% | 29.1% | +4.1 |
| Ghost Operative | Shadow Operative | 34.1% | 41.5% | +7.3 | Wraith | 32.4% | 35.3% | +2.9 |
| Signal Breaker | Noise Specialist | 24.1% | 31.8% | +7.8 | Nullwire | 28.4% | 31.1% | +2.8 |

Reading it:

- **The branch is easier than `main`:** +5.7 overall on first evolutions, +3.5
  on second. Every hero gains; none loses. That is the 16 hero traits arriving
  against 14 enemy traits that mostly sit on units a run meets a few times.
- **Mantle Hunt got easier (+8.8, +8.1) even with Pack Rage and the bigger
  pack bonus.** I did not split this by commit, so the cause is my reading,
  not a measurement: the rampage rule takes a lot from the Mantle Tyrant. Its
  rampages used to pile up and wait for an attack; now each one is gone after
  one turn, and its 1-6 ability (20 shield, rampage) is followed by an attack
  only some of the time.
- **Facility moves most (+8.2, +9.2).** Its only trait units are Patrol
  Enforcer and Volt Enforcer.
- **Second evolutions gain less** in Hive, Veil and Signal Purge (about +1 or
  less) than first evolutions do there (+5 in Hive and Signal Purge).
- Biggest hero moves: Noise Specialist +7.8, Shadow Operative +7.3, Synth
  Medic +7.1, Combat Medic +6.7. Smallest: Trench Rig +1.4, Arc Specialist
  +1.7.
- The sim's player does not plan around traits (it never holds Protocol for
  Redline, picks a kill for Silent Kill, or hits the Enforcer's allies last),
  so a real player gets more from the hero traits and loses less to the enemy
  ones than these numbers show.


## Gates

No full `verify_gate.py`, as ruled. Run by name with the new
`python scripts/verify_gate.py --only "a, b"`.

- **New gates, each with deliberate breaks that must fail it:**
  - `rampage`: duration, stacking, pack numbers and every printed copy.
    Breaks `stack`, `keep`, `pack_one`. Pass, 4 s.
  - `geode targeting`: combat, the planning intent, the Panther's data, a live
    round. Breaks `split`, `stale`. Pass, 16 s.
  - `traits`: the roster from your list, all 26 rules with and without the
    trait, the dice rules, where each is shown, the copy, a live round in both
    animation modes. Breaks `off`, `no_chip`, `frozen_dice`, `litany_first`,
    `boss_trait`. Pass, 15 s.
- **`validate-data`** now checks `traits.data.json` (schema, every assignment
  names a real unit and a defined trait, every `{number}` exists, every trait
  is used). I fed it four bad edits and it refused each.
- **Existing gates these changes touch: 46 of 46 pass**, in one run after the
  last code change: validate-data, doc consistency, knobs contract, autoload
  closure, caps law, component contract, effect target, ability audit, boss
  relics, flow smoke, tutorial smoke, primer smoke, card long press, help
  polish, battle layout, glyph coverage, wording fit, text legibility, panel
  count, float bounds, feedback honesty, final feedback and recovery, save
  schema, save roundtrip, checkpoint lifecycle, dice face, battle checkpoint,
  save resume, state code, no animations, action motion, auto-select target,
  nudge cast order, taunt planning chip, auto-target preview, item burn
  preview, preview accuracy, freeze regression, roll windows, roll windows
  live, rampage, geode targeting, traits, firewall feedback, accrete display,
  cloak ambush.
- **Not run:** the other 39 gates, the gate's sim leg, profile
  isolation, and `sim size break`'s real leg (its stamp is unchanged, so it
  is not due).
- No save format change: unit states are stored whole in the battle
  checkpoint, and `save schema` passes with the same fingerprint.
- Godot ran from a scratch copy through `GODOT_BIN` with `APPDATA` on a
  scratch folder (the editor is open on the project).

## Screenshots

In `debug_artifacts/traits/` (not committed): `battle_rolled.png` (markers on
all six cards, DEATH: 4 TO ALL on Volt Enforcer, the STATIC chip),
`inspect_enemy.png`, `inspect_hero.png`, `evolution_picker.png`,
`help_units.png`. What they plainly show: the marker sits in the name strip
above the unit name; the inspect leads with the trait line above the roll
breakdown; each evolution choice shows its trait in the header without
expanding. `battle_ui_capture.gd` gained `--capture-comp=Name,Name` to set a
lineup for shots like these.

## Not done, and things to know

- **Not in this batch, untouched:** the summons rework, Rewrite variants,
  permanent dice rewards.
- **The Help units list rows are unchanged.** A unit's trait shows when its
  row is opened (the breakdown leads with it, checked in the `traits` gate).
  I did not get a screenshot of an opened Help row.
- **The inspect's section label still reads ACTIVE EFFECTS** above the trait
  line. It is the existing header for that block; left for the UI redesign.
- **Volt Enforcer's warning colour is close to the amber of the other
  markers** in the screenshot. The words carry the warning more than the
  colour does.
- **The HP preview on a hero's card still sums the enemies' printed damage.**
  It does not count Anchor's -2, and it never counted an enemy's Rampage or
  pack bonus. The preview on an enemy's card runs the real hero phase, so the
  hero-side traits are in it (Redline, Exposed, Live Wire, Zero Day, Decoy);
  the Corrosive part of a burn tick is counted on both.
- **The sim change was not split by commit.** That needs a second checkout,
  and the C: drive ran out of space when I tried to make one.
- **C: has about 460 MB free** (1.9 TB drive). I filled it for a few seconds
  copying the import cache into a scratch checkout, removed the copy at once,
  and all 46 gates passed afterwards. Nothing of yours was touched, but the
  drive is that close to full on its own.
- **My mistakes, corrected before anything was pushed:** I staged your
  untracked `docs/ui_reference/` screenshots into the first Part B commit and
  redid the commit without them (they are untracked on disk as before). I
  edited `traits.data.json` to test the validator while a sim batch was
  running, so I threw that batch away and reran it clean; the numbers above
  are from the clean run.
- `battle_scene.gd` is at its 3,640-line mark exactly (the Geode commit took it
  to 3,648 and warned; this commit brings it back).
