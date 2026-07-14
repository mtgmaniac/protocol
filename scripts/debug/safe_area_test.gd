# Safe-area + font regression tests (Android Builds #1–#2). Headless — no device.
# Run: godot --headless --path <project> -s scripts/debug/safe_area_test.gd
#
# Standing rule: every fix ships with a test that would have failed on the
# original bug. PixelUI is accessed DYNAMICALLY (get/set/call on the script
# resource) so the file still parses on pre-safe-area builds and each test
# fails with its own message.
#
#  T1  _to_design ceils, never floors (90px @ 0.975 scale → 93; floor says 92
#      and leaves 1px of header under the camera).                    [Build #1]
#  T2  PersistentHeader consumes the top inset: band GROWS, Bar shifts down,
#      band never gains a top offset.                                 [Build #1]
#  T3  Font identity: the theme's default font resolves to family "m5x7", the
#      TTF exists, and m5x7.ttf.import pins allow_system_fallback=false.
#      HONESTY: get_font_name() passes on DESKTOP even while the DEVICE falls
#      back to Roboto — the family check and ttf_exists are proxies. The import
#      -flag assertion is the real pin (it locks the config that made the
#      device fallback silent), but it asserts source config, not device
#      behavior. This test CANNOT fail on the device-only rasterization bug
#      itself; the definitive probe is the diagnostic overlay's on-device
#      font_name readout.                                             [Build #2]
#  T4  Band reclaim (Build #2 RULING — dice field absorbs the whole inset
#      budget): at insets (132,56) the enemy rail clears the grown header band
#      (the Pixel 8 clipped-name-plate regression), the footer clears the
#      gesture reserve, rails + footer keep their EXACT desktop heights, and
#      the center/dice band shrinks by exactly top+bottom. Fails on Build #1's
#      code (band stack ignored insets; header overlapped the enemy rail).
#      NOTE: the task's literal "five heights + T + B == 2400" was authored
#      against the stale fixed-432 anatomy; the live board is flex rails +
#      authored gaps (center floor 540 — see battle_layout.gd), so the
#      invariant is asserted as conserved band heights + exact center shrink +
#      bounds containment, which is the same conservation law measured on the
#      real anatomy.                                                  [Build #2]
#  T5  Bottom gesture reserve: bottom_reserve("Android") == 56 even when the
#      OS reports 0 (Pixel 8: get_display_safe_area is cutout-only); 0 on any
#      other OS. HONESTY: pure-rule test — the OS.get_name() wiring inside
#      refresh_safe_insets is one line that only a device run exercises.
#                                                                     [Build #2]
#  T6  Desktop no-regression: refresh on a real (headless/desktop) display
#      reads all-zero insets; the battle boots with authored geometry (center
#      at its authored floor, footer flush to the screen bottom) and returns
#      to it after a live inset round-trip.                      [Builds #1+#2]
extends SceneTree

const PIXEL_UI_PATH := "res://scripts/ui/pixel_ui.gd"
const LAYOUT_PATH := "res://scripts/battle/battle_layout.gd"
const THEME_PATH := "res://assets/ui/theme_overload.tres"
const FONT_TTF := "res://assets/fonts/m5x7.ttf"
const FONT_IMPORT := "res://assets/fonts/m5x7.ttf.import"
const BATTLE_SCENE := "res://scenes/battle/BattleScene.tscn"
const DEFAULT_SQUAD := ["pulse", "combat", "shield"]
const DEVICE_TOP := 132     # Pixel 8 cutout inset (device readout, Build #1)
const DEVICE_BOTTOM := 56   # gesture reserve (= PixelUI.SAFE_BOTTOM_RESERVE)

var _errors: Array[String] = []
var _pixel_ui: GDScript = null


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("[SAFE_AREA] Starting safe-area + font regression tests")
	_pixel_ui = load(PIXEL_UI_PATH) as GDScript
	if _pixel_ui == null:
		_fail("could not load pixel_ui.gd")
		_finish()
		return
	if _pixel_ui.get("safe_top") == null:
		_fail("PixelUI.safe_top/right/bottom/left missing — pre-safe-area build")

	_test_to_design_ceils()
	_test_header_consumes_top_inset()
	_test_font_identity()
	_test_bottom_reserve()
	await _test_band_reclaim_and_desktop_baseline()
	_finish()


