# Safe-area regression tests (Android Build #1). Headless — no device.
# Run: godot --headless --path <project> -s scripts/debug/safe_area_test.gd
#
# Standing rule: every fix ships with a test that would have failed on the
# original bug. All four tests below fail on the pre-safe-area build — PixelUI
# accessed DYNAMICALLY (get/set/call on the script resource, never typed
# member access) so on that build this file still PARSES and each test fails
# with its own message instead of one opaque parse error.
#
#  T1  _to_design ceils, never floors (1080×2340 phone, 0.975 scale, 90px
#      physical top cutout → 93 design px; floor/int() says 92 and leaves 1px
#      of header under the camera).
#  T2  PersistentHeader consumes the top inset: band GROWS (content height +
#      inset), Bar content shifts down. Band never gains a top offset.
#  T3  BattleScene's ProtocolMargin consumes the bottom inset ON TOP of its
#      authored 4px pad, and re-applies on safe_area_changed.
#  T4  Desktop no-regression: with no cutout data all four insets read 0 and
#      the header renders at exactly HEADER_HEIGHT (the guarantee that landing
#      this blind cannot break desktop).
extends SceneTree

const PIXEL_UI_PATH := "res://scripts/ui/pixel_ui.gd"
const BATTLE_SCENE := "res://scenes/battle/BattleScene.tscn"
const DEFAULT_SQUAD := ["pulse", "combat", "shield"]

var _errors: Array[String] = []
var _pixel_ui: GDScript = null


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("[SAFE_AREA] Starting safe-area regression tests")
	_pixel_ui = load(PIXEL_UI_PATH) as GDScript
	if _pixel_ui == null:
		_fail("could not load pixel_ui.gd")
		_finish()
		return
	if _pixel_ui.get("safe_top") == null:
		# Pre-safe-area build: report, but still run every test so each fails
		# with its own message.
		_fail("PixelUI.safe_top/right/bottom/left missing — pre-safe-area build")

	_test_to_design_ceils()
	_test_header_consumes_top_inset()
	await _test_protocol_row_consumes_bottom_inset()
	_test_desktop_no_regression()
	_finish()


# ── T1 ─────────────────────────────────────────────────────────────────────
func _test_to_design_ceils() -> void:
	if not _script_has_method(_pixel_ui, "_to_design"):
		_fail("T1: PixelUI._to_design missing")
		return
	# 1080×2340 phone → content scale 0.975 → inverse 1/0.975. A 90px physical
	# cutout must become ceil(90 / 0.975) = 93 design px; floor()/int() = 92.
	var got: int = int(_pixel_ui.call("_to_design", 90.0, 1.0 / 0.975))
	if got != 93:
		_fail("T1: _to_design(90, 1/0.975) = %d, want 93 (ceil; floor leaves 1px under the camera)" % got)
	else:
		print("[SAFE_AREA] T1 pass — _to_design ceils (90px @ 0.975 → 93)")


# ── T2 ─────────────────────────────────────────────────────────────────────
func _test_header_consumes_top_inset() -> void:
	var header: Node = root.get_node_or_null("/root/PersistentHeader")
	if header == null:
		_fail("T2: PersistentHeader autoload missing")
		return
	if not header.has_method("_apply_safe_area"):
		_fail("T2: PersistentHeader._apply_safe_area missing — pre-safe-area build")
		return
	var band: Control = header.get_node_or_null("HeaderBand") as Control
	var bar: Control = header.get_node_or_null("HeaderBand/Bar") as Control
	if band == null or bar == null:
		_fail("T2: HeaderBand/Bar nodes missing")
		return
	var content_h: float = float(header.get("HEADER_HEIGHT"))

	_set_insets(93, 0, 0, 0)
	header.call("_apply_safe_area")
	if not is_equal_approx(band.offset_bottom, content_h + 93.0):
		_fail("T2: HeaderBand.offset_bottom = %s, want %s (content %s + inset 93)" % [band.offset_bottom, content_h + 93.0, content_h])
	elif not is_equal_approx(bar.offset_top, 93.0):
		_fail("T2: Bar.offset_top = %s, want 93" % bar.offset_top)
	elif not is_equal_approx(band.offset_top, 0.0):
		_fail("T2: HeaderBand gained a top offset (%s) — band must grow, not shift, or game art shows behind the cutout" % band.offset_top)
	else:
		print("[SAFE_AREA] T2 pass — header band grows to %s, bar content shifts to 93" % band.offset_bottom)

	_set_insets(0, 0, 0, 0)
	header.call("_apply_safe_area")


