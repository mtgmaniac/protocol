# Two-encounter tutorial

## Copy and inspection follow-up
Approved player-facing rewrite: explain battlefield positions and the central Roll button, explain Strike’s rolled 9 beside its ability, shorten enemy intent, remove the results state, introduce completed-turn income beside Nudge, simplify victory/optional continuation, clarify next-turn Burn and future keyword primers. All tutorial instructions use Splice. Alternate legal targets remain allowed.

Inspection redirects now receive the visible die rectangle and emphasize the portrait too; they no longer use the invisible pip-inclusive hit area for this lesson. The smoke test sends wrong-unit input and verifies both redirect rectangles, visible pulses, and that inspection remains required. Combat rules, stats and rigged results are unchanged.

Phone-size reviewed captures: [inspection](visuals/2026-09-08-tutorial-copy/battle1-step4.png), [income and Nudge](visuals/2026-09-08-tutorial-copy/battle1-step12.png), [Burn](visuals/2026-09-08-tutorial-copy/battle2-step4.png).

Baseline: all hard gates PASS with `--skip-sim` (`tutorial_copy_baseline.log`). No balance-sim surface changed; no baseline repinning.

Verification: final gate (`tutorial_copy_gate.log`) passed every check except an obsolete exact-copy assertion in unlock progression. Replaced that required old sentence with checks against misleading higher-is-always-better claims; the complete unlock progression test then passed (`tutorial_copy_unlock_recheck.log`). All required checks now pass. Native 390×844 full playthrough and inspection redirect checks also PASS (`tutorial_copy_capture.log`).

## Current revision — G-15
Welcome now precedes the controls. Battle one uses Strike 9 / Engineer 12 / Medic 2: 6 + 10 damage, heal and shield; it teaches no Mark or Burn. Nudge on turn two leaves 9 HP for independent turn three. Battle two uses Strike / Pulse / Medic. Mark raises Pulse’s 6 damage to 9, with 2 Burn resolving on the following turn. Subsequent turns offer normal target, order and spending choices.

Inventory copy uses “inventory” and highlights only the bottom-right button. Reroll receives a single optional tip after rolling with 2 Protocol and an unfrozen, unassigned die. The ending mentions more effects to discover and thanks the player before squad selection. Repeated starting-Protocol and training-reward disclaimers are removed; training inventory still clears on exit.

Untouched baseline: all hard gates PASS with `--skip-sim` (`training_revision_baseline.log`). This revision changes training inputs and teaching only; no authored stats, normal combat rules, sim knobs or baseline changes. New combat regressions verify 6→9 Mark damage and the real delayed 2 Burn tick. The tutorial playthrough checks independent turn three, optional continuation/exit, inventory use, one affordable Reroll notice and completion.

Verification: all hard gates PASS with `--skip-sim` (`training_revision_gate.log`), including the revised combat audit and tutorial smoke. Native 390×844 playthrough PASS (`training_revision_capture.log`). No balance sims needed for this training-only revision.

Reviewed 390×844 native captures: [welcome](visuals/2026-09-08-training-revision/battle1-step0.png), [Burn](visuals/2026-09-08-training-revision/battle2-step4.png), [inventory](visuals/2026-09-08-training-revision/battle2-step7.png), [completion](visuals/2026-09-08-training-revision/battle2-step12.png).

The original G-14 implementation and its balance report below are historical; G-15 above supersedes its tutorial sequence.

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
