# Shared tabbed help / codex overlay, opened from the persistent header's "?" button on any
# screen. Self-contained (reads DataManager + PixelUI only), so it works in battle and on the
# squad picker alike. One panel, content swaps per mini-tab. Dithered-Terminal styling.
class_name HelpMenu
extends CanvasLayer

const MENU_LAYER := 135  # above InspectPopup (130) and the persistent header (8)

# Mobile-readable font scale (matches the inspect popup, not the old tiny help text).
const TITLE_FONT := 48
const TAB_FONT := 30
const SECTION_FONT := 36
const BODY_FONT := 30
const TERM_FONT := 33
const SYNTAX_FONT := 27
const HEADER_FONT := 42
const RANGE_FONT := 30
const PICKER_FONT := 28
const BLURB_FONT := 28

const HELP_TABS := [
	{"id": "basics", "label": "BASICS"},
	{"id": "protocol", "label": "PROTOCOL"},
	{"id": "keywords", "label": "KEYWORDS"},
	{"id": "rewards", "label": "REWARDS"},
	{"id": "units", "label": "UNITS"},
	{"id": "bestiary", "label": "BESTIARY"},
	{"id": "settings", "label": "SETTINGS"},
]
const HELP_KEYWORD_ICON := {
	"burn": "burn", "pierce": "damage", "shield": "shield", "heal": "heal",
	"revive": "heal", "roll_down": "roll_down", "roll_up": "roll_up",
	"freeze": "freeze", "taunt": "shield", "aoe": "damage", "accrete": "shield",
}
const HELP_CATEGORY_ORDER := ["offense", "defense", "control", "support", "economy"]
const BESTIARY_FACTION_ORDER := ["facility", "hive", "veil", "voidCirclet", "stellarMenagerie"]
const BESTIARY_FACTION_LABEL := {
	"facility": "FACILITY",
	"hive": "HIVE",
	"veil": "VEIL",
	"voidCirclet": "NULL SYNOD",
	"stellarMenagerie": "THE ACCRETION",
}
const SECTION_HEADER_COLOR := Color(0.72, 0.88, 1.0, 1.0)

static var _active: HelpMenu = null

var _content_host: VBoxContainer = null
var _content_scroll: ScrollContainer = null
var _reset_armed: bool = false
var _reset_dev_button: Button = null
var _tab_buttons: Dictionary = {}
var _active_tab: String = ""
var _codex_detail: VBoxContainer = null
var _codex_buttons: Dictionary = {}
var _codex_unit: String = ""
var _bestiary_detail: VBoxContainer = null
var _bestiary_buttons: Dictionary = {}
var _bestiary_faction: String = ""


static func toggle(host: Node) -> void:
	if is_open():
		dismiss()
		return
	open(host)


static func open(host: Node) -> void:
	if host == null or not host.is_inside_tree():
		return
	dismiss()
	var menu := HelpMenu.new()
	host.get_tree().root.add_child(menu)
	menu._build()
	_active = menu


static func dismiss() -> void:
	if _active != null and is_instance_valid(_active):
		_active.queue_free()
	_active = null


static func is_open() -> bool:
	return _active != null and is_instance_valid(_active)


# Autoload via the live node (Variant) rather than the global identifier, so this script
# compiles even when loaded outside the running game (e.g. the headless capture harness).
func _dm() -> Variant:
	return get_node_or_null("/root/DataManager")


