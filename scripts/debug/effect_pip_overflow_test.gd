# Effect-pip overflow regression (ruled 2026-09-02).
#
# `effects_from_ability_raw` caps a pip row at EffectPip.MAX_VISIBLE_EFFECTS in
# AUTHORING order. It used to end in a bare `effects.slice(0, 3)`, dropping the
# tail SILENTLY: eleven abilities lost a keyword with nothing on the card to say
# so. Conclave Bulwark's long-press read "…firewall, summon (42%)" over an icon
# row that showed neither. The cap stays; the drop now renders a trailing "+N"
# badge, the same overflow language the status chip row uses.
#
# FAIL-ON-OLD: the pre-fix producer returns three pips with no overflow entry.
#   • Conclave Bulwark (5 effects) -> 3 pips + "+2", first-three by authoring order.
#   • the dropped keywords are still spelled out in the authored eff text, which
#     is what long-press renders under the pips (InspectResolver.resolve_ability).
#   • a three-or-fewer ability gets NO badge.
#   • every ability in the data set that overflows carries exactly one badge
#     whose count matches what was dropped.
# Run: godot --headless --path . -s scripts/debug/effect_pip_overflow_test.gd
extends SceneTree

var _errors: Array[String] = []


func _check(cond: bool, label: String) -> void:
	if not cond:
		_errors.append(label)


func _kinds(effects: Array) -> Array:
	var out: Array = []
	for effect_variant in effects:
		out.append(str((effect_variant as Dictionary).get("kind", "")))
	return out


func _overflow_value(effects: Array) -> String:
	for effect_variant in effects:
		var effect: Dictionary = effect_variant
		if str(effect.get("kind", "")) == "overflow":
			return str(effect.get("value", ""))
	return ""


# The raw ability dict for one named enemy ability, from live data.
func _find_enemy_raw(dm: Node, ability_name: String) -> Dictionary:
	for enemy_variant in (dm.get("enemies") as Dictionary).values():
		var enemy: Resource = enemy_variant as Resource
		if enemy == null:
			continue
		for range_variant in (enemy.get("dice_ranges") as Array):
			var entry: Dictionary = range_variant
			var raw: Dictionary = entry.get("raw", {})
			if str(entry.get("ability_name", "")) == ability_name:
				return raw
	return {}


func _initialize() -> void:
	await process_frame
	# Autoloads are not resolvable at COMPILE time in a `-s` script, so the
	# class_name references have to be loaded at runtime (the primer-smoke
	# pattern) — a compile error here would idle forever instead of failing.
	var EffectPip: GDScript = load("res://scripts/ui/effect_pip.gd")
	var InspectResolver: GDScript = load("res://scripts/ui/inspect_resolver.gd")
	var dm: Node = root.get_node("/root/DataManager")

	# ── Conclave Bulwark: 20 dmg · 12 shield · +2 roll (all) · firewall · summon.
	var bulwark: Dictionary = _find_enemy_raw(dm, "Conclave Bulwark")
	_check(not bulwark.is_empty(), "Conclave Bulwark is present in the enemy data")
	var pips: Array = EffectPip.effects_from_ability_raw(bulwark, "enemy")
	_check(pips.size() == EffectPip.MAX_VISIBLE_EFFECTS + 1,
		"Conclave Bulwark renders 3 pips + the overflow badge (saw %d)" % pips.size())
	_check(_kinds(pips).slice(0, 3) == ["dmg", "shield", "rfm"],
		"the visible three are the first three in AUTHORING order (saw %s)" % str(_kinds(pips)))
	_check(_overflow_value(pips) == "+2",
		"the two dropped effects (firewall, summon) render as +2 (saw '%s')" % _overflow_value(pips))

	# The dropped keywords must still be reachable: long-press renders the
	# authored eff text under the pips. If this fails, the badge is pointing at
	# nothing and THAT is the bug.
	var payload: Dictionary = InspectResolver.resolve_ability(bulwark, "enemy")
	var inspect_text: String = str(((payload.get("abilities", []) as Array)[0] as Dictionary).get("text", "")).to_lower()
	_check(inspect_text.contains("firewall"),
		"long-press text lists the dropped firewall (saw '%s')" % inspect_text)
	_check(inspect_text.contains("summon"),
		"long-press text lists the dropped summon (saw '%s')" % inspect_text)

	# ── A three-or-fewer ability gets no badge at all.
	var small: Array = EffectPip.effects_from_ability_raw({"dmg": 8, "burn": 3, "burnT": 2, "shield": 5}, "enemy")
	_check(small.size() == 3 and _overflow_value(small) == "",
		"a three-effect ability renders no overflow badge (saw %s)" % str(_kinds(small)))
	var tiny: Array = EffectPip.effects_from_ability_raw({"dmg": 8}, "hero")
	_check(tiny.size() == 1 and _overflow_value(tiny) == "",
		"a one-effect ability renders no overflow badge")

	# ── Sweep the live data: every overflowing ability carries exactly one
	# badge, and the row never exceeds the cap + badge.
	var swept: int = 0
	var overflowing: int = 0
	var overflow_names: Array = []
	var sweep_targets: Array = []
	for enemy_variant in (dm.get("enemies") as Dictionary).values():
		sweep_targets.append([enemy_variant, "enemy"])
	for unit_variant in (dm.get("units") as Dictionary).values():
		sweep_targets.append([unit_variant, "hero"])
	for target_variant in sweep_targets:
		var target: Array = target_variant
		var owner: Resource = target[0] as Resource
		var owner_side: String = str(target[1])
		if owner == null:
			continue
		for range_variant in (owner.get("dice_ranges") as Array):
			var raw: Dictionary = (range_variant as Dictionary).get("raw", {})
			if raw.is_empty():
				continue
			swept += 1
			var row: Array = EffectPip.effects_from_ability_raw(raw, owner_side)
			var badges: int = 0
			for effect_variant in row:
				if str((effect_variant as Dictionary).get("kind", "")) == "overflow":
					badges += 1
			if badges > 0:
				overflowing += 1
				overflow_names.append("%s (%s)" % [str(raw.get("name", "?")), _overflow_value(row)])
			if row.size() > EffectPip.MAX_VISIBLE_EFFECTS:
				_check(badges == 1 and str((row[row.size() - 1] as Dictionary).get("kind", "")) == "overflow",
					"%s: an over-cap row ends in exactly one overflow badge" % str(raw.get("name", "?")))
			_check(row.size() <= EffectPip.MAX_VISIBLE_EFFECTS + 1,
				"%s: the row never exceeds the cap + badge" % str(raw.get("name", "?")))
	_check(swept > 0, "the sweep saw abilities on both sides")
	_check(overflowing > 0, "the sweep found abilities that actually overflow")
	print("[EFFECT_PIP_OVERFLOW] swept %d abilities, %d overflow: %s" % [swept, overflowing, ", ".join(PackedStringArray(overflow_names))])

	if _errors.is_empty():
		print("[EFFECT_PIP_OVERFLOW] PASS")
		quit(0)
	else:
		for e in _errors:
			push_error("[EFFECT_PIP_OVERFLOW] " + e)
		print("[EFFECT_PIP_OVERFLOW] FAIL - %d check(s)" % _errors.size())
		quit(1)
