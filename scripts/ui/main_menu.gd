# Splash / main menu — the app's boot scene. Animated title logo, a big BEGIN (battle
# Roll-button styling) into the squad picker, plus FEEDBACK. Tutorial replay lives
# in Help. First-run choice (Kev 2026-07-21):
# when SaveManager.tutorial_done is unset, BEGIN raises a one-question overlay —
# RUN TUTORIAL or SKIP — and either path sets the flag and continues into the squad
# picker. Built in code (matching the rest of the UI) over a dark field; the buttons
# stay dark until the logo's boot-in finishes.
#
# Save system: when a valid run.json exists, CONTINUE appears above BEGIN and
# resumes the run on the screen it was checkpointed at; ABANDON RUN (with a
# confirm step) destroys it. Neither control is built when there is no run save,
# so the first-launch menu is unchanged. Two one-line notices can appear under
# the buttons: a discarded run from an older build, and — on web only — a
# warning that this browser mode will not persist progress at all.
extends Control

const TITLE_LOGO_SCENE := preload("res://scenes/ui/TitleLogo.tscn")
const BEGIN_SIZE := Vector2(640, 136)
const BEGIN_FONT := 52
# FEEDBACK keeps the amber secondary treatment; BEGIN is the primary action.
const FEEDBACK_SIZE := Vector2(420, 92)
const FEEDBACK_FONT := 34
# First-run choice overlay (question card after the first BEGIN).
const PROMPT_WIDTH := 780.0
const PROMPT_PAD := 36
const PROMPT_TITLE_FONT := 46
const PROMPT_BODY_FONT := 36
const PROMPT_BUTTON_SIZE := Vector2(560, 112)
const PROMPT_BUTTON_FONT := 40
const PROMPT_SKIP_FONT := 30
# CONTINUE matches BEGIN's primary weight (it is the primary action when a run
# is waiting); ABANDON RUN is the quiet destructive option, sized like FEEDBACK.
const CONTINUE_SIZE := Vector2(640, 136)
const ABANDON_SIZE := Vector2(420, 84)
const ABANDON_FONT := 30
const NOTICE_FONT := 28

var _logo: Control
var _begin_button: Button
var _feedback_button: Button
var _continue_button: Button
var _abandon_button: Button
var _has_run_save: bool = false


