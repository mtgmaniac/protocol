# Final feedback and casualty recovery — 10 September 2026

Task: implement Kev's approved Mark/Burn/arrival effects, remove repeated income copy from ITEM ACQUIRED, and recover previous-battle casualties at 75% HP. Source closeout takes priority; no release upload.

Context: started from clean main `d39866c` on `codex/final-feedback-revival`. Read canonical references and visual bible; recorded G-20 before editing. Untouched `verify_gate.py --skip-sim` passed. Determinism, authored in-battle revival, compact footer, existing fonts and legacy Angular remain unchanged.

Changes: shared BattleEngine startup applies 75% of updated max HP, floored with minimum 1, before explicit start damage. Survivors retain full recovery. Sim now records prior-battle casualties through the same GameState method as live play. Mark uses local acquisition corners; Burn application embers are distinct from its later damage tick. Applying Burn no longer shows a false damage number. Revive scans green; summons scan cyan after card layout. Decorative cues add no waits and respect Reduced Motion.

Verification: `final_feedback_test.gd` covers real scene startup with casualty/modifiers, survivors, minimum HP/rounding, actual authored item revival, cleared death history, cue lifetime, Reduced Motion and real summon injection/arrival. `feedback_honesty_test.gd` additionally proves Burn application leaves HP unchanged and the later tick emits real damage. Native 390×844 captures reviewed for portrait containment and unobstructed HP/footer. DiceTrayPhysicsProbe: 8 rolls, zero penetration/flyovers/frozen drift/tilted rests.

Reviewed native samples: [Mark](visuals/2026-09-10-feedback/mark.png), [Burn application](visuals/2026-09-10-feedback/burn.png), [Burn tick](visuals/2026-09-10-feedback/burn_tick.png), [Revive](visuals/2026-09-10-feedback/revive.png), [Summon scan](visuals/2026-09-10-feedback/summon.png). These sample the effect primitives on a portrait; the regression separately exercises real summon insertion.

Matched balance sample: 300 L1 runs per arm, seed base 900000, 8 workers; zero failed runs. Commands: `python scripts/sim/batch.py --name feedback_before_20260910 --runs 300 --policy l1 --seed-base 900000 --workers 8` and identical `feedback_after_20260910`, then `analyze.py results/<name> --metrics`.

| Operation | Before clear % | After clear % | Delta pp | Pinned baseline % |
|---|---:|---:|---:|---:|
| Facility | 36.62 | 29.58 | -7.04 | 50.70 |
| Hive | 28.81 | 22.03 | -6.78 | 28.81 |
| Stellar Menagerie | 20.83 | 16.67 | -4.16 | 16.67 |
| Veil | 32.31 | 24.62 | -7.69 | 40.00 |
| Void Circlet | 24.56 | 21.05 | -3.51 | 22.81 |

Overall 29.33% → 23.33% (-6.00 pp). No operation changed by more than 10 points from the untouched snapshot. The older pinned baseline already differed (Facility -14.08 pp before this task); it has not been repinned. These are small regression samples, not precise player difficulty estimates.

Final closeout: `python scripts/verify_gate.py --skip-sim` passed every hard gate, including combat audit, scene flow, tutorial, feedback honesty, title/unlock and the new recovery/arrival regression. Balance was measured separately above. Final native regression and `git diff --check` passed.

Logs and captures: `debug_artifacts/final-feedback-baseline.log`, `final-feedback-gate.log`, `final-feedback-test.log`, `final-feedback-native.log`, `final-feedback-physics.log`, `feedback-before-metrics.json`, `feedback-after-metrics.json`, and `final-feedback/*.png`. Existing missing audio clips/certificate-store warnings remain separate. V06 current web-export/browser/physical-phone verification and public upload remain open.
