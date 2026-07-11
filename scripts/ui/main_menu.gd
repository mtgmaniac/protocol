# Splash / main menu — the app's boot scene. Animated title logo, a big BEGIN (battle
# Roll-button styling) into the squad picker, and a smaller TUTORIAL button that launches
# the rigged onboarding encounter. Built in code (matching the rest of the UI) over a
# dark field; the buttons stay dark until the logo's boot-in finishes.
extends Control

const TITLE_LOGO_SCENE := preload("res://scenes/ui/TitleLogo.tscn")
const BEGIN_SIZE := Vector2(640, 136)
const BEGIN_FONT := 52
const TUTORIAL_SIZE := Vector2(420, 92)
const TUTORIAL_FONT := 34

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
	SceneManager.go_to_unit_select()


func _on_tutorial_pressed() -> void:
	AudioManager.play_select()
	GameState.start_tutorial_run()
	SceneManager.go_to_battle()
