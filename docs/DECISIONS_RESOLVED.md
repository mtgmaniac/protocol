# DECISIONS RESOLVED (human-adjudicated)

## G-65. The HP preview includes traits (Kev, 2026-10-09)

**Ruling (Kev, transcribed).**

"Hero card incoming-damage previews currently ignore traits (e.g. Anchored's
-2). They must include every trait that changes damage or its target:
Anchored, Illusory's negated first hit, Volatile's death damage where it
applies, and any others. Treat it as a class: list every trait that affects a
previewed number and fix them all. Gate it with a deliberate break."

On branch `claude/traits-beasts-geode`, pushed, not merged.

**The cause, and why the fix is not a list.** A hero's bar ran the real hero
phase and then summed each enemy's printed damage. A trait was missing
whenever it acted in the enemy phase or at the tick. Adding the missing traits
to that sum one by one would be right until the next trait. So the sum is
gone: the preview dry-runs the whole round with the code that resolves it
(`CombatManager.forecast_round`), and both kinds of card end their bar on the
result. This is the fix shape TASK_QUEUE already named for the enemy phase.

**The list** (all 26, with what was wrong before) is the table in TRUTH. Six
things were wrong: Anchored, Vengeful, Feral, Fervent, and Volatile when the
unit dies in the enemy phase or at the burn tick. Thirteen traits were already
right and are now pinned. Seven move no HP in the round they act.

**Readings I made.**

1. **"Any others" includes the enemy's own bar.** Vengeful hurts the attacker
   and Fervent heals its owner; both are numbers a card previews.
2. **"Volatile where it applies"** is every way the unit can die in the round:
   a hero's kill, a spike it runs into on its own turn, the burn tick.
3. **Rampage and the pack bonus are fixed too.** They are not traits, but the
   old sum missed them for the same reason and the handoff named them. The
   dry run cannot include traits and leave these out.
4. **The pips are left alone.** A die's pips print the ability; the bar shows
   the outcome. Redline's +2 is in the enemy's bar, not on the attack pip.
5. **A random pick shows as it will fall.** The dry run replays the seeded
   stream and puts it back, as it already did for the hero phase. When every
   hero is cloaked an enemy hits one at random; the bar now shows the hero the
   stream will pick.

**Gate.** `trait preview`, through `break_gate.py`. Breaks: `trait_blind` (the
dry run resolves the round with every trait off) and `hero_phase_only` (the
dry run stops after the hero phase, which is the old preview). In the clean
run each trait case also asks the blind dry run and requires it to be wrong,
so a case that does not depend on its trait fails.

## G-64. Trait requirements (Kev, 2026-10-09)

**Ruling (Kev, transcribed).**

"Tag each trait in traits.data.json with what it needs from the unit's kit
(e.g. Smoldering needs detonate, Vengeful needs taunt, Spectral needs cloak
and jam). validate-data must fail if a unit carries a trait whose requirements
its kit doesn't meet. This is groundwork for possible future trait pools;
don't build any pools, difficulty modes or unlocks."

On branch `claude/traits-beasts-geode`, pushed, not merged.

**As built.** Each trait has `needs`, a list of requirement names. The names
are defined once, in the same file (`requirements`), over the ability fields.
`validate-data` checks every unit against its trait. Tables in TRUTH.

**The tags.**

| Trait | Needs |
|---|---|
| Smoldering | detonate |
| Charged | chain |
| Ruthless | areaAttack, mark |
| Bloodlust | leech |
| Anchored | taunt |
| Vengeful | taunt |
| Glacial | freeze |
| Entrenched | nothing |
| Watchful | heal |
| Overflowing | heal |
| Redline | attack |
| Spectral | cloak, jam |
| Silent | cloak, singleAttack |
| Relentless | attack |
| Static | nothing |
| Zero-Day | rewrite |
| Vigilant | nothing |
| Volatile | nothing |
| Barbed | nothing |
| Corrosive | burn |
| Flickering | nothing |
| Zealous | nothing |
| Illusory | nothing |
| Fervent | burn |
| Commanding | rollPenalty |
| Feral | attack |

**Readings I made (each is a tag the ruling did not give).**

1. **A trait needs what its line reads and the unit's own kit must be able to
   make.** So Glacial needs freeze ("per frozen enemy"), Fervent needs burn
   ("whenever any burn ticks") and Ruthless needs mark as well as an area
   attack, though a teammate or the player could supply each. A pool that gave
   Glacial to a unit that cannot freeze would hand out a trait that does
   nothing in most squads. If these three should be looser, drop the tag:
   one word each.
2. **What a trait makes itself is not a need.** Flickering cloaks its unit, so
   it does not need a cloak ability; Relentless marks, so it does not need
   mark.
3. **Vengeful needs taunt only, not spike,** as the ruling says: it hits back
   with no spike up (G-62, reading 6).
4. **Smoldering needs detonate only,** as the ruling says. Burn to detonate
   can come from anyone.
5. **Feral needs an attack.** Rampage doubles an attack; a unit that never
   attacks would gain nothing.
6. **Silent needs a single-target attack,** since only one can "kill its
   target" from cloak (G-62).
7. **A need is met by one ability,** not by fields spread over two: an area
   attack is damage and `blastAll` on the same ability.
8. **The definitions are data, not validator code.** A trait pool will have to
   ask the same question in the game; reading one table keeps the two from
   drifting. The game does not read it yet.

**Gate.** `validate-data`. It also proves the rule can fail: nine deliberate
breaks on a copy of the real data, each of which must raise its own error. I
also fed it three bad edits to the real file (Vengeful on Wraith, Spectral on
Volt Enforcer, a trait with no `needs`) and two weakened rules (every need
met; `none` ignored); it refused all five.

## G-63. Trait names are titles (Kev, 2026-10-09)

**Ruling (Kev, transcribed).**

"The battle card shows the trait name above the unit's callsign. I like that
display: trait + callsign reads as the unit's full name (e.g. BARBED STALKER),
so keep it.

Rename traits so every one reads as a title with its callsign. Effects don't
change.

Hero evolutions:
- Afterburn -> Smoldering (Pyro)
- Live Wire -> Charged (Arc)
- Exposed -> Ruthless (Bladecore)
- Bloodlust -> keep (Ravager)
- Anchor -> Anchored (Bulwark)
- Retaliate -> Vengeful (Sentinel)
- Glacial Armor -> Glacial (Glacier)
- Dug In -> Entrenched (Trench)
- Triage -> Watchful (Combat Medic; also fixes the clash with its Triage
  ability)
- Overflow -> Overflowing (Synth)
- Redline -> keep (Overclocked)
- Ghost Signal -> Spectral (Phantom)
- Silent Kill -> Silent (Shadow)
- Clean Kill -> Relentless (Wraith)
- Static -> keep (Noise)
- Zero Day -> Zero-Day (Nullwire)

Elites:
- Backup -> Vigilant (Patrol Enforcer)
- Discharge -> Volatile (Volt Enforcer). Replace "DEATH: 4 TO ALL" on its card
  with VOLATILE, in a warning color distinct from the other traits' amber. The
  death damage stays in the long-press text.
- Barbed -> keep (Spine Stalker)
- Corrosive -> keep (Caustic Spewer)
- Blink -> Flickering (Phaseblade)
- Litany -> Zealous (Circuit Acolyte)
- Decoy -> Illusory (False Image)
- Kindle -> Fervent (Ash Channeler)
- Compel -> Commanding (Oath Binder)
- Pack Rage -> Feral (all Mantle Hunt beasts that have it)

Update every place trait names appear: card, long-press, evolution picker,
Help, battle log and trigger chips. Check every trait + callsign pair fits the
card at phone width, and list any that overflow."

On branch `claude/traits-beasts-geode`, pushed, not merged. This replaces the
names in G-62; G-62's rules and readings stand, under the new names.

**As built.** The 21 names changed in `traits.data.json` and nowhere else:
every screen and every log line reads a trait's name from the data. No pair
overflows the card (numbers in TRUTH).

**Readings I made.**

1. **The data key is not renamed.** Each trait keeps its first id
   (`afterburn`, `discharge`, `packRage`) as an internal key, as the roll
   windows keep theirs and Strike Unit keeps `combat`. The id is what the
   rules test and what a saved battle carries, so a rename there could turn a
   trait off in a resumed battle and would change 40 rule sites for no shown
   difference. The data file says so in its comment.
2. **The warning colour is the damage red** (`PixelUI.COLOR_DAMAGE`), the red
   of a damage number and of the HP a hit will take. It is an existing
   `PixelUI` colour, so no new colour was added. It replaces the pale rust the
   old marker used, which sat close to amber.
3. **"The death damage stays in the long-press text"** is the trait line as it
   was: "VOLATILE: When it dies, deals 4 damage to each hero."
4. **A name is one word of at most 12 letters** (a hyphen is allowed, for
   Zero-Day). The schema enforces it, so a later name cannot be a phrase that
   stops reading as a title.

**Gate.** `traits` (same five breaks). New checks: one title word per name; no
retired name in the data; no trait name typed in the nine files that print
one; VOLATILE's colour apart from amber and from the name under it; all 30
trait and callsign pairs fit their card line.

## G-62. Unit traits (Kev, 2026-10-09)

**Ruling (Kev, transcribed).**

"A new system: some units get one always-on trait. It works the same way for
heroes and enemies.
- Hero evolutions get a trait on evolving. Base heroes have none.
- Elite enemies get a trait.
- Mantle Hunt is the only operation where regular units also get a trait (Pack
  Rage, below). Regular units in other operations and all bosses have none.
- Traits should feel noticeable but small.

Hero evolutions:
- Pyro, Afterburn: detonating leaves 1 burn on the target.
- Arc, Live Wire: each chain jump deals +1 damage.
- Bladecore, Exposed: marked enemies take +2 from its area attacks.
- Ravager, Bloodlust: after rolling band 1, its next attack leeches 50% more.
- Bulwark, Anchor: takes 2 less damage while taunting.
- Sentinel, Retaliate: when hit while taunting, its spike deals +2.
- Glacier, Glacial Armor: at round start, gains 1 shield per frozen enemy.
- Trench, Dug In: at round start, gains 3 shield while below half HP.
- Medic, Triage: heals on the lowest-HP ally restore +3.
- Synth, Overflow: healing past full HP becomes shield.
- Overclocked, Redline: +2 damage on every attack while the player has 5 or
  more Protocol.
- Phantom, Ghost Signal: its jams last 1 extra round while it's cloaked.
- Shadow, Silent Kill: an ambush that kills its target doesn't break cloak.
- Wraith, Clean Kill: when it kills a target, the lowest-HP enemy becomes
  marked.
- Noise, Static: at round start, the highest enemy die drops by 1.
- Nullwire, Zero Day: enemies it rewrites take +2 damage that round.

Elites:
- Patrol Enforcer, Backup: when an ally is hit, gains 2 shield.
- Volt Enforcer, Discharge: when it dies, deals 4 to each hero. Its card must
  warn about this clearly.
- Spine Stalker, Barbed: heroes that hit it take 2.
- Caustic Spewer, Corrosive: its burns ignore shields.
- Phaseblade, Blink: after rolling band 1, it cloaks.
- Circuit Acolyte, Litany: at round start, the lowest enemy die rises by 2.
- False Image, Decoy: the first hit against it each battle is negated.
- Ash Channeler, Kindle: heals 3 whenever any burn ticks.
- Oath Binder, Compel: its roll penalties last 1 extra round.

Mantle Hunt: every regular and elite beast (not the boss, which keeps Accrete):
- Pack Rage: when an ally dies, this unit gains rampage. This replaces any
  other trait on Geode Panther and Cinder Raptor.

Dice rules that apply:
- Static and Litany change dice that are already showing. Use the existing
  deliberate-change path so the die visibly tips to its new face and the shown
  value always matches.
- A frozen die keeps its number (freeze ruling), so Static and Litany skip
  frozen dice.
- If both fire in the same round, define the order and tell me what you chose.

UI (use existing components, kept minimal; the UI is being redesigned
separately):
- Long-press: the trait (name and one-line effect) appears above the unit's
  roll breakdown.
- Evolution picker: the trait is shown in the minimized view of each choice,
  so the player always knows it before choosing.
- Battle card: a small trait marker on units that have one, never in portrait
  corners.
- When a trait triggers: a brief chip on the unit naming the trait, plus a
  battle log line, the same pattern as Accrete and Firewall. Respect Reduced
  Motion and No animations (the chip still appears, without animation).
- Help/unit reference: show each unit's trait.
- Copy short, plain, no em dashes."

On branch `claude/traits-beasts-geode`, pushed, not merged. Not tuned: Kev
plays it first.

**The order I chose: Static first, then Litany.** The four round-start traits
fire heroes first, as the round itself does, so Litany has the last word. On
dice 8 and 7 the result is 9 and 7 (the other order gives 8 and 8). The
enemy's trait answers the player's, not the reverse; if that feels wrong in
play it is one line to flip.

**Readings I made (each is a place the ruling left a choice).**

1. **Mantle Hunt's Pack Rage is on five units**, the three regular and two
   elite ones by the G-55 role table. Basalt Ape and Magma Drake are tanks in
   that table and have none (they keep the Accrete keyword). If "every beast
   but the boss" was meant, that is two lines in `traits.data.json`.
2. **"At round start" is when the dice have landed**, before planning. All
   four round-start traits fire there, so the shields and the moved dice are
   in front of the player while they plan.
3. **"Skip frozen dice" means pass over them**: the next highest (or lowest)
   die is taken. A hijacked die is passed over too. A die that cannot move
   (already 1 or 20, or held by a jam cap) is left alone and no other die is
   taken in its place.
4. **Afterburn's burn lasts 2 turns**, and only a detonation that had burn to
   detonate leaves it.
5. **Bloodlust is spent by the next attack that leeches**, not by any next
   attack. Ravager's first window has no leech, so "next attack" read
   literally would often waste it on a hit that cannot leech.
6. **Retaliate and Barbed work with no spike up.** Sentinel's taunt and its
   spike are on different rolls, so "its spike deals +2" while taunting would
   otherwise never apply.
7. **Ghost Signal's "while it's cloaked" is cloaked as the ability starts.**
   Both of Phantom Engineer's jams ride attacks, and the attack breaks the
   cloak before the jam lands.
8. **Zero Day's "that round" is until the rewrite ends**: the rest of the
   round it is applied in, and the round the die shows 3.
9. **Backup's shield is an ordinary one-round shield**, so it covers the rest
   of the heroes' attacks that round.
10. **Kindle heals once for each unit whose burn ticks**, heroes or enemies.
    Against a squad with burn on all three heroes that is 9 a round.
11. **Decoy negates the damage of the first attack.** The attack's burn, mark
    or jam still lands.
12. **Traits are not abilities**: a Firewall does not block one.
13. **Bloodlust and Blink print their unit's own first roll window** ("After
    rolling 1-7"), never a band name, per the band vocabulary rule.

**Two things to know.**

- **Combat Medic now has an ability and a trait both called Triage** (its 1-3
  ability, "6 heal (hero)", and this trait). I kept the ruling's name. One of
  them probably wants renaming.
- **`EnemyData.traits`** (an unused array field) is replaced by `unit_trait`.

**Gate.** `traits`, through `break_gate.py`. Five breaks: `off` (no trait
applies), `no_chip` (a trait applies without its chip), `frozen_dice` (Static
and Litany move frozen dice), `litany_first`, `boss_trait` (every unit that
should have none is given one).

## G-61. Geode Panther attacks the die it freezes (Kev, 2026-10-09)

**Ruling (Kev, transcribed).**

"Geode currently freezes the lowest die but attacks a different target. Change
it so it freezes and attacks the same target, the lowest. Update its text."

**As built.** Calcifying Bite and Stonefang Pounce aim at the hero showing the
lowest die, and the freeze lands on the hero that was hit. The rule is by
ability shape, not by unit name: a single-target attack that also freezes one
die. Only the Panther's two abilities have that shape today. The intent shown
while planning names that hero and follows the dice as the player changes
them. Full rule in TRUTH.

**Readings I made.**

- **"The lowest" is the lowest die showing,** the same pick the freeze always
  used (ties to squad order, cloaked and fallen heroes passed over, a taunt
  overrides).
- **Petrifying Shriek is left alone.** It freezes every die, so there is no one
  die to aim at.
- **Text:** "10 damage, freeze 1 turn (lowest hero die)". The parenthesis names
  the target of the whole line, the convention "(lowest HP)" already uses.

**Gate.** `geode targeting`. Breaks: `split` (the hit aims apart from the
freeze, the old behaviour) and `stale` (the planning intent reads last round's
dice).

## G-60. Beasts rework: rampage and pack bonus (Kev, 2026-10-09)

**Ruling (Kev, transcribed).**

"Beasts rework
- Rampage, game-wide: lasts until the unit's next turn and doesn't stack.
- Pack bonus: make it noticeably stronger. Propose the new numbers in the
  report, with the old values beside them."

On branch `claude/traits-beasts-geode`, pushed, not merged. Kev plays it before
deciding on tuning.

**As built.**

- **Rampage.** On or off. The unit's next turn spends it: an attack on that
  turn deals double damage, a turn that does not attack lets it go. A grant
  to a unit that already has it changes nothing.
- **Pack bonus: +3 per other living pack member of the same kind** (was +1).
  One constant, `CombatManager.PACK_BONUS_PER_MEMBER`. The table is in TRUTH.

**Readings I made (say if any is wrong).**

- **"Until the unit's next turn" includes that turn.** Read the other way
  (it ends as the turn starts) a rampage could never double anything, since a
  unit only attacks on its turn.
- **A rampage a unit grants itself during its turn is for its next turn.** So
  Tyrant Mantle (20 shield, rampage) still sets up the following round.
- **A rampaging unit whose turn grants rampage again keeps exactly one.** No
  "ends unused" line is shown for the old one.
- **A turn lost to the Decoy Beacon spends it.** A unit with no die this round
  took no turn and keeps it.
- **Ability text left alone:** "1 rampage (self)" and "1 rampage (all allies)"
  still read correctly, and changing them would mean changing the ability
  text format and its three checkers.
- **Pack bonus counts the same units as before** (same `enemy_type`; the dead
  do not count). Only the number changed.

**Why +3.** At +1 the pack-bonus attack was the weakest attack in the kit even
with a full pack. At +3 a full pack makes it the strongest non-20 attack, a
pack of two sits just under the plain attack, and killing one packmate takes 3
off every later bite. With Pack Rage (G-62) the trade is visible both ways: a
kill weakens the pack bonus and enrages the survivors for one turn.

**Gate.** `rampage`: `scripts/debug/rampage_test.gd` through `break_gate.py`.
Breaks: `stack` (grants add up again), `keep` (an unused rampage carries
over), `pack_one` (+1 again).

## G-59. Working rules; the break gate's real leg runs on change (Kev, 2026-10-09)

**Ruling (Kev, transcribed).**

"sim size break: run its real leg only when ci_smoke.py or the pin files
change, not on every full gate.

Working rules
- Never run the full verify_gate.py unless the prompt explicitly asks for it.
  Run only gates related to the change.
- After fixing a failure, rerun only the gate that failed, not the full suite.
- If an unrelated test fails or looks flaky, report it and move on. Don't
  investigate unless asked.
- Time-box: if a task runs well past its main work, stop and report where
  things stand instead of continuing.
- Before any wait longer than 10 minutes, check the process is alive and
  progressing."

**As built.**

- The rules are in the root `CLAUDE.md` under "Working rules". The older
  "Verification policy" paragraph there said to run the full gate once at the
  end of every task; it now defers to the rules. `docs/TASK_TEMPLATE.md` says
  the same.
