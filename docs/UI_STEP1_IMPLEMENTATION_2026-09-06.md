# Visual step 1 — implementation and verification

TASK: Implement approved V01–V05, remove Twin Fates, and defer the tutorial redesign.

## Context and constraints

Read TRUTH, INVARIANTS, DECISIONS_RESOLVED, AI_AGENT_GAME_REFERENCE, TASK_QUEUE and TASK_TEMPLATE before implementation. Recorded Kev's approved scope as G-10 before changing runtime code. The untouched game passed all hard gates and the 300-run `ci_smoke` baseline batch.

Preserved the deterministic combat fence (invariant 1), existing IDs except the explicitly removed relic (11), the portrait layout (12), and verification thresholds (13). No Angular code, balance formulas, other relic mechanics, baseline values or tutorial structure changed.

## Changes

| Item | Implemented behavior |
|---|---|
| V01 | Freeze, petrify and jam shells retain tint without writing depth over numerals. Full combat capture shows frozen 7 as readable as adjacent normal 7. |
| V02 | Four 144×144 design-pixel buttons, approximately 52×52 at 390-pixel width. Icons above NUDGE, REROLL, SET and ITEMS; costs at upper right. Labels fit without clipping. |
| Twin Fates | Removed relic definition, icon mapping, unlock entry, approval CSV row, picker states, button and copy engine. Invalid relic grants rejected. Old profile migration prunes the retired ID while retaining other unlocks and gate progress. Unused source art remains. |
| V03 | Replaced Godot icon with a hard-edged cyan reactor SVG. Local Web release generated matching favicon and Apple touch icon. |
| V04 | Seven quick consecutive taps on the operation title unlock dev tools during a run, for the app session. More than one second between taps or a tap elsewhere restarts the count. Tools then appear in Settings; header arrows can be toggled. Saved developer settings cannot unlock a fresh session. |
| V05 | Help now explains average-effective-roll XP, survivor +20, 100 XP evolution, one upgrade per win, and gear lasting through the run. Removed inaccurate boxed-card-tag description. |

The complete tutorial rethink is step 2.

## Captures

- [390×844 battle and footer](visuals/2026-09-06-step1/battle-390.png)
- [Actual completed combat turn: frozen and normal 7](visuals/2026-09-06-step1/frozen-round.png)
- [Die-status presentation: freeze, petrify, jam/rewrite](visuals/2026-09-06-step1/die-statuses.png)
- [Settings before unlock](visuals/2026-09-06-step1/settings-locked.png)
- [Settings after seven taps](visuals/2026-09-06-step1/settings-unlocked.png)
- [Exported reactor icon](visuals/2026-09-06-step1/reactor-icon.png)

Rendered in Godot 4.6.2 using the Compatibility renderer. The status capture applies display states deliberately; the frozen-turn capture follows real combat resolution. These are desktop viewport checks, not physical Pixel/iPhone testing. Web export succeeded; the Web build was not played in a browser or uploaded.

Reproduce the status image with `--rendering-method gl_compatibility -s res://docs/audit/visual-review-tools/step1_status_capture.gd --capture-rolled --capture-lock-targets=3 --capture-no-primers --capture-protocol=8 --capture-output=res://debug_artifacts/step1-status.png`.

## Verification

- `python scripts/verify_gate.py`: **all hard gates PASS**, including data, pool floors, ability audit, unlock progression, scene flow, tutorial, safe area, freeze, protocol cancellation and die-reroll visuals.
- New `dev_unlock_test.gd`: **PASS** — initial lock, six taps, timeout, tap-away reset, seven-tap unlock, arrow toggle, and old-profile migration.
- Replaced obsolete Twin Fates copy regression with a removed-ID/grant rejection regression; audit floor retained.
- Safe-area Settings regression now checks both session-lock states and debug/release build rules.
- Dice physics probe: **8 rolls, 0 penetrations, 0 flyovers, frozen drift 0.0000, 0 tilted rests**.
- Local Web release export: **success**, including regenerated favicon/touch icon. Output: `build/step1-web/index.html`.
- Existing missing `revive.wav` and `summon.wav` warnings remain.

## Balance report

Same 300-run seeded configuration before and after; no failed simulations. Removing a draftable relic changes reward selection and subsequent runs, so this is not a claim of identical balance.

| Operation | Pre-step clear % | Post-step clear % | Change, points |
|---|---:|---:|---:|
| Facility | 45.07 | 38.03 | -7.04 |
| Hive | 25.42 | 32.20 | +6.78 |
| Stellar Menagerie | 18.75 | 20.83 | +2.08 |
| Veil | 33.85 | 29.23 | -4.62 |
| Void Circlet | 28.07 | 24.56 | -3.51 |
| Overall | 31.33 | 29.67 | -1.66 |

No operation moved more than 10 points against this task's pre-change snapshot. The gate also compares to the older pinned baseline and flags Facility (-12.7) and Veil (-10.8). That warning remains open; **the pinned baseline was not updated or approved**. This small sample is a smoke check, not a balance conclusion.

## Closeout

TRUTH, G-10, the visual bible and unlock CSV describe the new behavior. Original audit captures and ratings remain a historical snapshot; this report supersedes V01–V05 recommendations. Physical phone testing and step 2 tutorial design remain future work. No merge, push or public upload performed.
