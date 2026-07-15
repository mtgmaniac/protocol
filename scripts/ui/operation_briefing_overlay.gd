# Reusable operation-lore presentation. This is deliberately a transient
# overlay, not persistent battle chrome: unlock acknowledgement, deployment,
# and boss warning share the same terminal panel vocabulary.
class_name OperationBriefingOverlay
extends Control

signal dismissed(mode: String)

const AUTO_DISMISS_SECONDS := 2.25
const PANEL_MARGIN := 52
const PANEL_PAD := 32
const TITLE_FONT := 64
const SECTION_FONT := 40
const BODY_FONT := PixelUI.FONT_BODY_MIN
const ACTION_FONT := 52
const ACTION_HEIGHT := 112

const OPERATION_COPY := {
	"facility": {
		"number": "01",
		"name": "FACILITY SWEEP",
		"origin": "The recovery network now classifies every survivor as salvage.",
		"site": "ORPHEUS RECOVERY COMPLEX",
		"failure": "RECLAMATION LOOP",
		"directive": "DISMANTLE SCRAPMASTER",
		"accent": Color("C07A45"),
	},
	"hive": {
		"number": "02",
		"name": "HIVE INCURSION",
		"origin": "Biofabrication organisms have breached containment and begun self-replication.",
		"site": "KHEPRI BIOFOUNDRY",
		"failure": "CONTAINMENT OVERRUN",
		"directive": "TERMINATE THE MATRIARCH",
		"accent": Color("B94A70"),
	},
	"veil": {
		"number": "03",
		"name": "VEIL CONCORD",
		"origin": "The colony's command lattice has rejected authority and sealed itself.",
		"site": "VEIL COMMAND ARRAY",
		"failure": "CONSENSUS LOCKOUT",
		"directive": "ISOLATE THE OVERSEER",
		"accent": Color("A6A9C9"),
	},
	"voidCirclet": {
		"number": "04",
		"name": "NULL SYNOD",
		"origin": "An isolated maintenance order now worships a corrupted root signal.",
		"site": "NULL ROOT ARCHIVE",
		"failure": "ROOT-SIGNAL CORRUPTION",
		"directive": "SEVER THE HIEROPHANT",
		"accent": Color("B653C8"),
	},
	"stellarMenagerie": {
		"number": "05",
		"name": "THE ACCRETION",
		"origin": "Terraforming fauna are mineralizing around a rupture in the planetary mantle.",
		"site": "NADIR TERRAFORMING BASIN",
		"failure": "MANTLE BREACH",
		"directive": "SHATTER THE TYRANT",
		"accent": Color("D89B4A"),
	},
}

const BOSS_FLAVOR := {
	"SCRAPMASTER": "The facility's central assembler turns battlefield wreckage back into soldiers.",
	"Hive Matriarch": "The brood's reproductive core continues producing combat organisms.",
	"CONCLAVE OVERSEER": "The lattice's sovereign node draws protection from every surviving subordinate.",
	"ROOT HIEROPHANT": "The Synod's root authority treats probability as writable doctrine.",
	"MANTLE TYRANT": "A mantle-fed apex organism grows new armor throughout the fight.",
}

var _mode := ""
var _repeat_deployment := false
var _action: Button = null
var _content_container: VBoxContainer = null


static func operation_copy(operation_id: String) -> Dictionary:
	return (OPERATION_COPY.get(operation_id, {}) as Dictionary).duplicate(true)


static func boss_flavor(boss_name: String) -> String:
	return str(BOSS_FLAVOR.get(boss_name, ""))


# Runtime owns the literal rule string. The split only gives the alert a compact
# rule-name header; the mechanic body is never duplicated in lore copy.
static func split_runtime_rule(runtime_rule: String) -> Dictionary:
	var divider: int = runtime_rule.find(" - ")
	if divider < 0:
		return {"name": runtime_rule, "mechanic": ""}
	return {
		"name": runtime_rule.left(divider),
		"mechanic": runtime_rule.substr(divider + 3),
	}


func present_unlock(operation_id: String) -> void:
	var copy := operation_copy(operation_id)
	if copy.is_empty():
		queue_free()
		return
	_mode = "unlock"
	_build_shell(PixelUI.COMPONENT_REWARD, PixelUI.DT_AMBER)
	_add_title("OPERATION UNLOCKED", PixelUI.DT_AMBER)
	_add_section("OPERATION %s // %s" % [str(copy["number"]), str(copy["name"])], PixelUI.TEXT_PRIMARY)
	_add_body(str(copy["origin"]))
	_add_action("ACKNOWLEDGE", PixelUI.DT_AMBER)


