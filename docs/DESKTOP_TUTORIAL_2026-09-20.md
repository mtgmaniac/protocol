# Desktop fit and tutorial recovery — 2026-09-20

## Task and starting point

Complete and verify the existing uncommitted Reddit-feedback fixes in the live
Godot project. Kev authorized implementation after the read-only handoff review.
Work branch: `codex/desktop-tutorial-fit`; starting HEAD: `5186774`.
Existing store artwork and `.claude/launch.json` changes are unrelated and retained.

Read TRUTH, INVARIANTS, DECISIONS_RESOLVED, AI_AGENT_GAME_REFERENCE, TASK_QUEUE,
TASK_TEMPLATE and the battle layout contract. Preserve invariants 1, 7, 9–12 and
14: combat, data, authored portrait composition and legacy assets stay unchanged.

Pre-change `python scripts/verify_gate.py --skip-sim` reported all hard gates PASS
(`debug_artifacts/desktop_gate_before.log`). However its old result matching ignored
nonzero exit codes: the inherited reachability test printed PASS while ending with
cleanup errors. Its gate now requires exit 0 and no ERROR output as well as PASS.

No balance surface changed; the sim was skipped and its baseline was not repinned.
The stored reference, not a newly measured result, is:

| Operation | Stored clear rate | New measurement / delta |
|---|---:|---|
| facility | 50.70% | Not run; UI-only |
| hive | 28.81% | Not run; UI-only |
| stellarMenagerie | 16.67% | Not run; UI-only |
| veil | 40.00% | Not run; UI-only |
| voidCirclet | 22.81% | Not run; UI-only |

> **Revision (Kev, same day):** the portrait letterbox described below was
> removed. The Web build now uses whatever viewport the browser or itch iframe
> supplies (Adaptive canvas, `canvas_items` + `expand` kept) with no width cap;
> Kev sets the desktop size in itch.io's Embed Options. The tutorial-recovery
> work stands. See "Letterbox removal" at the end; the letterbox paragraphs and
> the canvas table are kept as history only.

## Diagnosis and changes

Adaptive Web canvas sizing plus `canvas_items` / `expand` expanded the authored
portrait sideways on desktop (1366×700 became approximately 4683×2400 design
pixels). Existing captures confirm the resulting empty space and widely separated
cards, not an offscreen Roll button. Parent-page scrolling is a separate embedding
constraint: a child shell cannot resize an oversized host iframe.

The Web preset uses resize policy None and the shell owns an exact portrait
backing store. The fit uses the visual viewport, resize/fullscreen and DPR changes,
with dimensions in 9×20 physical-pixel units and a physically aligned origin.
Removed half-integer scale snapping: on DPR 2 at 1366×768 it could reduce the
canvas to 270×600 CSS pixels instead of using almost all available height.

The hidden dice-waiter recovery never covered ordinary gated actions. The tester's
exact stalled step is unknown; confusing presentation and fragile scaled holds
could compound the independent gating defect. Long-press tolerance is now 26
screen pixels (CSS pixels on Web, including DPR), rather than 26 design pixels.

Retained the opening THE OPERATION beat and 0.22 dim. Assistance after 20 idle
seconds or two refused actions performs the real lesson action. Inspection remains
open until the player dismisses it. Missing/offscreen required targets offer help
immediately; impossible actions offer an explicit training restart. Resizing
preserves recovery budgets, current targeting and assistance. A coach press is
consumed before callbacks, preventing that press from cancelling the Nudge it
just armed. Deferred coach placement ignores superseded presentations. Battle
layout avoids refreshing a scene after it has left the tree.

## Verification

- *(Removed with the letterbox)* `node scripts/checks/web_canvas_fit.cjs`: PASS, 60 size/DPR/visual-viewport cases.
- Expanded reachability test: PASS, exit 0 with no runtime errors. All guided action types via real coach clicks,
  inspection reading, resize with offers, real Nudge to 11, free play, missing
  target and explicit restart; cleanup waits for targeting to finish. A further
  regression confirms continuous resizing cannot postpone missing-roll recovery
  (`debug_artifacts/tutorial_reach_final.log`).
