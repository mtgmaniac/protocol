extends SceneTree

# Native phone-size review of Help navigation and both Icon Guide sections.
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	root.get_node("AudioManager").set_suppressed(true)
	root.size = Vector2i(390, 844)
	root.content_scale_size = Vector2i(1080, 2400)
	var help_script = load("res://scripts/ui/help_menu.gd")
	help_script.open(root)
	var menu = help_script._active
	var tabs: Dictionary = menu.get("_tab_buttons")
	tabs["icons"].pressed.emit()
	await _capture("actions", menu)
	var host: VBoxContainer = menu.get("_content_host")
	var sections := host.get_child(0)
	sections.get_child(1).pressed.emit()
	await _capture("effects", menu)
	var content := host.get_child(1)
	var more: Button = content.get_child(content.get_child_count() - 1)
	more.pressed.emit()
	await process_frame
	if menu.get("_active_tab") != "keywords":
		failures.append("More Effects must open Keywords")
	tabs["icons"].pressed.emit()
	await process_frame
	if menu.get("_content_scroll").scroll_vertical != 0:
		failures.append("Returning to Icon Guide must reset scrolling")
	help_script.dismiss()
	await process_frame
	if help_script.is_open():
		failures.append("Help must still dismiss")
	for failure in failures:
		push_error(failure)
	print("[ICON_GUIDE] %s" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)

func _capture(label: String, menu: Node) -> void:
	for _i in 8:
		await process_frame
	var scroll: ScrollContainer = menu.get("_content_scroll")
	var host: Control = menu.get("_content_host")
	if host.size.x > scroll.size.x + 1:
		failures.append("%s exceeds the content width" % label)
	for node in host.find_children("*", "TextureRect", true, false):
		if node.texture == null:
			failures.append("%s has a missing icon" % label)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var folder := ProjectSettings.globalize_path("res://debug_artifacts/icon-guide/")
		DirAccess.make_dir_recursive_absolute(folder)
		root.get_texture().get_image().save_png(folder + label + ".png")
