# Run-end screen. A victory is the OPERATION CLEARED screen (Kev, 2026-10-17,
# DECISIONS_RESOLVED G-76): the operation's image, a title over its sky, a
# report panel near the bottom and one CONTINUE. A defeat keeps the
# Direction-05 summary (title, banner, THIS RUN and SERVICE RECORD), unchanged.
extends Control

const DEFEAT_TITLE_FONT := 150
# Kev 2026-07-10: readability pass — heads/summary/button were well below the
# phone-legibility floor (section heads rendered ~13 preview px).
const SECTION_HEAD_FONT := 48
const SUMMARY_FONT := 64
const BUTTON_FONT := 56
const BUTTON_SIZE := Vector2(360, 120)

# The victory screen. Its image is drawn like the title's (one texel per art
# pixel, centred, the bleed canvas), through the same painter.
const ART_PAINTER := preload("res://scripts/ui/title_backdrop.gd")
## Design px from the screen edges to the victory text, panel and button.
const VICTORY_SIDE := 60
const VICTORY_BOTTOM := 48
## The title sits this far under the header, over the art's sky.
const VICTORY_TITLE_TOP := 96
const VICTORY_BUTTON_FONT := 64

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
	# The run's last screen keeps the in-operation header (ui-cleanup); its
	# buttons stay inert (this screen binds none of them). It also sets
	# PixelUI.ENCOUNTER_ACCENT to this operation's color.
	PersistentHeader.clear_battle_actions()
	if GameState.tutorial_mode:
		PersistentHeader.set_run_active(false)
	else:
		PersistentHeader.show_operation(GameState.selected_operation_id, GameState.current_battle, GameState.total_battles)

	var operation: OperationData = DataManager.get_operation(GameState.selected_operation_id) as OperationData
	var operation_name: String = GameState.selected_operation_id
	if operation != null:
		operation_name = operation.display_name

	var victory := GameState.last_run_result == "victory"
	AudioManager.play_sfx("victory" if victory else "failure")
	background.color = PixelUI.UI_BG
	if victory:
		_build_victory(operation, operation_name)
		return
	title_label.text = "RUN FAILED"
	summary_label.text = "The squad was wiped during %s.\nOperation: %s\n%s" % [
		GameState.get_battle_progress_text(),
		operation_name,
		_run_report_text(),
	]
	_apply_defeat_theme()


# ── Victory: OPERATION CLEARED ───────────────────────────────────────────────

func _build_victory(operation: OperationData, operation_name: String) -> void:
	# The defeat layout is not used.
	$Content.visible = false
	var painter: Control = ART_PAINTER.new()
	painter.set("image_path", operation.victory_backdrop if operation != null else "")
	var art: SubViewportContainer = PixelUI.make_art_grid_view(painter, "VictoryBackdrop")
	add_child(art)
	move_child(art, background.get_index() + 1)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Top: the title and the operation's name, over the art's sky.
	var top := VBoxContainer.new()
	top.name = "VictoryTitle"
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", PixelUI.GAP)
	add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = VICTORY_SIDE
	top.offset_right = -VICTORY_SIDE
	top.offset_top = PersistentHeader.band_height() + VICTORY_TITLE_TOP
	var title := Label.new()
	title.name = "ClearedLabel"
	title.text = "OPERATION CLEARED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelUI.apply_type(title, PixelUI.TYPE_HEADER, PixelUI.CHROME)
	top.add_child(title)
	var op_label := Label.new()
	op_label.name = "OperationLabel"
	op_label.text = operation_name
	op_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelUI.apply_type(op_label, PixelUI.TYPE_LABEL, PixelUI.ENCOUNTER_ACCENT)
	_outline(op_label)
	top.add_child(op_label)

	# Bottom: the report panel, then the one primary action.
	var bottom := VBoxContainer.new()
	bottom.name = "VictoryReport"
	bottom.add_theme_constant_override("separation", PixelUI.GAP * 2)
	add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.offset_left = VICTORY_SIDE
	bottom.offset_right = -VICTORY_SIDE
	bottom.offset_top = 0
	bottom.offset_bottom = -(VICTORY_BOTTOM + PixelUI.safe_bottom)
	bottom.add_child(_victory_report_panel(operation))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_child(row)
	var button := Button.new()
	button.name = "ContinueButton"
	button.text = "CONTINUE"
	button.custom_minimum_size = BUTTON_SIZE
	PixelUI.style_ui_primary_button(button, VICTORY_BUTTON_FONT)   # the screen's primary
	button.pressed.connect(_on_new_run_button_pressed)
	row.add_child(button)


func _victory_report_panel(operation: OperationData) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "ReportPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", PixelUI.victory_report_style())
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", PixelUI.GAP)
	panel.add_child(col)
	var boss := Label.new()
	boss.name = "BossLabel"
	boss.text = "%s DESTROYED" % _boss_name(operation)
	boss.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	PixelUI.apply_type(boss, PixelUI.TYPE_LABEL, PixelUI.ENCOUNTER_ACCENT)
	col.add_child(boss)
	var divider := ColorRect.new()
	divider.color = PixelUI.UI_LINE
	divider.custom_minimum_size = Vector2(0, PixelUI.MIN_STROKE)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(divider)
	for entry: Array in _victory_rows():
		var line := HBoxContainer.new()
		var key := Label.new()
		key.text = str(entry[0])
		key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		PixelUI.apply_type(key, PixelUI.TYPE_LABEL, PixelUI.CHROME_DIM)
		line.add_child(key)
		var value := Label.new()
		value.text = str(entry[1])
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		PixelUI.apply_type(value, PixelUI.TYPE_NUMERAL, PixelUI.CHROME)
		line.add_child(value)
		col.add_child(line)
	return panel


