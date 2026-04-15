@tool 
class_name UnitCard
extends PanelContainer

const LOW_HP_THRESHOLD := 0.3
const HERO_PORTRAIT_RATIO := 240.0 / 317.0
const BATTLE_PORTRAIT_WIDTH := 202.0
const BATTLE_PORTRAIT_HEIGHT := BATTLE_PORTRAIT_WIDTH / HERO_PORTRAIT_RATIO
const CHIP_DAMAGE_BG := Color(0.53, 0.20, 0.18, 0.98)
const CHIP_SHIELD_BG := Color(0.15, 0.32, 0.50, 0.98)
const CHIP_HEAL_BG := Color(0.12, 0.38, 0.23, 0.98)
const CHIP_DOT_BG := Color(0.43, 0.19, 0.22, 0.98)
const CHIP_DICE_BG := Color(0.46, 0.34, 0.14, 0.98)
const CHIP_FROST_BG := Color(0.12, 0.34, 0.48, 0.98)
const ICON_DAMAGE := "\u26A1"
const ICON_HEAL := "\u271A"
const ICON_DOT := "\u2620"
const STATUS_BADGE_SIZE := Vector2(70, 30)
const STATUS_ICON_SIZE := Vector2(18, 18)
const STATUS_TEXT_SIZE := 16
const ABILITY_DETAIL_HEIGHT := 60
const ABILITY_NAME_SIZE := 28
const ABILITY_CHIP_HEIGHT := 46
const ABILITY_CHIP_ICON_SIZE := Vector2(34, 34)
const ABILITY_CHIP_TEXT_SIZE := 22
const TOOLTIP_MIN_WIDTH := 640
const TOOLTIP_TEXT_WIDTH := 560
const ICON_MAP = {
	"damage": preload("res://assets/generated/icon_damage_1776027930.png"),
	"shield": preload("res://assets/generated/icon_shield_1776027929.png"),
	"heal": preload("res://assets/generated/icon_heal_heart_1776027943.png"),
	"dot": preload("res://assets/generated/icon_dot_1776027932.png"),
	"dice": preload("res://assets/generated/icon_dice_d6_1776027927.png"),
	"frost": preload("res://assets/generated/icon_frost_snowflake_frame_0_1776027966.png"),
}

const TOOLTIP_MAP = {
	"SH": "Shield: Provides temporary damage absorption. Absorbs incoming damage before HP.",
	"POI": "Poison: Deals damage at the end of every turn. Format shows damage × remaining turns.",
	"RFE": "Reflect: Deals a portion of damage back to the attacker.",
	"STU": "Stun: Target skips their next turn.",
	"REG": "Regen: Restores HP at the start of every turn.",
	"VMP": "Vampire: Heals the attacker for a portion of damage dealt.",
	"PRO": "Protection: Reduces incoming damage by a flat amount.",
	"CLOAK": "Cloak: Greatly increases evasion, making the unit hard to hit.",
	"COWER": "Cower: Unit is stunned and cannot take actions this turn.",
	"FROZEN": "Frozen: Die is locked to a specific value until thawed.",
	"RAGE": "Rage: Increases damage dealt for each stack. Decays after use.",
	"CURSED": "Cursed: Unit must roll twice and take the lower result.",
	"TAUNT": "Taunt: Forces enemies to target this unit above others.",
	"CNTR": "Counter: Chance to strike back immediately when attacked.",
	"PHASE 2": "Enraged: Boss has entered phase 2 with improved stats.",
	"DOWN": "Eliminated: This unit is no longer active in combat.",
	"DMG": "Damage: Deals direct damage to the target's health.",
	"HEAL": "Heal: Restores HP to the target or self.",
	"DOT": "Poison: Inflicts damage over time to the target.",
	"SHIELD": "Shield: Grants defensive protection to the target.",
	"DICE": "Dice Mod: Changes dice roll values or adds extra dice.",
	"HP": "Health: If this reaches zero, the unit is defeated.",
	"XP": "Experience: Earned by defeating enemies to level up.",
	"T": "Single Target: This ability affects one unit.",
	"ALL": "Area Effect: This ability affects all units in the zone.",
}

signal card_pressed

var _hovered_element_text: String = ""
var _hovered_node: Control = null
var _hold_triggered: bool = false
var _icon_texture_cache: Dictionary = {}
var _is_selected_source: bool = false
var _is_targetable: bool = false
var _is_target_hovered: bool = false
var _is_details_expanded: bool = false
var _active_ability_tooltip: String = ""
var _details_button: Button = null
var _details_panel: PanelContainer = null
var _ability_detail_rows: Array = []
var _gear_detail_rows: Array = []
var _detail_unit_name: String = ""
var _detail_current_hp: int = 0
var _detail_max_hp: int = 0
var _detail_dice_result: String = ""
var _detail_ability_text: String = ""
var _detail_target_text: String = ""
var _detail_target_side: String = ""
var _detail_status_list: Array = []
var _detail_xp_ratio: float = 0.0
var _detail_is_dead: bool = false
var _detail_accent_color: Color = Color.WHITE
var _details_accept_outside_close: bool = false
var _base_card_border_color: Color = Color(0.12, 0.24, 0.36, 0.95)
var _base_card_border_width: int = 3

# Combat preview — integrated bar sections drawn inside HPBar.
# All sections are carved right-to-left from the current HP edge.
# Layout (right → left within fill): [red][blue][purple][teal]
# Layout (extending right beyond fill): [bright green heal]
var _preview_hp_bar_ref: ProgressBar = null
var _preview_rect_red: ColorRect = null        # Direct HP loss this turn
var _preview_rect_blue: ColorRect = null       # Direct damage absorbed by shield
var _preview_rect_purple: ColorRect = null     # DoT damage that will reach HP
var _preview_rect_teal: ColorRect = null       # DoT damage absorbed by remaining shield
var _preview_rect_heal: ColorRect = null       # Incoming healing (extends right)
var _preview_tooltip_text: String = ""         # Human-readable description for HP hover
var _hp_bar_hover_connected: bool = false      # Guard for one-time signal connection

func _ready() -> void:
	_wire_card_frame_input()
	if Engine.is_editor_hint():
		_apply_editor_preview_theme()
	
	var tooltip_panel: PanelContainer = %TooltipPanel if has_node("%TooltipPanel") else get_node_or_null("TooltipPanel")
	if tooltip_panel:
		tooltip_panel.set_as_top_level(true)
		tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_mouse_filter_recursive(tooltip_panel, Control.MOUSE_FILTER_IGNORE)
		tooltip_panel.visible = false
		tooltip_panel.custom_minimum_size = Vector2(TOOLTIP_MIN_WIDTH, 72)
		_apply_tooltip_panel_style(tooltip_panel)
		var tooltip_margin: MarginContainer = tooltip_panel.get_node_or_null("TooltipMargin") as MarginContainer
		if tooltip_margin != null:
			tooltip_margin.add_theme_constant_override("margin_left", 16)
			tooltip_margin.add_theme_constant_override("margin_top", 12)
			tooltip_margin.add_theme_constant_override("margin_right", 16)
			tooltip_margin.add_theme_constant_override("margin_bottom", 12)
		
		var tooltip_label: Label = %TooltipLabel if has_node("%TooltipLabel") else tooltip_panel.get_node_or_null("TooltipMargin/TooltipLabel")
		if tooltip_label:
			tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD
			tooltip_label.custom_minimum_size.x = TOOLTIP_TEXT_WIDTH
			tooltip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			PixelUI.apply_pixel_font(tooltip_label)
			tooltip_label.add_theme_font_size_override("font_size", PixelUI.scale_font_size(24))
	
	var xp_bar: ProgressBar = get_node_or_null("%XPBar")
	if xp_bar:
		xp_bar.mouse_filter = Control.MOUSE_FILTER_STOP
		if not xp_bar.mouse_entered.is_connected(_on_element_mouse_entered):
			xp_bar.mouse_entered.connect(_on_element_mouse_entered.bind(TOOLTIP_MAP.XP, xp_bar))
			xp_bar.mouse_exited.connect(_on_element_mouse_exited)
		_connect_passthrough_click(xp_bar)

	var hold_timer: Timer = get_node_or_null("HoldTimer")
	if hold_timer and not hold_timer.timeout.is_connected(_on_hold_timer_timeout):
		hold_timer.timeout.connect(_on_hold_timer_timeout)
	_ensure_details_controls()


func _on_element_mouse_entered(text: String, node: Control = null) -> void:
	if text.is_empty(): return
	_hovered_element_text = text
	_hovered_node = node
	
	if not OS.has_feature("mobile"):
		_show_tooltip(text)
	
	var hold_timer = get_node_or_null("HoldTimer")
	if hold_timer:
		hold_timer.start()

func _on_element_mouse_exited() -> void:
	_hovered_element_text = ""
	_hovered_node = null
	var hold_timer = get_node_or_null("HoldTimer")
	if hold_timer:
		hold_timer.stop()
	_hide_tooltip()

func _show_tooltip(text: String = "") -> void:
	var final_text = text if not text.is_empty() else _hovered_element_text
	if final_text.is_empty(): 
		_hide_tooltip()
		return
	
	var tooltip_label: Label = %TooltipLabel if has_node("%TooltipLabel") else null
	var tooltip_panel: PanelContainer = %TooltipPanel if has_node("%TooltipPanel") else get_node_or_null("TooltipPanel")
	
	if tooltip_label and tooltip_panel:
		if tooltip_panel.visible and tooltip_label.text == final_text:
			# Only update position if we are already visible
			_update_tooltip_position(tooltip_panel)
			return
			
		tooltip_label.text = _professionalize_tooltip_text(final_text)
		# Force size update before making visible to avoid "flashing" at wrong position
		# Set a minimum width for the panel to prevent vertical text
		tooltip_panel.custom_minimum_size.x = TOOLTIP_MIN_WIDTH
		tooltip_panel.reset_size()
		_update_tooltip_position(tooltip_panel)
		tooltip_panel.visible = true

func _update_tooltip_position(panel: PanelContainer) -> void:
	if not _hovered_node or not _hovered_node.is_inside_tree():
		panel.global_position = get_global_mouse_position() + Vector2(15, 15)
		return
		
	var node_rect = _hovered_node.get_global_rect()
	var tooltip_size = panel.get_combined_minimum_size()
	
	# Position above the node by default
	var target_pos = Vector2(
		node_rect.position.x + (node_rect.size.x - tooltip_size.x) / 2,
		node_rect.position.y - tooltip_size.y - 12
	)
	
	# Clamp to screen bounds
	var screen_rect = get_viewport_rect()
	target_pos.x = clamp(target_pos.x, 12, screen_rect.size.x - tooltip_size.x - 12)
	
	if target_pos.y < 12:
		# If it goes off top of screen, show below the node instead
		target_pos.y = node_rect.end.y + 12
	target_pos.y = clamp(target_pos.y, 12, screen_rect.size.y - tooltip_size.y - 12)
		
	panel.global_position = target_pos