func _build() -> void:
	layer = MENU_LAYER

	# Full-screen catcher: a press anywhere outside the panel dismisses (the panel sits on top
	# and swallows its own presses, so its buttons keep working).
	var catcher := Control.new()
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	catcher.gui_input.connect(_on_catcher_input)
	add_child(catcher)

	catcher.add_child(PixelUI.make_modal_scrim())

	# Clear the persistent header band so the title isn't hidden behind it. Read the height off
	# the live node (not the PersistentHeader global) so this compiles without the autoload too.
	var header_node := get_node_or_null("/root/PersistentHeader")
	var band_height: float = 144.0
	if header_node != null:
		var value: Variant = header_node.get("HEADER_HEIGHT")
		if value != null:
			band_height = float(value)
	var top_margin: int = int(band_height) + 16 if header_node != null else 46
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", top_margin)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 46)
	add_child(margin)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	PixelUI.style_panel(panel, Color(0.018, 0.026, 0.044, 0.98), Color(0.36, 0.55, 0.78, 0.95), 4, 0)
	margin.add_child(panel)

	var panel_margin := MarginContainer.new()
	panel_margin.mouse_filter = Control.MOUSE_FILTER_PASS
	panel_margin.add_theme_constant_override("margin_left", 22)
	panel_margin.add_theme_constant_override("margin_top", 20)
	panel_margin.add_theme_constant_override("margin_right", 22)
	panel_margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(panel_margin)

	var root := VBoxContainer.new()
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 16)
	panel_margin.add_child(root)

	var header_row := HBoxContainer.new()
	header_row.mouse_filter = Control.MOUSE_FILTER_PASS
	header_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_theme_constant_override("separation", 12)
	root.add_child(header_row)

	var title := _make_label("TACTICAL REFERENCE", TITLE_FONT, PixelUI.TEXT_PRIMARY, HORIZONTAL_ALIGNMENT_LEFT, 3)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header_row.add_child(title)

	var close_button := Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(76, 70)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	PixelUI.style_button(close_button, PixelUI.BG_PANEL_ALT, PixelUI.LINE_BRIGHT, 38)
	close_button.pressed.connect(HelpMenu.dismiss)
	header_row.add_child(close_button)

	var tab_grid := GridContainer.new()
	tab_grid.columns = 3
	tab_grid.mouse_filter = Control.MOUSE_FILTER_PASS
	tab_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_grid.add_theme_constant_override("h_separation", 8)
	tab_grid.add_theme_constant_override("v_separation", 8)
	root.add_child(tab_grid)

	_tab_buttons.clear()
	for tab_variant in HELP_TABS:
		var tab: Dictionary = tab_variant
		var tab_id: String = str(tab["id"])
		var tab_button := Button.new()
		tab_button.text = str(tab["label"])
		tab_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_button.custom_minimum_size = Vector2(0, 70)
		tab_button.mouse_filter = Control.MOUSE_FILTER_STOP
		tab_button.pressed.connect(_select_tab.bind(tab_id))
		tab_grid.add_child(tab_button)
		_tab_buttons[tab_id] = tab_button

	_content_scroll = ScrollContainer.new()
	_content_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_content_scroll)

	_content_host = VBoxContainer.new()
	_content_host.mouse_filter = Control.MOUSE_FILTER_PASS
	_content_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_host.add_theme_constant_override("separation", 20)
	_content_scroll.add_child(_content_host)

	_select_tab("basics")


func _on_catcher_input(event: InputEvent) -> void:
	var pressed := false
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		pressed = mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed
	elif event is InputEventScreenTouch:
		pressed = (event as InputEventScreenTouch).pressed
	if pressed:
		HelpMenu.dismiss()


func _select_tab(tab_id: String) -> void:
	if _content_host == null:
		return
	_active_tab = tab_id
	for known_id in _tab_buttons.keys():
		_style_tab_button(_tab_buttons[known_id], str(known_id) == tab_id)
	for child in _content_host.get_children():
		child.queue_free()
	match tab_id:
		"basics":
			_build_basics(_content_host)
		"protocol":
			_build_protocol(_content_host)
		"keywords":
			_build_keywords(_content_host)
		"rewards":
			_build_rewards(_content_host)
		"units":
			_build_codex(_content_host)
		"bestiary":
			_build_bestiary(_content_host)
		"settings":
			_build_settings(_content_host)
	if _content_scroll != null:
		_content_scroll.scroll_vertical = 0


