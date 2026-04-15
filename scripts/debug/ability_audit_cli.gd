extends SceneTree

const AbilityAuditScript := preload("res://scripts/debug/ability_audit.gd")

var _has_run := false


func _process(_delta: float) -> bool:
	if _has_run:
		return true
	_has_run = true
	var audit: AbilityAudit = AbilityAuditScript.new()
	var result: Dictionary = audit.run(10000)
	quit(1 if int(result.get("failed", 0)) > 0 else 0)
	return true
