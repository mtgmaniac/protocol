# Dice face audit: why a die lands on one face and snaps to another

**Date:** 2026-09-26 · **Branch:** `dice-face-snap-p0` · **Scope:** Phase 1 diagnosis
of the P0 in TASK_QUEUE "Open backlog (2026-09-26)". No gameplay or tray code was
changed. **The root cause is the design, so Phase 2 is waiting on Kev's choice** (see
§5).

**Probes (diagnostic, not gates yet):**
- `scripts/debug/dice_face_audit_probe.gd`: the real `DiceTray3D` roll path with the
  battle rig in place. It logs the logic value, the landed face, the final face, the
  numeral whose label faces up, and the snap rotation for each die.
- `scripts/debug/dice_face_paths_probe.gd`: a live `BattleScene`. Each modify path is
  compared three ways: the die face, the effective value (readout and preview), and the
  value `resolve_round` acts on.

```
godot --headless --path . -s scripts/debug/dice_face_audit_probe.gd   # ~2 min
godot --headless --path . -s scripts/debug/dice_face_paths_probe.gd   # ~30 s
```

## 1. Root cause (confirmed)

**The result is decided before the roll, physics then rolls freely, and the die is
rotated to the decided face afterwards.**

Since `1171eb8` (end-of-round battle checkpoints, 2026-09-21), every roll outside the
tutorial works like this:

1. `battle_scene._begin_targeting_phase` draws each die's face from the seeded battle
   stream (`_stream_rig_values`, battle_scene.gd:1179) and hands it to the tray as a
   "rig" (`set_rigged_results`).
2. The tray throws real Jolt rigid bodies with random throw parameters
   (`_launch_die`). Nothing in the throw knows the rigged value.
3. When motion settles, `_resolve_landed_die_face` (dice_tray_3d.gd:1112) reads the
   physically-up face, **then discards it** in favour of the rig. After a 0.20 s pause
   (`RESULT_SNAP_DELAY`), `_start_result_face_present` tweens the body over 0.42 s from
   its landed pose to the pose with the rigged face up.

The landed face and the rigged face are independent, so they differ about 19 times in
20. The tween then rolls the die across to a different face. That is the snap.

