# Copy revision and reward rules — 2026-09-05

Historical review record. Kev approved the remaining proposals on September 6; see [the implementation report](COPY_IMPLEMENTATION_2026-09-06.md) for the applied changes and final validation.

TASK: Shorten the copy proposals for the existing UI and implement Kev's frozen-20 and reinforcement-reward changes.

STEP 0 — CONTEXT: Read TRUTH, INVARIANTS, DECISIONS_RESOLVED, the game reference and task queue. The untouched-tree full gate passed. Its pinned 300-run snapshot appears below. G-8 was recorded before implementation, superseding NK-04 and NK-10.

CONSTRAINTS: Preserve deterministic combat and summon chances (invariant 1), enemy AI gates (2), freeze alteration immunity and target rules (3/12), runtime IDs (11), and reward limits. The copy workbook remains a proposal; only the specifically requested Deep Freeze description and gameplay rules are applied to game data/code.

CHANGE:

- Every resolving frozen 20 triggers Loop/Rites, Protocol-on-20 gear, the 20s statistic and enemy summon chance. Loop/Rites echo once; the echo does not duplicate gear/stat payouts.
- Summoned and rebuilt enemies qualify for normal kill rewards. Killer/type/mark requirements and battle/inventory caps still apply.
- Deep Freeze: “This hero's freeze abilities last 1 additional turn.”
- Workbook: original operation threat lines restored; 305 ability tooltip drafts use compact numeric effects; all 31 gear, 25 consumable and 35 relic descriptions shortened. Removed outdated frozen-turn and reinforcement exclusions. Original cells are preserved outside the proposed-edit and comment columns.

VERIFY: Full `python scripts/verify_gate.py` passed, including 263 ability assertions (12 new), flow/tutorial smokes, profile isolation and the pinned 300-run simulation. New cases cover Loop, Rites, both together, neither, frozen enemy summons, field capacity, and ordinary/summoned/rebuilt kill rewards with later environmental kills and Scavenger's once-per-battle limit. `git diff --check` passed.

UI verification used the actual RewardScreen factories, fonts, effect pips and portrait viewport (1080×2400 logical, 540×1200 preview). All 56 gear/consumable drafts fit the two-line slots. All 35 relic drafts were measured in their expanding cards. Rendered Predator Lens and Deep Zero Pin examples were visually checked. The workbook export preserves all 13 tabs, 788 reviewed rows, original source cells, filters and frozen panes; representative exported cells were rendered and checked.

The separate DiceTrayPhysicsProbe also passed: eight rolls, zero penetrations, flyovers, frozen drift or tilted rests.

REPORT — baseline unchanged:

| Operation | Before clear rate | After | Change (percentage points) |
|---|---:|---:|---:|
| Facility | 50.70% | 50.70% | 0.0 |
| Hive | 28.81% | 28.81% | 0.0 |
| Stellar Menagerie | 16.67% | 18.75% | +2.1 |
| Veil | 40.00% | 38.46% | −1.5 |
| Void Circlet | 22.81% | 24.56% | +1.8 |
| Overall | 33.33% | 33.67% | +0.3 |

This is the pinned smoke comparison, not a comprehensive balance study. No baseline was repinned.

CLOSEOUT: TRUTH and DECISIONS_RESOLVED now match the implemented rules. Changes are local and uncommitted. Names and remaining spreadsheet copy await editorial approval.

Twin Fates already has a button beside Set when the relic is held. After rolling, select the source die and then the destination. It is free and once per battle. It copies the base roll, clears destination Nudge/Set adjustments, and then applies the destination's modifiers; the displayed values can differ. No new screen is needed. The revised proposal explicitly says “base roll.”

Existing copy/code issues remain annotated in the workbook: Deep Zero Pin alters already-frozen dice despite the general immunity rule; the non-boss kill helper misclassifies the Mantle Tyrant kit; some enemy ally-shield data is skipped by the shield handler. These are separate from the requested rule changes.
