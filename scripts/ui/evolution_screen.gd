# Evolution branch picker shown when a unit reaches a run-long upgrade.
extends Control

const ChoiceScreenGuardScript := preload("res://scripts/ui/choice_screen_guard.gd")


const CARD_WIDTH_FRACTION := 0.78
const CARD_MIN_WIDTH := 620.0
const CARD_MAX_WIDTH := 920.0
const CARD_TOP_SPACER_HEIGHT := 24.0
const CARD_BG := Color(0.024, 0.040, 0.060, 0.82)
const CARD_BG_HOVER := Color(0.036, 0.060, 0.086, 0.92)
# Branch-portrait token width; height derives from PixelUI.HERO_PORTRAIT_REGION
# in _create_path_header — never define a second portrait aspect here.
const PORTRAIT_W := 170
const PORTRAIT_BORDER := 4
const TITLE_FONT_SIZE := 58
const SUMMARY_FONT_SIZE := 36
const CARD_TITLE_FONT_SIZE := 44
const BODY_FONT_SIZE := PixelUI.FONT_BODY_MIN  # long-form prose (path focus, directive desc) — Polish Build A
const SMALL_FONT_SIZE := 32
# Band effect rows are the substance of a PERMANENT choice — floor them
# (UI review S-1: the densest decision screen had the smallest text).
const ABILITY_NAME_FONT_SIZE := PixelUI.FONT_INFO_MIN
const ABILITY_DESC_FONT_SIZE := PixelUI.FONT_INFO_MIN
# Directive cards (Kev 2026-07-10): the effect pips ARE the item image — large.
const DIRECTIVE_PIP_PROFILE := {
	"icon_size": 96,
	"value_font": 84,
	"duration_ratio": 0.6,
	"icon_value_gap": 6,
	"group_min_width": 110,
	"outline": 3,
	"duration_outline": 2,
}
const BUTTON_FONT_SIZE := 36

@onready var background: ColorRect = $Background
@onready var content_vbox: VBoxContainer = $Content/VBox
@onready var title_label: Label = $Content/VBox/Title
@onready var summary_label: Label = %SummaryLabel
@onready var choice_area: MarginContainer = $Content/VBox/ChoiceArea
@onready var choice_content: VBoxContainer = %ChoiceContent
@onready var top_spacer: Control = %TopSpacer
@onready var choice_cards: VBoxContainer = %ChoiceCards
@onready var footer_label: Label = %FooterLabel

var _help_overlay: Control = null


func _ready() -> void:
	# Safe area (device cutout / gesture bar): drop below the grown header band
	# and lift the footer clear. Both insets are 0 on desktop (no-op); the
	# authored .tscn offsets (156 / −12) stay the base.
	var content: MarginContainer = $Content
	content.offset_top += float(PixelUI.safe_top)
	content.offset_bottom -= float(PixelUI.safe_bottom)
	_apply_visual_theme()
	resized.connect(_update_choice_layout)
	# Header bar lives in the PersistentHeader autoload; bind this screen's handlers.
	PersistentHeader.bind_battle_actions(
		_on_help_button_pressed,
		_on_header_unavailable_pressed.bind("Auto turn is unavailable while choosing an evolution."),
		_on_header_unavailable_pressed.bind("Auto battle is unavailable while choosing an evolution."),
		_on_return_to_menu_button_pressed,
	)
	_update_battle_header()
	_refresh_summary()
	_build_choice_cards()
	_build_view_battle_button()


func _exit_tree() -> void:
	if is_instance_valid(PersistentHeader):
		PersistentHeader.clear_battle_actions()


func _on_return_to_menu_button_pressed() -> void:
	AudioManager.play_select()
	GameState.reset_run()
	SceneManager.go_to_unit_select()


func _on_help_button_pressed() -> void:
	AudioManager.play_select()
	if _help_overlay == null or not is_instance_valid(_help_overlay):
		_build_help_overlay()
	_help_overlay.visible = true
	_help_overlay.move_to_front()


