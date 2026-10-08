# Does CONTINUE restore a mid-battle round? Check of the disputed claim (2026-10-08)

**The claim (2026-10-06 session, G-48 point 2):** through the real menu, CONTINUE
never restored a mid-battle round. The routing save overwrote the round
checkpoint before the battle loaded, so the battle restarted at round 1.

**The dispute (Kev):** mid-battle reloads resumed at the round with the BATTLE
RESUMED message in playtests, matching shipped v0.1.1.

## Verdict

**The claim reproduces on every build tested, including both shipped itch
builds.** It was not a test-harness artifact. The fix in `3b4afe7`
(`SceneManager.resume_to`) stays, and the `resume guard` gate already reflects
real behaviour (its `routing_save` break is exactly the shipped code path).

| Build | Checkpoint before CONTINUE | After CONTINUE | Screen after CONTINUE |
|---|---|---|---|
| itch v0.1.1, `overload_protocol_web_2026-09-25.zip` | round 2 (`save_seq` 3) | none (`save_seq` 4, then 5) | battle 1 entry briefing, all units at full HP, Protocol 0 |
| itch v0.2, `build/itch-2026-09-28` (last itch release, commit `e03c2e7`) | round 2 (`save_seq` 4) | none (`save_seq` 5, then 6) | same |
| main before this branch, `fc0607b` (fresh web export) | round 2 (`save_seq` 4) | none (`save_seq` 5, then 6) | same |

No build showed BATTLE RESUMED.

## How it was run

- The shipped web builds themselves, served locally, played in a browser with
  real pointer clicks (`isTrusted` events, positions logged from the page):
  BEGIN, SKIP TUTORIAL, DEPLOY SQUAD, ENGAGE, ROLL, the hint boxes, a target for
  each hero, END TURN. Then a real page reload and a click on CONTINUE.
- No in-game harness, no debug flags, no script calls into the game. `index.js`,
  `index.wasm` and `index.pck` are the shipped files (the itch 09-28 files are
  byte-for-byte the ones in `build/itch-2026-09-28`).
- One change to the page, outside the game: `index.html` got a two-line
  `requestAnimationFrame` replacement, because the preview pane was not on
  screen and a hidden page gets no animation frames (the game would not run at
  all). It changes frame timing only.
- The checkpoint was read from the save itself: the `overload_protocol:run.json`
  entry in localStorage (the save's web mirror), polled every 50 ms across
  CONTINUE.
- `main` was exported from a clean checkout of `fc0607b` with the project's Web
  preset and played the same way.

Not done: a desktop windowed run. The web builds are what shipped and what the
phone runs, and the result was the same on all three.

Screenshots (local, git-ignored): `debug_artifacts/continue_claim_2026-10-08/`.
For each build: the board before the reload (round 1 resolved, damage on both
sides), the menu after the reload, and the screen after CONTINUE (entry
briefing, full HP).

## When it happens

Every time, with no other condition: any CONTINUE from the menu into a battle
whose save holds an end-of-round checkpoint, on every build since checkpoints
shipped (`1171eb8`, 2026-09-21) up to `main`.

The code path, identical on all three builds:

1. The menu's CONTINUE calls `SaveManager.resume_run()`, which loads the
   checkpoint and holds it for the battle scene (`_pending_battle_restore`).
2. It then calls `SceneManager.go_to_battle()`, whose routing save
   (`checkpoint_run("battle")`) discards that held checkpoint and writes a fresh
   battle entry with an empty `battle_checkpoint`.
3. The battle scene finds nothing to restore and starts from its entry.

`resume_run` has no other caller in the game. On those builds the BATTLE RESUMED
message can only be reached by the test scripts that load the battle scene
directly (`battle_checkpoint_test.gd`), which is why the older gates passed.

## Why a playtest can look like it resumed

- **A reload during round 1** restarts the battle from its entry, which is
  where the player already was (the `battle checkpoint` gate asserts the
  restarted battle's opening dice are identical), so it looks like a resume. There is no
  BATTLE RESUMED message in that case, on any build.
- **A reload from round 2 on** loses the rounds played: the battle is back at
  full HP with the entry briefing. The run state it restarts on is the one the
  checkpoint carried (mid-battle), not the battle-entry one, because the routing
  save writes whatever `resume_run` just loaded.
- **This branch does resume**, with BATTLE RESUMED. The project folder has been
  on `claude/resume-and-settings` since 2026-10-06 22:35, so anything played
  from the Godot editor since then ran the fixed code. This is the only way
  found to see that message through the menu. Whether that accounts for the
  playtests is a guess; it could not be checked from here.

The earlier report "restore doesn't work, I have to reload and relaunch" fits
the app-switch freeze (`APP_SWITCH_FREEZE_2026-10-06.md`) for the "have to
reload" half. The "restore doesn't work" half fits this bug: on the shipped
build the reload that follows a freeze lands on round 1.