# ── T3 ─────────────────────────────────────────────────────────────────────
func _test_protocol_row_consumes_bottom_inset() -> void:
	var header: Node = root.get_node_or_null("/root/PersistentHeader")
	# Boot a real battle with the inset already set, so _ready's application is
	# what's under test (not a later poke).
	_set_insets(0, 0, 48, 0)
	var gs: Node = root.get_node("/root/GameState")
	gs.call("start_run", DEFAULT_SQUAD.duplicate(), "facility")
	change_scene_to_file(BATTLE_SCENE)
	var deadline: float = Time.get_ticks_msec() + 30000.0
	while Time.get_ticks_msec() < deadline:
		await process_frame
		var scene: Node = current_scene
		if scene != null and str(scene.scene_file_path) == BATTLE_SCENE:
			break
	for _i in range(10):
		await process_frame
	var scene: Node = current_scene
	var margin: MarginContainer = scene.get_node_or_null("ProtocolPanel/ProtocolMargin") as MarginContainer if scene != null else null
	if margin == null:
		_fail("T3: ProtocolPanel/ProtocolMargin not found in battle scene")
		_set_insets(0, 0, 0, 0)
		return
	if not margin.has_theme_constant_override("margin_bottom"):
		_fail("T3: ProtocolMargin has no margin_bottom override — battle scene does not consume safe_bottom (pre-safe-area build)")
		_set_insets(0, 0, 0, 0)
		return
	var got: int = margin.get_theme_constant("margin_bottom")
	if got != 4 + 48:
		_fail("T3: ProtocolMargin margin_bottom = %d, want 52 (authored 4px pad + 48 inset)" % got)
	else:
		print("[SAFE_AREA] T3 pass — protocol row bottom pad 52 (4 + 48)")

	# Live re-apply on the header's signal (rotation / fold path).
	_set_insets(0, 0, 0, 0)
	if header != null and header.has_signal("safe_area_changed"):
		header.emit_signal("safe_area_changed")
		await process_frame
		var after: int = margin.get_theme_constant("margin_bottom")
		if after != 4:
			_fail("T3: after safe_area_changed with inset 0, margin_bottom = %d, want 4 (authored pad must survive)" % after)
		else:
			print("[SAFE_AREA] T3 pass — signal re-apply restores authored 4px pad")
	else:
		_fail("T3: PersistentHeader.safe_area_changed signal missing")


# ── T4 ─────────────────────────────────────────────────────────────────────
func _test_desktop_no_regression() -> void:
	if not _script_has_method(_pixel_ui, "refresh_safe_insets"):
		_fail("T4: PixelUI.refresh_safe_insets missing")
		return
	# Poison the values, then refresh from the real (headless/desktop)
	# DisplayServer: with a full-screen safe area and no cutouts, everything
	# must come back 0.
	_set_insets(77, 77, 77, 77)
	_pixel_ui.call("refresh_safe_insets", root)
	var vals: Array[int] = [
		int(_pixel_ui.get("safe_top")), int(_pixel_ui.get("safe_right")),
		int(_pixel_ui.get("safe_bottom")), int(_pixel_ui.get("safe_left")),
	]
	if vals != [0, 0, 0, 0]:
		_fail("T4: desktop insets = %s, want [0,0,0,0]" % str(vals))
		_set_insets(0, 0, 0, 0)
	var header: Node = root.get_node_or_null("/root/PersistentHeader")
	if header != null and header.has_method("_apply_safe_area"):
		header.call("_apply_safe_area")
		var band: Control = header.get_node_or_null("HeaderBand") as Control
		var content_h: float = float(header.get("HEADER_HEIGHT"))
		if band != null and not is_equal_approx(band.offset_bottom, content_h):
			_fail("T4: desktop HeaderBand.offset_bottom = %s, want exactly %s" % [band.offset_bottom, content_h])
			return
	if vals == [0, 0, 0, 0]:
		print("[SAFE_AREA] T4 pass — desktop reads zero insets, header at exactly 144")


# ── Plumbing ────────────────────────────────────────────────────────────────
func _set_insets(top: int, right: int, bottom: int, left: int) -> void:
	_pixel_ui.set("safe_top", top)
	_pixel_ui.set("safe_right", right)
	_pixel_ui.set("safe_bottom", bottom)
	_pixel_ui.set("safe_left", left)


func _script_has_method(script: GDScript, method_name: String) -> bool:
	if script == null:
		return false
	for m in script.get_script_method_list():
		if str(m.get("name", "")) == method_name:
			return true
	return false


func _fail(message: String) -> void:
	_errors.append(message)
	push_error("[SAFE_AREA] " + message)


func _finish() -> void:
	if _errors.is_empty():
		print("[SAFE_AREA] PASS — all 4 safe-area tests green")
		quit(0)
	else:
		print("[SAFE_AREA] FAIL — %d error(s)" % _errors.size())
		quit(1)
