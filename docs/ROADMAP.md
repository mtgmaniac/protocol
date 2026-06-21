# Overload Protocol Roadmap

> **Agents:** Read `docs/AI_AGENT_GAME_REFERENCE.md` and `docs/BATTLE_UI_V2_SPEC.md` first. Portrait **1080×2400**, **3-unit** squads, **5 operations**, healer **Splice Medic** — not landscape, not 4-unit, not Phase 0.

This roadmap is the practical plan for the Godot project that already exists in
this repo — not a greenfield build spec.

Last refreshed on 2026-06-21.

## 1. Current Project State

Already implemented in some form:

- portrait phone-first project setup
- home / unit-select flow
- operation selection
- 3-unit squad selection
- battle scene
- dice rolling and result presentation
- targeting flow
- protocol resource and footer display
- reward screen
- evolution screen
- shared theme autoload
- imported UI backgrounds and custom battle UI art
- battle screenshot capture tooling

The current work is not about "building the shell from scratch" anymore. It is
about improving clarity, cohesion, and reliability in the systems that already
exist.

## 2. Current Priority Track

### Priority A — Battle UI readability and cohesion

This is the active highest-value area.

Key themes:

- card proportion balance
- portrait / HP / status readability
- cleaner hierarchy on phone
- less ornamental noise
- screenshot-first verification

Primary files:

- [battle_scene.gd](C:/Users/Kev/Documents/protocol/scripts/battle/battle_scene.gd)
- [compact_unit_card.gd](C:/Users/Kev/Documents/protocol/scripts/ui/compact_unit_card.gd)
- [ability_readout.gd](C:/Users/Kev/Documents/protocol/scripts/ui/ability_readout.gd)
- [dice_tray_3d.gd](C:/Users/Kev/Documents/protocol/scripts/battle/dice_tray_3d.gd)
- [BATTLE_UI_V2_SPEC.md](C:/Users/Kev/Documents/protocol/docs/BATTLE_UI_V2_SPEC.md)

### Priority B — Shared in-match UI consistency

Keep battle, reward, and evolution on the same visual/header system.

Key themes:

- shared header placement
- consistent framing language
- consistent tooltip sizing
- consistent typography scale

### Priority C — Reward and evolution polish

These systems exist, but need ongoing UX cleanup and consistency checks.

Key themes:

- visual alignment with battle
- readable item/evolution descriptions
- clean card selection flow

## 3. Active Near-Term Goals

### Goal 1 — Stabilize battle card readability

We are still tuning:

- unit names
- HP band and HP text
- portrait proportion
- status band presence

Success looks like:

- readable at `450x1000`
- clear role separation between portrait and lower information bands
- no squinting required for names or HP

### Goal 2 — Keep battle visual changes honest

This has become a process goal as much as a UI goal.

Rules:

- compile-check after edits
- if the change is visual, regenerate the screenshot
- do not declare success unless the screenshot plainly shows it

### Goal 3 — Consolidate documentation and context

**Done (2026-06-21):** `docs/CLAUDE.md`, `docs/GDD.md`, and this file reconciled to
`offline-bundle/GROUND_TRUTH.md` (portrait, 3-unit, Splice Medic, 5 ops).
`docs/PHASE_0_STATUS.md` marked obsolete. Ongoing: keep `docs/AI_AGENT_GAME_REFERENCE.md`
and `docs/BASELINE.md` current after each merge.

## 4. Medium-Term Goals

### Medium-Term A — Mechanic cleanup and confidence

- continue validating dice physics feel
- continue validating targeting equivalence between cards and dice
- reduce battle-scene fragility through clearer ownership

### Medium-Term B — Asset swap polish

- continue replacing legacy placeholder art where needed
- keep borders and backgrounds aligned with the newer sci-fi language
- avoid reintroducing frame clutter in small spaces

### Medium-Term C — Better cross-screen consistency

- home screen
- battle
- reward
- evolution
- run end

should all feel like one game, not stitched prototypes

## 5. Long-Term Goals

### Long-Term A — Final art pass

Once proportions and readability are stable:

- final battle card styling
- final header/footer polish
- final pip/readout visual language
- final background harmony

### Long-Term B — Full-content confidence

- broader operation coverage
- fuller reward pool validation
- more complete evolution-path confidence
- longer-form balance and run testing

## 6. Anti-Roadmap Notes

These are things we should actively avoid while the current priorities are
unfinished:

- large architectural rewrites without a screenshot-driven reason
- reintroducing decorative UI clutter during readability work
- assuming old docs are still accurate without checking the current files
- declaring visual wins from code alone

## 7. Practical Next-Step Rule

If a change touches battle visuals, the practical sequence should be:

1. identify the real owner
2. make a narrowly scoped change
3. compile-check
4. regenerate battle screenshot
5. evaluate the screenshot honestly

That is the roadmap discipline that keeps this project moving forward now.
