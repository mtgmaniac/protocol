# Overload Protocol — current handoff

2026-09-27. Start here, then read `docs/TRUTH.md`, `docs/INVARIANTS.md`,
`docs/DECISIONS_RESOLVED.md` and `TASK_QUEUE.md` (see `AGENTS.md`).

## Current state

`main` is pushed and clean (`main` = `origin/main`). Everything below is
merged, approved by Kev and closed. Do not reopen it.

- **Dice rework and Dice rules.** Real 3D dice; the landed face is the roll
  (G-24). TRUTH "Dice rules" is the one place for dice behaviour (G-31
  containment, G-32 values hide while a die moves, G-33 re-thrown dice
  collide with resting dice). Evidence: `docs/DICE_REWORK_VERIFICATION_2026-09-26.md`,
  `docs/DICE_BALANCE_2026-09-27.md`.
- **Tutorial real rolls.** The three scripted rounds play recorded real
  throws (G-26); later rounds are free. `docs/TUTORIAL_REAL_ROLLS_2026-09-27.md`.
- **Framing editor and Kev's framing pass.** One framing entry per asset in
  `assets/portraits/portrait_anchors.json` (schema 2), edited with
  `dev/framing_editor/` (`docs/tools/FRAMING_TOOL.md`).
- **Portrait backdrop.** `PixelUI.cover_fit_portrait` draws black behind
  every portrait, so short art never shows the host frame's colour.
- **UI batch B1-B11** (`docs/batches/2026-09-27-ui-batch.md`, all done):
  exact hero-phase damage preview, Detonate number gap, fixed-slot encounter
  select, Route Fork header art at its own aspect (B4), popup art and empty
  band, boxed intercept options, long-press anywhere on a unit card, rampage
  icon, integer item art, re-thrown dice collide, evolved portraits in Help.
  Plus the intercept wording "rare or better gear".
- **Balance baseline** re-pinned 2026-09-27 to the post-dice-rework tree
  (BASELINE-APPROVED-BY-KEV): overall 0.2767, facility 0.4085, hive 0.2373,
  veil 0.2615, voidCirclet 0.2105, stellarMenagerie 0.2292. `ci_smoke.py` is
  green against it.
- **Gate:** `python scripts/verify_gate.py --skip-sim` passes. Run it with an
  isolated `APPDATA` when Kev may have Godot open (a live session shares
  `dev_run.json`). Godot rewrites the `config/icon` line in `project.godot`
  on launch: discard it, never commit it.

## Open items worth knowing

- **Enemy-phase preview gap (from B1).** The hero phase in the damage
  preview is exact, but each enemy hit on a hero is its raw `dmg`: enemy
  riders and enemy-phase shields (which can absorb the end-of-round burn
  tick) are not modelled. Fix shape in `TASK_QUEUE.md`.
- **`battle_scene.gd` is over its line limit:** 3648 lines against a
  high-water mark of 3640 (the pre-commit hook warns). Extract before adding
  to it; raising the mark needs Kev.
- **Android export size.** The Android preset excludes only `dev/*`, so its
  pack is about 422 MB with `debug_artifacts/`, `docs/` and `legacy-angular/`
  inside. Needs exclude filters before any Android build.
- `intercept_choice_flow_test.gd` is not gated (see `TASK_QUEUE.md`).
- Web and physical-phone rendering of the dice rework and the UI batch have
  not been checked (no web export since).

## Next up, in order

1. **Boss relic rework.** Scrap Converter, Blood Frenzy, Firewall Hack,
   Heretic Signal and Tectonic Charge replace the five old boss relics
   (Salvage Rig, Chitin Graft, Resonant Chorus, Root Access, Mantle Core).
   Overflow and Spillover join the normal draft pool. Kev has the full
   prompt; wait for it, don't design from this line. It touches combat, so
   run the sim and follow the baseline ceremony.
2. **Fresh web build to itch.io, plus a devlog.** Export with the headless
   console Godot (`C:/Users/Kev/Downloads/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64_console.exe`),
   check it on desktop browsers and a phone. Publishing is Kev's call.
3. **Reddit distribution** to the planned subreddits (not Kev's guild).
   Posting is Kev's to do or approve.
