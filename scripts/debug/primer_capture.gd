# DoD capture rig (fix/primer-highlight-granularity): launches a real windowed
# battle, rolls, fast-forwards the natural primer drain, then resets the ledger
# and re-raises the sightings for the abilities each readout ACTUALLY displays —
# so every modal in the drain anchors to a real glyph node — screenshotting each
# coachmark before tapping through. Output: debug_artifacts/primers/primer_seq_NN.png
# Run (windowed — screenshots need a real renderer):
#   godot --path . -s scripts/debug/primer_capture.gd
# Exit 0 = captured >= 3 modals incl. a scope-marker primer; 2 = rng gave too few
# sightings (rerun); 1 = rig failure.
extends SceneTree

const OUT_DIR := "res://debug_artifacts/primers/"
const SQUAD := ["engineer", "shield", "avalanche"]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var gs: Node = root.get_node("/root/GameState")
	var sm: Node = root.get_node("/root/SaveManager")
	sm.call("dev_reset_primers")
	gs.call("start_run", SQUAD, "facility")
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
	if primer == null:
		push_error("[PRIMER_CAPTURE] no primer on the battle scene")
		quit(1)
		return
	# Fast-forward the natural roll-time drain (no captures yet — we re-raise
	# below with a clean ledger for deterministic screenshots).
	primer.set("debug_force_active", true)
	primer.set("debug_auto_dismiss", true)
	var roll_button: Button = battle.get_node_or_null("%RollButton") as Button
	if roll_button == null:
		push_error("[PRIMER_CAPTURE] no roll button")
		quit(1)
		return
	roll_button.emit_signal("pressed")
	var dice_tray: Node = battle.get_node_or_null("%DiceTray3D")
	if dice_tray != null and dice_tray.has_signal("roll_finished"):
		await dice_tray.roll_finished
	await create_timer(1.0).timeout

	# Re-raise: fresh ledger, then notice the ability each readout DISPLAYS
	# (same derivation battle_scene uses), so glyph anchors resolve to the real
	# icon nodes on screen. Then flush WITHOUT awaiting — the tap loop below
	# drives the modal sequence.
	sm.call("dev_reset_primers")
	(primer.get("_fired_params") as Dictionary).clear()
	(primer.get("debug_shown_ids") as Array).clear()
	primer.set("debug_auto_dismiss", false)
	primer.call("on_turn_started")
	var cm: Object = battle.get("combat_manager")
	var dice_mgr: Object = battle.get("dice_manager")
	for side_info in [["hero", cm.call("get_hero_states"), battle.get("hero_rolls")], ["enemy", cm.call("get_enemy_states"), battle.get("enemy_rolls")]]:
		var side: String = str(side_info[0])
		var rolls: Dictionary = side_info[2]
		for state_variant in side_info[1]:
			var state: Dictionary = state_variant
			if bool(state.get("dead", false)):
				continue
			var state_id: String = str(state.get("id", ""))
			if not rolls.has(state_id):
				continue
			var eff_roll: int = cm.call("get_effective_roll", state, int(rolls[state_id]))
			var entry: Dictionary = dice_mgr.call("get_ability_for_roll", state["unit"], eff_roll)
			primer.call("notice_rolled_ability", entry.get("raw", {}), side, state_id)
	primer.call("flush_player_phase")  # not awaited — the loop taps through

	var spot: Node = primer.get("_spot")
	var shots: int = 0
	var idle: int = 0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	while idle < 120:  # ~2s with no coach visible = drain finished
		await process_frame
		if spot != null and (spot as CanvasLayer).visible:
			await create_timer(0.4).timeout  # coach placement + ring settle
			await RenderingServer.frame_post_draw
			shots += 1
			var img: Image = root.get_texture().get_image()
			img.save_png(ProjectSettings.globalize_path(OUT_DIR + "primer_seq_%02d.png" % shots))
			var shown: Array = primer.get("debug_shown_ids")
			print("[PRIMER_CAPTURE] shot %02d (mid-show, shown so far: %s)" % [shots, str(shown)])
			spot.emit_signal("tapped")
			idle = 0
			await process_frame
			await process_frame
			await process_frame
		else:
			idle += 1
	var shown_ids: Array = primer.get("debug_shown_ids")
	print("[PRIMER_CAPTURE] done — %d modals captured; sequence: %s" % [shots, str(shown_ids)])
	var has_marker: bool = shown_ids.has("primer_icon_self") or shown_ids.has("primer_icon_aoe") or shown_ids.has("primer_icon_target_lowest")
	if shots >= 3 and has_marker:
		quit(0)
	else:
		print("[PRIMER_CAPTURE] rng gave too few sightings (need >=3 + a marker) — rerun")
		quit(2)
