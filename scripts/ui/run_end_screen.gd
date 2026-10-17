# Run-end screen: OPERATION CLEARED or OPERATION FAILED (Kev, 2026-10-17,
# DECISIONS_RESOLVED G-76, G-78). Both results share one layout: the
# operation's image (`victory_backdrop`; a defeat draws it darkened and
# desaturated), a title over its sky, the operation's name, a report panel near
# the bottom and one CONTINUE.
extends Control

# The image is drawn like the title's (one texel per art pixel, centred, the
# bleed canvas), through the same painter.
const ART_PAINTER := preload("res://scripts/ui/title_backdrop.gd")
## Design px from the screen edges to the text, panel and button.
const SIDE := 60
const BOTTOM := 48
## The title sits this far under the header, over the art's sky.
const TITLE_TOP := 96
const BUTTON_FONT := 64
const BUTTON_SIZE := Vector2(360, 120)
## The panel's boss / wipe line and its rows (G-78): m5x7, one clean step up
## from LABEL's 64. Drawn pixel-exact through PixelUI.bind_m5x7_snap: laid out
## at font size 96, drawn so one font pixel is a whole number of screen px. On
## the phones that is 2 (360: 6 design px, 390: 5.54), at the 540 preview 3.
const REPORT_FONT_PX := Vector2(5.0, 6.0)
## The defeat panel's feedback line (SMALL, 48): one font pixel of 3 design px,
## snapped to whole screen px (360: 1, 390: 1, at 2.77 design px).
const FEEDBACK_FONT_PX := 3.0

## Every label kept on whole screen px (PixelUI.set_block_ink_snap).
var _snapped: Array[Label] = []
var _top: Control
var _body: Control
var _headline: Label
var _divider: ColorRect
## [key, value] label pairs, top to bottom.
var _rows: Array = []
var _feedback: Label = null
var _layout_queued := false

@onready var background: ColorRect = $Background


func _ready() -> void:
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
	_build(victory, operation, operation_name)


func _build(victory: bool, operation: OperationData, operation_name: String) -> void:
	var painter: Control = ART_PAINTER.new()
	painter.set("image_path", operation.victory_backdrop if operation != null else "")
	if not victory:
		# A loss reads differently: the same image, darker and grayer.
		painter.set("darken", PixelUI.DEFEAT_BACKDROP_DARKEN)
		painter.set("desaturate", PixelUI.DEFEAT_BACKDROP_DESATURATE)
	var art: SubViewportContainer = PixelUI.make_art_grid_view(painter, "ResultBackdrop")
	add_child(art)
	move_child(art, background.get_index() + 1)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Top: the title and the operation's name, over the art's sky.
	_top = Control.new()
	_top.name = "ResultTitle"
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_top)
	_top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_top.offset_left = SIDE
	_top.offset_right = -SIDE
	_top.offset_top = PersistentHeader.band_height() + TITLE_TOP
	var title := Label.new()
	title.name = "TitleLabel"
	title.text = "OPERATION CLEARED" if victory else "OPERATION FAILED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelUI.apply_type(title, PixelUI.TYPE_HEADER, PixelUI.CHROME)
	_snap(title)
	_top.add_child(title)
	var op_label := Label.new()
	op_label.name = "OperationLabel"
	op_label.text = operation_name
	op_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelUI.apply_type(op_label, PixelUI.TYPE_CARD_NAME, PixelUI.ENCOUNTER_ACCENT)
	_snap(op_label)
	_top.add_child(op_label)
	_top.resized.connect(_layout_top)

	# Bottom: the report panel, then the one primary action.
	var bottom := VBoxContainer.new()
	bottom.name = "ResultReport"
	bottom.add_theme_constant_override("separation", PixelUI.GAP * 2)
	add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.offset_left = SIDE
	bottom.offset_right = -SIDE
	bottom.offset_top = 0
	bottom.offset_bottom = -(BOTTOM + PixelUI.safe_bottom)
	bottom.add_child(_report_panel(victory, operation))
	# The block grows upward, so it is placed after the text first snaps; any
	# move re-snaps it (a moved panel is not resized, so the labels' own hooks
	# never see it).
	bottom.item_rect_changed.connect(_resnap)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_child(row)
	var button := Button.new()
	button.name = "NewRunButton"
	button.text = "CONTINUE"
	button.custom_minimum_size = BUTTON_SIZE
	PixelUI.style_ui_primary_button(button, BUTTON_FONT)   # the screen's primary
	button.pressed.connect(_on_new_run_button_pressed)
	row.add_child(button)
	_layout_top()
	_layout_body()


