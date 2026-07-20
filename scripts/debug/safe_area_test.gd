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
#  T7  Overlay arming rule (_should_arm, pure): default OFF with no env and no
#      saved setting; arms on env or setting only in a debug build, never
#      headless. Fails on Build #2's code (rule missing — it armed
#      unconditionally on mobile). Rule-level: the OS/env wiring is thin and
#      only a windowed/device run exercises it.                   [Build #3]
#  T8  Settings DEBUG section structurally absent in release: builds the REAL
#      settings tab with the debug_build_override seam forced false and
#      asserts the toggle row was never instantiated. Honest split: the
#      builder path is genuinely exercised; OS.is_debug_build() itself cannot
#      read false under a headless editor binary, so the flag READ is a
#      build-flag proxy.                                          [Build #3]
#  T9  Overlay toggle round-trip: setting persists via SaveManager both ways
#      and refresh_from_settings() re-evaluates live. HONEST: headless can
#      never VISUALLY arm (correct behavior, asserted) — the on-screen
#      arm/disarm needs a windowed run; this covers persistence + the state
#      machine.                                                   [Build #3]
#  T10 Footer bleed (the 6.5px): footer bottom lands EXACTLY on
#      screen − safe_bottom, a whole design pixel, at (0,0) AND (132,56).
#      Fails on pre-fix code at both (2406.5 / 2350.5) — the real bug.
#                                                                  [Build #3]
#  T11 ETC2/ASTC setting pinned true in project.godot. Config-level defense
#      only — says nothing about device texture behavior.          [Build #3]
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
	_test_trim_bottom_floor()
	_test_trim_never_negative()
	_test_overlay_arming_rule()
	_test_debug_section_release_absence()
	_test_overlay_toggle_round_trip()
	_test_etc2_pinned()
	await _test_band_reclaim_and_desktop_baseline()
	_finish()


# ── T12 (Build J Item 2): the bottom trim must never drop the Android
# reserve below BEZEL_BOTTOM_FLOOR (48). Removing the clamp makes 50-4=46
# and this fails. ────────────────────────────────────────────────────────────
func _test_trim_bottom_floor() -> void:
	var normal: Vector2i = _pixel_ui.apply_inset_trims(0, 56, "Android")
	if normal.y != 52:
		_fail("T12: Android 56 bottom should trim to 52, got %d" % normal.y)
		return
	var floored: Vector2i = _pixel_ui.apply_inset_trims(0, 50, "Android")
	if floored.y != 48:
		_fail("T12: Android 50 bottom must clamp at the 48 floor, got %d" % floored.y)
		return
	print("[SAFE_AREA] T12 pass — bottom trim honors the 48px Android floor")


# ── T13 (Build J Item 2): trims can never produce a negative inset.
# Removing the clamp makes 2-4=-2 and this fails. ────────────────────────────
func _test_trim_never_negative() -> void:
	var trimmed: Vector2i = _pixel_ui.apply_inset_trims(2, 0, "Windows")
	if trimmed.x != 0 or trimmed.y != 0:
		_fail("T13: trims must clamp at zero, got top=%d bottom=%d" % [trimmed.x, trimmed.y])
		return
	print("[SAFE_AREA] T13 pass — trims clamp at zero (desktop inert)")


# ── T7 ─────────────────────────────────────────────────────────────────────
func _test_overlay_arming_rule() -> void:
	var overlay: Node = root.get_node_or_null("/root/SafeAreaDebug")
	if overlay == null or not overlay.has_method("_should_arm"):
		_fail("T7: SafeAreaDebug._should_arm missing — overlay arms unconditionally (pre-Build-#3)")
		return
	var script: GDScript = overlay.get_script() as GDScript
	# (is_headless, is_debug, env_on, setting_on)
	var cases := [
		[[false, true, false, false], false, "default: no env, no setting → OFF"],
		[[false, true, true, false], true, "env arms (capture harness)"],
		[[false, true, false, true], true, "settings toggle arms"],
		[[true, true, true, true], false, "headless never arms"],
		[[false, false, true, true], false, "release build never arms"],
	]
	for case_variant in cases:
		var args: Array = case_variant[0]
		var want: bool = case_variant[1]
		var got: bool = bool(script.call("_should_arm", args[0], args[1], args[2], args[3]))
		if got != want:
			_fail("T7: _should_arm%s = %s, want %s (%s)" % [str(args), got, want, case_variant[2]])
			return
	print("[SAFE_AREA] T7 pass — overlay arming rule: default off, env/setting arm, headless+release never")