func _ready() -> void:
	# Boot → title: loop 1 starts here and won't restart on the way to deploy.
	MusicManager.play_track(&"sci_fi_loop_1")
	MusicManager.set_combat(false)
	# Header carries no run on the splash.
	if is_instance_valid(PersistentHeader):
		PersistentHeader.set_run_active(false)
	# Web: precompile the dice WebGL programs while the player reads the menu
	# (once per session — DiceTray3D gates internally). Deferred so the menu's
	# own first paint isn't sharing frames with the compile hitches.
	if OS.has_feature("web"):
		_start_web_dice_warmup.call_deferred()

	var bg := ColorRect.new()
	bg.color = PixelUI.DT_FIELD_BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Side margins so the wide logo always fits the screen width.
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 80)
	margin.add_theme_constant_override("margin_right", 80)
	margin.add_theme_constant_override("margin_top", 60)
	margin.add_theme_constant_override("margin_bottom", 60)
	add_child(margin)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 48)
	margin.add_child(col)

	# Fixed-height box, full bounded width; the logo scales to fit (keeps aspect, centered).
	_logo = TITLE_LOGO_SCENE.instantiate()
	_logo.custom_minimum_size = Vector2(0, 300)
	_logo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(_logo)

	# Asked ONCE and cached: peek_run_save() validates the schema and may discard
	# the file, so calling it per-frame or per-button would both re-warn and
	# re-discard. The notice it may raise is read after the buttons exist.
	_has_run_save = SaveManager.has_run_save()

	if _has_run_save:
		var resume := Button.new()
		resume.text = "CONTINUE"
		resume.custom_minimum_size = CONTINUE_SIZE
		resume.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		PixelUI.style_primary_button(resume, BEGIN_FONT)
		resume.pressed.connect(_on_continue_pressed)
		col.add_child(resume)
		_continue_button = resume

	var begin := Button.new()
	begin.text = "BEGIN"
	begin.custom_minimum_size = BEGIN_SIZE
	begin.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	PixelUI.style_primary_button(begin, BEGIN_FONT)
	begin.pressed.connect(_on_begin_pressed)
	col.add_child(begin)
	_begin_button = begin

	var feedback := Button.new()
	feedback.text = "FEEDBACK"
	feedback.custom_minimum_size = FEEDBACK_SIZE
	feedback.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	PixelUI.style_button(feedback, PixelUI.BG_PANEL_ALT, PixelUI.DT_AMBER, FEEDBACK_FONT)
	feedback.add_theme_color_override("font_color", PixelUI.DT_AMBER)
	feedback.add_theme_color_override("font_hover_color", PixelUI.DT_AMBER)
	feedback.add_theme_color_override("font_pressed_color", PixelUI.DT_AMBER)
	feedback.pressed.connect(_on_feedback_pressed)
	col.add_child(feedback)
	_feedback_button = feedback

	if _has_run_save:
		var abandon := Button.new()
		abandon.text = "ABANDON RUN"
		abandon.custom_minimum_size = ABANDON_SIZE
		abandon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		PixelUI.style_button(abandon, PixelUI.BG_PANEL_ALT, PixelUI.LINE_DIM, ABANDON_FONT)
		abandon.add_theme_color_override("font_color", PixelUI.TEXT_MUTED)
		abandon.pressed.connect(_on_abandon_pressed)
		col.add_child(abandon)
		_abandon_button = abandon

	_add_notices(col)

	# Buttons arrive only after the reactor ignites.
	begin.disabled = true
	begin.modulate.a = 0.0
	feedback.disabled = true
	feedback.modulate.a = 0.0
	for extra in [_continue_button, _abandon_button]:
		if extra != null:
			extra.disabled = true
			extra.modulate.a = 0.0
	# Last child on purpose: the stamp must paint over the full-rect background.
	_add_version_stamp()
	_logo.boot_in()
	await _logo.boot_finished
	if not is_inside_tree():
		return
	var fade := create_tween()
	fade.set_parallel(true)
	fade.tween_property(begin, "modulate:a", 1.0, 0.25)
	fade.tween_property(feedback, "modulate:a", 1.0, 0.25)
	begin.disabled = false
	feedback.disabled = false
	for extra in [_continue_button, _abandon_button]:
		if extra != null:
			fade.tween_property(extra, "modulate:a", 1.0, 0.25)
			extra.disabled = false


func _on_begin_pressed() -> void:
	# Locked during the flare so a double-tap can't fire the transition twice.
	_begin_button.disabled = true
	AudioManager.play_select()
	_logo.flare_out()
	await _logo.flare_finished
	if not is_inside_tree():
		return
	# First-run choice (Kev 2026-07-21, revised same day: no mid-drill Skip
	# button — the choice happens HERE, once, after the first BEGIN): a profile
	# that has never completed or skipped the drill gets one question — run the
	# tutorial, or head straight in. Unmissable, no menu discovery required.
	# Deleting the user:// save re-triggers first-run behavior (the intended
	# reset path).
	if not SaveManager.is_tutorial_done():
		_show_first_run_prompt()
		return
	SceneManager.go_to_unit_select()


func _on_feedback_pressed() -> void:
	AudioManager.play_select()
	# Synchronous inside the tap's handler — web popup blockers permit
	# gesture-initiated opens only (see feedback.gd).
	Feedback.open_form(self)


# Web-only (no-op elsewhere and after the first run): a tiny hidden DiceTray3D
# renders every dice material variant so WebGL program compilation happens here,
# spread across menu frames, instead of freezing battle entry (~1.3s measured).
# The tray is 64px, alpha-0 and mouse-ignoring — never visible, no layout shift
# (added directly to the scene root, not a container). If the player enters a
# battle before it finishes, the tray dies with the menu and the warm-up's
# start-set gate keeps it from ever running twice.
# Bottom-corner version stamp — read from ProjectSettings (project.godot
# config/version is the single source; never hardcode the string). Nominal 24 →
# rendered 32, the smallest crisp m5x7 rung: the stamp is chrome, not
# player-read copy, sized below the ACCENT floor by ruling (Kev 2026-07-24).
# Overlay label on the scene root (not the layout column) — zero layout shift.
# Margins add the live safe-area insets so the stamp clears the mobile-web
# floors (bottom 48 / left 24) instead of sitting under the corner radius.
func _add_version_stamp() -> void:
	var stamp := Label.new()
	stamp.text = str(ProjectSettings.get_setting("application/config/version", ""))
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUI.style_label(stamp, 24, PixelUI.INSPECT_TEXT_DIM, 0)
	stamp.anchor_left = 0.0
	stamp.anchor_right = 0.0
	stamp.anchor_top = 1.0
	stamp.anchor_bottom = 1.0
	stamp.grow_horizontal = Control.GROW_DIRECTION_END
	stamp.grow_vertical = Control.GROW_DIRECTION_BEGIN
	stamp.offset_left = 24.0 + float(PixelUI.safe_left)
	stamp.offset_bottom = -(16.0 + float(PixelUI.safe_bottom))
	stamp.offset_top = stamp.offset_bottom - 44.0
	add_child(stamp)


