# ProtocolPips — the footer PROTOCOL n/m segment row, drawn on the physical
# pixel grid per the pixel snap law (INVARIANTS #14).
#
# Replaces the HBoxContainer of EXPAND_FILL panels: a box container distributes
# FRACTIONAL widths across the row (accumulated float spacing), so pip edges
# land mid-pixel and gaps render unevenly at window scale. Integer layout
# instead, all in physical pixels:
#   pip_width = floor(track * PIP_FRACTION / total)           (fixed, every pip)
#   gap       = floor((track - total*pip_width) / (total-1))
#   remainder = track - total*pip_width - (total-1)*gap, one extra pixel to
#               each of the LEFTMOST `remainder` gaps.
# Zero overlap by construction; gaps differ by at most 1px.
class_name ProtocolPips
extends Control

const PIP_FRACTION := 0.9  # pip vs gap share of the track (matches the old 2px-sep look)

var total: int = 10:
	set(value):
		total = maxi(value, 1)
		queue_redraw()
var filled: int = 0:
	set(value):
		filled = clampi(value, 0, total)
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	if size.x < 2.0 or size.y < 2.0:
		return
	var xform: Transform2D = PixelUI.physical_transform(self)
	var scale_x: float = maxf(xform.get_scale().x, 0.0001)
	var scale_y: float = maxf(xform.get_scale().y, 0.0001)
	var origin_x: float = xform.get_origin().x
	var origin_y: float = xform.get_origin().y
	# Whole-physical-pixel track and pip geometry.
	var track: int = int(floor(size.x * scale_x))
	var pip_w: int = maxi(int(floor(track * PIP_FRACTION / total)), 1)
	var gap: int = 0
	var remainder: int = 0
	if total > 1:
		gap = int(floor(float(track - total * pip_w) / float(total - 1)))
		remainder = track - total * pip_w - (total - 1) * gap
	var top: int = int(round(origin_y))
	var bottom: int = int(round(origin_y + size.y * scale_y))
	var border: int = 1  # 1 physical px, on the grid by construction
	var x: int = int(round(origin_x))
	for i in total:
		# Map the integer physical rect back to local space for draw_rect.
		var rect := Rect2(
			(float(x) - origin_x) / scale_x,
			(float(top) - origin_y) / scale_y,
			float(pip_w) / scale_x,
			float(bottom - top) / scale_y
		)
		if i < filled:
			draw_rect(rect, PixelUI.DT_AMBER, true)
		else:
			draw_rect(rect, PixelUI.DT_PROTO_EMPTY_BORDER, true)
			var inset := Rect2(
				rect.position + Vector2(float(border) / scale_x, float(border) / scale_y),
				rect.size - Vector2(2.0 * border / scale_x, 2.0 * border / scale_y)
			)
			if inset.size.x > 0.0 and inset.size.y > 0.0:
				draw_rect(inset, PixelUI.DT_PROTO_EMPTY, true)
		x += pip_w + gap
		if i < remainder:
			x += 1
