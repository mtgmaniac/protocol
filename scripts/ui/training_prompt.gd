extends CanvasLayer

signal chosen(index: int)

static func present(parent: Node, heading: String, body: String, choices: Array):
	var prompt = load("res://scripts/ui/training_prompt.gd").new()
	parent.add_child(prompt)
	prompt.layer = 115
	var shade := ColorRect.new()
	shade.color = PixelUI.DT_FIELD_BG
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	prompt.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	prompt.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = parent.get_viewport().get_visible_rect().size.x - 80.0
	PixelUI.style_component(panel, PixelUI.COMPONENT_MODAL)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	margin.add_child(box)
	for value in [heading, body]:
		var label := Label.new()
		label.text = value
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 64 if value == heading else 56)
		PixelUI.apply_pixel_font(label)
		box.add_child(label)
	for i in choices.size():
		var button := Button.new()
		button.text = str(choices[i])
		button.custom_minimum_size.y = 128
		PixelUI.style_primary_button(button, 60)
		button.pressed.connect(func(): prompt.chosen.emit(i))
		box.add_child(button)
	return prompt