func _start_web_dice_warmup() -> void:
	if not is_inside_tree():
		return
	var tray := DiceTray3D.new()
	tray.size = Vector2(64, 64)
	add_child(tray)
	await tray.warm_up_web_pipelines()
	if is_instance_valid(tray):
		tray.queue_free()


# ── First-run choice overlay ──────────────────────────────────────────────────
# One modal question over the darkened splash. RUN TUTORIAL enters the drill
# with the continue flag set (TutorialController._finish → squad picker); SKIP
# sets the SAME tutorial_done flag as completing (one flag, two paths in) and
# heads straight into the squad picker. Neither path returns here.
func _show_first_run_prompt() -> void:
	var scrim := PixelUI.make_modal_scrim(0.78, true)
	add_child(scrim)

	var panel := PanelContainer.new()
	PixelUI.style_panel(panel, PixelUI.BG_PANEL, PixelUI.LINE_BRIGHT, 3)
	panel.custom_minimum_size = Vector2(PROMPT_WIDTH, 0)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)

	var pad := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		pad.add_theme_constant_override(side, PROMPT_PAD)
	panel.add_child(pad)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 28)
	pad.add_child(box)

	var title := Label.new()
	title.text = "FIRST TIME?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelUI.style_label(title, PROMPT_TITLE_FONT, PixelUI.DT_CYAN_BRIGHT, 3)
	box.add_child(title)

	var body := Label.new()
	body.text = "This is your first time playing, want to run the tutorial?"
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	PixelUI.style_body_label(body, PROMPT_BODY_FONT)
	box.add_child(body)

	var run := Button.new()
	run.text = "RUN TUTORIAL"
	run.custom_minimum_size = PROMPT_BUTTON_SIZE
	run.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	PixelUI.style_primary_button(run, PROMPT_BUTTON_FONT)
	run.pressed.connect(_on_first_run_tutorial_pressed)
	box.add_child(run)

	var skip := Button.new()
	skip.text = "SKIP TUTORIAL"
	skip.custom_minimum_size = Vector2(PROMPT_BUTTON_SIZE.x, 92)
	skip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	PixelUI.style_button(skip, PixelUI.BG_PANEL_ALT, PixelUI.LINE_DIM, PROMPT_SKIP_FONT)
	skip.add_theme_color_override("font_color", PixelUI.TEXT_MUTED)
	skip.pressed.connect(_on_first_run_skip_pressed)
	box.add_child(skip)


func _on_first_run_tutorial_pressed() -> void:
	AudioManager.play_select()
	GameState.start_tutorial_run(true)
	SceneManager.go_to_battle()


func _on_first_run_skip_pressed() -> void:
	AudioManager.play_select()
	SaveManager.mark_tutorial_done()
	SceneManager.go_to_unit_select()


# ── Run save: CONTINUE / ABANDON RUN ──────────────────────────────────────────

func _on_continue_pressed() -> void:
	_continue_button.disabled = true
	AudioManager.play_select()
	# resume_run() restores GameState and returns the screen the run was
	# checkpointed at. An empty return means the save evaporated between the
	# menu build and this tap (another tab, a cleared store) — fall back to the
	# normal start rather than dead-ending on a disabled button.
	var screen: String = SaveManager.resume_run()
	if screen == "":
		_continue_button.disabled = false
		return
	MusicManager.play_for_faction(GameState.selected_operation_id)
	_logo.flare_out()
	await _logo.flare_finished
	if not is_inside_tree():
		return
	match screen:
		"reward":
			SceneManager.go_to_reward_screen()
		"evolution":
			SceneManager.go_to_evolution()
		"fork":
			SceneManager.go_to_route_fork()
		"intercept":
			SceneManager.go_to_intercept()
		_:
			SceneManager.go_to_battle()


