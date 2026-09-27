# Tutorial real throws and physics Reroll

Branch: `codex/tutorial-real-rolls`. Main was fast-forwarded to the approved
`d5c25e1` and pushed first. This follow-up is not merged or web-exported.
The balance baseline, enemy data and gate thresholds are unchanged.

## Outcome safety

Actual BattleEngine simulations used 1,000 seeds per battle under each of two
policies, 4,000 battles total. All four cases had zero losses and zero stalls.
The same seeds are paired across policies, not independent extra samples.

| Battle | Policy | Loss rate | Stalls | Median victory round | Max victory round |
|---|---|---:|---:|---:|---:|
| 1 | Basic | 0/1,000 (0%) | 0 | 3 | 7 |
| 2 | Basic | 0/1,000 (0%) | 0 | 4.5 | 7 |
| 1 | L1 | 0/1,000 (0%) | 0 | 3 | 5 |
| 2 | L1 | 0/1,000 (0%) | 0 | 4 | 7 |

These are engine simulations with seeded free dice, not 4,000 UI playthroughs.
Stalls mean no legal target or exceeding 200 rounds. The existing SCRAP data
and retry prompt remain. See [methods and raw results](TUTORIAL_OUTCOMES_2026-09-27.md).

## Runtime behavior

Only battle 1 rounds 1–2 and battle 2 round 1 are scripted. Their requests live
in `scripts/battle/tutorial_roll_plan.gd`; every later round uses normal live
physics. The post-landing tutorial override is deleted. The gate verifies
free tutorial raws reach combat unchanged.

Scripted rounds replay recordings of the live tray's own launch and settling
path. A visual-mesh rotation before frame zero makes the requested face land
up, without changing labels during motion. The visible landed face supplies
the raw result, then the normal same-face upright snap runs. Four variants
are chosen randomly; all slots in one throw share a variant so their recorded
collision paths remain consistent. Recorded impacts drive the existing audio.

Hero Reroll, Phase Scrambler and Cascade Jammer physically rethrow affected
unfrozen dice, with modifier labels printed before launch. The pending battle
checkpoint is updated after settlement and payment/item consumption. Restoring
it preserves the rerolled result and other dice's Nudge/Set state without
reapplying roll-start effects. Frozen dice refuse alteration.

## Recorded motion measurements

The dev tool `scripts/debug/record_tutorial_throws.gd` calls the normal live
tray with no rig. It samples body position and quaternion every physics frame
at 120 Hz, ending at the live settle decision before the upright snap.
There are eight real throws per enemy-count group: four saved variants and
four additional measurement throws. In total: 24 throws, 128 measured die
trajectories, 64 saved tracks, approximately 1.61 MB including measurements.
The four-enemy group supports existing seven-die regression fixtures.

| Enemies | Measured die trajectories | Live settle time (s) | Live travel (world units) |
|---|---:|---:|---:|
| 1 | 32 | 2.525–3.783333 | 5.72845–23.34142 |
| 2 | 40 | 2.616667–3.608333 | 5.45294–27.08719 |
| 4 | 56 | 2.900–3.266667 | 4.84205–18.89087 |

The gate checks each playback die against its own slot's live range, rather
than only the aggregate ranges above. Tolerances are 0.02 world units and
0.05 seconds for sampling and interpolation. It also checks that recorded
tray bounds match the actual tutorial scene. Live measurements are committed
in `data/tutorial_throws/live_measurements.json`; the clean final gate's
playback sample is in `TUTORIAL_PLAYBACK_2026-09-27.json`.

In that sample, battle 1 playback settled at 3.041667 seconds with travel
11.08611–16.15142 world units; battle 2 settled at 2.650 seconds with travel
8.70821–12.33274. All individual slots passed their own live-range checks.

Regenerate recordings after changing live launch, tray geometry or physics:

```powershell
& $Godot --headless --path . --script scripts/debug/record_tutorial_throws.gd
& $Godot --headless --path . --script scripts/debug/tutorial_throw_gate.gd
python scripts/checks/tutorial_throw_mutations.py
```

Set `$Godot` to the installed Godot 4.6.2 console executable. Run these serially
with the full gate; it terminates stale headless Godot processes at startup.

## Copy inventory

1. YOUR PLAN retains “Choose your targets and attack order. Spend Protocol if
   useful.” It appends “Watch Burn deal damage at the end of this turn.” only
   while an enemy is alive and burning when the beat appears.
2. REROLL changes “You have 2 Protocol.” to “You have enough Protocol to
   reroll.” Its remaining cost and action explanation is unchanged.

Full inventory: [tutorial copy](TUTORIAL_ROLL_COPY_2026-09-27.md).

## Verification

`python scripts/verify_gate.py`: exit 0, all hard gates and profile isolation
PASS. This includes tutorial smoke (47 s), recorded throws (20 s), real-input
tutorial reachability, dice face (50 s), enemy reroll visuals, and the expanded
cross-process battle checkpoint gate (220 s, within its existing 360 s limit).
The pinned 300-run sim completed with zero failed runs. No threshold changed.
Log: `debug_artifacts/tutorial_rolls_final_gate_v3.log`.

| Operation | Pinned clear rate | Current 300-run clear rate | Delta (percentage points) |
|---|---:|---:|---:|
| facility | 36.62% | 40.85% | +4.23 |
| hive | 22.03% | 23.73% | +1.70 |
| stellarMenagerie | 16.67% | 22.92% | +6.25 |
| veil | 24.62% | 26.15% | +1.53 |
| voidCirclet | 21.05% | 21.05% | 0.00 |

Overall: 25.00% to 27.67%. All operations are within the unchanged ±10-point
limit. These match the prior dice branch's reported 300-run comparison; the
historical baseline is unchanged and was not re-pinned.

`DiceTrayPhysicsProbe.tscn`: exit 0; eight throws, zero penetration/flyover
events, zero frozen drift, zero tilted or corner rests. Average settle 3.10 s,
maximum 3.51 s. Log: `debug_artifacts/tutorial_rolls_physics_probe.log`.

The recorded-throw gate covers all three scripted rounds, requested top faces,
static labels on every playback physics frame, slot-specific live travel/time
ranges, and actual unrigged free launches. It also checks alive, dead and
cleared-Burn reminder conditions. Deliberately corrupting the scripted top and
an in-flight label both produces the intended gate failure: 2/2 detected,
without script errors.

The expanded dice-face gate covers physical rerolls and static in-flight
labels. The checkpoint gate uses separate processes to verify hero and enemy
item rerolls restore the same pending dice, payments and consumed inventory.

The first final gate exposed a newly added Roll input guard that also blocked
the initial throw. The guard now rejects only a tray actively rolling. The
fresh full run includes both tutorial smoke and real-input reachability.
The checkpoint comparison also exposed a stale enemy target after rerolling
from an attack to a support ability. Reroll now clears that die's old target
before recalculating intents, so live and restored target state agree.

Visual feel, audio feel and physical-phone rendering still require Kev's
review in Godot/on device. Headless transform checks do not claim visual
approval. No web build was produced.
