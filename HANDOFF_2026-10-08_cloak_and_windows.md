# Handoff: cloak ambush and new roll windows (2026-10-08, third session)

Branch `claude/cloak-and-windows`, cut from `main` at `c6e9dd3`. **Not merged.**
Pushed for your review. No itch build. The baseline is not re-pinned.

| Commit | Change |
|---|---|
| `41cb184` | Cloak is an ambush |
| `1e36b83` | New roll windows for every unit |
| this commit | Handoff and housekeeping (G-54) |

Rules: TRUTH, the two top entries. Rulings and my readings: G-52 (cloak),
G-53 (windows), G-54 (housekeeping).
Screens: `debug_artifacts/cloak_and_windows_2026-10-08/` (local).

## 1. Cloak is an ambush

**The rule as built.**

- A cloaked unit cannot be single-targeted by the other side. Its own attack
  breaks the cloak. That attack deals **+50% damage** (round up).
- Once per cloak, only out of cloak. A cloak torn off by an area hit pays
  nothing. An ability that does not attack keeps the cloak and the bonus.
- Same for heroes and enemies.
- Every target cloaked: a single-target attack hits one of them at random. It
  no longer fizzles. The unit that is hit keeps its cloak.
- Shield + cloak abilities are unchanged.

**What I chose and why: +50%, not double.** Matched batches, 1,500 runs each:

| | `main` (old rule) | new rule, no bonus | **+50%** | double | x2.5 |
|---|--:|--:|--:|--:|--:|
| Overall clear | 26.7% | 24.9% | **30.3%** | 32.5% | 35.7% |
| Hive | 29.4% | 27.1% | **37.0%** | 39.6% | 45.2% |
| Ghost Operative | 29.0% | 24.7% | **38.1%** | 44.3% | 52.4% |
| Best other hero (Splice Medic) | 36.4% | 31.5% | **38.8%** | 38.4% | 40.7% |
| Biggest single hit on a hero | 52 | 52 | **52** | 64 | 90 |

- With no bonus the random-hit rule alone costs the squad 1.8 points
  and Ghost 4.3: a fully cloaked squad is no longer safe.
- At double, Ghost gains 15 points and is the best hero by six. Hive moves
  10.2 points. A cloaked Geode Panther with Rampage hits for 64.
- At +50% Ghost gains 9 points and sits level with the best hero. No
  operation moves more than 7.6. The biggest hit does not change.
- The sim's player never cloaks on purpose and never puts a cloak item on its
  hardest hitter. Real players will get more out of the bonus than this shows.
- +50% is Mark's number too.

To change it: `CombatManager.AMBUSH_MULT`, plus the keyword and primer lines.
The gate fails if they disagree. It is also a sim knob (`ambush_mult`).

**Final copy.**

| Where | Text |
|---|---|
| Keyword (Help) | Enemies can't single-target this unit; allies still can. Its next attack deals +50% damage and breaks the cloak. An area hit breaks it too. If every target is cloaked, a single-target attack hits one at random. |
| Inspect line | Can't be targeted. Next attack deals +50% damage. |
| Primer | CLOAK: can't be targeted directly; its next attack deals +50% damage. |
| Chip on the unit | cloak icon, then `+50%` |
| Log, ambush | Ghost Operative ambushes from cloak for +50% damage. |
| Log, all cloaked | Every target is cloaked. Strike Unit hits Geode Panther at random. |
| Enemy inspect, all heroes cloaked | TARGETING: RANDOM |

Unchanged: Cloak Emitter ("Cloak 1 hero."), Cloak Array, Phase Weave, Ambush
Wiring ("This hero's attacks from cloak deal +5 damage."), Ghostblade.

**UI.** The cloak chip was an icon alone. It now shows the icon and `+50%`
while the cloak is up, on heroes and enemies. Nothing else was added. The HP
preview on a hero counts a cloaked enemy's ambush.
`cloak_chip.png` shows both sides; `cloak_chip_zoom.png` is the chip enlarged.

**For you to decide (my readings, G-52).**

1. An attack that also cloaks (Shadow Operative: Ghost Step, Strike and Fade)
   spends its cloak and puts up a new one. A Shadow who rolls those bands back
   to back ambushes every round. Left as the rule gives it.
2. Rampage and ambush stack on an enemy that has both (x3). Only the Geode
   Panther can. Its biggest such hit is 54.
3. The random hit is for attacks only. A lone mark, jam or taunt with every
   target cloaked still does nothing.
4. Ambush Wiring's +5 is added after the +50%.
5. An area attack from cloak pays the bonus on every target.

