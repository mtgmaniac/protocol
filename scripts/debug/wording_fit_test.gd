# Interaction-wording fit check (cross-platform wording pass, 2026-09-21).
#
#   godot --headless --path . -s scripts/debug/wording_fit_test.gd
#
# The tutorial/primer hint line on the spotlight coach card does NOT wrap; the
# card widens to it but is capped at the screen width minus its margins. So
# every hint string must fit that cap on the NARROWEST layout (the 1080-wide
# portrait design), measured with the real m5x7 font at its real scaled size.
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
		print("[WORDING_FIT] hint %-52s %4.0f / %4.0f px" % ['"%s"' % hint, w, cap])
		if w > cap:
			_failures.append("hint '%s' is %.0f px, over the %.0f px coach width" % [hint, w, cap])
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
