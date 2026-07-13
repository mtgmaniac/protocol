# Launches a predictable battle, captures the rendered viewport to disk, and exits.
extends SceneTree

const DEFAULT_OUTPUT := "res://debug_artifacts/battle_ui/latest.png"
const DEFAULT_OPERATION_ID := "facility"
const DEFAULT_BATTLE_NUMBER := 1
const DEFAULT_CAPTURE_DELAY_MS := 1200
const DEFAULT_SQUAD := ["shield", "avalanche", "pulse"]
const DEFAULT_CAPTURE_ROLLED := false
const DEFAULT_CAPTURE_LOCK_TARGETS := 0


func _initialize() -> void:
	call_deferred("_run_capture")


func _run_capture() -> void:
	var config: Dictionary = _parse_args()
	_prepare_run(config)
	change_scene_to_file("res://scenes/battle/BattleScene.tscn")
	await _wait_for_battle_scene(config)
	var output_path: String = str(config.get("output", DEFAULT_OUTPUT))
	var absolute_output: String = _resolve_output_path(output_path)
	var save_result: Error = _capture_viewport_to_file(absolute_output)
	if save_result != OK:
		push_error("Battle UI capture failed: %s" % error_string(save_result))
		quit(1)
		return
	print("[BATTLE_UI_CAPTURE] Saved screenshot to: %s" % absolute_output)
	quit(0)


