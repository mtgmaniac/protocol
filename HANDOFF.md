# Overload Protocol — finishing touches

2026-09-09. Continue from `main` in `C:/Users/Kev/Documents/protocol`.
Read `docs/TRUTH.md`, `docs/INVARIANTS.md`, `docs/DECISIONS_RESOLVED.md`, then `TASK_QUEUE.md`. The current visual reference is `docs/UI_VISUAL_BIBLE.md`. Work on a new `codex/*` branch. Do not edit legacy Angular code.

## Completed
- Approved game-copy audit and associated freeze/kill-reward corrections.
- V01–V05 and V07–V10/V12 visual work: compact icon-only footer restored, Twin Fates removed, hidden dev unlock (seven quick operation-title taps), revised choice layouts, item art, bounded combat numbers, centered Continue, Reduced Motion.
- Two-battle tutorial: welcome; damage/heal/shield/Protocol first, independent third turn; real item choice; optional second battle teaching Mark/Burn, inventory and conditional Reroll. Engineer Overdrive permanently deals 10. Uses Splice/SCRAP names; legal alternate targets remain allowed.
- Latest selection fixes: transparent reserved dossier space on locked encounters prevents layout jumps; locked hero names hidden; NO CLEARANCE removed for unplayed operations; briefing headings uppercase and descriptions sentence case.

## Next
1. Play the current tutorial and a normal run; address Kev's remaining usability/copy feedback. Keep phone readability, one-hand use and compact footer spacing central.
2. V06: verify the current exported web build on desktop and real phones/browsers before public release. Native screenshots alone do not finish this. Intended showcase: itch.io, screenshots, possibly a short trailer.
3. V11: review title-screen button hierarchy and sparse unlock-screen composition. Large unlock lists looked correct; the reproduced issue concerned small awards in a mostly empty panel. Do not assume the entire unlock UI is broken.

## Verification and cautions
Latest gameplay/UI head before handoff: `884f070`. Untouched baseline and final `python scripts/verify_gate.py --skip-sim` passed; strengthened empty-squad layout regression and native 390×844 captures passed. See `docs/SELECT_POLISH_2026-09-09.md` and `docs/TUTORIAL_IMPLEMENTATION_2026-09-08.md` for evidence and prior balance deltas. No baseline was repinned. Physical-device and current release-build verification remain open.

Godot console: `C:/Users/Kev/Downloads/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64_console.exe`. For test runs set APPDATA to the repo's `debug_artifacts/tutorial-profile` to isolate saves and permit logs. Gate startup stops headless Godot processes: do not run multiple gates concurrently. Existing missing audio-clip warnings are separate from this polish.

User requested all current work committed, merged to main and pushed to GitHub. This is a source handoff, not an itch.io release upload. Start the next chat from this file; no new chat is created automatically.