func present_deployment(operation_id: String, repeat_deployment: bool) -> void:
	var copy := operation_copy(operation_id)
	if copy.is_empty():
		queue_free()
		return
	_mode = "deployment"
	_repeat_deployment = repeat_deployment
	_build_shell(PixelUI.COMPONENT_MODAL)
	_add_title("OPERATION %s // %s" % [str(copy["number"]), str(copy["name"])], PixelUI.DT_CYAN)
	_add_key_value("SITE", str(copy["site"]), copy["accent"] as Color)
	_add_key_value("FAILURE", str(copy["failure"]), PixelUI.DT_RUST)
	_add_key_value("DIRECTIVE", str(copy["directive"]), PixelUI.TEXT_PRIMARY)
	_add_action("TAP TO DEPLOY" if repeat_deployment else "DEPLOY", PixelUI.DT_CYAN)
	if repeat_deployment:
		get_tree().create_timer(AUTO_DISMISS_SECONDS).timeout.connect(_auto_dismiss)


func present_boss_alert(boss_name: String, runtime_rule: String) -> void:
	var parsed := split_runtime_rule(runtime_rule)
	_mode = "boss_alert"
	_build_shell(PixelUI.COMPONENT_ENEMY)
	_add_title("%s DETECTED" % boss_name.to_upper(), PixelUI.DT_ENEMY_BORDER)
	_add_body(boss_flavor(boss_name))
	_add_section("%s ACTIVE" % str(parsed["name"]), PixelUI.DT_ENEMY_BORDER)
	_add_body(str(parsed["mechanic"]))
	_add_action("ENGAGE", PixelUI.DT_ENEMY_BORDER)


func present_boss_reminder(boss_name: String, runtime_rule: String) -> void:
	var parsed := split_runtime_rule(runtime_rule)
	_mode = "boss_reminder"
	_build_shell(PixelUI.COMPONENT_ENEMY)
	_add_title("%s // %s" % [boss_name.to_upper(), str(parsed["name"])], PixelUI.DT_ENEMY_BORDER)
	_add_body(str(parsed["mechanic"]))
	_add_action("CLOSE", PixelUI.DT_ENEMY_BORDER)


func _build_shell(component_kind: String, accent: Color = Color.TRANSPARENT) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_as_relative = false
	z_index = 250
	var scrim := PixelUI.make_modal_scrim(0.72, true)
	scrim.name = "BriefingScrim"
	scrim.gui_input.connect(_on_scrim_input)
	add_child(scrim)

	var outer := MarginContainer.new()
	outer.name = "BriefingOuter"
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		outer.add_theme_constant_override(side, PANEL_MARGIN)
	add_child(outer)

	var center := CenterContainer.new()
	center.name = "BriefingCenter"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(center)

	var panel := PanelContainer.new()
	panel.name = "BriefingPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.custom_minimum_size = Vector2(0, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	PixelUI.style_component(panel, component_kind, accent)
	center.add_child(panel)

	var pad := MarginContainer.new()
	pad.name = "BriefingPadding"
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		pad.add_theme_constant_override(side, PANEL_PAD)
	panel.add_child(pad)

	var column := VBoxContainer.new()
	column.name = "BriefingContent"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 18)
	pad.add_child(column)
	_content_container = column


func _content() -> VBoxContainer:
	return _content_container


func _add_title(text: String, color: Color) -> void:
	var label := _make_label(text, TITLE_FONT, color, 3)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content().add_child(label)


func _add_section(text: String, color: Color) -> void:
	var label := _make_label(text, SECTION_FONT, color, 2)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content().add_child(label)


func _add_body(text: String) -> void:
	var label := _make_label(text, BODY_FONT, PixelUI.TEXT_MUTED, 1)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_constant_override("line_spacing", PixelUI.BODY_LINE_SPACING)
	_content().add_child(label)


func _add_key_value(key: String, value: String, value_color: Color) -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 18)
	var key_label := _make_label(key, SECTION_FONT, PixelUI.TEXT_MUTED, 1)
	key_label.custom_minimum_size = Vector2(180, 0)
	row.add_child(key_label)
	var value_label := _make_label(value, SECTION_FONT, value_color, 2)
	value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(value_label)
	_content().add_child(row)


func _add_action(text: String, accent: Color) -> void:
	_action = Button.new()
	_action.name = "BriefingAction"
	_action.focus_mode = Control.FOCUS_NONE
	_action.text = text
	_action.custom_minimum_size = Vector2(0, ACTION_HEIGHT)
	_action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	PixelUI.style_button(_action, PixelUI.DT_HERO_BG, accent, ACTION_FONT)
	_action.pressed.connect(_dismiss)
	_content().add_child(_action)


func _make_label(text: String, font_size: int, color: Color, outline: int) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	PixelUI.style_label(label, font_size, color, outline)
	return label


func _on_scrim_input(event: InputEvent) -> void:
	if not _repeat_deployment:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_dismiss()
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		_dismiss()


func _auto_dismiss() -> void:
	if is_inside_tree() and _repeat_deployment:
		_dismiss()


func _dismiss() -> void:
	if not is_inside_tree():
		return
	AudioManager.play_select()
	dismissed.emit(_mode)
	queue_free()
