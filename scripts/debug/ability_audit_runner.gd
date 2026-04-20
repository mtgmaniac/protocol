extends Node


func _ready() -> void:
	var timeout_msec: int = 30000
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--audit-timeout="):
			timeout_msec = maxi(int(arg.get_slice("=", 1)), 1000)

	var audit := AbilityAudit.new()
	var result: Dictionary = audit.run(timeout_msec)
	var failures: Array = result.get("failures", [])
	get_tree().quit(1 if failures.size() > 0 else 0)