func _hide_tooltip() -> void:
	var tooltip_panel: PanelContainer = %TooltipPanel if has_node("%TooltipPanel") else get_node_or_null("TooltipPanel")
	if tooltip_panel:
		tooltip_panel.visible = false
	_hold_triggered = false

func _on_hold_timer_timeout() -> void:
	var text := _hovered_element_text if not _hovered_element_text.is_empty() else _active_ability_tooltip
	if not text.is_empty():
		_hold_triggered = true
		_show_tooltip(text)

func _on_click_button_down() -> void:
	_hold_triggered = false
	$HoldTimer.start()

func _on_click_button_up() -> void:
	var was_long_press = _hold_triggered
	$HoldTimer.stop()
	_hide_tooltip()
	if not was_long_press:
		card_pressed.emit()

func _on_click_button_mouse_exited() -> void:
	$HoldTimer.stop()
	_hide_tooltip()

func _on_badge_gui_input(event: InputEvent) -> void:
	_on_card_frame_gui_input(event)


func _connect_passthrough_click(control: Control) -> void:
	if control != null and not control.gui_input.is_connected(_on_card_frame_gui_input):
		control.gui_input.connect(_on_card_frame_gui_input)


func _ensure_details_controls() -> void:
	if _details_button == null:
		_details_button = Button.new()
		_details_button.name = "DetailsButton"
		_details_button.text = "+"
		_details_button.custom_minimum_size = Vector2(46, 42)
		_details_button.mouse_filter = Control.MOUSE_FILTER_STOP
		_details_button.z_as_relative = false
		_details_button.z_index = 130
		# set_as_top_level escapes PanelContainer's fill-all-children layout,
		# preventing the button from stretching to cover the entire card.
		_details_button.set_as_top_level(true)
		PixelUI.style_button(_details_button, Color(0.045, 0.070, 0.100, 0.96), Color(0.42, 0.62, 0.78, 0.95), 22)
		_details_button.pressed.connect(_on_details_button_pressed)
		add_child(_details_button)
		set_notify_transform(true)
		call_deferred("_reposition_details_button")
	if _details_panel == null:
		_details_panel = PanelContainer.new()
		_details_panel.name = "DetailsPanel"
		_details_panel.visible = false
		_details_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		_details_panel.z_as_relative = false
		_details_panel.z_index = 110
		_details_panel.clip_contents = true
		_details_panel.set_as_top_level(true)
		PixelUI.style_panel(_details_panel, Color(0.018, 0.026, 0.044, 0.98), Color(0.42, 0.62, 0.78, 0.95), 3, 0)
		add_child(_details_panel)


func _reposition_details_button() -> void:
	if _details_button == null:
		return
	var card_rect := get_global_rect()
	_details_button.size = Vector2(46, 42)
	_details_button.global_position = Vector2(
		card_rect.position.x + 8,
		card_rect.end.y - 50
	)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_TRANSFORM_CHANGED:
		_reposition_details_button()
		if _details_panel != null and _details_panel.visible:
			_update_details_panel_position()
		_layout_preview_overlays()


func _refresh_details_controls() -> void:
	if _details_button == null:
		return
	_details_button.text = "+"
	_details_button.z_index = 130 if _is_details_expanded else 20
	if _details_panel != null and _details_panel.visible:
		_populate_details_panel()
		_update_details_panel_position()


func _on_details_button_pressed() -> void:
	if _details_panel == null:
		return
	if _is_details_expanded:
		_close_details_panel()
		return
	_is_details_expanded = true
	_details_accept_outside_close = false
	_details_panel.visible = true
	_populate_details_panel()
	_update_details_panel_position()
	_refresh_details_controls()
	call_deferred("_enable_details_outside_close")


func _enable_details_outside_close() -> void:
	_details_accept_outside_close = _is_details_expanded


func _input(event: InputEvent) -> void:
	if not _is_details_expanded or not _details_accept_outside_close:
		return
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
			return
		var click_position: Vector2 = mouse_event.global_position
		var panel_rect: Rect2 = _details_panel.get_global_rect() if _details_panel != null else Rect2()
		var button_rect: Rect2 = _details_button.get_global_rect() if _details_button != null else Rect2()
		if button_rect.has_point(click_position):
			_close_details_panel()
			get_viewport().set_input_as_handled()
			return
		if panel_rect.has_point(click_position):
			return
		_close_details_panel()
	if event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event
		if not touch_event.pressed:
			return
		var touch_position: Vector2 = touch_event.position
		var touch_panel_rect: Rect2 = _details_panel.get_global_rect() if _details_panel != null else Rect2()
		var touch_button_rect: Rect2 = _details_button.get_global_rect() if _details_button != null else Rect2()
		if touch_button_rect.has_point(touch_position):
			_close_details_panel()
			get_viewport().set_input_as_handled()
			return
		if touch_panel_rect.has_point(touch_position):
			return
		_close_details_panel()


func _close_details_panel() -> void:
	_is_details_expanded = false
	_details_accept_outside_close = false
	if _details_panel != null:
		_details_panel.visible = false
	_refresh_details_controls()


func _populate_details_panel() -> void:
	for child in _details_panel.get_children():
		child.queue_free()
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_details_panel.add_child(margin)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(vbox)

	var header_row: HBoxContainer = HBoxContainer.new()
	header_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_theme_constant_override("separation", 8)
	vbox.add_child(header_row)
	_add_details_header(header_row, _detail_unit_name)
	_add_details_line(vbox, "HP: %d / %d" % [_detail_current_hp, _detail_max_hp], PixelUI.TEXT_PRIMARY, 20)
	_add_details_line(vbox, "Roll: %s" % _detail_dice_result.replace("D20: ", ""), PixelUI.TEXT_PRIMARY, 20)
	_add_details_line(vbox, "Target: %s" % _detail_target_text, _get_target_text_color(_detail_target_side, _detail_target_text), 20)
	_add_details_line(vbox, "XP: %d%%" % int(round(_detail_xp_ratio * 100.0)), PixelUI.TEXT_MUTED, 18)
	_add_details_line(vbox, "State: %s" % ("DOWN" if _detail_is_dead else "Active"), PixelUI.TEXT_MUTED, 18)

	_add_details_header(vbox, "Statuses")
	if _detail_status_list.is_empty():
		_add_details_line(vbox, "None", PixelUI.TEXT_MUTED, 18)
	else:
		for status_variant in _detail_status_list:
			_add_details_line(vbox, str(status_variant), PixelUI.TEXT_PRIMARY, 19)

	_add_details_header(vbox, "Current Ability")
	_add_details_line(vbox, _detail_ability_text, PixelUI.TEXT_PRIMARY, 20)

	_add_details_header(vbox, "Abilities")
	if _ability_detail_rows.is_empty():
		_add_details_line(vbox, "No ability data.", PixelUI.TEXT_MUTED, 18)
	else:
		for row_variant in _ability_detail_rows:
			var row: Dictionary = row_variant
			var ability_line := "%s: %s" % [str(row.get("range_text", "")), str(row.get("ability_name", "Ability"))]
			_add_details_line(vbox, ability_line, PixelUI.TEXT_PRIMARY, 19)
			var description := _professionalize_tooltip_text(str(row.get("description", "")))
			if description != "":
				_add_details_line(vbox, description, PixelUI.TEXT_MUTED, 17)
	_add_details_header(vbox, "Gear")
	if _gear_detail_rows.is_empty():
		_add_details_line(vbox, "No gear equipped.", PixelUI.TEXT_MUTED, 18)
	else:
		for gear_variant in _gear_detail_rows:
			var gear: Dictionary = gear_variant
			_add_details_line(vbox, str(gear.get("name", "Gear")), PixelUI.TEXT_PRIMARY, 19)
			var gear_description := _professionalize_tooltip_text(str(gear.get("description", "")))
			if gear_description != "":
				_add_details_line(vbox, gear_description, PixelUI.TEXT_MUTED, 17)


func _add_details_header(parent: Control, text: String) -> void:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	PixelUI.style_label(label, 24, Color(0.78, 0.88, 1.0, 1.0), 3)
	parent.add_child(label)


func _add_details_line(parent: VBoxContainer, text: String, color: Color, font_size: int = 22) -> void:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	PixelUI.style_label(label, font_size, color, 2)
	parent.add_child(label)


func _update_details_panel_position() -> void:
	if _details_panel == null:
		return
	var card_rect := get_global_rect()
	_details_panel.global_position = card_rect.position
	_details_panel.size = card_rect.size
	_details_panel.custom_minimum_size = card_rect.size


func _legacy_badge_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_event.pressed:
			_on_click_button_down()
		else:
			_on_click_button_up()
	elif event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event
		if touch_event.pressed:
			_on_click_button_down()
		else:
			_on_click_button_up()