Gate `cloak ambush`, 36 s. Breaks: `no_bonus`, `always`, `keep_cloak`,
`fizzle`, `first`, `no_chip`.

## 2. New roll windows

Heroes and evolutions are exactly your list (table in TRUTH). Every unit kept
its five bands and its abilities.

**Enemy table as applied.** Shape per operation, then the role rule.

| Operation | Unit | Role | Band 1 / 2 / 3 / 4 / top |
|---|---|---|---|
| Facility | Scrap Drone | regular | 1–3 / 4–9 / 10–15 / 16–19 / 20 |
| Facility | Rust Drone | regular | 1–3 / 4–9 / 10–15 / 16–19 / 20 |
| Facility | Static Skimmer | regular | 1–3 / 4–9 / 10–15 / 16–19 / 20 |
| Facility | Patrol Enforcer | elite | 1–3 / 4–9 / 10–14 / 15–19 / 20 |
| Facility | Shield Enforcer | support | 1–2 / 3–9 / 10–16 / 17–19 / 20 |
| Facility | Heavy Warden | tank | 1–2 / 3–9 / 10–16 / 17–19 / 20 |
| Facility | Volt Enforcer | elite | 1–3 / 4–9 / 10–14 / 15–19 / 20 |
| Facility | Scrapmaster | boss | 1–3 / 4–9 / 10–15 / 16–19 / 20 |
| Hive | Skitterling | regular | 1–5 / 6–11 / 12–16 / 17–19 / 20 |
| Hive | Bloodmite | regular | 1–5 / 6–11 / 12–16 / 17–19 / 20 |
| Hive | Spine Stalker | elite | 1–5 / 6–11 / 12–15 / 16–18 / 19–20 |
| Hive | Carapace Beetle | support | 1–4 / 5–11 / 12–17 / 18–19 / 20 |
| Hive | Broodwarden | tank | 1–4 / 5–11 / 12–17 / 18–19 / 20 |
| Hive | Caustic Spewer | tank | 1–4 / 5–11 / 12–17 / 18–19 / 20 |
| Hive | Hive Matriarch | boss | 1–5 / 6–11 / 12–16 / 17–19 / 20 |
| Veil | Shard Drone | regular | 1–3 / 4–8 / 9–15 / 16–19 / 20 |
| Veil | Prism Charger | regular | 1–3 / 4–8 / 9–15 / 16–19 / 20 |
| Veil | Aegis Anchor | support | 1–2 / 3–8 / 9–16 / 17–19 / 20 |
| Veil | Resonance Warden | tank | 1–2 / 3–8 / 9–16 / 17–19 / 20 |
| Veil | Phaseblade | elite | 1–3 / 4–8 / 9–14 / 15–18 / 19–20 |
| Veil | Stormweaver | tank | 1–2 / 3–8 / 9–16 / 17–19 / 20 |
| Veil | Relay Herald | support | 1–2 / 3–8 / 9–16 / 17–19 / 20 |
| Veil | Veil Overseer | boss | 1–3 / 4–8 / 9–15 / 16–19 / 20 |
| Signal Purge | Signal Wisp | regular | 1–4 / 5–8 / 9–12 / 13–19 / 20 |
| Signal Purge | Circuit Acolyte | elite | 1–4 / 5–8 / 9–11 / 12–19 / 20 |
| Signal Purge | Cipher Scribe | support | 1–3 / 4–8 / 9–13 / 14–19 / 20 |
| Signal Purge | Oath Binder | tank | 1–3 / 4–8 / 9–13 / 14–19 / 20 |
| Signal Purge | False Image | elite | 1–4 / 5–8 / 9–11 / 12–19 / 20 |
| Signal Purge | Ash Channeler | tank | 1–3 / 4–8 / 9–13 / 14–19 / 20 |
| Signal Purge | Signal Hierophant | boss | 1–4 / 5–8 / 9–12 / 13–19 / 20 |
| Mantle Hunt | Pumice Climber | regular | 1–6 / 7–9 / 10–12 / 13–19 / 20 |
| Mantle Hunt | Obsidian Hound | regular | 1–6 / 7–9 / 10–12 / 13–19 / 20 |
| Mantle Hunt | Slag Hound | regular | 1–6 / 7–9 / 10–12 / 13–19 / 20 |
| Mantle Hunt | Geode Panther | elite | 1–6 / 7–9 / 10–11 / 12–19 / 20 |
| Mantle Hunt | Basalt Ape | tank | 1–5 / 6–9 / 10–13 / 14–19 / 20 |
| Mantle Hunt | Cinder Raptor | elite | 1–6 / 7–9 / 10–11 / 12–19 / 20 |
| Mantle Hunt | Magma Drake | tank | 1–5 / 6–9 / 10–13 / 14–19 / 20 |
| Mantle Hunt | Mantle Tyrant | boss | 1–6 / 7–9 / 10–12 / 13–19 / 20 |

