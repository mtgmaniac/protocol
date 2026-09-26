# Optional observation only. Reads the engine's resolved log; no RNG draws,
# state writes or changes to ordinary telemetry / determinism fingerprints.
extends RefCounted


static func count(log_lines: Array, heroes: Array) -> Dictionary:
	var result := {"hero_repeats": 0, "enemy_repeats": 0, "capacitor_triggers": 0,
		"capacitor_protocol": 0, "echoes": 0, "enemy_reinforcements": 0}
	var hero_names: Array = heroes.map(func(st): return str(st["unit"].display_name))
	var frozen_actor := ""
	var frozen_side := ""
	for line_variant in log_lines:
		var line := str(line_variant)
		if line.contains("'s frozen die repeats its "):
			frozen_actor = line.get_slice("'s frozen die repeats its ", 0) if line.ends_with("repeats its 20.") else ""
			frozen_side = "hero" if hero_names.has(frozen_actor) else "enemy"
			if not frozen_actor.is_empty():
				result[frozen_side + "_repeats"] += 1
		elif line.contains(" uses ") or line.contains(" holds "):
			var actor := line.get_slice(" uses " if line.contains(" uses ") else " holds ", 0)
			if actor != frozen_actor:
				frozen_actor = ""
		if frozen_actor.is_empty():
			continue
		if frozen_side == "hero" and line.begins_with("Overload Capacitor: a 20 grants +"):
			result["capacitor_triggers"] += 1
			result["capacitor_protocol"] += int(line.trim_prefix("Overload Capacitor: a 20 grants +").get_slice(" ", 0))
		elif frozen_side == "hero" and line.begins_with("Overload Loop echoes the 20 for "):
			result["echoes"] += 1
		elif frozen_side == "enemy" and line.begins_with(frozen_actor + " calls for reinforcements"):
			result["enemy_reinforcements"] += 1
	return result
