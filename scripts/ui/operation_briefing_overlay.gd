# Reusable operation-lore presentation. This is deliberately a transient
# overlay, not persistent battle chrome: unlock acknowledgement, deployment,
# and boss warning share the same terminal panel vocabulary.
class_name OperationBriefingOverlay
extends Control

signal dismissed(mode: String)

const PANEL_MARGIN := 32
const PANEL_PAD := 24
const KEY_COLUMN_WIDTH := 240
const KEY_VALUE_SEPARATION := 32
const DEPLOYMENT_GRID_WIDTH := 900
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
		"threats": "SHIELDS · JAM · REBUILD",
		"failure": "RECLAMATION LOOP",
		"directive": "DISMANTLE SCRAPMASTER",
		"accent": Color("C07A45"),
	},
	"hive": {
		"number": "02",
		"name": "HIVE INCURSION",
		"origin": "Biofabrication organisms have breached containment and begun self-replication.",
		"site": "KHEPRI BIOFOUNDRY",
		"threats": "BURN · SWARM · SIPHON",
		"failure": "CONTAINMENT OVERRUN",
		"directive": "TERMINATE THE MATRIARCH",
		"accent": Color("B94A70"),
	},
	"veil": {
		"number": "03",
		"name": "VEIL CONCORD",
		"origin": "The colony's command lattice has rejected authority and sealed itself.",
		"site": "VEIL COMMAND ARRAY",
		"threats": "FIREWALL · SHIELDS · SUPPORT",
		"failure": "CONSENSUS LOCKOUT",
		"directive": "ISOLATE THE OVERSEER",
		"accent": Color("A6A9C9"),
	},
	"voidCirclet": {
		"number": "04",
		"name": "NULL SYNOD",
		"origin": "An isolated maintenance order now worships a corrupted root signal.",
		"site": "NULL ROOT ARCHIVE",
		"threats": "REWRITE · HIJACK · SIPHON",
		"failure": "ROOT-SIGNAL CORRUPTION",
		"directive": "SEVER THE HIEROPHANT",
		"accent": Color("B653C8"),
	},
	"stellarMenagerie": {
		"number": "05",
		"name": "THE ACCRETION",
		"origin": "Terraforming fauna are mineralizing around a rupture in the planetary mantle.",
		"site": "NADIR TERRAFORMING BASIN",
		"threats": "PACK · PETRIFY · ARMOR",
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
var _dismissed := false
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


func present_deployment(operation_id: String) -> void:
	var copy := operation_copy(operation_id)
	if copy.is_empty():
		queue_free()
		return
	_mode = "deployment"
	_build_shell(PixelUI.COMPONENT_MODAL)
	_add_title("OPERATION %s // %s" % [str(copy["number"]), str(copy["name"])], PixelUI.DT_CYAN)
	_add_deployment_grid(copy)
	_add_action("ENGAGE", PixelUI.DT_CYAN)


func present_boss_alert(boss_name: String, runtime_rule: String) -> void:
	var parsed := split_runtime_rule(runtime_rule)
	_mode = "boss_alert"
	_build_shell(PixelUI.COMPONENT_ENEMY)
	_add_title("%s DETECTED" % boss_name.to_upper(), PixelUI.DT_ENEMY_BORDER)
	_add_body(boss_flavor(boss_name))
	_add_section("%s ACTIVE" % str(parsed["name"]), PixelUI.DT_ENEMY_BORDER)
	_add_body(str(parsed["mechanic"]))
	_add_action("ENGAGE", PixelUI.DT_ENEMY_BORDER)


func _build_shell(component_kind: String, accent: Color = Color.TRANSPARENT) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_as_relative = false
	z_index = 250
	var scrim := PixelUI.make_modal_scrim(0.72, true)
	scrim.name = "BriefingScrim"
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
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(center)

	var panel := PanelContainer.new()
	panel.name = "BriefingPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.custom_minimum_size = Vector2(0, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# The slate owns the available width but keeps its content-derived height so
	# the centered modal remains compact over the live battlefield.
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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


func _add_deployment_grid(copy: Dictionary) -> void:
	var center := CenterContainer.new()
	center.name = "DeploymentInfoCenter"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content().add_child(center)
	var grid := VBoxContainer.new()
	grid.name = "DeploymentInfoGrid"
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.custom_minimum_size = Vector2(DEPLOYMENT_GRID_WIDTH, 0)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("separation", 10)
	center.add_child(grid)
	_add_key_value(grid, "SITE", str(copy["site"]), copy["accent"] as Color)
	_add_key_value(grid, "FAILURE", str(copy["failure"]), PixelUI.DT_RUST)
	_add_key_value(grid, "DIRECTIVE", str(copy["directive"]), PixelUI.TEXT_PRIMARY)


func _add_key_value(grid: VBoxContainer, key: String, value: String, value_color: Color) -> void:
	var row := HBoxContainer.new()
	row.name = "DeploymentRow%s" % key.capitalize()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", KEY_VALUE_SEPARATION)
	# A Label in an HBox can expand to its natural text width. Put it in a
	# fixed-width slot so every value column has exactly the same start.
	var key_slot := Control.new()
	key_slot.name = "DeploymentKeySlot%s" % key.capitalize()
	key_slot.custom_minimum_size = Vector2(KEY_COLUMN_WIDTH, 0)
	key_slot.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	key_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(key_slot)
	var key_label := _make_label(key, SECTION_FONT, PixelUI.TEXT_MUTED, 1)
	key_label.name = "DeploymentKey%s" % key.capitalize()
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	key_label.clip_text = true
	key_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	key_slot.add_child(key_label)
	var value_label := _make_label(value, SECTION_FONT, value_color, 2)
	value_label.name = "DeploymentValue%s" % key.capitalize()
	# The accepted operation values are authored to fit this full-width slate at
	# 540x1200. Keep each row to one decisive scan line rather than introducing
	# operation-specific wraps or positioning.
	value_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(value_label)
	grid.add_child(row)


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


func _dismiss() -> void:
	if _dismissed or not is_inside_tree():
		return
	_dismissed = true
	AudioManager.play_select()
	dismissed.emit(_mode)
	queue_free()