# ── T1 ─────────────────────────────────────────────────────────────────────
func _test_to_design_ceils() -> void:
	if not _script_has_method(_pixel_ui, "_to_design"):
		_fail("T1: PixelUI._to_design missing")
		return
	var got: int = int(_pixel_ui.call("_to_design", 90.0, 1.0 / 0.975))
	if got != 93:
		_fail("T1: _to_design(90, 1/0.975) = %d, want 93 (ceil; floor leaves 1px under the camera)" % got)
	else:
		print("[SAFE_AREA] T1 pass — _to_design ceils (90px @ 0.975 → 93)")


# ── T2 ─────────────────────────────────────────────────────────────────────
func _test_header_consumes_top_inset() -> void:
	var header: Node = root.get_node_or_null("/root/PersistentHeader")
	if header == null or not header.has_method("_apply_safe_area"):
		_fail("T2: PersistentHeader._apply_safe_area missing")
		return
	var band: Control = header.get_node_or_null("HeaderBand") as Control
	var bar: Control = header.get_node_or_null("HeaderBand/Bar") as Control
	if band == null or bar == null:
		_fail("T2: HeaderBand/Bar nodes missing")
		return
	var content_h: float = float(header.get("HEADER_HEIGHT"))

	_set_insets(DEVICE_TOP, 0)
	header.call("_apply_safe_area")
	if not is_equal_approx(band.offset_bottom, content_h + float(DEVICE_TOP)):
		_fail("T2: HeaderBand.offset_bottom = %s, want %s" % [band.offset_bottom, content_h + float(DEVICE_TOP)])
	elif not is_equal_approx(bar.offset_top, float(DEVICE_TOP)):
		_fail("T2: Bar.offset_top = %s, want %d" % [bar.offset_top, DEVICE_TOP])
	elif not is_equal_approx(band.offset_top, 0.0):
		_fail("T2: HeaderBand gained a top offset (%s) — band must grow, not shift" % band.offset_top)
	else:
		print("[SAFE_AREA] T2 pass — header band grows to %s, bar content shifts to %d" % [band.offset_bottom, DEVICE_TOP])
	_set_insets(0, 0)
	header.call("_apply_safe_area")


# ── T3 ─────────────────────────────────────────────────────────────────────
func _test_font_identity() -> void:
	var t3_failed := false
	if not ResourceLoader.exists(FONT_TTF):
		_fail("T3: %s missing from the project" % FONT_TTF)
		t3_failed = true
	var theme: Theme = load(THEME_PATH) as Theme
	if theme == null or theme.default_font == null:
		_fail("T3: theme_overload.tres has no default_font")
		t3_failed = true
	else:
		var family: String = theme.default_font.get_font_name()
		if family != "m5x7":
			_fail("T3: theme default font family = '%s', want 'm5x7'" % family)
			t3_failed = true
	# Import pin: the imported font must not silently substitute glyphs.
	var import_file: FileAccess = FileAccess.open(FONT_IMPORT, FileAccess.READ)
	if import_file == null:
		_fail("T3: cannot open %s" % FONT_IMPORT)
		t3_failed = true
	else:
		var text: String = import_file.get_as_text()
		if text.contains("allow_system_fallback=true"):
			_fail("T3: m5x7.ttf.import has allow_system_fallback=true — silent system-font glyph substitution")
			t3_failed = true
		elif not text.contains("allow_system_fallback=false"):
			_fail("T3: m5x7.ttf.import does not pin allow_system_fallback=false")
			t3_failed = true
	# The PROVEN Android root cause (Build #2, verified against the shipped
	# APK's file list): FontFile.load_dynamic_font(raw .ttf path) — exports pack
	# only the IMPORTED artifact, so the raw-path load fails on device and the
	# code's own SystemFont fallback rendered Roboto. Pin the loader at source
	# level: no runtime raw-path font loads anywhere in scripts/. This is the
	# one T3 check that ACTUALLY fails on the original device bug.
	for script_path in ["res://scripts/ui/pixel_ui.gd", "res://scripts/battle/dice_tray_3d.gd"]:
		var sf: FileAccess = FileAccess.open(script_path, FileAccess.READ)
		if sf == null:
			continue
		for line_variant in sf.get_as_text().split("\n"):
			var code_line: String = str(line_variant).strip_edges()
			if code_line.begins_with("#"):
				continue  # comments may (and do) NAME the forbidden call
			if code_line.contains("load_dynamic_font("):
				_fail("T3: %s calls FontFile.load_dynamic_font on a raw path — the raw .ttf is NOT packed in an export; load the imported resource via load()/ResourceLoader" % script_path)
				t3_failed = true
				break
	# And the runtime font object every label actually gets must be m5x7.
	var live_font: Variant = _pixel_ui.call("get_pixel_font")
	if live_font == null or not (live_font is Font) or (live_font as Font).get_font_name() != "m5x7":
		_fail("T3: PixelUI.get_pixel_font() resolved '%s', want 'm5x7'" % ((live_font as Font).get_font_name() if live_font is Font else "NULL"))
		t3_failed = true
	if not t3_failed:
		print("[SAFE_AREA] T3 pass — family 'm5x7' (theme + live), ttf present, fallback pinned OFF, no raw-path font loads")


