# Title and unlock polish — 9 September 2026

Task: implement G-19 / V11. Canonical context and closed rulings reviewed;
untouched `verify_gate.py --skip-sim` passed before editing.

Changes:
- Title retains BEGIN and amber FEEDBACK; removes duplicate TUTORIAL and the
  "Tell me what to fix" overlay. First Begin still presents the tutorial choice;
  Help / BASICS retains replay. Feedback still uses its synchronous tap handler.
- Remove the unused nudge cadence helpers; old settings are harmless and save
  format/counters remain compatible. Replace its obsolete cadence regression
  with actual title entry and unlock layout checks in the full gate.
- Unlock title/panel center as a compact group when all content fits. Otherwise
  the full-height scrolling viewport remains. Continue stays at the bottom,
  item icons keep their sizes, and viewport changes trigger remeasurement.

Constraints: no combat, data, progression, font, battle-header or footer change;
no Angular changes. Existing reward section order and inspect behavior remain.

Verification: `scripts/debug/title_unlock_test.gd` covers the two title actions,
absence of the removed buttons even with old cadence settings, first-run
tutorial, returning-player Begin, Help replay, single/boss-only/large awards,
large-list scroll reach, horizontal containment, bottom Continue and resize.
The native 390×844 capture pass reported `[TITLE_UNLOCK] PASS` with no script
errors. Visual inspection caught and corrected CenterContainer's minimum-size
behavior for long lists; the regression now also requires a useful tall viewport.

Reviewed native captures:
- [Title](visuals/2026-09-09-title-unlocks/title.png)
- [First-run choice](visuals/2026-09-09-title-unlocks/first-run.png)
- [Small award](visuals/2026-09-09-title-unlocks/unlock-single.png)
- [Boss relic only](visuals/2026-09-09-title-unlocks/unlock-boss.png)
- [Large list](visuals/2026-09-09-title-unlocks/unlock-fat.png)
- [Large list scrolled](visuals/2026-09-09-title-unlocks/unlock-fat-bottom.png)

No balance surface changed; per-operation deltas are not applicable and the
baseline remains untouched. V06 current-export/physical-device checks remain
open.

Closeout (10 September): final `python scripts/verify_gate.py --skip-sim`
passed all hard gates, including title/unlock, ability audit, scene flow and
the two-battle tutorial. Separate DiceTrayPhysicsProbe passed eight rolls
with zero penetrations, flyovers, frozen drift or tilted rests. Logs:
`debug_artifacts/v11-review/final-gate.log`, `native-test.log`, `physics.log`.
`git diff --check` passed. Existing missing audio clips and certificate-store
warnings remain unrelated to this change.
