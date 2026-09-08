# Two-encounter tutorial

## Task / context
Implement G-14: normal combat training with independent choices, reward learning,
optional Burn/item practice, and permanent Engineer Overdrive damage 10.
Read TRUTH, INVARIANTS, DECISIONS, game reference and task queue.
Baseline full gate: debug_artifacts/tutorial_baseline_isolated.log. The initial
attempt could not write Godot user logs under the sandbox; tests use an isolated
APPDATA beneath debug_artifacts, never the player's profile.

## Constraints
Deterministic inputs, unchanged combat rules and enemy stats, stable IDs, compact
footer, no persistent training inventory/progression. No baseline repinning.

## Change
Core encounter uses the real 35-HP Scrap Drone. Guided first round: Mark then
10 damage becomes 15; Medic protects Strike. Second round: Nudge Strike 8→11,
Engineer shields and Medic heals. Drone survives with 10 HP naturally. Open
third round offers damage, protection, targeting/order and Protocol choices.
Second encounter introduces Pulse Tech and two Scrap Drones, using live Burn
and consumables. Reward choice and optional continuation use real inventory.

## Verification / report
Full gate: all hard gates PASS (`debug_artifacts/training_final_gate2.log`).
Ability audit: 272 passed / 0 failed. Tutorial smoke also passes independently
after adding missing-roll recovery, real Burn tick and first-item acknowledgement
coverage (`training_smoke_final.log`). Native 390×844 render/playthrough passes
(`training_capture_checked.log`); footer remains clear of HP bars. Reward model,
component, capitalization and doc checks pass after the final presentation edits.

Matched 300-run gate simulations, changes versus the untouched working tree:

| Operation ID | Before | After | Change (points) |
|---|---:|---:|---:|
| facility | 38.03% | 36.62% | -1.41 |
| hive | 32.20% | 28.81% | -3.39 |
| stellarMenagerie | 20.83% | 20.83% | 0.00 |
| veil | 29.23% | 32.31% | +3.08 |
| voidCirclet | 24.56% | 24.56% | 0.00 |

Overall: 29.67% → 29.33%. Small per-operation samples, not a precise balance estimate.
The untouched tree already exceeded pinned-baseline tolerances in Facility and
Veil; Facility remains beyond the pinned tolerance after this change. No baseline
updated and no enforcement threshold changed. No current-task delta exceeds ±10.

## Presentation and limits
Coach text uses 60 design pixels, the real Mark/Burn glyphs and lighter dimming.
Nudge/Items explanations use the center gap. Roll/End Turn explanations use upper
portrait artwork, leaving the central button and enemy dice unobstructed.
Training failures offer retry or start-run, without recording a normal defeat.
Training completion and voluntary exit enter the squad picker; no mandatory
selection-screen lesson was added. Physical phone and Web release checks remain V06.
The current interaction supports inspection for help during independent play;
there is no separate solution-revealing hint button. Item use in practice is
encouraged, optional, and charged at the normal cost.

Reviewed 390×844 captures: [Mark](visuals/2026-09-08-training/battle1-step5.png),
[End Turn](visuals/2026-09-08-training/battle1-step8.png),
[Nudge](visuals/2026-09-08-training/battle1-step12.png),
[Burn](visuals/2026-09-08-training/battle2-step3.png),
[optional continuation](visuals/2026-09-08-training/reward-choice.png).

## Closeout
TRUTH, G-14 and the task queue describe the implemented flow. Live game changes
are ready for player iteration; no release upload or baseline refresh is included.
