# Handoff: feedback polish (2026-10-08, second session)

Branch `claude/feedback-polish`, cut from `main` at `b736eb5`. Items 1, 3, 4
and 5 are merged into `main`. Item 2 is a proposal on the branch, waiting for a
pick. No itch build. Spawn overlap on main rolls was not touched (backlog).

| Commit | Item | Change |
|---|---|---|
| `bb8ad63` | 5 | The balance sim reads `GODOT_BIN`, falling back to `GODOT` |
| `a7545b5` | 1 | A unit that does not attack shakes in place |
| `14fba49` | 3 | A Firewall says what it blocked |
| `eae85b4` | 4 | Accrete is shown and explained |
| branch only | 2 | Self and Summon icon options (nothing replaced) |

Rules: TRUTH, top entry. Rulings and my readings of them: G-51.

**Follow-up, same day (your three decisions): see the last section,
"Follow-up". Where it differs from the sections below, it wins.**
Screens: `debug_artifacts/feedback_polish_2026-10-08/` (local).

## Before starting

`project.godot` had one uncommitted change: the editor moved the line
`config/icon="res://icon.svg"` below the two `boot_splash` lines in
`[application]`. No
setting changed. Discarded.

## 1. Buff and debuff motion

Cause: the support tell was `play_action_feedback` on the old unit card. The
live card never had that method, so a `has_method` guard skipped it and only
the attacker's lunge was left.

Now the motion comes from the ability's own data
(`scripts/battle/action_motion.gd`): `dmg`, `burn` or `detonate` means it
attacks and lunges; every other ability wiggles (sideways to the lunge,
12 / 12 / 7 / 7 design px, back to rest). Reduced Motion: 5 / 5 px. No
animations: none. Round ticks: none.

310 unit abilities: **237 lunge, 73 wiggle**. Full lists at the end of this
file.

**Mixed abilities: all 48 lunge.** An attack that also shields, heals, buffs,
cloaks, raises a Firewall, gains Protocol or summons is still an attack.
Attacks with leech or lifesteal, and attacks with debuff riders (burn, roll
penalty, jam, mark, freeze), lunge too.

**For you to decide:** under Reduced Motion the lunge is still off (G-13), so
a supporter moves slightly and an attacker does not move at all. Say if you
want a small lunge there too.

Gate `action motion`: every ability gets a class, a live round plays the right
motion on both sides, the wiggle is sideways, smaller than the lunge (peak
12 px against 26), returns to rest, shrinks under Reduced Motion, absent under
No animations. Breaks: `no_wiggle`, `all_lunge`, `reduced_full`,
`no_anim_ignored`.

## 2. Self vs Summon icons (waiting for your pick)

`docs/ui_reference/icon_options/`:

- `self_options.png`: A marker arrow, B return arrow, C brackets
- `summon_options.png`: A plus, B gate, C call
- `self_vs_summon_pip_size.png`: every Self beside every Summon at pip size
- the six 128 px candidates, and `make_icons.py`, which draws them

Each sheet shows the icon enlarged, at pip size (40 px on a phone, 20 px in the
desktop preview) and inside a pip row. They are drawn on the set's 32x32 cell
grid with the set's own figure, lifted from `self.png`. Nothing in
`assets/ui/pips/` changed.

My pick, if it helps: **Summon A (plus), and keep the current Self.** The plus
reads at 20 px and Self keeps the ring players already know. If Self should
change too, C (brackets) holds up best small. The one pair I would avoid is
Self C with Summon B: both are a figure in a frame.

## 3. Firewall feedback

It was not fully silent: an X appeared over the unit and the log said
"<unit>'s firewall blocks the ability!". Neither named the Firewall's effect.

**Final copy.**

- Chip on the unit: `BLOCKED`
- Log, one effect: `Firewall blocked taunt on Scrap Drone.`
- Log, several: `Firewall blocked damage, burn and jam on Strike Unit.`

Lowercase "taunt" and the unit's name are my changes to your example; see G-51
reading 3.

**Every effect a Firewall can cancel** (25 call sites in `CombatManager`):

| Effect, as the log names it | Hero ability on an enemy | Enemy ability on a hero |
|---|---|---|
| damage | one target, area | one target, area |
| burn | alone, or riding an attack | alone, or riding an attack |
| mark | alone, or riding an attack | |
| breach | on the target, or "breach all" | |
| chain damage | a chain jump | |
| roll penalty | one target, all enemies | one target |
| taunt | yes | yes |
| freeze | one target, all enemies | one target, all heroes |
| jam | one target, all enemies | one target, all heroes |
| rewrite | yes | yes |
| siphon | | a blocked hit never connects |
| Spillover Charge | the relic's carry | |

