# Shared tabbed help / codex overlay, opened from the persistent header's "?" button on any
# screen. Self-contained (reads DataManager + PixelUI only), so it works in battle and on the
# squad picker alike. One panel, content swaps per mini-tab. Dithered-Terminal styling.
class_name HelpMenu
extends CanvasLayer

const MENU_LAYER := 135  # above InspectPopup (130) and the persistent header (8)
# ...except while THIS screen is showing a breakdown: a popup the help menu
# itself opened has to render above the help panel, so the menu ducks under
# the popup layer for the duration. Restored the moment the popup closes.
const MENU_LAYER_UNDER_POPUP := 125

# Mobile-readable font scale (matches the inspect popup, not the old tiny help text).
const TITLE_FONT := 48
const TAB_FONT := 36  # Batch 3: 30 → 36 (category tabs read under duress too)
const SECTION_FONT := 36
const BODY_FONT := PixelUI.FONT_INFO_MIN  # table rows / stats (read under duress — floored, UI review S-1)
const BODY_LONG_FONT := PixelUI.FONT_BODY_MIN  # long-form prose: bullets, keyword definitions (Polish Build A)
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
	{"id": "log", "label": "BATTLE LOG"},
	{"id": "settings", "label": "SETTINGS"},
]
# Battle-log tab cap: plenty to review the fight without building 1000 labels.
const LOG_MAX_LINES := 200
# Each keyword now has its own pip icon (batch 155-179 + the 2026-07-10 icon
# batch: rampage / pack_bonus / summon / self marker). Keyword id -> pip key.
const HELP_KEYWORD_ICON := {
	"burn": "burn", "chain": "chain", "detonate": "detonate", "execute": "execute",
	"breach": "breach", "leech": "leech", "mark": "mark", "spike": "spike",
	"pierce": "pierce", "shield": "shield", "heal": "heal", "revive": "revive",
	"roll_down": "roll_down", "roll_up": "roll_up", "jam": "jam", "rewrite": "rewrite",
	"hijack": "hijack", "freeze": "freeze", "cloak": "cloak", "ward": "firewall",
	"accrete": "accrete", "taunt": "taunt", "siphon": "siphon", "aoe": "aoe",
	"protocol_gain": "protocol", "wipe_shields": "breach",
	"rampage": "rampage", "pack_bonus": "pack_bonus", "summon": "summon",
	"target_self": "self", "target_all": "aoe", "target_lowest": "target_lowest",
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

var _breakdown_open: bool = false

var _content_host: VBoxContainer = null
var _content_scroll: ScrollContainer = null
var _reset_armed: bool = false
var _reset_dev_button: Button = null
var _tab_buttons: Dictionary = {}
var _active_tab: String = ""
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
	# band_height() = HEADER_HEIGHT + the top safe-area inset, so the panel also clears the
	# camera-cutout-grown band on device.
	var header_node := get_node_or_null("/root/PersistentHeader")
	var band_height: float = 144.0
	if header_node != null:
		if header_node.has_method("band_height"):
			band_height = float(header_node.call("band_height"))
		else:
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
	# Bottom clears the gesture-bar inset on device (0 on desktop).
	margin.add_theme_constant_override("margin_bottom", 46 + PixelUI.safe_bottom)
	add_child(margin)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Component: Modal (the old bright-blue border was border noise; the scrim +
	# elevation carry the "this is a layer" read).
	PixelUI.style_component(panel, PixelUI.COMPONENT_MODAL)
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
		tab_button.custom_minimum_size = Vector2(0, 100)
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
		"log":
			_build_battle_log(_content_host)
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

# BATTLE LOG (Kev 2026-07-10): the running combat log, newest first, so a
# player can look back at what happened. Reads the live battle scene's
# accumulated log; outside battle the tab says so.
func _build_battle_log(host: VBoxContainer) -> void:
	var log_text: String = ""
	var scene: Node = get_tree().current_scene
	if scene != null:
		var log_label: Variant = scene.get("battle_log_label")
		if log_label is RichTextLabel and is_instance_valid(log_label):
			log_text = (log_label as RichTextLabel).text
	var lines: Array = []
	for line in log_text.split("\n", false):
		if lines.size() >= LOG_MAX_LINES:
			break
		lines.append(line)
	if lines.is_empty():
		_add_section(host, "BATTLE LOG", ["No battle activity yet."])
		return
	_add_section(host, "BATTLE LOG - NEWEST FIRST", lines)


func _build_basics(host: VBoxContainer) -> void:
	_add_section(host, "HOW A TURN WORKS", [
		"Every unit - squad and hostile - rolls a D20 at the same time.",
		"Assign your hero rolls to targets, then enemies act, then you gain +1 Protocol.",
		"A unit with only one legal target selects it automatically.",
		"Each die is split into 5 ability bands; the roll's band decides which ability fires.",
		"A 20 always fires that unit's ultimate ability.",
	])
	_add_section(host, "READING A UNIT CARD", [
		"The name and portrait identify the unit.",
		"The HP bar reads current / max. Status icons appear when effects are active.",
		"Long-press a unit to read its full intel - abilities, roll ranges, and keywords.",
	])
	_add_section(host, "EVOLUTION", [
		"Units earn XP each battle by dealing damage, healing, or applying effects.",
		"At enough XP, the unit evolves at battle end - choose one of two paths.",
		"Each path changes abilities and raises max HP; more XP later unlocks a directive.",
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
		"Protocol is a shared squad resource that starts at 0 each battle, +1 at the end of every turn, and caps at 10.",
		"Spend it to manipulate dice and use items before you confirm the turn.",
	])
	_add_section(host, "SPENDING PROTOCOL", [
		"Nudge (1): +3 to a die's effective roll (once per die per turn).",
		"Reroll (2): reroll a single die.",
		"Set (4): set a hero's die to any value.",
	])


func _build_rewards(host: VBoxContainer) -> void:
	# Kev 2026-07-10: the icon-frame shape code and rarity color legend are
	# gone — cards carry a boxed TYPE word and the rarity name in plain text.
	_add_section(host, "ITEMS, GEAR & RELICS", [
		"Items: one-use, spent in battle. The reward picker is single-select + confirm.",
		"Gear: permanent passive, applies at battle start (+rolls, +max HP, starting shield).",
		"Relics: run-long global rules that affect every battle.",
		"Every card names its rarity and carries a boxed type tag (CONSUMABLE / GEAR / RELIC).",
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
	PixelUI.style_panel(icon_frame, PixelUI.INSPECT_BG, PixelUI.INSPECT_BORDER, 2, 0)
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
	text_box.add_child(_make_body_label(str(kw.get("def", "")), PixelUI.TEXT_PRIMARY))
	# No trailing syntax line (Kev 2026-07-10): it just repeated the keyword
	# name under its own definition.


# ── UNITS codex ───────────────────────────────────────────────────────────────
# A reference LIST, not a browser: all 24 entries at once (8 heroes, each
# followed by its two evolution branches as indented children). The per-unit
# tab strip and the three full ability tables it revealed are gone — five
# abilities with roll ranges, three times over, is a battle card's job, not a
# reference screen's. The whole table is one long-press away on any row.
func _build_codex(host: VBoxContainer) -> void:
	var list := VBoxContainer.new()
	list.mouse_filter = Control.MOUSE_FILTER_PASS
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	host.add_child(list)

	for unit_variant in _dm().units.values():
		var unit: UnitData = unit_variant as UnitData
		if unit == null:
			continue
		_add_reference_row(
			list, unit.portrait, unit.display_name.to_upper(), unit.max_hp,
			_derive_keyword_line(unit.dice_ranges, "hero", 0), "hero", unit)
		for evolution in _codex_evolution_groups(unit):
			var group: Dictionary = evolution
			# The battlefield card shows the CALLSIGN, so the reference screen
			# names an evolution the same way the player will meet it.
			var evo_title: String = str(group["callsign"]).to_upper()
			var abilities: Array = group["abilities"]
			_add_reference_row(
				list, unit.portrait, evo_title, int(group["hp"]),
				_derive_keyword_line(abilities, "hero", 0), "evolution", group, true)


# evolution_paths is FLAT (one entry per ability) — regroup it into the two
# branches, preserving authored order.
func _codex_evolution_groups(unit: UnitData) -> Array:
	var groups: Dictionary = {}
	var order: Array = []
	for path_variant in unit.evolution_paths:
		var path: Dictionary = path_variant
		var key: String = str(path.get("name", ""))
		if not groups.has(key):
			groups[key] = {"callsign": key, "hp": 0, "abilities": []}
			order.append(key)
		var group: Dictionary = groups[key]
		if str(path.get("callsign", "")) != "":
			group["callsign"] = str(path.get("callsign", ""))
		if int(path.get("hp", 0)) > 0:
			group["hp"] = int(path.get("hp", 0))
		for ability_variant in path.get("abilities", []):
			(group["abilities"] as Array).append(ability_variant)
	var out: Array = []
	for key in order:
		out.append(groups[key])
	return out


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
	# Same row shape as the Units list. The `role` sentence stays in the data
	# and moves to the long-press breakdown: it never scanned as a list row.
	_add_reference_row(
		host, enemy.portrait, enemy.display_name.to_upper(), enemy.max_hp,
		_derive_keyword_line(enemy.dice_ranges, "enemy", enemy.accrete), "enemy", enemy)


func _build_settings(host: VBoxContainer) -> void:
	host.add_child(_make_label("AUDIO", SECTION_FONT, SECTION_HEADER_COLOR, HORIZONTAL_ALIGNMENT_LEFT, 3))
	# Four channel rows (slider + ON/OFF each): MUSIC on MusicManager; SOUND FX /
	# DICE / UI on AudioManager buses. SOUND FX is the parent bus of DICE and UI,
	# so its row scales/mutes both; their rows are independent trims.
	var mm: Variant = _music()
	var am: Variant = _audio()
	_add_channel_row(host, "MUSIC",
		0.3 if mm == null else float(mm.get_music_volume()), _on_music_volume_changed,
		mm == null or bool(mm.is_music_enabled()), _on_toggle_music)
	_add_channel_row(host, "SOUND FX",
		1.0 if am == null else float(am.get_channel_volume("SFX")), _on_channel_volume_changed.bind("SFX"),
		am == null or bool(am.is_channel_enabled("SFX")), _on_channel_toggled.bind("SFX"))
	_add_channel_row(host, "DICE",
		1.0 if am == null else float(am.get_channel_volume("DICE")), _on_channel_volume_changed.bind("DICE"),
		am == null or bool(am.is_channel_enabled("DICE")), _on_channel_toggled.bind("DICE"))
	_add_channel_row(host, "UI",
		1.0 if am == null else float(am.get_channel_volume("UI")), _on_channel_volume_changed.bind("UI"),
		am == null or bool(am.is_channel_enabled("UI")), _on_channel_toggled.bind("UI"))
	_add_toggle_row(host, "Mute all audio", _audio_muted(), _on_toggle_mute)

	# --- Tutorials (Kev 2026-07-10) ---
	host.add_child(_make_label("TUTORIALS", SECTION_FONT, SECTION_HEADER_COLOR, HORIZONTAL_ALIGNMENT_LEFT, 3))
	var sm_t: Variant = _save_manager()
	var primers_on: bool = sm_t == null or bool(sm_t.get_setting("ability_primers_enabled", true))
	_add_toggle_row(host, "One-time ability tips (keyword primers)", primers_on, _on_toggle_ability_primers)

	# --- Feedback (mirrors the main-menu FEEDBACK button; one URL, feedback.gd) ---
	host.add_child(_make_label("FEEDBACK", SECTION_FONT, SECTION_HEADER_COLOR, HORIZONTAL_ALIGNMENT_LEFT, 3))
	var feedback_btn := _make_dev_button("SEND FEEDBACK", true)
	feedback_btn.pressed.connect(_on_send_feedback)
	host.add_child(feedback_btn)

	# --- Dev tools ---
	host.add_child(_make_label("DEV", SECTION_FONT, SECTION_HEADER_COLOR, HORIZONTAL_ALIGNMENT_LEFT, 3))
	# Developer mode: shows the header debug buttons (hidden by default for
	# non-dev hands — UI review DB-1). Persisted in the save profile.
	var sm: Variant = _save_manager()
	var dev_mode_on: bool = sm != null and bool(sm.get_setting("dev_mode", false))
	_add_toggle_row(host, "Developer mode (header debug buttons)", dev_mode_on, _on_toggle_dev_mode)
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

	# --- Debug (Build #3) --- STRUCTURALLY absent outside debug builds: the
	# section is never instantiated in release, so a player cannot reach it.
	# (Unlike DEV above, which is deliberately player-visible per DB-1.)
	if _is_debug_build():
		host.add_child(_make_label("DEBUG", SECTION_FONT, SECTION_HEADER_COLOR, HORIZONTAL_ALIGNMENT_LEFT, 3))
		var overlay_default: bool = bool(ProjectSettings.get_setting("overload/debug/safe_area_overlay", false))
		var overlay_on: bool = sm != null and bool(sm.get_setting("safe_area_overlay", overlay_default))
		var row: HBoxContainer = _add_toggle_row(host, "Safe-area / font diagnostic overlay", overlay_on, _on_toggle_safe_area_overlay)
		row.name = "DebugOverlayToggleRow"

	# Version footer — read from ProjectSettings (project.godot config/version is
	# the single source; never hardcode the string). Nominal 24 → rendered 32,
	# the smallest crisp m5x7 rung: the stamp is chrome, not player-read copy,
	# sized below the ACCENT floor by ruling (Kev 2026-07-24).
	var version_label: Label = _make_label(
		"v" + str(ProjectSettings.get_setting("application/config/version", "")),
		24, PixelUI.INSPECT_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, 0)
	host.add_child(version_label)


func _on_send_feedback() -> void:
	# Synchronous inside the tap's handler — web popup blockers permit
	# gesture-initiated opens only (see feedback.gd).
	Feedback.open_form(self)


func _on_dev_reset_primers() -> void:
	var sm: Variant = _save_manager()
	if sm != null:
		sm.dev_reset_primers()


func _on_toggle_ability_primers(pressed: bool) -> void:
	var sm: Variant = _save_manager()
	if sm != null:
		sm.set_setting("ability_primers_enabled", pressed)


# Variant lookups (mirroring _audio()) so this compiles even when the autoloads
# are absent (e.g. the headless capture harness).
func _save_manager() -> Variant:
	return get_node_or_null("/root/SaveManager")


func _on_toggle_dev_mode(pressed: bool) -> void:
	var sm: Variant = _save_manager()
	if sm != null:
		sm.set_setting("dev_mode", pressed)
	var header: Variant = get_node_or_null("/root/PersistentHeader")
	if header != null:
		header.set_dev_mode(pressed)


# Test seam for the release-absence assertion: OS.is_debug_build() is true in
# every headless/editor run, so the safe-area test injects false here to prove
# the DEBUG section is structurally absent (not merely hidden) in release.
static var debug_build_override: Variant = null

func _is_debug_build() -> bool:
	if debug_build_override != null:
		return bool(debug_build_override)
	return OS.is_debug_build()


# Persist via the ONE settings path (SaveManager), then arm/disarm the live
# overlay without a restart.
func _on_toggle_safe_area_overlay(pressed: bool) -> void:
	var sm: Variant = _save_manager()
	if sm != null:
		sm.set_setting("safe_area_overlay", pressed)
	var overlay: Variant = get_node_or_null("/root/SafeAreaDebug")
	if overlay != null and overlay.has_method("refresh_from_settings"):
		overlay.refresh_from_settings()


func _make_dev_button(text: String, amber: bool) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(0, 110)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	# Kev 2026-07-10: settings buttons + text sized up for phone hands.
	PixelUI.style_primary_button(btn, 44, amber)
	return btn


func _on_dev_unlock_all() -> void:
	var sm: Variant = _save_manager()
	if sm != null:
		sm.dev_unlock_all()
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
	var sm: Variant = _save_manager()
	if sm != null:
		sm.dev_reset_profile()
	_reset_armed = false
	dismiss()
	var scene_mgr: Variant = get_node_or_null("/root/SceneManager")
	if scene_mgr != null:
		scene_mgr.go_to_main_menu()


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


# Live MusicManager node (Variant), same absent-autoload tolerance as _audio().
func _music() -> Variant:
	return get_node_or_null("/root/MusicManager")


func _on_toggle_music(pressed: bool) -> void:
	var mm: Variant = _music()
	if mm != null:
		mm.set_music_enabled(pressed)


func _on_music_volume_changed(value: float) -> void:
	var mm: Variant = _music()
	if mm != null:
		mm.set_music_volume(value)


func _on_channel_volume_changed(value: float, channel: String) -> void:
	var am: Variant = _audio()
	if am != null:
		am.set_channel_volume(channel, value)


func _on_channel_toggled(pressed: bool, channel: String) -> void:
	var am: Variant = _audio()
	if am != null:
		am.set_channel_enabled(channel, pressed)


# A label + ON/OFF toggle button row, styled like the active/inactive tab buttons.
# Returns the row so callers may name/inspect it (Build #3: the DEBUG overlay
# row is asserted structurally absent in release by the safe-area test).
func _add_toggle_row(parent: VBoxContainer, label_text: String, initial: bool, on_toggle: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var label := _make_wrap_label(label_text, 40, PixelUI.TEXT_PRIMARY, 2)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)

	var btn := Button.new()
	btn.toggle_mode = true
	btn.button_pressed = initial
	btn.custom_minimum_size = Vector2(190, 96)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_style_toggle_button(btn)
	btn.toggled.connect(func(pressed: bool) -> void:
		on_toggle.call(pressed)
		_style_toggle_button(btn))
	row.add_child(btn)
	return row


# One audio channel row: label + slider + ON/OFF toggle on a single line, so the
# four channels (MUSIC / SOUND FX / DICE / UI) stack without pushing the section
# below the fold. Slider live-applies on drag; toggle is the channel mute.
func _add_channel_row(parent: VBoxContainer, label_text: String, initial_volume: float,
		on_volume: Callable, initial_on: bool, on_toggle: Callable) -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var label := _make_wrap_label(label_text, 40, PixelUI.TEXT_PRIMARY, 2)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)

	row.add_child(_make_volume_slider(initial_volume, on_volume))

	var btn := Button.new()
	btn.toggle_mode = true
	btn.button_pressed = initial_on
	btn.custom_minimum_size = Vector2(160, 96)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_style_toggle_button(btn)
	btn.toggled.connect(func(pressed: bool) -> void:
		on_toggle.call(pressed)
		_style_toggle_button(btn))
	row.add_child(btn)


# A 0..1 volume slider. Hard-edged track/fill per INVARIANTS #7 (no rounded
# corners); flat square grabber generated from PixelUI colors so no new art
# asset is needed.
func _make_volume_slider(initial: float, on_change: Callable) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = clampf(initial, 0.0, 1.0)
	slider.custom_minimum_size = Vector2(380, 96)
	slider.size_flags_horizontal = Control.SIZE_SHRINK_END
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.mouse_filter = Control.MOUSE_FILTER_STOP
	slider.focus_mode = Control.FOCUS_NONE
	# The track/fill styleboxes need explicit content height or HSlider draws them
	# as a hairline. 32 design px → 16 window px at the half-scale preview.
	var track := PixelUI.make_hard_style(PixelUI.BG_PANEL_ALT, PixelUI.LINE_DIM, 2)
	track.content_margin_top = 16
	track.content_margin_bottom = 16
	# Slider fill is a CONTROL accent (button-family teal tokens), not a panel
	# frame — strong cyan panel borders stay Selected-only.
	var fill := PixelUI.make_hard_style(PixelUI.BTN_PRIMARY_BG_HOVER, PixelUI.BTN_TEAL_BORDER, 2)
	fill.content_margin_top = 16
	fill.content_margin_bottom = 16
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	slider.add_theme_icon_override("grabber", _slider_grabber_icon())
	slider.add_theme_icon_override("grabber_highlight", _slider_grabber_icon())
	slider.add_theme_icon_override("grabber_disabled", _slider_grabber_icon())
	slider.value_changed.connect(on_change)
	return slider


var _grabber_icon: ImageTexture


func _slider_grabber_icon() -> Texture2D:
	if _grabber_icon == null:
		var img := Image.create(28, 64, false, Image.FORMAT_RGBA8)
		img.fill(PixelUI.DT_CYAN)
		_grabber_icon = ImageTexture.create_from_image(img)
	return _grabber_icon


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

	# The chevron marks the entry's FIRST LINE, so it must not stretch to the
	# row height and center itself against a wrapped bullet. SHRINK_BEGIN pins
	# its one-line box to the top of the row; the body tier font matches the
	# prose line box so the two first lines share a baseline.
	var bullet := _make_label(">", BODY_LONG_FONT, PixelUI.GOLD_ACCENT, HORIZONTAL_ALIGNMENT_LEFT, 2)
	bullet.custom_minimum_size = Vector2(30, 0)
	bullet.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	bullet.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(bullet)

	row.add_child(_make_body_label(text, PixelUI.TEXT_PRIMARY))


# Long-form reference prose (Tactical Reference bullets, keyword definitions):
# the body-copy tier — FONT_BODY_MIN + line spacing, wrapped.
func _make_body_label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	PixelUI.style_body_label(label, PixelUI.FONT_BODY_MIN, color)
	return label


# ── Reference rows (Bestiary + Units share ONE row shape) ────────────────────
# Portrait · name · HP · a derived keyword line. Nothing else: the full ability
# table lives one long-press away, the same gesture the battlefield card uses.
# Both screens call _add_reference_row, so they cannot drift apart.

const ROW_KEYWORD_CAP := 4
const ROW_PORTRAIT_BOX := 96.0
const ROW_CHILD_PORTRAIT_BOX := 72.0
const ROW_CHILD_INDENT := 34.0
# m5x7 has no box-drawing glyphs (U+2514/U+251C are TOFU on device — the glyph
# gate catches them), so the evolution connector is ASCII.
const ROW_CHILD_CONNECTOR := "|-"

# Keyword ids that carry a display label differing from the keywords.data.json
# term: the internal `ward` shows as Firewall everywhere in game, roll_down
# reads as two words, and Protocol Gain is just "protocol" in a keyword line.
const ROW_KEYWORD_LABEL := {
	"ward": "firewall",
	"roll_down": "roll down",
	"protocol_gain": "protocol",
	"aoe": "AoE",
}


# The canonical keyword sequence IS the hand-ordered keywords.data.json list —
# the same order the KEYWORDS tab renders. Both screens sort by it so a term
# always sits in the same relative place, whichever screen you are reading.
func _canonical_keyword_ids() -> Array:
	var ids: Array = []
	for entry_variant in (_dm().get_keywords() as Dictionary).get("keywords", []):
		ids.append(str((entry_variant as Dictionary).get("id", "")))
	return ids


func _keyword_row_label(keyword_id: String) -> String:
	if ROW_KEYWORD_LABEL.has(keyword_id):
		return str(ROW_KEYWORD_LABEL[keyword_id])
	for entry_variant in (_dm().get_keywords() as Dictionary).get("keywords", []):
		var entry: Dictionary = entry_variant
		if str(entry.get("id", "")) == keyword_id:
			return str(entry.get("term", "")).to_lower()
	return keyword_id


# Keyword ids ONE ability contributes, read from the structured fields the
# engine actually resolves — never from the authored eff string, which is copy
# and would drift the first time an ability is retuned.
#
# The roll fields are SIDE-INVERTED and this is the one place that matters:
# hero `rfe` lowers an enemy roll and hero `rfm` raises the squad's, but on the
# enemy side `rfm` is the one that lowers a HERO's roll (`erb` is its own
# buff), and no enemy ability uses `rfe` at all. Reading `rfe` for enemies is
# why the old bestiary line never once printed "roll down" — for any of the ten
# kits that have it, the five bosses included.
func _ability_keyword_ids(raw: Dictionary, side: String) -> Array:
	var ids: Array = []
	if int(raw.get("burn", 0)) > 0:
		ids.append("burn")
	if int(raw.get("chain", 0)) > 0:
		ids.append("chain")
	if bool(raw.get("detonate", false)):
		ids.append("detonate")
	if bool(raw.get("execute", false)):
		ids.append("execute")
	if bool(raw.get("breach", false)) or bool(raw.get("breachAll", false)):
		ids.append("breach")
	if bool(raw.get("leech", false)) or int(raw.get("lifestealPct", 0)) > 0:
		ids.append("leech")
	if bool(raw.get("mark", false)):
		ids.append("mark")
	if bool(raw.get("grantRampage", false)) or bool(raw.get("grantRampageAll", false)):
		ids.append("rampage")
	if bool(raw.get("packBonus", false)):
		ids.append("pack_bonus")
	if int(raw.get("spike", 0)) > 0:
		ids.append("spike")
	if bool(raw.get("ignSh", false)):
		ids.append("pierce")
	if int(raw.get("shield", 0)) > 0 or int(raw.get("shieldAlly", 0)) > 0:
		ids.append("shield")
	if int(raw.get("heal", 0)) > 0:
		ids.append("heal")
	if bool(raw.get("cleanse", false)):
		ids.append("cleanse")
	if bool(raw.get("revive", false)) or bool(raw.get("reviveAll", false)):
		ids.append("revive")
	if side == "hero":
		if int(raw.get("rfe", 0)) > 0:
			ids.append("roll_down")
		if int(raw.get("rfm", 0)) > 0:
			ids.append("roll_up")
	else:
		if int(raw.get("rfm", 0)) > 0:
			ids.append("roll_down")
		if int(raw.get("erb", 0)) > 0:
			ids.append("roll_up")
	if bool(raw.get("jam", false)) or bool(raw.get("jamAll", false)):
		ids.append("jam")
	if bool(raw.get("rewrite", false)):
		ids.append("rewrite")
	if bool(raw.get("hijack", false)):
		ids.append("hijack")
	if int(raw.get("freezeEnemyDice", 0)) > 0 or int(raw.get("freezeAllEnemyDice", 0)) > 0 \
			or int(raw.get("freezeAnyDice", 0)) > 0:
		ids.append("freeze")
	if bool(raw.get("cloak", false)):
		ids.append("cloak")
	if bool(raw.get("ward", false)):
		ids.append("ward")
	if bool(raw.get("taunt", false)) or bool(raw.get("enemySelfTaunt", false)):
		ids.append("taunt")
	if int(raw.get("siphon", 0)) > 0:
		ids.append("siphon")
	if int(raw.get("gainProtocol", 0)) > 0:
		ids.append("protocol_gain")
	if bool(raw.get("wipeShields", false)):
		ids.append("wipe_shields")
	if int(raw.get("summonChance", 0)) > 0:
		ids.append("summon")
	return ids


# The keyword line: every term the kit can produce, in canonical order, capped.
# AoE is tagged from DAMAGE AoE (`blastAll`) only — a unit that hits the whole
# enemy line. Squad-wide shields and heals are not what the tag is asking (a
# Bulwark carrying three squad-shields is a shield unit, not an AoE one), which
# is the shape Kev's reference table has.
func _derive_keyword_line(dice_ranges: Array, side: String, accrete: int) -> String:
	var found: Dictionary = {}
	var damage_aoe: int = 0
	for entry_variant in dice_ranges:
		var entry: Dictionary = entry_variant
		var raw: Dictionary = entry.get("raw", {})
		if raw.is_empty():
			continue
		for keyword_id in _ability_keyword_ids(raw, side):
			found[keyword_id] = true
		if bool(raw.get("blastAll", false)):
			damage_aoe += 1
	# Accrete is a UNIT property, not an ability one.
	if accrete > 0:
		found["accrete"] = true
	if damage_aoe > 0:
		found["aoe"] = true
	var labels: Array = []
	for keyword_id in _canonical_keyword_ids():
		if labels.size() >= ROW_KEYWORD_CAP:
			break
		if found.has(keyword_id):
			labels.append(_keyword_row_label(keyword_id))
	return ", ".join(labels)


# ONE row, both screens. The breakdown is described, not built: `source_kind` +
# `source_data` are resolved into an InspectPopup payload only when a row is
# actually long-pressed. Building 62 payloads up front meant running the whole
# resolver (pips, keyword definitions, gear lookups) for every row on every tab
# open, to throw all but at most one away.
func _add_reference_row(host: VBoxContainer, portrait: Texture2D, title: String,
		hp: int, keyword_line: String, source_kind: String, source_data: Variant,
		indented: bool = false) -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 14)
	host.add_child(row)

	var box: float = ROW_CHILD_PORTRAIT_BOX if indented else ROW_PORTRAIT_BOX
	if indented:
		var indent := Control.new()
		indent.custom_minimum_size = Vector2(ROW_CHILD_INDENT, 0)
		indent.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(indent)
		var connector := _make_label(ROW_CHILD_CONNECTOR, TERM_FONT, PixelUI.TEXT_MUTED, HORIZONTAL_ALIGNMENT_LEFT, 1)
		connector.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		connector.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(connector)

	if portrait != null:
		var frame := PanelContainer.new()
		frame.custom_minimum_size = Vector2(box, box)
		frame.clip_contents = true
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var border: Color = PixelUI.DT_ENEMY_BORDER if source_kind == "enemy" else PixelUI.DT_CYAN
		frame.add_theme_stylebox_override("panel", PixelUI.make_hard_style(PixelUI.DT_PANEL_BG, border, 2))
		var tex := TextureRect.new()
		tex.texture = portrait
		tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(tex)
		row.add_child(frame)

	var entry := VBoxContainer.new()
	entry.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	entry.add_theme_constant_override("separation", 1)
	row.add_child(entry)

	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_theme_constant_override("separation", 10)
	entry.add_child(head)
	var name_label := _make_wrap_label(title, TERM_FONT, PixelUI.GOLD_ACCENT, 2)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	var hp_label := _make_label("%d HP" % hp, BODY_FONT, PixelUI.TEXT_PRIMARY, HORIZONTAL_ALIGNMENT_RIGHT, 1)
	hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(hp_label)

	# No "APPLIES:" label — the word is implied, and dropping it puts the terms
	# themselves at the start of the line where they scan.
	if keyword_line != "":
		entry.add_child(_make_wrap_label(keyword_line, SYNTAX_FONT, PixelUI.TEXT_MUTED, 1))

	if source_kind != "":
		var long_press := LongPressInput.new()
		row.add_child(long_press)
		long_press.long_pressed.connect(
			_on_reference_row_long_pressed.bind(source_kind, source_data, row))


# The breakdown, on the battlefield's own gesture. HelpMenu sits ABOVE the
# InspectPopup's layer by design (135 vs 130) so an in-battle popup can't cover
# the help panel; a popup THIS screen opens has to win instead, so the menu
# drops below it for as long as the breakdown is up and restores on dismiss.
# InspectPopup exposes no dismissed signal, hence the polled restore.
func _on_reference_row_long_pressed(_where: Vector2, source_kind: String,
		source_data: Variant, source: Control) -> void:
	var payload: Dictionary = _resolve_row_payload(source_kind, source_data)
	if payload.is_empty():
		return
	var anchor: Rect2 = source.get_global_rect() if is_instance_valid(source) else Rect2()
	var source_id: int = source.get_instance_id() if is_instance_valid(source) else 0
	layer = MENU_LAYER_UNDER_POPUP
	_breakdown_open = true
	set_process(true)
	InspectPopup.open(self, payload, anchor, source_id)
	if not InspectPopup.is_open():
		_restore_layer_after_breakdown()


func _process(_delta: float) -> void:
	if _breakdown_open and not InspectPopup.is_open():
		_restore_layer_after_breakdown()


func _restore_layer_after_breakdown() -> void:
	_breakdown_open = false
	layer = MENU_LAYER
	set_process(false)


# Descriptor -> breakdown payload, built on demand.
func _resolve_row_payload(source_kind: String, source_data: Variant) -> Dictionary:
	match source_kind:
		"hero":
			return InspectResolver.resolve_unit(source_data as UnitData)
		"enemy":
			return _enemy_breakdown_payload(source_data as EnemyData)
		"evolution":
			var group: Dictionary = source_data
			return _evolution_breakdown_payload(
				str(group.get("callsign", "")).to_upper(),
				int(group.get("hp", 0)),
				group.get("abilities", []) as Array)
	return {}


# The enemy breakdown carries the authored `role` sentence. It is appended HERE
# rather than inside InspectResolver so the battlefield long-press is untouched
# — the role line is reference-screen copy, and the popup component itself is
# out of scope for this pass.
func _enemy_breakdown_payload(enemy: EnemyData) -> Dictionary:
	var payload: Dictionary = InspectResolver.resolve_unit(enemy)
	if payload.is_empty():
		return payload
	var role: String = enemy.role.strip_edges()
	if role != "":
		var existing: String = str(payload.get("description", "")).strip_edges()
		payload["description"] = role if existing == "" else "%s\n%s" % [role, existing]
	return payload


# An evolution is not its own UnitData — it lives in unit.evolution_paths in the
# SAME dice_ranges shape — so the breakdown is resolved through a throwaway
# UnitData rather than by teaching InspectResolver a second entry point.
func _evolution_breakdown_payload(evo_name: String, hp: int, abilities: Array) -> Dictionary:
	var stand_in := UnitData.new()
	stand_in.id = ""
	stand_in.display_name = evo_name
	stand_in.max_hp = hp
	var bands: Array[Dictionary] = []
	for ability_variant in abilities:
		bands.append(ability_variant as Dictionary)
	stand_in.dice_ranges = bands
	return InspectResolver.resolve_unit(stand_in)

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
