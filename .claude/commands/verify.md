---
description: Run the full verification gate and report per-op clear-rate deltas vs baseline
---

Run the full verification gate:

```
python scripts/verify_gate.py
```

(`--skip-sim` for a fast hard-gates-only pass; `--runs 100` for a quicker, noisier sim.)

Then report to the user:
1. PASS/FAIL per gate (validate-data, ability audit, flow smoke, tutorial smoke, freeze regression).
2. The per-operation clear-rate delta table verbatim.
3. If any per-op delta exceeds ±10 points: state loudly that the baseline ceremony applies
   (docs/INVARIANTS.md #9) — report the deltas and STOP. Do not run
   `ci_smoke.py --update-baseline`, and do not add BASELINE-APPROVED-BY-KEV yourself;
   only Kev issues that token.