- **The real leg's trigger is a committed stamp**,
  `scripts/sim/size_break_stamp.json`: the sha256 of `scripts/sim/ci_smoke.py`,
  `baseline.json` and `baseline_pins.json` (line endings normalized), written
  by `sim_size_break.py` when the real leg passes. The gate runs the real leg
  when the stamp is missing or does not match, and otherwise prints that it
  was skipped. `--real` forces it; `--logic-only` is unchanged.
- **Why a stamp and not git:** "changed" has to mean the same thing before
  and after a commit, on any clone. A diff against HEAD is empty the moment
  the change is committed, so the leg would never run in a gate after the
  commit.
- **The first stamp was written without rerunning the leg.** It passed on
  `cf30e31` (222 seconds, Hive flagged at -9.8) and none of the three files
  has changed since.
- **Not in the trigger, by the ruling:** game data and combat code. A combat
  change moves the tripwire, and re-pinning for it changes the pin files,
  which makes the real leg due.
- **Deliberate break:** `stale_stamp` (the fingerprint never changes) joins
  the four in Part A. The clean run also checks that a change to each of the
  three files, one at a time, makes the leg due, and that CRLF alone does not.

## G-58. Two-tier sim gate (Kev, 2026-10-09)

**Ruling (Kev, transcribed).**

"Approved: build the two-tier sim gate as proposed.
- Keep the 300-run pin as a tripwire on every full gate. Its output says that
  any move means combat changed, and that size is unreliable.
- Add a 1,500-run second pin, run only when the tripwire moves, with
  thresholds of 8 points per operation and 4 overall.
- Pin second evolutions (l1_evo2) the same way.
- Process rule: whenever numbers are tuned to a target, report a second seed
  base too.
Record it in DECISIONS_RESOLVED. Add a deliberate break showing the size check
fails on a real 10-point change. Gate, merge to main, push."

