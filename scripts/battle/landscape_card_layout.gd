extends RefCounted

## Placement adapter for the SAME CompactUnitCard controls and HP animations.
## The vertical comparison rotates the existing bar, including forecast layers.
const STYLE := preload("res://scripts/battle/landscape_battle_style.gd").VALUES
var _card: CompactUnitCard
var _plate: Control
var _vertical_hp := false

func setup(card: CompactUnitCard) -> void:
	_card = card
	var old_root: Control = card._name_strip.get_parent()
	_plate = Control.new()
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	old_root.get_parent().add_child(_plate)
	for child in [card._portrait_frame, card._name_strip, card._hp_back, card._hp_label, card._status_slot]:
		child.reparent(_plate, false)
		child.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		child.custom_minimum_size = Vector2.ZERO
	old_root.hide()
	card._hp_label.clip_text = true
	_plate.resized.connect(refresh)

func refresh() -> void:
	if _plate == null or _plate.size.x < 2.0:
		return
	var pad: float = STYLE.card_padding
	var inner := _plate.size - Vector2.ONE * pad * 2.0
	var aspect := 0.666667
	if _card.portrait != null:
		aspect = float(_card.portrait.get_width()) / maxf(_card.portrait.get_height(), 1.0)
	var portrait_w: float = minf(inner.x * STYLE.card_portrait_fraction, inner.y * aspect)
	portrait_w = PixelUI.snap_to_physical_px(_plate, portrait_w)
	var portrait_h: float = PixelUI.snap_to_physical_px(_plate, portrait_w / aspect, 1)
	place(_card._portrait_frame, Vector2(pad, pad + (inner.y - portrait_h) * 0.5), Vector2(portrait_w, portrait_h))
	var x: float = pad + portrait_w + STYLE.card_info_gap
	var w: float = inner.x - portrait_w - STYLE.card_info_gap
	for label in [_card._name_label, _card._hp_label]:
		var desired_font: int = int(CompactUnitCard.CARD_NAME_FONT_SIZE * STYLE.card_text_scale)
		var text_w: float = label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, desired_font).x
		var fitted: int = desired_font if text_w <= w else maxi(STYLE.card_min_text_font, int(floorf(desired_font * w / text_w)))
		label.add_theme_font_size_override("font_size", fitted)
	var y: float = pad + maxf(0.0, (inner.y - STYLE.card_name_height - STYLE.card_hp_number_height - STYLE.card_hp_bar_height - STYLE.card_status_height - STYLE.card_info_separation * 2.0) * 0.5)
	place(_card._name_strip, Vector2(x, y), Vector2(w, STYLE.card_name_height))
	y += STYLE.card_name_height
	place(_card._hp_label, Vector2(x, y), Vector2(w, STYLE.card_hp_number_height))
	y += STYLE.card_hp_number_height + STYLE.card_info_separation
	_card._hp_back.rotation = 0.0
	place(_card._hp_back, Vector2(x, y), Vector2(w, STYLE.card_hp_bar_height))
	if _vertical_hp:
		var bar_h: float = inner.y - STYLE.card_name_height - STYLE.card_hp_number_height - STYLE.card_info_separation
		place(_card._hp_back, Vector2(x, pad + inner.y), Vector2(bar_h, STYLE.card_hp_bar_height))
		_card._hp_back.rotation = -PI * 0.5
		place(_card._status_slot, Vector2(x + STYLE.card_hp_bar_height + STYLE.card_info_gap, y), Vector2(w - STYLE.card_hp_bar_height - STYLE.card_info_gap, STYLE.card_status_height))
	else:
		y += STYLE.card_hp_bar_height + STYLE.card_info_separation
		place(_card._status_slot, Vector2(x, y), Vector2(w, STYLE.card_status_height))
	for fill in [_card._hp_fill, _card._hp_chip]:
		fill.anchor_bottom = 1.0
		fill.offset_bottom = 0.0
	_card._locked_portrait_size = _card._portrait_frame.size
	_card._update_portrait_rect_transform()
	_card._populate_statuses()
	_card._layout_preview_overlays()

func place(control: Control, at: Vector2, extent: Vector2) -> void:
	control.position = Vector2(PixelUI.snap_to_physical_px(_plate, at.x), PixelUI.snap_to_physical_px(_plate, at.y, 1))
	control.size = Vector2(PixelUI.snap_to_physical_px(_plate, extent.x), PixelUI.snap_to_physical_px(_plate, extent.y, 1))