func _style_tab_button(button: Button, active: bool) -> void:
	if button == null:
		return
	if active:
		PixelUI.style_button(button, Color(0.06, 0.13, 0.17, 0.98), PixelUI.DT_CYAN, TAB_FONT)
		button.add_theme_color_override("font_color", PixelUI.DT_CYAN_BRIGHT)
	else:
		PixelUI.style_button(button, PixelUI.BG_PANEL_ALT, PixelUI.LINE_DIM, TAB_FONT)
		button.add_theme_color_override("font_color", PixelUI.TEXT_MUTED)


# ── Tab content ───────────────────────────────────────────────────────────────
func _build_basics(host: VBoxContainer) -> void:
	_add_section(host, "HOW A TURN WORKS", [
		"Every unit — squad and hostile — rolls a D20 at the same time.",
		"Assign your hero rolls to targets, then enemies act, then you gain +1 Protocol.",
		"Each die is split into 5 ability bands; the roll's band decides which ability fires.",
		"Higher roll = stronger ability. Bands run Recharge > Strike > Surge > Crit > Overload.",
		"Overload is the 20 — always that unit's strongest ability.",
	])
	_add_section(host, "READING A UNIT CARD", [
		"Bands differ per unit: glass units reach Crit at 14, tanks need 17 — the card shows its own ranges.",
		"The HP bar is current / max; the thin bar below tracks XP toward evolution.",
		"Status icons appear when active. Long-press a unit to read its full intel.",
	])
	_add_section(host, "EVOLUTION", [
		"Units earn XP each battle by dealing damage, healing, or applying effects.",
		"When the XP bar fills, the unit evolves at battle end.",
		"Choose one of two paths — each changes abilities and raises max HP.",
		"After evolving, continued XP advances toward a MAX-tier upgrade.",
	])
	_add_section(host, "WIN / LOSS", [
		"Clear every enemy to win the battle.",
		"A full squad wipe ends the run.",
	])

	# Replay the rigged onboarding encounter at any time.
	var replay := Button.new()
	replay.text = "REPLAY TUTORIAL"
	replay.custom_minimum_size = Vector2(0, 84)
	replay.mouse_filter = Control.MOUSE_FILTER_STOP
	PixelUI.style_button(replay, Color(0.06, 0.13, 0.17, 0.98), PixelUI.DT_CYAN, 30)
	replay.add_theme_color_override("font_color", PixelUI.DT_CYAN_BRIGHT)
	replay.pressed.connect(_replay_tutorial)
	host.add_child(replay)


func _replay_tutorial() -> void:
	HelpMenu.dismiss()
	var gs: Node = get_node_or_null("/root/GameState")
	var sm: Node = get_node_or_null("/root/SceneManager")
	if gs != null:
		gs.call("start_tutorial_run")
	if sm != null:
		sm.call("go_to_battle")


func _build_protocol(host: VBoxContainer) -> void:
	_add_section(host, "THE PROTOCOL", [
		"Protocol is a shared squad resource — the signature system.",
		"Starts at 0 each battle, +1 at the end of every turn, caps at 10.",
		"Spend it to manipulate dice before you confirm the turn.",
		"Unspent Protocol can carry between battles (some gear/relics seed a starting pool).",
	])
	_add_section(host, "SPENDING PROTOCOL", [
		"Nudge (1): +3 to a die's effective roll (once per die per turn).",
		"Reroll (2): reroll a single die.",
		"Set (3): set a hero's die to any value.",
	])


func _build_rewards(host: VBoxContainer) -> void:
	_add_section(host, "ITEMS, GEAR & RELICS", [
		"Items: one-use, spent in battle. The reward picker is single-select + confirm.",
		"Gear: permanent passive, applies at battle start (+rolls, +max HP, starting shield).",
		"Relics: run-long global rules that affect every battle.",
	])
	_add_section(host, "RARITY (BORDER COLOR)", [
		"Common — gray.",
		"Uncommon — green.",
		"Rare — blue.",
		"Legendary — gold.",
	])
	_add_section(host, "ICON FRAME = TYPE", [
		"Heart — heal / support.",
		"Shield — defense.",
		"Skull — damage / kill.",
		"Bolt — energy hit.",
		"Die — dice manipulation.",
		"Cloak — stealth.",
		"Star — buff.",
	])


