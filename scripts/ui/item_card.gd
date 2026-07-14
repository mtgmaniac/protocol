# Reusable "item picker" square card builder — the same visual the reward screen uses:
# perfect-square plate, rarity-colored hard border, a LARGE bare item icon (the type
# silhouettes — circle/square/hexagon — were cut 2026-07-10: the boxed type word carries
# type now, the icon carries identity), name, rarity + boxed TYPE chip, effect pips,
# description. All colors via PixelUI tokens; built from an ItemData. Used by the reward
# picker and the in-battle item-targeting overlay so the card looks identical in both.
class_name ItemCard
extends RefCounted

const CARD_PADDING := 18
const CARD_SEP := 8
const CARD_BORDER := 5
const ICON_AREA_SIZE := 190.0
const ICON_TEXTURE_SIZE := 170.0
const NAME_FONT := 44
const LABEL_FONT := 30
const TYPE_CHIP_FONT := 28
const BODY_FONT := 32
const PIP_PROFILE := {
	"icon_size": 52,
	"value_font": 62,
	"duration_ratio": 0.6,
	"icon_value_gap": 5,
	"group_min_width": 96,
	"outline": 2,
	"duration_outline": 2,
}


static func build(item: ItemData, width: float) -> PanelContainer:
	var accent: Color = accent_for(item)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(width, width)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.clip_contents = true
	var style: StyleBoxFlat = PixelUI.make_hard_style(PixelUI.DT_PANEL_BG, accent, CARD_BORDER)
	style.set_content_margin_all(0.0)
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", CARD_PADDING)
	margin.add_theme_constant_override("margin_top", CARD_PADDING)
	margin.add_theme_constant_override("margin_right", CARD_PADDING)
	margin.add_theme_constant_override("margin_bottom", CARD_PADDING)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", CARD_SEP)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vbox)

	vbox.add_child(_icon_area(item, accent))
	vbox.add_child(_label(item.display_name, NAME_FONT, accent))
	vbox.add_child(_type_row(item, accent))
	vbox.add_child(_pip_row(item))
	vbox.add_child(_description(item.description))
	return panel


# Rarity word (plain) + the TYPE word in a small boxed chip — the type cue that
# replaced the shape silhouettes (Kev 2026-07-10).
static func _type_row(item: ItemData, accent: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if item.item_type != "relic":
		var rarity := Label.new()
		rarity.text = _rarity_name(item).to_upper()
		rarity.mouse_filter = Control.MOUSE_FILTER_IGNORE
		PixelUI.style_label(rarity, LABEL_FONT, accent, 1)
		row.add_child(rarity)
	var chip := type_chip(item, accent)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(chip)
	return row


# The boxed type word (RELIC / CONSUMABLE / GEAR) — shared by the reward card,
# the loadout rows, and the gear section of the unit inspect.
static func type_chip(item: ItemData, accent: Color) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var style: StyleBoxFlat = PixelUI.make_hard_style(Color(0.03, 0.045, 0.065, 0.96), accent, 2)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	chip.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = _type_label(item)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUI.style_label(label, TYPE_CHIP_FONT, accent, 0)
	chip.add_child(label)
	return chip


static func accent_for(item: ItemData) -> Color:
	return PixelUI.rarity_color(_rarity_name(item))


static func _rarity_name(item: ItemData) -> String:
	if item.item_type == "relic":
		return "legendary"
	return item.rarity if item.rarity != "" else "common"


static func _type_label(item: ItemData) -> String:
	match item.item_type:
		"gear":
			return "GEAR"
		"consumable":
			return "CONSUMABLE"
		"relic":
			return "RELIC"
	return item.item_type.to_upper()


# Bare, LARGE icon — no outline, no shape frame (Kev 2026-07-10: the icon is
# the star; type is the boxed word below).
static func _icon_area(item: ItemData, _accent: Color) -> Control:
	var center := CenterContainer.new()
	center.custom_minimum_size = Vector2(0, ICON_AREA_SIZE)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if item.icon != null:
		var tex := TextureRect.new()
		tex.custom_minimum_size = Vector2(ICON_TEXTURE_SIZE, ICON_TEXTURE_SIZE)
		tex.texture = item.icon
		tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(tex)
	return center


static func _pip_row(item: ItemData) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var parts: Array = EffectPip.effects_from_passive(item.effect, item.target_kind)
	if parts.is_empty():
		row.add_child(_label("-", BODY_FONT, PixelUI.TEXT_MUTED))
		return row
	for part_variant in parts:
		row.add_child(EffectPip.build_group(part_variant, PIP_PROFILE))
	return row


static func _description(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	PixelUI.style_label(label, BODY_FONT, PixelUI.TEXT_MUTED, 1)
	return label


static func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	PixelUI.style_label(label, font_size, color, 2)
	return label