Before `1171eb8`, the physics face *was* the result, and the tween only squared up the
face that had landed. The checkpoint work (DECISIONS_RESOLVED: "the saved battle RNG
is AUTHORITATIVE for dice faces and physics only visually resolves to them")
extended the tutorial's rig (`a39735f`) to every roll. The tutorial always had the
same snap: the comment at dice_tray_3d.gd:437 says "the player never sees a wrong
number", but the rig replaces the value only after the die has landed.

### Evidence: `dice_face_audit_probe`, 40 rolls × 7 slots (3 hero, 4 enemy)

| Measure | Result |
|---|---|
| Dice logged | 280. Every slot saw all 20 values (140 slot × value pairs) |
| Landed face ≠ logic value | **269 / 280 (96.1 %)**. Chance is 95 % |
| Final face ≠ logic value | 0 / 280 |
| Numeral label facing up ≠ final face | 0 / 280 (the face table matches the mesh) |
| Snap rotation when the face changed | median **138°**, p90 176°, min 39°, max 180° |
| Snap rotation when the face was already right | median 93°, max 143° (yaw only, §2.4) |
| Face-change tilt | only 42°, 70.5°, 109.5°, 138° or 180°: the die rolls across to another face |
| Per slot | Mismatches of 37 to 40 in each of the 7 slots. No slot is special |
| Roll duration | 2.5 s to 3.8 s, median 3.0 s |

Every slot mismatches at the chance rate, the final face always equals the logic
value, and the labels agree with the face table. So the mapping and the target choice
are correct. The only defect is that the landing ignores the chosen value.

## 2. The roll pipeline

### 2.1 Where the result is decided
In game logic, from RNG. `BattleEngine.roll_states` → `roll_provider.roll_d20()`
(battle_engine.gd:503) is called by `battle_scene._stream_rig_values` before the
visual roll. The skip-visuals path draws the same values in the same order. The
tray's physics face is read (`_get_most_visible_face_value`) but overwritten whenever
a rig is present, which is now every roll. **Confirmed.**

### 2.2 What the visual die does
Both physics and scripted motion. The tumble is a real Jolt `RigidBody3D` (120 Hz,
convex d20 hull, `_spawn_die` / `_launch_die`, late damping ramp). The settle
presentation is a scripted `Tween` that sets `global_transform` directly
(`_start_result_face_present`). **Confirmed.**

### 2.3 End of roll
`_wait_for_dice_to_settle` freezes the bodies, waits 0.20 s, and then
`_resolve_landed_die_face` runs for each die. It rotates the body to
`_get_face_forward_result_basis(face_index_of(display))`, the pose with that face's
normal at world +Y and its numeral's up-axis toward −Z (screen-up), and moves it to
its result slot. The value comes from the rig, passed through `_display_face_for_entry`
(raw + roll buff − roll penalty, jam cap). **Confirmed.**

### 2.4 Secondary motion: the yaw square-up
Even when the landed face is correct, the tween spins the die about the vertical so
the numeral reads upright. That is 28° to 143° in the probe and up to 180° in
principle. It never changes the face, but it is visible motion at the end of every
roll. Any fix should bound it. With the icosahedral symmetry trick in §5 (options A′
and C), it can be held to 60° or less, or dropped. **Confirmed (measured).**

### 2.5 Face index → number
`_build_d20_face_data`: face *i* of `_get_d20_faces()` carries value *i*+1. Face
panels (`FacePanel%d`) and labels (`FaceNumber%d`) are built from the same face list
and normals. The probe checks this independently: the `Label3D` whose facing axis is
closest to world-up always reads the final face (280/280). The table matches the
model. (The numbering is not the standard layout, where opposite faces sum to 21.
That is cosmetic and out of scope.) **Confirmed.**

### 2.6 Which value gameplay uses, and which value the die shows
- **Gameplay** resolves from `BattleEngine.effective_hero_roll` /
  `effective_enemy_roll` (via `build_effective_rolls` into `resolve_round`). Those
  build on `CombatManager.get_effective_roll`: rewrite → 3, else raw + buff −
  penalty, jam cap. Frozen repeat, Set and Nudge are layered in the engine. **Hijack
  is applied later, inside `resolve_round`.**
- **The die numeral** is `_display_face_for_entry`, a separate copy of that rule in
  the tray. The copy has no rewrite, and it is fed once at roll time.
- **Readouts and die tags** use the effective value.

On a plain roll all three agree (paths probe: 5/5 units OK). They **disagree on the
paths in §3 marked ✗. On those paths gameplay acts on a value the die does not
show.** That is a gameplay-honesty bug, separate from the snap.

## 3. Paths that change a die after it lands (`dice_face_paths_probe`)

| Path | Die face vs value acted on | Motion | Verdict |
|---|---|---|---|
| Plain roll | equal | snap (§1) | ✗ snap |
| **Rewrite pending** (Synod rewrite, Hierophant ROOT ACCESS) | **die 18, acts on 3** | none | ✗ **gameplay ≠ die**. The tray's copy of the rule lacks rewrite (combat_manager.gd:657 vs dice_tray_3d.gd:1133) |
| **Hijack pending** (enemy) | **die 16, readout 16, acts on 20** (heroes' highest) | none | ✗ **gameplay ≠ die and ≠ readout**. Hijack applies only inside `resolve_round` (combat_manager.gd:822) |
| **Post-roll +3 buff** (Sync Antenna path, `apply_item_roll_buff` after settle) | **die 4, acts on 7** | none | ✗ **gameplay ≠ die**. `_apply_post_roll_gear_effects` never updates the die |
| Forced 20 (Vengeance Protocol / Dead Man's Hand); Resonant Chorus uses the same code | equal after, but **7 → 20 in one frame, 120°** | teleport | ✗ automatic second snap after the first. The value is known before the roll but is applied after it (`_apply_roll_relic_overrides` → `update_die_result_in_place`) |
| Jam cap | equal (cap shown) | snap (§1) | ✓ value |
| Nudge | equal | **instant** 120° to 180° (`update_die_result_in_place`) | ✓ value. Deliberate change, allowed, but it teleports with no animation |
| Set | equal | instant 72° to 180° | ✓ value, teleports |
| Reroll | equal | 0.82 s spin-and-arc (`reroll_die_to_result`) | ✓ |
| Enemy reroll item (Phase Scrambler / Cascade Jammer) | equal | instant 72° | ✓ value, teleports |
| Frozen die, including frozen 20s, hero and enemy | equal (20/20) | none (static, `_prepare_frozen_die`) | ✓ |
| Freeze applied mid-round | face unchanged by design (captures `last_die_value`) | none | ✓ (by code reading, not probed) |

Rewrite, hijack and the post-roll buff reproduced on every run. Rewrite showed
18 vs 3 and 7 vs 3 in two different runs.

## 4. Confirmed vs inferred

**Confirmed by logs:** the snap mechanism and its rate (§1). The face table (§2.5).
The yaw square-up (§2.4). The rewrite, hijack and post-roll buff mismatches. The
forced-20 one-frame jump. Nudge, Set and enemy-reroll teleports. Frozen 20s correct
on both sides.

**Inferred (code reading, not measured):**
- Resonant Chorus behaves like forced 20 (same `update_die_result_in_place` call).
- The tutorial rig has had the same snap since `a39735f`.
- The Hierophant's ROOT ACCESS feeds the rewrite mismatch (it calls
  `apply_rewrite_to_state`).
- Everything in §5 about Jolt determinism and mobile or web cost is engineering
  judgement. None of it is prototyped.

## 5. Phase 2: design options (Kev decides)

The rule for any fix: the game's result is authoritative, and the die must never
visibly show a face and then change to another, except for a deliberate change.

**Key fact for every option:** the d20's collision hull is an icosahedron. Its 60
rotational symmetries permute the faces and leave the physics shape unchanged. So
rotating only the `Visuals` child by a symmetry *g* changes which number sits on
which physical face, without changing how the body rolls. For any landed face and
any target number there are exactly 3 such *g*. Picking the one with the smallest
remaining yaw bounds the square-up to 60° or less. Options A, A′ and C use this.

**Godot 4.6 constraint (checked):** GDScript cannot step a physics space manually
(no `space_step` on `PhysicsServer3D`). Physics advances only with the main loop, at
120 ticks per real second. A hidden pre-simulation of a 3 s roll therefore takes
about 3 s of wall time. The only speed-ups are `Engine.time_scale` (global: every
tween, timer and animation speeds up too) or a GDExtension.

### A. Pre-simulate, rotate the visual, then re-run physics visibly (as briefed)
- **Looks:** identical to today's roll, and the landed face is the chosen number.
- **Reliability: poor.** It needs the visible run to reproduce the hidden run bit
  for bit. Jolt is deterministic only for identical inputs in identical order.
  Re-creating the bodies (new IDs, broadphase and contact-cache state), frozen
  blockers, and the audio contact monitor all break that. Same-device determinism
  is plausible; same-world replay after a pre-run is not. Web and mobile differ from
  desktop, but that does not matter here because the pre-run happens on the device
  that shows the roll.
- **Performance:** trivial compute, but about 3 s of added latency per roll, because
  the pre-run cannot go faster than real time (constraint above).
- **Effort:** high. **Not recommended.**

### A′. Pre-simulate, record, then play back the recording (a variant of A)
The hidden pre-run's transforms are recorded every tick and replayed kinematically on
the visible dice, with `Visuals` rotated by *g*. Determinism does not matter: the
playback *is* the simulation.
- **Looks:** identical to real physics, including dice-on-dice hits (contacts are
  recorded for audio).
- **Reliability:** 100 % correct face by construction.
- **Performance:** trivial compute and memory (7 dice × ~400 ticks). Latency is the
  problem, because of the real-time pre-run. It can be hidden only by pre-running as
  soon as the round is ready to roll. A player who taps Roll immediately still
  waits, up to about 3 s. `time_scale` fast-forward is possible but global and hacky.
- **Effort:** high (about 3 to 5 days). Every face lookup must fold in *g*, the
  playback path needs its own settle and audio code, and frozen dice must be
  included in the pre-run.

### B. Scripted tumble that ends exactly on the chosen face
- **Looks:** can be made convincing: arcs, bounces, a decaying spin that is keyed
  backwards from the target pose. It loses real dice-on-dice collisions unless
  they are faked (per-side lanes, or a simple separation pass). It will read as
  "animated", not "thrown".
- **Reliability:** 100 %. No physics dependence, identical on web and mobile.
- **Performance:** cheapest. Physics could be kept only for frozen-die blocking, or
  dropped.
- **Effort:** medium (about 2 to 3 days to look good). Audio would be driven by
  scripted impact keys instead of contact callbacks.

### C. Live physics with blank faces, and the number revealed on landing (my recommendation)
Keep today's physics roll unchanged, but the numerals are not readable while the die
tumbles: blank, or a scrambling glyph like the existing Rewrite scramble. On settle,
apply the symmetry *g* that puts the logic number on the face that actually landed
up, then reveal the numerals.
- **Looks:** the real thrown-dice feel is kept. The die never shows a number it then
  changes, because no number is readable before it rests on the right one. The end
  motion is only a yaw square-up of 60° or less, or none. **This changes the look:**
  there are no numbers during the tumble, which suits the terminal aesthetic but is
  Kev's call.
- **Reliability:** 100 %. No determinism needed.
- **Performance:** zero added cost. No latency.
- **Effort:** low (about 1 day), plus the gate.

### Rejected
Physics decides the face again, with seeded physics for checkpoints. This violates
INVARIANTS #1 (the headless sim cannot reproduce it) and the 2026-09-21 ruling that
the saved battle RNG is authoritative.

### Fix regardless of the option chosen (straightforward bugs)
1. **Rewrite:** the die must show 3. Remove the duplicated rule: the tray display
   should come from the same effective-roll source as gameplay (`get_effective_roll`),
   not from its own copy.
2. **Post-roll buffs (Sync Antenna):** update the die when the buff lands, or apply
   the buff before the reveal.
3. **Forced 20 / Resonant Chorus:** fold the override into the rig *before* the roll,
   so the die lands on 20 or 8 and never shows the stream face first. Stream
   consumption stays the same.
4. **Hijack needs a ruling:** does the enemy's die show the copied value at reveal,
   or at resolve? Heroes can Nudge or Set in between, which changes "the highest
   die". Today the enemy die and its readout both show the un-hijacked value, and it
   then acts on the copy.
5. **Nudge, Set and the enemy reroll item teleport** in one frame. These are allowed
   deliberate changes, but they should animate like Reroll does.

### Also for Kev
- Keep the yaw square-up? Numerals squared to screen-up read better. Leaving the die
  at its natural yaw removes the last end-of-roll motion.

### Planned gate (once an option is chosen)
`dice face` hard gate: every slot across all 20 values, plus each path in §3. It
fails if the final up face (label check) ≠ the logic value, if the end-of-roll face
change is anything other than 0, or if the square-up rotates more than a small
threshold. It will be broken on purpose once to prove it fails. It will reuse the
probes above.

---

## 6. Phase 2, step 1: one source for every die value (Kev's decisions, 2026-09-26)

**Rule:** at every moment the player can read a die, it shows the value the
unit will act on. It never shows a value the unit can't have.

**What changed:**
- **The tray's copy of the rule is deleted.** `_display_face_for_entry`, the
  `roll_rfe`/`roll_buff`/`jam_cap` value fields on tray entries, the tray rig
  (`set_rigged_results`), `update_die_result_in_place`, `get_hero_rolls` /
  `get_enemy_rolls`, and `sync_enemy_dice_after_item_reroll` are all gone.
- **The tray reads one source.** Every die reads `battle_scene._die_value(side,
  id)` through `DiceTray3D.value_provider`. That is `BattleEngine.effective_hero_roll`
  / `effective_enemy_roll`, the same functions `resolve_step` feeds into
  `resolve_round`.
- **The tray follows game logic live.** From landing until the round resolves
  (`set_values_live`), any change reaches the die without a call site having to
  push it. The scene turns this off at `_resolve_current_turn`, where the
  acted-on values are snapshotted.
- **Hijack moved into the engine.** `BattleEngine.hijack_value`: a pending,
  unfrozen hijack copies the heroes' highest *effective* die. That is exactly
  what `resolve_round` copies (it is handed the effective hero rolls), so the sim
  is unchanged. The enemy's die, readout and intent now show the copy live, and
  `_on_die_values_changed` re-picks intents when the heroes' highest die changes.
- **Values are decided before the throw, on one path.** `_begin_targeting_phase`
  draws the stream, then applies frozen repeats, the tutorial rig, forced 20 /
  Resonant Chorus, and `record_roll_values`, all before the dice are thrown.
  Visual and skip-visuals rolls now share this code. The tutorial draws the
  stream too, as the skip path always did.
- **Nothing reveals a result before the dice land.** Values exist during the
  tumble now, so the scene has `dice_landed()`. Card readouts and forecasts
  (`BattleCardView._revealed_rolls`), the tutorial's stalled-waiter recovery, and
  the reachability test all use it.
- **The card ±Roll chip reads `get_roll_modifier_totals`** instead of a
  hand-kept mirror of that sum.

### Roll-modifier classification

**KNOWN BEFORE ROLL.** Active when the throw starts, so the die lands on the
modified value.

| Modifier | Where it is set | How the die gets it |
|---|---|---|
| Temporary roll buffs from earlier rounds (hero and enemy abilities, Emergency Signal, multi-turn items) | `combat_manager._add_roll_buff` (from `:1292`, `:1296`, `:1981`, `:1983`, `:2312`, `:3036`) | `get_effective_roll` (`combat_manager.gd:655`) |
| Permanent roll buff (Coordinated Strike, battle-start cloak roll, intercept roll bonus) | `combat_manager.gd:440`, `:488`, `:551`, `:592`; `battle_engine.gd:138` | `get_roll_modifier_totals` → `get_effective_roll` |
| Roll penalties from earlier rounds (hero rfe, enemy rfm, penalty items with turns > 1) | `_add_rfe_stack` (from `:1328`, `:1333`, `:1969`, `:3044`) | `get_effective_roll` |
| Permanent penalty (Signal Jam) | `combat_manager.gd:543` | `get_effective_roll` |
| Jam cap | `_apply_jam` (`combat_manager.gd:1687`) | `get_effective_roll` |
| Rewrite (Synod rewrite, Hierophant ROOT ACCESS) | `_apply_rewrite` (`:1653`), `:383` | `get_effective_roll` |
| Hijack | `combat_manager.gd:2036` | `BattleEngine.hijack_value`, live (see below) |
| Freeze repeat, including frozen 20s | freeze abilities and items from an earlier round | `apply_frozen_roll_overrides` + `effective_*_roll` (frozen branch) |
| Forced 20 (Vengeance Protocol, Dead Man's Hand) | `forced_20_pending` (`combat_manager.gd:2480`, `:2292`) | `battle_scene._apply_roll_relic_overrides`, before the throw |
| Resonant Chorus (round-1 floor of 8) | relic `turn1RollFloor` | `_apply_roll_relic_overrides`, before the throw |
| Tutorial scripted values | `TUTORIAL_HERO_ROLLS` | `_apply_tutorial_dice_rig`, before the throw |

**APPLIED AFTER LANDING.** These respond to the result or come later. The die
first locks on its landed value, then changes.

| Modifier | Where | Path |
|---|---|---|
| Nudge (incl. Reverse Gimbal flip, Priming Charge) | `BattleEngine.apply_nudge` | `hero_roll_nudges` → `effective_hero_roll` |
| Set (incl. Root Access free Set) | `BattleEngine.apply_set` | `hero_roll_sets` → `effective_hero_roll` |
| Reroll | `BattleEngine.apply_reroll` | `hero_rolls` → effective; keeps its own spin animation |
| Roll-buff items (Calibration Chip, Momentum Core, Harmonic Injector, Archive Cascade) | `apply_item_roll_buff` (shapes the current roll) | `get_effective_roll` |
| Penalty items (Grounding Clip, Corrosion Bomb, Entropy Seed) | `apply_item_rfe` | `get_effective_roll` |
| Enemy reroll items (Phase Scrambler, Cascade Jammer) | `item_enemy_reroll`, `item_enemy_reroll_all` | `enemy_rolls` → effective |
| Freeze items (Cryo Gel, Cryo Web) | `item_freeze_die`. This round's value is unchanged; it repeats next round | effective |
| Deep Freeze Charge | `item_enemy_freeze_all` pins enemy dice to 1 | `enemy_rolls` → effective |
| Sync Antenna | `battle_scene._apply_post_roll_gear_effects` | roll-buff stack → `get_effective_roll` |
| Live hijack updates | any change to the heroes' highest die | `hijack_value` |

**Unclear cases, and how they were classified:**
- **Sync Antenna: after landing.** It is a reaction to the result: two heroes
  rolling the same number. The values are drawn before the throw, so it *could*
  be applied first. But then the die would land on 13 and the player would never
  see the matching pair that caused it. After landing, they see the pair and
  then both dice change.
- **Hijack: before the roll *and* live.** The copy is in place when the dice
  land, and it keeps following the heroes' highest die until resolution.
- **Multi-turn items (Harmonic Injector, Archive Cascade, penalty items):**
  after landing in the round they are used, then known before the roll in later
  rounds.
- **Mid-resolution changes** (abilities that buff, penalise, jam or rewrite
  during resolution): **neither.** They shape the *next* roll
  (`skip_next_tick`). The acted-on values are snapshotted at `resolve_step`, and
  the dice stop following logic at resolution, so they never change a die in
  the round they are cast.

### Modifier indicators that exist today (report only; nothing built)
- **Unit card:** a net ±Roll chip in the status row (`battle_card_view.gd`,
  `type: "roll"`), plus Jam and Rewrite chips.
- **At the die, transient:** a "+N" float spawns just above the die when a roll
  buff is *cast* (`battle_feedback.gd`, roll_buff float). It fades, so it isn't
  there at the next roll.
- **On the die, persistent:** the freeze/petrify crust with a FROZEN or PETRIFIED
  label, the jam tint with a "JAM <=N" marker, and "REWRITE->3" / "HIJACK" pending
  markers (`dice_tray_3d.gd`, `_set_die_*`).
- **Nothing near the die** shows an active ±roll buff or penalty at roll time, a
  pending forced 20, or Resonant Chorus. Those appear only as the card chip or
  in the battle log.
