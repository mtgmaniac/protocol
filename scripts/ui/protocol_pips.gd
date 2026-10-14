# ProtocolPips — the footer PROTOCOL n/m segment row, drawn on the physical
# pixel grid per the pixel snap law (INVARIANTS #14).
#
# Replaces the HBoxContainer of EXPAND_FILL panels: a box container distributes
# FRACTIONAL widths across the row (accumulated float spacing), so pip edges
# land mid-pixel and gaps render unevenly at window scale. Integer layout
# instead, all in physical pixels:
#   pip_width = floor(track * PIP_FRACTION / total)           (fixed, every pip)
#   gap       = floor((track - total*pip_width) / (total-1))  (fixed, every gap)
#   remainder = track - total*pip_width - (total-1)*gap, split into the row's
#               side MARGINS (row centred), never into the gaps.
# Zero overlap and PERFECTLY EVEN spacing by construction (Kev 2026-07-07:
# gaps must be identical, not merely within 1px).
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


# Held for the node's life. A style made inside _draw is freed when _draw
# returns, and its texture goes with it: the queued draw then has no texture and
# paints plain white (the white empty cells of the 2026-10-13 depth prototype).
var _empty_cell: StyleBoxTexture = PixelUI.battle_surface_style("cell")
var _charged_cell: StyleBoxTexture = PixelUI.battle_surface_style("cell_charged")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(queue_redraw)
	# Window resizes change the FINAL transform without resizing controls —
	# re-snap or the layout keeps the previous window scale.
	get_viewport().size_changed.connect(queue_redraw)


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
	# One recessed meter bed; cell positions and capacity are unchanged.
	draw_rect(Rect2(Vector2.ZERO, size), PixelUI.BATTLE_INNER_EDGE, true)
	# Remainder pixels pad the OUTSIDE of the row (centred), keeping every gap
	# identical.
	var x: int = int(round(origin_x)) + remainder / 2
	for i in total:
		# Map the integer physical rect back to local space for draw_rect.
		var rect := Rect2(
			(float(x) - origin_x) / scale_x,
			(float(top) - origin_y) / scale_y,
			float(pip_w) / scale_x,
			float(bottom - top) / scale_y
		)
		draw_style_box(_charged_cell if i < filled else _empty_cell, rect)
		x += pip_w + gap