# The panel's content is a plain Control laid out here, not containers: a
# snapped label keeps its text origin on a whole screen px only in a plain
# Control (PixelUI.set_block_ink_snap). The FALLEN names break onto lines by
# measure, so every label's height stays exact.
func _report_panel(victory: bool, operation: OperationData) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "ReportPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", PixelUI.result_report_style())
	_body = Control.new()
	_body.name = "ReportBody"
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_body)
	_headline = Label.new()
	_headline.name = "HeadlineLabel"
	if victory:
		_headline.text = "%s DESTROYED" % _boss_name(operation)
	else:
		_headline.text = "SQUAD LOST AT BATTLE %d/%d" % [GameState.current_battle, GameState.total_battles]
	_headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_report_type(_headline, PixelUI.ENCOUNTER_ACCENT if victory else PixelUI.KW_DAMAGE)
	_body.add_child(_headline)
	_divider = ColorRect.new()
	_divider.color = PixelUI.UI_LINE
	_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(_divider)
	for entry: Array in (_victory_rows() if victory else _defeat_rows()):
		var key := Label.new()
		key.text = str(entry[0])
		_report_type(key, PixelUI.CHROME_DIM)
		_body.add_child(key)
		var value := Label.new()
		value.text = str(entry[1])
		value.set_meta("full_text", value.text)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_report_type(value, PixelUI.CHROME)
		_body.add_child(value)
		_rows.append([key, value])
	if not victory:
		# The feedback pointer, one short line above CONTINUE (FEEDBACK in caps:
		# it names the main-menu button, caps law).
		_feedback = Label.new()
		_feedback.name = "FeedbackLabel"
		_feedback.text = "Thoughts? FEEDBACK on the main menu."
		_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		PixelUI.apply_type(_feedback, PixelUI.TYPE_SMALL, PixelUI.CHROME)
		# SMALL is 48 (a 3 design px font pixel): 1 screen px per font pixel at
		# 360 already, 1.08 at 390 without the snap.
		PixelUI.bind_m5x7_snap(_feedback, FEEDBACK_FONT_PX, FEEDBACK_FONT_PX)
		_snapped.append(_feedback)
		_body.add_child(_feedback)
	_body.resized.connect(_layout_body)
	return panel


# The title block: the title, a GAP, the operation's name, centred.
func _layout_top() -> void:
	var y: float = 0.0
	for label: Node in _top.get_children():
		y = _place(label as Label, Vector2(0.0, y), _top.size.x) + PixelUI.GAP
	_top.custom_minimum_size.y = maxf(y - PixelUI.GAP, 0.0)
	_resnap()


# The report body: the headline, GAP, the divider, GAP, the rows flush (the m5x7
# line carries its own leading; a row is as tall as its wrapped value), then the
# feedback line after a GAP. The body's height follows; the bottom block grows
# up to fit it.
func _layout_body() -> void:
	_layout_queued = false
	var width: float = _body.size.x
	if width < 1.0:
		# Before the first sort: the panel's inner width at the design size.
		width = get_viewport_rect().size.x - 2.0 * SIDE - 2.0 * float(PixelUI.GAP * 2)
	var y: float = _place(_headline, Vector2.ZERO, width) + PixelUI.GAP
	_divider.position = Vector2(0.0, y)
	_divider.size = Vector2(width, PixelUI.MIN_STROKE)
	y += PixelUI.MIN_STROKE + PixelUI.GAP
	for pair: Array in _rows:
		var key := pair[0] as Label
		var value := pair[1] as Label
		var key_w: float = key.get_combined_minimum_size().x
		var key_bottom: float = _place(key, Vector2(0.0, y), key_w)
		var value_w: float = width - key_w - PixelUI.GAP * 2
		value.text = _wrap_list(str(value.get_meta("full_text")), value, value_w)
		var value_bottom: float = _place(value, Vector2(width - value_w, y), value_w)
		y = maxf(key_bottom, value_bottom)
	if _feedback != null:
		y = _place(_feedback, Vector2(0.0, y + PixelUI.GAP), width)
	_body.custom_minimum_size.y = y
	_resnap()


