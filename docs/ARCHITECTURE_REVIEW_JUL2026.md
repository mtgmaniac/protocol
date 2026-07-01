# Architecture Review — July 2026 (pre-Early-Access)

Senior-level systems critique requested before continuing development. This
documents findings and recommendations **before** any large change is made
(per the working constraint: document first, implement later, one lane at a
time). Nothing in here has been implemented unless explicitly marked.

Verdict up front: the core loop (roll → band → target → resolve) is strong and
the data-driven ability system is genuinely good. The debt is concentrated in
ONE god object (`battle_scene.gd`), one duplicated rules engine (the TS sim),
and stringly-typed combat state. None of it blocks Early Access; all of it
taxes every future feature.

---

## 1. `battle_scene.gd` is the god object (2,958 lines, 143 funcs)

**What it owns today:** turn/phase state machine (10 phases via string
constants, 29 phase comparisons), dice-roll orchestration, targeting UI,
protocol economy UI (reroll/nudge/set/item buttons + their pick sub-modes),
item usage overlay, battle log, tutorial event emission, reward hand-off,
summon handling, and the construction of nearly every footer control.

**Why it happened:** the Task-2 split moved layout/cards/feedback out into
`battle_layout.gd` / `battle_card_view.gd` / `battle_feedback.gd`, but those
helpers reach back with `_scene.` **95 times** — they're extensions of the god
object, not modules with boundaries.

**Recommendation (in priority order):**
1. **Extract the protocol-spend subsystem** (reroll/nudge/set/item buttons,
   the four `*_PICK` phases, `_apply_nudge`/`_apply_set`/reroll flows) into a
   `protocol_actions.gd` owning its own buttons and sub-phase logic. This is
   the highest-churn area (tutorial, economy tuning) and is already listed as
   an optional follow-up in TASK_QUEUE.
2. **Promote the phase machine to a real enum + transition table.** String
   phases mean typos fail silently (`"ready_to_end"` appears in the tutorial
   script as a magic string today). A `Phase` enum plus one
   `transition(to: Phase)` choke point would also give the tutorial a typed
   hook instead of string payloads.
3. Only after those two: consider a `TargetingController`. Don't do all three
   at once — each is independently shippable and testable with the existing
   smoke tests.

**Not recommended:** a full ECS/actor rewrite. The game is 3v3 with ~10
statuses; the dictionary-based combat state is within its complexity budget
if it gets a schema (see §3).

## 2. Two combat rule engines exist (GDScript + TypeScript sim)

`combat_manager.gd` (1,441 lines) is authoritative; `scripts/sim/*.ts`
(~2,200 lines) re-implements the same band/keyword rules for balance tuning,
and AGENTS.md already documents where they diverge (no items/summons/taunt/
cloak in sim). Every new keyword must be written twice or the sim silently
lies about balance.

**Recommendation:** pick one of:
- **(a) Demote the sim** to explicitly frozen scope: rename to
  `sim-lab/`, stamp "facility-lane balance only — does not model X/Y/Z" into
  its README and every report header, and never extend it again; or
- **(b) Make GDScript the only engine** and run balance sims headlessly
  through Godot (`AbilityAuditRunner`-style scene that plays N battles with a
  policy bot and prints CSV). Slower per-run than Node, but one source of
  truth forever.

(b) is the better long-term architecture; (a) is one afternoon. Decide before
the next balance pass (Task 5 is paused pending exactly this kind of run).

## 3. Combat state is stringly-typed dictionaries

Unit state is `Dictionary` with ~25 magic keys (`"die_freeze_turns"`,
`"poison_skip_next_tick"`, `"gear_protocol_on_start"`, …) mutated from
`battle_scene`, `combat_manager`, `battle_card_view`, and the audit. A typo
in any key reads as default-zero, not an error — several past playtest bugs
(preview DoT sticking, freeze consumption) were exactly this class.

**Recommendation:** don't rewrite — *fence*. Add a `UnitBattleState` class
(RefCounted, typed vars, `to_dict()` for the audit) OR at minimum a
`state_keys.gd` constants file + a debug-mode validator that asserts unknown
keys on write. The second option is ~1 hour and immediately catches drift.

## 4. UI is 100% code-built; scenes are shells

Every screen builds its controls in `_ready()` (`BattleScene.tscn` is ~a
handful of containers; the 143-func scene script builds the rest). Pros:
diffable, AI-editable, no .tscn merge conflicts — this clearly fits the
workflow. Cons: no editor preview, layout constants tuned via screenshot
loops, and each screen re-invents header/theme/label plumbing
(`_update_battle_header` ×3, `_apply_visual_theme` ×3,
`_make_label`/`_style` ×5).

**Recommendation:** keep the code-built approach (it matches how this project
is actually developed) but add one `ScreenBase` class for the reward /
evolution / run-end trio: shared header binding, theme application, and the
label/style helpers. ~-150 lines and one place to change screen chrome.
`PixelUI` already proves the pattern works.

## 5. Systems that no longer fit / small leftovers

- **`DiceManager`** (27 lines) is a class with two trivial functions injected
  everywhere (`resolve_round(..., DiceManager.new())`). Fold `roll_d20()` and
  `get_ability_for_roll()` into `combat_manager` as statics, or accept it as
  a seam for rigged rolls — but today the tutorial rigs rolls by overwriting
  the results dict instead, so the seam is unused. Candidate for deletion.
- **Debug capture scripts** (5×) each re-implement `_run_capture` /
  `_parse_args` / `_capture_viewport_to_file` / `_wait_for_scene`. One
  `capture_base.gd` they extend kills ~300 duplicated lines. (Two purpose-
  built smoke tests — flow, tutorial — now exist and should be the pattern.)
- **`legacy-angular/`** is a 100+ MB asset closet for a dead app the docs
  must repeatedly warn agents away from. Migrate the ~30 PNGs Godot actually
  loads (`res://legacy-angular/public/...`) into `assets/`, delete the rest,
  and the warning paragraphs in three docs disappear. (Void Circlet portraits
  were migrated this way in July 2026 — the pattern works.)
- **`addons/ziva_agent`** is not enabled in project.godot. Delete or enable.
- **`hero_zone_ranges`** in DataManager: loaded but its accessor was dead
  code (removed July 2026) — check whether the load itself is still needed.

## 6. Gameplay-loop observations (design, not code)

- **Protocol economy reads well** (cap 10, +1/turn, costs 1/2/3) but all four
  spends live behind icon-only footer buttons; the tutorial now teaches
  Nudge properly, and Reroll/Set are named there, but in normal play nothing
  on screen says what a button costs until long-press inspect. A tiny cost
  numeral on each footer icon would remove the last memorization burden.
- **One-relic-per-run + one-evolution-per-win** are clean, legible rules —
  keep resisting scope creep here.
- **Enemy intent** is fully honest (readouts show exact rolled abilities).
  The queued "incoming target indicators" task is the right next step and
  needs no new architecture.

## Priority order if all of this gets green-lit

1. §2 decision (sim engine) — it gates the paused balance work.
2. §1.1 protocol-actions extraction + §1.2 phase enum.
3. §3 state-key fencing.
4. §4 ScreenBase + §5 leftovers as filler tasks.

Everything above is verifiable against the existing gates: ability audit
(105), flow smoke (11 steps), tutorial smoke (21 steps), dice physics probe.