func _build_keywords(host: VBoxContainer) -> void:
	var data: Dictionary = _dm().get_keywords()
	var keywords: Array = data.get("keywords", [])
	var by_cat: Dictionary = {}
	for kw_variant in keywords:
		var kw: Dictionary = kw_variant
		var cat: String = str(kw.get("category", "other"))
		if not by_cat.has(cat):
			by_cat[cat] = []
		(by_cat[cat] as Array).append(kw)

	var ordered: Array = HELP_CATEGORY_ORDER.duplicate()
	for cat in by_cat.keys():
		if not ordered.has(cat):
			ordered.append(cat)

	for cat in ordered:
		if not by_cat.has(cat):
			continue
		host.add_child(_make_label(str(cat).to_upper(), SECTION_FONT, SECTION_HEADER_COLOR, HORIZONTAL_ALIGNMENT_LEFT, 3))
		for kw_variant in by_cat[cat]:
			_add_keyword_row(host, kw_variant)

	var conventions: Dictionary = data.get("conventions", {})
	var convention_lines: Array = []
	if conventions.has("duration"):
		convention_lines.append(str(conventions["duration"]))
	if conventions.has("targeting"):
		convention_lines.append(str(conventions["targeting"]))
	if not convention_lines.is_empty():
		_add_section(host, "CONVENTIONS", convention_lines)


func _add_keyword_row(parent: VBoxContainer, kw: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var icon_frame := PanelContainer.new()
	icon_frame.custom_minimum_size = Vector2(64, 64)
	icon_frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	icon_frame.mouse_filter = Control.MOUSE_FILTER_PASS
	PixelUI.style_panel(icon_frame, Color(0.035, 0.050, 0.078, 0.92), Color(0.22, 0.34, 0.48, 0.95), 2, 0)
	row.add_child(icon_frame)

	var icon_key: String = str(HELP_KEYWORD_ICON.get(str(kw.get("id", "")), ""))
	var icon_texture: Texture2D = PixelUI.pip_texture_for_key(icon_key)
	if icon_texture != null:
		var icon := TextureRect.new()
		icon.texture = icon_texture
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(50, 50)
		icon.mouse_filter = Control.MOUSE_FILTER_PASS
		icon_frame.add_child(icon)
	else:
		# fix-2.6: no pixel icon — show the keyword's canonical pip CODE from the
		# registry (SI, CH, DT, ...), never a hand-derived first letter. Entries
		# without a code (e.g. Protocol Gain) fall back to the initial.
		var chip_text: String = str(kw.get("code", str(kw.get("term", "?")).substr(0, 1).to_upper()))
		var chip_font: int = 36 if chip_text.length() <= 1 else 28
		var letter := _make_label(chip_text, chip_font, PixelUI.DT_CYAN, HORIZONTAL_ALIGNMENT_CENTER, 2)
		letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		letter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon_frame.add_child(letter)

	var text_box := VBoxContainer.new()
	text_box.mouse_filter = Control.MOUSE_FILTER_PASS
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 2)
	row.add_child(text_box)

	text_box.add_child(_make_label(str(kw.get("term", "")).to_upper(), TERM_FONT, PixelUI.GOLD_ACCENT, HORIZONTAL_ALIGNMENT_LEFT, 2))
	text_box.add_child(_make_wrap_label(str(kw.get("def", "")), BODY_FONT, PixelUI.TEXT_PRIMARY, 2))
	var syntax: String = str(kw.get("syntax", "")).strip_edges()
	if syntax != "":
		text_box.add_child(_make_wrap_label(syntax, SYNTAX_FONT, PixelUI.TEXT_MUTED, 1))