func _populate_badges(container: Container, values: Array, empty_text: String) -> void:
	# Optimization: Only rebuild if values changed to prevent flickering during UI refreshes
	var current_values = []
	for child in container.get_children():
		var row = child.get_node_or_null("Row")
		if row:
			var label = row.get_child(-1) as Label
			if label:
				current_values.append(label.text)
	
	var new_values_str = []
	for v in values:
		new_values_str.append(_format_badge_text(str(v), empty_text))
		
	if str(current_values) == str(new_values_str):
		return

	for child in container.get_children():
		child.queue_free()
	
	# Status effects align right to fit next to portrait
	if container is HFlowContainer:
		container.set("alignment", 2) 

	if values.is_empty():
		var empty_label = Label.new()
		empty_label.text = _get_empty_row_text(empty_text)
		empty_label.modulate = Color(0.44, 0.50, 0.60, 0.7)
		PixelUI.apply_pixel_font(empty_label)
		empty_label.add_theme_font_size_override("font_size", PixelUI.scale_font_size(20))
		container.add_child(empty_label)
		return

	for value in values:
		var value_text: String = str(value)
		var badge: PanelContainer = PanelContainer.new()
		badge.custom_minimum_size = STATUS_BADGE_SIZE
		badge.mouse_filter = Control.MOUSE_FILTER_STOP
		
		# Tooltip logic
		var description = _get_tooltip_for_status_badge(value_text, empty_text)
		badge.mouse_entered.connect(_on_element_mouse_entered.bind(description, badge))
		badge.mouse_exited.connect(_on_element_mouse_exited)
		_connect_passthrough_click(badge)
		
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.set_border_width_all(2)
		style.border_color = _get_badge_border_color(value_text, empty_text)
		style.bg_color = Color(0, 0, 0, 0) # Transparent background
		badge.add_theme_stylebox_override("panel", style)

		var row: HBoxContainer = HBoxContainer.new()
		row.name = "Row"
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 6)
		badge.add_child(row)

		var icon_kind: String = _get_status_icon_kind(value_text, empty_text)
		if icon_kind != "":
			var icon_rect: TextureRect = TextureRect.new()
			icon_rect.mouse_filter = Control.MOUSE_FILTER_PASS
			icon_rect.custom_minimum_size = STATUS_ICON_SIZE
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			icon_rect.texture = _get_icon_texture(icon_kind)
			row.add_child(icon_rect)

		var text_label: Label = Label.new()
		text_label.mouse_filter = Control.MOUSE_FILTER_PASS
		text_label.text = _format_badge_text(value_text, empty_text)
		text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		PixelUI.apply_pixel_font(text_label)
		text_label.add_theme_font_size_override("font_size", PixelUI.scale_font_size(STATUS_TEXT_SIZE))
		text_label.add_theme_color_override("font_color", _get_badge_font_color(value_text, empty_text))
		text_label.add_theme_constant_override("outline_size", 3)
		text_label.add_theme_color_override("font_outline_color", Color(0.03, 0.04, 0.07, 0.95))
		row.add_child(text_label)
		container.add_child(badge)


func setup_card(display_name: String, current_hp: int, max_hp: int, dice_result: String, ability_text: String, target_text: String, target_side: String, status_list: Array, gear_list: Array, xp_ratio: float, is_dead: bool, accent_color: Color, portrait_texture: Texture2D = null, tooltip_text: String = "", ability_chart_rows: Array = [], active_zone: String = "") -> void:
	var portrait: TextureRect = get_node("%Portrait")
	var portrait_frame: Control = get_node("%PortraitFrame")
	var portrait_aspect: AspectRatioContainer = get_node("%PortraitAspect")
	var name_label: Label = get_node("%NameLabel")
	var hp_bar: ProgressBar = _resolve_hp_bar()
	var hp_label: Label = _resolve_hp_label(hp_bar)
	var target_label: Label = get_node("%TargetLabel")
	var status_title: Label = get_node("%StatusTitle")
	var gear_title: Label = get_node("%GearTitle")
	var status_effects: Container = get_node("%StatusEffects")
	var gear_slots: Container = get_node("%GearSlots")
	var xp_bar: ProgressBar = get_node("%XPBar")
	var card_frame: Panel = get_node("%CardFrame")
	var dice_chart_panel: PanelContainer = get_node_or_null("%DiceChartPanel")
	if dice_chart_panel == null:
		dice_chart_panel = get_node("CardFrame/Margin/VBox/DiceChartPanel")
	var tooltip_label: Label = get_node("%TooltipLabel")
	var dice_chart: VBoxContainer = get_node("%DiceChart")
	_ability_detail_rows = ability_chart_rows.duplicate(true)
	_gear_detail_rows = gear_list.duplicate(true)
	_detail_unit_name = display_name
	_detail_current_hp = current_hp
	_detail_max_hp = max_hp
	_detail_dice_result = dice_result
	_detail_ability_text = ability_text
	_detail_target_text = target_text
	_detail_target_side = target_side
	_detail_status_list = status_list.duplicate()
	_detail_xp_ratio = xp_ratio
	_detail_is_dead = is_dead
	_detail_accent_color = accent_color

	_configure_fixed_card_lanes(name_label, target_label, status_title, hp_bar, portrait_frame, portrait_aspect)
	name_label.text = display_name
	_fit_name_label(name_label, display_name)
	if hp_bar != null and hp_label != null:
		_place_hp_label_in_bar(hp_label, hp_bar)
		PixelUI.style_label(hp_label, 24, Color(0.02, 0.04, 0.04, 1.0), 5)
		hp_label.add_theme_color_override("font_outline_color", Color(0.86, 1.0, 0.88, 0.96))
		
		hp_bar.mouse_filter = Control.MOUSE_FILTER_PASS
		hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			
	PixelUI.style_label(target_label, 14, _get_target_text_color(target_side, target_text), 3)
	PixelUI.style_label(status_title, 14, PixelUI.TEXT_MUTED, 3)
	target_label.visible = false
	status_title.visible = false
	PixelUI.apply_pixel_font(tooltip_label)
	if hp_bar != null:
		hp_bar.max_value = max(max_hp, 1)
		hp_bar.value = clamp(current_hp, 0, max_hp)
	if hp_label != null:
		hp_label.text = "%d/%d" % [current_hp, max_hp]
	target_label.text = "Target: %s" % _get_first_target_word(target_text)
	xp_bar.value = clampf(xp_ratio, 0.0, 1.0) * 100.0
	
	# Connect tooltips for XP
	xp_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	if not xp_bar.mouse_entered.is_connected(_on_element_mouse_entered):
		xp_bar.mouse_entered.connect(_on_element_mouse_entered.bind(TOOLTIP_MAP.XP, xp_bar))
		xp_bar.mouse_exited.connect(_on_element_mouse_exited)
	_connect_passthrough_click(xp_bar)
	
	portrait.texture = portrait_texture
	portrait_aspect.ratio = HERO_PORTRAIT_RATIO
	if portrait_texture != null:
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	
	# Ability details
	_populate_dice_chart(dice_chart, ability_chart_rows, active_zone)
	status_effects.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_populate_badges(status_effects, status_list, "STATUS")
	gear_title.visible = false
	gear_slots.visible = false
	_ensure_details_controls()
	_refresh_details_controls()
	_apply_ability_sheet_style(dice_chart_panel)
	_apply_visual_state(card_frame, portrait_frame, portrait, hp_bar, current_hp, max_hp, is_dead, accent_color, active_zone)
	
	# Only hide tooltip if mouse is NOT over anything on this card anymore
	if _hovered_node == null:
		_hide_tooltip()
	else:
		# Update tooltip text in case it changed (e.g. status value changed)
		_show_tooltip(_hovered_element_text)


func _configure_fixed_card_lanes(name_label: Label, target_label: Label, status_title: Label, hp_bar: ProgressBar, portrait_frame: Control, portrait_aspect: AspectRatioContainer) -> void:
	for label in [name_label, target_label, status_title]:
		if label == null:
			continue
		label.custom_minimum_size.x = 0.0
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.autowrap_mode = TextServer.AUTOWRAP_OFF

	var info_column: Control = get_node_or_null("%InfoColumn") as Control
	if info_column != null:
		info_column.custom_minimum_size.x = 0.0
		info_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_column.clip_contents = true

	var status_effects: Control = get_node_or_null("%StatusEffects") as Control
	if status_effects != null:
		status_effects.custom_minimum_size.x = 0.0
		status_effects.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		status_effects.clip_contents = true

	var hp_row: Control = hp_bar.get_parent() as Control if hp_bar != null else null
	if hp_row != null:
		hp_row.custom_minimum_size.x = 0.0
		hp_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if hp_bar != null:
		hp_bar.custom_minimum_size.x = 0.0
		hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var portrait_margin: Control = get_node_or_null("CardFrame/Margin/VBox/BodyRow/PortraitMargin") as Control
	if portrait_margin != null:
		portrait_margin.custom_minimum_size = Vector2(BATTLE_PORTRAIT_WIDTH, 0)
		portrait_margin.size_flags_horizontal = Control.SIZE_SHRINK_END
		portrait_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if portrait_aspect != null:
		portrait_aspect.ratio = HERO_PORTRAIT_RATIO
	if portrait_frame != null:
		portrait_frame.custom_minimum_size = Vector2(BATTLE_PORTRAIT_WIDTH, BATTLE_PORTRAIT_HEIGHT)


func _get_first_target_word(target_text: String) -> String:
	var clean_text := target_text.strip_edges()
	if clean_text == "" or clean_text == "--":
		return clean_text
	return clean_text.split(" ", false, 1)[0]


func _get_target_text_color(target_side: String, target_text: String) -> Color:
	var clean_text := target_text.strip_edges()
	if clean_text == "" or clean_text == "--":
		return PixelUI.TEXT_MUTED
	if target_side == "hero":
		return Color(0.60, 0.92, 0.68, 1.0)
	if target_side == "enemy":
		return Color(1.0, 0.58, 0.56, 1.0)
	return PixelUI.TEXT_MUTED


func set_selected(is_selected: bool) -> void:
	_is_selected_source = is_selected
	_apply_highlight_state()


func set_targetable(is_targetable: bool) -> void:
	_is_targetable = is_targetable
	if not _is_targetable:
		_is_target_hovered = false
	_apply_highlight_state()


func play_action_feedback(kind: String = "neutral") -> void:
	var portrait_frame: Control = get_node_or_null("%PortraitFrame") as Control
	var portrait: CanvasItem = get_node_or_null("%Portrait") as CanvasItem
	var target: Control = portrait_frame if portrait_frame != null else self
	var flash_target: CanvasItem = portrait if portrait != null else self
	var original_position: Vector2 = target.position
	var original_modulate: Color = flash_target.modulate
	var flash_color: Color = Color(1.0, 1.0, 0.78, 1.0)
	var shake_amount: float = 3.0
	match kind:
		"attack":
			flash_color = Color(1.0, 0.72, 0.62, 1.0)
			shake_amount = 5.0
		"support":
			flash_color = Color(0.58, 0.82, 1.0, 1.0)
			shake_amount = 2.0

	var flash: Tween = create_tween()
	flash.tween_property(flash_target, "modulate", flash_color, 0.06)
	flash.tween_property(flash_target, "modulate", original_modulate, 0.16)

	var shake: Tween = create_tween()
	shake.tween_property(target, "position", original_position + Vector2(shake_amount, 0.0), 0.045)
	shake.tween_property(target, "position", original_position + Vector2(-shake_amount, 0.0), 0.06)
	shake.tween_property(target, "position", original_position + Vector2(shake_amount * 0.45, 0.0), 0.045)
	shake.tween_property(target, "position", original_position, 0.055)


func play_impact_feedback(kind: String = "damage") -> void:
	var portrait: CanvasItem = get_node_or_null("%Portrait") as CanvasItem
	var target: CanvasItem = portrait if portrait != null else self
	var original_modulate: Color = target.modulate
	var flash_color: Color = Color(1.0, 0.36, 0.36, 1.0)
	match kind:
		"shield", "support":
			flash_color = Color(0.45, 0.74, 1.0, 1.0)
		"heal":
			flash_color = Color(0.45, 1.0, 0.62, 1.0)

	var tween: Tween = create_tween()
	tween.tween_property(target, "modulate", flash_color, 0.08)
	tween.tween_property(target, "modulate", original_modulate, 0.18)


