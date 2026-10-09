# Handoff 2026-10-09: two-tier sim gate

Ruling: G-58. Built as proposed in G-57, merged to `main`. No itch build.

## What the gate's sim leg does now

| | Tripwire | Size check |
|---|---|---|
| When | Every full gate | Only for a policy whose tripwire moved |
| Runs | 300 per policy | 1,500 |
| Policies | `l1` and `l1_evo2` | The one that moved |
| Time | About 75 seconds | About 3.5 minutes each |
| What it says | Any move means combat changed. The size is unreliable and is not judged | Beyond 8 points on an operation or 4 overall is the ceremony (exit 3) |

- An unchanged tree reproduces all four pins exactly.
- Inside the line the gate passes and says to re-pin. A re-pin inside the
  line needs no token; beyond it the commit hook asks for yours.
- `python scripts/sim/ci_smoke.py` runs the same two tiers alone.
  `--update-baseline` re-pins all four together.

## Pins

| Pin | `l1` tripwire (300) | `l1` size (1,500) | `l1_evo2` tripwire (300) | `l1_evo2` size (1,500) |
|---|--:|--:|--:|--:|
| Overall | 0.2600 | 0.2653 | 0.2900 | 0.2760 |
| Facility | 0.2958 | 0.3246 | 0.3944 | 0.3770 |
| Hive | 0.3390 | 0.3079 | 0.4068 | 0.3238 |
| Veil | 0.3231 | 0.2606 | 0.2769 | 0.2866 |
| Signal Purge | 0.1579 | 0.2391 | 0.1930 | 0.2029 |
| Mantle Hunt | 0.1458 | 0.1886 | 0.1250 | 0.1785 |

`baseline.json` is the `l1` tripwire, unchanged. `baseline_pins.json` is new
and holds the other three with a tie to the first file. The gate and the
commit hook refuse pins that were not written together.

## The deliberate break: gate `sim size break`

- **On made-up figures:** 8.0 on an operation passes, 8.1 does not; 4.0
  overall passes, 4.1 does not; one run's worth on one hero is a tripwire
  move; untied pins are refused; the hook agrees with the gate. Four breaks
  must each fail it: the operation line back at 10, the overall line at 10, a
  tripwire that never reports, an unchecked tie.
- **A real change through the real size check:** +8% enemy damage in the
  Hive. It costs the Hive 9.8, 8.9 and 10.3 points on three 1,500-run seed
  sets. On the pinned runs it reads -9.8 and is flagged.
- **The same change under the old check:** -6.8 on the pinned 300 runs,
  inside the old 10-point line. The old gate would have passed it.

## Checked end to end

Three runs of the real tool with temporary data changes, put back after:

| Change | Tripwire | Size check | Exit |
|---|---|---|--:|
| None | No move, both policies | Not run | 0 |
| Pyro's Backdraft 16 to 14 | `l1` moved, `l1_evo2` did not | Inside the line (largest: Veil -2.0) | 0 |
| Hive Matriarch +4 on three attacks | Both moved | Hive -10.8 and -11.4, beyond the line | 3 |

The second row shows why the tripwire's size is not read: it showed Hive
-5.1, and the size check put the same change at -0.9.

The commit hook was checked the same way: pins staged together pass; a
tripwire re-pinned alone is refused; a size pin moved 10 points is refused
without the token and passes with it.

## Things to decide or know

- **The break gate adds about 4 minutes to every full gate** (a 300-run
  tripwire and one 1,500-run batch). If that is too much, its real leg can run
  only when `ci_smoke.py` or the pins change; the made-up part is instant.
  Your call. The tripwire itself is 75 seconds where the old leg was 36.
- **The size check is better, not perfect.** One operation in 1,500 runs is
  about 300 runs, and a real move still reads 2 to 4 points either way. In the
  same calibration, -7% enemy damage in Veil (a real move of about 9 points)
  read +8.1, +7.3 and +12.6: one seed set in three stayed inside the line. A
  real 10-point move on one operation is caught most of the time; 12 and over
  reliably. A change that moves every operation trips the 4-point overall line
  much sooner.
- **`--runs` is gone** from `verify_gate.py` and `ci_smoke.py`. A tripwire on
  another run count cannot reproduce a pin.
- **Process rule** is INVARIANTS #8: numbers tuned to a target are also
  reported on a second seed base.

## Found while gating: `tutorial smoke` was flaky

It failed once in the first full gate and passed alone, three times of three.

- **Cause.** Its last check wants to see Pulse Tech's round-one burn tick in
  the practice battle. The burn ticks at the end of round two, and round two
  is free play on live dice. If the heroes kill the burned drone first, or
  Pulse rolls its Detonate on it, nothing ticks. About one run in eight since
  the 2026-10-08 windows (1 of 8 today; my estimate).
- **Not a player problem.** The tutorial only adds its "Watch Burn deal
  damage" line when a burned enemy is alive.
- **Fix.** For that one round the test sets each hero's die to its kit's
  gentlest roll, read from the kit, until the tick has been seen.
- **One line of game code changed** for it (`battle_scene.gd`): in tutorial
  mode the scene sets the dice tray's requested faces only when the round has
  a plan. It used to set an empty plan on free rounds, which wiped a test's
  request. Play is the same: the tray clears its requests after every throw.
- **My first fix did nothing**, because of that wipe, and six passes in a row
  hid it. I caught it by printing the dice, then re-checked: three runs, the
  gentle rolls landed and the burn ticked each time.

## Gate

- **First full gate** (on `47a435b`): 81 of 82 hard gates and profile
  isolation passed. `tutorial smoke` failed (the flake above). The sim leg
  did not run: the gate stops before it when a hard gate fails.
- **Second full gate** (on `cf30e31`, after the fix): stopped at Kev's
  instruction while healthy, at 62 gates passed and none failed, `tutorial
  smoke` among the passes. Not rerun, as told.
- **Run instead, as told, on `cf30e31`:** `tutorial smoke` three times, all
  pass; `validate-data`, pass; the two-tier sim gate, no move on either
  policy, exit 0; `sim size break`, pass in 222 seconds, the Hive flagged at
  -9.8.
- **Not run since the one-line `battle_scene.gd` change:** the 19 gates the
  second run had not reached (reroll hop, auto-select target, no animations,
  nudge cast order, action motion, firewall feedback, accrete display, cloak
  ambush, roll windows, roll windows live, web loader palette, web display
  recovery, wording fit, text legibility, checkpoint lifecycle and the four
  framing gates). All 19 passed in the first full gate, one commit earlier.
- Godot ran from the scratch copy through `GODOT_BIN`, with `APPDATA` on a
  scratch folder (the editor is open on the project).