func _parse_args() -> Dictionary:
	var config := {
		"output": DEFAULT_OUTPUT,
		"operation_id": DEFAULT_OPERATION_ID,
		"battle_number": DEFAULT_BATTLE_NUMBER,
		"delay_ms": DEFAULT_CAPTURE_DELAY_MS,
		"rolled": DEFAULT_CAPTURE_ROLLED,
		"lock_targets": DEFAULT_CAPTURE_LOCK_TARGETS,
	}
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--capture-output="):
			config["output"] = arg.get_slice("=", 1)
		elif arg.begins_with("--capture-operation="):
			config["operation_id"] = arg.get_slice("=", 1)
		elif arg.begins_with("--capture-squad="):
			# Comma-separated hero ids, e.g. --capture-squad=engineer,avalanche,combat
			config["squad"] = arg.get_slice("=", 1).split(",", false)
		elif arg.begins_with("--capture-evolve="):
			# Comma-separated unitId:Path Name pairs, e.g.
			# --capture-evolve=engineer:Phantom,avalanche:Trench Rig
			config["evolve"] = arg.get_slice("=", 1).split(",", false)
		elif arg.begins_with("--capture-hero-hp="):
			# Set the first hero's current HP (UI precision acceptance: HP number legibility).
			config["hero_hp"] = int(arg.get_slice("=", 1))
		elif arg.begins_with("--capture-protocol="):
			# Set the protocol pool (pip acceptance at 1/10 and 10/10).
			config["protocol"] = int(arg.get_slice("=", 1))
		elif arg == "--capture-hero-chips":
			# Grant the first hero burn+shield+roll+mark: 4 statuses -> 3 chips + "+1".
			config["hero_chips"] = true
		elif arg.begins_with("--capture-battle="):
			config["battle_number"] = maxi(int(arg.get_slice("=", 1)), 1)
		elif arg.begins_with("--capture-delay-ms="):
			config["delay_ms"] = maxi(int(arg.get_slice("=", 1)), 100)
		elif arg == "--capture-rolled":
			config["rolled"] = true
		elif arg.begins_with("--capture-lock-targets="):
			config["lock_targets"] = maxi(int(arg.get_slice("=", 1)), 0)
			config["rolled"] = true
		elif arg == "--capture-force-auto":
			config["force_auto"] = true
			config["rolled"] = true
		elif arg == "--capture-no-primers":
			# Suppress first-sight keyword primers so a locked-target capture shows the
			# board (e.g. the incoming-damage block behind an HP number) un-dimmed.
			config["no_primers"] = true
		elif arg == "--capture-debug-log":
			config["debug_log"] = true
		elif arg == "--capture-enemy-shield":
			# After rolling, give the first enemy an active shield stack and
			# force the first pending hero to target that enemy. Used to
			# visually verify shield preview behaviour.
			config["enemy_shield"] = true
			config["rolled"] = true
		elif arg == "--capture-enemy-rolls-shield":
			# After rolling, force the first enemy's roll value down to 1
			# (which maps to their shield-self recharge ability), reapply
			# enemy targeting, and have the first pending hero target them.
			# Used to verify planning-shield does NOT show blue.
			config["enemy_rolls_shield"] = true
			config["rolled"] = true
		elif arg.begins_with("--capture-pick-mode="):
			# After targets are locked, simulate pressing the reroll, nudge,
			# or item button so the scene enters the matching *_pick sub-phase.
			# Used to verify that damage preview persists across these picks.
			config["pick_mode"] = arg.get_slice("=", 1)
		elif arg == "--capture-inspect-hero":
			config["inspect"] = "hero"
		elif arg.begins_with("--capture-hero-gear="):
			# Comma-separated gear item ids equipped on the FIRST hero before inspect.
			config["hero_gear"] = arg.get_slice("=", 1).split(",", false)
		elif arg == "--capture-inspect-enemy":
			config["inspect"] = "enemy"
		elif arg == "--capture-show-die-hitboxes":
			config["show_hitboxes"] = true
		elif arg.begins_with("--capture-inspect-protocol="):
			config["inspect_protocol"] = arg.get_slice("=", 1)
		elif arg == "--capture-loadout":
			config["loadout"] = true
		elif arg.begins_with("--capture-item-target="):
			config["item_target"] = arg.get_slice("=", 1)
		elif arg.begins_with("--capture-item-confirm-action="):
			config["item_confirm_action"] = arg.get_slice("=", 1)
		elif arg == "--capture-item-offtarget":
			config["item_offtarget"] = true
		elif arg == "--capture-loadout-tap":
			config["loadout_tap"] = true
		elif arg == "--capture-loadout-tap-poor":
			config["loadout_tap"] = true
			config["loadout_poor"] = true
		elif arg == "--capture-loadout-relic-inspect":
			config["loadout_relic_inspect"] = true
		elif arg.begins_with("--capture-relics="):
			# Comma-separated relic ids granted before the battle starts (so battle-start
			# relic effects like perm_rfe / perm_roll_buff apply).
			config["relics"] = arg.get_slice("=", 1).split(",", false)
		elif arg.begins_with("--capture-help="):
			# Open the tabbed help overlay on a given tab (basics|protocol|keywords|rewards).
			config["help_tab"] = arg.get_slice("=", 1).strip_edges()
		elif arg == "--capture-tutorial":
			# Launch the rigged tutorial battle (forced squad + scripted enemy + rigged dice).
			config["tutorial"] = true
		elif arg.begins_with("--capture-tutorial-step="):
			config["tutorial"] = true
			config["tutorial_step"] = int(arg.get_slice("=", 1))
	return config


func _prepare_run(config: Dictionary) -> void:
	if bool(config.get("no_primers", false)):
		_save_manager().set_setting("ability_primers_enabled", false)
	if bool(config.get("tutorial", false)):
		_game_state().start_tutorial_run()
		return
	var operation_id: String = str(config.get("operation_id", DEFAULT_OPERATION_ID))
	var squad: Array = config.get("squad", DEFAULT_SQUAD)
	_game_state().start_run(squad, operation_id)
	# Evolved-unit captures: apply unitId:Path Name pairs before the battle
	# builds its runtime units (portraits/kits come from get_run_unit_data).
	for pair_variant in config.get("evolve", []):
		var pair: String = str(pair_variant)
		if pair.contains(":"):
			_game_state().unit_evolutions[pair.get_slice(":", 0)] = pair.get_slice(":", 1)
	var battle_number: int = int(config.get("battle_number", DEFAULT_BATTLE_NUMBER))
	for _i in range(battle_number):
		_game_state().advance_to_next_battle()
	var relics: Variant = config.get("relics", null)
	if relics != null:
		var relic_ids: Array = []
		for r in relics:
			relic_ids.append(str(r).strip_edges())
		_game_state().relics = relic_ids


