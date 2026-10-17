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

## Phase 1: the merge

`integration/ui-merge` was cut from `proto/ui-cleanup` (`82faed9`) and the
Phase 0 doc committed on it (`23fcc2d`). `git merge main` answered "Already up
to date": main (`3d095d2`) is an ancestor, so git makes no merge commit and there
were **no conflicts to resolve**. No other branch was merged.

Branches holding work that is in neither main nor the UI stack, for Kev's
decision: `codex/godot-telemetry` (unfinished telemetry client with draft
TRUTH/DECISIONS text). Everything else listed in section 3 is superseded, doc-only
or marked not-for-merge.

## Phase 2: post-merge behavior

**Traits on the merged code.** A hero card shows a trait line only once the hero
holds a trait, which happens only at the 250 XP prestige pick
(`UnitTraits.PRESTIGE_XP`); before that the card shows the callsign alone. An enemy
card shows its trait (elites, every non-boss Mantle Hunt beast) only when
`SaveManager.enemy_traits_enabled()` is true, i.e. after the profile's first run
ended in a victory or defeat. On a first run every enemy is fielded as a trait-less
copy (`DataManager.enemy_for_battle`), so no enemy trait line and no trigger: the
first-run rule holds. Bosses never show a trait. The UI stack changes only the
trait line's styling and position. Gates on `integration/ui-merge`: `first run`,
`traits`, `trait preview`, `validate-data` PASS.

**Rulings table.** Unchanged from section 4 (the merge changed no file).

**What the UI stack broke or hid that main had working.** Found by running the
42 UI-facing gates on the merged branch:

| Gate | Cause | Fix |
|---|---|---|
| `boss nameplate` | Script error, then a 90 s hang: the test read `border_color` / `bg_color` off the card's panel styles, which the battle card skin (2026-10-12 component review) made `StyleBoxEmpty`; the skin paints the frame and title strip. Behavior intact. | Test reads the skin's palette (`_skin_front.border`, `_skin_back.title_fill`). |
| `no animations` | The restyled settings row nests its label in a text column; the test looked for the label as the row's first child. The Reduced motion row still shows its own setting. | Test finds the row's label anywhere in the row. |
| `web loader palette` | `web/shell.html` (the web loader) still painted the retired cyan (`#6fe0ef`, `#3fd0e2`), which no PixelUI token holds any more: the loader no longer matched the game it hands off to. | Loader recolored to the current tokens: text `UI_TEXT`, accent and bar `PLAYER_ACCENT`, the reload button primary, the logo glow `PROTOCOL_ACCENT`. |
| `boss relics` | Caused by this pass's Phase 3 snap, not the UI stack: in a window too small for one screen px per font pixel the snap scaled Battle Block labels above their cap, so the header label covered the screen and swallowed the "tap empty space cancels" test tap. | `block_pixel_px` never returns more than the cap. |

All other 38 gates in the set passed. No gameplay, data or save behavior changed.

## Phase 3: finish (2026-10-16)

### Rulings, verbatim, with scope

**INVARIANTS #7 (UI doctrine).** Scope: every screen; the six-components and
capitalization paragraphs are Polish Build A (Kev, 2026-07-14). Opening
paragraph: "Green is reserved for HP bars and heals — nothing else is ever
green. Grouping uses filled plates, never stroked outlines. Primer/keyword text
is one sentence, ~12 words max, stating the RULE not flavor. `PixelUI` is the
single source of visual constants; `theme_overload.tres` only mirrors it." Six
components: "every panel frame is one of six `PixelUI.component_style` kinds;
strong cyan borders belong to `selected_card` only, strong gold to
`major_event` only; one 4px frame width — rank is color, never width." (Also
the capitalization law and band vocabulary, unchanged.)

**Ruling #18 (DECISIONS_RESOLVED, Kev, 2026-07-10, UI review S-2).** Scope: the
rarity tokens and the evolution branch-name green. "**Ruling:** recolor. Rarity
ladder is gray → blue → purple → orange: common `#7a8290` (keep) · uncommon
`#5b7fe8` (was rare's blue) · rare `#9d52d8` (was epic's purple) · legendary
`#ff8230` (keep). … Green now has zero non-HP/heal surfaces."

**Build B reward presentation (TRUTH, Kev ruling).** Scope: the reward screen
(`reward_screen.gd`), i.e. every reward draft including battle 5's relic
cache. "RELIC offers stay ceremonial: two large Major-event (gold) cards —
deliberately a tier above ordinary rows, split builders on purpose
(`reward_screen._create_reward_row` / `_create_relic_card`)."

