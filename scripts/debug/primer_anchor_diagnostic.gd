# Anchor diagnostic (round 3, self/pierce whole-plate reports). Two probes:
#   A. NATURAL-FLOW TIMING: fresh ledger, real roll, the scene's own drain
#      presents modals — for each modal, dump the actual spotlight hole rect
#      vs the taught unit's plate-glyph/plate/row rects, and whether the plate
#      even EXISTED at show time (plates build in _process one frame after
#      reveal; a first-modal resolve may precede them -> row fallback).
#   B. FORCED BANDS: combat -> 18 (Precision Shot, PIERCE) via the REAL
#      readout reconfigure path (refresh_all_cards, not the die-face repaint),
#      then dump plate metas + resolver verdicts.
# Profile isolation is structural (DevContext).
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
		print("    %-46s meta=%-14s rect=%-28s alpha=%.2f" % [
			row["path"], row["meta"], row["rect"], row["alpha"]])


func _collect(root: Node, node: Node, out: Array) -> void:
	if node is TextureRect and node.has_meta("pip_icon_key"):
		var c: Control = node as Control
		out.append({
			"path": str(root.get_path_to(node)),
			"meta": str(node.get_meta("pip_icon_key")),
			"rect": str(c.get_global_rect()),
			"alpha": _effective_alpha(node),
		})
	for child in node.get_children():
		_collect(root, child, out)


func _classify_hole(battle: Node, hole: Rect2) -> String:
	# Which link of the chain does this hole rect correspond to?
	var die_tags: Dictionary = battle.get("_die_tags")
	for side_info in [["hero", battle.get("hero_card_views")], ["enemy", battle.get("enemy_card_views")]]:
		for view_variant in side_info[1]:
			var view: Dictionary = view_variant
			var unit_id: String = str((view.get("state", {}) as Dictionary).get("id", ""))
			var plate_entry: Dictionary = die_tags.get("%s:%s" % [str(side_info[0]), unit_id], {})
			var plate: Variant = plate_entry.get("plate")
			if plate is Control and is_instance_valid(plate):
				var glyphs: Array = []
				_collect(plate as Node, plate as Node, glyphs)
				for g_variant in glyphs:
					var g: Dictionary = g_variant
					var r: Rect2 = _rect_from_str(str(g["rect"]))
					if r.size != Vector2.ZERO and hole.grow(-10).intersects(r) and hole.size.x < r.size.x * 3.0:
						return "PLATE GLYPH (%s %s, meta=%s)" % [str(side_info[0]), unit_id, str(g["meta"])]
				var pr: Rect2 = (plate as Control).get_global_rect()
				if hole.grow(-16).encloses(pr.grow(-4)) and hole.size.x < pr.size.x * 1.4:
					return "WHOLE PLATE (%s %s)" % [str(side_info[0]), unit_id]
			var readout: Control = view.get("readout", null) as Control
			if readout != null and is_instance_valid(readout):
				var rr: Rect2 = readout.get_global_rect()
				if hole.grow(-16).intersects(rr) and absf(hole.size.x - rr.size.x) < 40.0:
					return "READOUT ROW (%s %s)" % [str(side_info[0]), unit_id]
	return "OTHER/CARD"


func _rect_from_str(_s: String) -> Rect2:
	return Rect2()  # placeholder — glyph classification uses direct rects below