func _wait_for_battle_scene(config: Dictionary) -> void:
	var delay_ms: int = int(config.get("delay_ms", DEFAULT_CAPTURE_DELAY_MS))
	var retries := 120
	while retries > 0:
		retries -= 1
		await process_frame
		if current_scene != null and current_scene.scene_file_path == "res://scenes/battle/BattleScene.tscn":
			break
	await create_timer(float(delay_ms) / 1000.0).timeout
	var debug_log_enabled: bool = bool(config.get("debug_log", false))
	if bool(config.get("rolled", DEFAULT_CAPTURE_ROLLED)):
		await _capture_after_roll(debug_log_enabled)
	var lock_count: int = int(config.get("lock_targets", DEFAULT_CAPTURE_LOCK_TARGETS))
	if lock_count > 0:
		await _lock_n_targets(lock_count)
	if bool(config.get("force_auto", false)):
		await _force_auto_target_first_hero()
	if bool(config.get("enemy_shield", false)):
		await _force_enemy_shield_scenario()
	if bool(config.get("enemy_rolls_shield", false)):
		await _force_enemy_rolls_shield_scenario()
	if config.has("hero_hp") or bool(config.get("hero_chips", false)):
		await _force_hero_card_state(config)
	if config.has("protocol"):
		current_scene.set("protocol_points", clampi(int(config["protocol"]), 0, 10))
		current_scene.call("_update_protocol_bar")
		await process_frame
	var pick_mode: String = str(config.get("pick_mode", ""))
	if pick_mode != "":
		await _force_pick_mode(pick_mode)
	if bool(config.get("show_hitboxes", false)):
		_tint_die_hitboxes()
	var hero_gear: Variant = config.get("hero_gear", null)
	if hero_gear != null and current_scene != null:
		var gs2: Node = root.get_node_or_null("/root/GameState")
		var hero_views2: Array = current_scene.get("hero_card_views")
		if gs2 != null and hero_views2 != null and not hero_views2.is_empty():
			var first_state: Dictionary = (hero_views2[0] as Dictionary).get("state", {})
			var unit_res: Resource = first_state.get("unit", null) as Resource
			if unit_res != null:
				var gear_ids: Array = []
				for g in hero_gear:
					gear_ids.append(str(g))
				(gs2.get("gear_by_unit") as Dictionary)[str(unit_res.get("id"))] = gear_ids
	var inspect_side: String = str(config.get("inspect", ""))
	if inspect_side != "":
		_open_inspect(inspect_side)
		await process_frame
		await process_frame
	var protocol_key: String = str(config.get("inspect_protocol", ""))
	if protocol_key != "":
		_long_press_protocol(protocol_key)
		await create_timer(0.55).timeout
		await process_frame
	if bool(config.get("loadout", false)):
		_open_loadout()
		await process_frame
		await process_frame
		await process_frame
	var item_target: String = str(config.get("item_target", ""))
	if item_target != "":
		_use_item_target(item_target)
		await process_frame
		await process_frame
		await process_frame
		# Optionally drive the no-target confirm card's follow-up tap directly (synthetic
		# viewport input won't reach the card's gui_input). "activate" = tap card again,
		# "cancel" = tap off the card.
		var confirm_action: String = str(config.get("item_confirm_action", ""))
		if confirm_action != "" and current_scene != null:
			current_scene.set("_item_targeting_armed", true)
			var has_card_before: bool = current_scene.get("_protocol").get("_item_targeting_card") != null
			var phase_before: String = str(current_scene.get("turn_phase"))
			if confirm_action == "activate":
				current_scene.get("_protocol").call("_confirm_pending_item")
			elif confirm_action == "cancel":
				current_scene.get("_protocol").call("_cancel_item_to_loadout")
			await process_frame
			await process_frame
			var has_card_after: bool = current_scene.get("_protocol").get("_item_targeting_card") != null
			var phase_after: String = str(current_scene.get("turn_phase"))
			print("[ITEMDBG] confirm_action=", confirm_action,
				" card before=", has_card_before, " after=", has_card_after,
				" phase ", phase_before, " -> ", phase_after,
				" pending=", current_scene.get("_protocol").get("_pending_item") != null)
		# Optionally simulate tapping a wrong-side unit/die (a non-legal target) during item
		# targeting — should cancel the item back to the loadout, same as tapping the card.
		if bool(config.get("item_offtarget", false)) and current_scene != null:
			current_scene.set("_item_targeting_armed", true)
			var cm: Object = current_scene.get("combat_manager")
			var hero_id: String = ""
			if cm != null:
				var heroes: Array = cm.call("get_hero_states")
				if not heroes.is_empty():
					hero_id = str((heroes[0] as Dictionary).get("id", ""))
			var phase_before2: String = str(current_scene.get("turn_phase"))
			var card_before2: bool = current_scene.get("_protocol").get("_item_targeting_card") != null
			print("[ITEMDBG] offtarget: tapping wrong-side hero ", hero_id, " during ", phase_before2)
			current_scene.call("_on_hero_card_pressed", hero_id)
			await process_frame
			await process_frame
			var phase_after2: String = str(current_scene.get("turn_phase"))
			var card_after2: bool = current_scene.get("_protocol").get("_item_targeting_card") != null
			print("[ITEMDBG] offtarget result: card ", card_before2, " -> ", card_after2,
				" phase ", phase_before2, " -> ", phase_after2,
				" pending=", current_scene.get("_protocol").get("_pending_item") != null)
	if bool(config.get("loadout_tap", false)):
		_open_loadout()
		await process_frame
		await process_frame
		await process_frame
		if bool(config.get("loadout_poor", false)) and current_scene != null and "protocol_points" in current_scene:
			# Drain Protocol so the tapped item is unaffordable — exercises the red-flash /
			# stay-open rejection path instead of the normal use-and-close.
			current_scene.set("protocol_points", 0)
		_tap_loadout_first_item()
		await process_frame
		await process_frame
		await process_frame
	if config.has("tutorial_step") and current_scene != null:
		var controllers: Array = root.find_children("*", "TutorialController", true, false)
		if not controllers.is_empty():
			controllers[0].call("_show_step", int(config["tutorial_step"]))
			await process_frame
			await process_frame
			await process_frame
	var help_tab: String = str(config.get("help_tab", ""))
	if help_tab != "" and current_scene != null:
		HelpMenu.open(current_scene)
		await process_frame
		var menu: Node = root.find_children("*", "HelpMenu", true, false)[0] if not root.find_children("*", "HelpMenu", true, false).is_empty() else null
		if menu != null and menu.has_method("_select_tab"):
			menu.call("_select_tab", help_tab)
		await process_frame
		await process_frame
		await process_frame
	if bool(config.get("loadout_relic_inspect", false)):
		_open_loadout()
		await process_frame
		await process_frame
		await process_frame
		_long_press_loadout_relic()
		await process_frame
		await process_frame
		await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	if debug_log_enabled:
		_print_target_state("final")


