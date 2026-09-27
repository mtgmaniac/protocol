# Pip spacing regression (UI batch 2026-09-27, B2).
#
# The hero readout's live Detonate number sat a whole glyph further from its
# icon than every other icon + number pair. Its value was authored "DT 9";
# EffectPip drops the keyword letters for icon kinds and kept the space.
#
# This lays out every icon + number pair the battle can show and MEASURES the
# gap from the icon's right edge to the first visible glyph of its number, in
# both pip profiles (readout and card):
#   • every ability in the live data (heroes, evolutions, enemies),
#   • the live Detonate value as battle_card_view patches it ("DT9"),
#   • a value authored with a stray space ("DT 9", "SP 3"): the strip is the
#     class fix, so a future "%s %d" can't bring the gap back.
# Every gap must equal the profile's icon_value_gap.
# FAIL-ON-OLD: "DT 9" measures one space glyph wider than the rest.
# Run: godot --headless --path . -s scripts/debug/pip_spacing_test.gd
extends SceneTree

var _errors: Array[String] = []
var _measured: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var EffectPip: GDScript = load("res://scripts/ui/effect_pip.gd")
	var dm: Node = root.get_node("/root/DataManager")
	var effects: Array = []  # [label, effect, side]
	var owners: Array = []
	for enemy_variant in (dm.get("enemies") as Dictionary).values():
		owners.append([enemy_variant, "enemy"])
	for unit_variant in (dm.get("units") as Dictionary).values():
		owners.append([unit_variant, "hero"])
	for owner_variant in owners:
		var owner: Resource = (owner_variant as Array)[0] as Resource
		if owner == null:
			continue
		var side: String = str((owner_variant as Array)[1])
		var ranges: Array = (owner.get("dice_ranges") as Array).duplicate()
		if "evolution_paths" in owner:
			for path_variant in owner.get("evolution_paths"):
				ranges.append_array((path_variant as Dictionary).get("abilities", []))
		for range_variant in ranges:
			var entry: Dictionary = range_variant
			for effect_variant in EffectPip.effects_from_ability_raw(entry.get("raw", {}), side):
				effects.append(["%s / %s" % [str(owner.get("display_name")), str(entry.get("ability_name", ""))], effect_variant, side])
	var dt: String = EffectPip.keyword_code("detonate", "DT")
	effects.append(["live Detonate value", {"kind": "detonate", "value": "%s%d" % [dt, 9]}, "hero"])
	effects.append(["Detonate authored with a space", {"kind": "detonate", "value": "%s %d" % [dt, 9]}, "hero"])
	effects.append(["Spike authored with a space", {"kind": "spike", "value": "SP 3"}, "enemy"])

	var host := Control.new()
	root.add_child(host)
	for profile_name in ["PROFILE_READOUT", "PROFILE_CARD"]:
		var profile: Dictionary = EffectPip.get(profile_name)
		var want: float = float(profile.get("icon_value_gap", 4))
		var groups: Array = []
		for item_variant in effects:
			var item: Array = item_variant
			var group: Control = EffectPip.build_group(item[1], profile, str(item[2]))
			host.add_child(group)
			groups.append([item[0], group])
		await process_frame
		await process_frame
		var seen_fail: Dictionary = {}
		for pair_variant in groups:
			var pair: Array = pair_variant
			var gap: float = _gap(pair[1] as Control)
			if gap < -9000.0:
				continue
			_measured += 1
			if absf(gap - want) > 0.5 and not seen_fail.has(pair[0]):
				seen_fail[pair[0]] = true
				_errors.append("%s: %s icon-to-number gap %.1f px, want %.1f" % [profile_name, str(pair[0]), gap, want])
		for pair_variant in groups:
			((pair_variant as Array)[1] as Control).queue_free()
		await process_frame
	if _measured < 100:
		_errors.append("measured only %d icon + number pairs; the sweep did not run" % _measured)
	if _errors.is_empty():
		print("[PIP_SPACING] PASS - %d icon + number pairs, every gap equals the profile gap" % _measured)
	else:
		for e in _errors:
			print("[PIP_SPACING] FAIL: " + e)
	quit(0 if _errors.is_empty() else 1)


# Icon right edge to the first visible glyph of the number that follows it, or
# -9999 when the group has no icon + number pair.
func _gap(group: Control) -> float:
	if group.get_child_count() < 2:
		return -9999.0
	var icon: TextureRect = group.get_child(0) as TextureRect
	if icon == null:
		return -9999.0
	var value: Control = group.get_child(1) as Control
	var label: Label = value as Label
	if label == null and value != null and value.get_child_count() > 0:
		label = value.get_child(0) as Label
	if label == null or label.text.strip_edges() == "":
		return -9999.0
	var font: Font = label.get_theme_font("font")
	var size: int = label.get_theme_font_size("font_size")
	var text_w: float = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var lead: String = label.text.substr(0, label.text.length() - label.text.lstrip(" \t").length())
	var lead_w: float = font.get_string_size(lead, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x if lead != "" else 0.0
	var offset: float = (label.size.x - text_w) * 0.5 if label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER else 0.0
	var glyph_x: float = label.get_global_rect().position.x + offset + lead_w
	return glyph_x - icon.get_global_rect().end.x