func set_interaction_enabled(is_enabled: bool) -> void:
	var click_button: Button = get_node("ClickButton")
	click_button.disabled = not is_enabled
	click_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if is_enabled else Control.CURSOR_ARROW
	var card_frame: Panel = get_node("CardFrame")
	card_frame.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if is_enabled else Control.CURSOR_ARROW


func _apply_highlight_state() -> void:
	var card_frame: Panel = get_node("CardFrame")
	var existing_style: StyleBoxFlat = card_frame.get_theme_stylebox("panel") as StyleBoxFlat
	if existing_style == null:
		return
	var style: StyleBoxFlat = existing_style.duplicate() as StyleBoxFlat
	style.border_color = _base_card_border_color
	style.set_border_width_all(_base_card_border_width)
	style.shadow_color = PixelUI.BLACK_EDGE
	style.shadow_size = 0
	if _is_targetable and _is_target_hovered:
		style.border_color = Color(1.0, 0.28, 0.24, 1.0)
		style.set_border_width_all(4)
		style.shadow_color = Color(0.30, 0.02, 0.02, 0.95)
		style.shadow_size = 6
	elif _is_selected_source:
		style.border_color = PixelUI.GOLD_ACCENT
		style.shadow_color = PixelUI.BLACK_EDGE
		style.shadow_size = 0
	elif _is_targetable:
		style.border_color = Color(0.34, 0.92, 0.48, 1.0)
		style.set_border_width_all(4)
		style.shadow_color = Color(0.02, 0.18, 0.05, 0.92)
		style.shadow_size = 4
	card_frame.add_theme_stylebox_override("panel", style)


func _get_tooltip_for_chip(chip: Dictionary, icon_kind: String) -> String:
	var tooltip: String = str(chip.get("tooltip", "")).strip_edges()
	if tooltip != "":
		return _professionalize_tooltip_text(tooltip)
	var value = _get_chip_value_text(chip)
	if value == "A":
		return "Affects all valid targets."
	if value == "ALL":
		return "Affects all allies."
	if value == "T":
		return "Uses manual ally targeting."
	if icon_kind == "damage":
		return "Deals %s damage." % value
	if icon_kind == "shield":
		return "Grants %s shield." % value
	if icon_kind == "heal":
		return "Restores %s health." % value
	if icon_kind == "dot":
		return "Inflicts %s poison." % value
	if icon_kind == "dice":
		return "Modifies the roll by %s." % value
	if icon_kind == "frost":
		return "Freezes a die for %s reveal." % value
	
	if TOOLTIP_MAP.has(icon_kind.to_upper()):
		return TOOLTIP_MAP[icon_kind.to_upper()]
	return value

func _get_tooltip_for_status_badge(value_text: String, empty_text: String) -> String:
	if empty_text == "GEAR":
		return "Item: %s." % value_text
		
	for key in TOOLTIP_MAP.keys():
		if value_text.begins_with(key):
			return TOOLTIP_MAP[key]
	
	if TOOLTIP_MAP.has(value_text):
		return TOOLTIP_MAP[value_text]
		
	return _professionalize_tooltip_text(value_text)


func _professionalize_tooltip_text(text: String) -> String:
	var clean_text: String = text.strip_edges()
	if clean_text == "":
		return ""
	clean_text = clean_text.replace("\r\n", "\n")
	clean_text = clean_text.replace(" | ", "\n")
	clean_text = clean_text.replace("  ", " ")
	var source_lines: PackedStringArray = clean_text.split("\n")
	var lines: Array[String] = []
	for source_line in source_lines:
		for part in String(source_line).split(",", false):
			var line: String = _professionalize_tooltip_fragment(String(part))
			if line != "":
				lines.append(line)
	return "\n".join(lines)


func _professionalize_tooltip_fragment(fragment: String) -> String:
	var line: String = fragment.strip_edges()
	if line == "":
		return ""
	var lower_line: String = line.to_lower()
	if lower_line.ends_with("t") and lower_line.left(lower_line.length() - 1).is_valid_int():
		var turns: int = int(lower_line.left(lower_line.length() - 1))
		return "Lasts %d %s." % [turns, "turn" if turns == 1 else "turns"]
	line = line.replace("dmg", "Damage")
	line = line.replace("Dmg", "Damage")
	line = line.replace("DMG", "Damage")
	line = line.replace("DoT", "Poison")
	line = line.replace("dot", "Poison")
	line = line.replace("HP", "Health")
	line = line.replace("eff", "Effect")
	if line.length() > 0:
		line = line.left(1).to_upper() + line.substr(1)
	if not line.ends_with(".") and not line.ends_with("!") and not line.ends_with("?"):
		line += "."
	return line

func _populate_dice_chart(container: VBoxContainer, rows: Array, active_zone: String) -> void:
	# Optimization: Only rebuild if content changed to prevent flickering
	var row_ids = []
	for r in rows:
		row_ids.append(str(r.get("range_text", "")) + str(r.get("ability_name", "")) + str(r.get("zone", "")) + str(r.get("has_overload_marker", false)) + str(r.get("overload_ability_name", "")))
	var current_row_ids = container.get_meta("row_ids", [])
	var current_active_zone = container.get_meta("active_zone", "")

	if str(row_ids) == str(current_row_ids) and active_zone == current_active_zone:
		return

	container.set_meta("row_ids", row_ids)
	container.set_meta("active_zone", active_zone)

	for child in container.get_children():
		child.queue_free()

	container.add_theme_constant_override("separation", 4)
	var has_merged_overload_marker: bool = false
	for row_variant in rows:
		var marker_row: Dictionary = row_variant
		if bool(marker_row.get("has_overload_marker", false)):
			has_merged_overload_marker = true
			break
	var visual_active_zone: String = "crit" if active_zone == "overload" and has_merged_overload_marker else active_zone
	var is_overload_active: bool = active_zone == "overload" and has_merged_overload_marker

	# Resolve active row and store tooltip for card-level long-press
	var active_row: Dictionary = {}
	for row_variant in rows:
		var row_data: Dictionary = row_variant
		if str(row_data.get("zone", "")) == visual_active_zone:
			active_row = row_data
			break
	if is_overload_active and not active_row.is_empty() and active_row.has("overload_description"):
		_active_ability_tooltip = _professionalize_tooltip_text(str(active_row.get("overload_description", "")))
	else:
		_active_ability_tooltip = _get_ability_row_description(active_row) if not active_row.is_empty() else ""

	var display_rows: Array = rows

	# Range strip — one tab per ability column, equal widths
	var range_strip: HBoxContainer = HBoxContainer.new()
	range_strip.mouse_filter = Control.MOUSE_FILTER_PASS
	range_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	range_strip.add_theme_constant_override("separation", 4)
	container.add_child(range_strip)

	for row_variant in display_rows:
		var row_data: Dictionary = row_variant
		var is_active_row: bool = str(row_data.get("zone", "")) == visual_active_zone
		var range_tab: Control = _make_range_tab(row_data, is_active_row)
		range_strip.add_child(range_tab)

	# Chip strip — one column per ability, widths match range_strip columns
	var chip_strip: HBoxContainer = HBoxContainer.new()
	chip_strip.mouse_filter = Control.MOUSE_FILTER_PASS
	chip_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip_strip.add_theme_constant_override("separation", 4)
	container.add_child(chip_strip)

	for row_variant in display_rows:
		var row_data: Dictionary = row_variant
		var chip_col: VBoxContainer = VBoxContainer.new()
		chip_col.mouse_filter = Control.MOUSE_FILTER_PASS
		chip_col.custom_minimum_size = Vector2(0, 52)
		chip_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip_col.alignment = BoxContainer.ALIGNMENT_CENTER
		chip_strip.add_child(chip_col)
		if active_row.is_empty() or str(row_data.get("zone", "")) != visual_active_zone:
			continue

		var active_display_row: Dictionary = _get_active_chart_row(row_data, is_overload_active)

		var chip_box: BoxContainer = HBoxContainer.new()
		chip_box.mouse_filter = Control.MOUSE_FILTER_PASS
		chip_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip_box.alignment = BoxContainer.ALIGNMENT_CENTER
		chip_box.add_theme_constant_override("separation", 4)
		chip_col.add_child(chip_box)

		if bool(active_display_row.get("is_overload_active", false)):
			chip_box.add_child(_make_crit_badge())
		var chip_size: Vector2 = Vector2(0, ABILITY_CHIP_HEIGHT)
		var icon_size: Vector2 = ABILITY_CHIP_ICON_SIZE
		var font_size: int = ABILITY_CHIP_TEXT_SIZE
		_add_effect_chips_to_box(chip_box, active_display_row.get("chips", []), chip_size, icon_size, font_size)


func _get_active_chart_row(row_data: Dictionary, is_overload_active: bool) -> Dictionary:
	var active_row: Dictionary = row_data.duplicate(true)
	if is_overload_active:
		var active_chips: Array = row_data.get("overload_chips", row_data.get("chips", []))
		active_row["ability_name"] = str(row_data.get("overload_ability_name", row_data.get("ability_name", "")))
		active_row["description"] = str(row_data.get("overload_description", row_data.get("description", "")))
		active_row["chips"] = active_chips.duplicate(true)
		active_row["is_overload_active"] = true
	return active_row


