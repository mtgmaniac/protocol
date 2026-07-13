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

**Roll-time sighting (Kev 2026-07-10; icon-keyed Bug-2 rework 2026-07-12):** when a
revealed roll picks an ability, `KeywordPrimer.notice_rolled_ability` resolves the
ICONS its pip readout actually renders (`EffectPip.effects_from_ability_raw` → kind
icon + scope marker per effect, both sides — enemy rolls included) and queues a primer
for every not-yet-seen icon via `ICON_TRIGGERS`, so the tip shows BEFORE the player
commits. **The ONE exclusion list is `HIGHLIGHT_EXEMPT_ICONS` = damage / heal / shield**
(self-evident; the tutorial covers them) — a pip whose icons are all exempt never
highlights; any non-exempt icon on it does. Roll sightings anchor to the pip readout
(`target_override`), and the event-stream triggers below remain as the mid-resolution
fallback with their authored anchors. An icon mapped in `ICON_TRIGGERS` but with no
loaded JSON entry skips silently — authoring the entry is the whole job of turning it
on (all mapped icons are authored as of 2026-07-12). Players can disable ability
primers entirely in Help → Settings → Tutorials (`ability_primers_enabled`).

### Trigger types (implemented)

| type | param | fires when |
|---|---|---|
| `die_status_applied` | jam / freeze / rewrite / hijack | the die status first lands on ANY die, either side |
| `status_applied` | mark / firewall / cloak / taunt / burn / spike / accrete | the status first appears on any unit card |
| `attack_keyword_resolved` | chain / detonate / execute / breach / pierce / leech / siphon / revive / rampage / pack_bonus / summon | the keyword first visibly resolves in the feedback stream, friendly or enemy (`wipe_shields` events also route to the breach primer — same rule) |
| `icon_first_seen` | aoe / target_lowest / roll / self / protocol | a non-keyword pip icon first appears on a revealed roll — the icon itself is the lesson (Bug-2, 2026-07-12). Only damage/heal/shield are exempt (`HIGHLIGHT_EXEMPT_ICONS`) — do not re-add them |
| `protocol_action_affordable` | *(no loaded entries)* | seam kept; the nudge/reroll/set primers were CUT 2026-07-10 — the scripted tutorial teaches them |
| `personality_assigned` | *(no loaded entries)* | trigger plumbing kept; the four attack-style primers were CUT 2026-07-10 (Kev: not tutorial material — the unit popup's TARGETING line remains the reference) |
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
  540×1200.

## Behavior semantics (what the manager guarantees)

- **Safe moments only:** primers display between battle-feedback action groups
  (the sequence pauses, resumes on dismiss) or during an idle player phase —
  never mid-swing.
- **FULL DRAIN, no cap (Kev 2026-07-12):** every unseen icon raised in a turn is
  taught IN that turn — the queue drains completely as a MODAL SEQUENCE (one
  popup at a time, tap through each; never simultaneous — that's the tutorial's
  `separate:true` spotlight mechanism, a different system). The old one-per-turn
  throttle didn't defer the losers, it DROPPED them (`_pending.clear()`) and
  hoped the icons recurred; an icon that never reappeared was never taught.
- **Order is spatial:** enqueue order == hero rail left→right, then enemy rail,
  pips left→right within a readout. The JSON `priority` field is **inert**
  (retained for schema compatibility; it only ever picked the single winner
  under the old cap — do not reintroduce a sort on it).
- **Copy leads with the glyph:** the coachmark renders the ACTUAL icon being
  taught (SpotlightLayer `opts["glyph"]`, keyed from the sighting's icon or the
  trigger param) ahead of the text — "this marker" is meaningless when two
  markers are on screen. The spotlight hole is the icon's own glyph node
  (`pip_icon_key` meta, tagged in `EffectPip.build_group`), searched in the
  **visible die-docked plate** (`battle_scene.get_die_tag_plate`) — NEVER the
  rail `AbilityReadout`, which is an alpha-0 data holder whose glyph nodes are
  ghosts with live rects (the 2026-07-12 wrong-node bug: a ghost match ringed
  empty screen space). `_find_glyph_rect` requires **effective alpha > 0**, not
  `.visible`. Fallback chain: plate glyph → whole plate → readout row → card.
  **Self-heal (2026-07-13):** plates build in `_process` one frame after reveal,
  so the drain's FIRST modal used to resolve with zero plates and silently ride
  the row fallback (position-dependent — burn/mark, the earliest-met icons,
  ringed whole plates while later icons anchored fine). A null plate now calls
  the scene's idempotent `_sync_die_tags()` and re-fetches; any resolution that
  still falls past the plate glyph `push_warning`s — a silent fallback is
  indistinguishable from no fallback firing at all.
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
