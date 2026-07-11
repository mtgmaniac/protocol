# Animated three-layer title logo (dimmed base + two additive glow layers stacked at
# identical registration). Boot-in with a reactor-ignite overshoot, two desynced idle
# glow pulses, an occasional horizontal glitch tear, and a flare-out for BEGIN.
# Tween-driven throughout — no AnimationPlayer, no per-frame _process.
extends Control

# Fires when the boot-in sequence has settled (reactor ignited, idle loops running).
signal boot_finished
# Fires when the flare-out has fully faded the logo.
signal flare_finished

# Idle pulse tuning. The asymmetric up/down times and the mismatched periods between
# the two glows are INTENTIONAL — synced pulses read mechanical. Do not equalize.
@export var core_pulse_lo := 0.35
@export var core_pulse_hi := 1.0
@export var core_pulse_up := 0.85
@export var core_pulse_down := 1.25
@export var proto_pulse_lo := 0.55
@export var proto_pulse_hi := 0.90
@export var proto_pulse_up := 1.30
@export var proto_pulse_down := 1.70

# Glitch tear tuning. Offsets are design px on the 1080-wide layout; keep them EVEN
# so the tear lands on whole physical pixels at the 540-wide half-scale preview.
@export var glitch_interval_min := 5.0
@export var glitch_interval_max := 9.0
@export var glitch_tear_right := 6.0
@export var glitch_tear_left := 4.0
@export var glitch_tear_hold := 0.035

@onready var _stack: Control = $Stack
@onready var _base: TextureRect = $Stack/Base
@onready var _core_glow: TextureRect = $Stack/CoreGlow
@onready var _proto_glow: TextureRect = $Stack/ProtoGlow

# Rest position cached once; every tear returns here so cuts never accumulate drift.
var _rest_x := 0.0
var _core_pulse_tween: Tween
var _proto_pulse_tween: Tween
var _glitch_tween: Tween
var _flaring := false


func _ready() -> void:
	_rest_x = _stack.position.x
	_update_pivot()
	_stack.resized.connect(_update_pivot)
	# Powered-down until boot_in().
	_base.modulate.a = 0.0
	_core_glow.modulate.a = 0.0
	_proto_glow.modulate.a = 0.0


func _exit_tree() -> void:
	for tween: Tween in [_core_pulse_tween, _proto_pulse_tween, _glitch_tween]:
		if tween != null and tween.is_valid():
			tween.kill()


## Starts the power-on sequence; `boot_finished` fires after the reactor ignite
## settles (the ProtoGlow warm-up may still be finishing; idle pulses take over).
## Sequence with `await logo.boot_finished` — NOT a coroutine: awaiting a coroutine
## that dies mid-flight (quit at the menu) leaks a GDScriptFunctionState ref cycle;
## a plain signal await on the node is released cleanly when the node frees.
func boot_in() -> void:
	var boot := create_tween()
	boot.set_parallel(true)
	boot.tween_property(_base, "modulate:a", 1.0, 0.45) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	boot.tween_property(_stack, "scale", Vector2.ONE, 0.55) \
		.from(Vector2(1.04, 1.04)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	boot.finished.connect(_play_ignite, CONNECT_ONE_SHOT)


func _play_ignite() -> void:
	# Reactor ignite: overshoot past full, then settle to the idle floor.
	var ignite := create_tween()
	ignite.tween_property(_core_glow, "modulate:a", 1.35, 0.10) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	ignite.tween_property(_core_glow, "modulate:a", core_pulse_lo, 0.40) \
		.set_trans(Tween.TRANS_SINE)
	ignite.finished.connect(_on_ignite_settled, CONNECT_ONE_SHOT)

	# PROTOCOL wordmark warms up alongside, slightly late.
	var proto := create_tween()
	proto.tween_interval(0.12)
	proto.tween_property(_proto_glow, "modulate:a", proto_pulse_lo, 0.60)
	proto.finished.connect(_start_proto_pulse, CONNECT_ONE_SHOT)


func _on_ignite_settled() -> void:
	_start_core_pulse()
	_schedule_glitch()
	boot_finished.emit()


## Reactor blowout for BEGIN; `flare_finished` fires once the logo has fully faded.
## Sequence with `await logo.flare_finished` (same non-coroutine rationale as boot_in).
func flare_out() -> void:
	_flaring = true
	for tween: Tween in [_core_pulse_tween, _proto_pulse_tween, _glitch_tween]:
		if tween != null and tween.is_valid():
			tween.kill()
	var flare := create_tween()
	flare.set_parallel(true)
	flare.tween_property(_core_glow, "modulate:a", 2.0, 0.12) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	flare.tween_property(_stack, "scale", Vector2(1.03, 1.03), 0.12)
	flare.chain().tween_property(self, "modulate:a", 0.0, 0.18)
	flare.finished.connect(flare_finished.emit, CONNECT_ONE_SHOT)


func _update_pivot() -> void:
	_stack.pivot_offset = _stack.size * 0.5


func _start_core_pulse() -> void:
	if _flaring:
		return
	if _core_pulse_tween != null and _core_pulse_tween.is_valid():
		_core_pulse_tween.kill()
	_core_pulse_tween = create_tween().set_loops()
	_core_pulse_tween.tween_property(_core_glow, "modulate:a", core_pulse_hi, core_pulse_up) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_core_pulse_tween.tween_property(_core_glow, "modulate:a", core_pulse_lo, core_pulse_down) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _start_proto_pulse() -> void:
	if _flaring:
		return
	if _proto_pulse_tween != null and _proto_pulse_tween.is_valid():
		_proto_pulse_tween.kill()
	_proto_pulse_tween = create_tween().set_loops()
	_proto_pulse_tween.tween_property(_proto_glow, "modulate:a", proto_pulse_hi, proto_pulse_up) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_proto_pulse_tween.tween_property(_proto_glow, "modulate:a", proto_pulse_lo, proto_pulse_down) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# Presentation-only randomness — the determinism fence (INVARIANTS #1) covers
# combat/targeting, not menu dressing. The tween is bound to this node, so leaving
# the tree pauses it and freeing kills it: no dangling loop on scene change.
func _schedule_glitch() -> void:
	if _glitch_tween != null and _glitch_tween.is_valid():
		_glitch_tween.kill()
	_glitch_tween = create_tween()
	_glitch_tween.tween_interval(randf_range(glitch_interval_min, glitch_interval_max))
	_glitch_tween.tween_callback(_fire_glitch)


func _fire_glitch() -> void:
	if _flaring or not is_inside_tree():
		return
	# Hard horizontal tear — zero-duration steps, no easing; these are cuts.
	var tear := create_tween()
	tear.tween_property(_stack, "position:x", _rest_x + glitch_tear_right, 0.0)
	tear.tween_interval(glitch_tear_hold)
	tear.tween_property(_stack, "position:x", _rest_x - glitch_tear_left, 0.0)
	tear.tween_interval(glitch_tear_hold)
	tear.tween_property(_stack, "position:x", _rest_x, 0.0)

	# Core stutters in sympathy: choke, flare, then the idle pulse reclaims it.
	if _core_pulse_tween != null and _core_pulse_tween.is_valid():
		_core_pulse_tween.kill()
	var stutter := create_tween()
	stutter.tween_property(_core_glow, "modulate:a", 0.15, 0.03)
	stutter.tween_property(_core_glow, "modulate:a", 1.2, 0.05)
	stutter.finished.connect(_start_core_pulse, CONNECT_ONE_SHOT)

	_schedule_glitch()