**How I read the role rules.**

- **Roles come from the game's own classifier**
  (`DataManager._classify_enemy_role`, which already fills encounter slots):
  a unit with simple AI is regular; 90 HP or more is a tank; two or more
  bands that aid an ally is a support; the rest are elites; the five units
  with a standing rule are bosses.
- **Tanks and supports:** band 1 gives its last face to band 2. Band 4 gives
  its first face to band 3. The top band is the 20 alone, so the upper end is
  band 4.
- **Elites:** band 4 starts one face lower. Band 3 loses that face.
- **Phaseblade and Spine Stalker:** elite, then the 19-20 top takes the 19
  from band 4. Their band 4 ends up as wide as the shape's.

**Ambiguous roles.**

| Unit | Given | Why it is ambiguous |
|---|---|---|
| Cinder Raptor | elite | 86 HP, just under the tank line. It heals itself and taunts, which reads as a tank. |
| Ash Channeler | tank | 94 HP, but it is a damage dealer. |
| Caustic Spewer | tank | 90 HP, exactly on the line. Its kit is hijack and burn. |
| Oath Binder | tank | 112 HP. Its kit is roll penalties and Protocol drain. |
| Volt Enforcer | elite | One band shields all allies. |
| Resonance Warden, Stormweaver | tank | Also supports by kit. Both roles give the same windows. |
| Rust Drone, Static Skimmer, Prism Charger | regular | They debuff or taunt, but they are the small units. |

**What else changed with it.**

- **Enemy ranges are data now.** Each kit has a `range` per band in
  `enemies.data.json`. The single table in `DataManager` is gone, with two
  copies of it in tool scripts. Inspect, the evolution screen, the briefing
  and the die's long-press already read the loaded ranges; nothing was
  hard-coded there.
- **Band-shifting gear keeps one face in the band it takes from.** With
  two-face bands the old arithmetic left an empty band. Ravager's 8-9 gives
  Wide Aperture one face, not two, and the Splice Deal one.
- **Tutorial.** Pulse Tech's scripted die in battle 2, round 1 is 6 (was 4).
  Its lesson says "Pulse deals 6 damage now and 2 Burn damage next turn", and
  that ability moved from 4-9 to 6-9. Every other scripted die lands in the
  same band. No throw was re-recorded. Outcome sim, 1,000 seeds per battle,
  two policies: no losses, no stalls.
- **Tests** that rigged a fixed face now read it from the data.

**For you to decide.**

1. **Phaseblade's top ability carries a 40% summon.** With a 19-20 top it
   fires on 10% of its rolls, not 5%. I did not touch summons; this follows
   from the window you set. Say if its summon should need the 20.
2. **On a 19, Pyro and Wraith fire their top ability** and get its
   celebration. Overload Capacitor, Overload Loop and the 20s stat still need
   a 20. Band Compressor already works this way.
3. **Cinder Raptor** is the closest role call (elite or tank). See the table above.

Gates `roll windows` (under 1 s, eleven in-memory breaks) and `roll windows
live` (two breaks: `shared_table`, `squeeze`).

## 3. Sim report

Policy l1. "Before" is `main` at `c6e9dd3`. "After" is the branch with both
changes. The pinned batch is the gate's 300 runs. The larger batch is 1,500
runs on matched seeds; I ran it because 300 runs is about 60 per operation.

**Clear rate per operation.**

| Operation | 300: before | 300: after | change | 1,500: before | 1,500: after | change |
|---|--:|--:|--:|--:|--:|--:|
| Facility | 40.8% | 32.4% | -8.5 | 37.5% | 32.4% | -5.1 |
| Hive | 25.4% | 32.2% | +6.8 | 29.4% | 38.3% | +8.9 |
| Veil | 26.2% | 21.5% | -4.6 | 23.3% | 17.7% | -5.6 |
| Signal Purge | 28.1% | 19.3% | -8.8 | 27.2% | 17.9% | -9.3 |
| Mantle Hunt | 14.6% | 10.4% | -4.2 | 16.7% | 13.5% | -3.2 |
| **Overall** | **28.0%** | **24.0%** | **-4.0** | **26.7%** | **23.9%** | **-2.8** |

