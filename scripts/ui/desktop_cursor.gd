extends Node
## Native 32px cursors stay independent of the portrait canvas scale.
const HOTSPOT := Vector2(2, 2)
const CURSOR_SIZE := 32
const TOP_Y := 2
const LEDGE_Y := 21
const BOTTOM_Y := 30
const LEFT_X := 2
const NOTCH_X := 13
const TIP_X := 30
var arrow: ImageTexture
var interactive: ImageTexture

func _ready() -> void:
	if DisplayServer.get_name() == "headless" or OS.has_feature("android") or OS.has_feature("ios"):
		return
	arrow = _make_cursor(false)
	interactive = _make_cursor(true)
	Input.set_custom_mouse_cursor(arrow, Input.CURSOR_ARROW, HOTSPOT)
	Input.set_custom_mouse_cursor(interactive, Input.CURSOR_POINTING_HAND, HOTSPOT)
	get_tree().node_added.connect(_on_node_added)
	_mark_buttons(get_tree().root)

func _make_cursor(active: bool) -> ImageTexture:
	var pixels := Image.create(CURSOR_SIZE, CURSOR_SIZE, false, Image.FORMAT_RGBA8)
	pixels.fill(Color.TRANSPARENT)
	var color: Color = PixelUI.DT_CYAN_BRIGHT if active else PixelUI.DT_CYAN
	# Direct 32px scan conversion of the reference polygon. Every occupied row
	# is one continuous span, so the cursor cannot develop holes from resampling.
	for y in range(TOP_Y, LEDGE_Y + 1):
		var progress: float = float(y - TOP_Y) / float(LEDGE_Y - TOP_Y)
		var right_x: int = roundi(lerpf(float(LEFT_X), float(TIP_X), progress))
		for x in range(LEFT_X, right_x + 1):
			pixels.set_pixel(x, y, color)
	for y in range(LEDGE_Y + 1, BOTTOM_Y + 1):
		var progress: float = float(y - LEDGE_Y) / float(BOTTOM_Y - LEDGE_Y)
		var right_x: int = roundi(lerpf(float(NOTCH_X), float(LEFT_X), progress))
		for x in range(LEFT_X, right_x + 1):
			pixels.set_pixel(x, y, color)
	return ImageTexture.create_from_image(pixels)

func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		node.set_deferred("mouse_default_cursor_shape", Control.CURSOR_POINTING_HAND)

func _mark_buttons(node: Node) -> void:
	_on_node_added(node)
	for child in node.get_children():
		_mark_buttons(child)

func _exit_tree() -> void:
	if arrow != null:
		Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
		Input.set_custom_mouse_cursor(null, Input.CURSOR_POINTING_HAND)
		arrow = null
		interactive = null