Not blocked, unchanged: burn ticks, spike, items, boss standing rules, an
enemy's "remove all hero shields".

The chip is a filled plate in the shield colours, on the unit for 1.5 s. It
replaces the X. Reduced Motion: no pop. No animations: no pop and no fade.

Gate `firewall feedback`: 30 cases, each run with and without a Firewall; a
live taunt into a Firewall; the chip under all three settings. Breaks:
`silent_taunt`, `old_log`, `no_chip`, `animated_chip`.

## 4. Accrete display

**The shield was never random.** The Mantle Tyrant has no Accrete keyword. Its
shield comes from the ACCRETION rule (6 at the start of rounds 1, 3, 5...) and
from its own 1-4 ability (20 shield), and all of it persists.

**What was wrong on screen:**

1. The shield chip stayed on its pre-round number while "+6" floated, then
   jumped when the boss acted. On round 1 the 6 was gained and absorbed with
   no chip at all. See `accrete_boss_round3_before.png` and `_after.png`.
2. The rampage chip appeared at the start of the resolve, on the same beat as
   the "+6", before the boss had granted it. I think this is the "doesn't
   display correctly" you saw, but I cannot be sure; tell me if it was
   something else.
3. A shield gain showed the amount asked for, not the shield applied under the
   max-HP cap.
4. Nothing named it, and the unit keyword (Basalt Ape 3, Magma Drake 4) was
   missing from the inspect entirely.

**Now:**

- Chip on the unit: `ACCRETE +6`. Log: `Mantle Tyrant accretes 6 shield.`
- The shield chip follows the round beat by beat (all units, both sides).
- The rampage chip lands when it is granted.
- Inspect, first line: `ACCRETE: always gains 6 shield at the start of every
  2nd round.` For the keyword: `ACCRETE: always gains 4 shield at the start of
  each of its turns.`
- At the shield cap: no chip, and `<unit>'s shield is at its limit. Accrete
  adds nothing.`

No combat change: four seeded Mantle Hunt sim runs are identical to the
previous commit apart from their events.

**Not changed:** the 6 still lands when the round resolves, not when the dice
are thrown (G-51 reading 10). The chip and the inspect line now say what
happened; the timing itself is yours to rule on.

Gate `accrete display`: shown value equals shield gained (free, capped, at the
cap); the rule fires on rounds 1 and 3 of 4; the inspect line; a live round
against the boss. Breaks: `asked`, `no_chip`, `stale_chip`, `no_line`.

## 5. Sim binary path

`scripts/sim/batch.py` reads `GODOT_BIN`, then `GODOT`, then the default path.
`scripts/debug/state_hash_tripwire.py` had the same single-name lookup and got
the same order. The full gate below ran with only `GODOT_BIN` set and the sim
leg ran 300 of 300.

## Gate

Full `python scripts/verify_gate.py` with the sim, Windows Godot 4.6.2, on
`eae85b4`: **all 78 hard gates PASS, plus profile isolation.** Three new gates:
`action motion` 36 s, `firewall feedback` 41 s, `accrete display` 19 s (90 s
budget each).

Balance sim (300 runs): overall 0.2833 -> 0.2800, stellarMenagerie 0.1667 ->
0.1458, every other operation +0.0, within tolerance. These are the same
numbers as the last two handoffs, so they are not from this batch.

**Environment only, not code:**

- The main Godot executable is still on the Desktop, not beside the console
  wrapper in Downloads. Gates ran with `GODOT_BIN` pointing at a scratch copy
  of both files.
- The gate ran with `APPDATA` pointed at a scratch folder, because the editor
  was open on the project.

No gate failed for any reason.

## Noticed, not fixed

- `scripts/debug/state_hash_tripwire.py` fails on untouched `main`: its pinned
  digest is stale (pinned `55b2ba69`, main gives `72d04e4a`). It is not in
  `verify_gate.py`. It will also move with this batch, because events gained
  fields.
- `firewall display` passes while printing four script errors
  (`BattleCardView._planned_taunt_on` reads `turn_phase` on a scene the test
  never set up). The checks still run. Since 2026-10-01.
- A shield absorbing a hit still floats "X 6". With BLOCKED now the word for a
  Firewall, the X only means "shield absorbed". Left as it is.
- `battle_scene.gd` and `protocol_actions.gd` line counts: unchanged.

## Motion lists

### Wiggle: abilities that do not attack (73)

