# Handles D20 rolls and maps those rolls to ability entries for heroes and enemies.
class_name DiceManager
extends RefCounted


func roll_d20() -> int:
	return randi_range(1, 20)


func roll_all(units: Array) -> Dictionary:
	var results: Dictionary = {}
	for unit in units:
		results[unit.id] = roll_d20()
	return results


func get_ability_for_roll(unit_data: Resource, roll: int) -> Dictionary:
	if unit_data == null:
		return {}

	var clamped_roll: int = clampi(roll, 1, 20)
	for range_entry in unit_data.dice_ranges:
		var min_roll: int = int(range_entry.get("min", 0))
		var max_roll: int = int(range_entry.get("max", 0))
		if clamped_roll >= min_roll and clamped_roll <= max_roll:
			return range_entry
	return {}