Split by change (1,500 runs): cloak alone is +3.6 overall (30.3%). The
windows then take 6.4 back. Every operation but Hive gets harder under the
windows. No operation moves more than 10 points against `main`.

**Hero win rate** (runs that include the hero).

| Hero | 300: before | 300: after | change | 1,500: before | 1,500: after | change |
|---|--:|--:|--:|--:|--:|--:|
| Pulse Tech | 22.4% | 26.2% | +3.7 | 26.6% | 20.2% | -6.4 |
| Strike Unit | 39.3% | 25.6% | -13.7 | 31.3% | 28.0% | -3.3 |
| Spike Guard | 15.9% | 10.3% | -5.6 | 20.1% | 12.7% | -7.4 |
| Avalanche Suit | 22.8% | 23.7% | +0.9 | 20.0% | 20.3% | +0.3 |
| Splice Medic | 30.5% | 29.5% | -1.0 | 36.4% | 30.6% | -5.8 |
| Field Engineer | 27.0% | 20.7% | -6.3 | 23.6% | 22.8% | -0.8 |
| Ghost Operative | 33.9% | 34.7% | +0.8 | 29.0% | 33.8% | +4.8 |
| Signal Breaker | 30.4% | 20.0% | -10.4 | 27.2% | 23.1% | -4.1 |

The two batches disagree on Pulse Tech, Strike Unit and Signal Breaker. With
about 110 runs per hero the 300-run figures move 8 or 9 points on chance
alone. Both agree on this much: Spike Guard is now clearly the weakest hero,
and Ghost Operative is the only one that gains.

**Signal Hierophant by squad.** The pinned 300 runs reach the boss 48 times
before and 38 after, one to five fights per squad, which says nothing. So I
ran 1,680 Signal Purge runs each way on matched seeds (random squads).

| | Before | After |
|---|--:|--:|
| Signal Purge cleared | 25.2% | 16.6% |
| Runs that reach the Hierophant | 80% (1,343) | 60% (1,003) |
| Boss fights won | 31.5% | 27.8% |
| Won with Splice Medic | 40.7% (540) | 36.9% (425) |
| Won without Splice Medic | 25.3% (803) | 21.1% (578) |
| 500-round stalls | 5 | 2 |

Boss fights won, by hero in the squad:

| Squad has | Before | After |
|---|--:|--:|
| Pulse Tech | 30.2% (510) | 22.6% (390) |
| Strike Unit | 27.4% (540) | 24.4% (427) |
| Spike Guard | 39.0% (438) | 29.1% (278) |
| Avalanche Suit | 26.5% (441) | 23.4% (363) |
| Splice Medic | 40.7% (540) | 36.9% (425) |
| Field Engineer | 24.2% (517) | 21.1% (374) |
| Ghost Operative | 37.1% (512) | 39.8% (377) |
| Signal Breaker | 27.1% (531) | 24.8% (375) |

The Medic gap is unchanged (about 16 points with against without), as you
said to leave it. The larger effect is before the boss: a fifth fewer squads
reach it. All 56 squads, sorted by the after column (8 to 30 fights each, so
single rows are rough):

