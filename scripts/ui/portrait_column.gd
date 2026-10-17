# Centers a screen's existing content inside the portrait design width.
# Only horizontal anchors change; authored edge padding and vertical layout stay.
extends Node

var _content: Control
var _left: float
var _right: float
var enabled := true


func _ready() -> void:
	_content = get_parent() as Control
	_left = _content.offset_left
	_right = _content.offset_right
	get_viewport().size_changed.connect(_fit)
	_fit()


func _exit_tree() -> void:
	get_viewport().size_changed.disconnect(_fit)


func _fit() -> void:
	var wide := enabled and get_viewport().get_visible_rect().size.x > PixelUI.PORTRAIT_WIDTH
	_content.anchor_left = 0.5 if wide else 0.0
	_content.anchor_right = 0.5 if wide else 1.0
	_content.offset_left = _left - PixelUI.PORTRAIT_WIDTH * 0.5 if wide else _left
	_content.offset_right = _right + PixelUI.PORTRAIT_WIDTH * 0.5 if wide else _right
