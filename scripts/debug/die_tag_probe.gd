# Die-tag tier verification: rolls a battle, then overrides the resolved
# readouts with synthetic effect payloads that force each presentation tier
# (1: full-size one line · 2: shrunk one line · 3: shrunk two lines), re-syncs
# the die-docked tags, and screenshots at 540x1200.
#
# Run windowed (capture harness law — the viewport must render):
#   godot --path . --script res://scripts/debug/die_tag_probe.gd
extends SceneTree

const OUTPUT := "res://debug_artifacts/battle_ui/die_tag_tiers.png"
const SQUAD := ["shield", "avalanche", "pulse"]

# Per-slot synthetic payloads: hero 0 = tier 1 basic, hero 1 = tier 1 two-pip,
# hero 2 = tier 3 evolved-grade (4 pips), enemy 0 = tier 2/3 upward growth.
const HERO_PAYLOADS := [
	{"effects": [{"kind": "dmg", "value": "12", "duration": 0, "scope": ""}], "target": ""},
	{"effects": [
		{"kind": "dmg", "value": "10", "duration": 0, "scope": ""},
		{"kind": "burn", "value": "3", "duration": 3, "scope": ""},
	], "target": ""},
	{"effects": [
		{"kind": "dmg", "value": "18", "duration": 0, "scope": ""},
		{"kind": "burn", "value": "12", "duration": 3, "scope": ""},
		{"kind": "rfm", "value": "+12", "duration": 2, "scope": "all"},
	], "target": "GUARD"},
]
const ENEMY_PAYLOAD := {"effects": [
	{"kind": "dmg", "value": "11", "duration": 0, "scope": ""},
	{"kind": "burn", "value": "3", "duration": 3, "scope": ""},
	{"kind": "roll", "value": "-2", "duration": 2, "scope": "all"},
], "target": ""}


func _initialize() -> void:
	root.size = Vector2i(540, 1200)
	call_deferred("_run")


func _run() -> void:
	root.get_node("/root/GameState").start_run(SQUAD, "facility")
	root.get_node("/root/GameState").advance_to_next_battle()
	change_scene_to_file("res://scenes/battle/BattleScene.tscn")
	var retries := 120
	while retries > 0:
		retries -= 1
		await process_frame
		if current_scene != null and current_scene.scene_file_path == "res://scenes/battle/BattleScene.tscn":
			break
	await create_timer(1.2).timeout
	var roll_button: Button = current_scene.get_node_or_null("%RollButton") as Button
	var dice_tray: Node = current_scene.get_node_or_null("%DiceTray3D")
	if roll_button != null and not roll_button.disabled:
		roll_button.emit_signal("pressed")
		if dice_tray != null and dice_tray.has_signal("roll_finished"):
			await dice_tray.roll_finished
		await create_timer(0.6).timeout
	_override_readouts()
	await process_frame
	current_scene.call("_sync_die_tags")
	await process_frame
	await RenderingServer.frame_post_draw
	var path: String = ProjectSettings.globalize_path(OUTPUT)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var image: Image = root.get_texture().get_image()
	if image != null:
		image.save_png(path)
		print("[DIE_TAG_PROBE] saved %s" % path)
	quit(0)


func _override_readouts() -> void:
	var hero_views: Array = current_scene.get("hero_card_views")
	for i in range(mini(hero_views.size(), HERO_PAYLOADS.size())):
		var readout: Object = (hero_views[i] as Dictionary).get("readout")
		if readout != null and is_instance_valid(readout):
			readout.call("configure", HERO_PAYLOADS[i], "hero")
			readout.call("show_pips")
	var enemy_views: Array = current_scene.get("enemy_card_views")
	if not enemy_views.is_empty():
		var readout: Object = (enemy_views[0] as Dictionary).get("readout")
		if readout != null and is_instance_valid(readout):
			readout.call("configure", ENEMY_PAYLOAD, "enemy")
			readout.call("show_pips")