| Side | Unit | Abilities |
|---|---|---|
| hero | Strike Unit | Target Lock (mark) |
| hero | Spike Guard | Challenge Beacon (3 spike, taunt); Reactive Cover (6 shield (hero), 3 spike (hero)); Spike Stance (5 shield, 5 spike) |
| hero | Bulwark | Fortify (7 shield, taunt); Iron Wall (6 shield (all heroes)); Bastion (8 shield (all heroes)); Fortress Screen (10 shield (all heroes), firewall) |
| hero | Sentinel | Challenge (4 shield, taunt); Counter Stance (6 spike) |
| hero | Avalanche Suit | Cryo Lattice (freeze any die 1 turn); Cryo Recovery (10 heal (all heroes)) |
| hero | Glacier Rig | Permafrost Weave (5 shield, freeze any die 1 turn) |
| hero | Trench Rig | Stabilize (10 heal (hero)); Dig In (8 shield, taunt); Bunker Firewall (5 heal, firewall (hero)); Last Bastion (8 shield (all heroes), 10 heal (all heroes)) |
| hero | Splice Medic | Diagnostic Pulse (3 shield (hero), 3 heal (hero)); Infusion (10 heal (hero), cleanse) |
| hero | Combat Medic | Triage (6 heal (hero)); Trauma Care (12 heal (hero)); Resuscitate (revive 50% HP, else 20 heal (hero)) |
| hero | Synth Medic | System Patch (8 heal (lowest HP)); Barrier Mesh (5 shield (all heroes)); Emergency Repair (12 heal (lowest HP)); Mass Revival (revive all heroes 30% HP, else 12 heal (all heroes)) |
| hero | Field Engineer | Field Patch (4 shield (hero), +1 Protocol); Barrier Deploy (9 shield (hero)) |
| hero | Overclock Engineer | Bias Charge (4 shield, +1 Protocol) |
| hero | Phantom Engineer | Stealth Field (cloak); Phantom Shield (10 shield, cloak) |
| hero | Ghost Operative | Active Camouflage (cloak) |
| hero | Signal Breaker | Wideband Hiss (-2 roll (all enemies) 1 turn); Harmonic Glitch (-2 roll (all enemies) 2 turns) |
| hero | Noise Specialist | Resonant Cage (-3 roll (all enemies) 3 turns) |
| enemy | Scrap Drone | Salvage Shell (8 shield (self)) |
| enemy | Rust Drone | Power Reroute (5 shield (self), +1 roll (self) 1 turn) |
| enemy | Static Skimmer | Jammer Screen (5 shield (self), jam) |
| enemy | Patrol Enforcer | Defensive Plating (6 shield (self)) |
| enemy | Shield Enforcer | Bulwark Link (4 shield (all allies)) |
| enemy | Heavy Warden | Field Service (7 shield (self), 4 heal (self)) |
| enemy | Volt Enforcer | Grounding (5 shield (all allies), 4 spike (self)) |
| enemy | Scrapmaster | Scrap Mantle (12 shield (self)) |
| enemy | Skitterling | Burrow Repair (5 heal (self)) |
| enemy | Bloodmite | Nutrient Pulse (3 heal (self)) |
| enemy | Spine Stalker | Spine Guard (6 shield (self), 4 spike (self)) |
| enemy | Carapace Beetle | Chitin Link (6 shield (all allies), 3 spike (self)) |
| enemy | Broodwarden | Nutrient Reserve (7 shield (self), 7 heal (self)) |
| enemy | Caustic Spewer | Mimic Gland (hijack) |
| enemy | Hive Matriarch | Royal Carapace (22 shield (self)) |
| enemy | Shard Drone | Phase Shell (4 shield (self)) |
| enemy | Prism Charger | Lattice Guard (taunt all heroes) |
| enemy | Aegis Anchor | Lattice Link (6 shield (self), 6 shield (ally), +1 roll (all allies) 1 turn, firewall (self)) |
| enemy | Resonance Warden | Harmonic Mend (7 shield (self), 7 heal (self), +1 roll (all allies) 1 turn, firewall (self)) |
| enemy | Phaseblade | Phase Alignment (5 shield (self), +1 roll (all allies) 1 turn) |
| enemy | Stormweaver | Capacitor Hum (+1 roll (all allies) 1 turn) |
| enemy | Relay Herald | Relay Tune (+2 roll (all allies) 1 turn, firewall (self)) |
| enemy | Veil Overseer | Overseer Mantle (22 shield (self), 8 shield (ally), +2 roll (all allies) 1 turn) |
| enemy | Signal Wisp | Static Hiss (-1 roll 1 turn) |
| enemy | Circuit Acolyte | Seal Sigil (firewall (self)) |
| enemy | Cipher Scribe | Signal Litany (+1 roll (all allies) 1 turn) |
| enemy | Oath Binder | Silencing Rite (-1 roll 2 turns) |
| enemy | False Image | False Image (6 shield (self), cloak) |
| enemy | Ash Channeler | Channel Focus (+2 roll (self) 1 turn) |
| enemy | Signal Hierophant | Hierophant Mantle (20 shield (self), 8 shield (ally), +2 roll (all allies) 1 turn, firewall (self)) |
| enemy | Pumice Climber | Still Perch (3 heal (self)) |
| enemy | Obsidian Hound | Slag Coat (4 shield (self)) |
| enemy | Slag Hound | Slag Coat (4 shield (self)) |
| enemy | Geode Panther | Geode Veil (10 shield (self), cloak) |
| enemy | Basalt Ape | Basalt Set (14 shield (self), 5 spike (self)) |
| enemy | Cinder Raptor | Scavenge (8 shield (self), 4 heal (self)) |
| enemy | Magma Drake | Magma Coil (8 shield (self)) |
| enemy | Mantle Tyrant | Tyrant Mantle (20 shield (self), 1 rampage (self)) |