func _run() -> void:
	var gs: Node = root.get_node("/root/GameState")
	var sm: Node = root.get_node("/root/SaveManager")
	sm.call("dev_reset_primers")
	gs.call("start_run", ["combat", "shield", "avalanche"], "facility")
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
	primer.set("debug_force_active", true)  # auto_dismiss stays FALSE — we drive taps

	# ── Probe A: natural-flow drain — per modal, dump the hole + plate state.
	print("[ANCHOR_DIAG] ══ PROBE A: natural-flow drain timing ══")
	var roll_button: Button = battle.get_node_or_null("%RollButton") as Button
	roll_button.emit_signal("pressed")
	var spot: Node = primer.get("_spot")
	var die_tags: Dictionary = battle.get("_die_tags")
	var modal_n: int = 0
	var idle: int = 0
	while idle < 240:  # ~4s without a coach = drain done
		await process_frame
		if spot != null and (spot as CanvasLayer).visible:
			modal_n += 1
			var holes: Array = (spot.get("_dim_canvas") as Node).get("holes")
			var hole: Rect2 = holes[0] if not holes.is_empty() else Rect2()
			var plates_alive: int = 0
			for key in die_tags:
				var pv: Variant = (die_tags[key] as Dictionary).get("plate")
				if pv is Control and is_instance_valid(pv):
					plates_alive += 1
			var verdict: String = _classify_hole_live(battle, hole)
			print("  modal %d: hole=%s plates_alive=%d -> %s" % [modal_n, str(hole), plates_alive, verdict])
			spot.emit_signal("tapped")
			idle = 0
			await process_frame
			await process_frame
			await process_frame
		else:
			idle += 1
	print("  drained; shown sequence: %s" % str(primer.get("debug_shown_ids")))

	# ── Probe B: force PIERCE (combat -> 18 = Precision Shot) via the REAL
	# readout reconfigure path, then dump plate metas + resolver verdicts.
	print("[ANCHOR_DIAG] ══ PROBE B: forced Precision Shot (pierce) ══")
	var rolls: Dictionary = battle.get("hero_rolls")
	var combat_sid: String = ""
	for view_variant in battle.get("hero_card_views"):
		var v: Dictionary = view_variant
		var st: Dictionary = v.get("state", {})
		var unit: Object = st.get("unit", null) as Object
		if unit != null and str(unit.get("id")) == "combat":
			combat_sid = str(st.get("id", ""))
			rolls[combat_sid] = 18
	(battle.get("_card_view") as Object).call("refresh_all_cards")  # readouts reconfigure here
	await create_timer(1.0).timeout  # plates rebuild on sig change in _process
	for view_variant in battle.get("hero_card_views"):
		var v: Dictionary = view_variant
		var st: Dictionary = v.get("state", {})
		if str(st.get("id", "")) != combat_sid:
			continue
		_dump_metas("A: rail readout (combat @18)", v.get("readout") as Node)
		var plate_entry: Dictionary = (battle.get("_die_tags") as Dictionary).get("hero:%s" % combat_sid, {})
		_dump_metas("B: visible plate (combat @18)", plate_entry.get("plate") as Node)
		for icon in ["damage", "pierce"]:
			var picked: Rect2 = primer.call("_resolve_ability_pip_rect", {
				"side": "hero", "target_id": combat_sid, "icon": icon})
			print("    C: resolver(%-8s) -> %s" % [icon, str(picked)])
	quit(0)


# Live classification against actual node rects.
func _classify_hole_live(battle: Node, hole: Rect2) -> String:
	var die_tags: Dictionary = battle.get("_die_tags")
	for side_info in [["hero", battle.get("hero_card_views")], ["enemy", battle.get("enemy_card_views")]]:
		for view_variant in side_info[1]:
			var view: Dictionary = view_variant
			var unit_id: String = str((view.get("state", {}) as Dictionary).get("id", ""))
			var plate_entry: Dictionary = die_tags.get("%s:%s" % [str(side_info[0]), unit_id], {})
			var plate: Variant = plate_entry.get("plate")
			if plate is Control and is_instance_valid(plate):
				var glyphs: Array = []
				_collect_nodes(plate as Node, glyphs)
				for g in glyphs:
					var gr: Rect2 = (g as Control).get_global_rect()
					# The hole is the glyph rect grown by PAD 14 — match by center containment + similar size.
					if hole.has_point(gr.get_center()) and hole.size.x <= gr.size.x + 40.0:
						return "PLATE GLYPH %s/%s meta=%s" % [str(side_info[0]), unit_id, str((g as Node).get_meta("pip_icon_key"))]
				var pr: Rect2 = (plate as Control).get_global_rect()
				if hole.has_point(pr.get_center()) and absf(hole.size.x - (pr.size.x + 28.0)) < 30.0:
					return "WHOLE PLATE %s/%s" % [str(side_info[0]), unit_id]
			var readout: Control = view.get("readout", null) as Control
			if readout != null and is_instance_valid(readout):
				var rr: Rect2 = readout.get_global_rect()
				if hole.has_point(rr.get_center()) and absf(hole.size.x - (rr.size.x + 28.0)) < 30.0:
					return "READOUT ROW %s/%s" % [str(side_info[0]), unit_id]
	return "OTHER/CARD/DIE"


func _collect_nodes(node: Node, out: Array) -> void:
	if node is TextureRect and node.has_meta("pip_icon_key"):
		out.append(node)
	for child in node.get_children():
		_collect_nodes(child, out)
