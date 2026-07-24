# Splash / main menu — the app's boot scene. Animated title logo, a big BEGIN (battle
# Roll-button styling) into the squad picker, and a smaller TUTORIAL button that launches
# the rigged onboarding encounter as a replay. First-run choice (Kev 2026-07-21):
# when SaveManager.tutorial_done is unset, BEGIN raises a one-question overlay —
# RUN TUTORIAL or SKIP — and either path sets the flag and continues into the squad
# picker. Built in code (matching the rest of the UI) over a dark field; the buttons
# stay dark until the logo's boot-in finishes.
extends Control

const TITLE_LOGO_SCENE := preload("res://scenes/ui/TitleLogo.tscn")
const BEGIN_SIZE := Vector2(640, 136)
const BEGIN_FONT := 52
const TUTORIAL_SIZE := Vector2(420, 92)
const TUTORIAL_FONT := 34
# First-run choice overlay (question card after the first BEGIN).
const PROMPT_WIDTH := 780.0
const PROMPT_PAD := 36
const PROMPT_TITLE_FONT := 46
const PROMPT_BODY_FONT := 36
const PROMPT_BUTTON_SIZE := Vector2(560, 112)
const PROMPT_BUTTON_FONT := 40
const PROMPT_SKIP_FONT := 30

var _logo: Control
var _begin_button: Button
var _tutorial_button: Button


func _ready() -> void:
	# Boot → title: loop 1 starts here and won't restart on the way to deploy.
	MusicManager.play_track(&"sci_fi_loop_1")
	MusicManager.set_combat(false)
	# Header carries no run on the splash.
	if is_instance_valid(PersistentHeader):
		PersistentHeader.set_run_active(false)
	# Web: precompile the dice WebGL programs while the player reads the menu
	# (once per session — DiceTray3D gates internally). Deferred so the menu's
	# own first paint isn't sharing frames with the compile hitches.
	if OS.has_feature("web"):
		_start_web_dice_warmup.call_deferred()

	var bg := ColorRect.new()
	bg.color = PixelUI.DT_FIELD_BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Side margins so the wide logo always fits the screen width.
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 80)
	margin.add_theme_constant_override("margin_right", 80)
	margin.add_theme_constant_override("margin_top", 60)
	margin.add_theme_constant_override("margin_bottom", 60)
	add_child(margin)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 48)
	margin.add_child(col)

	# Fixed-height box, full bounded width; the logo scales to fit (keeps aspect, centered).
	_logo = TITLE_LOGO_SCENE.instantiate()
	_logo.custom_minimum_size = Vector2(0, 300)
	_logo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(_logo)

	var begin := Button.new()
	begin.text = "BEGIN"
	begin.custom_minimum_size = BEGIN_SIZE
	begin.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	PixelUI.style_primary_button(begin, BEGIN_FONT)
	begin.pressed.connect(_on_begin_pressed)
	col.add_child(begin)
	_begin_button = begin

	var tutorial := Button.new()
	# Plain secondary button — opt-in and always replayable. (No completed-state
	# checkmark; it stays a neutral TUTORIAL button whether or not it's been run.)
	tutorial.text = "TUTORIAL"
	tutorial.custom_minimum_size = TUTORIAL_SIZE
	tutorial.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	PixelUI.style_button(tutorial, PixelUI.BG_PANEL_ALT, PixelUI.LINE_DIM, TUTORIAL_FONT)
	tutorial.add_theme_color_override("font_color", PixelUI.TEXT_MUTED)
	tutorial.pressed.connect(_on_tutorial_pressed)
	col.add_child(tutorial)
	_tutorial_button = tutorial

	# Buttons arrive only after the reactor ignites.
	begin.disabled = true
	begin.modulate.a = 0.0
	tutorial.disabled = true
	tutorial.modulate.a = 0.0
	# Last child on purpose: the stamp must paint over the full-rect background.
	_add_version_stamp()
	_logo.boot_in()
	await _logo.boot_finished
	if not is_inside_tree():
		return
	var fade := create_tween()
	fade.set_parallel(true)
	fade.tween_property(begin, "modulate:a", 1.0, 0.25)
	fade.tween_property(tutorial, "modulate:a", 1.0, 0.25)
	begin.disabled = false
	tutorial.disabled = false


func _on_begin_pressed() -> void:
	# Locked during the flare so a double-tap can't fire the transition twice.
	_begin_button.disabled = true
	_tutorial_button.disabled = true
	AudioManager.play_select()
	_logo.flare_out()
	await _logo.flare_finished
	if not is_inside_tree():
		return
	# First-run choice (Kev 2026-07-21, revised same day: no mid-drill Skip
	# button — the choice happens HERE, once, after the first BEGIN): a profile
	# that has never completed or skipped the drill gets one question — run the
	# tutorial, or head straight in. Unmissable, no menu discovery required.
	# Deleting the user:// save re-triggers first-run behavior (the intended
	# reset path).
	if not SaveManager.is_tutorial_done():
		_show_first_run_prompt()
		return
	SceneManager.go_to_unit_select()


