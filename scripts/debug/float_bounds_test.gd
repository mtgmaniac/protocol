extends SceneTree

class FloatHost extends Control:
	var float_layer: Control

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	await process_frame
	root.size = Vector2i(540, 1200)
	root.content_scale_size = Vector2i(1080, 2400)
	var host := FloatHost.new()
	host.size = Vector2(1080, 2400)
	root.add_child(host)
	host.float_layer = Control.new()
	host.add_child(host.float_layer)
	var feedback: Node = load("res://scripts/battle/battle_feedback.gd").new()
	host.add_child(feedback)
	feedback.call("setup", host)
	var cards: Array[Control] = []
	for i in 5:
		var card := Control.new()
		card.position = Vector2(20 + i * 208, 160)
		card.size = Vector2(184, 500)
		host.add_child(card)
		cards.append(card)
	for card in cards:
		for amount in [3, 8, 12, 24, 120, 200]:
			feedback.call("_spawn_floating_text", card, "damage", amount)
	# Inspect every animation frame, including the peak punch and full rise.
	var until := Time.get_ticks_msec() + 1700
	while Time.get_ticks_msec() < until:
		await process_frame
		var registry: Dictionary = feedback.get("_live_floats_by_card")
		for card in cards:
			var bounds := Rect2(card.position + Vector2(12, card.size.y * 0.20), Vector2(card.size.x - 24, card.size.y * 0.62))
			var count := 0
			var ink_rects: Array[Rect2] = []
			for entry in registry.get(card.get_instance_id(), []):
				if not is_instance_valid(entry) or not entry.visible:
					continue
				count += 1
				var ink: Rect2 = entry.get_global_rect().grow(12 * entry.scale.x)
				if not bounds.grow(2).encloses(ink):
					failures.append("Float escaped its portrait region: ink=%s bounds=%s" % [ink, bounds])
				for previous in ink_rects:
					if previous.intersects(ink):
						failures.append("Visible floats overlap")
				ink_rects.append(ink)
			if count > 2:
				failures.append("More than two live floats on a card")
		if not failures.is_empty():
			break
	# A fresh effect still appears after all prior labels expire.
	feedback.call("_spawn_floating_text", cards[0], "heal", 10)
	var latest: Array = feedback.get("_live_floats_by_card")[cards[0].get_instance_id()]
	if latest.is_empty() or not is_instance_valid(latest.back()) or latest.back().text != "+10":
		failures.append("New outcome missing after expiration")
	for failure in failures:
		push_error(failure)
	print("[FLOAT_BOUNDS] " + ("PASS" if failures.is_empty() else "FAIL"))
	host.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

