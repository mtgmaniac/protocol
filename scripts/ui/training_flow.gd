extends RefCounted

const Prompt := preload("res://scripts/ui/training_prompt.gd")

static func finish(parent: Node) -> void:
	var gs = parent.get_node("/root/GameState")
	var sm = parent.get_node("/root/SceneManager")
	parent.get_node("/root/SaveManager").mark_tutorial_done()
	gs.reset_run()
	sm.go_to_unit_select()

static func reward_claimed(parent: Node) -> void:
	var prompt = Prompt.present(parent, "KEEP LEARNING?", "Your item is in Items. The optional next battle covers burn and item use. Training rewards stay in training.", ["CONTINUE TRAINING", "START YOUR RUN"])
	var choice: int = await prompt.chosen
	prompt.queue_free()
	if choice == 1:
		finish(parent)
		return
	var gs = parent.get_node("/root/GameState")
	var items: Array = gs.consumables.duplicate()
	var op: String = gs.selected_operation_id
	gs.start_run(["pulse", "engineer", "medic"], op, -1, true)
	gs.current_battle = 2
	gs.consumables.assign(items)
	gs.tutorial_reward_item_id = str(items[0]) if not items.is_empty() else ""
	parent.get_node("/root/SceneManager").go_to_battle()

static func defeat(parent: Node) -> void:
	var prompt = Prompt.present(parent, "TRY ANOTHER PLAN", "Your squad fell. Retry this training encounter or start your run.", ["RETRY TRAINING", "START YOUR RUN"])
	var choice: int = await prompt.chosen
	prompt.queue_free()
	if choice == 1:
		finish(parent)
		return
	var gs = parent.get_node("/root/GameState")
	var second: bool = gs.current_battle == 2
	var reward: String = gs.tutorial_reward_item_id
	if second:
		gs.start_run(["pulse", "engineer", "medic"], gs.selected_operation_id, -1, true)
		gs.current_battle = 2
		gs.tutorial_reward_item_id = reward
		if reward != "":
			gs.consumables.append(reward)
	else:
		gs.start_tutorial_run(true)
	parent.get_node("/root/SceneManager").go_to_battle()

static func explain_first_item(parent: Node) -> void:
	var save = parent.get_node("/root/SaveManager")
	if save.is_primer_seen("item_acquired") or not save.get_setting("ability_primers_enabled", true):
		return
	var prompt = Prompt.present(parent, "ITEM ACQUIRED", "Your reward is in Items on the battle footer. Using an item costs 1 Protocol and consumes it. Protocol starts at 0; earn 1 each turn.", ["CONTINUE"])
	await prompt.chosen
	save.mark_primer_seen("item_acquired")
	prompt.queue_free()
