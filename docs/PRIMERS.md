# PRIMERS — authoring guide (keyword primer system)

One-shot micro-tutorials: the FIRST time a mechanic is sighted in a real battle, the
game pauses at a safe beat, dims everything except the thing that just happened, and
shows one sentence. Then never again (per save profile).

**Moving parts:** `data/raw/primers.data.json` (the registry, schema-validated) ·
`scripts/ui/keyword_primer.gd` (runtime manager, its own CanvasLayer at 110) ·
`scripts/ui/spotlight_layer.gd` (shared dim/ring/coachmark, also used by the tutorial)
· `SaveManager` `onboarding.primers_seen` (persistence) · `scripts/debug/primer_smoke_test.gd`
(headless regression). The tutorial (`TutorialController`) shares the SpotlightLayer but
is otherwise a separate system — never couple primer logic to it.

---

## Add a primer for an EXISTING trigger type (one JSON entry — no code)

Worked example — suppose Rampage needs a primer when its chip first appears:

```json
{
  "id": "primer_rampage",
  "trigger": { "type": "status_applied", "param": "rampage" },
  "target": "unit_card",
  "text": "RAMPAGE: its next attack deals double damage.",
  "priority": 40,
  "requires_feature": null
}
```

1. Append the entry to the `primers` array in `data/raw/primers.data.json`.
2. The `param` must map to a combat feedback event: check `EVENT_TRIGGERS` in
   `keyword_primer.gd`. If the event type already exists in the stream (grep
   `_emit_event` in combat_manager.gd), add one line to `EVENT_TRIGGERS`
   (`"rampage_up": ["status_applied", "rampage"]`). If the mechanic emits no
   event yet, add a marker `_emit_event(...)` at the visible moment — markers
   must have an empty float-text case in `battle_feedback._build_floating_text`
   so they add no visual noise, and they must NOT change combat outcomes.
3. `npm run validate-data` (schema + unique-id + no-signal_hook-in-loaded checks).
4. Run `scripts/debug/primer_smoke_test.gd` and the flow smoke.

### Trigger types (implemented)

| type | param | fires when |
|---|---|---|
| `die_status_applied` | jam / freeze / rewrite / hijack | the die status first lands on ANY die, either side |
| `status_applied` | mark / firewall / cloak / taunt / burn / spike / accrete | the status first appears on any unit card |
| `attack_keyword_resolved` | chain / detonate / execute / breach / pierce / leech / siphon / revive | the keyword first visibly resolves in the feedback stream |
| `protocol_action_affordable` | nudge / reroll / set | the action first becomes affordable during a player phase |
| `personality_assigned` | SYSTEMATIC / WOUNDED / PACK / SPITEFUL | that personality first selects a target (`requires_feature: "targeting_personalities"`) |
| `signal_hook` | any signal name | reserved seam — see below; no loaded entries yet |

### Targets (the spotlight anchor)

`die` (the affected die's projected tray rect) · `unit_card` (the affected unit's
card) · `ability_pip` (the unit's effect-pip readout, falls back to its card) ·
`footer_button` (the protocol action button for `param`) · `popup_line` (inspect
popup personality row — resolves only while the popup is open and exposes
`get_personality_row_rect()`; unresolvable otherwise, which safely skips).

---

## Add a NEW trigger type (one signal + one registry line)

The `signal_hook` seam exists so future mechanics (haunt, pilfer, counter_protocol —
see the `$signal_hook_examples` block in the JSON) cost one entry plus one emitted
signal:

1. **Emit the moment.** At the point the mechanic visibly resolves, call
   `_primer.notice_signal_hook("haunt_applied", {"side": side, "target_id": id})`
   (battle_scene holds `_primer`; guard with `if _primer != null and is_instance_valid(_primer)`).
2. **Author the entry** with `"trigger": {"type": "signal_hook", "param": "haunt_applied"}`
   and move it from `$signal_hook_examples` into `primers`. Set `requires_feature`
   to the mechanic's feature key and add that key to `PRESENT_FEATURES` in
   `keyword_primer.gd` when the mechanic ships — entries whose feature is absent
   are skipped silently, so the JSON can land first.
3. **New target type?** Register ONE resolver in `keyword_primer.gd`'s
   `_target_resolvers` — a `Callable(context) -> Rect2` (screen space, `Rect2()`
   = unresolvable → skip silently). `context` carries `{side, target_id, param}`.
4. Extend `primer_smoke_test.gd` with one case for the new trigger.

---

## Text rules (hard)

- ONE sentence, ~12 words max, ALL-CAPS keyword prefix ("JAM: …").
- States the RULE, never flavor. Sourced from `keywords.data.json` defs; where a
  def is too long, compress — a primer must NEVER contradict the glossary.
- Current wording law: Firewall (not Ward), Taunt (Lure is dead), Jam cap 10,
  two-clause Cloak, freeze = repeat, corrected Pierce/Breach sentences.
- Schema caps text at 90 chars; the audit of last resort is a human squint at
  450×1000.

## Behavior semantics (what the manager guarantees)

- **Safe moments only:** primers display between battle-feedback action groups
  (the sequence pauses, resumes on dismiss) or during an idle player phase —
  never mid-swing.
- **One per turn, maximum.** Additional first sightings the same turn are NOT
  marked seen; they fire on their next natural occurrence.
- **Priority** (higher wins) breaks same-moment ties only.
- **Suppression:** never during the scripted tutorial, headless mode, or auto
  battle. `requires_feature` entries skip silently when the feature is absent.
- **Failure safety:** if the target can't resolve or the layer is dead, the
  primer is skipped silently, NOT marked seen, and the battle never blocks.
- **Marked seen** only after the primer actually displayed and was dismissed
  (`SaveManager.mark_primer_seen`).
- **Persistence:** `onboarding.primers_seen` in `user://save.json`, healed by
  `_merge_loaded`; veteran saves that predate the system are grandfathered with
  every current primer marked seen. Dev tools: RESET PRIMERS (DEV) clears only
  `primers_seen`; RESET SAVE PROFILE clears all onboarding.
- **Determinism fence (INVARIANTS #1):** the manager observes; it never mutates
  combat state. New event markers must be feedback-only.

## Verification checklist

```
npm run validate-data
<godot> --headless --path . -s scripts/debug/primer_smoke_test.gd
<godot> --headless --path . -s scripts/debug/tutorial_smoke_test.gd   # shared SpotlightLayer
<godot> --headless --path . -s scripts/debug/flow_smoke_test.gd
<godot> --headless --path . scenes/debug/freeze_engine_regression.tscn
python scripts/sim/ci_smoke.py    # must show ZERO drift — primers never touch outcomes
```
