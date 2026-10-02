# StateCodePanel — the dev "COPY STATE CODE" result (StateCode, 2026-10-02).
#
# open() MUST be called synchronously inside the tap's pressed handler: browsers
# allow a clipboard write only while the tap's user activation is live (same
# reason as Feedback.open_form). It builds the code, tries the clipboard, then
# ALWAYS shows the code pre-selected, because the clipboard can be refused:
#   * web: a real HTML <textarea> laid over the panel, read-only and selected,
#     so the phone's own long-press -> Copy works with no clipboard permission;
#   * elsewhere: a read-only Godot TextEdit, all text selected.
# Lives on its own CanvasLayer above Help (130) and popups (135), below the
# scene transition (200). Dev-only: reached only after the seven-tap unlock.
class_name StateCodePanel
extends CanvasLayer

const LAYER := 150
const PANEL_WIDTH := 960.0
const BOX_HEIGHT := 1000.0
const TITLE_FONT := 46
const BODY_FONT := 36
const BUTTON_SIZE := Vector2(560, 112)
const BUTTON_FONT := 40
const DOM_ID := "opstate-code"

var _code: String = ""
var _status: Label
var _box: Control
var _poll_left: int = 0


## Builds the code, copies it if the platform allows, shows the panel.
static func open(host: Node) -> StateCodePanel:
	var panel := StateCodePanel.new()
	panel._code = StateCode.export_code()
	var copied: bool = panel._try_clipboard()
	host.get_tree().root.add_child(panel)
	panel._build(copied)
	return panel


func _try_clipboard() -> bool:
	if not OS.has_feature("web"):
		DisplayServer.clipboard_set(_code)
		return true
	# execCommand('copy') answers synchronously; navigator.clipboard reports
	# later through window.__opstateCopy, which _process polls.
	var script: String = """
		(function(text){
			window.__opstateCopy = 'pending';
			var ok = false;
			try {
				var ta = document.createElement('textarea');
				ta.value = text; ta.setAttribute('readonly', '');
				ta.style.position = 'fixed'; ta.style.left = '-9999px';
				document.body.appendChild(ta); ta.select();
				ok = document.execCommand('copy');
				document.body.removeChild(ta);
			} catch (e) { ok = false; }
			if (ok) { window.__opstateCopy = 'ok'; return 1; }
			try {
				navigator.clipboard.writeText(text).then(
					function(){ window.__opstateCopy = 'ok'; },
					function(){ window.__opstateCopy = 'fail'; });
			} catch (e) { window.__opstateCopy = 'fail'; }
			return 0;
		})(%s);
	""" % JSON.stringify(_code)
	var result: Variant = JavaScriptBridge.eval(script, true)
	return int(result if result != null else 0) == 1


func _build(copied: bool) -> void:
	layer = LAYER
	var scrim := PixelUI.make_modal_scrim(0.82, true)
	add_child(scrim)

	var panel := PanelContainer.new()
	PixelUI.style_component(panel, PixelUI.COMPONENT_MODAL)
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)

	var pad := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		pad.add_theme_constant_override(side, 32)
	panel.add_child(pad)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 24)
	pad.add_child(col)

	var title := Label.new()
	title.text = "STATE CODE (DEV)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelUI.style_label(title, TITLE_FONT, PixelUI.DT_CYAN_BRIGHT, 3)
	col.add_child(title)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	PixelUI.style_body_label(_status, BODY_FONT)
	col.add_child(_status)
	_set_status("ok" if copied else ("pending" if OS.has_feature("web") else "fail"))

	if OS.has_feature("web"):
		# Placeholder the DOM textarea is laid over.
		_box = Control.new()
		_box.custom_minimum_size = Vector2(0, BOX_HEIGHT)
		_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(_box)
	else:
		var text := TextEdit.new()
		text.text = _code
		text.editable = false
		text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		text.custom_minimum_size = Vector2(0, BOX_HEIGHT)
		col.add_child(text)
		text.select_all.call_deferred()
		_box = text

	var size_line := Label.new()
	size_line.text = "%d characters. Paste all of it, from OPSTATE1 to the end." % _code.length()
	size_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	size_line.autowrap_mode = TextServer.AUTOWRAP_WORD
	PixelUI.style_label(size_line, 28, PixelUI.TEXT_MUTED, 0)
	col.add_child(size_line)

	var close := Button.new()
	close.text = "CLOSE"
	close.custom_minimum_size = BUTTON_SIZE
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	PixelUI.style_primary_button(close, BUTTON_FONT)
	close.pressed.connect(_close)
	col.add_child(close)

	if OS.has_feature("web"):
		_poll_left = 90
		get_tree().root.size_changed.connect(_place_dom_box)
		_place_dom_box.call_deferred()


