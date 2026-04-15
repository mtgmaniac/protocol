# Phase 7 run-end screen that presents a clean victory or defeat state and lets the player restart.
extends Control

@onready var background: ColorRect = $Background
@onready var title_label: Label = %TitleLabel
@onready var summary_label: Label = %SummaryLabel
@onready var summary_panel: PanelContainer = $Content/VBox/SummaryPanel
@onready var new_run_button: Button = $Content/VBox/ButtonRow/NewRunButton
@onready var return_to_menu_button: Button = $Content/VBox/ButtonRow/ReturnToMenuButton


func _ready() -> void:
	_apply_visual_theme()
	var operation: OperationData = DataManager.get_operation(GameState.selected_operation_id) as OperationData
	var operation_name: String = GameState.selected_operation_id
	if operation != null:
		operation_name = operation.display_name

	if GameState.last_run_result == "victory":
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


func _on_new_run_button_pressed() -> void:
	GameState.reset_run()
	SceneManager.go_to_unit_select()


func _on_return_to_menu_button_pressed() -> void:
	GameState.reset_run()
	SceneManager.go_to_unit_select()


func _apply_visual_theme() -> void:
	background.color = PixelUI.BG_DARK
	PixelUI.style_panel(summary_panel, PixelUI.BG_PANEL, PixelUI.LINE_DIM, 2, 3)
	PixelUI.style_label(title_label, 42, PixelUI.GOLD_ACCENT, 2)
	PixelUI.style_label(summary_label, 24, PixelUI.TEXT_PRIMARY, 2)
	PixelUI.style_button(new_run_button, PixelUI.BG_PANEL_ALT, PixelUI.LINE_BRIGHT, 20)
	PixelUI.style_button(return_to_menu_button, PixelUI.BG_PANEL_ALT, PixelUI.LINE_DIM, 20)