### Lunge, mixed: an attack that also shields, heals, buffs, cloaks, raises a Firewall, gains Protocol or summons (48)

| Side | Unit | Abilities |
|---|---|---|
| hero | Bulwark | Cover Fire (5 damage, 7 shield (lowest HP)) |
| hero | Sentinel | Repulsion Field (8 damage (all enemies), 6 shield) |
| hero | Combat Medic | Recovery Salvo (10 damage, 8 heal (all heroes)) |
| hero | Synth Medic | Nanite Crossfire (6 damage (all enemies), 6 heal (all heroes)) |
| hero | Field Engineer | Scorched Earth (12 damage (all enemies), +2 Protocol) |
| hero | Overclock Engineer | Reactor Discharge (18 damage, 3 burn 2 turns, +2 Protocol) |
| hero | Shadow Operative | Ghost Step (5 damage, cloak); Strike and Fade (10 damage, cloak) |
| enemy | Shield Enforcer | Covering Shot (13 damage, 4 shield (ally)); Cover Field (12 damage, 5 shield (ally), +2 roll (all allies) 1 turn); Barrier Burst (17 damage, 4 shield (ally)); Fortress Advance (21 damage, 8 shield (ally)) |
| enemy | Heavy Warden | Reclamation Shot (32 damage, 3 heal (self)) |
| enemy | Carapace Beetle | Ramming Plate (12 damage, 50% lifesteal, 6 shield (ally)); Caustic Guard (10 damage, 2 burn 4 turns, 9 shield (ally)); Carapace Burst (13 damage, 3 burn 5 turns, 7 shield (ally)); Fortress Charge (16 damage, 2 burn 5 turns, 13 shield (ally)) |
| enemy | Prism Charger | Prism Drive (11 damage, 4 shield (self)) |
| enemy | Aegis Anchor | Aegis Bash (12 damage, 6 shield (ally), +1 roll (all allies) 1 turn); Bulwark Pulse (14 damage, 8 shield (ally), +1 roll (all allies) 1 turn); Fortress Lash (18 damage, 9 shield (ally), +2 roll (all allies) 1 turn, firewall (self)); Shieldline Rally (20 damage, 12 shield (ally), +2 roll (all allies) 2 turns, firewall (self), 42% summon) |
| enemy | Resonance Warden | Pulse Burn (12 damage, 3 burn 3 turns, +1 roll (all allies) 1 turn); Resonant Hammer (22 damage, +2 roll (all allies) 1 turn); Veil Rally (28 damage, 6 heal (self), +2 roll (all allies) 2 turns, 40% summon) |
| enemy | Phaseblade | Guarded Cut (19 damage, firewall (self)); Phase Reinforcements (24 damage, 40% summon) |
| enemy | Stormweaver | Storm Weave (12 damage, 2 burn 2 turns, +1 roll (all allies) 1 turn); Ion Tempest (14 damage, 3 burn 3 turns, +1 roll (all allies) 1 turn); Lattice Storm (16 damage, 5 burn 4 turns, +2 roll (all allies) 2 turns, 42% summon) |
| enemy | Relay Herald | Herald Strike (11 damage, 6 shield (ally)); Weave Shield (10 damage, 7 shield (ally), +1 roll (all allies) 1 turn); Conduit Spear (15 damage, 8 shield (ally), +1 roll (all allies) 2 turns); Relay Reinforcements (17 damage, 8 heal (self), +2 roll (all allies) 2 turns, 40% summon) |
| enemy | Veil Overseer | Judgment Arc (22 damage, 2 burn 2 turns, +1 roll (all allies) 1 turn); Suppressor Beam (26 damage, -3 roll 2 turns, +1 roll (all allies) 1 turn); Veil Cataclysm (remove all hero shields, 30 damage, +2 roll (all allies) 2 turns, 30% summon) |
| enemy | Circuit Acolyte | Warded Lash (17 damage, firewall (self)); Ritual Muster (18 damage, 40% summon) |
| enemy | Cipher Scribe | Glyph Strike (11 damage, 6 shield (ally)); Summon Verse (16 damage, +2 roll (all allies) 2 turns, 45% summon) |
| enemy | Oath Binder | Binding Decree (21 damage, firewall (self), rewrite, 35% summon) |
| enemy | Ash Channeler | Ashen Muster (22 damage, 4 burn 4 turns, 42% summon) |
| enemy | Signal Hierophant | Cinder Sermon (22 damage, 2 burn 2 turns, +1 roll (all allies) 1 turn); Machine Crusade (remove all hero shields, 30 damage, +2 roll (all allies) 2 turns, 32% summon) |
| enemy | Cinder Raptor | Brood Call (13 damage, 2 burn 3 turns, 50% summon) |
| enemy | Mantle Tyrant | Dominance Roar (24 damage, 1 rampage (all allies)); Mantle Rupture (remove all hero shields, 26 damage, freeze all heroes 1 turn, 1 rampage (all allies)) |

