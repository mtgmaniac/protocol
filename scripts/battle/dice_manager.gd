# Handles D20 rolls and maps those rolls to ability entries for heroes and enemies.
class_name DiceManager
extends RefCounted


func roll_d20() -> int:
	return randi_range(1, 20)


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
	if not compress_overload and surge_extend == 0 and crit_extend == 0:
		return base_ranges

	var adjusted: Array = []
	for range_entry in base_ranges:
		adjusted.append(range_entry.duplicate())
	for i in adjusted.size():
		var zone: String = str(adjusted[i].get("zone", ""))
		if compress_overload and zone == "overload":
			adjusted[i]["min"] = mini(int(adjusted[i]["min"]), 19)
			if i > 0:
				adjusted[i - 1]["max"] = mini(int(adjusted[i - 1]["max"]), 18)
		if surge_extend > 0 and zone == "surge":
			adjusted[i]["min"] = maxi(1, int(adjusted[i]["min"]) - surge_extend)
			if i > 0:
				adjusted[i - 1]["max"] = maxi(int(adjusted[i - 1]["min"]), int(adjusted[i]["min"]) - 1)
		if crit_extend > 0 and zone == "crit":
			adjusted[i]["min"] = maxi(1, int(adjusted[i]["min"]) - crit_extend)
			if i > 0:
				adjusted[i - 1]["max"] = maxi(int(adjusted[i - 1]["min"]), int(adjusted[i]["min"]) - 1)
	return adjusted