func _make_range_tab(row_data: Dictionary, is_active_row: bool) -> PanelContainer:
	var range_panel: PanelContainer = PanelContainer.new()
	var tooltip_text = _get_ability_row_tooltip(row_data)
	range_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	range_panel.mouse_entered.connect(_on_element_mouse_entered.bind(tooltip_text, range_panel))
	range_panel.mouse_exited.connect(_on_element_mouse_exited)
	_connect_passthrough_click(range_panel)
	range_panel.custom_minimum_size = Vector2(0, 38)
	range_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	range_panel.add_theme_stylebox_override("panel", _make_range_tab_style(is_active_row))

	var range_row: HBoxContainer = HBoxContainer.new()
	range_row.mouse_filter = Control.MOUSE_FILTER_PASS
	range_row.alignment = BoxContainer.ALIGNMENT_CENTER
	range_row.add_theme_constant_override("separation", 3)
	range_panel.add_child(range_row)

	var range_label: Label = Label.new()
	range_label.text = str(row_data.get("range_text", ""))
	range_label.mouse_filter = Control.MOUSE_FILTER_PASS
	range_label.custom_minimum_size = Vector2(0, 38)
	range_label.clip_text = true
	range_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	range_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	range_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	PixelUI.apply_pixel_font(range_label)
	range_label.add_theme_font_size_override("font_size", PixelUI.scale_font_size(24))
	range_label.add_theme_color_override("font_color", Color(0.90, 0.94, 1.0, 1.0) if is_active_row else PixelUI.TEXT_MUTED)
	range_label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.95))
	range_label.add_theme_constant_override("outline_size", 3)
	range_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	range_row.add_child(range_label)

	if bool(row_data.get("has_overload_marker", false)):
		var star_label: Label = Label.new()
		star_label.text = "★"
		star_label.mouse_filter = Control.MOUSE_FILTER_PASS
		star_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		PixelUI.apply_pixel_font(star_label)
		star_label.add_theme_font_size_override("font_size", PixelUI.scale_font_size(24))
		star_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.28, 1.0))
		star_label.add_theme_color_override("font_outline_color", Color(0.10, 0.05, 0.00, 0.95))
		star_label.add_theme_constant_override("outline_size", 3)
		range_row.add_child(star_label)
	return range_panel


func _place_hp_label_in_bar(hp_label: Label, hp_bar: ProgressBar) -> void:
	if hp_label == null or hp_bar == null:
		return
	if hp_label.get_parent() != hp_bar:
		var old_parent: Node = hp_label.get_parent()
		if old_parent != null:
			old_parent.remove_child(hp_label)
		hp_bar.add_child(hp_label)
	hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hp_label.offset_left = 8.0
	hp_label.offset_right = -6.0
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_label.size_flags_vertical = Control.SIZE_EXPAND_FILL


func _place_hp_row_above_target(hp_bar: ProgressBar, target_label: Label) -> void:
	if hp_bar == null or target_label == null:
		return
	var hp_row: Control = hp_bar.get_parent() as Control
	var info_column: VBoxContainer = target_label.get_parent() as VBoxContainer
	if hp_row == null or info_column == null:
		return
	if hp_row.get_parent() != info_column:
		var old_parent: Node = hp_row.get_parent()
		if old_parent != null:
			old_parent.remove_child(hp_row)
		info_column.add_child(hp_row)
	elif hp_row.get_index() < target_label.get_index():
		hp_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		return
	info_column.move_child(hp_row, target_label.get_index())
	hp_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _resolve_hp_bar() -> ProgressBar:
	var hp_bar: ProgressBar = get_node_or_null("%HPBar") as ProgressBar
	if hp_bar != null:
		return hp_bar
	hp_bar = find_child("HPBar", true, false) as ProgressBar
	if hp_bar != null:
		return hp_bar
	return get_node_or_null("CardFrame/Margin/VBox/BodyRow/InfoColumn/BarStack/HPRow/HPBar") as ProgressBar


func _resolve_hp_label(hp_bar: ProgressBar) -> Label:
	var hp_label: Label = get_node_or_null("%HPLabel") as Label
	if hp_label != null:
		return hp_label
	hp_label = find_child("HPLabel", true, false) as Label
	if hp_label != null:
		return hp_label
	hp_label = get_node_or_null("CardFrame/Margin/VBox/HPLabel") as Label
	if hp_label != null:
		return hp_label
	if hp_bar != null:
		hp_label = hp_bar.get_node_or_null("HPLabel") as Label
		if hp_label != null:
			return hp_label
		hp_label = Label.new()
		hp_label.name = "HPLabel"
		hp_label.unique_name_in_owner = true
		hp_bar.add_child(hp_label)
	return hp_label


func _wire_card_frame_input() -> void:
	var click_button: Button = get_node_or_null("ClickButton") as Button
	if click_button != null:
		click_button.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var card_frame: Panel = get_node_or_null("CardFrame") as Panel
	if card_frame == null:
		return
	card_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	if not card_frame.gui_input.is_connected(_on_card_frame_gui_input):
		card_frame.gui_input.connect(_on_card_frame_gui_input)
	if not card_frame.mouse_entered.is_connected(_on_card_frame_mouse_entered):
		card_frame.mouse_entered.connect(_on_card_frame_mouse_entered)
	if not card_frame.mouse_exited.is_connected(_on_card_frame_mouse_exited):
		card_frame.mouse_exited.connect(_on_card_frame_mouse_exited)
	_make_descendants_pass_mouse(card_frame)


func _make_descendants_pass_mouse(node: Node) -> void:
	for child in node.get_children():
		var control: Control = child as Control
		if control != null:
			control.mouse_filter = Control.MOUSE_FILTER_PASS
		_make_descendants_pass_mouse(child)


func _on_card_frame_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_event.pressed:
			_on_click_button_down()
		else:
			_on_click_button_up()
	elif event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event
		if touch_event.pressed:
			_on_click_button_down()
		else:
			_on_click_button_up()


func _on_card_frame_mouse_entered() -> void:
	if not _is_targetable:
		return
	_is_target_hovered = true
	_apply_highlight_state()


func _on_card_frame_mouse_exited() -> void:
	if not _is_target_hovered:
		return
	_is_target_hovered = false
	_apply_highlight_state()


func _make_range_tab_style(is_active_row: bool) -> StyleBoxFlat:
	var range_style: StyleBoxFlat = StyleBoxFlat.new()
	range_style.bg_color = Color(0.08, 0.13, 0.18, 0.46)
	range_style.border_color = Color(0.18, 0.34, 0.50, 0.72)
	range_style.set_border_width_all(2)
	range_style.corner_radius_top_left = 0
	range_style.corner_radius_top_right = 0
	range_style.corner_radius_bottom_left = 0
	range_style.corner_radius_bottom_right = 0
	if is_active_row:
		range_style.bg_color = Color(0.13, 0.23, 0.34, 0.62)
		range_style.border_color = Color(0.46, 0.68, 0.88, 0.86)
		range_style.set_border_width_all(2)
	return range_style


func _make_detail_panel_style(has_active_row: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.090, 0.130, 0.54) if has_active_row else Color(0.030, 0.050, 0.075, 0.32)
	style.border_color = Color(0.42, 0.62, 0.78, 0.76) if has_active_row else Color(0.16, 0.28, 0.42, 0.55)
	style.set_border_width_all(3)
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.set_content_margin(SIDE_LEFT, 0.0)
	style.set_content_margin(SIDE_TOP, 0.0)
	style.set_content_margin(SIDE_RIGHT, 0.0)
	style.set_content_margin(SIDE_BOTTOM, 0.0)
	return style


func _get_ability_row_tooltip(row_data: Dictionary) -> String:
	var parts: Array = [str(row_data.get("range_text", "")), str(row_data.get("ability_name", ""))]
	var chip_texts: Array = []
	for chip_variant in row_data.get("chips", []):
		var chip: Dictionary = chip_variant
		var icon_kind: String = _get_chip_icon_kind(chip)
		var chip_text: String = _get_tooltip_for_chip(chip, icon_kind)
		if chip_text != "":
			chip_texts.append(chip_text)
	if not chip_texts.is_empty():
		parts.append(" ".join(chip_texts))
	return "\n".join(parts)


func _get_ability_row_description(row_data: Dictionary) -> String:
	var description: String = str(row_data.get("description", "")).strip_edges()
	if description != "":
		return _professionalize_tooltip_text(description)
	return _get_ability_row_tooltip(row_data)


func _make_crit_badge() -> PanelContainer:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.34, 0.20, 0.02, 0.92)
	style.border_color = Color(1.0, 0.74, 0.20, 0.95)
	style.set_border_width_all(2)
	style.set_content_margin(SIDE_LEFT, 6.0)
	style.set_content_margin(SIDE_TOP, 3.0)
	style.set_content_margin(SIDE_RIGHT, 6.0)
	style.set_content_margin(SIDE_BOTTOM, 3.0)
	var panel: PanelContainer = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_theme_stylebox_override("panel", style)
	var label: Label = Label.new()
	label.text = "★ CRIT"
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	PixelUI.apply_pixel_font(label)
	label.add_theme_font_size_override("font_size", PixelUI.scale_font_size(20))
	label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.38, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.09, 0.04, 0.00, 1.0))
	label.add_theme_constant_override("outline_size", 3)
	panel.add_child(label)
	return panel


func _add_effect_chips_to_box(chip_box: BoxContainer, chips: Array, chip_size: Vector2, icon_size: Vector2, font_size: int) -> void:
	if chips.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "-"
		empty_label.mouse_filter = Control.MOUSE_FILTER_PASS
		empty_label.modulate = Color(0.44, 0.50, 0.60, 0.9)
		chip_box.add_child(empty_label)
		return

	for chip_variant in chips:
		var chip: Dictionary = chip_variant
		var chip_style: StyleBoxFlat = StyleBoxFlat.new()
		var chip_base_color: Color = chip.get("color", Color(0.24, 0.28, 0.36, 0.98))
		# Transparent background with colored border
		chip_style.bg_color = Color(0, 0, 0, 0)
		chip_style.border_color = chip_base_color
		chip_style.set_border_width_all(2)
		chip_style.corner_radius_top_left = 0
		chip_style.corner_radius_top_right = 0
		chip_style.corner_radius_bottom_left = 0
		chip_style.corner_radius_bottom_right = 0
		chip_style.set_content_margin(SIDE_LEFT, 6.0)
		chip_style.set_content_margin(SIDE_TOP, 3.0)
		chip_style.set_content_margin(SIDE_RIGHT, 6.0)
		chip_style.set_content_margin(SIDE_BOTTOM, 3.0)

		var chip_panel: PanelContainer = PanelContainer.new()
		chip_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		chip_panel.custom_minimum_size = Vector2(0, chip_size.y)
		chip_panel.add_theme_stylebox_override("panel", chip_style)
		chip_box.add_child(chip_panel)
		
		# Add tooltip for the chip
		var icon_kind_for_tooltip: String = _get_chip_icon_kind(chip)
		var tooltip_text = _get_tooltip_for_chip(chip, icon_kind_for_tooltip)
		chip_panel.mouse_entered.connect(_on_element_mouse_entered.bind(tooltip_text, chip_panel))
		chip_panel.mouse_exited.connect(_on_element_mouse_exited)
		_connect_passthrough_click(chip_panel)

		var chip_row: HBoxContainer = HBoxContainer.new()
		chip_row.mouse_filter = Control.MOUSE_FILTER_PASS
		chip_row.alignment = BoxContainer.ALIGNMENT_CENTER
		chip_row.add_theme_constant_override("separation", 4)
		chip_panel.add_child(chip_row)

		var icon_kind: String = _get_chip_icon_kind(chip)
		if icon_kind != "":
			var icon_rect: TextureRect = TextureRect.new()
			icon_rect.mouse_filter = Control.MOUSE_FILTER_PASS
			icon_rect.custom_minimum_size = icon_size
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			icon_rect.texture = _get_icon_texture(icon_kind)
			# Only modulate if icon is grayscale or needs specific coloring
			# icon_rect.modulate = _get_chip_icon_color(chip)
			chip_row.add_child(icon_rect)

		var value_label: Label = Label.new()
		value_label.text = _get_chip_value_text(chip)
		value_label.mouse_filter = Control.MOUSE_FILTER_PASS
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		PixelUI.apply_pixel_font(value_label)
		value_label.add_theme_font_size_override("font_size", PixelUI.scale_font_size(font_size))
		value_label.add_theme_color_override("font_color", Color(0.97, 0.98, 1.0, 1.0))
		value_label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.95))
		value_label.add_theme_constant_override("outline_size", 3)
		chip_row.add_child(value_label)

		var duration: int = int(chip.get("duration", 0))
		if duration > 1:
			var clock_label: Label = _make_chip_duration_label("⏱", maxi(16, font_size - 7), Color(0.96, 0.90, 0.68, 1.0))
			chip_row.add_child(clock_label)
			var duration_label: Label = _make_chip_duration_label("%d" % duration, maxi(16, font_size - 5), Color(0.97, 0.98, 1.0, 1.0))
			chip_row.add_child(duration_label)


