# Battle depth prototype — 2026-10-13

TASK: Test one environmental tray and cosmetic dice depth on
`codex/battle-depth-prototype`, then stop for visual review.

STEP 0 — CONTEXT: Read TRUTH, INVARIANTS, DECISIONS_RESOLVED, the runtime reference,
TASK_QUEUE and TASK_TEMPLATE. Branched from the current `codex/battle-ui-pixel-restyle`
checkout with its existing uncommitted component work preserved. No commits made.

CONSTRAINTS: Invariants 1 (positions never affect combat), 7 (PixelUI owns colors),
10 (documentation), 11 (portrait layout) and 14 (physical pixel snapping). Existing
cards, header, actions, portrait/dice art, physics and combat remain as found.

CHANGE: A code-drawn shallow metal bay inside the current tray rectangle; no new
asset generation. The existing die cosmetic container combines its settle scale
with a clamped 0.90–1.10 projected-y multiplier, independent of rigid bodies and
collision shapes. Bounds already read that cosmetic scale, so die tags and hit
regions follow it. Shadows are translucent ellipses behind the dice viewport;
they vary with depth and hop height. No perspective camera or new physics system.

VERIFY:
- Godot 4.6.2 import/load and actual rendered capture completed without script errors.
- `component_contract.py`: PASS. `git diff --check`: PASS.
- `roll_button_clearance_test.gd`: PASS; hero gap 42.3 px, enemy gap 52.2 px
  against the existing 40 px floor.
- Eight-roll physics probe: zero penetration, zero frozen drift, zero tilted rests;
  10 flyover events. The original script reported 0 in a separate ordinary run.
  A fixed-60-fps comparison reported 101 original / 60 prototype flyover samples,
  both still with zero penetration, frozen drift and tilted rests. This probe is
  timing-sensitive here; it does not establish a clean zero-flyover pass or identical
  trajectories. No physics parameters were changed to chase its result. Logs are
  `debug_artifacts/depth_{baseline_,}physics.log` and
  `debug_artifacts/depth_{baseline_fixed,physics_fixed}.log`.
- Screenshot: `debug_artifacts/battle_depth_prototype.png` (1080 x 2400).
- Relevant checks only, per canonical TRUTH / G-59. No balance changes or sim run.

REPORT: No baseline pins changed. Visual prototype only; no balance delta claimed.
The physical footprint stays constant while visible size varies by up to 10%,
so apparent contacts can differ slightly from exact mesh edges during a throw.

CLOSEOUT: TRUTH and DECISIONS_RESOLVED updated; first rendered treatment retained
for review. No follow-on UI restyle or visual iteration performed.
