# Handoff — Loadout / Item-targeting UX bugs

Branch: `feat/inspect-popup-ui`. The long-press **InspectPopup** + **LoadoutMenu** + item-targeting **ItemCard** work is in place and mostly working. Two UX bugs remain to tackle, plus one still-unresolved item below.

Verify visually with the capture harnesses in `scripts/debug/battle_ui_capture.gd` (Godot 4.6.2; run **windowed**, not `--headless`, so the viewport renders). See the auto-memory notes `reference_godot_ui_capture` and `project_inspect_popup_migration`.

---

## Bug 1 — No feedback when using an item with insufficient Protocol

**Repro:** open the loadout (item button, bottom bar) → tap a consumable while `protocol_points < item cost`.

**Current:** the loadout menu closes and nothing obvious happens (only a battle-summary line like `Need 1 Protocol to use X.`, easy to miss).

**Want:** the tapped item **blinks red** (can't afford), and the loadout menu **stays open**.

**Where:**
- `scripts/battle/battle_scene.gd` → `_on_item_button_pressed(item)` early-returns at:
  `if protocol_points < cost: _refresh_summary("Need %d Protocol to use %s."); return`
- `scripts/ui/loadout_menu.gd` → `_on_item_row_input()` calls `LoadoutMenu.dismiss()` **before** invoking the use-callback, so the menu is already gone when the cost check fails.

**Suggested approach:**
- Check affordability *before* dismissing. Options:
  - Pass each item's cost + current protocol into `LoadoutMenu` so a tap on an unaffordable item flashes that row red (tween `modulate`) and does **not** dismiss; or
  - Have the use-callback return a `bool` (success) and only `dismiss()` on success; on failure, flash the row.
- Cost source: `battle_scene._get_item_protocol_cost(item)` (flat 1, or 0 with the `protocolOnItemUse` relic). Current protocol: `battle_scene.protocol_points`.

---

## Bug 2 — Overlays flash at the top-left for one frame before centering

**Repro:** long-press a unit (InspectPopup breakout) **or** open an item (ItemCard) → it appears at the top-left corner for a frame, then jumps to the correct centered position. General to all these overlays, not item-specific.

**Cause:** overlays are added at `(0,0)` and only positioned a frame later by the deferred `_relayout` (InspectPopup/LoadoutMenu) or the first `CenterContainer` layout pass (item card).

**Status — partial fix already in the working tree (VERIFY it actually removes the flash in-game):**
- `scripts/ui/inspect_popup.gd` — `_panel.visible = false` in `_build`, `_panel.visible = true` at the end of `_relayout`.
- `scripts/ui/loadout_menu.gd` — same pattern.
- `scripts/battle/battle_scene.gd` → `_show_item_targeting_card()` — card hidden, shown via a `0s` timer after layout.

If a flash still shows, keep the panel hidden until **after** `RenderingServer.frame_post_draw`, or compute + set the position **synchronously** in `_build` (using `get_viewport().get_visible_rect().size`) instead of deferring.

---

## Still unresolved (separate) — item-targeting card disappears

Selecting a loadout item sometimes makes the centered ItemCard flash and vanish immediately. `_show_item_targeting_card()` runs, then something calls `_hide_item_targeting_card()` right after (candidates: `_cancel_item_to_loadout` via a spurious `_unhandled_input` press, or `_apply_item_effect`). An `_item_targeting_armed` 0.18s guard was added but the user still saw it.

**To diagnose:** re-add `print("[ITEMDBG] hide ", get_stack())` in `battle_scene._hide_item_targeting_card()`, run a real battle, and read the Godot **Output** panel `[ITEMDBG]` lines — the stack names the caller. Synthetic `push_input` in the capture harness does **not** trigger `gui_input`, so it cannot reproduce this; a real run is required.

---

## Capture hooks (for verification)

`scripts/debug/battle_ui_capture.gd`: `--capture-inspect-hero` / `--capture-inspect-enemy`, `--capture-inspect-protocol=nudge|reroll|set`, `--capture-loadout`, `--capture-loadout-tap`, `--capture-item-target=<item_id>`, `--capture-show-die-hitboxes`.