# ── UNITS codex ───────────────────────────────────────────────────────────────
func _build_codex(host: VBoxContainer) -> void:
	var selector := GridContainer.new()
	selector.columns = 2
	selector.mouse_filter = Control.MOUSE_FILTER_PASS
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selector.add_theme_constant_override("h_separation", 8)
	selector.add_theme_constant_override("v_separation", 8)
	host.add_child(selector)

	_codex_buttons.clear()
	var units: Dictionary = _dm().units
	var first_id: String = ""
	for unit_id_variant in units.keys():
		var unit_id: String = str(unit_id_variant)
		var unit: UnitData = units[unit_id_variant] as UnitData
		if unit == null:
			continue
		if first_id == "":
			first_id = unit_id
		var btn := Button.new()
		btn.text = unit.callsign if unit.callsign != "" else unit.display_name
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 66)
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.pressed.connect(_select_codex_unit.bind(unit_id))
		selector.add_child(btn)
		_codex_buttons[unit_id] = btn

	_codex_detail = VBoxContainer.new()
	_codex_detail.mouse_filter = Control.MOUSE_FILTER_PASS
	_codex_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_codex_detail.add_theme_constant_override("separation", 14)
	host.add_child(_codex_detail)

	var target: String = _codex_unit if units.has(_codex_unit) else first_id
	if target != "":
		_select_codex_unit(target)


func _select_codex_unit(unit_id: String) -> void:
	_codex_unit = unit_id
	for known_id in _codex_buttons.keys():
		_style_tab_button(_codex_buttons[known_id], str(known_id) == unit_id)
	if _codex_detail == null or not is_instance_valid(_codex_detail):
		return
	for child in _codex_detail.get_children():
		child.queue_free()
	var unit: UnitData = _dm().get_unit(unit_id) as UnitData
	if unit == null:
		return
	_build_codex_unit_detail(_codex_detail, unit)


func _build_codex_unit_detail(host: VBoxContainer, unit: UnitData) -> void:
	var title: String = unit.callsign if unit.callsign != "" else unit.display_name
	host.add_child(_make_wrap_label("%s · %s · %d HP" % [title.to_upper(), unit.class_name_text.to_upper(), unit.max_hp], HEADER_FONT, PixelUI.GOLD_ACCENT, 3))
	if unit.picker_blurb.strip_edges() != "":
		host.add_child(_make_wrap_label(unit.picker_blurb, BLURB_FONT, PixelUI.TEXT_MUTED, 1))

	_add_band_table(host, "ABILITIES", unit.dice_ranges)

	# evolution_paths is flat (one entry per ability); group by path name into the two evos.
	var groups: Dictionary = {}
	var order: Array = []
	for path_variant in unit.evolution_paths:
		var path: Dictionary = path_variant
		var nm: String = str(path.get("name", ""))
		if not groups.has(nm):
			groups[nm] = {"callsign": "", "focus": "", "hp": 0, "abilities": []}
			order.append(nm)
		var g: Dictionary = groups[nm]
		if str(path.get("callsign", "")) != "":
			g["callsign"] = str(path.get("callsign", ""))
		if str(path.get("focus", "")) != "":
			g["focus"] = str(path.get("focus", ""))
		if int(path.get("hp", 0)) > 0:
			g["hp"] = int(path.get("hp", 0))
		for ability_variant in path.get("abilities", []):
			(g["abilities"] as Array).append(ability_variant)

	if not order.is_empty():
		host.add_child(_make_label("EVOLUTIONS", SECTION_FONT, PixelUI.GOLD_ACCENT, HORIZONTAL_ALIGNMENT_LEFT, 3))
		for nm in order:
			var g: Dictionary = groups[nm]
			var evo_title: String = str(g["callsign"]) if str(g["callsign"]) != "" else nm
			var label: String = "%s · %d HP" % [evo_title.to_upper(), int(g["hp"])]
			if str(g["focus"]) != "":
				label = "%s · %s · %d HP" % [evo_title.to_upper(), str(g["focus"]), int(g["hp"])]
			_add_band_table(host, label, g["abilities"])


