# Overload Protocol — current handoff

2026-09-28. Start here, then read `docs/TRUTH.md`, `docs/INVARIANTS.md`,
`docs/DECISIONS_RESOLVED.md` and `TASK_QUEUE.md` (see `AGENTS.md`).

## In review: boss relic rework (branch `boss-relic-rework`, NOT merged)

Kev tests in Godot before merge. Pushed to `origin/boss-relic-rework`.
One commit per relic on top of `main`:

1. Retire Salvage Rig, Chitin Graft, Resonant Chorus, Root Access, Mantle Core;
   save migration (`SaveManager.LEGACY_BOSS_RELIC_IDS`); rulings G-34..G-41.
2. Scrap Converter (Facility). 3. Blood Frenzy (Hive). 4. Firewall Hack (Veil).
5. Tectonic Charge (Mantle Hunt). 6. Heretic Signal (Signal Purge).
7. Overheal Relay, 8. Spillover Charge (draft pool, placeholder names).
9. Deliberate-break script, TRUTH summary, wiki. 10. Tuning report + this handoff.

Every commit compiles and passes the `boss relics` gate and the ability audit
on its own. Rules: TRUTH "Boss relics"; readings the brief left open are
flagged in DECISIONS_RESOLVED G-34..G-41 for Kev to confirm.

- **Gates:** full `verify_gate.py` with the sim passes (66 gates). New gate
  `boss relics` (194 checks: every rule, edge case, the migration and the live
  screen paths). `battle checkpoint` gained Heretic Signal refresh legs;
  `dice face` gained the Firewall Hack tip-over and Heretic Signal re-throw
  paths. `scripts/checks/boss_relic_mutations.py --checkpoint` breaks 9 rules
  on purpose: all 9 caught.
- **Tuning (report only):** `docs/BOSS_RELIC_TUNING_2026-09-28.md`. In target:
  Scrap Converter +4.9, Blood Frenzy +5.3, Firewall Hack +4.4. Out: Heretic
  Signal +12.1 (proposal: costs 3 Protocol, measured +2.9) and Tectonic Charge
  -5.2 (proposal: +3 from round 2, measured +0.5; +4 overshoots to +8.0).
- **Baseline NOT re-pinned.** The two new draft relics change the battle-5
  cache, so the pinned 300-run CI batch moves: overall 0.2767 -> 0.2567,
  facility -4.2, hive +1.7, veil -3.1, voidCirclet +1.8, stellarMenagerie
  -6.2 (all inside +-10, so re-pinning needs no token; left for Kev with the
  tuning decisions). `ci_smoke.py` alone would flag stellarMenagerie (its
  per-op tolerance is 5).
- **Art needed (all seven use placeholders):** Scrap Converter, Blood Frenzy,
  Firewall Hack, Heretic Signal, Tectonic Charge (old boss icons), Overheal
  Relay (`gravityWell.png`), Spillover Charge (`twinFates.png`). All seven
  are rows in the framing editor.
- **Not verified:** Kev's Godot visual review of the hold banner, the Heretic
  confirm and the loadout relic row; web and phone. Godot will create `.uid`
  files for the three new scripts the first time the editor opens.
- **Test-only lesson:** never run gates in the same `APPDATA` as a sim batch;
  the sim workers create and delete the same `dev_run.json` (looked like a
  flaky checkpoint).

## Current state of `main`

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
- **`battle_scene.gd` is over its line limit** on `main` (3648 vs 3640). The
  boss relic branch brings it to exactly 3640 (the relic UI lives in the new
  `boss_relic_actions.gd`). `protocol_actions.gd` is 1165 against a mark of
  971 (warning only).
- **Pre-existing engine error on fast Rerolls:** back-to-back Rerolls log
  "Lambda capture at index 0 was freed" (reproduced on untouched `main`:
  3, 1, 0 times in three runs of ten rerolls). Harmless so far; not gated.
- **Android export size.** The Android preset excludes only `dev/*`, so its
  pack is about 422 MB with `debug_artifacts/`, `docs/` and `legacy-angular/`
  inside. Needs exclude filters before any Android build.
- `intercept_choice_flow_test.gd` is not gated (see `TASK_QUEUE.md`).
- Web and physical-phone rendering of the dice rework and the UI batch have
  not been checked (no web export since).

## Next up, in order

1. **Boss relic rework: Kev's Godot test and decisions.** Confirm or overrule
   the open readings (G-34..G-41), decide the Heretic Signal and Tectonic
   Charge proposals, rename the two draft relics, then merge and re-pin the
   baseline (the ceremony). New art for the seven relics.
2. **Fresh web build to itch.io, plus a devlog.** Export with the headless
   console Godot (`C:/Users/Kev/Downloads/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64_console.exe`),
   check it on desktop browsers and a phone. Publishing is Kev's call.
3. **Reddit distribution** to the planned subreddits (not Kev's guild).
   Posting is Kev's to do or approve.
