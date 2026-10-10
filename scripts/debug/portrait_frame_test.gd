# Portrait frame gate: on the LIVE screens, every portrait shows through the one
# portrait window (PixelUI.HERO_PORTRAIT_REGION aspect) and its art is never
# stretched.
#   <godot> --headless --path . -s scripts/debug/portrait_frame_test.gd [-- --portrait-frame-break=stretch]
#
# The static `framing sites` gate proves each screen CALLS the helper, and the
# framing editor's site list repeats each screen's intended size. Neither looks
# at the frame a screen really lays out: the evolution choice portraits asked
# for the right minimum size, were stretched tall by their row, and passed both
# (2026-10-10). This test loads each screen and measures the laid-out frame.
#
# For every visible TextureRect on every screen in SITES:
#   1. window  - a portrait placed by PixelUI.cover_fit_portrait sits in a frame
#                whose aspect is the portrait region's, within one design px;
#   2. art     - its drawn size keeps the texture's own aspect (no stretch);
#   3. helper  - portrait art (tagged heroes / enemies / bosses by DataManager)
#                is never shown without the helper.
# Each site must show at least its expected number of DIFFERENT portraits, so a
# sweep that stops reaching a screen fails instead of passing empty.
# Breaks (PixelUI.portrait_frame_break, debug builds only): `stretch` lets a
# row stretch the evolution portraits (the bug), `squash` draws them
# off-aspect, `bypass` shows one without the helper.
extends SceneTree

const PIXEL_UI := "res://scripts/ui/pixel_ui.gd"
const HEROES := ["pulse", "combat", "shield", "avalanche", "medic", "engineer", "ghost", "breaker"]
const OPERATIONS := ["facility", "hive", "veil", "voidCirclet", "stellarMenagerie"]
const PORTRAIT_SECTIONS := ["heroes", "enemies", "bosses"]
const WINDOW_TOLERANCE_PX := 1.0
const ART_TOLERANCE := 0.005
# Site -> the fewest different portraits it must show. Squad select is the 8
# hero tiles plus the encounter panel's 5 bosses; Help > Units is every hero,
# evolution and enemy; battle cards is the squad of 3, the 5 bosses and at
# least one other enemy per operation; evolution is 2 branches for each of 8
# heroes. Screens at 0 show no portrait today and are swept so one added later
# is measured too.
const SITES := {
	"squad select": 13,
	"help units": 62,
	"battle cards": 13,
	"tutorial battle": 4,
	"evolution": 16,
	"unlock / run end": 1,
	"directive": 0,
	"reward": 0,
	"route fork": 0,
	"intercept": 0,
	"run end": 0,
	"main menu": 0,
}

var failures: Array[String] = []
var _seen: Dictionary = {}    # site -> {art key: true}
var _frames: Dictionary = {}  # site -> {"WxH": true}
var _measured := 0
var _aspect := 0.0
var _verbose := false


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	if not ok and not failures.has(message):
		failures.append(message)


func settle(frames: int = 8) -> void:
	for _i in frames:
		await process_frame


