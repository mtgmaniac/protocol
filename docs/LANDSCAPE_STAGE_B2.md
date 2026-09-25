# Stage B2 — landscape card and dice readability

Implemented 2026-09-25 after Kev's Stage B approval. Stop for visual review at
this checkpoint. Horizontal HP is the default; a vertical-bar comparison is
available through the same card's presentation API for the capture harness.

## Context and constraints

Read TRUTH, INVARIANTS, DECISIONS_RESOLVED, AI_AGENT_GAME_REFERENCE and the task
queue/template. Stage B is the immediate implementation baseline. The original
committed 1080×2400 configuration at 9315334 is the portrait regression baseline.
Work remains in the isolated codex/landscape-battle-layout checkout. The original
checkout and its unrelated dirty 640×960 viewport change are untouched.

One BattleScene, one CompactUnitCard, the same dice/readout/Protocol controls and
callbacks. No global theme, viewport, stretch, orientation or export-setting
changes. No combat, RNG, data, save, progression, tutorial or asset changes.
Invariants 1 (determinism), 5 (legibility), 10 (documented changes) and 14
(portrait configuration) remain intact. LANDSCAPE_BATTLE_ENABLED stays false.
The existing unlocked debug setting can force the next battle into landscape;
release ignores that setting. AUTO tutorial stays portrait.

## Change

- `landscape_battle_style.gd` is the single table of landscape presentation
  sizes, gaps, camera projection and readout wrapping preferences.
- `landscape_card_layout.gd` only places the existing CompactUnitCard controls.
  It reparents the same portrait, name strip, HP number/bar and status row. The
  portrait fits its native aspect; statuses occupy the information column.
  HP animation, forecasts, input, cast badges and inspection are reused.
- The horizontal HP default provides more room for status chips. The optional
  vertical comparison rotates that same HP bar and its existing forecast
  layers, with the HP number above. There is no second card component.
- Names and HP fit to the information column (88–108 design-pixel font); the
  status overflow marker is measured inside the available row width.
- Dice projection and readouts are approximately 1.6× Stage B. Dice lanes move
  inward; hero readouts sit left, enemy readouts right, vertically centered.
  Multi-effect readouts wrap at full size before the existing shrink fallback.
  Physics bodies, dice values and seeded outcomes are unchanged.
- Protocol's bar is centered, capped at 1800 design pixels and bounded by the
  tray width. Its label has explicit clearance. Two existing action buttons sit
  on each side, each 224×224. Their signal bindings and costs are unchanged.
- The shared Roll/End Turn control has a landscape-only footer band. A 3v2
  browser encounter demonstrated that enlarged, differently spaced dice leave
  no reliable common gap inside the tray. The dedicated band prevents overlap.

## Verification

- Dedicated layout regression: **1177 checks, 0 failures**. Covers policy,
  portrait restoration, 960/1280/1920 geometry, native portrait aspect, both HP
  variants, long names/three-digit HP/statuses, overflow containment, readout
  docking, non-overlapping input areas and Roll/End Turn clearance. Existing
  targeting, hold-to-inspect, lunges, summon/replacement and Brood cap remain
  exercised. Seeded hero rolls stay 12/7/8.
- Existing gate (`python scripts/verify_gate.py --skip-sim`): **52 passes, one
  known tutorial-reachability failure**, same result as Stage A/B and no new
  failing gate against the accepted 47-pass/6-failure baseline. The strict gate
  still detects the existing Windows root-certificate error. No failure fixes.
- Forced-landscape flow: **14 transitions pass**; existing resource-at-exit
  diagnostics remain. Normal physics probe: eight rolls, zero penetrations,
  flyovers, tilted rests or frozen drift. No balance surface changed, so no
  simulator rerun or per-operation delta table applies; no baseline updated.
- Final native screenshots: 1920×1080, 1280×720, 960×600; horizontal/vertical HP;
  Matriarch plus escort/Brood; synthetic long-name/status stress; tutorial AUTO
  and forced-landscape initialization; restored main menu.
- Portrait: fresh captures of the original committed source and final B2 at
  540×1200, 432×960, 390×844 and 1920×1080 are **entirely pixel-identical**.
  Historical baseline PNGs are retained separately. They show rendering-color
  differences under the current environment; the fresh control comparison
  isolates B2 changes without overwriting the historical evidence.
- Debug and release web exports succeed. Final browser captures additionally
  exercise real pointer targeting/cast order/forecast and a 3v2 encounter,
  including the clear End Turn band. Full exported-browser evidence is in the
  accompanying Stage B2 gallery/report outside the repository.

## Non-battle audit — capture only

Fifteen views were captured at both 960×600 and 1280×720 (30 screenshots): main
menu, squad select, four Help tabs, full loadout, rewards, evolution, directive,
route fork, intercept, victory, defeat and unlocks. No source for these screens
changed. Shared header presentation restores when landscape battle exits.

| Screen | Observed at the requested sizes |
|---|---|
| Squad select | Compact central roster, small labels/lore, particularly at 960; unused surrounding width. No obvious overlap. |
| Full loadout | Narrow panel and very small dense text at both sizes; four consumables and two relics fit. Flag for later work. |
| Help | Dense/small body text and targets; Units scrolls normally. Empty Battle Log fixture only. Flag readability, not demonstrated clipping. |
| Evolution / directive | Dense central choice columns with tiny text/buttons and unused width. Flag, especially 960. |
| Rewards | Small text but rows/action fit; no obvious overlap. |
| Route fork / intercept | Wide panels with small text/buttons; fit. |
| Run end, victory / defeat | Small dense summary; Continue remains visible. |
| Main menu / unlocks | Centered content fits; auxiliary copy small. |

Loadout and unlock screenshots use display fixtures. These checks establish
visible composition, not complete interaction or scroll-content coverage.

## Remaining limits

The pre-existing Nudge die-click cancellation is unchanged and documented by
the regression. Full forced-landscape tutorial support, physical devices,
other browser engines and production rollout remain unverified/out of scope.
The feature flag remains false; no push, deployment or itch.io change.