| Squad | Before: won (fights) | After: won (fights) |
|---|--:|--:|
| Splice Medic / Pulse Tech / Spike Guard | 67% (15) | 75% (12) |
| Signal Breaker / Ghost Operative / Splice Medic | 53% (19) | 69% (13) |
| Avalanche Suit / Strike Unit / Ghost Operative | 29% (24) | 60% (20) |
| Strike Unit / Ghost Operative / Splice Medic | 40% (30) | 57% (28) |
| Avalanche Suit / Ghost Operative / Splice Medic | 67% (24) | 53% (17) |
| Signal Breaker / Splice Medic / Spike Guard | 73% (26) | 50% (16) |
| Ghost Operative / Splice Medic / Spike Guard | 71% (28) | 50% (16) |
| Field Engineer / Ghost Operative / Splice Medic | 38% (26) | 48% (23) |
| Signal Breaker / Ghost Operative / Spike Guard | 39% (18) | 46% (13) |
| Avalanche Suit / Splice Medic / Spike Guard | 50% (12) | 46% (11) |
| Ghost Operative / Splice Medic / Pulse Tech | 39% (33) | 44% (27) |
| Strike Unit / Ghost Operative / Spike Guard | 42% (26) | 42% (19) |
| Strike Unit / Splice Medic / Spike Guard | 53% (19) | 42% (12) |
| Avalanche Suit / Ghost Operative / Pulse Tech | 25% (20) | 41% (17) |
| Field Engineer / Ghost Operative / Spike Guard | 30% (27) | 41% (17) |
| Signal Breaker / Strike Unit / Ghost Operative | 33% (27) | 38% (24) |
| Signal Breaker / Strike Unit / Splice Medic | 21% (33) | 38% (24) |
| Signal Breaker / Splice Medic / Pulse Tech | 43% (42) | 38% (32) |
| Avalanche Suit / Signal Breaker / Ghost Operative | 37% (19) | 33% (12) |
| Field Engineer / Splice Medic / Pulse Tech | 31% (29) | 33% (24) |
| Signal Breaker / Field Engineer / Splice Medic | 27% (33) | 30% (23) |
| Avalanche Suit / Field Engineer / Splice Medic | 29% (24) | 27% (22) |
| Avalanche Suit / Ghost Operative / Spike Guard | 30% (20) | 27% (11) |
| Signal Breaker / Field Engineer / Ghost Operative | 18% (39) | 27% (26) |
| Strike Unit / Ghost Operative / Pulse Tech | 32% (22) | 27% (15) |
| Avalanche Suit / Field Engineer / Ghost Operative | 25% (20) | 26% (19) |
| Avalanche Suit / Splice Medic / Pulse Tech | 38% (29) | 26% (23) |
| Avalanche Suit / Signal Breaker / Strike Unit | 12% (25) | 25% (24) |
| Signal Breaker / Ghost Operative / Pulse Tech | 15% (20) | 25% (12) |
| Field Engineer / Pulse Tech / Spike Guard | 18% (17) | 25% (8) |
| Ghost Operative / Pulse Tech / Spike Guard | 43% (28) | 25% (20) |
| Avalanche Suit / Signal Breaker / Splice Medic | 18% (22) | 24% (21) |
| Strike Unit / Pulse Tech / Spike Guard | 33% (27) | 24% (17) |
| Strike Unit / Field Engineer / Ghost Operative | 35% (23) | 20% (15) |
| Field Engineer / Splice Medic / Spike Guard | 47% (15) | 20% (10) |
| Avalanche Suit / Strike Unit / Splice Medic | 20% (25) | 18% (22) |
| Avalanche Suit / Strike Unit / Spike Guard | 26% (19) | 18% (11) |
| Signal Breaker / Field Engineer / Spike Guard | 40% (25) | 18% (11) |
| Strike Unit / Field Engineer / Spike Guard | 33% (24) | 18% (17) |
| Avalanche Suit / Strike Unit / Field Engineer | 22% (32) | 17% (23) |
| Strike Unit / Field Engineer / Splice Medic | 24% (29) | 16% (25) |
| Field Engineer / Ghost Operative / Pulse Tech | 37% (19) | 15% (13) |
| Strike Unit / Field Engineer / Pulse Tech | 4% (25) | 15% (20) |
| Avalanche Suit / Strike Unit / Pulse Tech | 39% (23) | 10% (30) |
| Signal Breaker / Strike Unit / Pulse Tech | 20% (25) | 8% (24) |
| Strike Unit / Splice Medic / Pulse Tech | 37% (27) | 8% (24) |
| Avalanche Suit / Signal Breaker / Field Engineer | 14% (14) | 8% (13) |
| Avalanche Suit / Pulse Tech / Spike Guard | 22% (18) | 8% (13) |
| Signal Breaker / Strike Unit / Spike Guard | 24% (21) | 8% (13) |
| Avalanche Suit / Field Engineer / Pulse Tech | 15% (20) | 7% (15) |
| Avalanche Suit / Signal Breaker / Pulse Tech | 15% (20) | 6% (17) |
| Signal Breaker / Field Engineer / Pulse Tech | 10% (29) | 6% (18) |
| Avalanche Suit / Signal Breaker / Spike Guard | 6% (18) | 0% (10) |
| Avalanche Suit / Field Engineer / Spike Guard | 8% (13) | 0% (12) |
| Signal Breaker / Strike Unit / Field Engineer | 9% (34) | 0% (20) |
| Signal Breaker / Pulse Tech / Spike Guard | 41% (22) | 0% (9) |

## Housekeeping

Recorded as decided, not to be re-proposed (also G-54):

- **Enemy low bands stay as they are.** My reading: what enemies do on their
  lowest band (the "1-4" abilities) is not to be changed. The range of that
  band did move, to the shapes you set in item 2. Say if you meant something
  else.