func _run() -> void:
	await process_frame
	_verbose = OS.get_cmdline_user_args().has("--portrait-frame-verbose")
	var region: Vector2 = load(PIXEL_UI).HERO_PORTRAIT_REGION
	_aspect = region.x / region.y
	root.get_node("/root/AudioManager").call("set_suppressed", true)
	var gs: Node = root.get_node("/root/GameState")
	var sm: Node = root.get_node("/root/SaveManager")
	var disk_was: bool = bool(sm.get("_disk_enabled"))

	await _show("res://scenes/ui/MainMenu.tscn")
	_walk("main menu")

	# Squad select: every hero tile, and the encounter panel on each operation.
	await _show("res://scenes/ui/UnitSelect.tscn")
	for _index in OPERATIONS.size():
		_walk("squad select")
		current_scene.call("_on_nav_pressed", 1)
		await settle()

	# Help > Units: the squad list and every enemy faction.
	var help: GDScript = load("res://scripts/ui/help_menu.gd")
	help.open(current_scene)
	await settle()
	var menu: Node = help.get("_active")
	menu.call("_select_tab", "units")
	await settle()
	for faction in (menu.get("_bestiary_buttons") as Dictionary).keys():
		menu.call("_select_bestiary_faction", faction)
		await settle()
		_walk("help units", menu)
	help.dismiss()
	await settle()

	# Battle cards: the first battle and the boss battle of every operation.
	for operation in OPERATIONS:
		for battles in [1, 10]:
			gs.call("start_run", ["combat", "avalanche", "medic"], operation, 424242)
			for _i in battles:
				gs.call("advance_to_next_battle")
			await _show("res://scenes/battle/BattleScene.tscn")
			_walk("battle cards")
	gs.call("start_tutorial_run")
	await _show("res://scenes/battle/BattleScene.tscn")
	_walk("tutorial battle")

	# Evolution: both branch portraits of every hero, then a Directive pick.
	for hero in HEROES:
		var squad: Array = [hero]
		for other in HEROES:
			if squad.size() < 3 and other != hero:
				squad.append(other)
		gs.call("start_run", squad, "facility", 424242)
		gs.call("advance_to_next_battle")
		gs.set("pending_evolution_unit_id", hero)
		await _show("res://scenes/ui/EvolutionScreen.tscn")
		_walk("evolution")
	var first_path: Dictionary = (root.get_node("/root/DataManager").call("get_unit", "combat").get("evolution_paths") as Array)[0]
	(gs.get("unit_evolutions") as Dictionary)["combat"] = str(first_path.get("name", ""))
	gs.set("pending_evolution_unit_id", "combat")
	await _show("res://scenes/ui/EvolutionScreen.tscn")
	_walk("directive")

	for entry in [["reward", "res://scenes/ui/RewardScreen.tscn"], ["route fork", "res://scenes/ui/RouteForkScreen.tscn"],
			["intercept", "res://scenes/ui/InterceptScreen.tscn"], ["run end", "res://scenes/ui/RunEndScreen.tscn"]]:
		gs.call("start_run", ["combat", "avalanche", "medic"], "facility", 424242)
		gs.call("advance_to_next_battle")
		await _show(str(entry[1]))
		_walk(str(entry[0]))

	# Unlock screen: a run end that unlocks a hero (headless forces every unlock,
	# so use a real, partly locked profile; DevContext keeps it off the player's).
	sm.set("_disk_enabled", true)
	sm.call("dev_reset_profile")
	((sm.get("data") as Dictionary)["stats"] as Dictionary)["battles_fought"] = 45
	sm.call("record_run_finished", "victory", "facility", 10)
	check(not (sm.call("check_new_unlocks") as Array).is_empty(), "unlock / run end: the profile produced no unlocks to show")
	await _show("res://scenes/ui/UnlockScreen.tscn")
	_walk("unlock / run end")
	sm.call("dev_reset_profile")
	sm.set("_disk_enabled", disk_was)

	for site in SITES.keys():
		var seen: int = (_seen.get(site, {}) as Dictionary).size()
		check(seen >= int(SITES[site]), "%s: saw %d different portrait(s), expected at least %d - the sweep is not reaching this screen" % [site, seen, int(SITES[site])])
	if _verbose:
		for site in _frames.keys():
			print("[PORTRAIT_FRAME] %s: %d different portrait(s), frames %s" % [site, (_seen[site] as Dictionary).size(), str((_frames[site] as Dictionary).keys())])
	if failures.is_empty():
		print("[PORTRAIT_FRAME] PASS (%d portraits measured on %d sites, one window aspect %.3f)" % [_measured, SITES.size(), _aspect])
	else:
		for f in failures:
			print("[PORTRAIT_FRAME] FAIL - %s" % f)
	quit(0 if failures.is_empty() else 1)


func _show(scene: String) -> void:
	change_scene_to_file(scene)
	await settle(12)


# Measure every visible portrait under `from` (the whole tree by default; an
# overlay passes itself so the screen under it is not counted twice).
func _walk(site: String, from: Node = null) -> void:
	if not _seen.has(site):
		_seen[site] = {}
		_frames[site] = {}
	_walk_node(from if from != null else root, site)


func _walk_node(n: Node, site: String) -> void:
	if n is TextureRect and (n as TextureRect).is_visible_in_tree() and (n as TextureRect).texture != null:
		_check_rect(n as TextureRect, site)
	for child in n.get_children(true):
		_walk_node(child, site)


func _check_rect(rect: TextureRect, site: String) -> void:
	var tex: Texture2D = rect.texture
	var section: String = str(tex.get_meta("framing_section", ""))
	var is_portrait_art: bool = PORTRAIT_SECTIONS.has(section)
	var key: String = str(tex.get_meta("framing_key", "?"))
	var helped: bool = str(rect.get_meta("framing_helper", "")) == "portrait"
	if is_portrait_art and not helped:
		check(false, "%s: %s/%s is shown without PixelUI.cover_fit_portrait (helper)" % [site, section, key])
		return
	if not helped:
		return
	(_seen[site] as Dictionary)["%s/%s" % [section, key]] = true
	_measured += 1
	var frame: Vector2 = (rect.get_parent() as Control).size if rect.get_parent() is Control else Vector2.ZERO
	(_frames[site] as Dictionary)["%dx%d" % [int(frame.x), int(frame.y)]] = true
	if frame.x < 2.0 or frame.y < 2.0:
		check(false, "%s: %s/%s has an empty frame %s" % [site, section, key, str(frame)])
		return
	# 1. window: the frame carries the region aspect, to within a rounded px.
	var off: float = minf(absf(frame.y - frame.x / _aspect), absf(frame.x - frame.y * _aspect))
	check(off <= WINDOW_TOLERANCE_PX,
		"%s: %s/%s frame is %dx%d (aspect %.3f), the portrait window is %.3f (window)" % [site, section, key, int(frame.x), int(frame.y), frame.x / frame.y, _aspect])
	# 2. art: drawn size and on-screen scale keep the texture's own aspect.
	var native: float = float(tex.get_width()) / maxf(float(tex.get_height()), 1.0)
	var scale: Vector2 = rect.get_global_transform().get_scale()
	var drawn: float = (rect.size.x * scale.x) / maxf(rect.size.y * scale.y, 0.001)
	check(absf(drawn / native - 1.0) <= ART_TOLERANCE,
		"%s: %s/%s art is drawn at aspect %.3f, its texture is %.3f (art)" % [site, section, key, drawn, native])
