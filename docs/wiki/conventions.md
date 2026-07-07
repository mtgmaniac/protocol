# Conventions — everything a new agent must follow

> Part of the [Overload Protocol wiki](INDEX.md). See also: [decision-log.md](decision-log.md), [keywords.md](keywords.md), [statuses-and-chips.md](statuses-and-chips.md), [targeting.md](targeting.md).

This page codifies the working rules of the repo at `C:\Users\Kev\Documents\protocol`.
Sources: `docs/TRUTH.md` (canon), `docs/INVARIANTS.md` (the WHY rules),
`docs/DECISIONS_RESOLVED.md` (closed rulings), `docs/TASK_TEMPLATE.md`,
`scripts/hooks/*`, `scripts/verify_gate.py`. Where this page and those files ever
disagree, they win — fix this page.

---

## Reading order (before ANY edit)

1. `docs/TRUTH.md` — what the game IS (wins every doc conflict).
2. `docs/INVARIANTS.md` — WHY it must stay that way + what violations look like.
3. `docs/DECISIONS_RESOLVED.md` — closed rulings. Never relitigate.
4. Then the runtime map (`docs/AI_AGENT_GAME_REFERENCE.md`), layout contract
   (`docs/BATTLE_UI_V2_SPEC.md`), and `offline-bundle/CODEBASE_MAP.md`.
5. Every task follows the skeleton in `docs/TASK_TEMPLATE.md`.

