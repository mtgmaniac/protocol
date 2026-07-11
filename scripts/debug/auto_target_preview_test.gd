# Headless regression for §3 (Batch 4): auto-targeted abilities show their
# incoming damage/heal preview — both AoE (target all) and a single-target whose
# only legal target auto-resolved — without waiting for a manual pick.
# Run: godot --headless --path . -s scripts/debug/auto_target_preview_test.gd
# Repro (manual): roll a turn where a hero lands an AoE hit (e.g. Field Engineer's
# Missile Volley) or a single-target hit with one enemy alive → the enemy card
# shows the red damage forecast immediately, before you tap anything.
extends SceneTree

const BATTLE_SCENE := "res://scenes/battle/BattleScene.tscn"
const SQUAD := ["combat", "engineer", "medic"]

var _errors: PackedStringArray = []
var _cm: Object
var _dm: Object


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("[AUTO_PREVIEW] Starting auto-target preview regression")
	var gs: Node = root.get_node("/root/GameState")
	var dmgr: Node = root.get_node("/root/DataManager")
	gs.call("start_run", SQUAD, str(dmgr.call("get_operation_order")[0]))
	gs.call("advance_to_next_battle")
	change_scene_to_file(BATTLE_SCENE)
	var retries := 180
	while retries > 0:
		retries -= 1
		await process_frame
		if current_scene != null and current_scene.scene_file_path == BATTLE_SCENE:
			break
	await create_timer(1.0).timeout

	var roll_button: Button = current_scene.get_node_or_null("%RollButton") as Button
	if roll_button != null and roll_button.visible and not roll_button.disabled:
		var tray: Node = current_scene.get_node_or_null("%DiceTray3D")
		roll_button.emit_signal("pressed")
		if tray != null and tray.has_signal("roll_finished"):
			await tray.roll_finished
		else:
			await create_timer(2.0).timeout
	await create_timer(0.4).timeout

	_cm = current_scene.get("combat_manager")
	_dm = current_scene.get("dice_manager")
	var card_view: Object = current_scene.get("_card_view")
	var hero_states: Array = _cm.call("get_hero_states")
	var enemy_states: Array = _cm.call("get_enemy_states")
	var hero_rolls: Dictionary = current_scene.get("hero_rolls")

	var enemy0: Dictionary = {}
	for es_v in enemy_states:
		if not bool((es_v as Dictionary).get("dead", false)):
			enemy0 = es_v
			break
	if enemy0.is_empty():
		_errors.append("no living enemy")
		_finish()
		return
	var enemy0_id: String = str(enemy0.get("id", ""))

	# Simulate the mid-targeting state: player has committed NOTHING manually.
	current_scene.set("turn_phase", int(current_scene.get("PHASE_TARGETING")))
	current_scene.set("has_player_target_assignment", false)

	# Neutralise every hero to a non-damaging roll + no target, so each case's
	# contribution to enemy0 is isolated.
	for hs_v in hero_states:
		var hs: Dictionary = hs_v
		var r0: int = _find_roll(hs, "nondmg")
		if r0 > 0:
			hero_rolls[str(hs.get("id", ""))] = r0
		hs["selected_target_id"] = ""
		hs["target_display"] = "--"

	# ── CASE AoE ──────────────────────────────────────────────────────────────
	var aoe_hero: Dictionary = {}
	var aoe_dmg: int = 0
	for hs_v2 in hero_states:
		var hs2: Dictionary = hs_v2
		var r: int = _find_roll(hs2, "aoe")
		if r > 0:
			hero_rolls[str(hs2.get("id", ""))] = r
			aoe_hero = hs2
			aoe_dmg = int(_ability_raw(hs2, r).get("dmg", 0))
			break
	if aoe_hero.is_empty():
		_errors.append("no hero has an AoE-damage ability to test (unexpected with Field Engineer)")
	else:
		var pv: Dictionary = card_view.call("compute_preview_for_unit", enemy0, false)
		_expect(not pv.is_empty() and int(pv.get("damage", 0)) >= aoe_dmg,
			"AoE preview shows on enemy without a manual pick (dmg=%d, want>=%d)" % [int(pv.get("damage", 0)), aoe_dmg])
		# Reset the AoE hero back to non-damaging for the next case.
		var rr: int = _find_roll(aoe_hero, "nondmg")
		if rr > 0:
			hero_rolls[str(aoe_hero.get("id", ""))] = rr

	# ── CASE forced-single (auto-assigned, gate must not suppress it) ─────────
	var st_hero: Dictionary = {}
	var st_dmg: int = 0
	for hs_v3 in hero_states:
		var hs3: Dictionary = hs_v3
		var r: int = _find_roll(hs3, "single")
		if r > 0:
			hero_rolls[str(hs3.get("id", ""))] = r
			hs3["selected_target_id"] = enemy0_id   # simulate the auto-resolve
			st_hero = hs3
			st_dmg = int(_ability_raw(hs3, r).get("dmg", 0))
			break
	if st_hero.is_empty():
		_errors.append("no hero has a single-target damage ability to test")
	else:
		current_scene.set("has_player_target_assignment", false)  # still no manual pick
		var pv2: Dictionary = card_view.call("compute_preview_for_unit", enemy0, false)
		_expect(not pv2.is_empty() and int(pv2.get("damage", 0)) >= st_dmg,
			"forced-single preview shows with no manual assignment (dmg=%d, want>=%d)" % [int(pv2.get("damage", 0)), st_dmg])

	_finish()


# Finds a roll value (1..20) whose ability matches the requested kind for this hero.
func _find_roll(hero_state: Dictionary, kind: String) -> int:
	for r in range(1, 21):
		var raw: Dictionary = _ability_raw(hero_state, r)
		if raw.is_empty():
			continue
		var dmg: int = int(raw.get("dmg", 0))
		var blast: bool = bool(raw.get("blastAll", false))
		match kind:
			"aoe":
				if blast and dmg > 0:
					return r
			"single":
				if dmg > 0 and not blast:
					return r
			"nondmg":
				if dmg == 0 and not blast and int(raw.get("burn", 0)) == 0:
					return r
	return 0


func _ability_raw(hero_state: Dictionary, roll: int) -> Dictionary:
	var entry: Dictionary = _dm.call("get_ability_for_roll", hero_state.get("unit"), roll)
	return entry.get("raw", {})


func _expect(cond: bool, label: String) -> void:
	if not cond:
		_errors.append(label)


func _finish() -> void:
	if _errors.is_empty():
		print("[AUTO_PREVIEW] PASS — AoE and forced-single previews show without a manual pick")
	else:
		for e in _errors:
			print("[AUTO_PREVIEW] FAIL: " + e)
	quit(0 if _errors.is_empty() else 1)
