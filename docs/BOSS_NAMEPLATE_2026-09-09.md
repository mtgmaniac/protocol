# Boss nameplate C — 9 September 2026

Task: implement Kev's approved filled boss nameplate (G-18).

Context: canonical guidance and closed rulings reviewed; untouched fast gate
passed before editing (`debug_artifacts/boss-review/baseline-gate.log`).

Change: battle-card presentation derives boss identity from the existing
standing-rule registry. PixelUI owns the copper fill and dark ink. BOSS sits
above the callsign inside the existing 80-design-pixel name strip. Fixed
content bounds prevent either line from expanding the card. Dead bosses dim.
Ordinary enemies/heroes and selection/targeting borders keep their styling.

Constraints: no combat, data, IDs, portrait art, HP geometry, status-chip,
corner-badge or footer changes; no Angular code touched. This implements the
approved rank treatment without adding a seventh frame component.

Verification: `scripts/debug/boss_nameplate_test.gd` covers all five actual
boss encounters, registry-derived identity, ordinary enemies/heroes, unchanged
portrait/HP/name-strip bounds, selection border precedence, and dead styling.
It is included in the full gate. Native 390×844 captures were visually reviewed:

- [Scrapmaster](visuals/2026-09-09-boss-nameplate/facility.png)
- [Hive Matriarch](visuals/2026-09-09-boss-nameplate/hive.png)
- [Conclave Overseer](visuals/2026-09-09-boss-nameplate/veil.png)
- [Root Hierophant](visuals/2026-09-09-boss-nameplate/voidCirclet.png)
- [Mantle Tyrant](visuals/2026-09-09-boss-nameplate/stellarMenagerie.png)

No balance surface changed; per-operation simulation deltas are not applicable
and the baseline is untouched. Native capture does not close V06 web/physical
device verification.

Closeout: final `python scripts/verify_gate.py --skip-sim` passed all hard
gates, including the new boss regression, ability audit, flow and tutorial.
Separate DiceTrayPhysicsProbe passed eight rolls with zero penetrations,
flyovers, frozen drift or tilted rests. Logs are `debug_artifacts/boss-review/`
`final-gate.log` and `physics.log`. Native captures had no script errors;
existing missing audio clips and certificate-store warnings are unrelated.
`git diff --check` passed.