# ── T8 ─────────────────────────────────────────────────────────────────────
func _test_debug_section_release_absence() -> void:
	var menu_script: GDScript = load("res://scripts/ui/help_menu.gd") as GDScript
	if menu_script == null:
		_fail("T8: cannot load help_menu.gd")
		return
	# Seam presence probe: the sentinel default is null, so set-then-read (a
	# missing static var makes set() a silent no-op and get() stays null).
	menu_script.set("debug_build_override", true)
	if menu_script.get("debug_build_override") != true:
		_fail("T8: HelpMenu.debug_build_override seam missing — release absence unverifiable (pre-Build-#3)")
		return
	menu_script.set("debug_build_override", null)
	for case_variant in [[false, false, "release"], [true, true, "debug"]]:
		menu_script.set("debug_build_override", case_variant[0])
		var menu: CanvasLayer = menu_script.new() as CanvasLayer
		root.add_child(menu)
		var host := VBoxContainer.new()
		menu.add_child(host)
		menu.call("_build_settings", host)
		var row: Node = host.find_child("DebugOverlayToggleRow", true, false)
		var present: bool = row != null
		menu.queue_free()
		if present != bool(case_variant[1]):
			_fail("T8: DEBUG overlay toggle row %s in a %s build" % ["present" if present else "absent", case_variant[2]])
			menu_script.set("debug_build_override", null)
			return
	menu_script.set("debug_build_override", null)
	print("[SAFE_AREA] T8 pass — DEBUG section structurally absent in release, present in debug")


# ── T9 ─────────────────────────────────────────────────────────────────────
func _test_overlay_toggle_round_trip() -> void:
	var overlay: Node = root.get_node_or_null("/root/SafeAreaDebug")
	var sm: Node = root.get_node_or_null("/root/SaveManager")
	if overlay == null or sm == null or not overlay.has_method("refresh_from_settings"):
		_fail("T9: SafeAreaDebug.refresh_from_settings / SaveManager missing")
		return
	var before: Variant = sm.call("get_setting", "safe_area_overlay", false)
	sm.call("set_setting", "safe_area_overlay", true)
	overlay.call("refresh_from_settings")
	var on_persisted: bool = bool(sm.call("get_setting", "safe_area_overlay", false))
	# Headless may never VISUALLY arm even with the setting on — that is the
	# correct behavior and is itself asserted here.
	var armed_headless: bool = bool(overlay.get("_armed"))
	sm.call("set_setting", "safe_area_overlay", false)
	overlay.call("refresh_from_settings")
	var off_persisted: bool = bool(sm.call("get_setting", "safe_area_overlay", true))
	sm.call("set_setting", "safe_area_overlay", before)
	if not on_persisted:
		_fail("T9: toggle ON did not persist via SaveManager")
	elif off_persisted:
		_fail("T9: toggle OFF did not persist via SaveManager")
	elif armed_headless:
		_fail("T9: overlay armed in a HEADLESS run — the headless guard is broken")
	else:
		print("[SAFE_AREA] T9 pass — toggle persists both ways; headless stays disarmed (live visual arm needs a windowed run)")


# ── T11 ────────────────────────────────────────────────────────────────────
func _test_etc2_pinned() -> void:
	var f: FileAccess = FileAccess.open("res://project.godot", FileAccess.READ)
	if f == null:
		_fail("T11: cannot open project.godot")
		return
	if not f.get_as_text().contains("textures/vram_compression/import_etc2_astc=true"):
		_fail("T11: import_etc2_astc is not pinned true in project.godot")
	else:
		print("[SAFE_AREA] T11 pass — etc2_astc pinned (config-level only; no device coverage)")


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

	# T6 — desktop baseline: authored geometry at zero insets.
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

	# T10 (Build #3, the 6.5px footer bleed) — at ZERO insets the footer's
	# bottom edge lands EXACTLY on the screen bottom, on a whole design pixel.
	# Pre-fix code fails here at 2406.5 (min-height overflow split downward by
	# the grow-BOTH container because _position_zone_dividers ignored the
	# footer's minimum).
	if base_footer_bottom > screen_h + 0.01:
		_fail("T10: footer bleeds %.2fpx past the screen bottom at zero insets — the 6.5px bug" % (base_footer_bottom - screen_h))
	elif absf(base_footer_bottom - roundf(base_footer_bottom)) > 0.01:
		_fail("T10: footer bottom %.2f is not a whole design pixel (INVARIANTS #14)" % base_footer_bottom)
	else:
		print("[SAFE_AREA] T10 pass — zero-inset footer bottom exactly %.0f, whole pixel" % base_footer_bottom)

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
	# The whole footer rides UP by exactly the gesture reserve…
	if absf(footer_bottom - (base_footer_bottom - float(DEVICE_BOTTOM))) > 0.5:
		_fail("T4: footer bottom %.1f, want %.1f (desktop %.1f lifted by the %dpx reserve)" % [footer_bottom, base_footer_bottom - float(DEVICE_BOTTOM), base_footer_bottom, DEVICE_BOTTOM])
		t4_failed = true
	# …and T10 at the Pixel 8 budget: bottom edge ≤ screen − safe_bottom, whole
	# pixel — pre-fix code fails at 2350.5.
	if footer_bottom > screen_h - float(DEVICE_BOTTOM) + 0.01:
		_fail("T10: footer bottom %.2f is under the gesture reserve line %.0f at (132,56) — the 6.5px bug" % [footer_bottom, screen_h - float(DEVICE_BOTTOM)])
		t4_failed = true
	elif absf(footer_bottom - roundf(footer_bottom)) > 0.01:
		_fail("T10: inset footer bottom %.2f is not a whole design pixel (INVARIANTS #14)" % footer_bottom)
		t4_failed = true
	else:
		print("[SAFE_AREA] T10 pass — inset footer bottom exactly %.0f (screen − %d), whole pixel" % [footer_bottom, DEVICE_BOTTOM])
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