func _on_abandon_pressed() -> void:
	AudioManager.play_select()
	_show_abandon_confirm()


# Destroying a run is irreversible and the button sits one tap from CONTINUE,
# so it asks first. Modal component (INVARIANTS #7 — six frames, no bespoke
# styleboxes); tap-outside cancels, matching the discard picker's contract that
# a dismissal never destroys anything.
func _show_abandon_confirm() -> void:
	var scrim := PixelUI.make_modal_scrim(0.78, true)
	add_child(scrim)

	var panel := PanelContainer.new()
	PixelUI.style_component(panel, PixelUI.COMPONENT_MODAL)
	panel.custom_minimum_size = Vector2(PROMPT_WIDTH, 0)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)

	var pad := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		pad.add_theme_constant_override(side, PROMPT_PAD)
	panel.add_child(pad)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 28)
	pad.add_child(box)

	var title := Label.new()
	title.text = "ABANDON RUN?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelUI.style_label(title, PROMPT_TITLE_FONT, PixelUI.DT_AMBER, 3)
	box.add_child(title)

	var body := Label.new()
	body.text = "Your saved run will be deleted. Unlocks and records are kept."
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	PixelUI.style_body_label(body, PROMPT_BODY_FONT)
	box.add_child(body)

	var confirm := Button.new()
	confirm.text = "ABANDON RUN"
	confirm.custom_minimum_size = PROMPT_BUTTON_SIZE
	confirm.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	PixelUI.style_primary_button(confirm, PROMPT_BUTTON_FONT, true)
	confirm.pressed.connect(_on_abandon_confirmed.bind(scrim, panel))
	box.add_child(confirm)

	var keep := Button.new()
	keep.text = "KEEP RUN"
	keep.custom_minimum_size = Vector2(PROMPT_BUTTON_SIZE.x, 92)
	keep.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	PixelUI.style_button(keep, PixelUI.BG_PANEL_ALT, PixelUI.LINE_DIM, PROMPT_SKIP_FONT)
	keep.add_theme_color_override("font_color", PixelUI.TEXT_MUTED)
	keep.pressed.connect(_dismiss_abandon_confirm.bind(scrim, panel))
	box.add_child(keep)

	scrim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			_dismiss_abandon_confirm(scrim, panel)
	)


func _dismiss_abandon_confirm(scrim: Control, panel: Control) -> void:
	AudioManager.play_select()
	for node in [scrim, panel]:
		if is_instance_valid(node):
			node.queue_free()


func _on_abandon_confirmed(scrim: Control, panel: Control) -> void:
	AudioManager.play_select()
	# reset_run() is the one choke point: it clears the live run AND destroys
	# run.json (GameState.reset_run). The profile is untouched by design.
	GameState.reset_run()
	for node in [scrim, panel]:
		if is_instance_valid(node):
			node.queue_free()
	# Rebuild the menu so CONTINUE / ABANDON RUN go away.
	SceneManager.go_to_main_menu()


# ── Notices ───────────────────────────────────────────────────────────────────
# Quiet one-liners under the buttons. Neither blocks anything; both are absent
# in the ordinary case, so the menu a healthy desktop player sees is unchanged.

func _add_notices(col: VBoxContainer) -> void:
	# A run save from an older build, already discarded by peek_run_save().
	var discarded: String = SaveManager.take_run_save_notice()
	if discarded != "":
		col.add_child(_make_notice(discarded, PixelUI.DT_AMBER_TEXT))
	# Web private/incognito mode, or a browser that refused the IndexedDB mount:
	# user:// is a RAM disk for this session and nothing will outlive the tab.
	# Worth saying plainly — the alternative is a player losing a run and
	# concluding the save system is broken.
	if OS.has_feature("web") and not OS.is_userfs_persistent():
		col.add_child(_make_notice(
			"This browser mode can't save progress. Your run won't be kept.",
			PixelUI.TEXT_MUTED))


func _make_notice(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.custom_minimum_size = Vector2(PROMPT_WIDTH, 0)
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	PixelUI.style_label(label, NOTICE_FONT, color, 0)
	return label
