# ui-cleanup (CARD type role): every name a battle card can show and the widest
# HP string, measured in Battle Block and m5x7 at their lattice sizes.
# Headless is fine (font metrics only):
#   <godot> --headless --path . -s res://scripts/debug/card_type_fit_probe.gd
extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var dm: Node = root.get_node("/root/DataManager")
	var names: Dictionary = {}
	for unit: Resource in (dm.get("units") as Dictionary).values():
		names[str(unit.call("battle_name")).to_upper()] = "hero"
	for enemy: Resource in (dm.get("enemies") as Dictionary).values():
		names[str(enemy.call("battle_name")).to_upper()] = "enemy"
	var block: Font = load("res://assets/fonts/battle_block.fnt") as Font
	var m5x7: Font = load("res://assets/fonts/m5x7.ttf") as Font
	var sorted: Array = names.keys()
	sorted.sort_custom(func(a: String, b: String) -> bool:
		return block.get_string_size(a, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x > block.get_string_size(b, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x)
	print("[CARD_FIT] names=%d" % sorted.size())
	for n: String in sorted.slice(0, 12):
		print("[CARD_FIT] %-6s %-20s block32=%d block64=%d block96=%d m5x7_64=%d" % [names[n], n,
			block.get_string_size(n, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x,
			block.get_string_size(n, HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x,
			block.get_string_size(n, HORIZONTAL_ALIGNMENT_LEFT, -1, 96).x,
			m5x7.get_string_size(n, HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x])
	for hp: String in ["888 / 888", "180 / 180", "55 / 55"]:
		print("[CARD_FIT] hp %-10s block32=%d block64=%d block96=%d m5x7_64=%d" % [hp,
			block.get_string_size(hp, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x,
			block.get_string_size(hp, HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x,
			block.get_string_size(hp, HORIZONTAL_ALIGNMENT_LEFT, -1, 96).x,
			m5x7.get_string_size(hp, HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x])
	quit(0)
