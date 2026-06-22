# The ONE shared long-press gesture handler for Overload Protocol. Add as a child of any
# Control; it watches that control's gui_input and disambiguates:
#   - quick press+release        -> `tapped`        (the surface's normal action)
#   - press held past the hold    -> `long_pressed`  (open the InspectPopup)
# A fired long-press SUPPRESSES the tap on release, so the two never both fire. A drag
# beyond MOVE_CANCEL_PX cancels (so scrolling a list never triggers either).
#
# The hold duration lives in exactly one place: PixelUI.INSPECT_HOLD_SEC. No surface
# re-declares it.
class_name LongPressInput
extends Node

signal tapped
signal long_pressed(global_position: Vector2)

const MOVE_CANCEL_PX := 26.0

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
			else:
				_release()
	elif event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed:
			_begin(touch.global_position)
		else:
			_release()
	elif event is InputEventMouseMotion:
		_check_drag((event as InputEventMouseMotion).global_position)
	elif event is InputEventScreenDrag:
		_check_drag((event as InputEventScreenDrag).global_position)


func _begin(global_pos: Vector2) -> void:
	_pressed = true
	_fired = false
	_press_pos = global_pos
	if _timer != null:
		_timer.start()


func _check_drag(global_pos: Vector2) -> void:
	if _pressed and global_pos.distance_to(_press_pos) > MOVE_CANCEL_PX:
		_cancel()


func _on_hold_elapsed() -> void:
	if not _pressed:
		return
	_fired = true
	long_pressed.emit(_press_pos)


func _release() -> void:
	if not _pressed:
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
