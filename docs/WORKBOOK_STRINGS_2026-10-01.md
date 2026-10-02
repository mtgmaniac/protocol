# Workbook strings changed — playtest batch 2026-10-01

Mirror these in the 788-row copy audit workbook. Source: `data/raw/enemies.data.json`
(branch `playtest-fixes-2026-10-01`).

## Enemy ability eff text (34) — G-44 `(all enemies)` -> `(all allies)`, plus Mantle Tyrant's missing `(self)`

| Kit / band | Ability | Before | After |
|---|---|---|---|
| guard / recharge | Bulwark Link | 4 shield (all enemies) | 4 shield (all allies) |
| guard / surge | Cover Field | 12 damage, 5 shield (ally), +2 roll (all enemies) 1 turn | 12 damage, 5 shield (ally), +2 roll (all allies) 1 turn |
| volt / recharge | Grounding | 5 shield (all enemies), 4 spike (self) | 5 shield (all allies), 4 spike (self) |
| carapace / recharge | Chitin Link | 6 shield (all enemies), 3 spike (self) | 6 shield (all allies), 3 spike (self) |
| veilAegis / recharge | Lattice Link | 6 shield (self), 6 shield (ally), +1 roll (all enemies) 1 turn, firewall (self) | 6 shield (self), 6 shield (ally), +1 roll (all allies) 1 turn, firewall (self) |
| veilAegis / strike | Aegis Bash | 12 damage, 6 shield (ally), +1 roll (all enemies) 1 turn | 12 damage, 6 shield (ally), +1 roll (all allies) 1 turn |
| veilAegis / surge | Bulwark Pulse | 14 damage, 8 shield (ally), +1 roll (all enemies) 1 turn | 14 damage, 8 shield (ally), +1 roll (all allies) 1 turn |
| veilAegis / crit | Fortress Lash | 18 damage, 9 shield (ally), +2 roll (all enemies) 1 turn, firewall (self) | 18 damage, 9 shield (ally), +2 roll (all allies) 1 turn, firewall (self) |
| veilAegis / overload | Shieldline Rally | 20 damage, 12 shield (ally), +2 roll (all enemies) 2 turns, firewall (self), 42% summon | 20 damage, 12 shield (ally), +2 roll (all allies) 2 turns, firewall (self), 42% summon |
| veilResonance / recharge | Harmonic Mend | 7 shield (self), 7 heal (self), +1 roll (all enemies) 1 turn, firewall (self) | 7 shield (self), 7 heal (self), +1 roll (all allies) 1 turn, firewall (self) |
| veilResonance / surge | Pulse Burn | 12 damage, 3 burn 3 turns, +1 roll (all enemies) 1 turn | 12 damage, 3 burn 3 turns, +1 roll (all allies) 1 turn |
| veilResonance / crit | Resonant Hammer | 22 damage, +2 roll (all enemies) 1 turn | 22 damage, +2 roll (all allies) 1 turn |
| veilResonance / overload | Veil Rally | 28 damage, 6 heal (self), +2 roll (all enemies) 2 turns, 40% summon | 28 damage, 6 heal (self), +2 roll (all allies) 2 turns, 40% summon |
| veilNull / recharge | Phase Alignment | 5 shield (self), +1 roll (all enemies) 1 turn | 5 shield (self), +1 roll (all allies) 1 turn |
| veilStorm / recharge | Capacitor Hum | +1 roll (all enemies) 1 turn | +1 roll (all allies) 1 turn |
| veilStorm / surge | Storm Weave | 12 damage, 2 burn 2 turns, +1 roll (all enemies) 1 turn | 12 damage, 2 burn 2 turns, +1 roll (all allies) 1 turn |
| veilStorm / crit | Ion Tempest | 14 damage, 3 burn 3 turns, +1 roll (all enemies) 1 turn | 14 damage, 3 burn 3 turns, +1 roll (all allies) 1 turn |
| veilStorm / overload | Lattice Storm | 16 damage, 5 burn 4 turns, +2 roll (all enemies) 2 turns, 42% summon | 16 damage, 5 burn 4 turns, +2 roll (all allies) 2 turns, 42% summon |
| veilSynapse / recharge | Relay Tune | +2 roll (all enemies) 1 turn, firewall (self) | +2 roll (all allies) 1 turn, firewall (self) |
| veilSynapse / surge | Weave Shield | 10 damage, 7 shield (ally), +1 roll (all enemies) 1 turn | 10 damage, 7 shield (ally), +1 roll (all allies) 1 turn |
| veilSynapse / crit | Conduit Spear | 15 damage, 8 shield (ally), +1 roll (all enemies) 2 turns | 15 damage, 8 shield (ally), +1 roll (all allies) 2 turns |
| veilSynapse / overload | Relay Reinforcements | 17 damage, 8 heal (self), +2 roll (all enemies) 2 turns, 40% summon | 17 damage, 8 heal (self), +2 roll (all allies) 2 turns, 40% summon |
| veilBoss / recharge | Overseer Mantle | 22 shield (self), 8 shield (ally), +2 roll (all enemies) 1 turn | 22 shield (self), 8 shield (ally), +2 roll (all allies) 1 turn |
| veilBoss / surge | Judgment Arc | 22 damage, 2 burn 2 turns, +1 roll (all enemies) 1 turn | 22 damage, 2 burn 2 turns, +1 roll (all allies) 1 turn |
| veilBoss / crit | Suppressor Beam | 26 damage, -3 roll 2 turns, +1 roll (all enemies) 1 turn | 26 damage, -3 roll 2 turns, +1 roll (all allies) 1 turn |
| veilBoss / overload | Veil Cataclysm | remove all hero shields, 30 damage, +2 roll (all enemies) 2 turns, 30% summon | remove all hero shields, 30 damage, +2 roll (all allies) 2 turns, 30% summon |
| voidScribe / recharge | Signal Litany | +1 roll (all enemies) 1 turn | +1 roll (all allies) 1 turn |
| voidScribe / overload | Summon Verse | 16 damage, +2 roll (all enemies) 2 turns, 45% summon | 16 damage, +2 roll (all allies) 2 turns, 45% summon |
| voidCircletBoss / recharge | Hierophant Mantle | 20 shield (self), 8 shield (ally), +2 roll (all enemies) 1 turn, firewall (self) | 20 shield (self), 8 shield (ally), +2 roll (all allies) 1 turn, firewall (self) |
| voidCircletBoss / surge | Cinder Sermon | 22 damage, 2 burn 2 turns, +1 roll (all enemies) 1 turn | 22 damage, 2 burn 2 turns, +1 roll (all allies) 1 turn |
| voidCircletBoss / overload | Machine Crusade | remove all hero shields, 30 damage, +2 roll (all enemies) 2 turns, 32% summon | remove all hero shields, 30 damage, +2 roll (all allies) 2 turns, 32% summon |
| beastTyrant / recharge | Tyrant Mantle | 20 shield (self), 1 rampage | 20 shield (self), 1 rampage (self) |
| beastTyrant / crit | Dominance Roar | 24 damage, 1 rampage (all enemies) | 24 damage, 1 rampage (all allies) |
| beastTyrant / overload | Mantle Rupture | remove all hero shields, 26 damage, freeze all heroes 1 turn, 1 rampage (all enemies) | remove all hero shields, 26 damage, freeze all heroes 1 turn, 1 rampage (all allies) |

## Enemy battle-card callsigns (7)

GLITCH -> WISP (Signal Wisp) · INIT -> ACOLYTE (Circuit Acolyte) · AXIOM -> BINDER (Oath Binder) ·
FORK -> IMAGE (False Image) · DAEMON -> ASH (Ash Channeler) · NULL -> PHASE (Phaseblade) ·
SYNAPSE -> HERALD (Relay Herald). Signal Hierophant stays ROOT (pending), Shield Enforcer stays
GUARD (pending).

## New UI strings (code, not data)

- "Tap a die: hero +3, enemy -3." / "Tap an enemy die: -3." (Firewall Hack pick note)
- "Nudge cancelled." / "Reroll cancelled." / "Set cancelled."
- Firewall Hack block reasons, now shown for the first time: "Firewall Hack is used up this turn.",
  "That die is frozen solid - it can't be nudged.", "A hijacked die can't be nudged.",
  "Need 1 Protocol to Nudge."
