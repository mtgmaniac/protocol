# Minimal bootstrap scene that now doubles as the Phase 1 data-load verification screen.
extends Control

@onready var status_label: Label = %StatusLabel


func _ready() -> void:
	var pulse_tech := DataManager.get_unit("pulse")
	if pulse_tech == null:
		status_label.text = "Phase 1 check failed: no unit data loaded."
		return

	var first_range: Dictionary = pulse_tech.dice_ranges[0] if pulse_tech.dice_ranges.size() > 0 else {}
	status_label.text = "Loaded %d heroes, %d enemies, %d items.\n%s HP: %d\nFirst range: %s-%s -> %s" % [
		DataManager.units.size(),
		DataManager.enemies.size(),
		DataManager.items.size(),
		pulse_tech.display_name,
		pulse_tech.max_hp,
		str(first_range.get("min", "?")),
		str(first_range.get("max", "?")),
		str(first_range.get("ability_name", "?")),
	]
