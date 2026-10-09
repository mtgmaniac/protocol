---
description: Run the full verification gate and report the sim tripwire and, if it moved, the size check
---

Run the full verification gate:

```
python scripts/verify_gate.py
```

(`--skip-sim` for a fast hard-gates-only pass.)

Then report to the user:
1. PASS/FAIL per gate (validate-data, ability audit, flow smoke, tutorial smoke, freeze regression).
2. The sim leg (two tiers, G-58). If the tripwire did not move, say so: combat is
   unchanged. If it moved, say that combat changed and do NOT quote the size of the
   move on the 300-run tripwire; report the 1,500-run size table verbatim instead.
3. If the size check is beyond the line (8 points on an operation, 4 overall): state
   loudly that the baseline ceremony applies (docs/INVARIANTS.md #9) — report the size
   table and STOP. Do not run `ci_smoke.py --update-baseline`, and do not add
   BASELINE-APPROVED-BY-KEV yourself; only Kev issues that token.
4. If numbers were tuned to a target, report a second seed base too (INVARIANTS #8).