func _add_band_table(host: VBoxContainer, label: String, ability_entries: Array) -> void:
	host.add_child(_make_wrap_label(label, TERM_FONT, SECTION_HEADER_COLOR, 2))
	for ability_variant in ability_entries:
		var ability: Dictionary = ability_variant
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 12)
		host.add_child(row)

		var range_label := _make_label("%d-%d" % [int(ability.get("min", 0)), int(ability.get("max", 0))], RANGE_FONT, PixelUI.DT_CYAN, HORIZONTAL_ALIGNMENT_LEFT, 2)
		range_label.custom_minimum_size = Vector2(118, 0)
		range_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		row.add_child(range_label)

		var text_box := VBoxContainer.new()
		text_box.mouse_filter = Control.MOUSE_FILTER_PASS
		text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_box.add_theme_constant_override("separation", 1)
		row.add_child(text_box)

		text_box.add_child(_make_wrap_label(str(ability.get("ability_name", "")), BODY_FONT, PixelUI.GOLD_ACCENT, 2))
		var eff: String = str(ability.get("description", "")).strip_edges()
		if eff != "":
			text_box.add_child(_make_wrap_label(eff, SYNTAX_FONT, PixelUI.TEXT_PRIMARY, 1))


# ── BESTIARY codex (all unlocked; discovery gating comes later) ─────────────────
func _build_bestiary(host: VBoxContainer) -> void:
	var factions: Array = []
	for enemy_variant in _dm().enemies.values():
		var enemy: EnemyData = enemy_variant as EnemyData
		if enemy == null:
			continue
		var fac: String = enemy.faction if enemy.faction != "" else enemy.enemy_type
		if not factions.has(fac):
			factions.append(fac)
	var ordered: Array = []
	for f in BESTIARY_FACTION_ORDER:
		if factions.has(f):
			ordered.append(f)
	for f in factions:
		if not ordered.has(f):
			ordered.append(f)

	var picker := GridContainer.new()
	picker.columns = 3
	picker.mouse_filter = Control.MOUSE_FILTER_PASS
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.add_theme_constant_override("h_separation", 8)
	picker.add_theme_constant_override("v_separation", 8)
	host.add_child(picker)

	_bestiary_buttons.clear()
	for f in ordered:
		var btn := Button.new()
		btn.text = str(BESTIARY_FACTION_LABEL.get(f, str(f).to_upper()))
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 66)
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.pressed.connect(_select_bestiary_faction.bind(str(f)))
		picker.add_child(btn)
		_bestiary_buttons[str(f)] = btn

	_bestiary_detail = VBoxContainer.new()
	_bestiary_detail.mouse_filter = Control.MOUSE_FILTER_PASS
	_bestiary_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bestiary_detail.add_theme_constant_override("separation", 14)
	host.add_child(_bestiary_detail)

	var target: String = _bestiary_faction if ordered.has(_bestiary_faction) else (str(ordered[0]) if not ordered.is_empty() else "")
	if target != "":
		_select_bestiary_faction(target)


func _select_bestiary_faction(faction: String) -> void:
	_bestiary_faction = faction
	for known_id in _bestiary_buttons.keys():
		_style_tab_button(_bestiary_buttons[known_id], str(known_id) == faction)
	if _bestiary_detail == null or not is_instance_valid(_bestiary_detail):
		return
	for child in _bestiary_detail.get_children():
		child.queue_free()
	for enemy_variant in _dm().enemies.values():
		var enemy: EnemyData = enemy_variant as EnemyData
		if enemy == null:
			continue
		var fac: String = enemy.faction if enemy.faction != "" else enemy.enemy_type
		if fac == faction:
			_add_bestiary_entry(_bestiary_detail, enemy)


