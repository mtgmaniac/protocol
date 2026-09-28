# Overload Protocol — current handoff

2026-09-28. Start here, then read `docs/TRUTH.md`, `docs/INVARIANTS.md`,
`docs/DECISIONS_RESOLVED.md` and `TASK_QUEUE.md` (see `AGENTS.md`).

## Just finished: boss relic rework (merged to `main` 2026-09-28)

Kev tested `boss-relic-rework` in Godot and approved it; it is merged into
`main` and the branch is deleted. Rules: TRUTH "Boss relics"; rulings
DECISIONS_RESOLVED G-34..G-42. Final tuning (G-42); every boss relic lands in
the +2 to +5 band (Blood Frenzy's +5.3 is within noise of the edge):

- **Heretic Signal costs 3 Protocol** (still once per battle): +2.9. Relic text
  and confirm say so; with less than 3 Protocol the loadout row reads
  NEEDS 3 PROTOCOL.
- **Tectonic Charge: +3 from round 2, and 3 shield on each hero while they
  hold in round 1**: +3.6 (shield 2: +2.8, 4: +5.1). The hold banner has a
  second line with the shield and the +3.
- Scrap Converter +4.9, Blood Frenzy +5.3, Firewall Hack +4.4 (unchanged).
  Overheal Relay and Spillover Charge keep their names and numbers.
- Four open readings confirmed by Kev (G-42): Blood Frenzy once per hero per
  round with repeats adding repeats; re-throws clear Nudge / Set / Firewall
  Hack with no refund; Spillover wraps last to first, skips cloaked, is
  blocked by Firewall; the unlock buckets. The other open readings stand as
  implemented.
- Evidence: `docs/BOSS_RELIC_TUNING_2026-09-28.md` (final section).
- **Still needed:** new art for the seven relics (all placeholders; rows in
  the framing editor). Web and phone check of the hold banner, the Heretic
  confirm and the loadout relic row happens with the web build below.

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
- **Balance baseline** re-pinned 2026-09-28 after the boss relic rework
  (BASELINE-APPROVED-BY-KEV): overall 0.2567, facility 0.3662, hive 0.2542,
  veil 0.2308, voidCirclet 0.2281, stellarMenagerie 0.1667. `ci_smoke.py` is
  green against it.
- **Gate:** full `python scripts/verify_gate.py` with the sim passes
  (2026-09-28). Run it with an
  isolated `APPDATA` when Kev may have Godot open (a live session shares
  `dev_run.json`). Godot rewrites the `config/icon` line in `project.godot`
  on launch: discard it, never commit it.

## Open items worth knowing

- **Enemy-phase preview gap (from B1).** The hero phase in the damage
  preview is exact, but each enemy hit on a hero is its raw `dmg`: enemy
  riders and enemy-phase shields (which can absorb the end-of-round burn
  tick) are not modelled. Fix shape in `TASK_QUEUE.md`.
- **`battle_scene.gd` is at its line limit** (3640, since the relic UI lives
  in `boss_relic_actions.gd`). `protocol_actions.gd` is 1165 against a mark of
  971 (warning only; split task in `TASK_QUEUE.md`).
- **Pre-existing engine error on fast Rerolls:** back-to-back Rerolls log
  "Lambda capture at index 0 was freed". Harmless so far; P3 in
  `TASK_QUEUE.md`.
- **Android export size.** The Android preset excludes only `dev/*`, so its
  pack is about 422 MB with `debug_artifacts/`, `docs/` and `legacy-angular/`
  inside. Needs exclude filters before any Android build.
- `intercept_choice_flow_test.gd` is not gated (see `TASK_QUEUE.md`).
- Web and physical-phone rendering of the dice rework and the UI batch have
  not been checked (no web export since).

## Next up, in order

1. **Fresh web build to itch.io, plus a devlog.** Export with the headless
   console Godot (`C:/Users/Kev/Downloads/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64_console.exe`;
   9-file flat zip), check it on desktop browsers and a phone (first web
   build since the dice rework, the UI batch and the boss relics). Write the
   devlog (boss relic rework, real dice). Publishing is Kev's call.
2. **Reddit distribution** to the planned subreddits (not Kev's guild).
   Posting is Kev's to do or approve.
3. New art for the seven relics.