func _on_header_unavailable_pressed(message: String) -> void:
	footer_label.text = message
	footer_label.visible = true


func _build_view_battle_button() -> void:
	if GameState.battle_review_state.is_empty():
		return
	var button := Button.new()
	button.name = "ViewBattleButton"
	button.text = "VIEW BATTLEFIELD"
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 96)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	PixelUI.style_button(button, Color(0.04, 0.09, 0.12, 0.96), PixelUI.DT_HERO_BORDER, 34)
	button.add_theme_color_override("font_color", PixelUI.DT_HERO_NAME)
	button.pressed.connect(_on_view_battle_pressed)
	content_vbox.add_child(button)


func _on_view_battle_pressed() -> void:
	AudioManager.play_select()
	GameState.battle_review_return_target = "evolution"
	GameState.entering_battle_review = true
	SceneManager.go_to_battle()


func _hide_help_overlay() -> void:
	if _help_overlay != null and is_instance_valid(_help_overlay):
		_help_overlay.visible = false


func _build_help_overlay() -> void:
	_help_overlay = Control.new()
	_help_overlay.name = "EvolutionHelpOverlay"
	_help_overlay.visible = false
	_help_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_help_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_help_overlay.z_as_relative = false
	_help_overlay.z_index = 200
	_help_overlay.gui_input.connect(_on_help_overlay_input)
	add_child(_help_overlay)

	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.005, 0.007, 0.012, 0.82)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_help_overlay.add_child(dim)

	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_help_overlay.add_child(center)

	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(820, 0)
	# Component: Modal (the legacy sci-fi ninepatch was a second frame language).
	PixelUI.style_component(panel, PixelUI.COMPONENT_MODAL)
	center.add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	margin.add_child(content)

	content.add_child(_make_label("EVOLUTION HELP", 40, PixelUI.TEXT_PRIMARY, 3))
	for line in [
		"Choose one evolution branch for this unit.",
		"Each card shows the full ability table after the upgrade.",
		"Each evolution card previews that branch's unique portrait and full ability table.",
	]:
		var label: Label = _make_label(line, BODY_FONT_SIZE, PixelUI.TEXT_MUTED, 1)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(label)


func _on_help_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed:
			_hide_help_overlay()
	elif event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event as InputEventScreenTouch
		if touch_event.pressed:
			_hide_help_overlay()


func _build_choice_cards() -> void:
	for child in choice_cards.get_children():
		child.queue_free()

	var unit_id: String = GameState.get_pending_evolution_unit_id()
	var unit: UnitData = DataManager.get_unit(unit_id) as UnitData
	if GameState.is_pending_directive_stage():
		for choice_variant in GameState.get_pending_directive_choices():
			choice_cards.add_child(_create_directive_card(choice_variant, unit))
	else:
		var paths: Array = GameState.get_pending_evolution_paths()
		for path_variant in paths:
			var path: Dictionary = path_variant
			choice_cards.add_child(_create_evolution_card(path, unit))
	# Zero-options guard (permanent fixture, TRUTH §Run structure): a stop with
	# no choices routes on rather than stranding the run.
	if not ChoiceScreenGuardScript.ensure_options("evolution", choice_cards.get_child_count(), SceneManager.go_to_next_battle_or_beat):
		return
	call_deferred("_update_choice_layout")