# Opens the unified InspectPopup on the first hero/enemy card, exercising the live
# _on_unit_detail_requested path (Stage-2 migration verification).
# Grant protocol + a consumable, then begin using it (enters item-target phase, showing
# the centered item card).
func _use_item_target(item_id: String) -> void:
	if current_scene == null:
		return
	var gs: Node = root.get_node_or_null("/root/GameState")
	if gs != null:
		gs.set("consumables", [item_id])
		gs.set("relics", ["ironCurtain"])
	if current_scene.has_method("_update_item_panel"):
		current_scene.call("_update_item_panel")
	if "protocol_points" in current_scene:
		current_scene.set("protocol_points", 10)
	var dm: Node = root.get_node_or_null("/root/DataManager")
	var item: Resource = dm.call("get_item", item_id) if dm != null else null
	if item != null and current_scene.get("_protocol") != null:
		current_scene.get("_protocol").call("_on_item_button_pressed", item)


# Seed a couple of consumables + a relic, then open the themed LOADOUT menu.
func _open_loadout() -> void:
	if current_scene == null:
		return
	var gs: Node = root.get_node_or_null("/root/GameState")
	if gs != null:
		gs.set("consumables", ["grounding_clip", "scrap_plate"])
		gs.set("relics", ["ironCurtain"])
	if "protocol_points" in current_scene:
		current_scene.set("protocol_points", 10)
	# The item list lives on the protocol module — refresh it AFTER seeding so
	# the menu shows the seeded consumables.
	if current_scene.get("_protocol") != null:
		current_scene.get("_protocol").call("_update_item_panel")
		current_scene.get("_protocol").call("_on_item_button_pressed_menu")