func _add_bestiary_entry(host: VBoxContainer, enemy: EnemyData) -> void:
	var entry := VBoxContainer.new()
	entry.mouse_filter = Control.MOUSE_FILTER_PASS
	entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry.add_theme_constant_override("separation", 1)
	host.add_child(entry)

	entry.add_child(_make_wrap_label(enemy.display_name.to_upper(), TERM_FONT, PixelUI.GOLD_ACCENT, 2))

	var stats: String = "HP %d" % enemy.max_hp
	if enemy.damage_preview_max > 0:
		stats += " · Attack %d-%d" % [enemy.damage_preview_min, enemy.damage_preview_max]
	entry.add_child(_make_label(stats, BODY_FONT, PixelUI.TEXT_PRIMARY, HORIZONTAL_ALIGNMENT_LEFT, 1))

	var keywords: String = _enemy_keyword_summary(enemy)
	if keywords != "":
		entry.add_child(_make_wrap_label("Applies: %s" % keywords, SYNTAX_FONT, PixelUI.TEXT_MUTED, 1))


func _enemy_keyword_summary(enemy: EnemyData) -> String:
	var found: Array = []
	for ability_variant in enemy.dice_ranges:
		var ability: Dictionary = ability_variant
		var raw: Dictionary = ability.get("raw", {})
		var tags: Array = []
		if int(raw.get("burn", 0)) > 0:
			tags.append("Burn")
		if int(raw.get("rfe", 0)) > 0:
			tags.append("Roll Down")
		if int(raw.get("shield", 0)) > 0 or int(raw.get("shieldAlly", 0)) > 0:
			tags.append("Shield")
		if int(raw.get("heal", 0)) > 0 or int(raw.get("lifestealPct", 0)) > 0:
			tags.append("Heal")
		if bool(raw.get("blastAll", false)):
			tags.append("AoE")
		if bool(raw.get("ward", false)):
			tags.append("Firewall")
		if bool(raw.get("wipeShields", false)):
			tags.append("Shield Wipe")
		if int(raw.get("freezeEnemyDice", 0)) > 0 or int(raw.get("freezeAllEnemyDice", 0)) > 0 or int(raw.get("freezeAnyDice", 0)) > 0:
			tags.append("Freeze")
		if int(raw.get("summonChance", 0)) > 0 or str(raw.get("summonName", "")) != "":
			tags.append("Summon")
		for tag in tags:
			if not found.has(tag):
				found.append(tag)
	return ", ".join(found)


# ── SETTINGS ─────────────────────────────────────────────────────────────────────
func _build_settings(host: VBoxContainer) -> void:
	host.add_child(_make_label("AUDIO", SECTION_FONT, SECTION_HEADER_COLOR, HORIZONTAL_ALIGNMENT_LEFT, 3))
	_add_toggle_row(host, "Mute all audio", _audio_muted(), _on_toggle_mute)
	# Room for more settings here later (e.g. volume sliders, haptics, reduced motion).

	# --- Dev tools ---
	host.add_child(_make_label("DEV", SECTION_FONT, SECTION_HEADER_COLOR, HORIZONTAL_ALIGNMENT_LEFT, 3))
	var unlock_btn := _make_dev_button("UNLOCK ALL (DEV)", false)
	unlock_btn.pressed.connect(_on_dev_unlock_all)
	host.add_child(unlock_btn)
	_reset_armed = false
	_reset_dev_button = _make_dev_button("RESET SAVE PROFILE (DEV)", true)
	_reset_dev_button.pressed.connect(_on_dev_reset_profile)
	host.add_child(_reset_dev_button)
	# Clears only onboarding.primers_seen — every keyword primer fires fresh again.
	var reset_primers_btn := _make_dev_button("RESET PRIMERS (DEV)", false)
	reset_primers_btn.pressed.connect(_on_dev_reset_primers)
	host.add_child(reset_primers_btn)


func _on_dev_reset_primers() -> void:
	SaveManager.dev_reset_primers()


func _make_dev_button(text: String, amber: bool) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(0, 90)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	PixelUI.style_primary_button(btn, BODY_FONT, amber)
	return btn


func _on_dev_unlock_all() -> void:
	SaveManager.dev_unlock_all()
	# Rebuild the underlying screen so unlock state (locked heroes/ops) refreshes.
	dismiss()
	get_tree().reload_current_scene()


