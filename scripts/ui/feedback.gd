# Feedback channel — the ONE place the external feedback form URL lives
# (single clearly-marked constant; never duplicate it elsewhere).
#
# Web popup rule: browsers only permit window.open inside (or within the
# transient-activation window of) a user gesture, so open_form MUST be called
# synchronously from the tap's pressed handler — never deferred, never awaited.
# When a blocker refuses the open anyway, a fallback panel shows the short URL
# as readable text so the player can type it.
class_name Feedback
extends RefCounted

const FEEDBACK_URL := "https://forms.gle/eYP6xc1Ef5SSkSk3A"
# Human-typeable form of FEEDBACK_URL for the blocked-popup fallback panel.
const FEEDBACK_URL_SHORT := "forms.gle/eYP6xc1Ef5SSkSk3A"

const PANEL_WIDTH := 780.0
const PANEL_PAD := 36
const TITLE_FONT := 46
const BODY_FONT := 36


# Opens the feedback form; on web-blocked popups, raises the fallback panel on
# `host` (any node in the live scene tree). Call ONLY from a pressed handler.
static func open_form(host: Node) -> void:
	if OS.has_feature("web"):
		# window.open must run synchronously in this (gesture-initiated) call
		# stack; returns 0 when a popup blocker refused it.
		var opened: Variant = JavaScriptBridge.eval(
			"(function(){ try { return window.open('%s', '_blank') ? 1 : 0; } catch (e) { return 0; } })()" % FEEDBACK_URL,
			true)
		if not bool(opened):
			_show_blocked_panel(host)
		return
	OS.shell_open(FEEDBACK_URL)


# Popup-blocked fallback: modal scrim + one panel with the short URL, any tap
# dismisses. Built from PixelUI vocabulary only.
static func _show_blocked_panel(host: Node) -> void:
	if host == null or not host.is_inside_tree():
		return
	var scrim: Control = PixelUI.make_modal_scrim(0.78, true)
	host.add_child(scrim)

	var panel := PanelContainer.new()
	PixelUI.style_panel(panel, PixelUI.BG_PANEL, PixelUI.LINE_BRIGHT, 3)
	# The whole overlay is one tap target: the panel ignores the mouse so every
	# tap (panel included) reaches the scrim's close handler.
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	scrim.add_child(panel)

	var pad := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		pad.add_theme_constant_override(side, PANEL_PAD)
	panel.add_child(pad)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 28)
	pad.add_child(box)

	var title := Label.new()
	title.text = "FEEDBACK"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelUI.style_label(title, TITLE_FONT, PixelUI.DT_AMBER, 3)
	box.add_child(title)

	var body := Label.new()
	body.text = "The browser blocked the link. Type this address:"
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	PixelUI.style_body_label(body, BODY_FONT)
	box.add_child(body)

	var url := Label.new()
	url.text = FEEDBACK_URL_SHORT
	url.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelUI.style_label(url, BODY_FONT, PixelUI.DT_CYAN_BRIGHT, 2)
	box.add_child(url)

	var hint := Label.new()
	hint.text = "Tap anywhere to close."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelUI.style_label(hint, PixelUI.FONT_ACCENT_MIN, PixelUI.TEXT_MUTED, 2)
	box.add_child(hint)

	scrim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			scrim.queue_free())