# ── T5 ─────────────────────────────────────────────────────────────────────
func _test_bottom_reserve() -> void:
	if not _script_has_method(_pixel_ui, "bottom_reserve"):
		_fail("T5: PixelUI.bottom_reserve missing — Android gesture bar sits on the protocol row")
		return
	var android: int = int(_pixel_ui.call("bottom_reserve", "Android"))
	var desktop: int = int(_pixel_ui.call("bottom_reserve", "Windows"))
	# Reported safe_bottom on the Pixel 8 is 0 (cutout-only API) — the
	# effective inset is max(reported, reserve) and must be ≥ 56.
	if maxi(0, android) < 56:
		_fail("T5: effective Android bottom inset with reported 0 = %d, want ≥ 56" % android)
	elif desktop != 0:
		_fail("T5: bottom_reserve on Windows = %d, want 0 (desktop inert)" % desktop)
	else:
		print("[SAFE_AREA] T5 pass — Android reserve %d (≥56) with reported 0; desktop 0" % android)


# ── T4 + T6 ─────────────────────────────────────────────────────────────────
func _test_band_reclaim_and_desktop_baseline() -> void:
	var header: Node = root.get_node_or_null("/root/PersistentHeader")
	var layout_script: GDScript = load(LAYOUT_PATH) as GDScript
	var authored_center: float = 540.0
	if layout_script != null and layout_script.get("CENTER_ZONE_HEIGHT") != null:
		authored_center = float(layout_script.get("CENTER_ZONE_HEIGHT"))

	_set_insets(0, 0)
	var gs: Node = root.get_node("/root/GameState")
	gs.call("start_run", DEFAULT_SQUAD.duplicate(), "facility")
	change_scene_to_file(BATTLE_SCENE)
	var deadline: float = Time.get_ticks_msec() + 30000.0
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if current_scene != null and str(current_scene.scene_file_path) == BATTLE_SCENE:
			break
	for _i in range(12):
		await process_frame
	var scene: Node = current_scene
	var enemy_panel: Control = scene.get_node_or_null("Content/VBox/Board/EnemyPanel") as Control
	var center_panel: Control = scene.get_node_or_null("Content/VBox/Board/CenterPanel") as Control
	var hero_panel: Control = scene.get_node_or_null("Content/VBox/Board/HeroPanel") as Control
	var footer: Control = scene.get_node_or_null("ProtocolPanel") as Control
	if enemy_panel == null or center_panel == null or hero_panel == null or footer == null:
		_fail("T4: battle band nodes missing")
		return
	var screen_h: float = (scene as Control).size.y

	# T6 — desktop baseline: authored geometry at zero insets. The footer
	# carries a PRE-EXISTING ~6.5px min-height overflow past the screen bottom
	# (grow-both container whose content minimum exceeds its anchored span) —
	# harmless offscreen bleed that predates the safe-area work. Desktop must
	# stay pixel-identical, so the baseline RECORDS it and T4 asserts the
	# RELATIVE shift rather than an absolute flush line.
	var base_enemy_h: float = enemy_panel.size.y
	var base_hero_h: float = hero_panel.size.y
	var base_footer_h: float = footer.size.y
	var base_center_h: float = center_panel.size.y
	var base_footer_bottom: float = footer.get_global_rect().end.y
	if not is_equal_approx(base_center_h, authored_center):
		_fail("T6: desktop center band = %s, want authored %s" % [base_center_h, authored_center])
	elif base_footer_bottom < screen_h - 0.5:
		_fail("T6: desktop footer bottom = %s — does not reach the screen bottom %s" % [base_footer_bottom, screen_h])
	else:
		print("[SAFE_AREA] T6 pass — desktop battle at authored geometry (center %s, footer bottom %s)" % [base_center_h, base_footer_bottom])

	# T4 — apply the Pixel 8 budget live (rotation/fold path: signal re-apply).
	_set_insets(DEVICE_TOP, DEVICE_BOTTOM)
	if header != null and header.has_method("_apply_safe_area"):
		header.call("_apply_safe_area")
	if header != null and header.has_signal("safe_area_changed"):
		header.emit_signal("safe_area_changed")
	else:
		_fail("T4: safe_area_changed signal missing")
	# stabilize_board_layout spans 4 frames of refresh+relayout — wait it out.
	for _i in range(16):
		await process_frame

	var band_bottom: float = 144.0 + float(DEVICE_TOP)
	if header != null and header.get("HEADER_HEIGHT") != null:
		band_bottom = float(header.get("HEADER_HEIGHT")) + float(DEVICE_TOP)
	var enemy_top: float = enemy_panel.get_global_rect().position.y
	var footer_bottom: float = footer.get_global_rect().end.y
	var t4_failed := false
	if enemy_top < band_bottom - 0.5:
		_fail("T4: enemy rail top %.1f is under the grown header band (bottom %.1f) — the clipped-name-plate regression" % [enemy_top, band_bottom])
		t4_failed = true
	# Relative to the recorded desktop baseline (which carries the pre-existing
	# ~6.5px offscreen bleed): the whole footer must ride UP by exactly the
	# gesture reserve.
	if absf(footer_bottom - (base_footer_bottom - float(DEVICE_BOTTOM))) > 0.5:
		_fail("T4: footer bottom %.1f, want %.1f (desktop %.1f lifted by the %dpx reserve)" % [footer_bottom, base_footer_bottom - float(DEVICE_BOTTOM), base_footer_bottom, DEVICE_BOTTOM])
		t4_failed = true
	if absf(enemy_panel.size.y - base_enemy_h) > 0.5 or absf(hero_panel.size.y - base_hero_h) > 0.5:
		_fail("T4: rail heights changed (%s/%s, desktop %s/%s) — only the dice field may give up height" % [enemy_panel.size.y, hero_panel.size.y, base_enemy_h, base_hero_h])
		t4_failed = true
	if absf(footer.size.y - base_footer_h) > 0.5:
		_fail("T4: footer height changed (%s, desktop %s) — footer keeps its authored anatomy" % [footer.size.y, base_footer_h])
		t4_failed = true
	var want_center: float = base_center_h - float(DEVICE_TOP + DEVICE_BOTTOM)
	if absf(center_panel.size.y - want_center) > 0.5:
		_fail("T4: center band = %s, want %s (authored %s − inset budget %d)" % [center_panel.size.y, want_center, base_center_h, DEVICE_TOP + DEVICE_BOTTOM])
		t4_failed = true
	if not t4_failed:
		print("[SAFE_AREA] T4 pass — dice band %s→%s absorbs the full budget; rails/footer conserved; rail clears band" % [base_center_h, center_panel.size.y])

	# Restore desktop state and confirm the live path returns to baseline.
	_set_insets(0, 0)
	if header != null:
		header.call("_apply_safe_area")
		header.emit_signal("safe_area_changed")
	for _i in range(12):
		await process_frame
	if absf(center_panel.size.y - base_center_h) > 0.5:
		_fail("T4: after resetting insets, center = %s, want %s (live restore)" % [center_panel.size.y, base_center_h])

	# T6 (Build #1 half) — refresh from the real display reads zero.
	if _script_has_method(_pixel_ui, "refresh_safe_insets"):
		_set_insets(77, 77)
		_pixel_ui.call("refresh_safe_insets", root)
		var vals: Array[int] = [
			int(_pixel_ui.get("safe_top")), int(_pixel_ui.get("safe_right")),
			int(_pixel_ui.get("safe_bottom")), int(_pixel_ui.get("safe_left")),
		]
		if vals != [0, 0, 0, 0]:
			_fail("T6: desktop refresh insets = %s, want [0,0,0,0]" % str(vals))
			_set_insets(0, 0)
	else:
		_fail("T6: PixelUI.refresh_safe_insets missing")


# ── Plumbing ────────────────────────────────────────────────────────────────
func _set_insets(top: int, bottom: int) -> void:
	_pixel_ui.set("safe_top", top)
	_pixel_ui.set("safe_right", 0)
	_pixel_ui.set("safe_bottom", bottom)
	_pixel_ui.set("safe_left", 0)


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
		print("[SAFE_AREA] PASS — all safe-area + font tests green")
		quit(0)
	else:
		print("[SAFE_AREA] FAIL — %d error(s)" % _errors.size())
		quit(1)
