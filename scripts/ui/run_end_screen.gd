# Run-end screen — victory / defeat summary in the Direction-05 DT language.
extends Control

const TITLE_FONT := 96
const SUMMARY_FONT := 40
const BUTTON_FONT := 44
const BUTTON_SIZE := Vector2(360, 120)

@onready var background: ColorRect = $Background
@onready var title_label: Label = %TitleLabel
@onready var summary_label: Label = %SummaryLabel
@onready var summary_panel: PanelContainer = $Content/VBox/SummaryPanel
@onready var button_row: HBoxContainer = $Content/VBox/ButtonRow
@onready var new_run_button: Button = $Content/VBox/ButtonRow/NewRunButton


func _ready() -> void:
	# Run is over here — blank the persistent header's run label and make its
	# buttons inert (this screen binds none of them).
	PersistentHeader.set_run_active(false)
	PersistentHeader.clear_battle_actions()

	var operation: OperationData = DataManager.get_operation(GameState.selected_operation_id) as OperationData
	var operation_name: String = GameState.selected_operation_id
	if operation != null:
		operation_name = operation.display_name

	var victory := GameState.last_run_result == "victory"
	if victory:
		title_label.text = "Operation Complete"
		if operation != null and operation.victory_title != "":
			title_label.text = operation.victory_title
		summary_label.text = "%s cleared.\n%s\n%s" % [
			operation_name,
			GameState.get_battle_progress_text(),
			GameState.get_inventory_summary(),
		]
		if operation != null and operation.victory_subtitle != "":
			summary_label.text = "%s\n%s" % [summary_label.text, operation.victory_subtitle]
	else:
		title_label.text = "Run Failed"
		summary_label.text = "The squad was wiped during %s.\nOperation: %s\n%s" % [
			GameState.get_battle_progress_text(),
			operation_name,
			GameState.get_inventory_summary(),
		]

	_apply_visual_theme(victory)


func _on_new_run_button_pressed() -> void:
	AudioManager.play_select()
	GameState.reset_run()
	SceneManager.go_to_unit_select()


func _apply_visual_theme(victory: bool) -> void:
	# Result accent: green for a win, rust for a loss.
	var accent: Color = PixelUI.DT_ROLL_LIGHT if victory else PixelUI.DT_RUST

	background.color = Color(0.055, 0.070, 0.095, 1.0)   # flat DT field

	# Center the title/panel/buttons block vertically instead of pinning it to the top.
	var vbox := $Content/VBox as VBoxContainer
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 40)
	button_row.add_theme_constant_override("separation", 28)

	# Hard-square DT panel, border tinted by the result.
	var panel_style: StyleBoxFlat = PixelUI.make_hard_style(PixelUI.DT_TRAY_BG, accent, 4)
	summary_panel.add_theme_stylebox_override("panel", panel_style)

	_style_label(title_label, TITLE_FONT, accent)
	_style_label(summary_label, SUMMARY_FONT, PixelUI.TEXT_PRIMARY)

	# Single primary action (start a fresh run) = green commit button.
	_style_button(new_run_button, PixelUI.DT_ROLL_BG, PixelUI.DT_ROLL_LIGHT, PixelUI.DT_ROLL_TEXT)


func _style_label(label: Label, font_size: int, color: Color) -> void:
	PixelUI.apply_pixel_font(label)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.98))
	label.add_theme_constant_override("outline_size", 2)


func _style_button(button: Button, fill: Color, border: Color, text_color: Color) -> void:
	button.custom_minimum_size = BUTTON_SIZE
	PixelUI.style_button(button, fill, border, BUTTON_FONT)
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_pressed_color", text_color)
	button.add_theme_color_override("font_focus_color", text_color)