## Follow-up (same day): your three decisions

| Commit | Decision | Change |
|---|---|---|
| `bba42f4` | 2 | Reduced Motion: attackers lunge 11 px (26 x 5/12). No animations: still |
| `845e478` | 3 | The boss's Accrete wording names the moment the +6 lands |
| `31ac3e4` | 1 | Self and Summon icons replaced with Self A and Summon A |

**1. Icons.** Heal check passed, so they are committed. At 40 px and 20 px, in
colour and greyscale, heal is one large cross filling the pip and Summon A is a
figure with a small plus at its shoulder. They do not read as the same glyph.
One caveat: a plus beside a person is also a common "heal this unit" cue, so a
new player can still guess wrong before the Summon primer shows. Renders:
`docs/ui_reference/icon_options/heal_vs_summon_A.png` and
`chosen_in_battle.png` (both new icons in real readout rows). The Targets Self
definition in Help now reads "The figure under an arrow (or (self) in text)
means the ability affects its own caster."

**2. Reduced Motion lunge.** 11 px, same timing as the full lunge. The
`action motion` gate now checks the small lunge under Reduced Motion and no
lunge under No animations; its `reduced_full` and `no_anim_ignored` breaks
fail on the lunge too.

**3. Wording.** The +6 lands after you commit the round and before any hero
acts. "At the start of every 2nd round" read as the dice throw. Reworded:

- Inspect line: `ACCRETE: always gains 6 shield every 2nd round, before your
  heroes act.`
- ACCRETION rule text, second sentence: `It accretes every 2nd round, before
  your heroes act; its shields persist and stack.` It carried the same phrase
  and sits in the same inspect, so it changed with it.

Not changed: the Veil Overseer's rule says "at the start of every round" for a
Firewall raised at the same moment. Say if you want it to match.

**Gate.** Full `python scripts/verify_gate.py` with the sim on `69e2e6a` (the
three commits above plus their G-51 entry): all 78 hard gates PASS, plus
profile isolation. Sim unchanged from the run above (overall 0.2800,
stellarMenagerie 0.1458, within tolerance). Same environment notes: Godot run
from a scratch copy through `GODOT_BIN`, `APPDATA` on a scratch folder.

## Second follow-up (same day)

**1. Rule text, the moment it lands.** One change:

| Where | Before | After |
|---|---|---|
| Veil Overseer, THE COURT, second sentence | It raises that firewall on itself at the start of every round, for as long as any ally lives. | It raises that firewall on itself every round, before your heroes act, for as long as any ally lives. |

Checked and left alone, because the wording already matches the moment or
names none: ASSEMBLY LINE ("every 2nd enemy phase"), THE BROOD ("every 3
rounds"), ROOT ACCESS ("every round"), the Accrete keyword's definition, primer
and inspect line ("at the start of each of its turns"), the REGENERATIVE route
modifier ("At the start of each enemy phase"), the Burn primer and status
line, Tectonic Charge, Firewall Hack and the intercept choices. Details: G-51.

**2. Help text.** Targets Self now reads: "The figure under an arrow, or (self)
in text, means the ability affects its caster."

