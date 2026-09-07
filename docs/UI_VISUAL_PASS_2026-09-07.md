# Visual pass: V07–V12 follow-up

TASK: Mock up V07/V08; implement V09/V10 and the Continue-button correction; reproduce V11 and explain V12.

## Context and constraints

Read TRUTH, INVARIANTS, DECISIONS_RESOLVED, AI_AGENT_GAME_REFERENCE, TASK_QUEUE and TASK_TEMPLATE. Untouched-tree `verify_gate.py --skip-sim` passed. G-12 records the scope before runtime changes. Preserve deterministic combat (invariant 1), existing item IDs (11), portrait layout and compact footer (12), and all enforcement thresholds (13). No balance surface changed; no simulation or baseline update was needed.

## Implemented

**Continue:** removed the swap icon and its spacing overrides from the shared run-end screen. Victory and defeat use centered text, matching the unlock screen.

**V09:** remapped two icons in DataManager, using the existing 128×128 detailed sci-fi set without altering source images:

| Item | Reused source | Reason |
|---|---|---|
| Gravity Well | `assets/icons/items/momentum_core.png` | An orbital apparatus suits a persistent gravity field; replaces the 32-pixel pastel ring. |
| Interference Charge | `assets/icons/items/signalJam.png` | An antenna/emitter communicates disrupted rolls; replaces the chemical container. |

These images are shared with their original items; they are not new unique illustrations. The retired files remain available as source history. Twin Fates remains removed.

**V10:** replaced unlimited upward stacking with two bounded lanes over each affected portrait. Text scales to fit the lane at its largest punch size, including the outline. Titles, health bars, neighboring units and header stay clear. A third outcome retires the oldest floating label immediately; the latest two remain. No queue of delayed combat numbers accumulates, and the complete event history remains in the battle log. Roll buffs remain anchored to dice. Float tweens are bound to their labels so retiring a label stops its animation.

## V07/V08 proposals only

Interactive mockups in the conversation use current Avalanche/Glacier/Trench abilities and current reward descriptions, with existing art and the game's pixel font.

- V07 inspect: left-aligned effects, stable roll-range column, readable contrast, preserved targets and durations.
- V07 evolution: comparable HP/role/20 summaries, all five abilities available per branch, explicit selection and confirmation. An optional mockup control compares branches by roll band.
- V08 route: shared hostile context appears once; risk and reward are the main information in each alternative.
- V08 reward: item names stay bright across rarities; type/rarity are secondary; effects stay concise.

These layouts are not implemented in the game.

## V11 reproduction and interpretation

Reproduced the existing unlock capture scenarios at 537×1195 with isolated profiles:

- **Single gate:** start with three banked battles, record a defeat, process the next unlock gate. Three new items appear in the middle of a mostly empty full-height panel. This matches the original finding.
- **Large award:** a Facility victory after many banked battles fills the panel with several categories and scrolls as intended. The user's large-award screenshot is consistent with this working layout.
- **Boss only:** a single boss relic is presented in the full-height frame.

This is a small-award composition recommendation, not an unlock malfunction or claim that every unlock screen looks sparse. No unlock-layout change was made.

“Tutorial does not look disabled relative to feedback” refers to the main menu's muted `LINE_DIM` Tutorial styling beside Feedback's brighter amber styling. Tutorial is usable; the concern is that gray can suggest unavailable. The menu temporarily disables launch controls during a scene transition, not ordinary menu access. This is a subjective, lower-priority hierarchy concern, not a functional defect.

## V12 meaning — not implemented

An optional Reduced Motion setting would lower or remove camera/card shake, glitch distortion, strong full-screen color pulses (the “wash”), and large zoom/punch transitions. It would retain visible roll results, damage/heal amounts, targeting, status changes and turn progression. Affected transitions would still complete normally. This is an optional comfort setting, not a proposal to remove normal animations for everyone or change combat speed/rules.

## Verification and evidence

- Before and after `python scripts/verify_gate.py --skip-sim`: **all hard gates PASS**.
- New `float_bounds_test.gd`: **PASS**. Six rapid hits per card across five narrow enemy lanes; every frame through punch/rise/fade checks region bounds, visible-label overlap and the two-label cap. A later heal still appears after previous labels expire.
- Rendered a four-number burst, squad-wide damage and a complete actual combat turn. Number floats remain associated with the affected units.
- Rendered centered Continue and both remapped icons in the reward UI.
- Browser-checked the mockup's view switching and full-kit expansion. Mockups are review prototypes, not physical-device validation.
- Existing missing revive/summon sound warnings remain. No public upload, merge or push.

Evidence:

- [Remapped item art](visuals/2026-09-07/v09-art.png)
- [Bounded burst](visuals/2026-09-07/v10-burst.png)
- [Actual combat turn](visuals/2026-09-07/v10-round.png)
- [Continue button](visuals/2026-09-07/continue.png)
- [Small unlock](visuals/2026-09-07/unlock-small.png)
- [Large unlock](visuals/2026-09-07/unlock-large.png)
- [Boss-only unlock](visuals/2026-09-07/unlock-boss.png)

## Closeout

TRUTH, G-12, the visual bible and the two affected content-index entries reflect the changes. V07/V08 remain proposals; V11/V12 remain unimplemented. Original review captures remain historical evidence. Per-operation balance deltas are not claimed for this presentation-only pass.