func _on_tutorial_pressed() -> void:
	AudioManager.play_select()
	GameState.start_tutorial_run()
	SceneManager.go_to_battle()


# Web-only (no-op elsewhere and after the first run): a tiny hidden DiceTray3D
# renders every dice material variant so WebGL program compilation happens here,
# spread across menu frames, instead of freezing battle entry (~1.3s measured).
# The tray is 64px, alpha-0 and mouse-ignoring — never visible, no layout shift
# (added directly to the scene root, not a container). If the player enters a
# battle before it finishes, the tray dies with the menu and the warm-up's
# start-set gate keeps it from ever running twice.
# Bottom-corner version stamp — read from ProjectSettings (project.godot
# config/version is the single source; never hardcode the string). Nominal 24 →
# rendered 32, the smallest crisp m5x7 rung: the stamp is chrome, not
# player-read copy, sized below the ACCENT floor by ruling (Kev 2026-07-24).
# Overlay label on the scene root (not the layout column) — zero layout shift.
# Margins add the live safe-area insets so the stamp clears the mobile-web
# floors (bottom 48 / left 24) instead of sitting under the corner radius.
func _add_version_stamp() -> void:
	var stamp := Label.new()
	stamp.text = str(ProjectSettings.get_setting("application/config/version", ""))
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUI.style_label(stamp, 24, PixelUI.INSPECT_TEXT_DIM, 0)
	stamp.anchor_left = 0.0
	stamp.anchor_right = 0.0
	stamp.anchor_top = 1.0
	stamp.anchor_bottom = 1.0
	stamp.grow_horizontal = Control.GROW_DIRECTION_END
	stamp.grow_vertical = Control.GROW_DIRECTION_BEGIN
	stamp.offset_left = 24.0 + float(PixelUI.safe_left)
	stamp.offset_bottom = -(16.0 + float(PixelUI.safe_bottom))
	stamp.offset_top = stamp.offset_bottom - 44.0
	add_child(stamp)


func _start_web_dice_warmup() -> void:
	if not is_inside_tree():
		return
	var tray := DiceTray3D.new()
	tray.size = Vector2(64, 64)
	add_child(tray)
	await tray.warm_up_web_pipelines()
	if is_instance_valid(tray):
		tray.queue_free()


# ── First-run choice overlay ──────────────────────────────────────────────────
# One modal question over the darkened splash. RUN TUTORIAL enters the drill
# with the continue flag set (TutorialController._finish → squad picker); SKIP
# sets the SAME tutorial_done flag as completing (one flag, two paths in) and
# heads straight into the squad picker. Neither path returns here.
func _show_first_run_prompt() -> void:
	var scrim := PixelUI.make_modal_scrim(0.78, true)
	add_child(scrim)

	var panel := PanelContainer.new()
	PixelUI.style_panel(panel, PixelUI.BG_PANEL, PixelUI.LINE_BRIGHT, 3)
	panel.custom_minimum_size = Vector2(PROMPT_WIDTH, 0)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)

	var pad := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		pad.add_theme_constant_override(side, PROMPT_PAD)
	panel.add_child(pad)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 28)
	pad.add_child(box)

	var title := Label.new()
	title.text = "FIRST TIME?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelUI.style_label(title, PROMPT_TITLE_FONT, PixelUI.DT_CYAN_BRIGHT, 3)
	box.add_child(title)

	var body := Label.new()
	body.text = "This is your first time playing - want to run the tutorial? You can replay it anytime from the Help menu."
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	PixelUI.style_body_label(body, PROMPT_BODY_FONT)
	box.add_child(body)

	var run := Button.new()
	run.text = "RUN TUTORIAL"
	run.custom_minimum_size = PROMPT_BUTTON_SIZE
	run.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	PixelUI.style_primary_button(run, PROMPT_BUTTON_FONT)
	run.pressed.connect(_on_first_run_tutorial_pressed)
	box.add_child(run)

	var skip := Button.new()
	skip.text = "SKIP TUTORIAL"
	skip.custom_minimum_size = Vector2(PROMPT_BUTTON_SIZE.x, 92)
	skip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	PixelUI.style_button(skip, PixelUI.BG_PANEL_ALT, PixelUI.LINE_DIM, PROMPT_SKIP_FONT)
	skip.add_theme_color_override("font_color", PixelUI.TEXT_MUTED)
	skip.pressed.connect(_on_first_run_skip_pressed)
	box.add_child(skip)


func _on_first_run_tutorial_pressed() -> void:
	AudioManager.play_select()
	GameState.start_tutorial_run(true)
	SceneManager.go_to_battle()


func _on_first_run_skip_pressed() -> void:
	AudioManager.play_select()
	SaveManager.mark_tutorial_done()
	SceneManager.go_to_unit_select()
