# Window sizing for the before/after capture tools (UI batch 2026-09-27).
#
# A 1080x2400 window does not fit a 1440 px tall monitor: Windows clamps it,
# the layout squeezes into the clamped height and the off-screen part renders
# black. When the requested size is taller than the monitor, the root renders
# at the requested size with viewport stretch inside a half-size window, which
# is pixel for pixel what a 1080x2400 phone draws at canvas scale 1.0, and
# root.get_texture() returns the full-size frame.

extends RefCounted


static func apply(root: Window, want: Vector2i) -> void:
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	if want.y > usable.size.y or want.x > usable.size.x:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		root.content_scale_size = want
		DisplayServer.window_set_size(want / 2)
	else:
		DisplayServer.window_set_size(want)
		root.size = want
