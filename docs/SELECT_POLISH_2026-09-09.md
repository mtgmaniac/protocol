# Squad selection and tutorial copy polish

Task: implement G-16 without changing combat, unlock requirements or data IDs.

The empty dossier on locked operations retains its normal layout footprint and becomes transparent. Selecting the first hero restores its content without moving the squad grid. Locked hero names are blank with reserved label height; silhouettes and LOCKED remain. Unplayed encounters omit NO CLEARANCE, while real progress and locked status remain.

Tutorial copy uses SCRAP instead of drone and introduces battle two as learning new abilities. Deployment titles and field keys stay uppercase; site, situation and objective use sentence case with proper boss names.

Verification: untouched baseline and final `verify_gate.py --skip-sim` pass (`select_polish_baseline.log`, `select_polish_gate.log`). The final unlock test additionally verifies genuinely empty squad selection, identical before/after detail and grid bounds, hidden locked names and no clearance disclaimer (`select_polish_unlock_final.log`). Native 390x844 capture passes (`select_polish_capture.log`). No balance changes or baseline repinning.

Reviewed captures: [empty locked encounter](visuals/2026-09-09-select-polish/locked-empty.png), [first selection](visuals/2026-09-09-select-polish/locked-selected.png), [Facility](visuals/2026-09-09-select-polish/facility.png), [briefing](visuals/2026-09-09-select-polish/briefing.png).

TRUTH, task queue and G-16 updated alongside implementation. Physical-device checks remain separate.