**Does Build B cover boss relic rewards?** No. Boss relics are never reward
offers: `GameState._roll_relic_choice_ids` excludes them ("they unlock via first
operation clears"), and the unlock screen shows them on its own gold card
(`unlock_screen._make_boss_relic_card`, untouched). The "two" relic offers are
the relic cache (`RELIC_ONLY_ROUND := 5`, `RELIC_CHOICE_COUNT := 2`). So the
ruling covers the relic cache, and the cache gets the ceremonial cards back.

### What changed

| Change | Files | Gate |
|---|---|---|
| Relic cache: ceremonial cards restored (from `5008f47`), minus the "RELIC" label. Effect pips also stay off: the earlier fix removed Field Cache's green +1, which repeated its description. No Build B override needed. | `scripts/ui/reward_screen.gd`, `scripts/debug/reward_model_test.gd` (T7 asserts no RELIC label) | `reward model` PASS |
| Header ^ (auto turn) / ^^ (auto battle) exist in debug builds only. Release builds free both nodes in `_ready` (`strip_debug_buttons`), and SETTINGS > DEV drops the "Developer mode (header debug buttons)" toggle (`has_debug_buttons`). The seven-tap unlock still opens the other dev tools. G-10 asks that developer controls stay hidden until that unlock; it does not require the arrows in release, so no G-10 conflict. | `scripts/autoloads/PersistentHeader.gd`, `scripts/ui/help_menu.gd`, `scripts/debug/dev_unlock_test.gd` (release path: buttons freed, nothing brings them back) | `developer unlock`, `safe area` PASS |

### Governance edits (complete list)

1. `docs/DECISIONS_RESOLVED.md`, top: new **G-75** (color ownership, constant
   dice colors, notch rule, primary (solid, reverted 2026-10-17 to outlined cobalt with the notch) / outlined secondary / amber
   destructive with no stripes, type roles incl. CARD, GAP rule, Protocol
   color, rarity ladder, relic cache cards, debug-only ^/^^), with
   **Overrides**: #18 and INVARIANTS #7, each "overridden by Kev, 2026-10-16"
   with one reason line. #7 is overridden in two clauses only (green rarity;
   the component table replaces the six-component list).
2. `docs/DECISIONS_RESOLVED.md`, top: **"Decided 2026-10, NOT YET
   IMPLEMENTED"**: Scrapmaster heals 8 HP per living Scrap Drone; Signal Purge
   non-fodder units add a 25% Signal Wisp summon to their lowest band;
   summoning becomes Hive's identity; supersedes the G-54 summons hold once
   implemented. Recorded only.
3. `docs/DECISIONS_RESOLVED.md` #18: one line under the heading pointing at the
   override.
4. `docs/INVARIANTS.md` #7: one line under the heading pointing at the
   override.
5. `docs/TRUTH.md`: a three-line UI-authority entry at the top naming
   `docs/UI_STYLE.md`; the header chevron paragraph notes debug builds only.

### Verification

- **Full `verify_gate.py` (with sim), once:** 90 of 91 hard gates PASS,
  profile isolation PASS. **FAIL: `sim size break`**, not caused by this work.
  `main`'s G-74 re-pin (`3d095d2`) changed `baseline.json` /
  `baseline_pins.json` without re-stamping `scripts/sim/size_break_stamp.json`
  (last stamped at G-67), so the gate's real leg is due on `main` as well. Its
  Part B self-test then measured hive moving -7.9 points for a 1.08 damage
  scalar on 1,500 runs, under the ~10 it expects to flag. This branch changes
  no sim, data or pin file. Needs Kev's call (re-measure / re-stamp on main).
  Because a hard gate failed, `verify_gate` skipped the sim tripwire; it was
  run separately: **no move** (300 pinned runs per policy; l1 0.1833, l1_evo2
  0.2533; "the pinned runs reproduced exactly, so combat is unchanged").
- **Boot check, every player-facing screen** (scratch profile, a live run):
  MainMenu, UnitSelect, BattleScene, RewardScreen, InterceptScreen,
  RouteForkScreen, EvolutionScreen, UnlockScreen, RunEndScreen: all load with
  zero new errors. (UnlockScreen with nothing to unlock routes home, as built.)

### Deliverables (`debug_artifacts/ui_fix/`, gitignored, 390 px unless noted)

`battle_facility.png`, `battle_trait_card.png` (VIGILANT PATROL / VOLATILE VOLT
cards, 3x nearest crop of `battle_trait_full.png`), `battle_360.png` (360x800,
AVALANCHE / ENGINEER / BREAKER), `reward.png` (uncommon in leaf green),
`intercept_relic.png` (relic cache, ceremonial cards, no RELIC label).

### Branch cleanup

Checked with `git rev-list --count <branch> ^integration/ui-merge`. **Fully
contained, safe to delete:**

- `proto/battle-depth-v2`, `proto/battle-depth-v3`, `proto/flat-pixel-a`,
  `proto/flat-pixel-b`, `proto/ui-restyle-a`, `proto/ui-unify`,
  `proto/ui-cleanup`
