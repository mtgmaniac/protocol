# Restore the compact battle footer

TASK: Restore the pre-step-1 icon-only footer after the enlarged buttons overlapped friendly health bars.

## Context

Read TRUTH, INVARIANTS, DECISIONS_RESOLVED, AI_AGENT_GAME_REFERENCE, TASK_QUEUE and TASK_TEMPLATE. The untouched pre-restoration tree passed `python scripts/verify_gate.py --skip-sim`. Recorded the user's superseding decision as G-11 before runtime edits.

## Constraints and change

Preserved the portrait layout (invariant 12), deterministic combat (1), stable IDs (11) and verification thresholds (13). This is a narrow restoration of the previous footer dimensions and styling: 112×112 design-pixel buttons, no permanent word labels, and original bottom-right costs. Removed the unused caption helper. Other step-1 changes remain, including Twin Fates removal.

## Verification

Captured the real battle with Strike, Engineer and Splice using Godot 4.6.2's Compatibility renderer at 537×1195 (the user's editor-window dimensions) and 390×844. Measured the actual footer panel top against every hero card's bottom after layout settled:

| Viewport | Before | Restored |
|---|---:|---:|
| 537×1195 | -25.5 design pixels: overlap | +6.5 design pixels: clearance |
| 390×844 | — | +5.0 design pixels: clearance |

Visually checked both captures: health bars are clear, and the footer fits on screen. The remaining gap is intentionally compact, approximately 3 and 2 screen pixels respectively. No physical phone test was performed.

- [Restored footer at 537×1195](visuals/2026-09-06-footer-restore/battle-537.png)
- [Restored footer at 390×844](visuals/2026-09-06-footer-restore/battle-390.png)

Post-restoration `python scripts/verify_gate.py --skip-sim`: **all hard gates PASS**, including protocol cancellation, roll-button clearance, safe area, tutorial and scene-flow checks. Verification and closeout completed 2026-09-07.

## Balance report and closeout

No balance surface changed; simulation skipped under TASK_TEMPLATE's UI-only allowance. No baseline update or balance-delta claim. TRUTH, G-11, the visual bible and the earlier implementation report now identify the compact footer as current. No merge, push or Web re-export performed.
