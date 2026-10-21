# Reusable operation-lore presentation. This is deliberately a transient
# overlay, not persistent battle chrome: unlock acknowledgement, deployment,
# and boss warning share the same terminal panel vocabulary.
class_name OperationBriefingOverlay
extends Control

signal dismissed(mode: String)

const PANEL_MARGIN := 32
const PANEL_PAD := 24
## The objective wraps onto at most this many lines.
const OBJECTIVE_MAX_LINES := 2
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
		"origin": "The foundry has turned on its workers. Its drones feed scrap to the machine that runs it.",
		"site": "Colony reclamation works",
		"threats": "SHIELDS · JAM · REPAIR",
		"failure": "Security machines hostile",
		"directive": "Destroy the Scrapmaster",
	},
	"hive": {
		"number": "02",
		"name": "HIVE INCURSION",
		"origin": "An invasive brood has overrun the colony labs. The hive is spreading into the surrounding settlements.",
		"site": "Colony bioresearch labs",
		"threats": "BURN · SWARM · LEECH",
		"failure": "Hive containment lost",
		"directive": "Kill the Hive Matriarch",
	},
	"veil": {
		"number": "03",
		"name": "VEIL BREACH",
		"origin": "An alien force known as the Veil has seized the colony relay. Its troops fight behind linked energy shields.",
		"site": "Colony command relay",
		"threats": "FIREWALL · SHIELDS · SUPPORT",
		"failure": "Command relay occupied",
		"directive": "Eliminate the Veil Overseer",
	},
	"voidCirclet": {
		"number": "04",
		"name": "SIGNAL PURGE",
		"origin": "A machine cult has seized the colony archive. Its broadcasts are corrupting military systems across the colony.",
		"site": "Colony signal archive",
		"threats": "REWRITE · HIJACK · SIPHON",
		"failure": "Hostile signal broadcast",
		"directive": "Eliminate the Signal Hierarch",
	},
	"stellarMenagerie": {
		"number": "05",
		"name": "MANTLE HUNT",
		"origin": "Deep drilling has driven mineral-plated predators to the surface. The largest is tearing through the mining perimeter.",
		"site": "Colony deep-core mine",
		"threats": "PACK · PETRIFY · ARMOR",
		"failure": "Predators through the perimeter",
		"directive": "Kill the Mantle Tyrant",
	},
}

const BOSS_FLAVOR := {
	"Scrapmaster": "An industrial assembler that repairs itself with scrap its drones bring it.",
	"Hive Matriarch": "A living brood factory that sends its offspring into the fight.",
	"Veil Overseer": "The Veil commander fights behind a firewall sustained by its surviving troops.",
	"Signal Hierarch": "A machine priest whose broadcasts override the squad's targeting systems.",
	"Mantle Tyrant": "An apex predator that grows fresh mineral armor as it fights.",
}

var _mode := ""
var _dismissed := false
var _action: Button = null
var _content_container: VBoxContainer = null


static func operation_copy(operation_id: String) -> Dictionary:
	var copy: Dictionary = (OPERATION_COPY.get(operation_id, {}) as Dictionary).duplicate(true)
	if not copy.is_empty():
		# Flat pixel B: the encounter color is reserved for the battle header and
		# the enemy cards, so operation copy (squad select, briefing) reads CHROME.
		copy["accent"] = PixelUI.CHROME
	return copy


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


# present_unlock is RETIRED (Build G, ruled): the one-time operation-unlock
# popup folded into the UnlockScreen's NEW OPERATION section (name + origin
# line at body tier). Deployment and boss-alert modes are unchanged.
func present_deployment(operation_id: String) -> void:
	var copy := operation_copy(operation_id)
	if copy.is_empty():
		queue_free()
		return
	_mode = "deployment"
	_build_shell(PixelUI.COMPONENT_MODAL)
	_add_title("OPERATION %s // %s" % [str(copy["number"]), str(copy["name"])], PixelUI.CHROME)
	_add_deployment_grid(copy)
	_add_action("ENGAGE", PixelUI.PLAYER_ACCENT)


func present_boss_alert(boss_name: String, runtime_rule: String) -> void:
	var parsed := split_runtime_rule(runtime_rule)
	_mode = "boss_alert"
	_build_shell(PixelUI.COMPONENT_ENEMY)
	_add_title("%s DETECTED" % boss_name.to_upper(), PixelUI.ENCOUNTER_ACCENT.lightened(0.2))
	_add_body(boss_flavor(boss_name))
	_add_section("%s ACTIVE" % str(parsed["name"]), PixelUI.ENCOUNTER_ACCENT.lightened(0.2))
	_add_body(str(parsed["mechanic"]))
	_add_action("ENGAGE", PixelUI.PLAYER_ACCENT)


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
	# ui-unify: the slate's width (the deployment grid plus padding) so its text
	# wraps inside the screen; the boss alert used to size to its longest line
	# and run off a 390 px screen.
	panel.custom_minimum_size = Vector2(DEPLOYMENT_GRID_WIDTH + PANEL_PAD * 2, 0)
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
	column.add_theme_constant_override("separation", 20)
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
	var label := _make_label(text, BODY_FONT, PixelUI.CHROME, 1)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_constant_override("line_spacing", PixelUI.BODY_LINE_SPACING)
	_content().add_child(label)


# The deployment briefing shows only the objective (Kev 2026-10-20): OBJECTIVE
# centred, the objective centred on the line under it, both m5x7 at 80. SITE
# and SITUATION stay in OPERATION_COPY (the encounter inspect reads the site)
# but are not shown here. The objective wraps at words, at most two lines (the
# operation lore gate checks every operation).
func _add_deployment_grid(copy: Dictionary) -> void:
	var grid := VBoxContainer.new()
	grid.name = "DeploymentInfoGrid"
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("separation", 8)
	_content().add_child(grid)
	var label := _make_label("OBJECTIVE", SECTION_FONT, PixelUI.TEXT_MUTED, 1)
	label.name = "ObjectiveLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grid.add_child(label)
	var value := _make_label(str(copy["directive"]), SECTION_FONT, PixelUI.TEXT_PRIMARY, 2)
	value.name = "ObjectiveValue"
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.autowrap_mode = TextServer.AUTOWRAP_WORD
	value.max_lines_visible = OBJECTIVE_MAX_LINES
	grid.add_child(value)


func _add_action(text: String, accent: Color) -> void:
	_action = Button.new()
	_action.name = "BriefingAction"
	_action.focus_mode = Control.FOCUS_NONE
	_action.text = text
	_action.custom_minimum_size = Vector2(0, ACTION_HEIGHT)
	_action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# The slate's confirm is the pop-up's primary (ui-unify).
	PixelUI.style_ui_primary_button(_action, ACTION_FONT)
	_action.pressed.connect(_dismiss)
	_content().add_child(_action)


func _make_label(text: String, font_size: int, color: Color, outline: int) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	PixelUI.style_label(label, font_size, color, outline)
	return label


func _dismiss() -> void:
	if _dismissed or not is_inside_tree():
		return
	_dismissed = true
	AudioManager.play_click()
	dismissed.emit(_mode)
	queue_free()