# A comma list broken onto lines that fit `width` (the FALLEN names); labels
# here never autowrap, so their heights stay exact.
func _wrap_list(text: String, label: Label, width: float) -> String:
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	var lines: Array[String] = []
	var line: String = ""
	for part: String in text.split(", "):
		var trial: String = part if line == "" else line + ", " + part
		if line != "" and font.get_string_size(trial.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
			lines.append(line + ",")
			line = part
		else:
			line = trial
	lines.append(line)
	return "
".join(lines)


# Puts a label at `at`, `width` wide and as tall as its text wraps; returns its
# bottom.
func _place(label: Label, at: Vector2, width: float) -> float:
	label.position = at
	label.size = Vector2(width, 0.0)
	label.size = Vector2(width, label.get_combined_minimum_size().y)
	return at.y + label.size.y


# The report's text: m5x7 caps, one font pixel on a whole number of screen px.
func _report_type(label: Label, ink: Color) -> void:
	PixelUI.apply_type(label, PixelUI.TYPE_LABEL, ink)
	PixelUI.bind_m5x7_snap(label, REPORT_FONT_PX.x, REPORT_FONT_PX.y)
	_snapped.append(label)
	label.minimum_size_changed.connect(_queue_layout_body)


func _queue_layout_body() -> void:
	if not _layout_queued:
		_layout_queued = true
		_layout_body.call_deferred()


func _snap(label: Label) -> void:
	PixelUI.set_block_ink_snap(label)
	_snapped.append(label)


func _resnap() -> void:
	for label: Label in _snapped:
		if is_instance_valid(label):
			PixelUI.set_block_ink_snap(label)


## The victory rows: stats the run already tracks (GameState), nothing new.
## Battles won: the battle the run ended on (all of them on a clear).
## Survivors: heroes standing at the final battle's end (deaths_last_battle).
## XP earned: the squad's run XP (unit_xp, reset at start_run).
## Relics: held at the end (a Starting Directive's relic included).
## Turns and time: the run's totals (run_total_turns, the wall clock).
func _victory_rows() -> Array:
	var squad: Array = GameState.selected_units
	var standing: int = 0
	for unit_id_variant in squad:
		if not GameState.deaths_last_battle.has(str(unit_id_variant)):
			standing += 1
	return [
		["BATTLES WON", "%d" % GameState.current_battle],
		["SURVIVORS", "%d / %d" % [standing, squad.size()]],
		["XP EARNED", "%d" % _squad_xp()],
		["RELICS", "%d" % GameState.relics.size()],
		["TURNS", "%d" % GameState.run_total_turns],
		["TIME", _format_duration(GameState.run_duration_secs())],
	]


## The defeat rows (G-78): the same sources. Battles won are the ones before
## the wipe; the fallen are every hero dead at a battle's end this run (a
## defeat is the whole squad), by callsign, in the order they fell.
func _defeat_rows() -> Array:
	return [
		["BATTLES WON", "%d" % maxi(GameState.current_battle - 1, 0)],
		["TURNS", "%d" % GameState.run_total_turns],
		["TIME", _format_duration(GameState.run_duration_secs())],
		["XP EARNED", "%d" % _squad_xp()],
		["RELICS", "%d" % GameState.relics.size()],
		["FALLEN", _fallen_heroes_text()],
	]


func _squad_xp() -> int:
	var xp: int = 0
	for unit_id_variant in GameState.selected_units:
		xp += GameState.get_unit_xp(str(unit_id_variant))
	return xp


## The operation boss's name: the unit with a standing rule in the last battle.
func _boss_name(operation: OperationData) -> String:
	if operation == null or operation.battles.is_empty():
		return "BOSS"
	var names: Array = (operation.battles[operation.battles.size() - 1] as Dictionary).get("enemy_names", [])
	var bosses: Array = GameState.boss_names_in(names)
	return str(bosses[0]) if not bosses.is_empty() else "BOSS"


func _fallen_heroes_text() -> String:
	if GameState.run_hero_deaths.is_empty():
		return "NONE"
	var names: Array = []
	for unit_id in GameState.run_hero_deaths:
		var unit: Resource = DataManager.get_unit(str(unit_id))
		names.append(str(unit.call("battle_name")) if unit != null and unit.has_method("battle_name") else str(unit_id))
	return ", ".join(names)


# Clock form (25:20, 1:02:05): the rows are capitals, and "25M 20S" misreads.
func _format_duration(secs: int) -> String:
	if secs >= 3600:
		return "%d:%02d:%02d" % [secs / 3600, (secs % 3600) / 60, secs % 60]
	return "%d:%02d" % [secs / 60, secs % 60]


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