func _tap_loadout_first_item() -> void:
	# Synthetic push_input does NOT route to the row's gui_input (CanvasLayer GUI picking
	# needs real OS input), so drive the menu's row handler directly — this still exercises
	# the real _on_use callback wiring and the accept/reject branching.
	var menus: Array = root.find_children("*", "LoadoutMenu", true, false)
	if menus.is_empty():
		print("[ITEMDBG] no LoadoutMenu open")
		return
	var menu: Node = menus[0]
	var row: Node = menu.find_child("LoadoutItemRow", true, false)
	if row == null:
		print("[ITEMDBG] no LoadoutItemRow found")
		return
	var gs: Node = root.get_node_or_null("/root/GameState")
	var dm: Node = root.get_node_or_null("/root/DataManager")
	var item: Resource = null
	if gs != null and dm != null:
		var cons: Array = gs.get("consumables")
		if cons != null and not cons.is_empty():
			item = dm.call("get_item", str(cons[0]))
	if item == null:
		print("[ITEMDBG] no item resolved for loadout tap")
		return
	print("[ITEMDBG] driving row handler for ", item.display_name)
	menu.call("_on_item_row_tapped", row, item)


# Drives a long-press on the loadout's relic row directly (synthetic input can't reach
# gui_input) to verify it opens the InspectPopup.
func _long_press_loadout_relic() -> void:
	var menus: Array = root.find_children("*", "LoadoutMenu", true, false)
	if menus.is_empty():
		print("[ITEMDBG] no LoadoutMenu open")
		return
	var menu: Node = menus[0]
	var row: Node = menu.find_child("LoadoutRelicRow", true, false)
	if row == null:
		print("[ITEMDBG] no LoadoutRelicRow found")
		return
	var gs: Node = root.get_node_or_null("/root/GameState")
	var dm: Node = root.get_node_or_null("/root/DataManager")
	var relic: Resource = null
	if gs != null and dm != null:
		var relics: Array = gs.get("relics")
		if relics != null and not relics.is_empty():
			relic = dm.call("get_item", str(relics[0]))
	if relic == null:
		print("[ITEMDBG] no relic resolved for loadout long-press")
		return
	print("[ITEMDBG] driving relic long-press for ", relic.display_name)
	menu.call("_on_row_long_pressed", Vector2.ZERO, relic, row)
	var popups: Array = root.find_children("*", "InspectPopup", true, false)
	print("[ITEMDBG] InspectPopup open after relic long-press: ", not popups.is_empty())


# Drive a real long-press (press + hold past the threshold) on a protocol control to
# exercise the LongPressInput->InspectPopup path on a Button.
func _long_press_protocol(key: String) -> void:
	if current_scene == null:
		return
	var button: Object = null
	match key:
		"reroll":
			button = current_scene.get("protocol_spend_button")
		"nudge":
			button = current_scene.get("_nudge_button")
		"set":
			button = current_scene.get("_set_button")
	if button == null or not (button is Control) or not is_instance_valid(button):
		return
	var control: Control = button
	if control is BaseButton:
		(control as BaseButton).disabled = false
	if "protocol_points" in current_scene:
		current_scene.set("protocol_points", 10)
	var pos: Vector2 = control.global_position + control.size * 0.5
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.position = pos
	press.global_position = pos
	root.push_input(press)
	print("[BATTLE_UI_CAPTURE] long-pressing protocol '%s' at %s" % [key, pos])