- **The Splice Medic / Signal Hierophant imbalance stays for now.**
- **Not worth fixing:** spawn overlap, the hop launch pop, tutorial throw
  re-recording, the Glacier Rig lock.
- **Summons are on hold** pending your decision. Not changed here.

## Gate

Full `python scripts/verify_gate.py` with the sim, Windows Godot 4.6.2, on
`1e36b83` (both commits): **all 81 hard gates PASS, plus profile isolation.**
Three new gates: `cloak ambush` 36 s, `roll windows` under 1 s, `roll windows
live` 3 s (90 s budget each).

Balance sim leg (300 runs against the pinned baseline): overall 0.2833 ->
0.2400; Facility -8.5, Hive +6.8, Veil -4.6, Signal Purge -8.8, Mantle Hunt
-6.2. The gate calls this within tolerance (no operation past 10 points). The
baseline file still says Mantle Hunt 0.1667 where `main` gives 0.1458, which
is why the gate's Mantle Hunt figure is -6.2 and section 3's is -4.2.

**One real failure on the way, fixed.** The first full run failed `unlock
progression`: that test counts the keys on an enemy ability, and each now has
a `range`. The test was corrected and the fix is in `1e36b83`. The run above
is the clean rerun of the whole gate.

The cloak commit was also gated by itself (`41cb184`, in a scratch checkout):
all 79 hard gates of that commit pass.

**Environment only, not code:**

- The main Godot executable is still on the Desktop, not beside the console
  wrapper in Downloads. Gates ran with `GODOT_BIN` pointing at a scratch copy
  of both files.
- The gate ran with `APPDATA` pointed at a scratch folder, because the editor
  was open on the project.
- The `41cb184` run shared the machine with my sim batches. Five gates failed
  there and passed when rerun alone: `validate-data` (the scratch checkout had
  no `node_modules`), both `tutorial recorded throws` (timed out at 90 s under
  twelve sim workers), `save resume` and `battle checkpoint` (the sims used
  the same scratch save folder). None of this touched the final run, which
  had the machine to itself.

## Noticed, not fixed

- **Signal Purge is much harder** (25.2% to 16.6% on its own batch). Its
  heavy band 4 runs 13-19, so its regular enemies fire their fourth ability
  on 35% of rolls where it was 15%.
- **Spike Guard drops to 12.7%.** Its taunt band went from six faces to two.
- **Band Compressor does nothing for Pyro and Wraith.** Their top band is
  already 19-20.
- **Wide Aperture's text says "2 die values lower"** and the Splice Deal's
  says "expands upward by 2". Ravager gets one from each.
- **The cloak icon is dark** on the chip's dark plate. Same art as before;
  the `+50%` beside it reads clearly.
- **The enemy phase's HP preview still ignores Rampage and Pack Bonus.** It
  did before. It now counts the ambush.
- **The inspect prints a one-face band as "20 - 20".** It did before.
- The 500-round stalls that remain all have Avalanche Suit in the squad.
- `scripts/debug/state_hash_tripwire.py` is still stale on `main` and is not
  in the gate.
- `battle_scene.gd` and `protocol_actions.gd` were not touched.

## Follow-up (2026-10-09): your six decisions

Rulings: G-55. Where this differs from the sections above, it wins.

| Commit | Decision | Change |
|---|---|---|
| `bf3bb20` | 3, 4 | Roles by kit; Phaseblade tops out on the 20 |
| this commit | 2 | The signature-move list, for your approval. Nothing swapped |
| this commit | | Sim: a policy that plays the second evolutions (`l1_evo2`) |

Not done, waiting on you: the swaps (item 2) and the number tuning (item 5,
which you set after items 2 to 4). No ability number has changed.

**1. Cloak** stays at +50%. **6.** Shadow's back-to-back ambush, Rampage with
ambush and the low band reading are recorded as accepted.

**3. Roles by kit.** Three units changed shape:

| Unit | Was | Now |
|---|---|---|
| Ash Channeler | tank, 1–3 / 4–8 / 9–13 / 14–19 / 20 | elite, 1–4 / 5–8 / 9–11 / 12–19 / 20 |
| Oath Binder | tank, same | elite, same |
| Caustic Spewer | tank, 1–4 / 5–11 / 12–17 / 18–19 / 20 | elite, 1–5 / 6–11 / 12–15 / 16–19 / 20 |

