# Centralizes scene changes so gameplay code does not need to know tree details.
extends Node

const MAIN_MENU_SCENE := "res://scenes/ui/MainMenu.tscn"
const UNIT_SELECT_SCENE := "res://scenes/ui/UnitSelect.tscn"
const BATTLE_SCENE := "res://scenes/battle/BattleScene.tscn"
const REWARD_SCENE := "res://scenes/ui/RewardScreen.tscn"
const RUN_END_SCENE := "res://scenes/ui/RunEndScreen.tscn"
const UNLOCK_SCENE := "res://scenes/ui/UnlockScreen.tscn"
const EVOLUTION_SCENE := "res://scenes/ui/EvolutionScreen.tscn"
const ROUTE_FORK_SCENE := "res://scenes/ui/RouteForkScreen.tscn"
const INTERCEPT_SCENE := "res://scenes/ui/InterceptScreen.tscn"
const ResumeGuard := preload("res://scripts/autoloads/resume_guard.gd")
# The run save's `screen` -> the scene CONTINUE lands on (anything else: battle).
const RESUME_SCENES := {
	"reward": REWARD_SCENE,
	"evolution": EVOLUTION_SCENE,
	"fork": ROUTE_FORK_SCENE,
	"intercept": INTERCEPT_SCENE,
}


# All scene changes route through TransitionManager (docs/TRANSITIONS_SCOPE.md):
# DITHER DISSOLVE is the one default transition (no per-route variants — ruling
# 2026-07-12); headless degrades to the old instant hard cut inside the manager.
func go_to(scene_path: String, transition_kind: String = "dither_dissolve") -> void:
	TransitionManager.change_scene(scene_path, transition_kind)


# ── Save checkpoints ─────────────────────────────────────────────────────────
# Routing is the choke point: every between-node transition in a run passes
# through this file, so "what does CONTINUE resume into" is decided in ONE
# place rather than in five screens. These writes lock in a resolved choice at
# the moment the run commits to its next destination.
#
# Screens ALSO checkpoint at the end of their own _ready, once their offers are
# rolled. That second write is strictly richer (it carries the exact cards) and
# overwrites this one with the same `screen` value, so the two never disagree.


# Post-victory routing (pkg7.2): when a beat sits after the battle just won,
# detour through its screen before the next battle; otherwise advance directly.
func go_to_next_battle_or_beat() -> void:
	var beat: Dictionary = GameState.get_beat_after_battle(GameState.current_battle)
	if not beat.is_empty() and not GameState.consumed_beats.has(GameState.current_battle):
		GameState.consumed_beats.append(GameState.current_battle)
		match str(beat.get("type", "")):
			"fork":
				go_to_route_fork()
				return
			"intercept":
				go_to_intercept()
				return
	GameState.advance_to_next_battle()
	go_to_battle()


# CONTINUE: lands on the screen the run save names WITHOUT saving again. The
# save on disk already says exactly that, and the routing save above would
# replace an end-of-round battle checkpoint with a fresh battle entry before
# the battle scene could restore it (G-48: through the real menu a mid-battle
# CONTINUE never restored its round). Screens still write their own entry save.
func resume_to(screen: String) -> void:
	if ResumeGuard.break_mode() == "routing_save":
		_resume_with_routing_save(screen)
		return
	var scene_path: String = str(RESUME_SCENES.get(screen, BATTLE_SCENE))
	go_to(scene_path)
	SaveManager.watch_resume_landing(scene_path)


# The pre-G-48 CONTINUE routing, kept only for the resume guard gate's
# deliberate break (debug builds, --resume-guard-break=routing_save).
func _resume_with_routing_save(screen: String) -> void:
	match screen:
		"reward":
			go_to_reward_screen()
		"evolution":
			go_to_evolution()
		"fork":
			go_to_route_fork()
		"intercept":
			go_to_intercept()
		_:
			go_to_battle()


func go_to_main_menu() -> void:
	go_to(MAIN_MENU_SCENE)


func go_to_unit_select() -> void:
	go_to(UNIT_SELECT_SCENE)


func go_to_battle() -> void:
	# A read-only battle REVIEW re-enters this scene WITHOUT advancing the run.
	# Checkpointing it would record screen="battle" while the run is really
	# parked on the reward screen, so CONTINUE would restart a battle the player
	# already won. The live entry checkpoints itself in _init_live_battle.
	if not GameState.entering_battle_review:
		SaveManager.checkpoint_run("battle")
	go_to(BATTLE_SCENE)


func go_to_reward_screen() -> void:
	SaveManager.checkpoint_run("reward")
	go_to(REWARD_SCENE)


func go_to_intercept() -> void:
	SaveManager.checkpoint_run("intercept")
	go_to(INTERCEPT_SCENE)


func go_to_route_fork() -> void:
	SaveManager.checkpoint_run("fork")
	go_to(ROUTE_FORK_SCENE)


# POWER DOWN exclusively means you died (ruling 2026-07-12) — defeat only.
# Victory -> run-end and quit-to-menu use the standard dissolve, or the signal
# stops being a signal and becomes an animation.
func go_to_run_end(defeat: bool = false) -> void:
	go_to(RUN_END_SCENE, "power_down" if defeat else "dither_dissolve")


func go_to_evolution() -> void:
	SaveManager.checkpoint_run("evolution")
	go_to(EVOLUTION_SCENE)


# Build F: run summary -> unlock screen (only when the run-end delta is
# non-empty; the run-end screen owns that branch) -> home.
func go_to_unlocks() -> void:
	go_to(UNLOCK_SCENE)