**Doc supremacy (INVARIANTS #10):** TRUTH beats every other doc; code beats TRUTH
(fix TRUTH and record the correction). Any behavior change updates TRUTH.md **in the
same commit** or the task is incomplete. Archived docs in `docs/archive/` are
history only.

## DECISIONS_RESOLVED process

- **RESOLVED & IMPLEMENTED** entries are done — executing sessions cite them, never
  re-open them without a new explicit ruling from Kev.
- **RULED — IMPLEMENTATION PENDING** entries: step 0 of the implementing session is
  to **transcribe Kev's ruling text VERBATIM into the entry**, then implement
  against the written ruling. Implementing a pending ruling from a chat log or from
  memory is a process violation — the ruling lives in the repo, not in anyone's head.
- Entry numbers are permanent (they match the old TRUTH.md DECISIONS list) so old
  references stay valid.
- Balance items #6–#10 and #17 are DEFERRED to the global balance pass: every cited
  number stays untouched until that ruling.

---

## Data files, schemas, and the validation gate

- Game data lives in `data/raw/*.json`: `heroes.data.json`, `enemies.data.json`,
  `items.data.json`, `gear.data.json`, `relics.data.json`, `battle-modes.json`,
  `keywords.data.json`, `primers.data.json`.
- Schemas live in `data/schemas/` (heroes, enemies, battle-modes, primers).
  **After ANY `data/raw/` edit run `npm run validate-data`**
  (→ `scripts/assets/validate-game-data.mjs`, ajv) **plus the ability audit**
  (`scenes/debug/AbilityAuditRunner.tscn`, headless — expect `0 failed` AND a pass
  count ≥ the `AUDIT_MIN_PASSED` floor in `scripts/verify_gate.py`).
- Schemas are deliberately strict (`additionalProperties: false`); dead fields
  (`shT`, `cower*`, `counterspellPct`, phase-2 fields, `xpBoost`) were removed from
  the schemas so they cannot come back silently.

## Ability `eff` text — the canonical grammar (TRUTH §Ability eff text syntax)

Format: `[value] [type] [target] [duration]`, effects joined by ` + `. Numbers
first, type second, target third, duration last; target omitted for a single enemy;
duration omitted when instant.

- Damage: `12 dmg` · `9 dmg all` · `10 dmg + pierce`
- Burn: `4 burn 3t`
- Heal: `8 heal ally` / `13 heal all` / `11 heal lowest`
- Shield (one round — NEVER a duration suffix): `ally 9 shield` / `all 14 shield`
- Roll: `+3 roll ally` / `-2 roll all enemies 2t`
- Protocol: `+2 protocol`
- Status: `freeze (repeat 1)` / `freeze any (repeat 1)` / `freeze all (repeat 1)` /
  `cloak` / `self firewall` / `taunt` / `rampage +1`
- Boss extras: `wipe shields` / `summon 40%` (no phase-2 syntax — that system is dead)

`scripts/debug/audit_eff_text.py` regenerates/verifies eff strings (0 mismatches
expected). Target-scope display vocabulary is pinned: **SELF / ALLY / ALL** only —
no OTHERS, no ALL·FOE.

## Data field glossary

`dmg` · `burn`+`burnT` · `heal` (+`healTgt`/`healAll`/`healLowest`) ·
`shield` (+`shieldAll`/`shTgt`/`shieldLowest`) · `rfe`+`rfT` (+`rfeAll`) ·
`rfm`+`rfmT` (+`rfmTgt`) · `ignSh` (pierce) · `blastAll` · `cloak` ·
`ward` (+`wardTgt`; **displayed Firewall**) · `taunt` / `enemySelfTaunt` ·
`revive` (+`revivePct`/`reviveAll`) · `freezeAnyDice`/`freezeEnemyDice`/
`freezeAllEnemyDice` (+`repeats`, cosmetic `freeze_flavor`: ice/petrify) ·
`vsFrozenBonus`. Keywords: `chain`, `detonate`, `execute`, `breach`/`breachAll`,
`leech`, `mark`, `spike`, `jam`/`jamAll`, `rewrite`, `hijack`, `siphon`.
Zone names: `recharge` → `strike` → `surge` → `crit` → `overload`.

## Naming schemes

- **Hero ids** are lowercase single words; three are **legacy and FROZEN**
  (INVARIANTS #11): Strike Unit = `combat`, Spike Guard = `shield`,
  Splice Medic = `medic`. Saves, gear tables, and sim telemetry key on them —
  never "clean up" an id.
- **Operation ids** are camelCase and FROZEN even where the display name changed:
  `voidCirclet` (displays "Null Synod"), `stellarMenagerie` (displays
  "The Accretion"). Player-visible strings must use the NEW names; internal ids
  never change.
- **Evolution ids** = lowercased callsign, schema-enforced (pyro, arc, blade,
  ravager, bulwark, sentinel, glacier, trench, medic, synth, overclocked, phantom,
  shadow, wraith, noise, nullwire).
- **Callsigns** ≤ 8 chars (enemies schema `maxLength`).
- **Portraits:** hero base `assets/portraits/<hero_id>.png`; evolved
  `assets/portraits/<hero_id>_<evo_id>.png` (missing file silently falls back to
  base — never errors, never blanks). Enemy art in `assets/portraits/enemies/` via
  the explicit `ENEMY_PORTRAIT_BY_NAME` map (bare filenames only), fallback
  `_slugify(display_name).png`. Unreferenced art is quarantined in
  `assets/portraits/enemies/unused/`, kept not deleted. All framing goes through
  the crop-to-content contract (`_crop_to_content` + `PixelUI.cover_fit_portrait()`)
  — **never per-unit pixel offsets**. Rerun
  `python scripts/assets/defringe_alpha_edges.py` when new cutout art lands.
- `legacy-angular/` is an asset warehouse ONLY — never revive app code there
  (INVARIANTS #11).

## Combat-design budgets (audit-enforced)

- **One keyword per ability; overload faces may carry two** (INVARIANTS #3).
  Pierce (`ignSh`) COUNTS as a keyword — it is not "free".
- **Max ONE manually-picked component per hero ability** (INVARIANTS #12).
  Components sharing a pick (dmg+burn on one enemy) count once; `freezeAnyDice`
  counts as the pick. Everything else auto-targets (self / all / lowest).
- **The dice-suppression complexity budget is SPENT** (INVARIANTS #4): jam /
  rewrite / hijack / freeze fills it. Default-REJECT any fifth keyword that
  "locks", "corrupts", "glitches", or "delays" a die. Open design space is
  hero-side RISK and MOMENTUM.
- **Legibility beats cleverness** (INVARIANTS #5): if a rule can't be one sentence
  in an inspect popup, it's wrong (the twice-killed bank/thaw freeze is the
  precedent).
- **Enemy AI is a legible rule, not a mind** (INVARIANTS #6): max 4 targeting
  personalities (SYSTEMATIC / WOUNDED / PACK / SPITEFUL), deterministic, one
  choke-point (`targeting_personality.gd::personality_pick_target`), surfaced
  verbatim in the inspect popup. `ai_type` is a SEPARATE, load-bearing field
  (nat-20 elite summons + summon-injection guard) — never derive targeting from it
  or vice versa (INVARIANTS #2).
- **Shatter** exists ONLY as the Glacier Mantle rider (`vsFrozenBonus`) and the
  Cold Logic relic — nowhere else.

## Chip doctrine (current — post DECISIONS #16)

Card chips are exactly: **Burn / Shield / Mark / ±Roll / Firewall / Taunt**
(cap 3, +N overflow badge opens inspect). Everything else has its own surface:
Cloak = ghosted portrait · Freeze/Petrify = die crust (ice cyan / stone gray) ·
Jam = die tint + "JAM ≤10" marker · Rewrite/Hijack = pending die marker + readout ·
Spike = readout pip only. The shield chip was cut in pkg8.1 and **restored per Kev
(DECISIONS #16)** — it is canon; it drops at the per-side phase tick, not round end.
Do not add new chips without a ruling.

## Determinism fence (INVARIANTS #1)

All combat outcomes flow through the seeded roll provider
(`scripts/sim/roll_provider.gd` seam); the 3D tray physics is presentation only.
The headless sim must reproduce any battle byte-identically from a seed.
**No `randi()` in combat/targeting code** (SeededRollProvider or nothing); no
mechanic may depend on physical dice positions. Freeze=repeat passes the fence:
the crust is presentation, the locked face is engine state. Any new event marker
for primers/feedback must be observer-only and never change outcomes.

## Balance discipline

- Target: **25–40% skilled full-clear of facility in real play**; sim metric =
  per-op AND per-hero clear-rate variance (policy l1, `scripts/sim/baseline.json`).
- **Numbers move together** (INVARIANTS #8) — tune in passes, measure the whole
  table (`python scripts/sim/ci_smoke.py`, sweeps via `scripts/sim/sweep.py` +
  `scripts/sim/knobs.json`).
- **Baseline ceremony (INVARIANTS #9):** report per-op deltas vs the pre-change
  snapshot BEFORE any baseline update; any per-op move beyond **±10 points**
  requires Kev's sign-off — the commit must contain the literal token
  `BASELINE-APPROVED-BY-KEV` or the commit-msg hook aborts it.
- Deferred numbers (#6–#10, #17) re-anchor to the crit-banking checkpoint
  (overall 0.2867); Avalanche 23.7% is the known repricing target — **no ability
  numbers move until that ruling**.

## Enforcement hooks

Installed via `git config core.hooksPath scripts/hooks`.

| Hook | File | Rule |
|---|---|---|
| commit-msg | `scripts/hooks/baseline_ceremony.py` | ABORTS a `baseline.json` commit with any per-op drift beyond ±10 pts unless the message contains `BASELINE-APPROVED-BY-KEV` |
| commit-msg | `scripts/hooks/threshold_guard.py` | the ratchet (INVARIANTS #13): LOOSENING any watched enforcement threshold needs the token; tightening is free. Watched: growth watermarks (max), `CEREMONY_PTS` (max), ci_smoke tolerances (max), `AUDIT_MIN_PASSED` (a FLOOR — lowering needs the token) |
| pre-commit | `scripts/hooks/battle_scene_growth.py` | WARNS (never blocks) when `battle_scene.gd` (> 2610 lines) or `protocol_actions.gd` (> 971) grows past its watermark — these files get SPLIT, not grown |

Principle: **you can't loosen enforcement on yourself.** Precedents: the
3378→3416 watermark self-raise; the extraction that silently lost 6 audit
recordings (hence the pass-count floor).

## Verify commands (the gate)

Godot binary:
`C:/Users/Kev/Downloads/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64_console.exe`

```
python scripts/verify_gate.py            # everything + per-op delta table (--skip-sim / --runs N)
npm run validate-data                    # JSON schema gate
<godot> --headless <proj> scenes/debug/AbilityAuditRunner.tscn   # expect 0 failed, count >= AUDIT_MIN_PASSED
<godot> --headless <proj> -s scripts/debug/flow_smoke_test.gd
<godot> --headless <proj> -s scripts/debug/tutorial_smoke_test.gd
<godot> --headless <proj> -s scripts/debug/primer_smoke_test.gd
<godot> --headless <proj> -s scripts/debug/run_smoke_test.gd
<godot> --headless <proj> scenes/debug/freeze_engine_regression.tscn
<godot> --headless <proj> scenes/debug/DiceTrayPhysicsProbe.tscn  # any dice change: 0/0/0
<godot> <proj> -- --debug-battle         # windowed battle + screenshot
python scripts/sim/ci_smoke.py           # balance diff vs baseline.json
```

Gotchas: run the ability audit as a SCENE (autoloads required), not `--script`;
`--check-only` misses parser errors outside the launched scene's dependency chain —
run the audit or `--debug-battle` and watch the console. UI claims require a fresh
screenshot ("do not claim an improvement unless the screenshot plainly shows it").

## TASK_TEMPLATE workflow (`docs/TASK_TEMPLATE.md`)

Every task prompt fills every section — a task that skips one is incomplete by
definition:

1. **STEP 0 — CONTEXT:** read TRUTH → INVARIANTS → DECISIONS_RESOLVED (transcribe
   any pending ruling FIRST); run `verify_gate.py` on the untouched tree and record
   the per-op snapshot.
2. **CONSTRAINTS:** explicit, citing invariants by number (e.g. #1 determinism,
   #3/#12 budgets, #2 ai_type, #11 frozen ids).
3. **CHANGE:** the smallest coherent slice.
4. **VERIFY:** full gate + a NAMED task-specific regression that pins the changed
   behavior.
5. **REPORT:** per-op deltas vs the step-0 snapshot BEFORE any baseline update;
   |delta| > 10 pts → STOP, report to Kev, never self-approve.
6. **CLOSEOUT (same commit):** TRUTH.md updated; DECISIONS_RESOLVED updated if a
   ruling was implemented; new regressions committed with the change they pin.

## PixelUI token system + UI doctrine

- `PixelUI` (`scripts/ui/pixel_ui.gd`) is the single source of visual constants
  (Direction-05 `DT_*` palette); `theme_overload.tres` only mirrors it. **Never
  hardcode hex in a scene script** (INVARIANTS #7).
- Meaning-based color: **cyan/teal** = player + primary actions · **red/rust** =
  enemy/damage · **green = HP bars and heals ONLY** · **amber** = protocol pips,
  risk/confirm, unlock accents · **gold** = commit/reward moments.
- Grouping uses filled plates, never stroked outlines. Primer/keyword text is one
  sentence, ~12 words max (90-char schema cap), stating the RULE not flavor.
- All pips build through `EffectPip` (`scripts/ui/effect_pip.gd`,
  `docs/EFFECT_PIP_GUIDE.md`) — no local icon maps or value formatting in UI files.
- Font: `m5x7`; pixel art; hard edges, no gradients/glow/bloom.

### Pixel snap law (INVARIANTS #14) + even-stroke rule

- Every ratio-derived UI position/size must round to whole PHYSICAL window pixels
  before drawing — use `PixelUI.snap_to_physical_px` / `physical_px_width` (they
  compose the viewport's FINAL transform, which
  `get_global_transform_with_canvas()` does NOT include).
- Snapped draw layers must `queue_redraw` on `viewport.size_changed`.
- Godot-drawn strokes (StyleBoxFlat borders) can't be per-instance snapped, so the
  SCALE is integer-friendly instead: the dev preview window is **540×1200 — exactly
  half** of 1080×2400 — and **stroke widths must be EVEN design pixels** (2/4/6 →
  crisp 1/2/3 window px; a 3px stroke shimmers).

### Layout contract

Portrait **1080×2400**, five stacked bands: Header 144 — Enemy rail 768 — Center
rail 432* — Hero rail 768 — Footer 144 (Reroll, Nudge, Set, Item + PROTOCOL n/m
amber pips). Header height == footer height; all unit cards identical outer size;
dice align to card slots; result tags are uniform die-docked plates; no scrolling;
touch-first. This layout + the frozen legacy ids are contractual (INVARIANTS #11).
*The live center band uses 540px by design (`battle_layout.gd`) — the 432 figure is
the original spec value; the runtime constant wins.

## Branch / workflow habits

- Backend/data/combat → `fix/cleanup`-style branches; UI → `feat/*` / `codex/*`;
  never batch unrelated UI + backend in one commit.
- One prompt → diff → test → commit. After any `data/raw/` edit: validate-data +
  ability audit.
- Commit messages carry the verify results and (for balance-adjacent work) the
  per-op delta table.

## File locations
- `docs/TRUTH.md` · `docs/INVARIANTS.md` · `docs/DECISIONS_RESOLVED.md` ·
  `docs/TASK_TEMPLATE.md`
- `scripts/verify_gate.py` · `scripts/hooks/{commit-msg,pre-commit,baseline_ceremony.py,threshold_guard.py,battle_scene_growth.py}`
- `data/schemas/*.json` · `scripts/assets/validate-game-data.mjs`
- `scripts/ui/pixel_ui.gd` · `scripts/ui/effect_pip.gd` · `docs/EFFECT_PIP_GUIDE.md`
- `scripts/battle/targeting_personality.gd` · `scripts/sim/roll_provider.gd` ·
  `scripts/sim/baseline.json` · `scripts/sim/knobs.json`

## Known edge cases
- Headless save profiles read as fully unlocked (sim/audit can pick any hero/op) —
  don't "fix" that.
- `class_name` scripts need one Godot run with `--import` after a fresh clone so
  the class registers (`.godot/` is gitignored).
- Wall of Static's cap-15 jam clause is an intentional exception to `JAM_CAP = 10`.
- `shieldsPersist` (Mantle Core / MANTLE TYRANT) is the ONLY legal shield
  persistence; nothing else may persist a shield.

## ⚠ Open findings
<!-- AUDIT-LINKS:conventions -->
- [A-089](../audit/INTERACTION_AUDIT.md#a-089) - [confusing] 450x1000 preview size stale in four docs
- [A-090](../audit/INTERACTION_AUDIT.md#a-090) - [confusing] CLAUDE.md 'do not contradict' table contradicts code
- [A-091](../audit/INTERACTION_AUDIT.md#a-091) - [dead] AI_AGENT_GAME_REFERENCE points to the deleted TS sim
- [A-092](../audit/INTERACTION_AUDIT.md#a-092) - [confusing] BATTLE_UI_V2_SPEC references deleted scenes
- [A-093](../audit/INTERACTION_AUDIT.md#a-093) - [confusing] ANIMATION.md guardrail says green = protocol
- [A-094](../audit/INTERACTION_AUDIT.md#a-094) - [confusing] CODEBASE_MAP.md materially stale
- [A-097](../audit/INTERACTION_AUDIT.md#a-097) - [confusing] GDD battle-card lists gear slots/XP bar not on cards

Resolved (2026-07-08 fix pass): [A-086](../audit/INTERACTION_AUDIT.md#a-086)
