extends Control

func _ready() -> void:
	_build_preview()


func _build_preview() -> void:
	for child in get_children():
		child.queue_free()

	custom_minimum_size = Vector2(1080, 2400)

	var bg := ColorRect.new()
	bg.color = Color(0.004, 0.008, 0.014, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 28)
	root.offset_left = 24
	root.offset_top = 44
	root.offset_right = -24
	root.offset_bottom = -44
	add_child(root)

	_add_header(root, "COMPACT UNIT CARD PROTOTYPE")
	_add_rail(root, "ENEMY RAIL", _enemy_cards())
	_add_notes(root)
	_add_rail(root, "HERO RAIL", _hero_cards())


func _add_header(parent: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(0, 78)
	PixelUI.apply_pixel_font(label)
	label.add_theme_font_size_override("font_size", 42)
	label.add_theme_color_override("font_color", PixelUI.TEXT_PRIMARY)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 2)
	parent.add_child(label)


func _add_rail(parent: VBoxContainer, title: String, cards: Array) -> void:
	var title_label := Label.new()
	title_label.text = title
	title_label.custom_minimum_size = Vector2(0, 46)
	PixelUI.apply_pixel_font(title_label)
	title_label.add_theme_font_size_override("font_size", 32)
	title_label.add_theme_color_override("font_color", PixelUI.TEXT_MUTED)
	parent.add_child(title_label)

	var rail := HBoxContainer.new()
	rail.custom_minimum_size = Vector2(0, 492)
	rail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rail.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	rail.alignment = BoxContainer.ALIGNMENT_CENTER
	rail.add_theme_constant_override("separation", 14)
	parent.add_child(rail)

	for card_data in cards:
		var card := CompactUnitCard.new()
		card.custom_minimum_size = CompactUnitCard.CARD_SIZE
		card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		card.configure(card_data)
		rail.add_child(card)


func _add_notes(parent: VBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 230)
	PixelUI.style_panel(panel, Color(0.018, 0.030, 0.048, 0.92), Color(0.18, 0.32, 0.48, 0.9), 2, 0)
	parent.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var label := Label.new()
	label.text = "Card target: about 102 x 196 on a 450 x 1000 preview\nAlways visible: name, portrait, HP band, current action, critical statuses\nLong press can show full roll ranges and ability descriptions."
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	PixelUI.apply_pixel_font(label)
	label.add_theme_font_size_override("font_size", 34)
	label.add_theme_color_override("font_color", PixelUI.TEXT_PRIMARY)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 1)
	margin.add_child(label)


func _hero_cards() -> Array:
	return [
		{
			"side": "hero",
			"name": "STRIKE UNIT",
			"current_hp": 55,
			"max_hp": 55,
			"action": "SLASH",
			"portrait": load("res://legacy-angular/public/heroes/combat-portrait.png"),
			"statuses": ["SH"],
		},
		{
			"side": "hero",
			"name": "FIELD ENGINEER",
			"current_hp": 50,
			"max_hp": 50,
			"action": "REPAIR",
			"portrait": load("res://legacy-angular/public/heroes/engineer-portrait.png"),
			"statuses": ["UP", "CL"],
			"targetable": true,
		},
		{
			"side": "hero",
			"name": "SYSTEMS MEDIC",
			"current_hp": 45,
			"max_hp": 45,
			"action": "INFUSE",
			"portrait": load("res://legacy-angular/public/heroes/medic-portrait.png"),
			"statuses": ["POI", "-2", "SH", "FR", "+1"],
		},
		{
			"side": "hero",
			"name": "PULSE TECH",
			"current_hp": 40,
			"max_hp": 40,
			"action": "OVERLOAD",
			"portrait": load("res://legacy-angular/public/heroes/pulse-portrait.png"),
			"statuses": ["POI", "CL"],
			"selected": true,
		},
	]


func _enemy_cards() -> Array:
	return [
		{
			"side": "enemy",
			"name": "SCRAP DRONE",
			"current_hp": 40,
			"max_hp": 40,
			"action": "SHOOT",
			"portrait": load("res://legacy-angular/public/enemies/scrap-portrait.png"),
			"statuses": ["-2"],
		},
		{
			"side": "enemy",
			"name": "RUST DRONE",
			"current_hp": 35,
			"max_hp": 35,
			"action": "RUST",
			"portrait": load("res://legacy-angular/public/enemies/rust-portrait.png"),
			"statuses": ["POI"],
			"selected": true,
		},
		{
			"side": "enemy",
			"name": "SIGNAL BREAKER",
			"current_hp": 45,
			"max_hp": 45,
			"action": "JAM",
			"portrait": load("res://legacy-angular/public/enemies/eclipse-lynx-portrait.png"),
			"statuses": ["TA", "FR"],
		},
		{
			"side": "enemy",
			"name": "SPITE GUARD",
			"current_hp": 60,
			"max_hp": 60,
			"action": "DEFEND",
			"portrait": load("res://legacy-angular/public/enemies/guard-portrait.png"),
			"statuses": ["SH", "+2"],
		},
	]
