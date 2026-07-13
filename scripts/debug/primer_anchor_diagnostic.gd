# Anchor diagnostic (Bug 1, fix/primer-highlight-granularity round 2 — this is
# the rig that produced the ghost-tree evidence table). For one real rolled
# battle, dumps EVERY node carrying a pip_icon_key meta — under (A) the rail
# AbilityReadout and (B) the visible die-docked plate — with node path, meta
# value, global rect, visible, is_visible_in_tree, and effective alpha. Then
# calls the REAL _resolve_ability_pip_rect per icon and prints its verdict.
# Profile safety is STRUCTURAL now (DevContext: any -s launch resolves
# SaveManager/settings to dev_* scratch files) — no backup/restore needed.
# Run windowed: godot --path . -s scripts/debug/primer_anchor_diagnostic.gd
extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _effective_alpha(node: Node) -> float:
	var alpha: float = 1.0
	var walker: Node = node
	while walker != null:
		if walker is CanvasItem:
			alpha *= (walker as CanvasItem).modulate.a
		walker = walker.get_parent()
	return alpha


func _dump_metas(label: String, root: Node) -> void:
	if root == null or not is_instance_valid(root):
		print("  (%s: node missing)" % label)
		return
	var found: Array = []
	_collect(root, root, found)
	print("  ── %s (%d tagged nodes) ──" % [label, found.size()])
	for row_variant in found:
		var row: Dictionary = row_variant
		print("    %-46s meta=%-14s rect=%-28s visible=%-5s in_tree_vis=%-5s alpha=%.2f" % [
			row["path"], row["meta"], row["rect"], row["visible"], row["vis_tree"], row["alpha"]])


func _collect(root: Node, node: Node, out: Array) -> void:
	if node is TextureRect and node.has_meta("pip_icon_key"):
		var c: Control = node as Control
		out.append({
			"path": str(root.get_path_to(node)),
			"meta": str(node.get_meta("pip_icon_key")),
			"rect": str(c.get_global_rect()),
			"visible": str(c.visible),
			"vis_tree": str(c.is_visible_in_tree()),
			"alpha": _effective_alpha(node),
		})
	for child in node.get_children():
		_collect(root, child, out)


func _run() -> void:
	var gs: Node = root.get_node("/root/GameState")
	gs.call("start_run", ["engineer", "shield", "avalanche"], "facility")
	change_scene_to_file("res://scenes/battle/BattleScene.tscn")
	var retries := 240
	while retries > 0:
		retries -= 1
		await process_frame
		if current_scene != null and current_scene.scene_file_path == "res://scenes/battle/BattleScene.tscn":
			break
	await create_timer(1.2).timeout
	var battle: Node = current_scene
	var primer: Node = battle.get("_primer")
	primer.set("debug_force_active", true)
	primer.set("debug_auto_dismiss", true)  # natural drain flies through, no modals block
	var roll_button: Button = battle.get_node_or_null("%RollButton") as Button
	roll_button.emit_signal("pressed")
	var dice_tray: Node = battle.get_node_or_null("%DiceTray3D")
	if dice_tray != null and dice_tray.has_signal("roll_finished"):
		await dice_tray.roll_finished
	await create_timer(1.5).timeout  # plates build in _process after reveal

	# Dump every unit whose readout is showing: rail-readout metas (what the
	# resolver walks) vs die-plate metas (what the player sees), then the REAL
	# resolver's verdict per icon.
	var die_tags: Dictionary = battle.get("_die_tags")
	for side_info in [["hero", battle.get("hero_card_views")], ["enemy", battle.get("enemy_card_views")]]:
		var side: String = str(side_info[0])
		for view_variant in side_info[1]:
			var view: Dictionary = view_variant
			var readout: Object = view.get("readout")
			if readout == null or not bool(readout.call("is_showing")):
				continue
			var unit_id: String = str((view.get("state", {}) as Dictionary).get("id", ""))
			print("[ANCHOR_DIAG] ═══ %s %s ═══" % [side, unit_id])
			_dump_metas("A: rail AbilityReadout (resolver walks THIS)", readout as Node)
			var plate_entry: Dictionary = die_tags.get("%s:%s" % [side, unit_id], {})
			_dump_metas("B: visible die-docked plate", plate_entry.get("plate") as Node)
			# C: what the real resolver picks for each distinct icon present.
			var icons: Dictionary = {}
			var collector: Array = []
			_collect(readout as Node, readout as Node, collector)
			for row_variant in collector:
				icons[str((row_variant as Dictionary)["meta"])] = true
			for icon in icons.keys():
				var picked: Rect2 = primer.call("_resolve_ability_pip_rect", {
					"side": side, "target_id": unit_id, "icon": icon})
				print("    C: resolver(%-14s) -> %s" % [icon, str(picked)])
	quit(0)
