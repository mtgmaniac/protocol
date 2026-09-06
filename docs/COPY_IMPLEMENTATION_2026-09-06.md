# Approved copy implementation — 2026-09-06

TASK: Implement the approved concise copy review and its copy/code alignment fixes.

STEP 0 — CONTEXT: Read TRUTH, INVARIANTS, DECISIONS_RESOLVED, the game reference and task queue. The full pre-change gate passed with 263 ability assertions; its 300-run snapshot is the Before column below. Recorded Kev's approval as G-9 before editing.

CONSTRAINTS: Preserve authored stats, stable hero/evolution/item/operation/kit IDs, enemy runtime IDs, portrait paths, unlock order and deterministic combat. Follow the approved compact text and existing UI conventions. No baseline repin.

CHANGE:

- Implemented the reviewed names, operation lore, boss flavor, directives, item descriptions, intercept choices and battle modifiers. Added all 305 concise ability tooltip drafts. Retained the five original operation threat lines.
- Updated boss dispatch, portraits, summons, encounter pools, directive ability references, tutorial effect predicates and simulation tuning paths. Enemy display migrations explicitly retain the old runtime IDs; OVERCLOCK retains evolution ID `overclocked`.
- Updated target-text validation to the approved grammar, comparing effect/target counts to coded scopes. Straight apostrophes and ASCII minus signs preserve pixel-font coverage.
- Changed deployment labels to SITUATION and OBJECTIVE. Intercept action buttons are separate from wrapped consequences; a scroll container accommodates long choices.
- Fixed ally shields being skipped without self-shield, Bounty misclassifying Mantle Tyrant, and Deep Freeze Charge overwriting frozen faces. The charge extends an existing freeze without altering its face. No authored amounts or durations changed.
- Includes G-8's previously uncommitted frozen-20 triggers and reinforcement kill rewards. Twin Fates retains its existing base-roll copy, controls and once-per-battle limit.

VERIFY:

- Full `python scripts/verify_gate.py`: all hard gates passed, including 271 ability assertions, scene flow, tutorial, unlocks, lore, glyph coverage, preview accuracy, profile isolation and the pinned simulation.
- Eight new G-9 assertions cover ally-shield targeting/fallback/group behavior, all five bosses' Bounty eligibility, mixed frozen/unfrozen charge targets, stable IDs/portraits and summon references. Twelve G-8 assertions cover frozen-20 riders and reinforcement rewards.
- Static ability and gear/relic audits passed. Refreshed the static ability auditor to recognize the existing Cleanse handler and Build I's explicitly ruled taunt-plus-3-spike setup; no new keyword exception was introduced.
- All 2,936 authored numeric/boolean/null values checked unchanged against the prior committed edition, with IDs and data structure preserved. Target-validator negative checks reject wrong-side, missing and duplicate suffixes and obsolete `dmg` notation.
- Rendered at 1080×2400 logical / 540×1200 preview: all 91 item descriptions, 305 ability popups, five briefings and 22 intercepts checked without layout failures. Gear/consumables fit their two-line slots. Visually checked Signal Purge, Overclock Chamber, Shieldline Rally and representative reward captures.
- `git diff --check` passed.
- DiceTrayPhysicsProbe passed eight rolls with zero penetrations, flyovers, frozen drift or tilted rests.

REPORT — same pinned configuration and seeds, 300 total runs:

| Operation | Before | After | Change (percentage points) |
|---|---:|---:|---:|
| Facility | 50.70% | 45.07% | −5.6 |
| Hive | 28.81% | 25.42% | −3.4 |
| Mantle Hunt | 18.75% | 18.75% | 0.0 |
| Veil Breach | 38.46% | 33.85% | −4.6 |
| Signal Purge | 24.56% | 28.07% | +3.5 |
| Overall | 33.67% | 31.33% | −2.3 |

All per-operation changes are within ±10 points. The largest change against the older committed baseline is Veil at −6.2 points, also within tolerance. The baseline is unchanged. These are smoke-simulation results, not a comprehensive balance study.

CLOSEOUT: TRUTH, INVARIANTS and DECISIONS_RESOLVED reflect the implementation. The September 5 spreadsheet is approved and applied, with only font-safe punctuation changes and the documented code-alignment fixes above.
