extends Control


func _ready() -> void:
	pass


func _on_start_run_pressed() -> void:
	AudioManager.play_select()
	SceneManager.go_to_unit_select()
