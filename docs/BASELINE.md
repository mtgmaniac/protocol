# Known-good baseline (Task 1)

**Established:** 2026-06-21  
**Git tag:** `baseline-fable-restart` (move with `git tag -f baseline-fable-restart` after each verified baseline refresh)  
**Engine:** Godot 4.6.2  
**Repo:** `C:\Users\Kev\Documents\protocol`

Use this tag to reset when a refactor goes sideways: `git checkout baseline-fable-restart`.

---

## Run the game

### Normal play

1. Open `project.godot` in Godot 4.6.2, or run the console build.
2. Main scene: `res://scenes/ui/UnitSelect.tscn` (F5).
3. Pick 3 heroes → Begin run → play battles → reward / evolution as triggered.

### Debug battle (skip unit select)

Launches facility with first three heroes, rolls once, saves screenshot, quits.

```powershell
& 'C:\Users\Kev\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' `
  --path 'C:\Users\Kev\Documents\protocol' `
  -- --debug-battle
```

Owner: `scripts/debug/DebugBattleLauncher.gd` (autoload; active only when `--debug-battle` is in user args).  
Screenshot: `debug_artifacts/debug_screenshot.png`.

### Data validation

```bash
npm run validate-data
```

---

## Automated verification (run before/after risky changes)

| Check | Command | Expected |
|-------|---------|----------|
| JSON schemas | `npm run validate-data` | `Game data JSON validates against schemas.` |
| Ability audit | Godot scene `res://scenes/debug/AbilityAuditRunner.tscn` | `78 passed, 0 failed` |
| Scene flow | `--script res://scripts/debug/flow_smoke_test.gd` | `[FLOW_SMOKE] PASS` |
| Main scene boot | `UnitSelect.tscn --quit-after 3` | exit 0, no errors |
| Debug battle | `-- --debug-battle` | screenshot saved, exit 0 |

**Ability audit** (must run as scene — autoloads required):

```powershell
& 'C:\Users\Kev\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' `
  --path 'C:\Users\Kev\Documents\protocol' `
  'res://scenes/debug/AbilityAuditRunner.tscn'
```

**Full scene-flow smoke** (home → battle → reward → evolution → run-end):

```powershell
& 'C:\Users\Kev\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' `
  --path 'C:\Users\Kev\Documents\protocol' `
  --script 'res://scripts/debug/flow_smoke_test.gd'
```

---

## Baseline verification log (2026-06-21)

| Check | Result |
|-------|--------|
| `npm run validate-data` | PASS |
| Ability audit | **78 passed, 0 failed** |
| Flow smoke test | **PASS** (11 steps, no errors) |
| `--debug-battle` | PASS (screenshot 450×1000) |
| UnitSelect `--quit-after 3` | PASS |

### Manual spot-check (recommended once per session)

Play one full battle from UnitSelect through victory to the reward screen. Confirm dice roll, targeting, protocol footer, and reward transition feel normal.

---

## What this baseline does not cover

- Visual/readability polish (see `docs/BATTLE_UI_V2_SPEC.md` open tuning areas)
- Balance sim full-clear targets (see `balance_sim_facility.ts`)
- Headless `--check-only` does not parse the full script graph — prefer the runners above