func _make_chip_duration_label(text: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	PixelUI.apply_pixel_font(label)
	label.add_theme_font_size_override("font_size", PixelUI.scale_font_size(font_size))
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.95))
	label.add_theme_constant_override("outline_size", 3)
	return label


func _apply_ability_sheet_style(panel: PanelContainer) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.020, 0.038, 0.060, 0.46)
	style.border_color = Color(0.12, 0.24, 0.36, 0.58)
	style.set_border_width_all(3)
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.set_content_margin(SIDE_LEFT, 0.0)
	style.set_content_margin(SIDE_TOP, 3.0)
	style.set_content_margin(SIDE_RIGHT, 0.0)
	style.set_content_margin(SIDE_BOTTOM, 3.0)
	panel.add_theme_stylebox_override("panel", style)


func _apply_visual_state(card_frame: Panel, portrait_frame: PanelContainer, portrait: TextureRect, hp_bar: ProgressBar, current_hp: int, max_hp: int, is_dead: bool, accent_color: Color, active_zone: String) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.026, 0.044, 0.066, 0.68)
	style.border_color = accent_color.lightened(0.12)
	style.set_border_width_all(3)
	_base_card_border_color = style.border_color
	_base_card_border_width = 3
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.shadow_color = PixelUI.BLACK_EDGE
	style.shadow_size = 0
	style.shadow_offset = Vector2.ZERO
	card_frame.add_theme_stylebox_override("panel", style)

	var portrait_style: StyleBoxFlat = StyleBoxFlat.new()
	portrait_style.bg_color = Color(0.018, 0.030, 0.050, 0.62)
	portrait_style.border_color = accent_color.lightened(0.12)
	portrait_style.set_border_width_all(2)
	portrait_style.corner_radius_top_left = 0
	portrait_style.corner_radius_top_right = 0
	portrait_style.corner_radius_bottom_left = 0
	portrait_style.corner_radius_bottom_right = 0
	portrait_frame.add_theme_stylebox_override("panel", portrait_style)

	portrait.modulate = Color(1, 1, 1, 1) if portrait.texture != null else accent_color.darkened(0.18)
	modulate = Color(1, 1, 1, 1)
	var hp_fill: Color = Color(0.20, 0.62, 0.40, 1)
	var xp_bar: ProgressBar = get_node("%XPBar")
	PixelUI.style_progress_bar(xp_bar, Color(0.35, 0.68, 1.0, 1), Color(0.015, 0.020, 0.035, 1.0), Color(0.18, 0.28, 0.42, 1.0))

	if is_dead:
		modulate = Color(0.50, 0.52, 0.58, 0.58)
		portrait.modulate = Color(0.38, 0.40, 0.46, 0.55)
		hp_fill = Color(0.36, 0.38, 0.44, 1)
	PixelUI.style_progress_bar(hp_bar, hp_fill, Color(0.015, 0.020, 0.035, 1.0), Color(0.18, 0.28, 0.42, 1.0))


func _get_badge_color(value_text: String, empty_text: String) -> Color:
	if empty_text == "GEAR":
		return Color(0.20, 0.23, 0.36, 0.98)
	# Shield
	if value_text.begins_with("SH"):
		return Color(0.16, 0.34, 0.50, 0.98)
	# Poison / DoT
	if value_text.begins_with("POI"):
		return Color(0.36, 0.14, 0.36, 0.98)
	# Roll debuff (RFE)
	if value_text.begins_with("RFE"):
		return Color(0.44, 0.28, 0.08, 0.98)
	# Roll buff ("+N ROLL")
	if value_text.begins_with("+"):
		return Color(0.12, 0.36, 0.20, 0.98)
	# Cloak / evasion
	if value_text == "CLOAK":
		return Color(0.10, 0.26, 0.38, 0.98)
	# Cower (stunned / can't act)
	if value_text.begins_with("COWER"):
		return Color(0.30, 0.24, 0.14, 0.98)
	# Frozen die
	if value_text.begins_with("FROZEN"):
		return Color(0.12, 0.30, 0.46, 0.98)
	# Rampage charges
	if value_text.begins_with("RAGE"):
		return Color(0.44, 0.10, 0.10, 0.98)
	# Cursed (rolls twice, keeps lower)
	if value_text == "CURSED":
		return Color(0.26, 0.12, 0.36, 0.98)
	# Taunt (forces hero targeting)
	if value_text == "TAUNT":
		return Color(0.44, 0.22, 0.06, 0.98)
	# Counter chance
	if value_text.begins_with("CNTR"):
		return Color(0.18, 0.34, 0.14, 0.98)
	# Boss phase 2
	if value_text == "PHASE 2":
		return Color(0.44, 0.16, 0.04, 0.98)
	# Down / eliminated
	if value_text == "DOWN":
		return Color(0.34, 0.24, 0.24, 0.98)
	return Color(0.22, 0.28, 0.34, 0.98)


func _get_badge_font_color(value_text: String, empty_text: String) -> Color:
	if empty_text == "GEAR":
		return Color(0.95, 0.97, 1.0, 1.0)
	if value_text.begins_with("SH"):
		return Color(0.88, 0.96, 1.0, 1.0)
	if value_text.begins_with("POI"):
		return Color(1.0, 0.82, 1.0, 1.0)
	if value_text.begins_with("RFE"):
		return Color(1.0, 0.88, 0.62, 1.0)
	if value_text.begins_with("+"):
		return Color(0.80, 1.0, 0.82, 1.0)
	if value_text == "CLOAK":
		return Color(0.72, 0.96, 1.0, 1.0)
	if value_text.begins_with("COWER"):
		return Color(1.0, 0.94, 0.72, 1.0)
	if value_text.begins_with("FROZEN"):
		return Color(0.84, 0.96, 1.0, 1.0)
	if value_text.begins_with("RAGE"):
		return Color(1.0, 0.78, 0.78, 1.0)
	if value_text == "CURSED":
		return Color(0.90, 0.72, 1.0, 1.0)
	if value_text == "TAUNT":
		return Color(1.0, 0.86, 0.68, 1.0)
	if value_text.begins_with("CNTR"):
		return Color(0.84, 1.0, 0.76, 1.0)
	if value_text == "PHASE 2":
		return Color(1.0, 0.80, 0.60, 1.0)
	if value_text == "DOWN":
		return Color(1.0, 0.90, 0.90, 1.0)
	return Color(0.92, 0.95, 1.0, 1.0)


func _get_badge_border_color(value_text: String, empty_text: String) -> Color:
	if empty_text == "GEAR":
		return Color(0.60, 0.72, 0.94, 0.95)
	if value_text.begins_with("SH"):
		return Color(0.58, 0.84, 1.0, 0.95)
	if value_text.begins_with("POI"):
		return Color(0.90, 0.52, 0.90, 0.95)
	if value_text.begins_with("RFE"):
		return Color(1.0, 0.72, 0.28, 0.95)
	if value_text.begins_with("+"):
		return Color(0.52, 1.0, 0.64, 0.95)
	if value_text == "CLOAK":
		return Color(0.44, 0.92, 1.0, 0.95)
	if value_text.begins_with("COWER"):
		return Color(0.86, 0.76, 0.48, 0.95)
	if value_text.begins_with("FROZEN"):
		return Color(0.64, 0.92, 1.0, 0.95)
	if value_text.begins_with("RAGE"):
		return Color(1.0, 0.44, 0.44, 0.95)
	if value_text == "CURSED":
		return Color(0.76, 0.44, 1.0, 0.95)
	if value_text == "TAUNT":
		return Color(1.0, 0.60, 0.26, 0.95)
	if value_text.begins_with("CNTR"):
		return Color(0.56, 1.0, 0.48, 0.95)
	if value_text == "PHASE 2":
		return Color(1.0, 0.52, 0.22, 0.95)
	if value_text == "DOWN":
		return Color(0.92, 0.64, 0.64, 0.95)
	return Color(0.76, 0.84, 0.94, 0.95)


func _format_badge_text(value_text: String, empty_text: String) -> String:
	var cleaned = value_text
	# Strip all possible icon characters that might be in the source string
	# to avoid double-rendering with the new pixel art TextureRects.
	var icons_to_strip = [
		ICON_DAMAGE, ICON_HEAL, ICON_DOT, 
		"\u26B0", "\u26A1", "\u271A", "\u2620", 
		"⚡", "✚", "☠", "🛡️", "🎲", "♥"
	]
	for icon in icons_to_strip:
		cleaned = cleaned.replace(icon, "")
	cleaned = cleaned.strip_edges()
	
	if empty_text == "GEAR":
		return _shorten_gear_name(cleaned)
	if cleaned.begins_with("SH"):
		return cleaned.substr(2).strip_edges()
	if cleaned.begins_with("POI"):
		return cleaned.substr(3).strip_edges()
	if cleaned.begins_with("RFE"):
		return cleaned.substr(3).strip_edges()
	if cleaned.begins_with("+") and cleaned.contains("ROLL"):
		return cleaned.replace("ROLL", "").strip_edges()
	if cleaned.begins_with("FROZEN"):
		return cleaned.substr(6).strip_edges()
	return cleaned


