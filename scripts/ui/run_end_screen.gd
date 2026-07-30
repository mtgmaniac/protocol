# Run-end screen — victory / defeat summary in the Direction-05 DT language.
extends Control

const VICTORY_TITLE_FONT := 108
const DEFEAT_TITLE_FONT := 150
# Kev 2026-07-10: readability pass — heads/summary/button were well below the
# phone-legibility floor (section heads rendered ~13 preview px).
const SECTION_HEAD_FONT := 48
const SUMMARY_FONT := 64
const BUTTON_FONT := 56
const BUTTON_SIZE := Vector2(360, 120)

@onready var background: ColorRect = $Background
@onready var title_label: Label = %TitleLabel
@onready var summary_label: Label = %SummaryLabel
@onready var summary_panel: PanelContainer = $Content/VBox/SummaryPanel
@onready var button_row: HBoxContainer = $Content/VBox/ButtonRow
@onready var new_run_button: Button = $Content/VBox/ButtonRow/NewRunButton


func _ready() -> void:
	# Safe area (device cutout / gesture bar): drop below the grown header band
	# and lift the bottom button row clear. Both insets are 0 on desktop
	# (no-op); the authored .tscn offsets (192 / −48) stay the base.
	var content: MarginContainer = $Content
	content.offset_top += float(PixelUI.safe_top)
	content.offset_bottom -= float(PixelUI.safe_bottom)
	# Encounter end (victory or defeat): crossfade back to loop 1.
	MusicManager.play_track(&"sci_fi_loop_1")
	MusicManager.set_combat(false)
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
		title_label.text = "OPERATION COMPLETE"
		if operation != null and operation.victory_title != "":
			title_label.text = operation.victory_title.to_upper()
		summary_label.text = "%s cleared.\n%s" % [
			operation_name,
			_run_report_text(),
		]
		if operation != null and operation.victory_subtitle != "":
			summary_label.text = "%s\n%s" % [summary_label.text, operation.victory_subtitle]
	else:
		title_label.text = "RUN FAILED"
		summary_label.text = "The squad was wiped during %s.\nOperation: %s\n%s" % [
			GameState.get_battle_progress_text(),
			operation_name,
			_run_report_text(),
		]

	_apply_visual_theme(victory)


# The shared compact run report — identical rows on victory and defeat (the
# defeat screen's old structure is the template; victory folds progress into
# its "cleared" line, defeat into its "wiped during" line, so the block itself
# never repeats the battle count).
func _run_report_text() -> String:
	var lines: Array = []
	if GameState.last_run_result == "victory":
		lines.append(GameState.get_battle_progress_text())
	lines.append("Duration: %s | Turns: %d" % [
		_format_duration(GameState.run_duration_secs()),
		GameState.run_total_turns,
	])
	lines.append(GameState.get_inventory_summary())
	lines.append("Fallen: %s" % _fallen_heroes_text())
	return "\n".join(lines)


func _fallen_heroes_text() -> String:
	if GameState.run_hero_deaths.is_empty():
		return "none"
	var names: Array = []
	for unit_id in GameState.run_hero_deaths:
		var unit: Resource = DataManager.get_unit(str(unit_id))
		names.append(str(unit.get("display_name")) if unit != null else str(unit_id))
	return ", ".join(names)


func _format_duration(secs: int) -> String:
	if secs >= 3600:
		return "%dh %02dm" % [secs / 3600, (secs % 3600) / 60]
	if secs >= 60:
		return "%dm %02ds" % [secs / 60, secs % 60]
	return "%ds" % secs


# Lifetime record from the save profile — the "service record" section body (the
# "SERVICE RECORD" heading is drawn separately above the divider).
func _service_record_text() -> String:
	var stats: Dictionary = SaveManager.get_stats()
	var wins: Dictionary = stats.get("runs_won_by_op", {})
	var total_wins: int = 0
	for op_wins in wins.values():
		total_wins += int(op_wins)
	return "Runs: %d  Wins: %d  Best clear: battle %d\n20s rolled: %d  Squad deaths: %d" % [
		int(stats.get("runs_started", 0)),
		total_wins,
		int(stats.get("best_clear", 0)),
		int(stats.get("nat20s", 0)),
		int(stats.get("deaths", 0)),
	]


func _on_new_run_button_pressed() -> void:
	AudioManager.play_select()
	# Build F: anything unlocked this run end (boss relic, item gates, hero,
	# operation) gets the UNLOCKS screen on the way home — victory AND failure.
	# Nothing unlocked -> straight home, never an empty ceremony.
	if SaveManager.check_new_unlocks().is_empty():
		GameState.reset_run()
		SceneManager.go_to_unit_select()
	else:
		SceneManager.go_to_unlocks()