# Two-step confirm: first tap arms (label + a 3s auto-disarm), second tap resets.
func _on_dev_reset_profile() -> void:
	if not _reset_armed:
		_reset_armed = true
		_reset_dev_button.text = "TAP AGAIN TO CONFIRM"
		PixelUI.style_primary_button(_reset_dev_button, BODY_FONT, true)
		_disarm_reset_after_delay()
		return
	SaveManager.dev_reset_profile()
	_reset_armed = false
	dismiss()
	SceneManager.go_to_main_menu()


func _disarm_reset_after_delay() -> void:
	await get_tree().create_timer(3.0).timeout
	if _reset_armed and is_instance_valid(_reset_dev_button):
		_reset_armed = false
		_reset_dev_button.text = "RESET SAVE PROFILE (DEV)"
		PixelUI.style_primary_button(_reset_dev_button, BODY_FONT, true)


# Live AudioManager node (Variant) so this compiles even when the autoload is absent
# (e.g. the headless capture harness), mirroring _dm().
func _audio() -> Variant:
	return get_node_or_null("/root/AudioManager")


func _audio_muted() -> bool:
	var am: Variant = _audio()
	return am != null and bool(am.is_muted())


func _on_toggle_mute(pressed: bool) -> void:
	var am: Variant = _audio()
	if am != null:
		am.set_muted(pressed)


# A label + ON/OFF toggle button row, styled like the active/inactive tab buttons.
func _add_toggle_row(parent: VBoxContainer, label_text: String, initial: bool, on_toggle: Callable) -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var label := _make_wrap_label(label_text, BODY_FONT, PixelUI.TEXT_PRIMARY, 2)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)

	var btn := Button.new()
	btn.toggle_mode = true
	btn.button_pressed = initial
	btn.custom_minimum_size = Vector2(150, 76)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_style_toggle_button(btn)
	btn.toggled.connect(func(pressed: bool) -> void:
		on_toggle.call(pressed)
		_style_toggle_button(btn))
	row.add_child(btn)


func _style_toggle_button(btn: Button) -> void:
	if btn.button_pressed:
		PixelUI.style_button(btn, Color(0.06, 0.13, 0.17, 0.98), PixelUI.DT_CYAN, TAB_FONT)
		btn.add_theme_color_override("font_color", PixelUI.DT_CYAN_BRIGHT)
		btn.text = "ON"
	else:
		PixelUI.style_button(btn, PixelUI.BG_PANEL_ALT, PixelUI.LINE_DIM, TAB_FONT)
		btn.add_theme_color_override("font_color", PixelUI.TEXT_MUTED)
		btn.text = "OFF"


# ── Shared builders ─────────────────────────────────────────────────────────────
func _add_section(parent: VBoxContainer, title_text: String, bullet_lines: Array) -> void:
	var section := VBoxContainer.new()
	section.mouse_filter = Control.MOUSE_FILTER_PASS
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", 8)
	parent.add_child(section)
	section.add_child(_make_wrap_label(title_text, SECTION_FONT, SECTION_HEADER_COLOR, 3))
	for line_variant in bullet_lines:
		_add_bullet(section, str(line_variant))


func _add_bullet(parent: VBoxContainer, text: String) -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)

	var bullet := _make_label(">", BODY_FONT, PixelUI.GOLD_ACCENT, HORIZONTAL_ALIGNMENT_LEFT, 2)
	bullet.custom_minimum_size = Vector2(30, 0)
	bullet.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	row.add_child(bullet)

	row.add_child(_make_wrap_label(text, BODY_FONT, PixelUI.TEXT_PRIMARY, 2))


func _make_label(text: String, font_size: int, color: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT, outline: int = 2) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = align
	PixelUI.style_label(label, font_size, color, outline)
	return label


func _make_wrap_label(text: String, font_size: int, color: Color, outline: int = 2) -> Label:
	var label := _make_label(text, font_size, color, HORIZONTAL_ALIGNMENT_LEFT, outline)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label