Every other tank protects itself by kit and stays as it was (Heavy Warden,
Broodwarden, Resonance Warden, Basalt Ape, Magma Drake; Stormweaver is a
support, the same shape). Cinder Raptor stays an elite. The encounter slots
still use their own HP-based classifier; I did not touch it.
One reading: **Oath Binder is an elite** because four of its five bands are
attacks. If a debuffer should count as a support, it keeps its old windows.

**4. Phaseblade** is 1–3 / 4–8 / 9–14 / 15–19 / 20. Spine Stalker keeps
19–20.

Clear rates after items 3 and 4 (1,500 matched runs): overall 23.9% to 24.1%.
No operation moved more than one point.

### 2. Signature moves: the list

A swap exchanges two abilities between two bands of one unit. The ranges
stay. "Faces" is how many of the 20 the ability fires on: before the windows,
now, and after the swap.

**Heroes.**

| # | Unit | Ability that shrank | Faces | Swap with | After | My view |
|---|---|---|---|---|---|---|
| H1 | Spike Guard | Challenge Beacon (3 spike, taunt) | 6 to 2 | Reactive Cover (band 2) | taunt 6, Reactive Cover 2 | Yes |
| H2 | Sentinel | Challenge (4 shield, taunt) | 5 to 2 | Punish (band 3) | taunt 7, Punish 2 | Yes |
| H3 | Bulwark | Fortify (7 shield, taunt) | 6 to 2 | Cover Fire (band 2) | taunt 8, Cover Fire 2 | Yes |
| H4 | Avalanche Suit | Cryo Lattice (freeze any die) | 6 to 3 | Whiteout Spray (band 3) | freeze-any 5, Whiteout Spray 3 | Yes |
| H5 | Ravager | Siphon Slash and Deep Extraction (leech) | 5 + 5 to 2 + 2 | Deep Extraction with Wound Ignition (band 4) | leech 10 plus the 20, detonate 2 | Yes |
| H6 | Pulse Tech | Arc Burst and Plasma Lance (burn) | 6 + 6 to 4 + 4 | Plasma Lance with Flash Detonation (band 4) | burn 10 plus the 20, detonate 4 | Yes, mildly |
| H7 | Signal Breaker | Phase Tear (12 damage, jam) | 6 to 4 | Harmonic Glitch (band 3) | jam 6, Harmonic Glitch 4 | Your call; I would skip |

- **H2** could go to band 2 instead (taunt 5 faces), but that band holds
  Counter Stance, Sentinel's spike, which is the other half of its name.
- **H3**: taunt is not Bulwark's stated focus ("Squad-wide shields"), but it
  is the kit's only taunt, and it is the swap the sim rewards most (below).
- **H5**: without it Ravager, "Leech-fueled brawling", leeches on 5 faces of
  20 and detonates on 8.
- **H6**: Pulse "plants burn on every hit" but now plants it on 9 faces and
  detonates on 6. The tutorial's scripted die is not affected.

Checked, no swap proposed:

- **Shadow Operative.** Its two hit-and-cloak moves went from 10 faces to 7.
  The only wider band is band 4 (9 faces); putting one there would have it
  cloaked on 65% of rolls.
- **Glacier Rig.** Permafrost Weave (freeze any die) went 6 to 3, but its
  other freeze grew: 13 freeze faces before, 12 now.
- **Pyro.** Two burn bands went 5 to 3 each; burn overall 16 faces to 14.
- **Phantom Engineer.** Stealth Field 5 to 3; cloak overall 10 to 8.
- **Splice Medic** (Infusion 7 to 5) and **Trench Rig** (Stabilize 6 to 2,
  while its named taunt and firewall grew).

**Enemies.**

| # | Unit | Ability that shrank | Faces | Swap with | After | My view |
|---|---|---|---|---|---|---|
| E1 | Pumice Climber | Pumice Grasp (pack bonus) | 6 to 3 | Arterial Bite (band 4) | pack attack 7, Arterial Bite 3 | Yes |
| E2 | Obsidian Hound, Slag Hound | Rending Fang (pack bonus) | 6 to 3 | Throat Clamp (band 4) | pack attacks 7 plus the 20, Throat Clamp 3 | Yes |
| E3 | Oath Binder | Compulsion (14 damage, -1 roll) | 6 to 4 | Dominion Bolt (band 4) | roll penalties 12, plain bolt 4 | Yes |
| E4 | Ash Channeler | Cinder Litany (15 damage, burn) | 6 to 3 | Sacrificial Drain (band 4) | burn 8 plus the 20, drain 3 | Yes |
| E5 | Heavy Warden | Field Service (7 shield, 4 heal, self) | 4 to 2 | Crushing Blow (band 2) | self-heal 7, Crushing Blow 2 | I would skip |
| E6 | Resonance Warden | Harmonic Mend (shield, heal, firewall, self) | 4 to 2 | Resonant Slam (band 2) | self-heal 6, Resonant Slam 2 | I would skip |