func _apply_visual_theme(victory: bool) -> void:
	# Result accent: teal for a win (green is HP-only now), rust for a loss.
	var accent: Color = PixelUI.BTN_TEAL_BORDER if victory else PixelUI.DT_RUST

	background.color = PixelUI.DT_FIELD_BG   # flat DT field
	# Edge vignette + faint scanlines behind the content (which we lift to the front).
	PixelUI.add_terminal_backdrop(self)
	move_child($Content, get_child_count() - 1)

	# Center the title/panel/buttons block vertically instead of pinning it to the top.
	var vbox := $Content/VBox as VBoxContainer
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 40)
	button_row.add_theme_constant_override("separation", 28)

	# Framed transmission window (result-tinted border + corner brackets).
	summary_panel.add_theme_stylebox_override("panel", PixelUI.make_hard_style(PixelUI.DT_PANEL_BG, accent, 2))
	PixelUI.add_corner_brackets(summary_panel, accent, 24.0, 3.0, 8.0)

	var title_font: int = VICTORY_TITLE_FONT if victory else DEFEAT_TITLE_FONT
	_style_label(title_label, title_font, accent)

	_add_result_banner(victory, accent)
	_build_two_section_stats(accent)

	# Single primary action (start a fresh run) = teal primary button, prefixed
	# with the swap/restart glyph (batch 181).
	new_run_button.custom_minimum_size = BUTTON_SIZE
	PixelUI.style_primary_button(new_run_button, BUTTON_FONT)
	new_run_button.icon = load(PixelUI.ICON_SWAP) as Texture2D
	new_run_button.expand_icon = true
	new_run_button.add_theme_constant_override("icon_max_width", 56)
	new_run_button.add_theme_color_override("icon_normal_color", PixelUI.BTN_PRIMARY_INK)
	new_run_button.add_theme_constant_override("h_separation", 16)


# Result illustration (victory / defeat) pinned above the title. Cover-cropped
# to a fixed banner height so the centered emblem reads at any source aspect.
func _add_result_banner(victory: bool, accent: Color) -> void:
	var path: String = "res://assets/ui/events/%s.png" % ("victory" if victory else "defeat")
	if not ResourceLoader.exists(path):
		return
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		return
	# Show the whole illustration at its own aspect (no crop), fit inside the
	# content width x a bounded height so the emblem and full scene both read.
	var max_w: float = float(ProjectSettings.get_setting("display/window/size/viewport_width", 1080)) - 2.0 * 60.0
	var frame := PixelUI.make_scene_banner(tex, max_w, 980.0, accent)
	var vbox := $Content/VBox as VBoxContainer
	vbox.add_child(frame)
	vbox.move_child(frame, 0)


# The old amber "UNLOCKED" panel lived here (heroes / operations only — boss
# relics unlocked silently). Retired in Build F: every run-end award now lands
# on the dedicated UnlockScreen (unlock_screen.gd), which also announces boss
# relics and item-gate buckets. The one-time operation-origin acknowledgement
# moved with it.


# Splits the stats panel into two divider-separated sections: THIS RUN (the run
# summary) and SERVICE RECORD (lifetime save stats).
func _build_two_section_stats(accent: Color) -> void:
	var host := summary_label.get_parent() as MarginContainer   # SummaryMargin
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 14)
	host.remove_child(summary_label)
	host.add_child(col)

	col.add_child(_make_section_head("THIS RUN", accent))
	summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_label(summary_label, SUMMARY_FONT, PixelUI.TEXT_PRIMARY)
	col.add_child(summary_label)

	var divider := ColorRect.new()
	divider.color = Color(accent.r, accent.g, accent.b, 0.5)
	divider.custom_minimum_size = Vector2(0, 2)
	col.add_child(divider)

	col.add_child(_make_section_head("SERVICE RECORD", accent))
	var record := Label.new()
	record.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	record.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	record.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	record.text = _service_record_text()
	# Lifetime stats are the retention hook here — keep them on the info floor.
	_style_label(record, maxi(SUMMARY_FONT - 6, PixelUI.FONT_INFO_MIN), PixelUI.TEXT_MUTED)
	col.add_child(record)

	# Feedback pointer — one unobtrusive sentence-case line on the info floor
	# (FEEDBACK in caps because it names the main-menu button, caps law).
	var feedback := Label.new()
	feedback.text = "Thoughts? FEEDBACK on the main menu."
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_label(feedback, PixelUI.scale_font_size(PixelUI.FONT_INFO_MIN), PixelUI.TEXT_MUTED)
	col.add_child(feedback)


func _make_section_head(text: String, accent: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(label, SECTION_HEAD_FONT, PixelUI.DT_AMBER)
	return label


func _style_label(label: Label, font_size: int, color: Color) -> void:
	PixelUI.apply_pixel_font(label)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.98))
	label.add_theme_constant_override("outline_size", 2)
