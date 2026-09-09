# Icon Guide — 9 September 2026

Task: add the reviewed Icon Guide to Help (G-17).

Context: TRUTH, INVARIANTS, DECISIONS_RESOLVED, task queue and visual bible
reviewed. Untouched `python scripts/verify_gate.py --skip-sim` passed.

Change: ICON GUIDE occupies the ninth slot in the existing three-column Help
navigation. ACTIONS explains the four compact footer icons, standard costs,
cost modifiers and free inventory opening. EFFECTS shows damage, heal, shield,
Burn and Mark; Burn/Mark definitions come from the canonical keyword registry.
MORE EFFECTS opens the full keyword reference. Switching sections resets scroll.

Constraints: preserve current font/header (Kev selected A), compact footer,
combat, IDs, save format and existing keyword meanings. No Angular edits.
Battle-prompt proposals are not included in the guide-only approval.

Verification: `scripts/debug/icon_guide_capture.gd` exercises tab navigation,
both guide sections, icon loading, content-width containment, More Effects,
scroll reset and dismissal. Native 390×844 captures were visually inspected:
[Actions](visuals/2026-09-09-icon-guide/actions.png) and
[Effects](visuals/2026-09-09-icon-guide/effects.png).

No balance surface changed; simulation deltas are not applicable and the
baseline is untouched. Physical-device and current web-release verification
remain open.

Closeout: final `python scripts/verify_gate.py --skip-sim` passed all hard
gates, including the ability audit, scene flow and two-battle tutorial.
Separate DiceTrayPhysicsProbe: 8 rolls, zero penetrations/flyovers, zero
frozen drift, zero tilted rests. Logs: `debug_artifacts/icon-guide/final-gate.log`
and `debug_artifacts/icon-guide/physics.log`. Native capture/navigation runner
reported `[ICON_GUIDE] PASS` with no script errors after correcting its startup
load order. Existing missing audio clips and certificate-store warning remain
separate from this UI change. `git diff --check` passed.