# Tier-3 Directive pick (pkg6): a compact card — name, passive text, choose.
func _create_directive_card(directive: Dictionary, base_unit: UnitData) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.custom_minimum_size = Vector2(_get_card_width(), 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_style_evolution_panel(panel, false)
	panel.mouse_entered.connect(_style_evolution_panel.bind(panel, true))
	panel.mouse_exited.connect(_style_evolution_panel.bind(panel, false))

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	var directive_name: String = str(directive.get("name", "Directive"))
	vbox.add_child(_make_label(directive_name.to_upper(), CARD_TITLE_FONT_SIZE, PixelUI.GOLD_ACCENT, 3))
	# Kev 2026-07-10: image beside description — the directive's effect pip
	# icons render LARGE on the left, the passive text reads to the right.
	var body_row: HBoxContainer = HBoxContainer.new()
	body_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_row.add_theme_constant_override("separation", 20)
	var pips: Array = EffectPip.effects_from_directive(directive.get("effect", {}))
	if not pips.is_empty():
		var pip_col: VBoxContainer = VBoxContainer.new()
		pip_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pip_col.add_theme_constant_override("separation", 8)
		for pip_variant in pips:
			pip_col.add_child(EffectPip.build_group(pip_variant, DIRECTIVE_PIP_PROFILE))
		body_row.add_child(pip_col)
	var desc: Label = _make_label(str(directive.get("desc", "")), BODY_FONT_SIZE, PixelUI.TEXT_PRIMARY, 2)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	body_row.add_child(desc)
	vbox.add_child(body_row)
	if base_unit != null:
		var evolved_name: String = GameState.get_unit_evolution_name(base_unit.id)
		vbox.add_child(_make_label("PERMANENT PASSIVE FOR %s" % evolved_name.to_upper(), SMALL_FONT_SIZE, PixelUI.TEXT_MUTED, 1))
	vbox.add_child(_create_divider())

	var choose_button: Button = Button.new()
	# Kev 2026-07-10 (rev 2): big tap target, label vertically comfortable.
	choose_button.custom_minimum_size = Vector2(0, 128)
	choose_button.text = "CHOOSE %s" % directive_name.to_upper()
	PixelUI.style_button(choose_button, Color(0.022, 0.034, 0.050, 0.95), PixelUI.DT_CYAN, BUTTON_FONT_SIZE)
	choose_button.icon = load(PixelUI.ICON_EVOLVE) as Texture2D
	choose_button.expand_icon = true
	choose_button.add_theme_constant_override("icon_max_width", 44)
	choose_button.add_theme_color_override("icon_normal_color", PixelUI.DT_CYAN)
	choose_button.add_theme_constant_override("h_separation", 14)
	choose_button.pressed.connect(_on_choose_directive_pressed.bind(directive_name))
	vbox.add_child(choose_button)
	return panel


func _on_choose_directive_pressed(directive_name: String) -> void:
	var pending_unit_id: String = GameState.get_pending_evolution_unit_id()
	if not GameState.apply_pending_directive(directive_name):
		footer_label.text = "That directive could not be applied."
		return
	AudioManager.play_sfx("evolve")
	var unit: UnitData = DataManager.get_unit(pending_unit_id) as UnitData
	var unit_name: String = unit.display_name if unit != null else pending_unit_id
	footer_label.text = "%s adopted the %s directive." % [unit_name, directive_name]
	SceneManager.go_to_next_battle_or_beat()


func _create_evolution_card(path: Dictionary, base_unit: UnitData) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.custom_minimum_size = Vector2(_get_card_width(), 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_style_evolution_panel(panel, false)
	panel.mouse_entered.connect(_style_evolution_panel.bind(panel, true))
	panel.mouse_exited.connect(_style_evolution_panel.bind(panel, false))

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	vbox.add_child(_create_path_header(path, base_unit))
	vbox.add_child(_create_divider())

	var abilities: VBoxContainer = VBoxContainer.new()
	abilities.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	abilities.add_theme_constant_override("separation", 10)
	for entry_variant in _build_merged_ranges(path, base_unit):
		var entry: Dictionary = entry_variant
		abilities.add_child(_create_ability_row(entry))
	vbox.add_child(abilities)

	var choose_button: Button = Button.new()
	choose_button.custom_minimum_size = Vector2(0, 78)
	choose_button.text = "CHOOSE %s" % str(path.get("name", "EVOLUTION")).to_upper()
	PixelUI.style_button(choose_button, Color(0.022, 0.034, 0.050, 0.95), PixelUI.DT_CYAN, BUTTON_FONT_SIZE)
	choose_button.icon = load(PixelUI.ICON_EVOLVE) as Texture2D
	choose_button.expand_icon = true
	choose_button.add_theme_constant_override("icon_max_width", 44)
	choose_button.add_theme_color_override("icon_normal_color", PixelUI.DT_CYAN)
	choose_button.add_theme_constant_override("h_separation", 14)
	choose_button.pressed.connect(_on_choose_path_pressed.bind(str(path.get("name", ""))))
	vbox.add_child(choose_button)
	return panel


func _create_path_header(path: Dictionary, base_unit: UnitData) -> HBoxContainer:
	var header: HBoxContainer = HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_constant_override("separation", 18)

	var portrait_frame: PanelContainer = PanelContainer.new()
	# The ONE portrait window (PixelUI.HERO_PORTRAIT_REGION aspect) scaled to
	# PORTRAIT_W, art inset by the border — the old private 170×210 (0.81) window
	# + centered cover was liar #3 of the 2026-07-12 portrait-region bug.
	var inner_w: float = float(PORTRAIT_W - 2 * PORTRAIT_BORDER)
	var inner_h: float = roundf(inner_w * PixelUI.HERO_PORTRAIT_REGION.y / PixelUI.HERO_PORTRAIT_REGION.x)
	portrait_frame.custom_minimum_size = Vector2(PORTRAIT_W, inner_h + 2.0 * float(PORTRAIT_BORDER))
	portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var portrait_style: StyleBoxFlat = PixelUI.make_hard_style(PixelUI.DT_HERO_BG, PixelUI.DT_HERO_BORDER, PORTRAIT_BORDER)
	portrait_style.set_content_margin_all(float(PORTRAIT_BORDER))
	portrait_frame.add_theme_stylebox_override("panel", portrait_style)
	header.add_child(portrait_frame)

	var crop: Control = Control.new()
	crop.clip_contents = true
	crop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.add_child(crop)

	var portrait: TextureRect = TextureRect.new()
	portrait.texture = _get_path_portrait(path, base_unit)
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_SCALE  # position/size set by cover-fit
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crop.add_child(portrait)
	# Shared framing rule — same function as the battle card and squad tiles.
	crop.resized.connect(func() -> void: PixelUI.cover_fit_portrait(portrait, crop.size))

	var text_stack: VBoxContainer = VBoxContainer.new()
	text_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_stack.add_theme_constant_override("separation", 6)
	header.add_child(text_stack)

	var path_callsign: String = str(path.get("callsign", ""))
	if path_callsign != "":
		text_stack.add_child(_make_label(path_callsign, CARD_TITLE_FONT_SIZE, PixelUI.GOLD_ACCENT, 3))

	# Branch name is a selection, not a rarity — cyan, not green (UI review S-2).
	var path_name: Label = _make_label(str(path.get("name", "Evolution")), CARD_TITLE_FONT_SIZE, PixelUI.DT_CYAN, 3)
	path_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_stack.add_child(path_name)

	var focus_text: String = str(path.get("focus", ""))
	if focus_text != "":
		var focus: Label = _make_label(focus_text, BODY_FONT_SIZE, PixelUI.TEXT_PRIMARY, 2)
		focus.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text_stack.add_child(focus)

	var hp_value: int = int(path.get("hp", 0))
	var hp_label_text: String = "MAX HP UNCHANGED"
	if hp_value > 0:
		hp_label_text = "MAX HP %d" % hp_value
	text_stack.add_child(_make_label(hp_label_text, SMALL_FONT_SIZE, PixelUI.GOLD_ACCENT, 1))

	# No FROM <unit> line (Kev 2026-07-10) — the player just came from that unit.
	return header


# Ability row in the SAME shape as the long-press inspect popup (Kev
# 2026-07-10): "Roll: N - M  Name" on one line, then the effect pips beside
# the short eff text — the layout the player already reads in battle.
func _create_ability_row(entry: Dictionary) -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)

	# Alignment contract (Kev 2026-07-10, matches the inspect popup): the
	# "Roll: N - M  Name" line is CENTERED; pips LEFT, description RIGHT.
	var row1: HBoxContainer = HBoxContainer.new()
	row1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.alignment = BoxContainer.ALIGNMENT_CENTER
	row1.add_theme_constant_override("separation", 12)
	row1.add_child(_make_label("Roll: %d - %d" % [int(entry.get("min", 0)), int(entry.get("max", 0))], SMALL_FONT_SIZE, PixelUI.TEXT_MUTED, 1))
	var ability_name: Label = _make_label(str(entry.get("ability_name", "Ability")), ABILITY_NAME_FONT_SIZE, PixelUI.DT_CYAN, 2)
	ability_name.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row1.add_child(ability_name)
	box.add_child(row1)

	var raw: Dictionary = entry.get("raw", {})
	var eff_text: String = str(raw.get("eff", entry.get("description", ""))).strip_edges()
	var effects: Array = EffectPip.effects_from_ability_raw(raw, "hero") if not raw.is_empty() else []
	if not effects.is_empty() or eff_text != "":
		var row2: HBoxContainer = HBoxContainer.new()
		row2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row2.add_theme_constant_override("separation", 10)
		for effect_variant in effects:
			var group: Control = EffectPip.build_group(effect_variant, EffectPip.PROFILE_CARD, "hero")
			group.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			row2.add_child(group)
		if eff_text != "":
			var description: Label = _make_label(eff_text, ABILITY_DESC_FONT_SIZE, PixelUI.TEXT_MUTED, 1)
			description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			description.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			row2.add_child(description)
		box.add_child(row2)
	return box


func _create_divider() -> ColorRect:
	var divider: ColorRect = ColorRect.new()
	divider.color = PixelUI.LINE_DIM
	divider.custom_minimum_size = Vector2(0, 2)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return divider


func _style_evolution_panel(panel: PanelContainer, hovered: bool) -> void:
	# Component: Major-event — evolutions are the ceremonial tier, the one place
	# strong gold is legal. Hover brightens the gold; the old cyan hover read as
	# a selection state on a card that wasn't selected.
	var style: StyleBoxFlat = PixelUI.component_style(PixelUI.COMPONENT_MAJOR)
	style.bg_color = CARD_BG_HOVER if hovered else CARD_BG
	if hovered:
		style.border_color = style.border_color.lightened(0.20)
	panel.add_theme_stylebox_override("panel", style)


func _build_merged_ranges(path: Dictionary, base_unit: UnitData) -> Array:
	var ability_map: Dictionary = path.get("abilities_by_zone", {})
	var ranges: Array = []
	if base_unit == null:
		for zone_name in ["recharge", "strike", "surge", "crit", "overload"]:
			if ability_map.has(zone_name):
				ranges.append((ability_map[zone_name] as Dictionary).duplicate(true))
		ranges.sort_custom(_sort_range_min)
		return ranges

	for base_range_variant in base_unit.dice_ranges:
		var base_range: Dictionary = base_range_variant
		var zone: String = str(base_range.get("zone", ""))
		if ability_map.has(zone):
			ranges.append((ability_map[zone] as Dictionary).duplicate(true))
		else:
			ranges.append(base_range.duplicate(true))
	ranges.sort_custom(_sort_range_min)
	return ranges


func _sort_range_min(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("min", 0)) < int(b.get("min", 0))


func _get_path_portrait(path: Dictionary, base_unit: UnitData) -> Texture2D:
	# Each branch card previews its own evolved portrait when the file exists
	# (assets/portraits/<hero_id>_<evo_id>.png), else the base portrait.
	if base_unit == null:
		return null
	var evolved_portrait: Texture2D = DataManager.get_evolution_portrait(base_unit.id, str(path.get("id", "")))
	if evolved_portrait != null:
		return evolved_portrait
	return base_unit.portrait


func _refresh_summary() -> void:
	var unit_id: String = GameState.get_pending_evolution_unit_id()
	var unit: UnitData = DataManager.get_unit(unit_id) as UnitData
	if unit == null:
		summary_label.text = "No evolution is ready."
		return
	if GameState.is_pending_directive_stage():
		summary_label.text = "%s reached %d XP. Choose a permanent Directive." % [
			GameState.get_unit_evolution_name(unit_id),
			GameState.XP_TO_DIRECTIVE,
		]
		return
	summary_label.text = "%s reached level %d. Choose a permanent branch." % [
		unit.display_name,
		GameState.get_unit_level(unit_id),
	]


func _on_choose_path_pressed(path_name: String) -> void:
	var pending_unit_id: String = GameState.get_pending_evolution_unit_id()
	if not GameState.apply_pending_evolution(path_name):
		footer_label.text = "That evolution could not be applied."
		return
	AudioManager.play_sfx("evolve")
	var unit: UnitData = DataManager.get_unit(pending_unit_id) as UnitData
	var unit_name: String = pending_unit_id
	if unit != null:
		unit_name = unit.display_name
	footer_label.text = "%s evolved into %s." % [unit_name, path_name]
	SceneManager.go_to_next_battle_or_beat()


func _update_battle_header() -> void:
	var operation: OperationData = DataManager.get_operation(GameState.selected_operation_id) as OperationData
	var op_name: String = operation.battle_name() if operation != null else "OP"
	PersistentHeader.set_run_active(true)
	PersistentHeader.update_progress(GameState.current_battle, GameState.total_battles, op_name)


func _update_choice_layout() -> void:
	if choice_cards == null:
		return
	var card_width: float = _get_card_width()
	choice_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	choice_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	choice_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	choice_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choice_content.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	choice_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choice_cards.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	choice_content.add_theme_constant_override("separation", 18)
	choice_cards.add_theme_constant_override("separation", 18)
	top_spacer.custom_minimum_size = Vector2(0, CARD_TOP_SPACER_HEIGHT)
	for child in choice_cards.get_children():
		var panel: PanelContainer = child as PanelContainer
		if panel != null:
			panel.custom_minimum_size = Vector2(card_width, 0)
			panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN


func _get_card_width() -> float:
	var available_width: float = choice_area.size.x if choice_area != null else size.x
	if available_width <= 1.0:
		available_width = get_viewport().get_visible_rect().size.x
	available_width = maxf(available_width - 24.0, 1.0)
	return clampf(available_width * CARD_WIDTH_FRACTION, CARD_MIN_WIDTH, CARD_MAX_WIDTH)


func _apply_visual_theme() -> void:
	# Direction-05: flat dark DT field (matches the battle screen), no bright grid.
	background.color = Color(0.055, 0.070, 0.095, 1.0)
	var pattern: Control = get_node_or_null("BackgroundPattern")
	if pattern != null:
		pattern.visible = false
	content_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	content_vbox.add_theme_constant_override("separation", 8)
	footer_label.visible = false
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelUI.style_label(title_label, TITLE_FONT_SIZE, PixelUI.GOLD_ACCENT, 3)
	PixelUI.style_label(summary_label, SUMMARY_FONT_SIZE, PixelUI.TEXT_PRIMARY, 2)
	PixelUI.style_label(footer_label, 30, PixelUI.TEXT_MUTED, 1)
	_update_choice_layout()


func _make_label(text: String, font_size: int, color: Color, outline: int = 1) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUI.style_label(label, font_size, color, outline)
	return label