func _get_status_icon_kind(value_text: String, empty_text: String) -> String:
	if empty_text == "GEAR":
		return ""
	if value_text.begins_with("SH"):
		return "shield"
	if value_text.begins_with("POI") or value_text == "DOWN":
		return "dot"
	if value_text.begins_with("RFE") or (value_text.begins_with("+") and value_text.contains("ROLL")):
		return "dice"
	if value_text.begins_with("FROZEN"):
		return "frost"
	return ""


func _get_empty_row_text(empty_text: String) -> String:
	if empty_text == "GEAR":
		return "No gear"
	return "No status"


func _shorten_gear_name(gear_name: String) -> String:
	if gear_name.length() <= 12:
		return gear_name
	var words: PackedStringArray = gear_name.split(" ")
	if words.size() >= 2:
		return "%s %s" % [words[0], words[1].left(3)]
	return gear_name.left(12)


func _apply_editor_preview_theme() -> void:
	var portrait: TextureRect = get_node("%Portrait")
	var portrait_frame: Control = get_node("%PortraitFrame")
	var hp_bar: ProgressBar = _resolve_hp_bar()
	var card_frame: Panel = get_node("CardFrame")
	var dice_chart_panel: PanelContainer = get_node("%DiceChartPanel")
	var dice_chart: VBoxContainer = get_node("%DiceChart")
	var status_effects: Container = get_node("%StatusEffects")
	var gear_slots: Container = get_node("%GearSlots")
	var gear_title: Label = get_node("%GearTitle")
	var tooltip_panel: PanelContainer = get_node("TooltipPanel")

	_apply_visual_state(card_frame, portrait_frame, portrait, hp_bar, 40, 40, false, Color(0.26, 0.78, 0.66, 1.0), "strike")
	_apply_ability_sheet_style(dice_chart_panel)
	_style_preview_dice_chart(dice_chart)
	_style_preview_badges(status_effects, "STATUS")
	gear_title.visible = false
	gear_slots.visible = false

	tooltip_panel.custom_minimum_size = Vector2(TOOLTIP_MIN_WIDTH, 72)
	_apply_tooltip_panel_style(tooltip_panel)
	tooltip_panel.visible = false


func _apply_tooltip_panel_style(tooltip_panel: PanelContainer) -> void:
	var tooltip_style: StyleBoxFlat = StyleBoxFlat.new()
	tooltip_style.bg_color = Color(0.018, 0.026, 0.044, 0.96)
	tooltip_style.border_color = Color(0.36, 0.55, 0.78, 0.92)
	tooltip_style.set_border_width_all(3)
	tooltip_style.corner_radius_top_left = 0
	tooltip_style.corner_radius_top_right = 0
	tooltip_style.corner_radius_bottom_left = 0
	tooltip_style.corner_radius_bottom_right = 0
	tooltip_panel.add_theme_stylebox_override("panel", tooltip_style)


func _fit_name_label(name_label: Label, display_name: String) -> void:
	PixelUI.apply_pixel_font(name_label)
	var font_size: int = 28
	name_label.add_theme_font_size_override("font_size", PixelUI.scale_font_size(font_size))


func _style_preview_dice_chart(container: VBoxContainer) -> void:
	for row_variant in container.get_children():
		var row: HBoxContainer = row_variant as HBoxContainer
		if row == null:
			continue
		var range_label: Label = row.get_child(0) as Label
		if range_label != null:
			range_label.custom_minimum_size = Vector2(64, 22)
			PixelUI.apply_pixel_font(range_label)
			range_label.add_theme_color_override("font_color", Color(0.90, 0.94, 1.0, 1.0))
			range_label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.95))
			range_label.add_theme_constant_override("outline_size", 3)
			var range_style: StyleBoxFlat = StyleBoxFlat.new()
			range_style.bg_color = Color(0.10, 0.13, 0.18, 1.0)
			range_style.border_color = PixelUI.BLACK_EDGE
			range_style.set_border_width_all(2)
			range_style.corner_radius_top_left = 0
			range_style.corner_radius_top_right = 0
			range_style.corner_radius_bottom_left = 0
			range_style.corner_radius_bottom_right = 0
			range_label.add_theme_stylebox_override("normal", range_style)

		var chip_row: Container = row.get_child(1) as Container
		if chip_row == null:
			continue
		for chip_variant in chip_row.get_children():
			var chip_label: Label = chip_variant as Label
			if chip_label == null:
				continue
			chip_label.custom_minimum_size = Vector2(58, 24)
			PixelUI.apply_pixel_font(chip_label)
			chip_label.add_theme_color_override("font_color", Color(0.97, 0.98, 1.0, 1.0))
			chip_label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.95))
			chip_label.add_theme_constant_override("outline_size", 3)
			var chip_style: StyleBoxFlat = StyleBoxFlat.new()
			if chip_label.text.contains(ICON_DAMAGE) or chip_label.text.begins_with("DMG"):
				chip_style.border_color = CHIP_DAMAGE_BG
			elif chip_label.text.begins_with("SH"):
				chip_style.border_color = CHIP_SHIELD_BG
			elif chip_label.text.contains(ICON_DOT) or chip_label.text.begins_with("DOT"):
				chip_style.border_color = CHIP_DOT_BG
			elif chip_label.text.contains(ICON_HEAL) or chip_label.text.begins_with("HEAL"):
				chip_style.border_color = CHIP_HEAL_BG
			else:
				chip_style.border_color = CHIP_DICE_BG
			chip_style.bg_color = Color(0, 0, 0, 0)
			chip_style.set_border_width_all(2)
			chip_style.corner_radius_top_left = 0
			chip_style.corner_radius_top_right = 0
			chip_style.corner_radius_bottom_left = 0
			chip_style.corner_radius_bottom_right = 0
			chip_label.add_theme_stylebox_override("normal", chip_style)


func _style_preview_badges(container: Container, badge_type: String) -> void:
	for child_variant in container.get_children():
		var badge: Label = child_variant as Label
		if badge == null:
			continue
		PixelUI.apply_pixel_font(badge)
		badge.add_theme_color_override("font_outline_color", Color(0.03, 0.04, 0.07, 0.95))
		badge.add_theme_constant_override("outline_size", 3)
		badge.add_theme_color_override("font_color", _get_badge_font_color(badge.text, badge_type))
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.corner_radius_top_left = 0
		style.corner_radius_top_right = 0
		style.corner_radius_bottom_left = 0
		style.corner_radius_bottom_right = 0
		style.set_border_width_all(2)
		# Transparent background with colored border
		style.border_color = _get_badge_border_color(badge.text, badge_type)
		style.bg_color = Color(0, 0, 0, 0)
		badge.add_theme_stylebox_override("normal", style)


func _get_chip_icon_kind(chip: Dictionary) -> String:
	var raw_text: String = str(chip.get("text", "")).strip_edges()
	var bg: Color = chip.get("color", Color(0.24, 0.28, 0.36, 0.98))
	if raw_text == "A" or raw_text == "ALL" or raw_text == "T":
		return ""
	if raw_text.begins_with("-"):
		return "dice"
	if bg.is_equal_approx(CHIP_HEAL_BG):
		return "heal"
	if bg.is_equal_approx(CHIP_SHIELD_BG):
		return "shield"
	if bg.is_equal_approx(CHIP_DOT_BG):
		return "dot"
	if bg.is_equal_approx(CHIP_DAMAGE_BG):
		return "damage"
	if bg.is_equal_approx(CHIP_FROST_BG):
		return "frost"
	return ""


func _get_chip_value_text(chip: Dictionary) -> String:
	var raw_text = str(chip.get("text", "")).strip_edges()
	# Strip all possible icon characters that might be in the source string
	# to avoid double-rendering with the new pixel art TextureRects.
	var icons_to_strip = [
		ICON_DAMAGE, ICON_HEAL, ICON_DOT, 
		"\u26B0", "\u26A1", "\u271A", "\u2620", 
		"⚡", "✚", "☠", "🛡️", "🎲", "♥"
	]
	for icon in icons_to_strip:
		raw_text = raw_text.replace(icon, "")
	return raw_text.strip_edges()


func _get_chip_icon_color(chip: Dictionary) -> Color:
	var raw_text: String = str(chip.get("text", "")).strip_edges()
	var bg: Color = chip.get("color", Color(0.24, 0.28, 0.36, 0.98))
	if raw_text.begins_with("-"):
		return Color(0.98, 0.90, 0.62, 1.0)
	if bg.is_equal_approx(CHIP_HEAL_BG):
		return Color(0.72, 1.0, 0.78, 1.0)
	if bg.is_equal_approx(CHIP_SHIELD_BG):
		return Color(0.82, 0.94, 1.0, 1.0)
	if bg.is_equal_approx(CHIP_DOT_BG):
		return Color(0.78, 0.56, 1.0, 1.0)
	if bg.is_equal_approx(CHIP_DAMAGE_BG):
		return Color(1.0, 0.44, 0.38, 1.0)
	if bg.is_equal_approx(CHIP_FROST_BG):
		return Color(0.72, 0.94, 1.0, 1.0)
	return Color(0.97, 0.98, 1.0, 1.0)


func _flatten_chip_color(color: Color) -> Color:
	return Color(
		clampf(color.r * 0.72, 0.0, 1.0),
		clampf(color.g * 0.72, 0.0, 1.0),
		clampf(color.b * 0.72, 0.0, 1.0),
		1.0
	)


func _set_mouse_filter_recursive(node: Node, filter: Control.MouseFilter) -> void:
	if node is Control:
		node.mouse_filter = filter
	for child in node.get_children():
		_set_mouse_filter_recursive(child, filter)

func _get_icon_texture(icon_kind: String) -> Texture2D:
	return ICON_MAP.get(icon_kind)


# ── Combat Preview ─────────────────────────────────────────────────────────────
# All sections are painted as solid ColorRect children of the HPBar ProgressBar.
# They sit at z_index = 1 (above the bar's own fill stylebox) and the HP label
# is raised to z_index = 3 so it always reads on top.
#
# Visual layout carved right-to-left from the current HP edge:
#
#   ← bar start                                                   bar end →
#   [ green fill (untouched HP) ][ teal ][ purple ][ blue ][ red ][ empty ]
#                                                                  ↑ cur_hp
#   And extending rightward into the empty space:
#   [ empty ][ bright-green heal ]
#
#   red    = direct damage that will hit HP this turn
#   blue   = direct damage absorbed by shield (total_shield = cur + incoming)
#   purple = DoT damage reaching HP next tick (after remaining shield is used)
#   teal   = DoT damage absorbed by remaining shield after direct hit
#   green  = incoming healing extending past current HP (capped at max HP)
#
# effects dict keys (from _compute_preview_for_unit in battle_scene.gd):
#   damage        : int  — raw incoming direct damage
#   heal          : int  — raw incoming healing
#   shield        : int  — incoming new shield being added this turn
#   dot           : int  — damage per DoT tick (single tick shown)
#   current_shield: int  — existing shield stacks total before this turn

