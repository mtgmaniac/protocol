@tool
extends EditorScript

const AbilityAuditScript := preload("res://scripts/debug/ability_audit.gd")


func _run() -> void:
	var audit: AbilityAudit = AbilityAuditScript.new()
	audit.run(10000)
