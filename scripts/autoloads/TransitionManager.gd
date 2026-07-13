# Scene-transition overlay (docs/TRANSITIONS_SCOPE.md — rulings Kev 2026-07-12,
# cover-phase revision 2026-07-13).
#
# One mechanism: snapshot the outgoing viewport into a full-rect TextureRect on
# this CanvasLayer (layer 200 — above PersistentHeader 8, primers 110, popups
# 130/135), change the scene UNDER the snapshot, then a shader runs a THREE-BEAT
# cover transition: the snapshot dithers OUT to an opaque cover, HOLDS fully
# covered, then the new scene dithers IN from the cover. The two frames are
# never simultaneously visible (the old dissolve-direct read as a crossfade).
# The scene swap happens at the very start, under the opaque snapshot, so the
# load is fully concealed across the OUT+HOLD beats.
#
# Kinds: "dither_dissolve" (0.27s, the default for every scene change) ·
# "power_down" (0.8s, DEFEAT ONLY — it exclusively means you died) · "none".
#
# CONTRACT:
# - Headless degrades to an instant hard cut (zero awaits — smoke tests keep
#   their speed). debug_force_active is the test seam.
# - FAILURE SAFETY: a failed snapshot or missing shader falls through to the
#   hard cut — a transition can never strand the game between scenes.
# - Input is blocked while a transition runs (the overlay is MOUSE_FILTER_STOP).
# - Presentation only (INVARIANTS #1): never touches GameState/combat; the
#   scene change itself is the same change_scene_to_file call as before.
extends CanvasLayer

const LAYER := 200
# ruling: fires constantly, every 50ms is felt. 0.27s = ~0.10 out / 0.05 hold /
# ~0.12 in (the OUT_END/HOLD_END split lives in dither_dissolve.gdshader).
const DISSOLVE_DURATION := 0.27
const POWER_DOWN_DURATION := 0.8  # ruling: the death screen should linger
const SHADERS := {
	"dither_dissolve": "res://assets/shaders/dither_dissolve.gdshader",
	"power_down": "res://assets/shaders/power_down.gdshader",
}

# Test seam (transition_smoke_test.gd): force the overlay path under headless
# so the failure-safety fallback is exercisable.
var debug_force_active: bool = false

var _running: bool = false
var _overlay: TextureRect = null
var _tween: Tween = null


func _ready() -> void:
	layer = LAYER


func change_scene(scene_path: String, kind: String = "dither_dissolve") -> void:
	if _suppressed() or kind == "none" or not SHADERS.has(kind):
		_hard_change(scene_path)
		return
	if _running:
		_cleanup()  # second change mid-transition: finish the old one instantly
	var snapshot: ImageTexture = _snapshot_viewport()
	var shader: Shader = load(str(SHADERS[kind])) as Shader
	if snapshot == null or shader == null:
		_hard_change(scene_path)  # failure safety — never strand between scenes
		return
	_running = true
	_build_overlay(snapshot, shader)
	_hard_change(scene_path)  # new scene loads UNDER the snapshot
	var duration: float = POWER_DOWN_DURATION if kind == "power_down" else DISSOLVE_DURATION
	_tween = create_tween()
	_tween.tween_property(_overlay.material, "shader_parameter/ramp", 1.0, duration)
	_tween.finished.connect(_cleanup, CONNECT_ONE_SHOT)


func _suppressed() -> bool:
	if debug_force_active:
		return false
	return DisplayServer.get_name() == "headless"


func _hard_change(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)


func _snapshot_viewport() -> ImageTexture:
	if DisplayServer.get_name() == "headless":
		return null  # dummy renderer has no frame to read — don't poke it (it ERRORs)
	var vp: Viewport = get_viewport()
	if vp == null:
		return null
	var vt: ViewportTexture = vp.get_texture()
	if vt == null:
		return null
	var img: Image = vt.get_image()
	if img == null or img.is_empty() or img.get_width() <= 0 or img.get_height() <= 0:
		return null
	return ImageTexture.create_from_image(img)


func _build_overlay(snapshot: ImageTexture, shader: Shader) -> void:
	_overlay = TextureRect.new()
	_overlay.name = "TransitionSnapshot"
	_overlay.texture = snapshot
	_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_overlay.stretch_mode = TextureRect.STRETCH_SCALE
	_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP  # input blocked mid-transition
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("ramp", 0.0)
	# Backdrop pulled from PixelUI (never hardcode hex) — power_down collapses
	# over the field background; the dissolve ignores the uniform.
	mat.set_shader_parameter("backdrop", PixelUI.DT_FIELD_BG)
	_overlay.material = mat
	add_child(_overlay)


func _cleanup() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	_running = false
