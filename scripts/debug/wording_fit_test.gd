# Interaction-wording fit check (cross-platform wording pass, 2026-09-21).
#
#   godot --headless --path . -s scripts/debug/wording_fit_test.gd
#
# The tutorial/primer hint line on the spotlight coach card wraps (since the
# 2026-09-26 56 → 64 rung move) but must stay within TWO lines. Every hint is
# laid out on a real SpotlightLayer at each test resolution's design viewport
# (canvas_items + expand: the design is never narrower than 1080) and the
# card must sit inside the screen with no clipped content.
# The Help dev-reset confirm text must fit its full-width Settings button.
extends SceneTree

const SPOTLIGHT := preload("res://scripts/ui/spotlight_layer.gd")
const DESIGN_WIDTH := 1080.0
# Every hint the tutorial controller / keyword primer can put on the card.
const HINTS := [
	"Continue >",
	"Stuck? Select this and we'll do it >",
	"Can't continue? Select this to restart training >",
]

# Physical sizes from TEXT_LEGIBILITY_AUDIT Part 1 §1 (phones in and out of the
# browser, desktop fullscreen/windowed, itch embeds, the editor preview).
const RESOLUTIONS := [
	Vector2(1080, 2400), Vector2(1081, 2047), Vector2(1170, 2532), Vector2(1170, 1992),
	Vector2(1920, 1080), Vector2(1920, 950), Vector2(1920, 885), Vector2(1280, 720),
	Vector2(540, 960), Vector2(540, 1200),
]
const DESIGN_SIZE := Vector2(1080, 2400)
const MAX_HINT_LINES := 2

var _failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var pixel_ui: GDScript = load("res://scripts/ui/pixel_ui.gd")
	var font: Font = pixel_ui.get_pixel_font()
	var hint_size: int = pixel_ui.scale_font_size(SPOTLIGHT.HINT_FONT)
	var cap: float = DESIGN_WIDTH - SPOTLIGHT.SCREEN_MARGIN * 2.0 - SPOTLIGHT.COACH_PAD * 2.0 - SPOTLIGHT.COACH_MEASURE_SLACK
	for hint in HINTS:
		var w: float = font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hint_size).x
		print("[WORDING_FIT] hint %-52s %4.0f / %4.0f px at %d px" % ['"%s"' % hint, w, cap, hint_size])
	for res in RESOLUTIONS:
		await _check_coach_at(res)
	# Help > Settings dev reset: the armed text replaces the label in place on
	# a full-width (EXPAND_FILL) button. The Settings column is inset ~78 px a
	# side (help_menu margins 28 + 22 + 28) = ~924 px at 1080; 800 px is a
	# conservative bound that leaves room for the button's own padding.
	var btn_size: int = pixel_ui.scale_font_size(44)
	var armed: float = font.get_string_size("SELECT AGAIN TO CONFIRM", HORIZONTAL_ALIGNMENT_LEFT, -1, btn_size).x
	print("[WORDING_FIT] dev confirm %.0f / 800 px" % armed)
	if armed > 800.0:
		_failures.append("the dev-reset confirm text (%.0f px) no longer fits the Settings button" % armed)
	# Every glyph must exist in m5x7 (the glyph gate covers this game-wide too).
	for text in HINTS + ["SELECT AGAIN TO CONFIRM", "Hold a unit to inspect its full effects.",
			"Hold a unit to inspect its full intel - abilities, roll ranges, and keywords.",
			"BATTLE RESUMED - ROUND 10"]:
		for i in text.length():
			if not font.has_char(text.unicode_at(i)):
				_failures.append("m5x7 lacks '%s' in '%s'" % [text[i], text])
	if _failures.is_empty():
		print("[WORDING_FIT] PASS")
		quit(0)
		return
	for f in _failures:
		print("[WORDING_FIT] FAIL - %s" % f)
	quit(1)


# canvas_items + expand: the design viewport keeps the whole 1080×2400 visible
# and grows along the spare axis.
func _design_viewport(physical: Vector2) -> Vector2:
	var scale: float = minf(physical.x / DESIGN_SIZE.x, physical.y / DESIGN_SIZE.y)
	return (physical / scale).floor()


# Lay every hint out on a real coach card (tutorial presentation, with a title
# and a two-line body) inside a SubViewport of the design size.
func _check_coach_at(physical: Vector2) -> void:
	var design: Vector2 = _design_viewport(physical)
	var vp := SubViewport.new()
	vp.size = Vector2i(design)
	root.add_child(vp)
	var spot = SPOTLIGHT.new()
	vp.add_child(spot)
	spot.use_training_presentation()
	await process_frame
	var screen := Rect2(Vector2.ZERO, design)
	for hint in HINTS:
		for anchor in [SPOTLIGHT.CoachAnchor.BOTTOM, SPOTLIGHT.CoachAnchor.CENTER]:
			await spot.spotlight([], "Select the Scrap Drone to target it.", anchor, {"title": "TARGET", "hint": hint})
			await process_frame
			var coach: Control = spot._coach
			var hint_label: Label = spot._hint_label
			var rect := Rect2(coach.position, coach.size)
			var lines: int = hint_label.get_line_count()
			var need: float = ceilf(coach.get_combined_minimum_size().y)
			if not screen.encloses(rect):
				_failures.append("%s: coach %s leaves the %s screen with hint '%s'" % [physical, rect, design, hint])
			if lines > MAX_HINT_LINES:
				_failures.append("%s: hint '%s' takes %d lines (max %d)" % [physical, hint, lines, MAX_HINT_LINES])
			if coach.size.y + 0.5 < need:
				_failures.append("%s: coach %.0f px tall, content needs %.0f" % [physical, coach.size.y, need])
			if hint_label.size.x + 0.5 < hint_label.get_minimum_size().x:
				_failures.append("%s: hint '%s' is clipped horizontally" % [physical, hint])
		print("[WORDING_FIT] %4.0fx%-4.0f (design %4.0fx%-4.0f) '%s' coach %.0fx%.0f, hint %d line(s)" % [
			physical.x, physical.y, design.x, design.y, hint.left(12), spot._coach.size.x, spot._coach.size.y, spot._hint_label.get_line_count()])
	vp.queue_free()
	await process_frame