- `codex/battle-depth-prototype`, `codex/battle-ui-pixel-restyle`,
  `codex/approved-copy`, `codex/boss-nameplate`,
  `codex/compact-battle-ui-three-unit-pips`, `codex/demo-finishing-review`,
  `codex/desktop-tutorial-fit`, `codex/final-feedback-revival`,
  `codex/title-unlock-polish`, `codex/tutorial-real-rolls`,
  `codex/ui-compact-card-prototype`
- Remote: `origin/codex/compact-battle-ui-three-unit-pips`,
  `origin/codex/dice-rules-containment`

**Keep: `codex/godot-telemetry`** (1 commit, `e8835cb`, not contained:
unfinished telemetry client with draft TRUTH/DECISIONS text).

### Fast-forward (for Kev; main was not touched)

`main` is an ancestor of `integration/ui-merge`, so this is a pure fast-forward:

    git checkout main
    git merge --ff-only integration/ui-merge
    git push origin main

## Phase 4: final fixes (2026-10-17)

- **Buttons.** The primary button is back to the pre-`83f3aaf` style: dark
  fill, cobalt border and thick left edge, light-cobalt text, the notch;
  pressed is a cobalt fill with ink text. One helper
  (`PixelUI.style_ui_primary_button`) serves every primary (ROLL / END TURN,
  CONFIRM, DEPLOY SQUAD, title CONTINUE / BEGIN, pop-up confirms).
  `PLAYER_FILL_TEXT` is deleted. Secondary and destructive unchanged.
- **HP numerals, diagnosis** (390 and 360 captures, 3x crops):
  a. *Glyph design:* Battle Block's digits are a classic 5x7 set. None thins;
     every stroke is one font pixel. Some are narrower at the bottom by
     design: 5 (5 wide on top, 4 at the bottom), 4 and 7 (end in one column),
     "/" (ends bottom-left). 0, 3, 6, 8 and 9 are symmetric.
  b. *Clipping:* none. Every font pixel was a whole 2x2 screen block, all 7
     rows present, with 2 screen px of bar left below.
  c. *Scaling / position:* the scale is uniform (f, f), but the label is laid
     out at 96 in a 78 bar. It grew downward only, and the snap scales about
     the label's own centre, so the numerals sat about 8 design px low: 8
     screen px of bar above them and 2 below at 390 (7 / 2 at 360). The low
     seat plus the narrow bottoms of 5 / 7 read as "melting".
  **Fix:** the HP label grows both ways, so it and its snap pivot are
  centred on the bar. Now 5 / 5 at 390 and 4 / 4 at 360. `stroke_runs`: every
  HP ink run a multiple of 2 at both widths.
- **HP options** (`CompactUnitCard.HP_NUMERAL_OPTION`, captures pass
  `--hp-numeral=A|B|C`; `debug_artifacts/ui_fix/hp_font_comparison.png`):
  **A chosen**, Battle Block at CARD, centred. It has even strokes, no
  render taper, clear gaps, and the same size on every card. B (one font pixel
  larger, "60/60") is bigger, but the digits and slash run together and sit 1
  font px from the bar edges. Three-digit boss HP does not fit at B, so a
  boss card would fall back to A's size beside larger numbers. C (m5x7 with
  the dice's own-colour outline and dark edge) draws blobby, uneven strokes.
- **Trait colours.** Before: every trait title was amber (`DT_AMBER`), and a
  trait flagged `warning` (only Volt Enforcer's VOLATILE: its death deals 4
  damage to each hero) was the damage red, per Kev's G-63 ("a warning color
  distinct from the other traits' amber"). Now every trait name is its card's
  name colour (enemy: the encounter-derived name; hero: the hero name). The
  `warning` flag stays in data (`UnitTraits.is_warning`) but no longer colours
  anything. Recorded in G-75; one line under G-63.
- **Housekeeping:** `assets/fonts/battle_block.svg.import` restored.
- **Gates (targeted):** layout rhythm, component contract, boss nameplate,
  traits, caps law PASS; also battle layout, text legibility, trait preview,
  preview accuracy, feedback honesty, wording fit, reward model PASS.
  `stroke_runs`: HP and callsigns k=2 at 390 and 360. Boot check: title,
  squad select, battle, reward, intercept, route fork, evolution, unlock, run
  end load with zero new errors; battle also boots with options B and C.
- **Found, not fixed:** at 360x800 the AVALANCHE callsign's first "A" loses its
  leftmost screen px column to the name strip edge (one-px runs in
  `stroke_runs`). It is the name label, not HP, and it predates this pass.
  The trait title line (m5x7 SMALL 48) is unsnapped by design, so its runs are
  uneven.
- **Deliverables** (`debug_artifacts/ui_fix/`): `hp_font_comparison.png`,
  `battle_facility.png`, `battle_360.png`, `battle_trait_card.png` (3x crop of
  `battle_trait_full.png`), `reward.png`, `title.png` (scratch profile with a
  run save: CONTINUE primary).
