# Handles D20 rolls and maps those rolls to ability entries for heroes and enemies.
class_name DiceManager
extends RefCounted

# OWNED stream, not Godot's global RNG (save-system refactor). roll_d20 is
# reached in live play by the Protocol Reroll, the item enemy-reroll effects and
# the skip-visuals auto-battle path — all run-affecting, so none of them may sit
# on a global stream that nothing can save, restore, or reason about. (The sim
# never calls this: BattleEngine hands combat a SeededRollProvider, and the
# sim's DiceManager is used only for get_ability_for_roll.)
#
# randomize() by default so an unseeded manager behaves exactly as the global
# RNG did; battle_scene seeds it from the run's battle seed so a resumed battle
# reproduces the same non-physics stream.
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


## Debug-build seam for the `roll windows live` gate's deliberate breaks (never
## set by the game): `shared_table` gives every enemy one fixed table again
## (read by DataManager); `squeeze` lets a band shift empty the band it takes
## from (the pre-2026-10-08 arithmetic).
const WINDOWS_BREAK_ARG := "--roll-windows-break="
static var _windows_break: String = "?"


static func roll_windows_break() -> String:
	if _windows_break == "?":
		_windows_break = ""
		if OS.is_debug_build():
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with(WINDOWS_BREAK_ARG):
					_windows_break = arg.trim_prefix(WINDOWS_BREAK_ARG)
	return _windows_break


func _init() -> void:
	_rng.randomize()


func seed_stream(stream_seed: int) -> void:
	_rng.seed = stream_seed


func get_stream_state() -> int:
	return int(_rng.state)


func set_stream_state(state: int) -> void:
	_rng.state = state


func roll_d20() -> int:
	return _rng.randi_range(1, 20)


func get_ability_for_roll(unit_data: Resource, roll: int) -> Dictionary:
	if unit_data == null:
		return {}

	var clamped_roll: int = clampi(roll, 1, 20)
	for range_entry in get_adjusted_ranges(unit_data):
		var min_roll: int = int(range_entry.get("min", 0))
		var max_roll: int = int(range_entry.get("max", 0))
		if clamped_roll >= min_roll and clamped_roll <= max_roll:
			return range_entry
	return {}


# Runtime band overrides (pkg3.4): gear and relics shift band edges for HERO
# units at resolve time — the authored ability ranges stay untouched.
#  - Band Compressor gear (overloadBandCompress): overload becomes 19-20, the
#    band below it ends at 18.
#  - Wide Aperture gear (surgeBandExtend): surge extends N lower, the band
#    below shrinks to match.
#  - Standing Order relic (critBandExtend): every crit band extends N down.
func get_adjusted_ranges(unit_data: Resource) -> Array:
	var base_ranges: Array = unit_data.dice_ranges
	if not (unit_data is UnitData):
		return base_ranges
	var compress_overload: bool = false
	var surge_extend: int = 0
	var crit_extend: int = 0
	var gear_ids: Array = GameState.gear_by_unit.get(str(unit_data.id), [])
	for gear_id in gear_ids:
		var item: ItemData = DataManager.get_item(str(gear_id)) as ItemData
		if item == null or item.effect == null:
			continue
		match str(item.effect.get("type", "")):
			"overloadBandCompress":
				compress_overload = true
			"surgeBandExtend":
				surge_extend = maxi(surge_extend, int(item.effect.get("amount", 2)))
	if GameState.has_relic_effect("critBandExtend"):
		crit_extend = 1
	# The Splice Deal intercept (pkg7.4): overload 19-20 + recharge widens 2.
	var splice: bool = bool((GameState.hero_run_mods.get(str(unit_data.id), {}) as Dictionary).get("splice_bands", false))
	if splice:
		compress_overload = true
	if not compress_overload and surge_extend == 0 and crit_extend == 0:
		return base_ranges

	var adjusted: Array = []
	for range_entry in base_ranges:
		adjusted.append(range_entry.duplicate())
	for i in adjusted.size():
		var zone: String = str(adjusted[i].get("zone", ""))
		if splice and zone == "recharge":
			_grow_up(adjusted, i, 2)
		if compress_overload and zone == "overload":
			_grow_down(adjusted, i, int(adjusted[i]["min"]) - 19)
		if surge_extend > 0 and zone == "surge":
			_grow_down(adjusted, i, surge_extend)
		if crit_extend > 0 and zone == "crit":
			_grow_down(adjusted, i, crit_extend)
	return adjusted


# Band `i` takes up to `faces` faces from the band below it. A squeezed band
# always keeps at least one face, so every shift leaves five contiguous bands
# covering 1-20 (a two-face band can only give one: roll windows, 2026-10-08).
static func _grow_down(ranges: Array, i: int, faces: int) -> void:
	if i <= 0 or faces <= 0:
		return
	var room: int = int(ranges[i - 1]["max"]) - int(ranges[i - 1]["min"])
	var taken: int = faces if roll_windows_break() == "squeeze" else mini(faces, maxi(room, 0))
	ranges[i]["min"] = int(ranges[i]["min"]) - taken
	ranges[i - 1]["max"] = int(ranges[i]["min"]) - 1


# Band `i` takes up to `faces` faces from the band above it, same floor.
static func _grow_up(ranges: Array, i: int, faces: int) -> void:
	if i + 1 >= ranges.size() or faces <= 0:
		return
	var room: int = int(ranges[i + 1]["max"]) - int(ranges[i + 1]["min"])
	var taken: int = mini(faces, maxi(room, 0))
	ranges[i]["max"] = int(ranges[i]["max"]) + taken
	ranges[i + 1]["min"] = int(ranges[i]["max"]) + 1