This is the setup proposed in G-57, now built. It replaces the single 300-run
leg and its 10-point line. BASELINE-APPROVED-BY-KEV is on the commit: it
changes an enforcement threshold (INVARIANTS #13).

**As built.**

- **Tier 1, the tripwire.** 300 pinned runs for `l1` and 300 for `l1_evo2`
  (seed base 900000), on every full gate, about 75 seconds. An unchanged tree
  reproduces them exactly. If any pinned figure differs (overall, an
  operation, a hero, a content figure) the output says: the tripwire moved,
  any move at all means combat changed, and the size shown is unreliable on
  300 runs and must not be read.
- **Tier 2, the size check.** 1,500 pinned runs, run only for a policy whose
  tripwire moved (about 3.5 minutes each). A move beyond **8 points on an
  operation or 4 overall** is the ceremony: exit 3, and the re-pin needs Kev's
  token. Inside the line the gate passes and says to re-pin.
- **Pins.** `scripts/sim/baseline.json` is still the `l1` tripwire.
  `scripts/sim/baseline_pins.json` holds the `l1_evo2` tripwire and both size
  pins. `ci_smoke.py --update-baseline` writes all four together, and the
  second file carries a tie to the first (`pinned_with`): the gate and the
  commit hook both refuse pins that were not written together, so a tripwire
  cannot be re-pinned alone to hide a change from the size check.

| Pin | `l1` tripwire (300) | `l1` size (1,500) | `l1_evo2` tripwire (300) | `l1_evo2` size (1,500) |
|---|--:|--:|--:|--:|
| Overall | 0.2600 | 0.2653 | 0.2900 | 0.2760 |
| Facility | 0.2958 | 0.3246 | 0.3944 | 0.3770 |
| Hive | 0.3390 | 0.3079 | 0.4068 | 0.3238 |
| Veil | 0.3231 | 0.2606 | 0.2769 | 0.2866 |
| Signal Purge | 0.1579 | 0.2391 | 0.1930 | 0.2029 |
| Mantle Hunt | 0.1458 | 0.1886 | 0.1250 | 0.1785 |

- **One place for the line.** `ci_smoke.SIZE_OP_PTS` (8) and
  `SIZE_OVERALL_PTS` (4). `verify_gate.py` imports them and the commit hook
  reads them from the file being committed. The old `CEREMONY_PTS` was kept in
  two files and guarded in both; it is gone, with `ci_smoke`'s four tolerance
  constants (the exact tripwire does their job). `threshold_guard.py` now
  watches the two lines (may not rise) and the two run counts (may not fall).
- **Commit hook.** `baseline_ceremony.py` judges the size pins against HEAD at
  8 and 4, not `baseline.json` at 10. It does not judge the 300-run pins.
- **The deliberate break: gate `sim size break`**
  (`scripts/checks/sim_size_break.py`).
  - Part A, on made-up figures: 8.0 on an operation passes and 8.1 does not;
    4.0 overall passes and 4.1 does not; one run's worth on one hero is a
    tripwire move; untied pins are refused; the hook agrees with the gate.
    Four in-memory breaks must each make it fail: the operation line back at
    10, the overall line at 10, a tripwire that never reports, an unchecked
    tie.
  - Part B, a real change through the real size check: **+8% enemy damage in
    the Hive** (`ci_smoke.SIZE_BREAK_TUNING`). On three 1,500-run seed sets it
    costs the Hive 9.8, 8.9 and 10.3 points: a real 10-point change. On the
    pinned 1,500 runs it reads -9.8 and is flagged.
  - The same change under the old check: the pinned 300 runs read it as -6.8,
    inside the old 10-point line, so the old gate would have passed it. Over
    fifteen blocks of 300 runs it read from -19.7 to +1.8 and crossed 10 in
    nine.

**Process rule (ruling, last point).** Recorded as INVARIANTS #8: whenever
numbers are tuned until a batch hits a target, the before and the after are
also run on a second seed base the tuning never saw, and both are reported
with the pooled difference.

**My readings.**

1. **A "move" is any pinned figure that differs**, the content figures
   included. So a change to what rewards are offered also trips it; that is a
   change to how runs play, and worth the size check.
2. **The size check runs only for the policy that moved.** A change to a
   second evolution leaves the `l1` pins untouched and costs one 1,500-run
   batch, not two.
3. **Inside the line the gate passes (exit 0) and the pins stay as they
   were.** Later changes are still measured against the last pin, so small
   moves cannot add up unseen. Until someone re-pins, every full gate pays for
   the size check. A re-pin inside the line needs no token; beyond it the hook
   asks for Kev's.
4. **`--runs` is gone** from `verify_gate.py` and `ci_smoke.py`. A tripwire
   on another run count cannot reproduce a pin.
5. **Cost.** The tripwire is 75 seconds where the old leg was 36. The break
   gate adds about 4 minutes to every full gate (a 300-run tripwire and one
   1,500-run batch). If that is too much for every gate, Part B can move to
   run only when `ci_smoke.py` changes; Part A is instant. Kev's call.
6. **What the size check cannot do.** At 1,500 runs one operation is about
   300 runs, and a real move still reads 2 to 4 points either way. The same
   calibration cut enemy damage 7% in Veil: a real move of about 9 points,
   which read +8.1, +7.3 and +12.6 on the three sets, so one set in three
   stayed inside the line. A real 10-point move on one operation is caught
   most of the time, not every time; 12 and over is caught reliably. A change
   that moves every operation is caught far sooner by the 4-point overall
   line.

**Found while gating: `tutorial smoke` was a coin that mostly landed heads.**
It failed once in the full gate and passed alone. Its last check wants to see
Pulse Tech's round-one burn tick in the practice battle. That burn ticks at
the end of round two, and round two is free play on live dice: if the heroes
kill the burned drone first, or Pulse rolls its Detonate on it, nothing ticks
and the check fails. It failed about one run in eight since the 2026-10-08
windows (my estimate from today's runs: 1 of 8). Nothing is wrong for a
player: the tutorial only adds "Watch Burn deal damage at the end of this
turn" when a burned enemy is alive.

- The test now sets each hero's die for that one round to its kit's gentlest
  roll (least damage, never a Detonate), read from the kit, until the tick has
  been seen. Checked with the dice printed out: three runs, the three gentle
  rolls landed and the burn ticked each time.
- For that to work, one line of `battle_scene.gd` changed: in tutorial mode
  the scene sets the tray's requested faces only when the round has a plan. It
  used to set an empty plan on free rounds, which wiped anything a test had
  asked for. No difference in play: the tray clears its requests after every
  throw, and nothing but the tutorial plan and the tests ever sets them.
- My first attempt at this fix did nothing (the wipe above), and six passes in
  a row hid that. I only caught it by printing the dice.

## G-57. Numbers approved; re-pin, gate and merge (Kev, 2026-10-09)

**Rulings (Kev, transcribed).**

1. "Keep all numbers as they are, including the Arc, Trench and Nullwire
   nerfs."
2. "Re-pin baseline.json to the final tuned state. Tell me whether 300 runs is
   too noisy for the gate's sim leg, given it disagrees with the 1,500-run
   batches by up to 12 points. If so, propose a better setup (more runs, or
   tolerances based on measured noise) but don't change it yet."
3. "Run every gate that hasn't passed on the final data (71d8bb0), including
   the five layout and flow gates that ran before the last trim, plus the sim
   leg after re-pinning. Skip gates that already passed on the final data. Fix
   any test that rigged rolls or abilities by number the way preview accuracy
   and freeze regression did, reading from the kit instead. Report anything
   that fails."
4. "If everything passes, merge claude/cloak-and-windows into main and push.
   No itch build."

**Closed by ruling 1:** every number in G-56 stands, the three second
evolutions tuned down included (G-56 ruling 4, my reading 2). Not to be
re-proposed.

**As built, ruling 2 (re-pin).** `baseline.json` is the tuned game: overall
0.2600, Facility 0.2958, Hive 0.3390, Veil 0.3231, Signal Purge 0.1579, Mantle
Hunt 0.1458. `ci_smoke.py` reproduces it exactly.

**Is 300 runs too noisy? Yes, for judging size. No, as a tripwire.** Measured:
the change from `main` to the tuned game, read on ten separate 300-run blocks
of the two 1,500-run sets.

| Per 300 runs | Real move (3,000 runs) | Spread between blocks (SD) | Lowest and highest block |
|---|--:|--:|--:|
| Facility | +2.3 | 8.0 | -12 to +12 |
| Hive | +1.8 | 9.1 | -15 to +19 |
| Veil | +1.7 | 6.9 | -11 to +10 |
| Signal Purge | -0.3 | 6.7 | -13 to +12 |
| Mantle Hunt | -0.9 | 4.9 | -8 to +7 |
| Overall | +0.8 | 3.9 | -5 to +8 |

- A change whose real effect is under 2.5 points on every operation crossed
  the 10-point line on at least one operation in 5 of those 10 blocks. The
  pinned 300 runs, an eleventh block, crossed it too (Facility -11.3, Signal
  Purge -12.3).
- What still works: the sim is deterministic, so a tree that does not touch
  combat reproduces the pin exactly. Any move at all is a true signal that
  combat changed. Only its size is unreliable.
- At 1,500 runs the spread per operation is about 2 to 4 points (SD) and
  under 2 overall (the 300-run spread divided by the square root of 5; the
  750-run blocks agree).

**Proposed setup (not built; needs Kev's yes, and the token, since it changes
an enforcement threshold, INVARIANTS #13):**

1. **Keep the 300-run leg as the tripwire**, and say so in its output: "any
   move means combat changed". It costs 36 seconds and stays in every full
   gate.
2. **Judge size on 1,500 runs, only when the tripwire moves.** A second pinned
   file from the same seed base at 1,500 runs (about 3.5 minutes). A change
   that does not touch combat never pays for it.
3. **Set the line from the measured spread:** 8 points per operation (2 SD
   or more at 1,500 runs) and 4 overall, in place of 10 per operation on 300.
   That is tighter than today and trips far less often by chance.
4. **Pin the second evolutions too:** the same two legs for `l1_evo2`. Today
   nothing in the gate plays them.
5. When a change is tuned to a target, also report a second seed base. Tuning
   to one set of seeds fits that set (G-56 ruling 2, my reading 2).

**As built, ruling 3 (tests and gates).**

- **Tests that rigged a roll by number now read the kit.** Beside the two
  fixed in `e2da97f`: `preview accuracy` (chain, pierce, execute and the three
  single-target cases), `action motion` (which hero attacks, which enemy does
  not), `accrete display` (the boss's shield-and-rampage roll, the first
  hero's attack), `taunt planning chip` (the enemies' attack), the live part
  of `cloak ambush` (the two cloaked units' attacks), and the detonate capture
  in the dev tool `battle_ui_capture.gd`. Where the old number is still the
  right kind of ability it is kept, so today's runs are unchanged.
- **Left alone, and why:** the tutorial's scripted dice and the audit's checks
  of its math (the numbers are the product, and the checks fail loudly if a
  band moves); the gear checks whose subject is a band edge (Band Compressor,
  Wide Aperture, Standing Order, the Splice Deal); tests built on made-up
  units; dice that only have to land (layout, checkpoint, resume, dice face);
  and `unlock progression`'s three Rust and Scrap Drone abilities, which are
  pinned on purpose to prove a rename kept their mechanics.
- **Correction to my last report.** I said five layout and flow gates had last
  run before the final trim. It was 25 gates. All of them, and every gate that
  had never run on this branch's final data, were run for this ruling.
- **One gate failed and was fixed: `save resume`.** It played seed 4242's
  Facility squad to a checkpoint before battle 4; with the new balance that
  squad dies in battle 3, so the checkpoint leg wrote no save. Saving was not
  at fault. The gate now uses the first seed from 4242 upward whose run
  reaches the checkpoint (4243 for Facility on this data).
- **Result:** all 81 hard gates pass on the final data, with profile
  isolation, and the sim leg reads +0.0 on every operation against the new
  pin. 64 gates were run for this ruling; the other 17 had already passed on
  the final data, and five of those were run again after their tests changed.

**As built, ruling 4.** `claude/cloak-and-windows` merged into `main` and
pushed. No itch build.

## G-56. Swaps approved; tune enemies, outlier heroes and second evolutions (Kev, 2026-10-09)

**Rulings (Kev, transcribed).**

1. "Swaps: approve H1–H6 and E1–E4. Skip H7, E5 and E6."
2. "Item 5, enemy tuning: proceed as you planned. Tune enemy numbers operation
   by operation to the targets on the standard first-evolution batch, and
   report the second-evolution batch beside it. Hive needs to come up in
   difficulty too, not only the others down."
3. "Hero gaps: close outliers only. Bring Spike Guard (and any hero more than
   about 5 points below its pre-windows rate) back toward its old rate through
   its own ability numbers. Leave other heroes alone."
4. "Second evolutions: after the enemy tuning, do a hero-side pass so each
   second evolution lands within about 3 points of its first-evolution sibling
   on the l1_evo2 batch. Tune only the second evolutions' own ability numbers.
   Report every number changed."

The targets in ruling 2 are G-55's: Facility 37.5%, Hive 29.4%, Veil 23.3%,
Signal Purge 27.2%, Mantle Hunt 16.7%, within about 3 points, on 1,500-run
batches.

**As built, ruling 1 (the swaps).** Two abilities of one unit change places;
ranges, shapes and numbers stay.

| # | Unit | Swap | Result |
|---|---|---|---|
| H1 | Spike Guard | Challenge Beacon with Reactive Cover | taunt on 3–8 (6 faces, was 2) |
| H2 | Sentinel | Challenge with Punish | taunt on 8–14 (7 faces, was 2) |
| H3 | Bulwark | Fortify with Cover Fire | taunt on 3–10 (8 faces, was 2) |
| H4 | Avalanche Suit | Cryo Lattice with Whiteout Spray | freeze any die on 10–14 (5 faces, was 3) |
| H5 | Ravager | Deep Extraction with Wound Ignition | leech on 8–9, 12–19 and the 20 (11 faces, was 5) |
| H6 | Pulse Tech | Plasma Lance with Flash Detonation | burn on 6–9, 14–19 and the 20 (11 faces, was 9) |
| E1 | Pumice Climber | Pumice Grasp with Arterial Bite | pack attack on 13–19 (7 faces, was 3) |
| E2 | Obsidian Hound, Slag Hound | Rending Fang with Throat Clamp | pack attack on 13–19 and the 20 (8 faces, was 4) |
| E3 | Oath Binder | Compulsion with Dominion Bolt | roll penalty on 1–4 and 12–19 (12 faces, was 8) |
| E4 | Ash Channeler | Cinder Litany with Sacrificial Drain | burn on 12–19 and the 20 (9 faces, was 4); drain on 9–11 (3 faces, was 8) |

Not swapped, as ruled: H7 (Signal Breaker), E5 (Heavy Warden), E6 (Resonance
Warden).

**As built, ruling 2 (enemy numbers).** 68 damage numbers on 19 enemies, by
1 to 3 points; the table is in TRUTH (2026-10-09 entry). Per operation:

- **Facility:** Shield Enforcer -1 on each attack. Nothing else.
- **Hive (harder):** Spine Stalker, Carapace Beetle, Broodwarden and Caustic
  Spewer +1 on each attack (Broodwarden's 20 is +2); Hive Matriarch +2 on each
  attack, +3 on Royal Mandibles (19 to 22).
- **Veil:** Aegis Anchor, Resonance Warden, Phaseblade and Stormweaver -1 on
  each attack (Stormweaver's lightest is unchanged).
- **Signal Purge:** the five larger units -1 on each attack, -2 on the heaviest hits
  of Oath Binder, False Image and Ash Channeler; Signal Hierophant -1
  on Absolute Binding and on its 20.
- **Mantle Hunt:** Geode Panther, Basalt Ape and Cinder Raptor -1 on their
  heavier attacks.

**How it was fitted.** A per-operation damage multiplier was swept first
(sim knob `enemy_dmg_scalar`): about -5% on four operations and +6% on the
Hive put all five near target. That was baked into whole numbers, then
trimmed: units whose numbers did not move the clear rate went back to what
they had (all small units, Patrol Enforcer), and others went back to stop an
operation overshooting (Heavy Warden, Volt Enforcer, Relay Herald, Magma
Drake, three bosses). Sensitivity is high: 5% of enemy damage is about 6
points of clear rate.

**My readings, ruling 2:**

1. **Damage only.** The ruling allows shield and heal amounts too; damage
   was enough, so nothing else moved.
2. **"Within about 3 points" is met on the batch the targets came from**
   (seed base 500000): every operation is within 0.7. I also ran `main` and
   the tuned game on a second 1,500 runs (seed base 700000) to see how much
   of that is fit to one set of seeds. There the tuned game is 5.0 (Facility),
   3.6 (Hive) and 3.4 (Veil) points easier than `main`, level on Signal Purge,
   and 2.1 harder on Mantle Hunt. Pooled over both sets no operation is more
   than 2.2 from `main`.
3. **The pinned 300-run batch is not re-pinned** and disagrees with both big
   batches: Facility -11.3, Hive +8.5, Veil +6.2, Signal Purge -12.3, Mantle
   Hunt -2.1 against `baseline.json`. That is about 60 runs per operation.
   The full gate's sim leg will stop on the 10-point line for Facility and
   Signal Purge until Kev re-pins.

**As built, ruling 3 (outlier heroes).** Four numbers:

- **Spike Guard:** Challenge Beacon spike 3 to 5; Spike Stance shield 5 to 7.
  **Bulwark:** Fortify shield 7 to 9. Spike Guard goes 16.0% (swaps alone) to
  18.5%, against 20.1% before the windows; on the second seed set 16.1%
  against 14.8%.
- **Pulse Tech:** Pyro Specialist's Backdraft damage 14 to 16.

**My readings, ruling 3:**

1. **"Pre-windows rate" is the hero's rate on `main`**, the same batch the
   operation targets came from.
2. **Pulse Tech counted as an outlier.** With the enemies tuned and Spike
   Guard's two base numbers in, it was 21.6% against 26.6%, 5.0 under. No
   other hero was more than 2 under.
3. **Pulse Tech's number is on its evolution, not its base kit.** +1 damage on
   Static Ping, Arc Burst and Plasma Lance did not help (21.6% to 20.9%). Backdraft +2 moved it 2 points. The sim always evolves Pulse
   into Pyro, so this helps the Pyro line only; Arc Specialist is handled by
   ruling 4.
4. **Spike Guard's Bulwark number.** The two base numbers alone left it at
   about 18%; Fortify added about 1.5 points when it went in. Sentinel is matched to Bulwark
   under ruling 4.
5. Pulse Tech still reads 4.6 under on the first seed set (22.0%) and level
   on the second (26.3% against 25.7%). I stopped there: the two sets disagree
   by more than the gap.

**As built, ruling 4 (second evolutions).** 20 numbers on the eight second
evolutions; the table is in TRUTH (2026-10-09 entry).

- **Up:** Ravager (Thermal Cut 6 to 7, Siphon Slash 9 to 11, Deep Extraction
  12 to 15), Sentinel (Counter Stance spike 6 to 8, Challenge shield 4 to 8,
  Repulsion Field 8 damage and 6 shield to 9 and 7), Synth Medic (Nanite
  Crossfire damage 6 to 9), Phantom Engineer (EMP Pulse 7 to 10), Wraith (Scan
  Weakness 4 to 6, Neural Trace 8 to 10, Assassinate 14 to 16, Wraith Blade 15
  to 17).
- **Down:** Arc Specialist (Forked Lightning 12 to 11, Arc Cascade 15 to 14),
  Trench Rig (Dig In shield 8 to 6, Trench Breaker 18 to 16), Nullwire (Bit
  Spike 9 to 8, Deep Interference 12 to 11, Signal Sever 14 to 13).

**My readings, ruling 4:**

1. **What is compared.** A second evolution's rate on the `l1_evo2` batch
   against its sibling's rate on the standard `l1` batch, both counted over
   runs where that evolution was picked.
2. **Three second evolutions were tuned down.** The ruling says to tune the
   second evolutions' own numbers so each lands within about 3 points. Arc
   Specialist, Trench Rig and Nullwire started within 3 of their sibling while
   playing beside five weak squadmates. Once those five were lifted, the three
   stood 6 to 8 points above their sibling. Leaving them would have broken the
   target the other way, so they came down by 2 or 3 numbers each. If Kev
   would sooner leave them strong, those seven numbers go back and the three
   would read roughly 5 points high (my estimate, not measured).
3. **Where it ended.** On the batch named in the ruling, seven of eight are
   within about 3 (Arc Specialist +3.1) and Ravager is 4.3 under. On the
   second seed set Ravager is 4.4 over and Trench Rig 5.7 over. I stopped
   rather than chase a gap that changes sign between seed sets.
4. **Sensitivity.** A second evolution's first trial buff (2 to 4 points on
   three or four abilities each) took the batch from 21% to 35% overall. The
   final numbers are about half of that.

## G-55. Decisions on the cloak and windows branch (Kev, 2026-10-08)

**Rulings (Kev, transcribed).**

1. "Cloak: keep +50%."
2. "Signature moves: Spike Guard lost most of its taunt because its taunt sits
   in band 1, which the tank shape shrank to two faces. Treat it as a class:
   for every hero and enemy, check whether its defining ability sits in a band
   that shrank. List each case and propose moving that ability into the band
   the shape intends for it (e.g. a tank's taunt into a middle band). Don't
   change any shapes. Show me the list, then apply the swaps I approve."
3. "Roles: classify enemies by kit, not HP. Ash Channeler, Caustic Spewer and
   Oath Binder get their kit-based role and shape. Cinder Raptor stays elite."
4. "Phaseblade: top band back to 20 only, pending my summons decision. Spine
   Stalker keeps 19–20."
5. "Difficulty: keep the new windows. After items 2–4, tune ability numbers
   (damage, shield, heal amounts) so each operation's clear rate lands within
   about 3 points of its old value on 1,500-run batches: Facility 37.5%, Hive
   29.4%, Veil 23.3%, Signal Purge 27.2%, Mantle Hunt 16.7%. Report every
   number you changed."
6. "Accept as-is: Shadow ambushing on consecutive rounds, Rampage and ambush
   stacking, and the low band reading (abilities closed, ranges moved)."

**Closed by this:** G-52's number (+50%) and its readings 5 and 7; G-54's
reading of the enemy low bands; G-53's reading 5 for Cinder Raptor (elite).
**Overturned:** G-53's reading 1 (roles from the HP-based classifier) and its
reading 4 for Phaseblade.

**As built (items 3 and 4):**

- **Roles are by kit.** A tank protects itself (self shield, heal or growing
  armour); a support aids its allies in two or more bands; the small units
  are regular; the five with a standing rule are bosses; the rest are elites.
  Three units change: **Ash Channeler** and **Oath Binder** take the Signal
  Purge elite shape (1–4 / 5–8 / 9–11 / 12–19 / 20) and **Caustic Spewer**
  the Hive elite shape (1–5 / 6–11 / 12–15 / 16–19 / 20). Every other tank
  was checked against its kit and stays a tank or a support: Heavy Warden,
  Broodwarden, Resonance Warden (shield and heal themselves), Basalt Ape,
  Magma Drake (self shield and Accrete), Stormweaver (lifts ally rolls in four
  bands; a support, which is the same shape). The encounter slots still use
  `DataManager._classify_enemy_role` unchanged; only the windows table moved.
- **My reading on Oath Binder:** elite. Four of its five bands are attacks of
  14 to 21 damage with a debuff riding on them, and it aids no ally. If a
  debuffer should count as a support it keeps the windows it had (1–3 / 4–8 /
  9–13 / 14–19 / 20).
- **Phaseblade** is an elite with the 20 alone on top: 1–3 / 4–8 / 9–14 /
  15–19 / 20. Its summon ability fires on 5% of rolls again. The `roll
  windows` gate now allows the wide top for Pyro, Wraith and Spine Stalker
  only, and has a break for Phaseblade getting it back.

**Item 2** is a list for Kev to approve (handoff, "Signature moves"); nothing
was swapped. **Item 5** waits for those approvals, as ruled ("after items
2–4"). No ability number was changed.

## G-54. Closed items, not to be re-proposed (Kev, 2026-10-08)

**Ruling (Kev, transcribed from the task).** "In the handoff, record these as
decided and not to be re-proposed: enemy low bands (1–4) stay as they are;
the Medic/Signal Hierophant imbalance stays for now; spawn overlap, the hop
launch pop, tutorial throw re-recording and the Glacier Rig lock are not worth
fixing." And: "Summons are on hold pending my decision; don't change them."

- **Enemy low bands stay as they are.** My reading: what enemies do on their
  lowest band (the mostly non-attacking abilities that sat on 1–4 until
  G-53) is not to be changed. The range of that band is whatever G-53's
  shapes give it (1–2 to 1–6).
- **The Splice Medic / Signal Hierophant imbalance stays for now.** Measured
  again on 2026-10-08 (1,680 Signal Purge runs): boss fights won with Splice
  Medic 36.9%, without 21.1%. Do not propose a fix until Kev reopens it.
- **Not worth fixing:** spawn overlap on main rolls, the hop launch pop,
  re-recording the tutorial throws, and the Glacier Rig lock (G-46's "known
  lock"; its candidate fix, the re-freeze rule, is not to be re-proposed
  either).
- **Summons are on hold** pending Kev's decision. Do not change summon
  chances, summon content or summon rules until he rules.

## G-53. New roll windows for every unit (Kev, 2026-10-08)

**Ruling (Kev, transcribed from the task).** "Every unit keeps five bands and
its current abilities. Only the ranges change. Very few units fire their top
move on more than a 20.

Heroes and evolutions, exactly as follows (band 1 -> top):
- Pulse Tech 1–5 / 6–9 / 10–13 / 14–19 / 20
  - Pyro 1–6 / 7–9 / 10–12 / 13–18 / 19–20
  - Arc 1–3 / 4–8 / 9–14 / 15–19 / 20
- Strike Unit 1–5 / 6–10 / 11–14 / 15–19 / 20
  - Bladecore 1–3 / 4–8 / 9–15 / 16–19 / 20
  - Ravager 1–7 / 8–9 / 10–11 / 12–19 / 20
- Spike Guard 1–2 / 3–8 / 9–15 / 16–19 / 20
  - Bulwark 1–2 / 3–10 / 11–17 / 18–19 / 20
  - Sentinel 1–2 / 3–7 / 8–14 / 15–19 / 20
- Avalanche Suit 1–3 / 4–9 / 10–14 / 15–19 / 20
  - Glacier 1–3 / 4–11 / 12–16 / 17–19 / 20
  - Trench 1–2 / 3–9 / 10–16 / 17–19 / 20
- Splice Medic 1–4 / 5–9 / 10–14 / 15–19 / 20
  - Medic 1–3 / 4–9 / 10–15 / 16–19 / 20
  - Synth 1–3 / 4–8 / 9–13 / 14–19 / 20
- Field Engineer 1–4 / 5–10 / 11–14 / 15–19 / 20
  - Overclocked 1–6 / 7–9 / 10–13 / 14–19 / 20
  - Phantom 1–3 / 4–10 / 11–15 / 16–19 / 20
- Ghost Operative 1–6 / 7–10 / 11–13 / 14–19 / 20
  - Shadow 1–4 / 5–7 / 8–10 / 11–19 / 20
  - Wraith 1–6 / 7–10 / 11–14 / 15–18 / 19–20
- Signal Breaker 1–2 / 3–9 / 10–15 / 16–19 / 20
  - Noise 1–2 / 3–10 / 11–16 / 17–19 / 20
  - Nullwire 1–4 / 5–8 / 9–15 / 16–19 / 20

Enemies: one shape per operation:
- Facility (steady): 1–3 / 4–9 / 10–15 / 16–19 / 20
- Hive (swarm): 1–5 / 6–11 / 12–16 / 17–19 / 20
- Veil (precise middle): 1–3 / 4–8 / 9–15 / 16–19 / 20
- Signal Purge (heavy band 4): 1–4 / 5–8 / 9–12 / 13–19 / 20
- Mantle Hunt (swingy): 1–6 / 7–9 / 10–12 / 13–19 / 20

Role adjustments within each operation:
- Regular enemies: the shape as-is.
- Tanks and supports: move one face from each end into the middle bands.
- Elites: widen band 4 by one.
- Bosses: the operation's shape, top on 20 only.
- Only Phaseblade and Spine Stalker get a 19–20 top. Every other enemy tops
  out on 20 alone.
Classify each enemy's role from its kit, and if one is ambiguous, say which
role you gave it.

Also:
- Roll modifiers and printed faces must still work with the new ranges.
- Ability text, inspect, help and anything showing ranges must update from
  the data, with no hard-coded ranges.
- Gate: every unit has exactly five contiguous bands covering 1–20, and only
  Pyro, Wraith, Phaseblade and Spine Stalker have a top band wider than one
  face. Add a deliberate break."

**As built:** TRUTH, top entry ("2026-10-08 new roll windows"), with the hero
table and the full enemy table (unit, operation, role, ranges). Gates `roll
windows` and `roll windows live`. On branch `claude/cloak-and-windows`,
waiting for Kev's review. The baseline is not re-pinned.

**My readings, each Kev's to overturn:**

1. **OVERTURNED by G-55 (roles are by kit, not HP).** Roles are the game's own classifier, not a new list:
   `DataManager._classify_enemy_role`, which already sorts enemies into the
   encounter slots. `fodder` (a unit whose `ai` is `dumb`) is a regular
   enemy; `heavy` (90 HP or more) is a tank; `support` (two or more bands
   that aid an ally) is a support; anything else is an elite. The five units
   with a standing rule are the bosses.
2. **"One face from each end into the middle":** band 1 gives its last face
   to band 2, and band 4 gives its first face to band 3. The top band is the
   20 alone and has nothing to give, so the upper end is band 4.
3. **"Widen band 4 by one":** it starts one face lower; band 3 loses that
   face. The top band stays the 20.
4. **Phaseblade's part OVERTURNED by G-55 (its top is the 20 alone).** Phaseblade and Spine Stalker are elites by their kits, so band 4
   starts one face lower, then the 19–20 top takes the 19 from it:
   Phaseblade 1–3 / 4–8 / 9–14 / 15–18 / 19–20, Spine Stalker 1–5 / 6–11 /
   12–15 / 16–18 / 19–20. Band 4 ends up the same width as the shape's.
5. **Ambiguous roles, and what I gave them:**
   - **Cinder Raptor: elite.** 86 HP, under the 90 line. Its kit heals
     itself and taunts, so tank is the other reading (1–5 / 6–9 / 10–13 /
     14–19 / 20 instead of 1–6 / 7–9 / 10–11 / 12–19 / 20).
   - **Ash Channeler: tank.** 94 HP, but its kit is a damage dealer (the
     Synod's heaviest burn). Elite is the other reading.
   - **Caustic Spewer: tank.** 90 HP, exactly on the line; its kit is hijack
     and long burn.
   - **Oath Binder: tank.** 112 HP; its kit is roll penalties and Protocol
     drain, not protection.
   - **Volt Enforcer: elite.** One band shields all allies; the rest is burn.
   - **Resonance Warden, Stormweaver:** tank by HP and support by kit. The
     two roles give the same windows.
   - **Rust Drone, Static Skimmer, Prism Charger: regular.** They debuff or
     taunt, but they are the small units.
6. **Evolution names in the ruling** are read as: Pyro = Pyro Specialist, Arc
   = Arc Specialist, Bladecore = Blade Trooper, Glacier = Glacier Rig, Trench
   = Trench Rig, Medic = Combat Medic, Synth = Synth Medic, Overclocked =
   Overclock Engineer, Phantom = Phantom Engineer, Shadow = Shadow Operative,
   Noise = Noise Specialist.
7. **The tutorial's scripted Pulse Tech die moves from 4 to 6** (battle 2,
   round 1) so its Burn lesson still gets Arc Burst. Nothing else in the
   tutorial changed, and no throw was re-recorded.
8. **A band shift keeps one face in the band it takes from.** The old
   arithmetic left an empty or overlapping band once a band had two faces
   (Ravager 8–9 with Wide Aperture). Wide Aperture then gives Ravager one
   face, and the Splice Deal one.
9. **Band Compressor is unchanged**, so it does nothing for Pyro and Wraith
   (their top band is already 19–20). Say if it should reach 18 for them.
10. **`heroZones` is kept and gated**, not deleted: the schema requires it
    and nothing in the game reads it.
11. **Kits, not units, carry the ranges.** Obsidian Hound and Slag Hound
    share a kit and a role, so they share windows. The gate fails if a kit is
    ever shared by a unit with the wide top and one without.

## G-52. Cloak is an ambush (Kev, 2026-10-08)

**Ruling (Kev, transcribed from the task).** "Today cloak makes a unit
untargetable but attacking breaks it immediately, so it almost never lasts (4
of 7,037 cloaks survived a round in the audit sim) and cloak items are useless
on attackers. New rule:

- Cloak still makes the unit untargetable by single-target attacks, and
  attacking still breaks it.
- The unit's first attack out of cloak gets a large bonus. Start at double
  damage; tune it with the sim and report what you chose and why.
- Same rule for heroes and enemies. Enemy dice are face-up, so the player can
  see an enemy ambush coming.
- If every valid target of a single-target attack is cloaked, the attack hits
  one of them at random instead of fizzling. This removes the all-cloaked
  stalemate.
- Shield + cloak abilities stay as they are.
- UI: a cloaked unit shows that its ambush bonus is ready, using existing UI
  elements, kept minimal (the UI is being redesigned separately).
- Update keyword text, inspect lines and the primer. Copy short and plain, no
  em dashes."

This amends K1 (cloak = 2 clauses) and replaces "everyone cloaked -> the
ability fizzles". K1's "do not re-add pierce-from-cloak" stands: the ambush
does not pierce. #12 stands: friendly picks on cloaked allies are legal.

**As built:** TRUTH, top entry ("2026-10-08 cloak is an ambush"). Gate
`cloak ambush`. On branch `claude/cloak-and-windows`, waiting for Kev's review.

**The number: +50%, not double.** Matched batches, 1,500 runs each, same seeds
(`ambush_mult` = 1.0 is the new targeting rule with no bonus):

| | main | 1.0 | **1.5** | 2.0 | 2.5 |
|---|--:|--:|--:|--:|--:|
| Overall clear | 26.7% | 24.9% | **30.3%** | 32.5% | 35.7% |
| Facility | 37.5% | 36.5% | **42.2%** | 42.2% | 45.9% |
| Hive | 29.4% | 27.1% | **37.0%** | 39.6% | 45.2% |
| Veil | 23.3% | 21.5% | **25.0%** | 29.2% | 28.5% |
| Signal Purge | 27.2% | 25.8% | **29.8%** | 30.1% | 33.4% |
| Mantle Hunt | 16.7% | 13.8% | **18.0%** | 21.5% | 25.7% |
| Ghost Operative | 29.0% | 24.7% | **38.1%** | 44.3% | 52.4% |
| Best other hero (Splice Medic) | 36.4% | 31.5% | **38.8%** | 38.4% | 40.7% |
| Biggest single hit on a hero | 52 | 52 | **52** | 64 | 90 |

- With no bonus the random-hit rule alone costs the heroes 1.8 points (a fully
  cloaked squad is no longer safe from single-target attacks), and Ghost 4.3.
- At 2.0 Ghost gains 15.3 points and is the best hero by six; Hive moves 10.2
  (past the +-10 sign-off line of INVARIANTS #9); a cloaked enemy with Rampage
  hits for 64, more than any unevolved hero's HP.
- At 1.5 cloak pays (Ghost +9.1, from mid-pack to level with the best), no
  operation moves more than 7.6, and the biggest hit is unchanged.
- The sim's player never cloaks on purpose or puts a cloak item on its
  hardest hitter, so real play gets more from the bonus than the sim shows.
  That argues for the lower number too.
- +50% is also Mark's number, so the player learns one bonus, not two.

One constant (`CombatManager.AMBUSH_MULT`) and two data strings (keyword,
primer) change it; the log, the chip and the inspect line follow the constant.

**My readings, each Kev's to overturn:**

1. **"Attack" is an ability that deals damage** (`dmg` > 0): the test that has
   always broken a cloak. No ability in the data plants burn without damage.
2. **The bonus multiplies the ability's damage number.** Flat extras added
   after it are not multiplied: first-hit gear, Momentum, the vs-frozen bonus,
   execute's +8, burn. A chain jump is half of the ambush hit.
3. **An area attack from cloak pays the bonus on every target.**
4. **Only out of cloak:** a cloak torn off by an area hit pays nothing.
5. **An attack that also cloaks** (Ghost Step, Strike and Fade) spends the
   cloak it had and puts up a new one, which pays again. A Shadow Operative
   who rolls those two bands back to back ambushes every round. You named
   shield + cloak as unchanged; attack + cloak follows the same rule and was
   not changed either.
6. **Ambush Wiring's +5 is added after the bonus** (10 becomes 15, then 20).
   Its text, "attacks from cloak deal +5 damage", is still true.
7. **Rampage and ambush stack** (x2 and x1.5 = x3). Both chips are on the
   enemy before it acts. Only the Geode Panther can have both (it cloaks; the
   Mantle Tyrant grants Rampage); its highest such hit is Petrifying Shriek,
   18 x 3 = 54.
8. **The random hit is for single-target attacks only.** A lone mark, jam or
   taunt with every target cloaked still finds no target, as before. The
   attack's own riders land on the unit it hit.
9. **The unit that is hit at random keeps its cloak.** Only an area hit or
   its own attack breaks it.
10. **The enemy freeze rider** ("freeze lowest hero die") still skips cloaked
    heroes; it has its own pick and is not an attack.
11. **The chip is the cloak icon plus "+50%"**, replacing the icon-only cloak
    chip. No new element, no float text, no sound.
12. **A hero's random hit is not in the HP preview.** The preview leaves out a
    hero who has no chosen target, and there is none to choose.
13. **Enemy inspect: "TARGETING: RANDOM"** when its attack will hit a cloaked
    hero at random.

## G-51. Feedback polish: support motion, Firewall block, Accrete (Kev, 2026-10-08)

**Rulings (Kev, transcribed from the task).**

1. "Units using a buff or debuff ability don't move like attackers do. They
   should still make a motion, but a small wiggle or shake in place instead of
   the forward lunge. Applies to heroes and enemies, for any ability that
   buffs, debuffs, shields or heals without attacking. Reduced Motion: a
   smaller version. No animations: none."
2. "A Firewall silently cancels a taunt (and possibly other effects) with no
   feedback to the player. Treat it as a class: find every effect a Firewall
   can cancel. When it cancels one, show it: a brief chip on the affected unit
   and a battle log line. Copy short and plain, e.g. 'BLOCKED' and 'Firewall
   blocked Taunt.' Respect Reduced Motion and No animations (the chip still
   appears, without animation)."
3. "The operation 5 boss had Accrete and gained a seemingly random amount of
   shield, with nothing explaining it, and Accrete doesn't display correctly
   on the boss. Investigate the display bug and fix it. When Accrete triggers,
   show the shield gained as a number on the unit, plus a log line. The
   inspect text should explain how the amount is calculated, in one short
   line."

**As built:** TRUTH, top entry ("2026-10-08 feedback polish"). Gates
`action motion`, `firewall feedback`, `accrete display`.

**My readings, each Kev's to overturn:**

1. **Motion follows the ability, not the outcome.** An ability with `dmg`,
   `burn` or `detonate` attacks and lunges; everything else wiggles. An attack
   that also shields, heals or buffs lunges (attack wins). An attack a
   Firewall blocks still lunges. No ability in the data plants a burn with no
   damage; if one is authored it lunges.
2. **Reduced Motion: the lunge stays off.** G-13 removed it and this ruling
   only names the wiggle. So under Reduced Motion a supporter moves a little
   (5 px) and an attacker does not move at all. **OVERTURNED by Kev the same
   day, see the follow-up below: attackers get a small lunge.**
3. **The log line is lowercase and names the unit:** "Firewall blocked taunt
   on Scrap Drone." The example was "Firewall blocked Taunt."; the
   capitalization law keeps keywords lowercase inside a sentence, and with
   several units on the board the line needs to say whose Firewall it was.
4. **The BLOCKED chip replaces the X.** The X over the unit was the old
   Firewall cue; both together said the same thing twice. A shield absorbing a
   hit keeps its "X N" number.
5. **One block names every effect it cancelled:** "Firewall blocked damage,
   burn and jam on Strike Unit." One chip and one line per ability per unit,
   not one per effect.
6. **Accrete's number is a labelled chip, "ACCRETE +6",** not a bare "+6". The
   bare number is what the playtest saw and could not explain.
7. **The boss rule and the unit keyword are shown the same way** (chip, log
   line, inspect line), since the player meets both as "Accrete". The boss
   rule does not trigger the keyword's primer, whose line says "each of its
   turns".
8. **Beyond Accrete, two display fixes came with it** because they were the
   bug on the boss: the shield chip now follows the round beat by beat for
   every unit, and a rampage grant has an event so its chip lands when it is
   granted. Shield grants report the shield applied, not the amount asked for.
9. **Inspect line: "ACCRETE: always gains 6 shield at the start of every 2nd
   round."** "Always" is the answer to "how is the amount calculated": it is a
   fixed number. The boss's ACCRETION paragraph is unchanged below it.
   **REWORDED the same day, see the follow-up below.**
10. **The +6 still lands when the round resolves,** as THE COURT's Firewall
    does, not when the dice are thrown. Moving it would change what an item
    used during planning hits; that is a rules change and was not asked for.

**Follow-up rulings (Kev, 2026-10-08, transcribed).**

- "Icons: Self A, Summon A. Before committing, render the chosen Summon icon
  next to the heal chip at pip size and confirm they can't be confused. If
  they can, tell me and don't commit."
- "Reduced Motion: attackers get a small lunge, scaled down the same way the
  wiggle is (5 px vs 12). No animations stays fully still. Update the action
  motion gate."
- "Boss +6 timing: no rules change. Make sure the inspect wording matches the
  moment the player sees the +6 land. If 'start of every 2nd round' reads as a
  different moment, reword it, short and plain."

**As built:**

- **Icons.** `assets/ui/pips/self.png` is the figure under a marker arrow,
  `summon.png` the figure with a purple plus. Heal check: at 40 px and 20 px,
  colour and greyscale, heal is one large cross filling the pip and Summon is
  a figure with a small plus at its shoulder; they do not read as the same
  glyph (`docs/ui_reference/icon_options/heal_vs_summon_A.png`). My reading:
  "can't be confused" means on sight. A plus beside a person is also a common
  cue for healing a unit, so the meaning still has to be learned; the purple
  and the Summon primer carry that.
- **Reduced Motion lunge.** 11 px: 26 x 5 / 12, rounded. Same timing as the
  full lunge. No animations: no lunge, no wiggle. The `action motion` gate
  checks both; its `reduced_full` and `no_anim_ignored` breaks fail on the
  lunge as well as the wiggle.
- **Wording.** The +6 lands as the round resolves, ahead of the hero phase,
  which is after the player commits and before any hero acts. "At the start of
  every 2nd round" read as the dice throw, so both places that said it were
  reworded: the inspect line is **"ACCRETE: always gains 6 shield every 2nd
  round, before your heroes act."** and the ACCRETION rule text ends **"It
  accretes every 2nd round, before your heroes act; its shields persist and
  stack."** My reading: the rule text is part of the same inspect (and of the
  briefing), so leaving the old phrase there would have contradicted the new
  line. The keyword units' line is unchanged ("at the start of each of its
  turns" is when theirs lands: after the heroes, before the enemies act).
  **Not changed:** the Veil Overseer's THE COURT text says "at the start of
  every round" for a Firewall that is raised at the same moment. Same phrase,
  same timing, not part of this ruling. **Ruled next, see below.**

**Second follow-up (Kev, 2026-10-08, transcribed).** "Veil Overseer: reword its
Firewall rule text to match the Accrete fix: the moment the player actually
sees it happen, short and plain. Check every other boss and unit rule text for
the same 'at the start of every round' phrasing, and fix any that also mismatch
the moment it lands." And: "Help text: rewrite the Targets Self line without
nested parentheses."

- **Changed (1):** THE COURT, second sentence: "It raises that firewall on
  itself at the start of every round, for as long as any ally lives." is now
  "It raises that firewall on itself every round, before your heroes act, for
  as long as any ally lives." The Firewall goes up as the round resolves,
  ahead of the hero phase (`_apply_boss_round_start_rules`), the moment the
  ACCRETION +6 lands.
- **Checked, no mismatch, unchanged:**
  - ASSEMBLY LINE: "rebuilds one every 2nd enemy phase, counting from its
    first". It lands at the start of the enemy phase, as it says.
  - THE BROOD: "births one every 3 rounds". Names no moment; it lands in the
    enemy phase of rounds 3, 6 and so on.
  - ROOT ACCESS: "does this every round". Names no moment; the rewrite is set
    in the enemy phase and shows on the next roll.
  - Accrete keyword (definition, primer, inspect line): "at the start of each
    of its turns". It lands at the start of the enemy phase: after the heroes,
    before any enemy acts.
  - REGENERATIVE route modifier: "At the start of each enemy phase". It lands
    there.
  - Burn primer and status line ("at the end of each round", "each round"):
    the tick is at round end.
  - Tectonic Charge, Firewall Hack and the intercept choices name a round
    number, "once per turn" or a battle start, not a round start.
  My reading: only round-start wording was in question, so text that names no
  moment at all was left alone even where a moment could be added.
- **Targets Self** (Help > Keywords): "The figure under an arrow, or (self) in
  text, means the ability affects its caster."

## G-50. A lost display reloads and resumes by itself (Kev, 2026-10-08)

**Ruling (Kev, transcribed).** "App-switch freeze: build the fix. Add a reload
overlay in web/shell.html that detects the lost context, then reloads and
resumes automatically through the existing resume path, so the player lands
back in their battle with BATTLE RESUMED. Copy: short, plain, no em dashes."

This answers the open question in `docs/audits/APP_SWITCH_FREEZE_2026-10-06.md`
(a reload prompt, or reload and resume by itself): by itself.

**As built** (details: TRUTH, top entry):

- Copy: "DISPLAY LOST" / "Reloading to bring it back." With the RELOAD button:
  "DISPLAY LOST" / "Tap RELOAD to bring it back."
- The reload waits until the page is on screen. A loss in the background
  reloads when the player returns.
- The resume is CONTINUE's own code, not a second path, so it restores exactly
  what CONTINUE restores and writes the resume guard's marker.

**Readings of mine, Kev's to overturn:**

1. **No second automatic reload within 20 s.** If the display is lost again
   that soon after our own reload, the overlay offers a RELOAD button instead.
   Without it, a device that cannot hold a display would reload forever.
2. **No automatic resume while the resume guard's marker is set.** If the last
   resume never finished loading, the reloaded page shows the menu (CONTINUE,
   and RESUME EARLIER POINT when there is one) and waits for the player.
3. **The resume skips the title animation and goes straight to the screen.**
4. **Audio is suspended while the overlay is up** and comes back with the
   reload. After a reload the browser needs one tap before it plays sound
   again (its rule, not ours), so the resumed battle is silent until the first
   tap.

**Not verified on a phone.** Verified in desktop Chrome with a forced context
loss (`WEBGL_lose_context`), on a fresh export of this branch. Not verified:
that Android Chrome or iOS Safari loses the context on an app switch in the way
the audit predicts, that the event (or the on-return check) is seen there, the
behaviour inside the itch frame on a phone, and the overlay's look on a real
screen.

## G-49. Two settings: Auto-select sole valid target, No animations (Kev, 2026-10-06)

**Ruling (Kev, transcribed).** "Add both to the Settings screen using its current
styling. The UI redesign will restyle it later, so don't polish the visuals.

- AUTO-SELECT SOLE VALID TARGET (off by default): when an armed action has
  exactly one valid target, apply it automatically, with a short visible cue
  showing what was picked.
- NO ANIMATIONS (off by default): disables non-essential animations beyond what
  Reduced Motion already covers. Gameplay and dice results must stay fully
  readable. Report exactly what it turns off. Dice tumbling may count as
  essential, so if you're unsure how to handle the dice, propose an approach
  and wait before building that part.

Gates: each setting on and off, with a deliberate break for each."

**Auto-select, as implemented** (`scripts/battle/auto_pick.gd`, called from
`ProtocolActions._auto_pick_armed`). "Armed action" is read as the four actions
that arm and wait for a tap: Reroll, Nudge, Set and an item that needs a
target. A target is valid when the pick would go through: a hero die that can
be altered (not frozen, has a roll) and that the pool can pay for; with
Firewall Hack, an enemy die it may take; for an item, a unit it may legally
target. With exactly one, the pick is made through the same handler a tap
reaches, and a note in the combat zone reads "Only target: Strike Unit." (for
Set the note sits in the number picker: the die is picked, the number is still
the player's). With two or more, or none, nothing changes. Never in the
tutorial. **Hero abilities are not part of the setting:** a hero ability with
one legal target has always been assigned on its own, outside the tutorial,
and that stays on regardless.

**No animations, as implemented** (`PixelUI.no_animations_enabled`). It applies
everything Reduced Motion does, and also turns off:

- battle numbers: no rise, no size punch, no fade (shown 1.5 s, then removed)
- the card tint flash on a hit, heal or shield
- the hit pause and the slow-motion beat on a 20
- the Siphon / Hijack label drifting to its target (it appears on the target)
- the fade on the ability name shown for a 20
- the HP bar draining or growing (it lands on the new value)
- the ability pips fading in
- the pulse on the item confirm card and on the tutorial spotlight ring; the
  fade on the tutorial redirect ring
- the jam overlay flicker on a die
- the red fade on a refused loadout row (red, then back in one step)
- the title buttons fading in and the logo's exit fade

**Kept on purpose:** the pause between actions as a round resolves (0.10 s
before and 0.34 s after each), because that is what lets each result be read
in order; timed notes and banners, which appear and go without motion; audio
fades; the web loader's pulse (it runs before the game can read a setting).

**Sound is not motion (Kev, 2026-10-08).** Reduced Motion dropped the 20's
stinger sound and the music duck under it, and No animations inherited that.
Ruling: "Sound isn't motion. Restore the stinger under both settings and gate
it." Both settings now remove only the gold wash and the shake on a 20. Neither
setting may silence a sound.

**Dice: ruled (Kev, 2026-10-08): option A, the dice stay as they are.** With
the setting on the dice still throw, hop on a reroll, tip onto a changed face,
turn upright and slide to their slots, exactly as before, and the setting's
line keeps "Dice still roll." The two alternatives from the 2026-10-06 handoff
(dice placed already showing their roll; a hidden fast throw) are not built.
Do not re-propose them: G-24 and Dice rule 6 stand for this setting too.

Gates: `auto-select target` and `no animations` (each `scripts/checks/
break_gate.py` over its test: off and on, then deliberate breaks that must
fail it; `no animations` also checks the stinger under motion on, Reduced
Motion and No animations, with a break that silences it).

## G-48. Resume guard: a CONTINUE that hangs on load offers an earlier point (Kev, 2026-10-06)

**Ruling (Kev, transcribed).** "Problem: the save records the destination screen
before it loads. If that screen hangs on load, CONTINUE hangs every time and the
only way out is ABANDON RUN. Build the design already proposed:

- CONTINUE writes a marker to its own small file, user://resume_guard.json, with
  the save_seq, screen, battle number and round it resumed from. The run save
  format does not change.
- The marker clears once the run moves past that point (a run save with a
  different screen, a later battle, or a later checkpoint round).
- If the menu finds the marker still set, CONTINUE stays the main button and a
  second option appears: RESUME EARLIER POINT, with the line "The last resume
  didn't get past loading." It loads run.json.bak (the previous save the system
  already keeps) and says which point it restored. Nothing switches
  automatically.
- The state-code button keeps working throughout."

Gate (Kev): "a resume that hangs on load must produce the RESUME EARLIER POINT
option on the next launch, and a normal resume must not. Add a deliberate break
that fails."

**As implemented, and where the code had to differ from the proposal's
assumptions (each one is Kev's to overturn):**

1. **`run.json.bak` is not an earlier point, so the guard keeps its own copy,
   `run.json.prev`.** `.bak` is the previous WRITE, and every screen saves twice
   on entry (the routing save, then the screen's own), so once a screen has
   loaded `.bak` holds the same point as the save. `.prev` is the last save from
   the previous screen, copied when a save changes screen or battle. `.bak` and
   G-21's write-safety rules are unchanged.
2. **CONTINUE no longer re-saves the run before the screen loads.** The menu
   routed through `SceneManager.go_to_battle`, whose pre-load save replaced the
   end-of-round checkpoint with a fresh battle entry: through the real menu a
   mid-battle CONTINUE had never restored its round (it restarted at round 1 on
   the checkpoint's mid-battle run state). Same cause as the ruling's problem
   statement (the save written before the destination loads); the gates missed
   it because they called `resume_run` and changed scene directly.
   `SceneManager.resume_to` now lands on the saved screen without saving.
3. **The marker also clears when the resumed screen finishes loading with no
   error** (scene ready, no error logged since CONTINUE, still running 1 second
   later), as well as on the ruled progress rule. Without it, anyone who
   reloaded twice on one screen got the option with a false "didn't get past
   loading", and could use it to rewind at will: replay a battle already won, or
   re-throw dice already seen (Dice rule 9). Cost: a stall that begins after a
   clean load is not offered the option.
4. **RESUME EARLIER POINT is two taps.** It makes the earlier save the run save
   and rebuilds the menu, which says "Restored the rewards after battle 8."
   (or the start of a battle, the upgrade, the route choice, the intercept);
   CONTINUE then resumes it.
5. **A restored battle starts from its entry**, never from a round checkpoint,
   so a finished battle's last round can never come back.
6. **`battles_fought` stays exactly-once** (INVARIANTS #18): restoring a point
   before a battle the profile already counted does not count it again.
7. The marker carries `run_seed` as well, so a marker from another run is
   ignored, and it is cleared by writing an inactive marker (never by deleting
   the file): on web a deleted file can come back from IndexedDB.

Not offered when no earlier save exists (a hang on the run's first battle) or
when the earlier save is unusable: the menu is then unchanged. Details: TRUTH
"Resume guard". Gate: `resume guard`.

**Confirmed (Kev, 2026-10-08): keep all five deviations.** `.prev` instead of
`.bak` (1), the marker clearing on a clean load (3), two taps (4), back one
screen with a battle restarting from its entry (5), and no option when nothing
earlier exists. These are closed; do not reopen them.

**Point 2 was disputed and checked (2026-10-08).** Kev's playtests had resumed
at the round with BATTLE RESUMED. The round loss reproduces with real clicks on
the shipped itch builds (v0.1.1 of 2026-09-25, v0.2 of 2026-09-28) and on `main`
at `fc0607b`: the save holds a round-2 checkpoint before CONTINUE and none
after it, and the battle is back at its entry. It was not a test artifact, so
`SceneManager.resume_to` stays. Evidence and method:
`docs/audits/CONTINUE_ROUND_RESTORE_2026-10-08.md`.

## G-47. A reroll is a real hop in the die's own slot (Kev, 2026-10-05; replaces the reroll re-throw)

Ruling (Kev): "rerolls become a real in-place hop." Every reroll (hero
Reroll, the enemy reroll items, one die or all; abilities and items alike)
is a physical hop of the same die in its own slot: a real upward impulse with
spin, and physics decides the face. Neighbouring dice stay frozen and are never
touched or passed over. The die lands back in its slot; the landed face is the
roll (G-24), and the upright snap may correct tilt but never changes the top
face.

**Replaces** the reroll as a re-throw: item 5 of "Tutorial real throws and
Reroll follow-up" (Kev, 2026-09-27; "hero and enemy item rerolls are live
throws", implemented in `7d90891` / `e98fe2f`), G-33 (re-thrown dice collide
with resting dice; `ed19a68`) and G-45 (a re-thrown die never passes over
resting dice). G-24 itself stands. **Why:** re-throwing one die into a
crowded tray boxed it in behind a full row (about 1 re-throw in 6 on a six-die
board had no route to its slot that did not pass over a resting die), stacked
it on top of other dice, and let the snap change its face (a die balanced on
another die's edge).

As implemented: `DiceTray3D.reroll_die_to_result` reprints the die for its new
state in the frame the hop starts (G-27), locks its horizontal movement, makes
it all but frictionless for the hop (so it cannot hang on an edge) and
launches it up from a uniformly random orientation with a random spin (the hop is too short for spin alone to randomize the face: it landed on its own starting face 19% of the time instead of 5%); the static-obstacle colliders, the slide
planner and the lift are deleted. Gate `reroll hop` (1,000 rerolls: uniform
faces, no contact, never leaves its slot, the snap never changes the face;
each broken on purpose). Heretic Signal is not a reroll: it still re-throws
every unfrozen die through the full throw (G-37).

## G-46. No round limit; a stalled fight is exited by abandoning the run (Kev, 2026-10-05)

The 2026-10-02 design audit found fights no player action can end (a boss
repeating its non-damaging 1-4 face under freeze = repeat while the squad's
damage stays below its shield), and the game has no round limit. A round-40
backstop ("STANDOFF") was proposed and approved in principle on 2026-10-04,
then dropped. Ruling (Kev): "drop the round-40 standoff entirely. Players can
abandon the run from the menu if a fight stalls."

- **There is no round limit** on a live battle. Do not re-propose a round cap,
  a standoff/draw result, or an escalation timer as the answer to stalls.
- **A stalled fight is exited by abandoning the run** (quit to the menu; the
  run save is destroyed, `GameState` reset path).
- **The known lock is still live:** a Glacier Rig with the Deep Freeze directive
  can keep a boss frozen on its 1-4 self-shield face (10 of 583 such boss fights
  in the audit sims, 0 of 1,897 without that pairing). The candidate fix is the
  re-freeze rule (audit option C1: re-freezing does not add repeats, or a thawed
  unit cannot be re-frozen at once), **post-demo**. It amends Combat rule 7 /
  DECISIONS #1 ("re-freezing adds repeats"), so it needs its own ruling.
- The sim keeps its 500-round safety cap; a battle that reaches it is a
  stalemate and never a clear (`b44787b`).

## G-45. A re-thrown die never passes over resting dice (Kev, 2026-10-04; amends G-33)

**Superseded by G-47 (2026-10-05):** a reroll is now a hop in the die's own slot; there is no re-throw.

Playtest report: a re-thrown die "rolled but just stayed in the corner" with the
other five slots full. Investigation (2026-10-04): on a full board 15-20% of
re-throw landings end pinned between a wall and resting dice, where the slide
planner finds no floor route; the die then turns upright in place and is
lifted over the row, which the top-down camera shows as the die gliding across
the resting dice. Ruling (Kev): "The lift/glide over resting dice counts as a
G-33 violation: dice shouldn't visibly pass over other dice."

G-33's "lifted over a full row" fallback is therefore withdrawn. How a pinned
die reaches its slot instead is not yet ruled (proposals pending, Phase 1).
The stuck-in-the-corner report itself is not reproduced (1,520 re-throws on
six-die boards, seven phone sizes, 8x and real time: every die reached its
slot); open.

## G-44. Enemy own-side group targets read "(all allies)" (Kev, 2026-10-01; amends G-9)

Playtest report: "+1 roll (all enemies)" on an enemy's ability read as hitting
the heroes, when it buffs the enemy's own side. Ruling (Kev): "Approve (all
allies) on enemy abilities as a G-9 amendment. Update the gate."

G-9's group-target grammar named the side absolutely (`7 shield (all enemies)`
on an enemy). From now on an ENEMY ability's own-side group target reads
`(all allies)`, matching the single-target `(ally)` it already used. Hero
abilities are unchanged (`(all heroes)` / `(all enemies)`), and an enemy's
hostile group target still reads `(all heroes)`. 33 enemy eff strings changed
(roll buffs, ally shields, Mantle Tyrant's rampage grant).

As implemented: `scripts/checks/effect_text_target.py` requires `all allies` for
an enemy's `shieldAll`/`healAll`/`shieldAllyAll`/`erbAll`/`grantRampageAll`, and
now also checks rampage clauses, which it never parsed. That exposed one
pre-existing G-9 miss, Mantle Tyrant's recharge "1 rampage" without the
enemy-self `(self)`; it now reads "1 rampage (self)".

## G-43. Rewrite is applied after landing (Kev, 2026-10-01; amends Dice rule 5 for Rewrite)

Playtest report: under the Signal Hierophant's ROOT ACCESS the squad's highest
die was thrown printed with 3 on every face. Ruling (Kev, approving the
proposal "as written, including the plain-die reprint when there's no 3 face"):

- **Rewrite is no longer printed on the faces before the throw.** The die rolls
  naturally (its other known-before-roll modifiers still printed, Dice rule 5),
  lands, then visibly tips onto a face showing 3: the hijack pattern, a
  deliberate change after landing (Dice rule 6).
- **If no printed face shows 3** (for example a +3 buffed die printing 4-20), the
  die is reprinted as a plain 1-20 die in the frame the tip starts, like Set
  (G-25, G-27), and tips onto its 3.
- The dice rules still hold throughout: static faces while tumbling, a natural
  landing in the tray, and value displays (pip tag, inspect hit-area, top-face
  highlight) hidden from landing until the die rests on 3 (G-32), so nothing
  ever shows a value the unit can't act on once the rewrite applies.
- One keyword, both sides: this covers every Rewrite (the ROOT ACCESS rule, the
  enemy Synod rewrites and the hero rewrites on enemy dice). The engine is
  unchanged: the unit still acts on 3, and the sim and skip-visuals path are
  unaffected.

The Signal Hierophant's cloak stalemate is a separate design decision and is
not part of this ruling.

## Boss relic rework (Kev, 2026-09-27): G-34 to G-42

Transcribed from Kev's task brief ("Replace the five boss relics and add two
relics to the normal draft pool. All design decisions below are final.").
Implemented on branch `boss-relic-rework`; Kev tested it in Godot and approved
it, merged to `main` 2026-09-28. The rules below are the ruling; the "As
implemented" notes record how the engine reads it, including the points the
brief left open (flagged **open reading** so Kev can overrule them; the ones
Kev has since approved are marked **confirmed**, see G-42). TRUTH "Rewards /
Boss relics" carries the same rules.

### G-42. Boss relic tuning and confirmed readings (Kev, 2026-09-28)

Kev tested the branch in Godot and approved it, with two tuning changes:

- **Heretic Signal costs 3 Protocol** to use (still once per battle). The
  relic text and the confirm say so ("Spend 3 Protocol to re-throw every die?
  This can't be undone."). Amends G-37.
- **Tectonic Charge: +3 to hero rolls from round 2 (was +2), and while the
  heroes hold in round 1 each hero gains a shield.** The shield amount was
  tuned with the sim to land the relic at +2 to +5 clear rate versus no relic
  (value and numbers: `docs/BOSS_RELIC_TUNING_2026-09-28.md`, final section).
  The relic text and the hold banner say so. Amends G-38.

Kev approved four of the open readings (marked **confirmed** below):

1. Blood Frenzy freezes once per hero per round, and a kill on a repeat round
   adds another repeat (G-35).
2. A re-throw clears Nudge, Set and Firewall Hack with no refund (G-36, G-37).
3. Spillover Charge wraps from the last slot to the first, skips cloaked
   enemies and is blocked by a Firewall (G-40).
4. The unlock buckets: Spillover Charge in bucket 1, Overheal Relay in bucket
   14 (G-41).

Overheal Relay and Spillover Charge keep their names and numbers. The other
open readings (who counts as the killer, Sync Antenna on a re-throw, the
round-1 re-throw under Tectonic Charge, Overheal Relay's attacker-less damage)
were not raised and stay as implemented.

### G-34. Scrap Converter (Facility boss relic)

"When a hero die lands showing 1 or 2, gain 1 Protocol. 'Showing' means the
printed face, so a buffed die that can't show 1 or 2 never triggers it. Only
physical landings count (rolls and rerolls), not Set, Nudge or frozen repeats."

As implemented: `protocolOnLowLanding` (amount 1, maxFace 2),
`BattleEngine.landing_protocol`. Paid per die as the dice settle (two dice on
1 and 2 pay 2). The Heretic Signal re-throw is a landing and pays. A refresh
into a settled roll pays once (the pending-roll checkpoint holds the pre-roll
Protocol; a restored re-throw is not paid again).

### G-35. Blood Frenzy (Hive boss relic)

"When a hero kills an enemy, that hero's die freezes (keeps its value and
repeats next round, per the freeze rules)."

As implemented: `killFreezesKillerDie` (repeats 1). The die freezes on the value
the hero acted on (G-23) and follows every frozen-die rule. **Confirmed (G-42):**
once per hero per round (an AoE that kills two freezes once, not twice); a kill
on a repeat round adds a repeat, so a hero that keeps killing keeps repeating
(the freeze rules' "re-freezing adds repeats"). **Open readings:** only kills with a hero attacker
count (burn ticks, items, relic damage don't); summoned and rebuilt enemies
count (G-8); a Spillover Charge kill is the hero's kill.

### G-36. Firewall Hack (Veil boss relic)

"Once per turn, Nudge one enemy die down by 3 for the normal Nudge cost. Can't
go below 1. Can't target frozen or hijacked dice. The die moves to its new face
per the Dice rules, and that enemy's intent updates if its ability changes."

As implemented: `enemyNudgeOncePerTurn` (amount 3). The Nudge action accepts an
enemy die once per turn (arm Nudge, tap the enemy die). Cost is a flat 1
Protocol (Priming Charge's free hero Nudge doesn't apply to it). The -3 lives in
`BattleState.enemy_roll_nudges` for the round. **Confirmed (G-42):** a Heretic
Signal re-throw clears it without a refund, like a Reroll clears a Nudge.

### G-37. Heretic Signal (Signal Purge boss relic)

"Once per battle, re-throw every die on the board, heroes and enemies.
Activated by tapping the relic in the relic/items menu, then confirming
('Re-throw every die? This can't be undone.'). Planning phase only. Frozen dice
are skipped. Everything else follows the Dice rules, and the battle checkpoint
updates so a refresh restores the new dice."

**Amended by G-42: costs 3 Protocol** (`cost: 3` on the effect).

As implemented: `rethrowAllOncePerBattle`. The re-throw is the normal full
throw (frozen dice stay put as blockers). The checkpoint after it holds the new
dice, the pending actions and `heretic_signal_used`. The cost is paid when the
re-throw lands; with less than 3 Protocol the relic row says NEEDS 3 PROTOCOL.
**Confirmed (G-42):** a re-thrown die is a fresh roll, so its Nudge, Set or
Firewall Hack is cleared without a refund (the Reroll rule). **Open readings:**
Sync Antenna does not fire again; in
Tectonic Charge's round 1 only the enemy dice are on the board, so only they
are re-thrown.

### G-38. Tectonic Charge (Mantle Hunt boss relic)

"In round 1 of each battle, heroes don't act (their dice don't roll; items stay
usable; show clearly that heroes are holding). From round 2 on, all hero rolls
get +2, printed on the faces."

**Amended by G-42: +3 from round 2, and a round-1 shield on every hero while
they hold** (`amount: 3`, `shield` on the effect; an ordinary one-round shield,
granted to each living hero as round 1 resolves).

As implemented: `heroesHoldRoundOne` (originally amount 2). Round 1 throws only
enemy dice; the screen shows YOUR HEROES HOLD THIS ROUND over the hero readouts
until the round resolves, with a second line naming the shield and the roll
bonus, and the log says so. As round 1 resolves each living hero gains the
shield (it covers that round's enemy phase and is gone at the round-end tick).
When round 1 ends every hero (a fallen one too, for a later revive) gains a
permanent +3 roll buff, so the faces print it and the roll chip shows +3. Reroll, Set and hero Nudge have no die to act on
in round 1 (they say "Your heroes hold this round."). A refresh in round 1
restores the enemy-only roll.

### G-39. Overheal Relay (draft relic; name kept, G-42)

"Healing beyond max HP deals that much damage to a random enemy."

As implemented: `overhealDamage`, unlock bucket 14. Any heal on a hero counts
(abilities, items, relics, gear, lifesteal); the random pick is seeded
(INVARIANTS #1). **Open reading:** the damage has no attacker, so it doesn't
consume a Mark, doesn't spill, and its kill is nobody's kill.

### G-40. Spillover Charge (draft relic; name kept, G-42)

"Overkill damage carries to the next enemy in slot order."

As implemented: `overkillSpillover`, unlock bucket 1. **Confirmed (G-42):** the
next enemy is the next living, uncloaked one after the dead one's slot, wrapping
from the last to the first; a Firewall blocks the spill. **Open readings:** only
a hero attack's overkill spills (burn ticks, items and relic damage don't); the
spill is still the hero's hit (shields absorb it, a Mark amplifies it, its kill
is the hero's kill and can spill again).

### G-41. Removals, save migration and relic counts

"Remove the five old boss relics (Salvage Rig, Chitin Graft, Resonant Chorus,
Root Access, Mantle Core) and any code only they used. The Signal Hierophant's
standing rule keeps the name ROOT ACCESS." "SAVES: anyone who unlocked an old
boss relic gets the new one for the same operation. Nothing is lost."

As implemented: the five relics and their effect handlers are gone
(`protocolOnShieldBreak`, `heroHealOnOwnKill`, `turn1RollFloor`,
`setCostZeroOncePerBattle`, the relic half of `shieldsPersist`). The MANTLE
TYRANT keeps `shields_persist`, now its alone, so it remains the single named
exception to one-round shields (#2). `SaveManager.LEGACY_BOSS_RELIC_IDS` maps
Salvage Rig → Scrap Converter, Chitin Graft → Blood Frenzy, Resonant Chorus →
Firewall Hack, Root Access → Heretic Signal, Mantle Core → Tectonic Charge. The
profile's unlocked list migrates on load and is saved back under the new ids;
a run in progress keeps its held relic and Starting Directive as the new id.
The run save's shape did not change, so `RUN_SAVE_VERSION` stays 3 (the
`save schema` gate confirms the fingerprint). Relics: 36 = 31 draftable + 5
boss (was 34 = 29 + 5). **Confirmed (G-42):** bucket placement of the two draft
relics (Spillover Charge in bucket 1, Overheal Relay in bucket 14), which was
not in the brief. All seven relics use placeholder art (the retired relics' icons and
two unused relic icons) and need new art.

## G-33. Re-thrown dice collide with resting dice (Kev, 2026-09-27)

**Superseded by G-47 (2026-10-05):** a reroll is now a hop in the die's own slot; there is no re-throw.

A re-thrown die collides with the dice resting in the tray, which act as
immovable obstacles and never move or change face.

This covers every single-die re-throw (hero Reroll, the enemy reroll items)
and the Set / reprint tumbles. The moving die bounces off the resting dice;
the resting dice never move, get pushed or change face (Dice rules 8), and
the re-thrown die never ends up overlapping another die, its slide into its
slot included.

Why: settled dice had their collision switched off, so a rerolled die could
roll straight through or under the dice already resting in the tray (UI batch
2026-09-27, B10). See TRUTH "Dice rules", rule 10.

## UI batch 2026-09-27 (Kev) — event header art keeps its own aspect (B4)

Every event header image keeps its own aspect ratio; the frame is fitted to the
image, with no crop and no letterbox. There is no single fixed aspect across
event screens. Intercept and run-end art already did this
(`PixelUI.make_scene_banner`). Route Fork was the only screen that broke it:
its 16:9 hallway art sat pillarboxed in a 420 px frame. Its frame is now full
width at the art's own aspect and grows upward into the empty space above the
window, so the route cards don't move. ("Split photos" in Kev's original
report meant Route Fork.) **Supersedes** the brief's "one fixed aspect for all
event header art" and the 2026-07-10 KEEP_ASPECT 420 px Route Fork banner.

## UI batch 2026-09-27 (Kev) — encounter select fixed slots (B3)

Transcribed from Kev's UI batch brief (`docs/batches/2026-09-27-ui-batch.md`).
The encounter panel has fixed slots. Locked encounters show the unlock
condition in the subtitle slot (e.g. "Clear Hive Incursion to unlock"), and the
LOCKED status line stays. The detail box is always present at a fixed height and
shows encounter info only (story text and THREATS); locked encounters show the
lock info and "THREATS: ???". Unit info (name and blurb) moves to long-press on
the unit tile; tapping a unit only toggles it in the squad. Switching between any
encounters, locked or not, moves nothing. **Supersedes** G-16's "detail-panel
footprint ... transparent when empty" on locked encounters and the hero dossier
in the squad-select detail panel.

## G-31. Dice stay in the visible tray (Kev, 2026-09-27)

Every die stays inside the visible dice tray for its whole motion and bounces
off the tray walls; every landing happens in view. This applies to every path
that moves a die, including recorded tutorial playback.

Recorded throws are made inside the real battle tray at its real layout
(1080×2400) with its walls, and stored relative to the tray (normalised to
its bounds). Playback maps them onto the live tray, whose size depends on the
screen. A recording in which any die leaves the tray, or lands out of view,
after mapping is discarded. If no recorded variant fits, the dice are thrown
live. Settled result slots are clamped to the live walls.

Why: the first recordings were made headless, where the window is 64×64 and
the tray laid out 2400 px wide, so the scripted dice flew out of the phone's
view and snapped back in. See TRUTH "Dice rules", rule 3.

## G-32. Value displays hide while a die moves (Kev, 2026-09-27)

Anything that shows a die's value or its ability (pips, readouts, value tags,
the inspect hit-area, the top-face highlight) is hidden while the die is
moving. It appears with the new value after the die settles. This applies to
every path where a die moves after the initial roll: hero and enemy-item
rerolls, Set, reprints, Nudge tip-overs, hijack updates and item changes.

Why: on Reroll the previous roll's pips rode along with the tumbling die and
only updated after it settled. See TRUTH "Dice rules", rule 7.

## Tutorial real throws and Reroll follow-up (Kev, 2026-09-27) — IMPLEMENTED AND VERIFIED

Kev approved the Godot-reviewed dice branch through d5c25e1, except tutorial
motion, for fast-forward into main. That fast-forward is complete. Follow-up
work is on `codex/tutorial-real-rolls`; do not merge or web-export it, and do
not re-pin the balance baseline.

1. Script only battle 1 rounds 1–2 and battle 2 round 1. All later tutorial
   rolls are free live physics throws, on both sides.
2. Delete the post-landing tutorial dictionary override. Scripted throws must
   land with their requested value already printed, using recorded live throws;
   free throws use no rig. Landed values follow the normal result path.
3. G-14 stands: measure without HP/damage clamps. Simulate at least 1,000 runs
   per battle; report loss rate, soft-locks, median/max victory rounds. Above
   1% loss or any soft-lock: STOP and propose a tutorial-only SCRAP ability
   table change. At or below 1%, retain the retry prompt.
4. YOUR PLAN's Burn reminder appears only while a burned enemy is alive and
   burning. Reroll copy says there is enough Protocol, without an exact count.
   Plain friendly copy, no em dashes or internal band names; list all changes.
5. *(Re-throw superseded by G-47, 2026-10-05: a reroll is a hop in its own slot.)*
   Reroll follows G-24 everywhere: hero and enemy item rerolls are live throws;
   the landed face determines the result, with static preprinted modifiers and
   normal same-face upright snap. Frozen dice refuse reroll. Update the pending
   battle checkpoint after settling. This supersedes the earlier "Reroll keeps
   its animation" note. Extend dice-face and checkpoint gates accordingly.
6. Replace G-26's generated tumble with recordings made using live launch/tray
   settings, one transform per physics frame through settle. Choose among
   multiple recordings per slot. Orient the visual mesh before launch so the
   requested value lands up; never relabel in flight. Apply the normal upright
   snap afterward. Gate scripted top values, static labels and measured live
   travel/time bounds; deliberately break the first two checks.

Commit numbered steps separately. Finish with an updated handoff and push.
The approved schedule, landed-value path, outcome measurement, conditional copy,
physical rerolls and recorded tutorial playback are implemented on the work branch.
Full gate, pinned 300-run comparison, physics probe and both deliberate-failure
checks pass. See [verification](TUTORIAL_REAL_ROLLS_2026-09-27.md). Kev's Godot
visual review remains; this follow-up is not merged or web-exported.

**G-24–G-30 implementation (2026-09-26):** steps 1–9 are implemented on
`dice-face-snap-p0`. The replacement dice contract covers all eight acceptance
criteria, including unchanged-value Set reprints and frozen-die immobility
between rolls. Full verification and balance evidence are recorded in the
branch handoff; no baseline re-pin or merge is implied.

## G-27. Reprint on deliberate change (Kev, 2026-09-26)

Extends G-25 to every case. When a deliberate after-landing change needs a value
that no printed face shows (Nudge past a jam cap, a hijack copy outside the
printed range, Deep Freeze Charge on a buffed die, any change to an all-3 or
all-20 die), the die is reprinted for its new state and does a short tumble onto
the face showing the new value. The reprint happens in the same frame the tumble
starts; labels are static from then on. The top face must always show the value
the unit acts on.

## G-28. Upright snap definition (Kev, 2026-09-26)

After settling: same top face, flattening tilt under 90°, and any yaw spin
needed to make the numeral upright (up to 180°). This replaces the "rotates less
than 90°" wording wherever it appears.

## G-29. Rewrite marker is static (Kev, 2026-09-26)

The REWRITE marker above a die no longer cycles digits: it shows a static
`REWRITE->N` tag.

## G-30. Hijack × freeze: the hijack waits (Kev, 2026-09-26)

While a hijacking enemy die is frozen, it keeps its number (G-23) and the hijack
stays pending — the round-end tick must not clear it. When the freeze ends, the
hijack resumes copying the heroes' highest die. This corrects the earlier wording
that frozen dice are "immune to Hijack": the hijack does not bounce off, it waits.
Jam and Rewrite are unchanged (they still bounce off a frozen die).

## G-25. Set overrides modifiers (Kev, 2026-09-26)

The player can Set any value 1–20 and the unit acts on exactly that value,
ignoring pre-roll buffs, penalties and jam caps. (The engine already resolves it
this way: `BattleEngine.effective_hero_roll` returns the Set value absolutely.)
Presentation under G-24: Setting clears the die's printed modifier labels. It
becomes a plain 1–20 die and does a short tumble onto the chosen face, with
static labels throughout, then the normal upright snap. This resolves the "Set
to a value no face prints" case of the G-24 step-6 blocker.

## G-26. Tutorial dice use recorded real throws (Kev, updated 2026-09-27)

Only battle 1 rounds 1–2 and battle 2 round 1 are scripted. Their movement is
recorded from live physics throws, with identical launch parameters and tray
setup, sampled each physics frame through settle. Four variants per slot are
stored under `data/tutorial_throws/`; a throw shares its selected variant across
slots, preserving the recorded inter-die trajectories and impact timing.

Before playback, the visual mesh is oriented so the recording's upper face
carries the requested number. Labels never change in flight. The actual visible
top supplies the result through the normal landed-value path. The normal upright
snap follows, keeping that top face. Later tutorial rounds use unrigged live
physics. The post-landing tutorial result override is deleted.

This supersedes the 2026-09-26 short generated tumble. The recorder is
`scripts/debug/record_tutorial_throws.gd`; regenerate when live physics settings
change. Recordings are tray-relative and mapped onto the live tray (G-31). `tutorial_throw_gate.gd` checks values, labels, live travel/time bounds,
actual tutorial tray bounds and free landing integrity. Its first two checks
have deliberate-failure proof in `scripts/checks/tutorial_throw_mutations.py`.

## G-24. Dice are real dice; the landed face is the roll (Kev, 2026-09-26)

"Dice look and behave like real dice. Faces are static; numbers never
change or flash while a die tumbles. The face that physically lands up
is the roll. After a die settles, it rotates into place so its top face
reads right-side up to the player; this is the only automatic motion
after landing. A die only moves to a different face when the player or
an ability deliberately changes it (Nudge, Set, reroll, hijack), and that
is shown as the die tipping over onto the new face."

What this settles:
- **Physics is authoritative for live rolls again**, as before 1171eb8: the
  natural each die lands on is its raw roll, and the engine computes the
  effective value from it exactly as before. The balance sim and the
  skip-visuals path still draw from the seeded stream (a uniform d20 either
  way). INVARIANTS #1 is reworded accordingly; the "physics is presentation"
  framing is retired.
- **Supersedes** the 2026-09-21 follow-up "the saved battle RNG is AUTHORITATIVE
  for dice faces and physics only visually resolves to them", and items 3–5 of
  the Dice face entry below (Option C: scrambling digits, relabelling on
  landing, no upright snap). Items 1, 2, 6 and 7 of that entry, and G-23, stand.
- **Refresh still cannot reroll a roll the player has seen.** As soon as all
  dice settle, the landed raw values are written into the battle checkpoint as
  a pending roll; CONTINUE places the dice showing them without rolling. A
  refresh before the dice settle throws again (nothing was shown).
- **Modifiers known before the roll are printed on the faces before the throw**
  (each face shows its effective value), so the face that lands up already
  reads the value the unit acts on.

## Dice face: one value source + Option C presentation (Kev, 2026-09-26) — PARTLY SUPERSEDED by G-24

> Items 3–5 (Option C presentation) are superseded by G-24 above. The rest stands.

From the P0 dice-face audit (`docs/audits/DICE_FACE_AUDIT.md`). Rulings:
1. **One source of truth for die values.** The tray keeps no copy of the
   effective-roll rule; every die reads the value the unit will act on from game
   logic. Invariant: whenever a die's value is readable it is the value the unit
   acts on, and never a value the unit can't have.
2. **Every roll modifier is classified** as KNOWN BEFORE ROLL (applied before the
   throw; the die lands on it) or APPLIED AFTER LANDING (the die locks, then
   changes). Sync Antenna is after-landing (it reacts to a matching pair).
3. **Option C with scrambling digits.** Keep the seeded draw before the roll
   (checkpoints depend on it) and the real physics throw. Numerals scramble
   (stepped pixel digits) while tumbling; on settle the value is placed on the
   landed face by turning only the visual mesh, unseen mid-scramble, then the
   digits lock. The placed value is the effective value with every pre-roll
   modifier, clamped 1–20 (a +3 die never shows 1–3; a forced 20 lands as 20).
4. **No final spin.** Of the three placements, the numeral closest to screen-up;
   a settled die does not rotate again. (As implemented it still slides, without
   rotating, to its result slot under its unit.)
5. **After-landing changes scramble-and-lock** on the die (~0.26 s): Nudge, Set,
   after-landing relics/abilities, forced values. The earlier "Reroll keeps its
   animation" note is superseded by the 2026-09-27 real-throw ruling above.
   No single-frame jumps.
6. **Hijack shows live** from landing and follows the heroes' highest die until
   resolution; its readout follows the die. Frozen behaviour unchanged.
7. **The tutorial uses the same path.**
Hard gate: `dice face` (`scripts/debug/dice_face_gate.gd`).

## NK-17 conditional alternative: `else` + Medic 20-band fallback (Kev, 2026-09-25) — RESOLVED & IMPLEMENTED

**Grammar.** NK-17 gains a *conditional-alternative* clause: `else N effect
(scope)`, comma-joined like every clause, legal only directly after a revive
clause, and firing only when the preceding clause has nothing to act on (no
hero down). `revive 50% HP, else 20 heal (hero)`. It is one token, reads
naturally, and keeps the comma split intact. `effect_text_target.py` counts an
`else` heal as its own kind (a plain heal can never stand in for it), requires
the amount to equal `fallbackHeal`, and rejects `else` anywhere but after a revive.

**Distinct from the conditional-BONUS ruling (Kev 2026-07-12).** That ruling adds
MORE to an effect that always fires (`10 +5❄` — base + bonus + condition icon on
one pip). `else` REPLACES an effect that cannot fire with a different one. They
are not interchangeable: never write a fallback as a bonus, or a bonus as an else.

**Abilities.** Resuscitate: revive a fallen hero at 50% HP (was 70%), else 20
heal (hero). Mass Revival: revive all fallen heroes at 30% HP, else 12 heal (all
heroes) — 12, not 20, so it is a clear step up from Nanite Crossfire's 6 (all)
without the fallback outshining the revive. Data: `fallbackHeal`, `fallbackHealAll`.

**Resolved at fire time, not pick time.** An ally can fall between the pick and
the cast; the ability does the more useful thing when it fires (anyone down →
revive, else heal). Lock-in at pick time would recreate the dead roll. Targeting
offers a living pick only when the fallback will fire.

**Board-aware pips.** The battle readout shows what this roll does NOW: the
revive pip when someone is down, the heal pip when nobody is. No second pip or
condition icon (keyword density is already a known problem). Inspect has no
squad state: it shows the revive pip at the resolved percentage and the eff text
carries the `else` clause.

**Directives override the revive percentage only.** Field Surgeon (Resuscitate
→ 100%) and Resuscitation Loop (Mass Revival → 50%) leave the fallback heal
unchanged — a directive that removed the fallback would reintroduce the dead
roll for the players who invested in it. Field Surgeon stays at 100%: its end
state is strictly better than today; its gain grows from +30 to +50 points of
max HP, **flagged for the next sim run**.

**Display honesty fix (same change).** Revive pips used to show raw `revivePct`,
ignoring the directive and the reviveNoPenalty relic (Field Surgeon showed 70
while reviving at 100). `ReviveResolution.resolved_pct` is now the one source for
the engine, the readout and inspect.

**Balance:** revive 70→50 plus the new fallback — not measured alone; **flagged
for the next sim run** together with Field Surgeon.

## Experimental battle landscape Stage B2 (Kev, 2026-09-23) — APPROVED

Stage B typography approved. Updated request (2026-09-25): rearrange the same
CompactUnitCard as a horizontal plate with an aspect-preserving portrait and a
separate information/status column; compare horizontal and vertical HP bars.
Hero readouts dock left of dice, enemy readouts right, vertically centered.
Cap and center Protocol with substantially larger grouped action buttons.
Enlarge landscape dice/numerals/readouts about
1.6–2×, reduce the gap between dice columns, center/clear the Protocol label,
contain status overflow, and consolidate landscape sizing in one style table.
Capture squad select, rewards, loadout, help and run end at 960×600 and 1280×720;
report cramped presentation without changing those screens. Keep portrait,
global viewport/settings, shared behavior and the default-false flag unchanged.
Stop with screenshots for review. Original dirty checkout remains untouched.

## Experimental battle landscape Stage B (Kev, 2026-09-23) — APPROVED

Proceed from Checkpoint 2 to landscape-specific typography, status/badge sizing,
spacing and polish. Keep shared behavior, portrait presentation, non-battle
presentation and global viewport/stretch settings unchanged. The player feature
flag stays false; the original checkout's unrelated 640×960 edit remains untouched.
Do not repair the pre-existing Nudge input issue or unrelated baseline failures.

## Experimental battle landscape Stage A (Kev, 2026-09-22) — APPROVED

Use the committed portrait configuration as the regression baseline. Do not touch
the separate working tree's uncommitted viewport change. Keep current non-battle
presentation and all global viewport/stretch settings unchanged. Reuse one battle
scene, shared components, bindings and behavior; only layout/sizing varies.
Landscape remains behind a default-false feature flag, with a debug-only session
override. AUTO tutorials stay portrait; explicit FORCE LANDSCAPE may test them.
The existing 47 passes / 6 failures are the baseline: do not repair unrelated
failures. Stop at Checkpoint 2 with portrait comparisons and both desktop captures,
before Stage B typography/badge polish. This scoped experiment is an explicit
exception to INVARIANTS #11's earlier prohibition on an orientation option.

## Web demo QoL: branded loader + end-of-round battle checkpoints (Kev, 2026-09-21) — RESOLVED & IMPLEMENTED

**Ruling (transcribed from Kev's request).** Two focused web-demo improvements,
no unrelated gameplay / UI / balance / layout changes:

1. Replace the generic Godot web loading presentation with a branded Overload
   Protocol loader: near-black, cyan accent, centered branding, the game's own O
   symbol pulsing (lightweight CSS), `INITIALIZING OPERATION...`, a progress bar
   only if the loader exposes reliable progress (never a fake percentage),
   `First launch may take a moment.` Visible immediately, no white flash, scales
   with the iframe, disappears cleanly; the "use whatever viewport the browser /
   itch iframe provides" behavior is preserved (no fixed portrait wrapper).
2. End-of-round battle checkpoints. An active battle is checkpointed ONCE per
   completed round, at the stable ready-to-roll boundary (after every action,
   damage, death, status tick, summon/revive and end-of-round cleanup; before
   the next Roll). Never mid-interaction (dice physics, selection, targeting,
   animation, enemy actions, Nudge/Reroll/Set). CONTINUE restores that state
   exactly, without replaying completed actions or duplicating consumables,
   rewards, XP, kills or relic triggers. **Refreshing must not reroll the upcoming
   dice** — the deterministic RNG state is checkpointed. Extend the existing
   run save with an optional `battle_checkpoint`; old saves keep loading. A
   close before the first completed round may restart the battle (as before).
   A finished battle clears its checkpoint. Exact mid-action recovery is out of
   scope.

**Supersedes in part G-21** ("Nothing mid-battle is serialized", "Live d20 FACES
are read off the settled physics tray and are NOT restorable", and "mid-battle
state serialization" under out-of-scope). Node-boundary checkpoints, the
battle-entry checkpoint and every other G-21 rule stand.

**As implemented (superseded by G-24, 2026-09-26).** Live d20 faces were drawn
from the battle's seeded d20 stream and rigged onto the physics tray, so the next
round's dice were saveable state. G-24 returns live faces to the physics landing
and keeps refreshes honest with a pending-roll checkpoint instead. `RUN_SAVE_VERSION`
1 → 2; v1 run saves are read forward (a strict subset: no block = no
checkpoint), not discarded. Details: TRUTH.md §Active-run save.

**Follow-up ruling (Kev, 2026-09-21, final QoL pass):** the saved battle RNG is
AUTHORITATIVE for dice faces (confirmed). *(Superseded 2026-09-26 by G-24: the
face the die physically lands on is the roll.)* 64-bit seeds are stored as strings (run save v3). **No backward
compatibility:** run saves older than v3 are discarded cleanly (the one-line
"older build" notice), not migrated — superseding the read-forward above.
CONTINUE into a restored checkpoint shows a brief `BATTLE RESUMED - ROUND X`;
no per-round SAVED message. Checkpoint frequency stays at the ready-to-roll
boundary; an item used after the last checkpoint may be undone by a refresh
(accepted). Tutorial/Help interaction wording is platform-neutral (Select /
Hold / Hold to inspect).

## UI consistency polish (Kev, 2026-09-20) — RESOLVED & IMPLEMENTED

Keep current battle portrait zoom and dimensions; correct friendly framing and
Scrap/Rust vertical alignment only. Merge Help into Protocol, Units, Battle Log,
Settings; retain Icon Guide within Protocol and enemy operation filters within
Units. Increase codex descriptor legibility and normalize thumbnails/HP alignment.
Add restrained pixel HUD default/hover cursors, Help hover/scroll/Escape polish,
capture before/after evidence, then bump the version. Implemented in demo4;
see `UI_CONSISTENCY_2026-09-20.md`. No combat or broader HUD redesign.

Companion to `docs/TRUTH.md` §DECISIONS NEEDED. Entries land here once Kev rules;
numbers are preserved from the TRUTH.md list so old references stay valid.
**Do not re-open a ruled item without a new explicit ruling from Kev.** Purpose:
future agents execute rulings — they do not relitigate them, and they do not
carry rulings in chat memory.

**How to read status:**
- **RESOLVED & IMPLEMENTED** — ruling landed in code+docs; done.
- **RULED — IMPLEMENTATION PENDING** — Kev has adjudicated it (2026-07 decision
  review). Where the entry says *ruling text awaiting transcription*, the ruling
  exists only in Kev's adjudication list: **step 0 of the implementing session is
  to paste the ruling text into the entry, then implement against the written
  ruling.** Implementing a pending item from a chat log or from memory — without
  the ruling written here first — is a process violation. This is the insurance
  against a session misreading an answer: the ruling lives in the repo.

---

# RESOLVED & IMPLEMENTED

## G-23. Freeze locks the number on the face (Kev, 2026-09-26)

A frozen die keeps exactly the value it SHOWED when it froze — its effective
value, including every roll modifier active at that moment — and nothing changes
it while it stays frozen, including modifiers applied or removed in later rounds.
This refines #1 (freeze = repeat): "keeps its face" means the number on the face,
not the raw natural under it. Before this ruling the capture was the raw face
(`last_die_value`), so a +3 die showing 20 repeated on 17 — a different band,
contradicting #1's "same zone, same ability".

As implemented: freeze captures the effective value (`BattleEngine.item_freeze_die`
for items; `CombatManager._freeze_die_state` from `stamp_acted_values`, the values
the round acts on, for abilities and riders). A frozen die returns its locked
value from the moment it freezes (`BattleEngine._is_locked_by_freeze`), so a
frozen die never moves or changes face while frozen. Deep Freeze Charge still pins to 1 (G-9): it
sets the value to 1 and freezes it, and the die now shows 1 from that moment.
Hard gate: `dice face` criterion (d).

Also decided with this ruling: dice keep sliding to their slot after landing.
(The same day's approval of "after-landing changes scramble all faces" fell with
Option C — see G-24.)

## G-22. Version stamp renders at the 48 px text floor (Kev, 2026-09-26)

Kev accepted the text legibility Step 1 web build (branch
`text-legibility-step1`, 3443759). The version stamp (main-menu corner and Help
footer, `PixelUI.version_label()`) renders at `PixelUI.TEXT_MIN_PX` = 48 like all
other text. This **supersedes the 2026-07-24 ruling** that sized the stamp below
the text floor (nominal 24 → rendered 32); that ruling was only ever recorded in
code comments (`main_menu.gd`, `help_menu.gd`), which now point here.

## G-21. Desktop fit and tutorial recovery (Kev, 2026-09-20)

Kev approved completing and testing the existing Reddit-feedback fixes: offer help
for stalled gated tutorial actions, preserve the real lesson action instead of
skipping it, and keep THE OPERATION as the opening beat with the existing 0.22 dim.
Desktop redesign and balance changes are outside this pass. Assistance leaves
inspection open for the player to read; an impossible action offers an explicit
restart rather than advancing into invalid instructions.

**Web viewport (Kev, 2026-09-20, supersedes the same-day letterbox):** no custom
portrait-width restriction. The Web build uses whatever viewport the browser or
itch iframe supplies (Adaptive canvas, `canvas_items` + `expand` kept); no
desktop max-width, breakpoint or fixed width in code. Kev controls the desktop
presentation through itch.io's Embed Options. Mobile-sized viewports must keep
working. Per-screen responsive redesign is a separate, later decision.

Implementation and test evidence: [desktop verification](DESKTOP_TUTORIAL_2026-09-20.md).

## 1. Freeze semantics — FREEZE = REPEAT *(ruled by Kev, 2026-07-06; landed 52e2fa5)*

**Ruling.** Freeze = repeat is the original design intent, restored. Identical for
both sides: a frozen die crusts, stays static in the tray as a hard physics
blocker other dice bounce off, and on the next roll does NOT reroll. It keeps the
same face, and its unit **acts again on that same result — same zone, same
ability**. Targeting is re-picked fresh on each repeat (manual pick for heroes,
personality choke-point for enemies); only the die result is locked. After its
authored N repeats the die thaws and rerolls normally. Deep Freeze extends the
repeat count. Frozen dice are immune to Jam and Rewrite; a Hijack waits until the
freeze ends (G-30, 2026-09-26). Non-damage
freeze abilities (incl. shield+freeze / heal+freeze) target ANY unit via manual
pick (`freezeAnyDice`); freeze riders on damaging abilities stay enemy-side.
Enemy AI freeze targets the hero's LOWEST revealed die, deterministically.

**Lineage — kept so no future agent resurrects a dead model:**
1. **Bank/thaw (fix-1.4 "banked-face" reading, DEAD).** An unspent-reveal freeze
   "banked" the face; thaw revealed the banked value once. Written into
   `offline-bundle/GROUND_TRUTH.md` §7 with a DESIGN-TODO claiming it superseded
   the 67d95b6 revert. It did not. Killed for illegibility.
2. **Next-turn static lockout (commit-era revert, DEAD).** "Reverted per Kev from
   the fix-1.4 bank/thaw reading": the die stayed static and the unit SKIPPED its
   next N reveals — pure action denial. Live until 2026-07-06
   (`die_freeze_consumed_this_round`, item `skips` key).
3. **Repeat (2026-07-06, FINAL).** The frozen face is not denied — it is
   REPLAYED. Both prior models removed from code, data, text, and tests in one
   pass; flag is `die_freeze_repeat_this_round`, item data uses `repeats`, eff
   strings read `freeze (repeat N)`.

**Where it lives:** `combat_manager.gd` (freeze block, `_freeze_die_state`,
`_freeze_pick_hero_lowest_die`, jam/rewrite/hijack immunity guards),
`battle_engine.gd`, `policy_l1_greedy.gd`, TRUTH.md rule 7, `keywords.data.json`,
`ability_audit.gd` freeze regressions, `freeze_engine_regression.gd`.
**Balance note:** landed WITHOUT re-baselining (overall 53.0%→25.3%, Avalanche
79.8%→13.2%) — see the ±10 report in `docs/SESSION_2026-07-06_engine_semantics.md`;
rebalance is Kev's call.

## 3. Buff/DoT timers — INDEPENDENT INSTANCES *(ruled by Kev, 2026-07-06; landed 52e2fa5)*

**Ruling.** Roll buffs (`rfm` and `erb`, both sides) and DoTs (burn) stop
refreshing to max on recast. Each application is its own instance with its own
remaining duration; effective value = sum of live instances; each expires on its
own clock. Display aggregates ONE chip: summed value, longest remaining duration.
Canonical case: +3/2t cast turn 1, +5/2t cast turn 2 → turn 2 total +8, turn 3
total +5, turn 4 zero. **Rationale:** refresh-to-max made recast buffs read as
permanent and made burn stacking unpredictable; instances are the one-sentence rule.
**Known casualties (balance calls, data untouched):** `erbT: 1` (2 abilities) and
Emergency Signal's 1t buff now expire the round they're cast without shaping a roll.
**Where it lives:** `roll_buff_stacks`/`burn_stacks` in combat_manager, TRUTH rule
10, `_run_instance_timer_regressions`.

## 4. Permanent-burn Detonate — ONE TICK, NOT CONSUMED *(ruled by Kev, 2026-07-06; landed 52e2fa5)*

**Ruling.** Detonate on a PERMANENT burn (plagueProtocol) deals exactly one tick's
damage (the burn amount) and the permanent burn is NOT consumed. Finite burns
unchanged: amount × remaining turns, consumed. `DETONATE_MAX_TURNS` removed as the
mechanism. Payload Fuse +50% applies to the whole burst. **Rationale:** the 6-turn
cap was a data-derived placeholder, not a rule anyone could state; "one tick, keeps
burning" is legible and can't one-shot. **Where it lives:** `_detonate_burn` +
`get_expected_detonate_burst` (single-sourced into the Detonate pip), keywords def,
TRUTH keyword table, `_run_detonate_regression`.

## K1. Cloak = 2 clauses *(keyword batch Task 7, commit 4474ab3)*
Untargetable by hostile single-target abilities; breaks on dealing damage or being
hit by an AoE. The third clause ("first attack from Cloak gains Pierce") was
REMOVED — one keyword was doing two jobs. Ghost post-nerf sim: 43.5→50.8, no
compensation needed. Do not re-add pierce-from-cloak.
**Amended by G-52 (2026-10-08):** the attack that breaks a cloak is an ambush
(+50% damage), and an attack with every target cloaked hits one at random.

## K2. Pierce AND Breach both kept, distinct sentences *(keyword batch Task 6)*
Pierce (`ignSh`): damage ignores shields (they remain). Breach: destroys all
shield on the target BEFORE damage. They read as different verbs and support
different counterplay; merging them was considered and rejected. Keyword defs in
`keywords.data.json` are the canonical sentences.

## K3. Taunt unified, Lure deleted *(keyword batch Tasks 4+9, commit 0bd652c)*
One keyword both directions: "The taunted unit can only target the taunter."
Hero-side redirects all enemy aim (overrides everything, even cloak); enemy-side
keeps the internal `lured_by_id` split but every player-facing string says Taunt.
Do not reintroduce a separate Lure.

## K4. Jam cap = 10 *(keyword batch Task 5, commit b219162)*
`JAM_CAP := 10` (was 12). 12 barely bit (most bands sit below it); 10 clips the
surge band without deleting crit fishing. Wall of Static's own cap-15 clause is a
separate, intentional exception.

## K5. ECS rejected *(architecture review, Jul 2026 — docs/ARCHITECTURE_REVIEW_JUL2026.md)*
The dictionary-state + choke-point architecture stays. An ECS/refactor to typed
components was evaluated and rejected: the game's complexity ceiling (3v4 units,
~20 status keys) doesn't amortize the migration risk, and the sim/live-screen
shared-rule seam (BattleEngine) already gives the decoupling that mattered. The
approved structural work is the god-object split backlog, not a paradigm change.

## 17. voidCirclet 68% accepted, compensation pass owed *(accepted at 3901e06)*
The keyword batch moved voidCirclet 42.1%→68.4% (+26.3): ward cull + hijack swap +
Synod trash on SYSTEMATIC all point the same way. Kev accepted the baseline (the
mechanics were correct) and explicitly flagged a **compensating Synod pass** as
owed — a design decision on how much to claw back, folded into the post-semantics
rebalance (which now also covers the freeze=repeat regression, see #1).

**SUPERSEDED (per Kev 2026-07-06, baseline accept):** "Post repeat-freeze
checkpoint, pre repricing. Avalanche figure known biased low: L1 cannot yet play
ally crit banking. DECISIONS_RESOLVED #17 Synod compensation note is void; #6
through #10 deferred balance numbers re anchor to this checkpoint." Ruled
DEFERRED to the global balance pass (see the transcribed batch below).
Re-anchored 2026-07-06 to the crit-banking checkpoint (overall 0.2867; the
voidCirclet +10.5 is the Root Access counter — see the batch entry note).

---

# RULED — TRANSCRIBED 2026-07-06 *(implementation pending unless marked deferred)*

> Ruling text below is Kev's adjudication batch, transcribed VERBATIM (no
> paraphrase) per the cleanup order of 2026-07-06 — implement against THIS text.
> Batch preamble, verbatim: "Decision batch closeout, human adjudicated. Read
> docs/TRUTH.md and docs/INVARIANTS.md first. For every item: implement, update
> TRUTH.md in the same commit, move the entry from DECISIONS NEEDED into
> docs/DECISIONS_RESOLVED.md with date and rationale. Do NOT touch the freeze,
> buff timer, or detonate paths; those landed in a separate adjudicated session."
> Batch verify clause, verbatim: "VERIFY: validate-data, ability audit, flow
> smoke, tutorial smoke, ci_smoke. Expected drift: zero, except possibly #2's
> normalization sweep if any multi turn shields exist in data; report any delta
> before touching the baseline."

## 2. Shield "one round" per-side reading — IMPLEMENTED 2026-07-07
**Status:** CONFIRMED as coded; data audit found ZERO offenders (no shield
duration field exists; eff-text "Nt" suffixes near shields bind to the roll-buff
clause per the canonical grammar; only shieldsPersist persists). TRUTH rule 5
names the single exception; the combat_manager DESIGN-TODO is a resolved
citation. Doc-only — zero drift.
**Question:** code applies expiry per-side as "one opposing action phase" so
enemy-phase shields survive one tick (`combat_manager.gd` `_add_shield_stack`);
alternative was strict same-round expiry.
**Ruling (verbatim):** "#2 CONFIRMED plus sweep: shields last one opposing action
phase, per side expiry as coded. Audit data/raw for ANY ability, gear, or enemy
kit granting multi turn shields; normalize to one phase and fix eff text, long
descriptions, and pip descriptions. SINGLE NAMED EXCEPTION: shieldsPersist
(Mantle Core relic, MANTLE TYRANT standing rule) is untouched, and TRUTH.md rule
5 must name it as the only exception."

## 5. SCRAPMASTER "every other turn" — IMPLEMENTED 2026-07-07
**Status:** cadence now counts from FIRST ACTIVATION (per-boss
`assembly_line_first_round` stamp; phase 1 = first live enemy phase, rebuilds
on phases 2/4/6). Identical to the old even-round reading when the boss is live
from round 1 (the only shipping case → zero drift); the offset case is
regression-pinned. Player-visible rule text updated in BOSS_STANDING_RULES.
**Question:** code reads ASSEMBLY LINE as even-numbered rounds; alternative is
every 2nd enemy phase from first activation.
**Ruling (verbatim):** "#5: SCRAPMASTER's ASSEMBLY LINE fires every 2nd enemy
phase counted from first activation, not even numbered rounds. Adjust, update
player visible rule text, test the cadence."

## 6.–10. + 17. Balance numbers — DEFERRED to the global balance pass *(resolved as deferred)*
**Ruling (verbatim):** "#6, #7, #8, #9, #10, #17: record all six in
DECISIONS_RESOLVED as 'DEFERRED to the global balance pass' with file:line
cites; leave every number untouched; remove from DECISIONS NEEDED."
**Cites (current):** #6 INTERCEPT_CARDS `GameState.gd:394` · #7 route modifiers
`GameState.gd:253` · #8 boss cadence `combat_manager.gd:107` (consts + tuning
seam defaults) · #9 execute bonus `combat_manager.gd:1406` · #10 chain ratio
`combat_manager.gd:1474` · #17 Synod difficulty (see the superseded entry above).
**Checkpoint re-anchor (per Kev 2026-07-06, crit-banking checkpoint — supersedes
the repeat-freeze checkpoint anchor):** "Post crit-banking checkpoint. voidCirclet
+10.5 is mechanically coherent: frozen dice are immune to Rewrite and Hijack, so
ally banking directly counters ROOT HIEROPHANT's Root Access standing rule; the
bot found the boss tech. Avalanche at 23.7% remains the known repricing target;
no ability numbers move until that ruling. All deferred balance numbers re anchor
to this checkpoint." (Prior anchor for lineage: the repeat-freeze checkpoint,
overall 0.2533.) All six numbers are sweepable via the balance workbench
(`scripts/sim/knobs.json`).

**Batch-1 update (Kev 2026-07-11):** #10 `chain_ratio` was explicitly set
**0.6→0.5** in the Batch-1 data/balance pass (a small-changes batch, NOT the
global balance pass). The pinned chain audit regression was updated to the new
50% expectation in the same pass (still 228/0). The other deferred numbers
(#6, #7, #8, #9, #17) remain untouched. Baseline intentionally NOT re-pinned
(a full balance pass follows; win-rate implications deferred per the batch).

## 11. Reverse Gimbal UX
**Question:** "may subtract" implemented as tap-again to flip +3 ↔ −3.
**Ruling (verbatim):** "#11 CONFIRMED: Reverse Gimbal tap again to flip +3/−3
ships as is."

## 12. Cloak: hostile-only untargetability — IMPLEMENTED 2026-07-07
**Status:** code path verified (the legality filter skips cloaked units only on
hostile enemy-side picks; "hero" and friendly "any" picks include cloaked
allies); keyword def + inspect tooltip + TRUTH now state the friendly-picks
legality explicitly; battle_scene DESIGN-TODO replaced with the citation.
**Question:** friendly picks on cloaked allies stay legal (`_get_legal_target_ids`).
**Ruling (verbatim):** "#12 CONFIRMED: cloak blocks hostile single target picks
only; friendly picks on cloaked allies are always legal. Ensure the cloak def
and tooltip state it."

## 13. Tutorial runs count toward `runs_started` — IMPLEMENTED 2026-07-07
**Status:** start_run skips record_run_started when tutorial_mode is set; the
rung-1 pity unlock (3 runs → avalanche post-Batch-1; engineer before the
2026-07-11 starter swap) counts real runs only. No retroactive
save adjustment — already-banked tutorial runs are grandfathered (TRUTH notes it).
**Question:** they do today, feeding the rung-1 pity unlock (3 runs → engineer).
**Ruling (verbatim):** "#13: tutorial completion no longer increments
runs_started; the rung 1 pity unlock therefore counts real runs only. No
retroactive save adjustment; note grandfather behavior in TRUTH.md."

## 14. Directive Marks stay single-target on AoE — IMPLEMENTED 2026-07-07
**Status:** CONFIRMED, never AoE Mark. Data audit found ZERO abilities combining
AoE with mark (reported before any rewrite; none needed). Combat Sense and
Marked for Death descs now read "Your single-target hits Mark their primary
target."; the combat_manager DESIGN-TODO is a resolved citation.
**Question:** Combat Sense / Marked for Death mark only the single-target hit;
AoE marking everything read too strong.
**Ruling (verbatim):** "#14 CONFIRMED, never AoE Mark: keep single target
directive behavior; update Combat Sense and Marked for Death descriptions to say
they Mark the primary target of single target hits; audit data/raw for any
ability combining AoE with mark, report any found before rewriting them; replace
the DESIGN-TODO at combat_manager.gd:1215 with a resolved citation."

## 15. Mid-run re-equip — IMPLEMENTED 2026-07-07 (rejection recorded)
**Status:** REJECTED, not deferred: the deterministic rotate-one-slot stand-in
is the permanent behavior; the TODO at the _rotate_gear_loadouts site is now a
rejection citation. Do not build the full re-equip UI.
**Question:** "freely re-equip" is deferred; deterministic stand-in in place
(`GameState.gd`). Full UI wanted?
**Ruling (verbatim):** "#15: mid run re-equip REJECTED, not deferred. Remove the
TODO at GameState.gd:623, keep the deterministic stand in, record the rejection."

## 16. Active shield total readout — IMPLEMENTED 2026-07-07 (cut REVERSED, chip is canon)
**Status:** the shield chip is restored as a visible primary numeric chip
(⬡ + total) on unit cards, BOTH sides — the pkg8.1 cut is reversed per Kev and
the chip is canon. State-driven, so it updates live on grant/break/expiry and
drops at the correct per-side phase tick (#2); the renderer's shield palette
and numeric mapping had survived the cut, only the token source was restored.
HP preview unchanged. Pixel-level collision verification at 450×1000 lands in
the same-day UI precision batch (its chip-clamp acceptance covers 4-chip
zero-clip, superseding a one-off check here).
**Question:** shield total only visible via HP preview/inspect since the chip was
cut — sufficient at 450×1000?
**Ruling (verbatim):** "#16 RESTORE the active shield total as a visible primary
status chip on unit cards (battle_card_view), both sides, updating live as
shields are granted, broken, and expired, styled consistently with existing
chips. Record in DECISIONS_RESOLVED that the chip's absence is reversed per Kev
and the chip is canon; HP preview behavior unchanged. Note: with per side expiry
confirmed in #2, the chip must visibly drop at the correct phase tick, not at
round end."

## 18. Rarity palette — GREEN EXITS *(ruled by Kev, 2026-07-10; UI review S-2)*
**Question:** `RARITY_UNCOMMON` green (#5cb85c) surfaced on reward-card borders,
the equip overlay, and item text — in tension with INVARIANTS #7 ("green is
reserved for HP bars and heals — nothing else is ever green"). Sanctioned
exception, or recolor?
**Ruling:** recolor. Rarity ladder is gray → blue → purple → orange:
common `#7a8290` (keep) · uncommon `#5b7fe8` (was rare's blue) · rare `#9d52d8`
(was epic's purple) · legendary `#ff8230` (keep). "epic" is unused in data; its
token stays aligned with rare. Green now has zero non-HP/heal surfaces. The
evolution branch-name green (`PixelUI.HERO_ACCENT` at its single call site) is a
selection, not a rarity — recolored to `DT_CYAN` in the same pass.
**Where it lives:** `pixel_ui.gd` RARITY_* tokens, `evolution_screen.gd:300`.

---

# BUILD G PUNCH-LIST RULINGS (Kev, 2026-07-15 playtest)

## G-21. Save system — resumable runs + persistent meta (Kev, 2026-09-15)

> **Superseded in part (2026-09-21)** by "Web demo QoL: branded loader +
> end-of-round battle checkpoints" (top of this file): battles now checkpoint at
> each completed round, and live d20 faces come from the seeded stream. The
> clauses below that say otherwise are historical.

**Ruling.** Runs are resumable across a reload. Two files with separate
lifecycles: `user://save.json` (the existing profile — tutorial flag, unlocks,
lifetime stats, settings) keeps its path and schema, and `user://run.json` is
added alongside it for the ACTIVE RUN ONLY, deleted on victory, defeat and
ABANDON RUN. **No `meta.json`, no rename, no profile migration** — the profile
gains only a `schema_version` dispatch wrapper in front of the existing
`_merge_loaded`, which may never discard: a future schema bump must not cost a
player their unlocks.

Checkpoints land at NODE BOUNDARIES only, after a node's content is generated and
before the player acts on it. Nothing mid-battle is serialized. A reload restarts
the current battle from its opening state; the reward, event, fork and intercept
screens show the identical offers, in the identical order.

**The battle-start checkpoint is taken immediately after `record_battle_entered()`
and BEFORE the remaining one-shot consumptions** in `battle_scene._init_live_battle`
(carried protocol, battle-start consumables, the route modifier, the armed
intercept effects). Saving after them would restore a post-consumption run and
then re-enter the scene, which re-consumes nothing and silently drops the route
modifier — the resumed fight would be the easy version.

**`battles_fought` stays exactly-once across a resume.** It is the unlock metric
and INVARIANTS #18 calls it farm-proof by construction; a resumed battle that
re-counted its entry would make reloading an unlock farm. The guard is
`GameState.battle_entry_counted`, saved RUN STATE rather than a checkpoint
argument — as a parameter, every routing call site had to remember to forward it
and one that forgot re-opened the hole for the width of a scene transition.
`nat20s` and `deaths` are display-only SERVICE RECORD counters and DO double-count
the replayed part of a restarted battle; accepted, not worth mid-battle buffering.

**No run save is ever written while `tutorial_mode` is true.** The drill is not
resumable; only its completion flag persists.

**RNG.** Run-affecting randomness runs on owned `RandomNumberGenerator`
instances, never Godot's global stream. The save stores RNG `state`, never the
seed — restoring from a seed would rewind the between-battle economy and let a
reload reroll every reward already offered. **64-bit values (RNG states, seeds)
are stored as STRINGS**: Godot's JSON parses every number as a double, so an
unquoted int64 comes back rounded AND retyped, silently (verified on 4.6.2:
9007199254740993 → 9007199254740992.0). `DiceManager` and `PhysicsRollProvider`
gained owned streams seeded from `GameState.battle_rng_seed`, replacing bare
`randi()` / `randi_range()`. That seed is **derived** from (`run_seed`,
`current_battle`) and consumes no stream: drawing it from the run RNG was safe
only because the balance sim happens not to run `battle_scene`, and the first
seeded path to call it would have shifted every downstream reward, beat and
intercept roll. Live d20 FACES are read off the settled physics tray and are NOT
restorable — a restarted battle can roll differently, by design. *(2026-09-26,
G-24: the landed faces of a settled roll are now kept as a pending roll in the
battle checkpoint.)*

**Write safety.** Copy the outgoing primary to `.bak`, then `.tmp` → rename into
place. Every write to a primary goes through that one atomic path, the repair
below included. On load the best of primary / `.bak` / the web mirror wins by a
monotonic **`save_seq`**, not `saved_at` (wall-clock moves backwards across a
device clock change or a timezone-confused browser). A copy that will not parse
loses to any copy that will; all three unusable = clean start, logged, no crash.
Deleting a run removes the mirror key as well as the files — a surviving mirror
copy would put CONTINUE back after a finished run. When the mirror wins a load,
the stale primary is **repaired in place**, keeping the winner's `save_seq`
(a repair is not a new save): `run.json` would heal at the next checkpoint
anyway, but `save.json` can go a whole session unwritten, so clearing site data
afterwards would silently roll a profile back.

**Web durability.** Godot 4.6.2 mounts `user://` as IDBFS with **no
`autoPersist`**, so writes sit in MEMFS until the engine's debounced `FS.syncfs`
fires from the main loop, and no GDScript API can force it. Background the tab
first — which is exactly what iOS Safari does — and the write dies with the page.
Every save is therefore ALSO mirrored to `localStorage`. This **narrows** the
window; it does not close it, because Safari persists localStorage
asynchronously too and the itch.io iframe partitions both stores. Every
`JavaScriptBridge` access degrades to the IDBFS-only path on failure. On web,
`OS.is_userfs_persistent()` false raises a non-blocking menu notice.

**Schema drift is a build break.** `RUN_SAVE_SCHEMA_FINGERPRINT` pins a hash of
the save's key/type structure beside `RUN_SAVE_VERSION`, and the `save schema`
gate fails when the structure moves without a version bump. Array length, the
keys of ID-keyed dictionaries (`GameState.ID_KEYED_RUN_FIELDS`) and `save_seq`
are excluded as data — a fingerprint that moved when a hero was swapped would
fire on ordinary play and be turned off. Recorded as a rule in `CLAUDE.md`: any
change to `to_save_dict()` bumps the version in the same commit, with the
migration decision.

**Known trade, accepted for the demo:** a player who is losing a battle can
reload to restart it. No mitigation was built.

**Supersedes.** `docs/OVERLOAD_PROTOCOL_DEMO_READINESS_AUDIT.md` R-02 ("either
implement an atomic between-battle run checkpoint or scope the first demo to
desktop") — the checkpoint is implemented, so the desktop-only fallback is off
the table. R-03 (mobile pause/focus lifecycle) is NOT addressed and remains open.

**Out of scope, unchanged:** mid-battle state serialization, cloud saves,
multiple save slots, and any balance or content change.

## G-17. Icon Guide in Help (Kev, 2026-09-09)

Add the reviewed Icon Guide to Help, with Actions and Effects sections using
the existing font and icons. Explain Nudge, Reroll, Set and Item, normal costs,
and common effect symbols; retain access to the full keyword reference.
Keep the current fonts and battle header (review option A). This approval is
for the guide only; battle prompts and the compact footer remain unchanged.

## G-18. Filled boss nameplate, option C (Kev, 2026-09-09)

Implement reviewed option C: a copper-filled nameplate with dark BOSS text
above the existing callsign, inside the current name-strip footprint.
Keep portraits, HP bars, status rows and targeting borders unchanged. No glow,
new portrait-corner badge or animation. Use the existing standing-rule boss
registry; ordinary enemies and heroes retain their current nameplates.

## G-19. Compact unlocks and simpler title (Kev, 2026-09-09)

Implement the reviewed compact small-unlock composition: title above a panel
sized to its awards, centered in the available area; Continue stays at the
bottom. Large lists retain scrolling and readable icon sizes.
Remove the title-screen Tutorial button and the duplicate "Tell me what to
fix" feedback nudge. Keep the Feedback button, the first-run tutorial choice,
and Help's tutorial replay. No font replacement or first-run behavior change.

## G-14. Two-encounter training and Engineer damage (Kev, 2026-09-08)

Implement the reviewed tutorial flow: complete guided turns, independent play after
the guidance, a real item choice, and an optional second encounter with two enemies
covering Burn and item use. Offer CONTINUE TRAINING / START YOUR RUN after the reward.
Training rewards remain in training. Preserve first-time item guidance in real runs.
Both dice and portraits remain valid selection/target inputs. Unit selection needs
only its existing selection affordances, not a separate mandatory lesson.
Use normal damage, HP and status rules; never clamp damage or prevent a legal kill.
Arrange guided rolls to leave room for independent decisions, preferably round three
of encounter one and throughout encounter two. Permanently change base Field
Engineer's Overdrive (11–15) from 11 to 10 damage; Mark then gives 15 damage.
Preserve the compact footer. This supersedes the tutorial deferral in G-13.

## G-1. Operation-unlock popup FOLDED into the UnlockScreen *(ruled; landed Build G)*
**Ruling.** The separate one-time operation-unlock popup
(`OperationBriefingOverlay.present_unlock`) is retired. The UnlockScreen's NEW
OPERATION section shows the operation name (caps law: Title-Case label form -
"Facility Sweep" / "Hive Incursion" fixed in battle-modes.json) with its
one-sentence origin line beneath at body tier. Building the row acknowledges
`operation_origins_seen`. The deployment slate's first-run behavior is
unchanged.

## G-2. NK-17 amendment: equipped self-buffs drop the (self) marker *(ruled; landed Build G)*
**Ruling.** GEAR and RELIC effects that buff the HOLDER omit the `(self)`
marker and any self-target icon - equipment context makes it redundant.
ABILITY effect text keeps NK-17 exactly as-is. Encoded in TRUTH.md's grammar
section and gate-enforced both directions by
`scripts/checks/effect_text_target.py` (abilities: computed suffix required;
gear/relic/item text: `(self)` banned). `EffectPip.effects_from_passive`
strips the `self` scope at its single exit; `all`/`lowest` scopes stay.
The D sweep re-ran under the amended grammar: zero equipment offenders
existed (the amendment prevents future stamping and removes the redundant
self icon from equipment pip rows).

## G-3. Firewall must be visible *(ruled: yes; landed Build G)*
**Ruling.** Firewall (one mechanic - internal field `ward`, displayed
Firewall; NOT a duplicate of some other mechanic) displays at the portrait
tier alongside cloak/freeze: a FirewallBadge docked to the portrait corner
whenever `warded` is true, both sides, cleared on break/expiry. Not a new
chip - the sanctioned chip stays and still competes in the 3-chip row; the
badge is the always-visible tier. A hidden defensive state that eats an
ability without explanation was the defect.

## G-4. Taunt targets a SINGLE enemy *(ruled; landed Build G Lane 2)*
**Ruling.** Hero-side taunt is a single-enemy redirect, not an all-enemy
stance: casting taunt picks ONE enemy; that enemy can only target the
taunter until round end (NK-08 clearing unchanged). This aligns the code
with what the keyword def and NK-17 bare-`taunt` grammar already claimed
("The taunted unit can only target the taunter."). Enemy-side paths keep
their shapes: beastHyena's lure stays single-hero (`lured_by_id`);
veilPrism's `enemySelfTaunt` stays the all-heroes self-taunt (the taunted
units are all heroes, each restricted to the one taunter - consistent with
the def). Anchor Frame gear (`tauntAbove50`) is a standing stance and keeps
its aura behavior pending its own ruling - recorded here as the ONE
remaining aura-form taunt.

## G-5. Portrait corners carry NO status markers *(ruled by Kev, 2026-09-02; REVERSES G-3 / Build G item 11)*
**Ruling.** Nothing renders in a battle card's portrait top-right corner. The
`FirewallBadge` docked there by G-3 is DELETED. An armed firewall is an ordinary
chip in the bottom status row, on the existing priority order, under the same
3-chip cap and the same `+N` overflow as every other chip.
**This reverses G-3 ("Firewall must be visible"), which added the portrait-tier
badge precisely because the chip kept losing the 3-chip priority contest into
the `+N` overflow.** That outcome is now ACCEPTED: firewall may sit in overflow.
The cost is paid for by long-press, which shows the full status breakdown — and
the badge's own cost (a status tier that only one mechanic could ever use, and
a portrait corner permanently reserved) was the larger one.
**Corner audit at the time of ruling** (`compact_unit_card.gd`): top-LEFT is the
`CastOrderBadge` — the hero's own cast-order rank, an input the player set, not
unit state — and is UNCHANGED by this ruling; top-RIGHT is now empty;
bottom-left/right were already empty (the chip row is a full-width
`PRESET_BOTTOM_WIDE` strip, not a corner dock). The roster-tile corner badges on
the home screen (role color, pick-order slot, NEW) are selection and unlock
affordances, not unit status, and are untouched.
**Where it lives:** `scripts/ui/compact_unit_card.gd` (badge, its constants, its
layout reservation and the dead `warded` mirror all removed),
`battle_card_view.gd` (the `warded` configure key dropped — the firewall chip is
built from state by `_build_compact_status_tokens` as before), TRUTH.md chip
doctrine. Regression `scripts/debug/firewall_display_test.gd`, rewritten to
assert the new behaviour: no badge node, the chip renders, and firewall folding
into `+N` behind three higher-priority chips is a PASS, not a failure.

## G-6. Effect-pip overflow renders `+N` *(ruled by Kev, 2026-09-02)*
**Ruling.** The pip-row cap stays at 3, kept first-three-by-authoring-order.
What changes: effects past the third no longer vanish SILENTLY. They fold into
one trailing `+N` badge after the third pip, using the same overflow language
the card's status chip row already speaks (gold, "+N", TRUTH.md chip doctrine).
`effects_from_ability_raw` used to end in a bare `effects.slice(0, 3)`. Twelve
abilities were losing a keyword with nothing on the card to say so — Lattice
Link, Fortress Lash, Conclave Bulwark, Harmonic Mend and Hierophant Mantle lost
firewall; Veil Collapse, Lattice Storm, Broodlink Surge, Veil Cataclysm, Mass
Snare, Void Gate and Total Eclipse lost summon. Conclave Bulwark's long-press
read "…firewall, summon (42%)" over an icon row that showed neither.
The dropped effects remain readable: long-press renders the ability's authored
eff text beneath the pips, and that text carries every clause. Verified, and
asserted in the regression — if the eff text ever stops carrying them, the badge
points at nothing and THAT is the bug.
**Where it lives:** `scripts/ui/effect_pip.gd` (`MAX_VISIBLE_EFFECTS`,
`_cap_with_overflow`, the `overflow` letter-only kind and its gold value color),
`compact_unit_card._pip_border`. Every pip surface — readout, die-docked tag,
inspect, evolution — inherits it through `EffectPip.build_group`, one producer.
Regression `scripts/debug/effect_pip_overflow_test.gd` (gated), which also
sweeps all 230 authored abilities for a well-formed row.

## G-7. G-2's principle extends to hero-side ability PIPS *(ruled by Kev, 2026-09-02; extends G-2)*
**Ruling.** The `self` scope MARKER (the circled-figure icon) is stripped from
hero-side ability pips: on your own squad card a self-buff is already obvious,
so the icon is noise. It stays on the ENEMY side, where "who does this hit?" is
the open question, and `all`/`lowest` stay on both sides. This is the same
principle G-2 applied to gear/relic/consumable passives — redundant
self-marking is noise where context already answers it — extended from
equipment passives to hero ability pips. Recorded now because an earlier batch
landed the code without a written ruling.
**Tension to record honestly:** G-2 closed with "ABILITY eff text keeps NK-17
exactly as-is," and read narrowly that line reserves abilities from the
amendment entirely. The reconciliation: G-2's sentence governs authored eff
TEXT, and eff text IS untouched — NK-17 still owns the "(self)" suffix and
`scripts/checks/effect_text_target.py` still requires it on abilities in both
directions. What this ruling changes is the ICON, a different surface. Anyone
reading G-2's closing line as covering pips too is reading it reasonably; this
entry is the ruling that settles it, not a claim that G-2 already allowed it.
**Where it lives:** `EffectPip.effects_from_ability_raw`, the hero self-buff
exception block at its exit (mirrors `effects_from_passive`'s single-exit strip
from G-2). Gate `effect target` (`effect_text_target.py`) is unaffected and
still enforces the text side.


## G-20. Final feedback and casualty recovery (Kev, 2026-09-10)

Implement local Mark acquisition, distinct Burn application/tick cues, and summon/revive arrival effects; respect Reduced Motion and preserve turn timing. Remove the income sentence from the first item-acquired primer. Heroes dead at the end of the previous battle return at 75% of their updated maximum HP (integer floor, minimum 1), before explicit battle-start damage. Survivors retain full recovery; in-battle revival percentages stay authored. Prioritize verified source committed and pushed to main; web/physical-device release verification remains open.

## G-13. Implement approved choice mockups and Reduced Motion (Kev, 2026-09-07)

Implement V07 inspect/evolution and V08 route/reward mockups. Ability details use fixed roll columns, secondary names and bright left-aligned concise effects; evolution previews show the 20 first, expandable full abilities and selection before confirmation. Route consequences separate risk and reward; share hostile composition only when the two routes actually match. Reward names and effects remain bright regardless of rarity. Implement V12 as a persisted, default-off Reduced Motion setting: suppress decorative shake, glitch, strong washes and exaggerated scaling while keeping results, feedback and navigation functional. This supersedes G-12's mockup-only/deferred scope for V07/V08/V12 and older centered ability-row styling. Preserve gameplay and G-11's compact footer. V06 and V11 remain, with the full tutorial redesign separately deferred.

## G-12. Next visual pass scope (Kev, 2026-09-07)

Mock up V07/V08 for review; do not implement those layouts yet. Implement V09 art-outlier fixes using existing art when it fits the item's role and current style, and V10 bounded combat-number stacking. Remove the icon from the run-end Continue button. Reproduce V11's unlock-layout finding and explain V11/V12; these are investigation/explanation, not approval to redesign unlocks or add reduced motion. Twin Fates stays removed. Keep gameplay, the restored compact footer and stable item IDs unchanged.

## G-11. Restore compact battle footer (Kev, 2026-09-06)

The enlarged, labeled footer overlaps friendly health bars. Kev approved going back to the prior compact icon-only layout. Restore 112×112 buttons and bottom-right costs, and remove permanent captions. This supersedes the footer portion of G-10. Keep Twin Fates removed and preserve the other step-1 changes. Do not repeat the label enlargement without a new layout decision.

## G-10. Public-demo visual step 1 (Kev, 2026-09-06)

Kev approved step 1: preserve readable dice values under status overlays; improve the footer with icons and compact labels if they fit; replace the default application icon with the existing identity's reactor motif; hide developer controls until seven consecutive taps on the operation title unlock them for the current application session; and correct inaccurate help while deferring the full tutorial rethink to step 2.

Remove Twin Fates from the game for now, including offers, unlocks, reference content and its battle copy controls. Preserve old profile compatibility and unrelated stable IDs. This supersedes G-9's retention of Twin Fates. Existing art may remain as an unused source asset. No other relic, dice rule or progression formula changes.

## G-9. Apply the concise copy review (Kev, 2026-09-06)

Kev approved implementing the full revised copy workbook. Apply its names, lore, descriptions and compact ability tooltips, with matching runtime references and preserved internal IDs/art paths. The approved effect syntax uses “damage” and explicit “turns”; hero self effects are implicit, while enemy self effects retain `(self)`. Group targets say `(all heroes)` or `(all enemies)` and lowest-HP support says `(lowest HP)`. This updates the text portion of NK-17/G-7; target checking must still derive and verify each clause's actual scope. Gear and consumables keep concise holder/target context. Operation threat lines retain their original text. Deployment labels become SITUATION and OBJECTIVE.

Resolve the review's copy/code mismatches without tuning authored numbers: enemy ally-shield clauses work independently of self-shield; Bounty excludes every standing-rule boss, including Mantle Tyrant; Deep Freeze Charge does not change an already-frozen face (it extends that freeze). Twin Fates retains its existing free, once-per-battle base-roll copy and controls. Long intercept choices use short action buttons and separate readable consequences.

## G-8. Frozen 20s and reinforcement kill rewards (Kev, 2026-09-05; supersedes NK-04 and NK-10)

Kev requested that Overload Loop activate again on frozen turns, removed frozen-repeat exclusions, and confirmed that summoned and rebuilt enemies should count for kill rewards. Every resolution of a frozen 20 now triggers the usual 20-face riders on both sides: Loop/Rites echo, Protocol-on-20 gear, the 20s statistic, and enemy summon chance. Loop/Rites grant one extra activation, not recursive echoes; Protocol and stats pay once per resolving hero turn, not once per echo. Existing summon chances and field limits remain.

Summoned and rebuilt enemy deaths now qualify for normal kill rewards: Protocol, Bounty, Chitin Graft, Kill Switch, Momentum, and Scavenger Manifest. Killer, mark, enemy-type, inventory-capacity, and once-per-battle requirements still apply. Freeze duration and alteration immunity remain unchanged. Player copy uses “turns”; Glacier's Deep Freeze adds one turn.

## G-15. Basics before effects (Kev, 2026-09-08)

Approved: welcome first; battle one teaches damage, heal, shield and Protocol only, retaining free turn three. Battle two retains Strike and swaps Engineer for Pulse to teach Mark and Burn, inventory use, and a once-only Reroll hint when 2 Protocol and an available die make it usable. Inventory instructions spotlight only its button. Remove repeated starting-Protocol and training-reward disclaimers. Close with more effects to discover and thanks before squad selection. Training still clears its rewards on exit; authored combat rules and numbers remain unchanged.

### G-15 copy follow-up (Kev, 2026-09-08)
Approved concise battlefield/roll/inspection/intent teaching, remove the results beat, introduce income beside Nudge, shorten reward/continuation copy, clarify delayed Burn and future primers. Use Splice in instructions. Inspect redirects flash visible die and portrait rather than pip hit area. Suggested targets stay unenforced. Income wording remains each completed turn to match runtime.

## G-16. Stable squad selection and display-name copy (Kev, 2026-09-08)
Keep the detail-panel footprint on locked encounters with no focused hero, transparent when empty. Hide locked hero names while retaining silhouettes/LOCKED and layout space; supersedes prior named-locked-card presentation. Remove NO CLEARANCE for unplayed operations; keep meaningful progress and LOCKED. Tutorial refers to SCRAP and introduces new abilities without naming them early. Briefing title/keys stay uppercase; site, situation and objective use sentence case with proper boss names. No unlock or combat changes.
