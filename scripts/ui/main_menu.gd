# Splash / main menu — the app's boot scene. Logo, a big green BEGIN (battle Roll-button
# styling) into the squad picker, and a smaller TUTORIAL button that launches the rigged
# onboarding encounter. Built in code (matching the rest of the UI) over a dark field.
extends Control

const LOGO_TEXTURE := preload("res://assets/ui/logo_scifi_overload_protocol.png")
const BEGIN_SIZE := Vector2(640, 136)
const BEGIN_FONT := 52
const TUTORIAL_SIZE := Vector2(420, 92)
const TUTORIAL_FONT := 34


func _ready() -> void:
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

	var logo := TextureRect.new()
	logo.texture = LOGO_TEXTURE
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Fixed-height box, full bounded width; the logo scales to fit (keeps aspect, centered).
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(0, 300)
	logo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(logo)

	var begin := Button.new()
	begin.text = "BEGIN"
	begin.custom_minimum_size = BEGIN_SIZE
	begin.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	PixelUI.style_primary_button(begin, BEGIN_FONT)
	begin.pressed.connect(_on_begin_pressed)
	col.add_child(begin)

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


func _on_begin_pressed() -> void:
	AudioManager.play_select()
	SceneManager.go_to_unit_select()


func _on_tutorial_pressed() -> void:
	AudioManager.play_select()
	GameState.start_tutorial_run()
	SceneManager.go_to_battle()
