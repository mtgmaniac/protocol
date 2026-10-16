# Branch reconcile: proto/ui-cleanup into main (2026-10-16)

Phase 0 inventory, written before anything changed. Updated after the merge in
"Phase 2" at the bottom.

## 1. Branches (after `git fetch --all`)

`main` and `origin/main` are the same commit, `3d095d2` (2026-10-11, "Re-pin the
sim to the prestige-trait game; record G-74"). `claude/prestige-traits` and
`codex/battle-ui-pixel-restyle` point at that same commit.

| Branch | Head | Date | Subject |
|---|---|---|---|
| proto/ui-cleanup | 82faed9 | 2026-10-16 | ui-cleanup: verify + final report |
| proto/ui-unify | 86f6037 | 2026-10-16 | ui-unify: last legacy buttons to secondary |
| proto/flat-pixel-b | 9e65ddd | 2026-10-16 | flat-pixel-b: verify + final report |
| proto/flat-pixel-a | d0093ea | 2026-10-16 | flat-pixel: verify + final report |
| proto/ui-restyle-a | 40946c3 | 2026-10-16 | docs: record battle depth v2 prototype in TRUTH and DECISIONS_RESOLVED |
| proto/battle-depth-v3 | 80296e3 | 2026-10-13 | proto: battle depth v3 (full-bleed scene, transparent die tags) |
| proto/battle-depth-v2 | f2b2beb | 2026-10-13 | proto: battle depth v2 (draw-time perspective, tray scene, contact shadows) |
| codex/battle-depth-prototype | d18fda2 | 2026-10-13 | proto: battle depth v1 (checkpoint) |
| main, origin/main, claude/prestige-traits, codex/battle-ui-pixel-restyle | 3d095d2 | 2026-10-11 | Re-pin the sim to the prestige-trait game; record G-74 |
| origin/claude/prestige-traits | 9ebe7fa | 2026-10-10 | Prestige traits replace Directives; no enemy traits on a first run; bosses hold their slot (G-70 to G-73) |
| claude/traits-beasts-geode (+origin) | 04db4a8 | 2026-10-10 | Size-break stamp for the re-pinned sim (G-67) |
| claude/two-tier-sim-gate (+origin) | 47f47c6 | 2026-10-09 | Handoff for the two-tier sim gate |
| claude/cloak-and-windows (+origin) | 97b5bf9 | 2026-10-09 | Baseline re-pinned to the tuned game; numbers approved (G-57) |
| claude/feedback-polish (+origin) | c6e9dd3 | 2026-10-08 | THE COURT's rule text names the moment its Firewall goes up |
| claude/resume-and-settings (+origin) | b736eb5 | 2026-10-08 | Handoff 2026-10-08: CONTINUE claim, stinger, Nudge warnings, display recovery |
| claude/firewall-hack-coverage (+origin) | 47d784f | 2026-10-06 | Add hop launch capture |
| claude/wip-reroll-hop (+origin) | d76b863 | 2026-10-05 | Reroll hop: launch from a random orientation |
| origin/claude/wip-floor-router | 58e6ac2 | 2026-10-05 | WIP (not for merge): silhouette floor router + gate (l) |
| origin/claude/wip-spawn-fix | 0d0134e | 2026-10-05 | WIP (not for merge): verified spawn fallback, gate (m) |
| origin/claude/dice-overlap-stalemates | 1d22fa7 | 2026-10-05 | Record G-46 |
| origin/claude/design-audit-2026-10-02 | b0b9053 | 2026-10-04 | Design audit: correct the all-cloaked targeting claim |
| origin/claude/playtest-fixes-dev-tools-thep00 | ca491ba | 2026-10-02 | Save the battle's owed XP (run save v4) |
| playtest-fixes-2026-10-01 (+origin) | e3cb5e6 | 2026-10-02 | Handoff: playtest bug-fix batch 2026-10-01 |
| codex/godot-telemetry | e8835cb | 2026-09-28 | WIP: telemetry client, unfinished |
| origin/boss-relic-rework | 88d9e39 | 2026-09-28 | Boss relic rework: final tuning |
| older (2026-04-15 to 2026-09-27) | | | 60 more local/remote branches: `feat/*`, `fix/*`, `audit/*`, `docs/*`, older `codex/*`, `claude/*`, `framing-*`, `dice-*`, `text-legibility*`, `backup/build-df`, `assets/item-icons-64-72` |

Full list: `git for-each-ref --sort=-committerdate refs/heads refs/remotes`.

## 2. proto/ui-cleanup against main

- **Merge base:** `3d095d2`, which is `main`'s head. `main` is an ancestor of
  `proto/ui-cleanup`.
- **Commits on main not in proto/ui-cleanup: none.** Nothing landed on `main`
  after the UI stack branched, so merging `main` in is a no-op ("Already up to
  date"), with no conflicts possible.
- proto/ui-cleanup is 41 commits ahead of main: the whole UI stack, in order
  battle-depth v1 (`d18fda2`), Protocol meter fix (`aaed29a`), depth v2, v3,
  UI restyle A (`cbf3915`, `40946c3`), flat-pixel A, flat-pixel B, ui-unify,
  ui-cleanup. So `codex/battle-depth-prototype`, `proto/battle-depth-v2/v3`,
  `proto/ui-restyle-a`, `proto/flat-pixel-a/b` and `proto/ui-unify` are all
  ancestors of proto/ui-cleanup.

### What the UI stack touches outside styling

From `git diff --stat main proto/ui-cleanup` (113 files). No file under
`data/raw/` changes except a new `data/raw/battle-tray-scenes.json`
(per-operation tray floor/backdrop, presentation only). No save code
(`GameState.gd`, `SaveManager.gd`) changes. Gameplay-adjacent scripts it edits:
`battle_scene.gd`, `protocol_actions.gd`, `boss_relic_actions.gd`,
`inspect_resolver.gd`, `battle_feedback.gd`, `dice_tray_3d.gd`. These are the
files Phase 2 reads for behavior changes.

Docs it adds that look like design material but are not rulings:
`docs/UNIT_VARIETY_CHANGES.json` + `docs/Unit_Variety_Draft.xlsx` (an HP/damage
"archetypes" draft for every non-boss enemy; nothing applied to data),
`docs/ENCOUNTERS_2026-10-10.md` (read-only listing),
`docs/BATTLE_LOSS_RATES_PRE_TRAITS.md`, `docs/COPY_DATA_MISMATCHES.md`.

## 3. Commits in neither main nor proto/ui-cleanup

Every other branch was checked with `git rev-list B ^main ^proto/ui-cleanup`.
All but seven are fully contained. The seven:

| Branch | Commits | Files | What it is | Verdict |
|---|---|---|---|---|
| origin/claude/playtest-fixes-dev-tools-thep00 | ca491ba (2026-10-02) | GameState, SaveManager, TRUTH, 2 tests | Owed battle XP saved (run save v4) | **Already on main** in other commits: `_battle_effective_rolls`/`_battle_end_alive` are in `SAVED_RUN_FIELDS` (`GameState.gd:1887`). Superseded. |
| origin/claude/design-audit-2026-10-02 | 9c08db3, b0b9053 | docs/DESIGN_AUDIT_2026-10-02.md | Descriptive audit, no code | Doc only. Not merged, nothing lost in play. |
| codex/godot-telemetry | e8835cb (2026-09-28) | Telemetry autoload, gate, TRUTH/DECISIONS lines, export preset | "WIP: telemetry client, unfinished" | **Unmerged feature, for Kev's decision.** Carries draft DECISIONS/TRUTH text. |
| origin/claude/wip-floor-router | 58e6ac2 | dice_tray_3d.gd, dice gate | "WIP (not for merge)" | Superseded by the reroll-hop work (G-47) and G-54 "spawn overlap not worth fixing". |
| origin/claude/wip-spawn-fix | 0d0134e | dice_tray_3d.gd, dice gate | "WIP (not for merge)" | Same as above. |
| backup/build-df | f9ed77f (2026-07-15) | unlocks, UnlockScreen, DataManager, GameState, SaveManager | Build F backup | Superseded: unlock progression and UnlockScreen are on main in later form. |
| audit/references | f5ab59c (2026-07-07) | docs/audit/REFERENCE_AUDIT.md | July reference audit | Doc only. |

None of the seven holds a DECISIONS_RESOLVED ruling that main lacks.

## 4. October rulings against the code

Checked on `main` (`3d095d2`) and `proto/ui-cleanup` (`82faed9`). Because main
is an ancestor and the UI stack changes no gameplay data or save code, the
gameplay half of each row is the same on both; the UI half is listed where
the UI stack touched the display.

| Ruling | Status | Where |
|---|---|---|
| **G-71 hero traits only at the 250 XP prestige pick** (none at the 100 XP evolution; card shows callsign only before prestige) | Implemented | `UnitTraits.PRESTIGE_XP := 250` (`scripts/battle/unit_traits.gd:37`), `GameState.XP_TO_PRESTIGE` (`GameState.gd:149`); gate `traits`. UI stack keeps `_trait_label` on the card (`compact_unit_card.gd`). |
| **G-72 no enemy traits on a player's first run** | Implemented | `SaveManager.enemy_traits_enabled()` (`SaveManager.gd:780`), flag set at run end (`:854`), `DataManager.enemy_for_battle` (`DataManager.gd:366`); gate `first run` (breaks `traits_on`, `no_flag`). |
| G-73 False Image summon flag removed | Implemented | `enemies.data.json`; `validate-data` rule. |
| G-70 bosses never replaced/removed by a modifier | Implemented | `GameState._shape_comp_for_modifier`, `lineup_for_battle`; gate `boss lineup`. |
| **G-69 Signal Hierophant -> Signal Hierarch, callsign HIERARCH** | Implemented | `enemies.data.json:3185`/`:3192`, legacy alias `DataManager.ENEMY_LEGACY_NAMES` (`:215`). |
| G-68 one shared portrait frame; Shield Enforcer callsign SHIELD | Implemented | `PixelUI.make_portrait_frame`; gates `framing sites`, `portrait frame`. |
| G-66 Feral on every non-boss beast | Implemented | `traits.data.json`; gate `traits` (`boss_trait`). |
| G-65 HP preview includes traits | Implemented | `CombatManager.forecast_round`; gate `trait preview`. |
| G-64 trait requirements | Implemented | `traits.data.json` tags, `validate-data`. |
| **G-60 beast pack + rampage** (rampage on/off, spent by the next turn; pack +3 per packmate) | Implemented | `PACK_BONUS_PER_MEMBER := 3` (`combat_manager.gd:2762`); gate `rampage` (breaks `stack,keep,pack_one`). |
| G-61 Geode Panther attacks the die it freezes | Implemented | gate `geode targeting`. |
| **G-53 new roll windows** | Implemented | hero/enemy kits in `heroes.data.json` / `enemies.data.json`; gates `roll windows` (static) and `roll windows live`. |
| **G-52 cloak is an ambush** | Implemented | `AMBUSH_MULT := 1.5` (`combat_manager.gd:2834`, tuned from the ruling's starting 2x per G-55); all-cloaked -> random target; gate `cloak ambush` (6 breaks). |
| G-47 reroll is a hop; G-46 no round limit; G-48 to G-50 resume/settings/display | Implemented | merged October branches, all ancestors of main. |
| **Scrapmaster healing 8 HP per living Scrap Drone** | **Not found** | No ruling in DECISIONS_RESOLVED or TRUTH, and no code or data on any branch. The Scrapmaster rule is ASSEMBLY LINE (rebuild one Scrap Drone at 50% HP every 2nd enemy phase, `SCRAPMASTER_REBUILD_PCT := 50`, `combat_manager.gd:152`), DECISIONS #5. Also noted in `docs/COPY_DATA_MISMATCHES.md`. |
| **Signal Wisp summons** | **Existing behavior only; no new ruling** | Five Signal Purge overloads summon a Signal Wisp (`voidAcolyte` 40%, `voidScribe` 45%, `voidBinder` 35%, `voidChanneler` 42%, `voidCircletBoss` 32%). G-54: "Summons are on hold pending my decision; don't change them." No later ruling found on any branch. |
| **Hive summon identity** | **No ruling found** | Today THE BROOD (Hive Matriarch, every 3 rounds) spawns a Bloodmite (`BROOD_SPAWN_NAME`, `combat_manager.gd:120`); Bloodmite appears nowhere else in `battle-modes.json`. No Hive regular summons. Covered by G-54's summon hold. |
| Unit variety (archetype HP/damage) draft | **Draft only, not a ruling** | `docs/UNIT_VARIETY_CHANGES.json` on the UI stack; no data changed. |

The three "not found" items appear to be pending design ideas, not recorded
rulings. Per the working rules they are not implemented from chat memory.