func _set_status(state: String) -> void:
	match state:
		"ok":
			_status.text = "Copied to the clipboard. The code is also below."
		"pending":
			_status.text = "Copying..."
		_:
			_status.text = "Couldn't copy automatically. Hold the box below, then Copy."


func _process(_delta: float) -> void:
	if _poll_left <= 0:
		return
	_poll_left -= 1
	var state: Variant = JavaScriptBridge.eval("window.__opstateCopy || ''", true)
	var text: String = str(state) if state != null else ""
	if text == "ok" or text == "fail":
		_set_status(text)
		_poll_left = 0
	elif _poll_left == 0:
		_set_status("fail")


# Lays the HTML textarea exactly over the placeholder: design rect -> window
# pixels (the root's stretch transform) -> CSS pixels (the canvas's own scale).
func _place_dom_box() -> void:
	if _box == null or not is_instance_valid(_box) or not _box.is_inside_tree():
		return
	var xform: Transform2D = get_tree().root.get_final_transform()
	var rect: Rect2 = _box.get_global_rect()
	var top_left: Vector2 = xform * rect.position
	var bottom_right: Vector2 = xform * rect.end
	var script: String = """
		(function(text, x, y, w, h){
			var canvas = document.querySelector('canvas');
			if (!canvas) { return 0; }
			var r = canvas.getBoundingClientRect();
			var sx = r.width / canvas.width, sy = r.height / canvas.height;
			var ta = document.getElementById('%s');
			if (!ta) {
				ta = document.createElement('textarea');
				ta.id = '%s';
				ta.readOnly = true;
				ta.value = text;
				ta.style.cssText = 'position:fixed;z-index:1000;box-sizing:border-box;margin:0;padding:8px;'
					+ 'resize:none;font:12px monospace;word-break:break-all;color:#%s;'
					+ 'background:#%s;border:2px solid #%s;';
				ta.addEventListener('focus', function(){ ta.setSelectionRange(0, ta.value.length); });
				document.body.appendChild(ta);
			}
			ta.style.left = (r.left + x * sx) + 'px';
			ta.style.top = (r.top + y * sy) + 'px';
			ta.style.width = (w * sx) + 'px';
			ta.style.height = (h * sy) + 'px';
			try { ta.focus({preventScroll: true}); } catch (e) {}
			ta.select();
			ta.setSelectionRange(0, ta.value.length);
			return 1;
		})(%s, %f, %f, %f, %f);
	""" % [DOM_ID, DOM_ID, PixelUI.TEXT_PRIMARY.to_html(false), PixelUI.DT_FIELD_BG.to_html(false),
		PixelUI.LINE_DIM.to_html(false), JSON.stringify(_code), top_left.x, top_left.y,
		bottom_right.x - top_left.x, bottom_right.y - top_left.y]
	JavaScriptBridge.eval(script, true)


func _close() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("(function(){ var t = document.getElementById('%s'); if (t) { t.remove(); } })();" % DOM_ID, true)
		if get_tree().root.size_changed.is_connected(_place_dom_box):
			get_tree().root.size_changed.disconnect(_place_dom_box)
	queue_free()


func _exit_tree() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("(function(){ var t = document.getElementById('%s'); if (t) { t.remove(); } })();" % DOM_ID, true)