# Debug: tint the (normally invisible) die long-press hit-rects so coverage is visible.
func _tint_die_hitboxes() -> void:
	if current_scene == null:
		return
	var overlays: Variant = current_scene.get("_die_tooltip_overlays")
	if overlays is Array:
		for overlay_variant in overlays:
			if overlay_variant is ColorRect and is_instance_valid(overlay_variant):
				(overlay_variant as ColorRect).color = Color(1.0, 0.2, 0.2, 0.30)


func _open_inspect(side: String) -> void:
	if current_scene == null:
		return
	var key: String = "hero_card_views" if side == "hero" else "enemy_card_views"
	var views: Variant = current_scene.get(key)
	if not (views is Array) or (views as Array).is_empty():
		return
	var card: Node = ((views as Array)[0] as Dictionary).get("card")
	if card != null and current_scene.has_method("_on_unit_detail_requested"):
		current_scene.call("_on_unit_detail_requested", card)


func _force_pick_mode(mode: String) -> void:
	if current_scene == null:
		return
	var battle: Node = current_scene
	# Grant a generous protocol pool so the gating in _on_*_button_pressed
	# doesn't bail out early.
	if "protocol_points" in battle:
		battle.set("protocol_points", 10)
	var method_name := ""
	match mode:
		"reroll":
			method_name = "_on_reroll_button_pressed"
		"nudge":
			method_name = "_on_nudge_button_pressed"
		"item":
			# Items need a real ItemData; just set the phase directly to
			# PHASE_ITEM_PICK_ENEMY to mimic an enemy-target item being chosen.
			if battle.has_method("transition"):
				battle.call("transition", battle.call("phase_from_name", "item_pick_enemy"))
			await process_frame
			return
	if method_name != "" and battle.has_method(method_name):
		battle.call(method_name)
		await process_frame


func _capture_after_roll(debug_log_enabled: bool = false) -> void:
	if current_scene == null:
		return
	var roll_button: Button = current_scene.get_node_or_null("%RollButton") as Button
	if roll_button == null or roll_button.disabled or not roll_button.visible:
		return
	var dice_tray: Node = current_scene.get_node_or_null("%DiceTray3D")
	roll_button.emit_signal("pressed")
	if dice_tray != null and dice_tray.has_signal("roll_finished"):
		await dice_tray.roll_finished
	else:
		await create_timer(2.0).timeout
	await create_timer(0.4).timeout
	if debug_log_enabled:
		_print_target_state("post-roll")


func _print_target_state(tag: String) -> void:
	if current_scene == null:
		return
	var battle: Node = current_scene
	var phase: String = str(battle.get("turn_phase"))
	var lines: PackedStringArray = []
	var pending_ids: Array = battle.get("pending_manual_target_ids")
	lines.append("[CAPTURE_DEBUG][%s] turn_phase=%s pending=%s" % [tag, phase, str(pending_ids)])
	var hero_views: Array = battle.get("hero_card_views")
	if hero_views != null:
		for view_variant in hero_views:
			var view: Dictionary = view_variant
			var state: Dictionary = view.get("state", {})
			var unit_name: String = ""
			var unit_resource: Resource = state.get("unit", null) as Resource
			if unit_resource != null and unit_resource.has_method("battle_name"):
				unit_name = str(unit_resource.call("battle_name"))
			var card: Node = view.get("card", null)
			var card_mod: Color = Color.WHITE
			var card_target_locked: bool = false
			if card != null:
				card_mod = card.modulate
				card_target_locked = bool(card.get("target_locked"))
			lines.append("  hero=%s id=%s display=%s sel_id=%s card.target_locked=%s card.modulate=%s" % [
				unit_name,
				str(state.get("id", "?")),
				str(state.get("target_display", "?")),
				str(state.get("selected_target_id", "?")),
				str(card_target_locked),
				str(card_mod),
			])
	var log_path: String = ProjectSettings.globalize_path("res://debug_artifacts/battle_ui/capture_debug.log")
	var f: FileAccess = FileAccess.open(log_path, FileAccess.READ_WRITE if FileAccess.file_exists(log_path) else FileAccess.WRITE)
	if f == null:
		f = FileAccess.open(log_path, FileAccess.WRITE)
	if f != null:
		f.seek_end()
		for line in lines:
			f.store_line(line)
		f.close()


