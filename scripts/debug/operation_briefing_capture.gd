# Captures a deployment slate directly from the reusable overlay.
#   godot --path . --script res://scripts/debug/operation_briefing_capture.gd \
#     --capture-operation=facility --capture-output=res://debug_artifacts/operation_layout/facility_deployment.png
extends Node

const OVERLAY := preload("res://scripts/ui/operation_briefing_overlay.gd")
const DEFAULT_OUTPUT := "res://debug_artifacts/operation_layout/deployment.png"


func _ready() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var operation_id := "facility"
	var output := DEFAULT_OUTPUT
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--capture-operation="):
			operation_id = arg.get_slice("=", 1)
		elif arg.begins_with("--capture-output="):
			output = arg.get_slice("=", 1)
	var overlay := OVERLAY.new()
	get_tree().root.add_child(overlay)
	overlay.present_deployment(operation_id)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var absolute_output: String = ProjectSettings.globalize_path(output) if output.begins_with("res://") else output
	DirAccess.make_dir_recursive_absolute(absolute_output.get_base_dir())
	var result: Error = get_viewport().get_texture().get_image().save_png(absolute_output)
	if result != OK:
		push_error("Deployment capture failed: %s" % error_string(result))
		get_tree().quit(1)
		return
	print("[DEPLOYMENT_CAPTURE] Saved: %s" % absolute_output)
	get_tree().quit(0)
