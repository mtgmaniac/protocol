# The ONE shared long-press gesture handler for Overload Protocol. Add as a child of any
# Control; it watches that control's gui_input and disambiguates:
#   - quick press+release        -> `tapped`        (the surface's normal action)
#   - press held past the hold    -> `long_pressed`  (open the InspectPopup)
# A fired long-press SUPPRESSES the tap on release, so the two never both fire. A drag
# beyond the cancel tolerance cancels (so scrolling a list never triggers either).
#
# The hold duration lives in exactly one place: PixelUI.INSPECT_HOLD_SEC. No surface
# re-declares it.
class_name LongPressInput
extends Node

signal tapped
signal long_pressed(global_position: Vector2)

# Cancel tolerance in screen pixels (CSS pixels on Web) — how far the pointer
# actually travels on the glass, not how far the design space says it moved.
# This was 26 DESIGN px, and design space scales into the window: at the 0.2917x
# of a 1366x700 browser window it came to 7.6 device px, so a mouse drifting
# eight screen pixels during the 0.42 s hold cancelled the gesture. The
# tutorial's inspect beat ("Hold Strike's portrait") has no alternative path, so
# that drift was a dead end. 26 device px is exactly what a 1080-native phone
# always had (final-transform scale 1.0), so touch behaviour is unchanged.
const MOVE_CANCEL_DEVICE_PX := 26.0

var _target: Control = null
var _timer: Timer = null
var _pressed := false
var _fired := false
var _press_pos := Vector2.ZERO


func _ready() -> void:
	_target = get_parent() as Control
	if _target == null:
		push_warning("LongPressInput must be a child of a Control")
		return
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = PixelUI.INSPECT_HOLD_SEC
	add_child(_timer)
	_timer.timeout.connect(_on_hold_elapsed)
	_target.gui_input.connect(_on_gui_input)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_begin(mb.global_position)
			elif mb.canceled:
				_cancel()  # a ScrollContainer took the gesture over
			else:
				_release(mb.global_position)
	elif event is InputEventScreenTouch:
		# Touch events carry no global_position (it was read anyway, a script
		# error on every touch — the gesture only worked through the emulated
		# mouse events). Their local position maps through the target instead.
		var touch: InputEventScreenTouch = event
		if touch.pressed:
			_begin(_touch_global(touch.position))
		elif touch.canceled:
			_cancel()
		else:
			_release(_touch_global(touch.position))
	elif event is InputEventMouseMotion:
		_check_drag((event as InputEventMouseMotion).global_position)
	elif event is InputEventScreenDrag:
		_check_drag(_touch_global((event as InputEventScreenDrag).position))


func _touch_global(local_pos: Vector2) -> Vector2:
	return _target.get_global_transform() * local_pos


func _begin(global_pos: Vector2) -> void:
	_pressed = true
	_fired = false
	_press_pos = global_pos
	if _timer != null:
		_timer.start()


func _check_drag(global_pos: Vector2) -> void:
	if _pressed and global_pos.distance_to(_press_pos) > move_cancel_distance():
		_cancel()


## MOVE_CANCEL_DEVICE_PX expressed in the space the compared positions live in.
## The positions are event GLOBAL positions — design space — and the viewport's
## FINAL transform is what maps design space to window pixels (the same
## transform INVARIANTS #14 exists about; get_global_transform_with_canvas does
## NOT include it). Deliberately the final transform ALONE and not the target's
## own global scale: cards get scaled by punch/zoom feedback mid-gesture, and a
## tolerance that breathed with an animation would cancel holds at random.
func move_cancel_distance() -> float:
	if _target == null or not is_instance_valid(_target) or not _target.is_inside_tree():
		return MOVE_CANCEL_DEVICE_PX
	return cancel_distance_for(_target.get_viewport())


## The same tolerance for any surface that tells a tap from a drag (the inspect
## popup's tap-to-close shares it, rather than a copy of the constant).
static func cancel_distance_for(viewport: Viewport) -> float:
	if viewport == null:
		return MOVE_CANCEL_DEVICE_PX
	var scale: float = viewport.get_final_transform().get_scale().x
	if scale <= 0.0:
		return MOVE_CANCEL_DEVICE_PX
	# Web's backing store includes DPR; pointer travel is measured in CSS px.
	# Native window coordinates already use the display server's input units.
	var density: float = 1.0
	if OS.has_feature("web"):
		density = maxf(1.0, float(JavaScriptBridge.eval("window.devicePixelRatio || 1")))
	return MOVE_CANCEL_DEVICE_PX * density / scale


func _on_hold_elapsed() -> void:
	if not _pressed:
		return
	_fired = true
	long_pressed.emit(_press_pos)


# `global_pos`: where the pointer came up. A ScrollContainer that takes over a
# drag stops the motion events reaching this target, so the travel is checked
# again at release (playtest 2026-10-01: a swipe on a reward row selected it).
func _release(global_pos: Vector2 = Vector2.INF) -> void:
	if not _pressed:
		return
	if global_pos != Vector2.INF and global_pos.distance_to(_press_pos) > move_cancel_distance():
		_cancel()
		return
	_pressed = false
	if _timer != null:
		_timer.stop()
	if _fired:
		# Long-press already handled this gesture; swallow the tap.
		_fired = false
		return
	tapped.emit()


func _cancel() -> void:
	_pressed = false
	_fired = false
	if _timer != null:
		_timer.stop()