func _force_enemy_rolls_shield_scenario() -> void:
	if current_scene == null:
		return
	var battle: Node = current_scene
	var enemy_views: Array = battle.get("enemy_card_views")
	if enemy_views == null or enemy_views.is_empty():
		return
	var first_enemy_view: Dictionary = enemy_views[0]
	var enemy_state: Dictionary = first_enemy_view.get("state", {})
	if enemy_state.is_empty():
		return
	var enemy_id: String = str(enemy_state.get("id", ""))
	# Force roll to 1 — scrap_drone's recharge (shield 8, 2t) sits in the low
	# roll band per data inspection.
	var enemy_rolls: Dictionary = battle.get("enemy_rolls")
	if enemy_rolls != null:
		enemy_rolls[enemy_id] = 1
	_force_log("enemy_rolls_shield: forced enemy %s roll to 1" % enemy_id)
	# Have first pending hero target this enemy so damage preview triggers.
	var pending: Array = battle.get("pending_manual_target_ids")
	if pending != null and not pending.is_empty():
		for hero_id_variant in pending.duplicate():
			var hero_id: String = str(hero_id_variant)
			if not battle.has_method("_select_targeting_hero"):
				break
			battle.call("_select_targeting_hero", hero_id)
			await process_frame
			var legal_ids: Array = battle.get("legal_target_ids")
			var legal_side: String = str(battle.get("legal_target_side"))
			if legal_side == "enemy" and legal_ids != null and legal_ids.has(enemy_id):
				battle.call("_assign_target_to_active_hero", enemy_id, "enemy")
				await process_frame
				_force_log("enemy_rolls_shield: assigned %s -> %s" % [hero_id, enemy_id])
				break
	if battle.has_method("_refresh_all_cards"):
		battle.call("_refresh_all_cards")
	await process_frame


# UI precision acceptance rig: pin the first hero's HP (e.g. a non-round value to
# verify the HP number reads over the fill/damage block) and/or grant 4 simultaneous
# statuses (burn + shield + dice+1 + mark -> 3 chips and the "+1" overflow badge, the
# documented chip cap).
func _force_hero_card_state(config: Dictionary) -> void:
	if current_scene == null:
		return
	var hero_views: Array = current_scene.get("hero_card_views")
	if hero_views == null or hero_views.is_empty():
		return
	var state: Dictionary = (hero_views[0] as Dictionary).get("state", {})
	if state.is_empty():
		return
	if config.has("hero_hp"):
		state["current_hp"] = clampi(int(config["hero_hp"]), 1, int(state.get("max_hp", 55)))
	if bool(config.get("hero_chips", false)):
		state["burn"] = 4
		state["burn_turns"] = 2
		state["shield_stacks"] = [{"amt": 8, "skip_next_tick": false}]
		state["shield"] = 8
		state["roll_buff"] = 1
		state["marked"] = true
	if current_scene.has_method("_refresh_all_cards"):
		current_scene.call("_refresh_all_cards")
	elif current_scene.get("_card_view") != null:
		current_scene.get("_card_view").call("refresh_all_cards")
	await process_frame