func show_combat_preview(effects: Dictionary) -> void:
	var hp_bar: ProgressBar = _resolve_hp_bar()
	if hp_bar == null:
		return
	_preview_hp_bar_ref = hp_bar
	hp_bar.set_meta("_preview_effects", effects)
	_ensure_preview_rects(hp_bar)
	if not hp_bar.resized.is_connected(_on_preview_bar_resized):
		hp_bar.resized.connect(_on_preview_bar_resized)
	_preview_tooltip_text = _build_preview_tooltip(effects)
	call_deferred("_layout_preview_overlays")


func clear_combat_preview() -> void:
	_hide_preview_rects()
	_preview_tooltip_text = ""
	if _preview_hp_bar_ref != null and is_instance_valid(_preview_hp_bar_ref):
		if _preview_hp_bar_ref.has_meta("_preview_effects"):
			_preview_hp_bar_ref.remove_meta("_preview_effects")
		if _preview_hp_bar_ref.resized.is_connected(_on_preview_bar_resized):
			_preview_hp_bar_ref.resized.disconnect(_on_preview_bar_resized)
	_preview_hp_bar_ref = null


func _on_preview_bar_resized() -> void:
	_layout_preview_overlays()


func _ensure_preview_rects(hp_bar: ProgressBar) -> void:
	# Re-create any rect that is null, freed, or parented to a different node.
	if _preview_rect_red == null or not is_instance_valid(_preview_rect_red) or _preview_rect_red.get_parent() != hp_bar:
		_preview_rect_red    = _make_preview_rect(hp_bar, "PreviewRed")
	if _preview_rect_blue == null or not is_instance_valid(_preview_rect_blue) or _preview_rect_blue.get_parent() != hp_bar:
		_preview_rect_blue   = _make_preview_rect(hp_bar, "PreviewBlue")
	if _preview_rect_purple == null or not is_instance_valid(_preview_rect_purple) or _preview_rect_purple.get_parent() != hp_bar:
		_preview_rect_purple = _make_preview_rect(hp_bar, "PreviewPurple")
	if _preview_rect_teal == null or not is_instance_valid(_preview_rect_teal) or _preview_rect_teal.get_parent() != hp_bar:
		_preview_rect_teal   = _make_preview_rect(hp_bar, "PreviewTeal")
	if _preview_rect_heal == null or not is_instance_valid(_preview_rect_heal) or _preview_rect_heal.get_parent() != hp_bar:
		_preview_rect_heal   = _make_preview_rect(hp_bar, "PreviewHeal")
	# Raise the HP label above all preview rects (z_index 3 > rect z_index 1).
	for child in hp_bar.get_children():
		if child is Label:
			child.z_index = 3
	# Connect HP bar hover once so we can show a summary tooltip.
	if not _hp_bar_hover_connected:
		hp_bar.mouse_entered.connect(_on_hp_bar_mouse_entered)
		hp_bar.mouse_exited.connect(_on_element_mouse_exited)
		hp_bar.mouse_filter = Control.MOUSE_FILTER_PASS
		_hp_bar_hover_connected = true


func _make_preview_rect(hp_bar: ProgressBar, rect_name: String) -> ColorRect:
	var r := ColorRect.new()
	r.name = rect_name
	r.z_index = 1
	r.visible = false
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_bar.add_child(r)
	return r


func _hide_preview_rects() -> void:
	for r in [_preview_rect_red, _preview_rect_blue, _preview_rect_purple,
			  _preview_rect_teal, _preview_rect_heal]:
		if r != null and is_instance_valid(r):
			r.visible = false


func _place_preview_rect(r: ColorRect, x_hp: float, w_hp: float,
		max_hp: float, bar_w: float, bar_h: float, color: Color) -> void:
	if r == null or not is_instance_valid(r):
		return
	if w_hp <= 0.0:
		r.visible = false
		return
	r.visible = true
	r.color = color
	r.position = Vector2((x_hp / max_hp) * bar_w, 0.0)
	r.size    = Vector2((w_hp / max_hp) * bar_w, bar_h)


func _layout_preview_overlays() -> void:
	if _preview_hp_bar_ref == null or not is_instance_valid(_preview_hp_bar_ref):
		return
	var hp_bar: ProgressBar = _preview_hp_bar_ref
	if not hp_bar.has_meta("_preview_effects"):
		_hide_preview_rects()
		return

	var effects: Dictionary = hp_bar.get_meta("_preview_effects")
	var bar_w: float = hp_bar.size.x
	var bar_h: float = hp_bar.size.y
	if bar_w <= 2.0:
		return

	var max_hp: float     = maxf(float(hp_bar.max_value), 1.0)
	var cur_hp: float     = float(hp_bar.value)
	var cur_shield: float = float(int(effects.get("current_shield", 0)))
	var inc_dmg: float    = float(int(effects.get("damage", 0)))
	var inc_heal: float   = float(int(effects.get("heal", 0)))
	var inc_shield: float = float(int(effects.get("shield", 0)))
	var dot_tick: float   = float(int(effects.get("dot", 0)))
	var lethal: bool      = bool(effects.get("lethal", false))

	# ── Lethal: the enemy will die this turn — paint the entire fill red ──────
	if lethal:
		_place_preview_rect(_preview_rect_red, 0.0, cur_hp, max_hp, bar_w, bar_h, Color(0.88, 0.18, 0.14, 0.92))
		for r in [_preview_rect_blue, _preview_rect_purple, _preview_rect_teal, _preview_rect_heal]:
			if r != null and is_instance_valid(r):
				r.visible = false
		return

	# ── Shield absorption math ────────────────────────────────────────────────
	# For heroes: total shield = existing + incoming this turn.
	# For enemies: current_shield was set to 0 in battle_scene so this is 0.
	var total_shield: float = cur_shield + inc_shield

	# Direct hit: shield absorbs first, remainder hits HP.
	var blue_w: float      = minf(total_shield, inc_dmg)      # absorbed by shield (direct)
	var red_w: float       = maxf(0.0, inc_dmg - blue_w)      # HP lost (direct)
	var shield_left: float = total_shield - blue_w             # shield remaining after direct hit

	# DoT tick (only present if unit already has active poison this turn):
	# remaining shield absorbs what it can, leftover hits HP.
	var teal_w: float   = minf(shield_left, dot_tick)          # absorbed by shield (DoT)
	var purple_w: float = maxf(0.0, dot_tick - teal_w)         # HP lost (DoT tick)

	# ── Section positions carved right-to-left from the HP fill edge ─────────
	# Order right → left:  red | blue | purple | teal
	var red_x: float    = maxf(0.0, cur_hp - red_w)
	var blue_x: float   = maxf(0.0, red_x   - blue_w)
	var purple_x: float = maxf(0.0, blue_x  - purple_w)
	var teal_x: float   = maxf(0.0, purple_x - teal_w)

	_place_preview_rect(_preview_rect_red,    red_x,    red_w,    max_hp, bar_w, bar_h, Color(0.88, 0.18, 0.14, 0.88))
	_place_preview_rect(_preview_rect_blue,   blue_x,   blue_w,   max_hp, bar_w, bar_h, Color(0.22, 0.55, 0.95, 0.80))
	_place_preview_rect(_preview_rect_purple, purple_x, purple_w, max_hp, bar_w, bar_h, Color(0.62, 0.18, 0.82, 0.85))
	_place_preview_rect(_preview_rect_teal,   teal_x,   teal_w,   max_hp, bar_w, bar_h, Color(0.18, 0.72, 0.68, 0.75))

	# ── Heal extends rightward from cur_hp into the empty portion of the bar ──
	var heal_eff: float = minf(inc_heal, max_hp - cur_hp)
	_place_preview_rect(_preview_rect_heal, cur_hp, heal_eff, max_hp, bar_w, bar_h, Color(0.28, 0.94, 0.50, 0.85))


func _on_hp_bar_mouse_entered() -> void:
	if _preview_tooltip_text.is_empty():
		return
	var hp_bar: ProgressBar = _resolve_hp_bar()
	_hovered_node = hp_bar
	_show_tooltip(_preview_tooltip_text)


func _build_preview_tooltip(effects: Dictionary) -> String:
	var lines: Array = []
	var inc_dmg: int      = int(effects.get("damage", 0))
	var inc_heal: int     = int(effects.get("heal", 0))
	var inc_shield: int   = int(effects.get("shield", 0))
	var dot_tick: int     = int(effects.get("dot", 0))
	var cur_shield: int   = int(effects.get("current_shield", 0))
	var lethal: bool      = bool(effects.get("lethal", false))

	if lethal:
		lines.append("Lethal — this unit will not survive the turn.")
		return "\n".join(lines)

	var total_shield: int = cur_shield + inc_shield
	if inc_dmg > 0:
		var absorbed: int = mini(total_shield, inc_dmg)
		var hp_lost: int  = inc_dmg - absorbed
		if absorbed > 0 and hp_lost > 0:
			lines.append("%d damage — %d blocked by shield, %d to HP" % [inc_dmg, absorbed, hp_lost])
		elif absorbed > 0:
			lines.append("%d damage — fully blocked by shield" % inc_dmg)
		else:
			lines.append("%d damage to HP" % inc_dmg)

	if inc_shield > 0:
		if cur_shield > 0:
			lines.append("+%d shield (stacks with existing %d)" % [inc_shield, cur_shield])
		else:
			lines.append("+%d incoming shield" % inc_shield)

	if dot_tick > 0:
		var shield_after_dmg: int = maxi(0, total_shield - mini(total_shield, inc_dmg))
		var dot_absorbed: int     = mini(shield_after_dmg, dot_tick)
		var dot_hp_lost: int      = dot_tick - dot_absorbed
		if dot_absorbed > 0 and dot_hp_lost > 0:
			lines.append("Poison tick: %d (%d blocked, %d to HP)" % [dot_tick, dot_absorbed, dot_hp_lost])
		elif dot_absorbed > 0:
			lines.append("Poison tick: %d (fully blocked by shield)" % dot_tick)
		else:
			lines.append("Poison tick: %d to HP" % dot_tick)

	if inc_heal > 0:
		lines.append("+%d healing" % inc_heal)

	if lines.is_empty():
		return ""
	return "\n".join(lines)
