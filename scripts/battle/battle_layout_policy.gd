class_name BattleLayoutPolicy
extends RefCounted

## Presentation only. Enable AUTO for players by changing this one flag.
const LANDSCAPE_BATTLE_ENABLED := false
const MIN_DESKTOP_WIDTH := 960.0
const MIN_ASPECT := 1.3
enum Override { AUTO, FORCE_PORTRAIT, FORCE_LANDSCAPE }
static var dev_override: Override = Override.AUTO


static func resolve(enabled: bool, debug_build: bool, override_mode: int, tutorial: bool, desktop: bool, viewport_size: Vector2) -> bool:
	if debug_build and override_mode == Override.FORCE_LANDSCAPE:
		return true
	if tutorial or (debug_build and override_mode == Override.FORCE_PORTRAIT):
		return false
	return enabled and desktop and viewport_size.x >= MIN_DESKTOP_WIDTH and viewport_size.y > 0.0 and viewport_size.x / viewport_size.y >= MIN_ASPECT


static func select_for_battle(scene: Control) -> bool:
	var tutorial: bool = bool(scene.get_node("/root/GameState").tutorial_mode)
	return resolve(LANDSCAPE_BATTLE_ENABLED, OS.is_debug_build(), dev_override, tutorial, is_desktop(), window_size(scene))


static func is_desktop() -> bool:
	if OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios"):
		return false
	if OS.has_feature("web"):
		if PixelUI.is_mobile_web():
			return false
		# Touch-primary devices include tablets presenting a desktop user agent.
		# Touch-capable laptops with a fine pointer remain desktop.
		if bool(JavaScriptBridge.eval("matchMedia('(pointer: coarse)').matches && matchMedia('(hover: none)').matches", true)):
			return false
		return OS.has_feature("web_windows") or OS.has_feature("web_macos") or OS.has_feature("web_linuxbsd")
	return OS.has_feature("pc")


static func window_size(scene: Control) -> Vector2:
	if OS.has_feature("web"):
		return Vector2(float(JavaScriptBridge.eval("window.innerWidth", true)), float(JavaScriptBridge.eval("window.innerHeight", true)))
	return Vector2(scene.get_window().size) / maxf(DisplayServer.screen_get_scale(), 1.0)