func _force_enemy_shield_scenario() -> void:
	if current_scene == null:
		return
	var battle: Node = current_scene
	var enemy_views: Array = battle.get("enemy_card_views")
	if enemy_views == null or enemy_views.is_empty():
		return
	var first_enemy_view: Dictionary = enemy_views[0]
	var enemy_state: Dictionary = first_enemy_view.get("state", {})
	if enemy_state.is_empty():
		return
	var stacks: Array = enemy_state.get("shield_stacks", [])
	stacks.append({"amt": 12, "skip_next_tick": false})
	enemy_state["shield_stacks"] = stacks
	enemy_state["shield"] = 12
	var enemy_id: String = str(enemy_state.get("id", ""))
	_force_log("enemy_shield: granted 12 shield to enemy id=%s" % enemy_id)
	var pending: Array = battle.get("pending_manual_target_ids")
	if pending == null or pending.is_empty():
		_force_log("enemy_shield: no pending heroes to target")
		if battle.has_method("_refresh_all_cards"):
			battle.call("_refresh_all_cards")
		await process_frame
		return
	# Find a pending hero whose ability targets enemies.
	var assigned: bool = false
	for hero_id_variant in pending.duplicate():
		var hero_id: String = str(hero_id_variant)
		if not battle.has_method("_select_targeting_hero"):
			break
		battle.call("_select_targeting_hero", hero_id)
		await process_frame
		var legal_ids: Array = battle.get("legal_target_ids")
		var legal_side: String = str(battle.get("legal_target_side"))
		_force_log("enemy_shield: hero=%s legal_side=%s legal_ids=%s" % [hero_id, legal_side, str(legal_ids)])
		if legal_side == "enemy" and legal_ids != null and legal_ids.has(enemy_id):
			battle.call("_assign_target_to_active_hero", enemy_id, "enemy")
			await process_frame
			assigned = true
			_force_log("enemy_shield: assigned %s -> %s" % [hero_id, enemy_id])
			break
	if not assigned:
		_force_log("enemy_shield: no hero could target enemy %s" % enemy_id)
	if battle.has_method("_refresh_all_cards"):
		battle.call("_refresh_all_cards")
	await process_frame


func _force_log(message: String) -> void:
	var log_path: String = ProjectSettings.globalize_path("res://debug_artifacts/battle_ui/capture_debug.log")
	var f: FileAccess = FileAccess.open(log_path, FileAccess.READ_WRITE if FileAccess.file_exists(log_path) else FileAccess.WRITE)
	if f == null:
		f = FileAccess.open(log_path, FileAccess.WRITE)
	if f != null:
		f.seek_end()
		f.store_line(message)
		f.close()


func _force_auto_target_first_hero() -> void:
	if current_scene == null:
		return
	var battle: Node = current_scene
	var hero_views: Array = battle.get("hero_card_views")
	if hero_views == null or hero_views.is_empty():
		return
	var first_view: Dictionary = hero_views[0]
	var state: Dictionary = first_view.get("state", {})
	if state.is_empty():
		return
	state["selected_target_id"] = ""
	state["target_display"] = "All Squad"
	var pending: Array = battle.get("pending_manual_target_ids")
	if pending != null:
		pending.erase(str(state.get("id", "")))
	if battle.has_method("_refresh_all_cards"):
		battle.call("_refresh_all_cards")
	await process_frame


func _lock_n_targets(count: int) -> void:
	if current_scene == null:
		return
	var battle: Node = current_scene
	if not battle.has_method("_select_targeting_hero") or not battle.has_method("_assign_target_to_active_hero"):
		return
	for _i in range(count):
		var pending: Array = battle.get("pending_manual_target_ids")
		if pending == null or pending.is_empty():
			break
		var hero_id: String = str(pending[0])
		battle.call("_select_targeting_hero", hero_id)
		await process_frame
		var active: String = str(battle.get("active_targeting_hero_id"))
		if active == "":
			break
		var legal_ids: Array = battle.get("legal_target_ids")
		var legal_side: String = str(battle.get("legal_target_side"))
		if legal_ids == null or legal_ids.is_empty():
			break
		var target_id: String = str(legal_ids[0])
		battle.call("_assign_target_to_active_hero", target_id, legal_side)
		await process_frame
	await create_timer(0.2).timeout


func _resolve_output_path(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	return path


func _capture_viewport_to_file(absolute_output: String) -> Error:
	var directory: String = absolute_output.get_base_dir()
	var make_dir_result: Error = DirAccess.make_dir_recursive_absolute(directory)
	if make_dir_result != OK:
		return make_dir_result
	var image: Image = root.get_texture().get_image()
	if image == null:
		return ERR_CANT_ACQUIRE_RESOURCE
	return image.save_png(absolute_output)


func _game_state() -> Node:
	return root.get_node("/root/GameState")


func _save_manager() -> Node:
	return root.get_node("/root/SaveManager")
