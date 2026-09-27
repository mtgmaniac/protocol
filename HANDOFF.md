# Overload Protocol — tutorial real rolls handoff

2026-09-27. Branch `codex/tutorial-real-rolls`; **do not merge or web-export**.
Kev approved the previous dice work through `d5c25e1`; main was fast-forwarded
there and pushed before this branch was created. The old dice rework is done.
This handoff supersedes the previous `dice-face-snap-p0` starting point.

Read `docs/TRUTH.md`, `docs/INVARIANTS.md`, `docs/DECISIONS_RESOLVED.md`, this file
and `TASK_QUEUE.md`. G-24 governs all dice; revised G-26 specifies recorded real
throws for the three scripted tutorial rounds. All approved rulings are closed.

## Outcome safety first

Actual BattleEngine simulations ran 1,000 seeds per battle under each of two
policies: 4,000 battles, zero losses and zero engine stalls. The same seeds
are paired across policies. Median/max victory rounds:

| Battle | Basic | L1 |
|---|---:|---:|
| 1 | 3 / 7 | 3 / 5 |
| 2 | 4.5 / 7 | 4 / 7 |

These are seeded engine simulations, not 4,000 UI playthroughs. SCRAP data and
the existing retry prompt remain unchanged. Full methods and raw results:
[TUTORIAL_OUTCOMES_2026-09-27.md](docs/TUTORIAL_OUTCOMES_2026-09-27.md).

## Completed work

| Commit | Step |
|---|---|
| `4ee386d` | 1: approved scripted/free schedule and rulings |
| `7d05a85` | 2: delete post-landing tutorial override; free later rounds |
| `4a72c7f` | 3: outcome simulation and results |
| `2ca0952` | 4: conditional Burn reminder and honest Reroll hint |
| `7d90891` | 5: real hero/enemy physics rerolls and checkpoint restoration |

Step 6 replaces generated tumbles with recorded live throws. Only battle 1
rounds 1–2 and battle 2 round 1 are scripted. The recorder uses the live
physics launch and tray; 24 throws produced 64 saved tracks and 128 measured
die trajectories. Four variants per slot share their selected variant across
the throw. Meshes are oriented before launch, labels stay static, the visible
top determines the result, and the normal same-face upright snap follows.

Hero Reroll, Phase Scrambler and Cascade Jammer physically rethrow affected
unfrozen dice. After settling, the checkpoint preserves pending raws, paid
costs, consumed items and other dice's Nudge/Set state. A fresh process restores
these dice without throwing again or duplicating roll-start effects.

The final integration also corrects the active-roll input guard so the first
Roll remains available, and keeps the engine's all-enemy reroll guard aligned
with frozen-repeat rules. Enemy rerolls clear their previous target before
recalculating intents, fixing attack-to-support target drift on refresh.

## Copy changes

1. YOUR PLAN appends “Watch Burn deal damage at the end of this turn.” only
   while an enemy is alive and burning when the beat appears. Its base text
   stays “Choose your targets and attack order. Spend Protocol if useful.”
2. REROLL: “You have 2 Protocol.” becomes “You have enough Protocol to reroll.”
   The remaining cost/action explanation is unchanged.

No other tutorial copy changed. See
[copy inventory](docs/TUTORIAL_ROLL_COPY_2026-09-27.md).

## Verification and remaining limits

**Implementation and automated verification are complete.** Full gate: exit 0,
all hard gates and profile isolation PASS, including real-input tutorial and
fresh-process reroll checkpoint restoration. The pinned 300-run comparison
has zero failed runs; overall clear is 25.00% to 27.67%, all operations within
the unchanged ±10-point limit. The physics probe passes eight throws with zero
penetrations, flyovers, frozen drift or tilted rests. Both deliberately broken
recorded-throw checks are detected. No baseline re-pin was performed.

The recorded-throw gate verifies the three scripted rounds' requested top
values, per-frame static labels, actual tutorial tray bounds, and per-slot
travel/time within measured live ranges. It also checks free physics launches
preserve the landed raw. Both deliberately broken criteria are detected.

Full measurements, exact commands and verification evidence:
[TUTORIAL_REAL_ROLLS_2026-09-27.md](docs/TUTORIAL_REAL_ROLLS_2026-09-27.md).
Old dice verification and 6,000-run balance evidence remain in
`docs/DICE_REWORK_VERIFICATION_2026-09-26.md` and
`docs/DICE_BALANCE_2026-09-27.md`; do not restart those tasks.

Kev's Godot visual review remains: throw feel, Reroll feel, sound timing,
tutorial transitions and refresh after Reroll. Physical-phone rendering and
web output are not visually verified. No web export was produced. The balance
baseline and enforcement thresholds have not changed.

Godot: `C:/Users/Kev/Downloads/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64_console.exe`.
Run gates serially: `verify_gate.py` kills stale headless Godot processes at
startup. These runs used normal Godot log-directory access; restricted log
access can crash the executable before tests start. Profile isolation remains
enforced. Regenerate recordings when live launch, tray or physics settings
change, then rerun the motion gate and mutation proof.