- **E3 and E4** come from item 3. In the elite shape band 4 is 8 faces. For
  Oath Binder that band holds a plain 19 damage; for Ash Channeler it holds a
  2 Protocol drain, on 40% of its rolls.
- **E5 and E6** are your tank example, but the middle band is wider than
  their old band 1 (4 faces): a Warden that heals itself on 30 to 35% of
  rolls makes its fights longer. Their named traits did not shrink.

Checked, no swap proposed:

- **Circuit Acolyte.** Rewrite went 6 to 3 and drain 6 to 4, but its
  first-named trait, the firewall, went from 7 faces to 12.
- **False Image.** The shield wipe went 6 to 3; its hijack went 3 to 8.
- **Shield Enforcer, Aegis Anchor, Stormweaver, Relay Herald.** Their opener
  went 4 to 2, but every other band carries the same ally shields and roll
  bonuses, and those grew. Relay Herald's firewall is only on that opener.

**What the sim says about the swaps: very little.** They restore what a unit
is known for; they barely move win rates.

| 1,500 matched runs | `main` | Branch now | + H1, H2, H4, H5, H6, E1 to E4 | + H3, H7 |
|---|--:|--:|--:|--:|
| Overall | 26.7% | 24.1% | 24.5% | 25.5% |
| Spike Guard | 20.1% | 11.6% | 12.9% | 15.5% |
| Bulwark (picked) | 23.7% | 14.6% | 17.0% | 20.2% |
| Pulse Tech | 26.6% | 20.9% | 21.4% | 23.0% |

Spike Guard's fall in the sim is mostly Bulwark, because of the next point.

### The sim only ever played first evolutions

Its player takes each hero's first evolution every time: Pyro, Blade Trooper,
Bulwark, Glacier Rig, Combat Medic, Overclock Engineer, Shadow Operative,
Noise Specialist. The other eight have never been in a batch, the pinned
baseline included. So yesterday's hero figures say nothing about Sentinel,
Ravager and the rest.

I added a sim-only policy, `l1_evo2`, that takes the second evolution. The
default is untouched, so the pinned batch is byte for byte what it was.

| 1,500 runs, second evolutions | `main` | Branch now | + recommended swaps |
|---|--:|--:|--:|
| Overall | 17.7% | 20.6% | 19.8% |
| Facility | 31.8% | 31.8% | 32.4% |
| Hive | 18.2% | 33.3% | 29.4% |
| Veil | 13.5% | 14.2% | 13.9% |
| Signal Purge | 17.5% | 11.3% | 9.6% |
| Mantle Hunt | 7.7% | 12.5% | 13.8% |
| Sentinel (picked) | 11.9% | 13.1% | 14.3% |
| Ravager (picked) | 23.1% | 26.6% | 25.1% |
| Phantom Engineer (picked) | 10.6% | 20.5% | 20.1% |

Second evolutions are much weaker than first ones in the sim, on `main` too
(17.7% against 26.7%). That is older than this branch.

### 5. Tuning: where it starts, and how I plan to do it

Against your targets, after items 3 and 4:

| Operation | Target | Now | With the recommended swaps |
|---|--:|--:|--:|
| Facility | 37.5% | 32.4% | 32.4% |
| Hive | 29.4% | 38.0% | 38.3% |
| Veil | 23.3% | 18.1% | 18.1% |
| Signal Purge | 27.2% | 18.9% | 19.5% |
| Mantle Hunt | 16.7% | 13.5% | 14.1% |

My plan, unless you say otherwise:

- Tune **enemy** ability numbers, operation by operation, since the targets
  are per operation and a hero number moves all five at once. Damage first;
  shield and heal where an operation needs it.
- Measure on the standard batch (first evolutions), which is how your targets
  were measured, and report the second-evolution batch beside it.
- Leave hero numbers alone. That leaves Spike Guard low (about 13 to 15%).
  Say if you want hero gaps closed too.

### Gates (targeted only, as asked)

On `bf3bb20`: `validate-data`, `roll windows`, `roll windows live`, `cloak
ambush` and `unlock progression` all pass. The full gate was not run. Godot
ran from the scratch copy through `GODOT_BIN`, with `APPDATA` on a scratch
folder (the editor is open on the project).