- Full `python scripts/verify_gate.py --skip-sim`: PASS, exit 0
  (`debug_artifacts/desktop_gate_after.log`). Tutorial smoke covers both encounters,
  rewards, item use and exit; the strengthened reachability gate also passes.
- `DiceTrayPhysicsProbe.tscn`: PASS, 8 rolls, 0 penetrations, 0 flyovers,
  0 tilted rests, frozen drift 0.0000 (`debug_artifacts/desktop_physics.log`).
- Local Web release export: exit 0, no export errors
  (`debug_artifacts/desktop_export.log`).
- Chrome exported-build acceptance: PASS, exit 0, no runtime script/page errors.
  Real mouse input completed the core tutorial through victory, including Nudge
  assistance. Held inspection with 10 CSS px drift worked at DPR 1 and 2.
  Actual iframe fullscreen entry/exit preserved the gated Roll beat. Resize with
  a visible assistance offer preserved the offer and its working action.
  Screenshots and console: `debug_artifacts/desktop_web/`.

*Historical (letterbox build).* The responsive iframe reserves 32 CSS pixels for a host toolbar. Chrome measured:

| Outer viewport | Canvas at DPR 1 | Canvas at DPR 2 |
|---|---|---|
| 1366×768 | 324×720 | 328.5×730 |
| 1440×900 | 387×860 | 387×860 |
| 1920×1080 | 468×1040 | 468×1040 |
| 1920×1200 | 522×1160 | 522×1160 |
| 1280×450 | 180×400 | 184.5×410 |

Every case retained the exact 1080×2400 design viewport, an onscreen coach and
zero game-document scrolling. The canvas loses less than 20 physical pixels of
height to exact-aspect quantization. Edge passed the same suite against the final
export, exit 0, including core tutorial completion and DPR 2 inspection, with no
runtime script/page errors. Evidence: `debug_artifacts/desktop_edge.log` and
`debug_artifacts/desktop_edge/`.

Browser runner: `node scripts/debug/desktop_browser_test.cjs`, after serving
`build/web` locally. `PLAYWRIGHT_MODULE` selects an installed Playwright package;
`WEB_TEST_URL` selects the build URL; `WEB_TEST_CHANNEL` selects Chrome or Edge.
For the optional browser harness dependency: `npm install --prefix
debug_artifacts/browser-tools --no-save --package-lock=false playwright`.
It uses isolated profiles, actual mouse input and the read-only tutorial geometry
bridge. It does not invoke game handlers or alter tutorial state from JavaScript.

Live itch configuration and physical-phone verification remain separate from a
local iframe/desktop test. Nothing was uploaded or published by this pass.

## Letterbox removal (Kev, 2026-09-20)

Kev's ruling: no custom portrait-width restriction and no fixed desktop width,
max-width or breakpoint in code; the game takes the viewport it is given and
the desktop presentation is controlled from itch.io's Embed Options.

- `web/shell.html` reverted to its committed version (no canvas fit pass);
  Web preset `html/canvas_resize_policy` back to 2 (Adaptive). Stretch settings
  unchanged. `scripts/checks/web_canvas_fit.cjs` and its gate were deleted.
- Visual survey of Squad Select at 432/512/540/560×960 (design width
  1080/1280/1350/1400): panels and DEPLOY widen, the hero grid stays fixed-size
  and centred, header buttons stay right-anchored, portraits undistorted.
- Unrelated fix found in the survey: at the 1080 design width the Squad Select
  operation blurb was capped at 2 lines and clipped Facility's text. Operation
  mode now gives the hidden hero-name row's height to a third blurb line, so the
  plate keeps its exact hero-dossier footprint (nothing below moves).
- `tutorial_reachability_test.gd` now also clicks Roll at 560×960 and 1366×768,
  resizes an assist offer to 560×960, and checks the long-press tolerance at
  1366×768: PASS, exit 0, no ERROR lines.
- `desktop_browser_test.cjs` is width-agnostic (design height 2400, width from
  the canvas aspect) and asserts the canvas fills the iframe. Exported build in
  Chrome: PASS, exit 0 at DPR 1 and 2 across 432/512/560×960 iframes,
  1366×768, 1920×1080 and 1280×450 windows, including fullscreen, held
  inspection with drift, Nudge assistance, resize with an offer visible and a
  real-input tutorial through victory.