## The report rows: stats the run already tracks (GameState), nothing new.
## Battles won: the battle the run ended on (all of them on a clear).
## Survivors: heroes standing at the final battle's end (deaths_last_battle).
## XP earned: the squad's run XP (unit_xp, reset at start_run).
## Relics: held at the end (a Starting Directive's relic included).
## Turns and time: the run report's totals (run_total_turns, the wall clock).
func _victory_rows() -> Array:
	var squad: Array = GameState.selected_units
	var standing: int = 0
	var xp: int = 0
	for unit_id_variant in squad:
		var unit_id: String = str(unit_id_variant)
		if not GameState.deaths_last_battle.has(unit_id):
			standing += 1
		xp += GameState.get_unit_xp(unit_id)
	return [
		["BATTLES WON", "%d" % GameState.current_battle],
		["SURVIVORS", "%d / %d" % [standing, squad.size()]],
		["XP EARNED", "%d" % xp],
		["RELICS", "%d" % GameState.relics.size()],
		["TURNS", "%d" % GameState.run_total_turns],
		["TIME", _format_duration(GameState.run_duration_secs())],
	]


## The operation boss's name: the unit with a standing rule in the last battle.
func _boss_name(operation: OperationData) -> String:
	if operation == null or operation.battles.is_empty():
		return "BOSS"
	var names: Array = (operation.battles[operation.battles.size() - 1] as Dictionary).get("enemy_names", [])
	var bosses: Array = GameState.boss_names_in(names)
	return str(bosses[0]) if not bosses.is_empty() else "BOSS"


# A dark edge for m5x7 text over the art (Battle Block roles get theirs from
# apply_type).
func _outline(label: Label) -> void:
	label.add_theme_color_override("font_outline_color", PixelUI.INK_OUTLINE)
	label.add_theme_constant_override("outline_size", PixelUI.MIN_STROKE)


# ── Defeat ───────────────────────────────────────────────────────────────────

# The shared compact run report (the defeat screen's THIS RUN block). Progress
# is in its "wiped during" line, so the block never repeats the battle count.
func _run_report_text() -> String:
	var lines: Array = []
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


func _apply_defeat_theme() -> void:
	# ui-unify: a loss is the warning amber.
	var accent: Color = PixelUI.WARNING

	# Edge vignette + faint scanlines behind the content (which we lift to the front).
	PixelUI.add_terminal_backdrop(self)
	move_child($Content, get_child_count() - 1)

	# Center the title/panel/buttons block vertically instead of pinning it to the top.
	var vbox := $Content/VBox as VBoxContainer
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", PixelUI.GAP)
	button_row.add_theme_constant_override("separation", 28)

	# Framed transmission window (result-tinted border + corner brackets).
	summary_panel.add_theme_stylebox_override("panel", PixelUI.make_hard_style(PixelUI.UI_PANEL, accent.darkened(0.3), PixelUI.MIN_STROKE))
	PixelUI.add_corner_brackets(summary_panel, accent, 24.0, 3.0, 8.0)

	_style_label(title_label, DEFEAT_TITLE_FONT, accent.lightened(0.3))
	PixelUI.apply_type(title_label, PixelUI.TYPE_DISPLAY)

	_add_result_banner(accent)
	_build_two_section_stats(accent)

	# Continue is centered text, matching the unlock screen's primary action.
	new_run_button.custom_minimum_size = BUTTON_SIZE
	PixelUI.style_ui_primary_button(new_run_button, BUTTON_FONT)   # the screen's primary
	new_run_button.icon = null


# Defeat illustration pinned above the title. Cover-cropped to a fixed banner
# height so the centered emblem reads at any source aspect.
func _add_result_banner(accent: Color) -> void:
	var path: String = "res://assets/ui/events/defeat.png"
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
	col.add_theme_constant_override("separation", 16)
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
	_style_label(record, maxi(SUMMARY_FONT - 6, PixelUI.FONT_INFO_MIN), PixelUI.CHROME)
	col.add_child(record)

	# Feedback pointer — one unobtrusive sentence-case line on the info floor
	# (FEEDBACK in caps because it names the main-menu button, caps law).
	var feedback := Label.new()
	feedback.text = "Thoughts? FEEDBACK on the main menu."
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_label(feedback, PixelUI.scale_font_size(PixelUI.FONT_INFO_MIN), PixelUI.CHROME)
	col.add_child(feedback)


func _make_section_head(text: String, accent: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(label, SECTION_HEAD_FONT, PixelUI.CHROME_DIM)
	PixelUI.apply_type(label, PixelUI.TYPE_SMALL)
	return label


func _style_label(label: Label, font_size: int, color: Color) -> void:
	PixelUI.apply_pixel_font(label)
	label.add_theme_font_size_override("font_size", PixelUI.text_px(font_size))
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", PixelUI.INK_OUTLINE)
	label.add_theme_constant_override("outline_size", 2)
