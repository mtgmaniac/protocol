# Every screen that displays a portrait, enemy, boss, item or relic, with the
# frame size that screen gives its art (design px, 1080-wide space). DEV ONLY
# (dev/ is excluded from every export preset).
#
# Sizes are read from each screen's OWN constants wherever the screen has one,
# so this list cannot drift from the game; the few computed ones repeat the
# screen's arithmetic and name the line they mirror. Rendering goes through
# the SAME helpers the screens call (PixelUI.cover_fit_portrait,
# make_integer_icon, make_item_art), so a preview here is what the screen
# shows, minus the surrounding chrome.
extends RefCounted

const HOME := preload("res://scripts/ui/home_screen.gd")
const EVOLUTION := preload("res://scripts/ui/evolution_screen.gd")
const REWARD := preload("res://scripts/ui/reward_screen.gd")
const UNLOCK := preload("res://scripts/ui/unlock_screen.gd")

const PORTRAIT := "portrait"
const ITEM := "item"


# One row per site: id, label, kind, size, fit mode (items), sections shown,
# item_types filter (items: consumable / gear; empty = any), chrome colours.
static func all_sites() -> Array[Dictionary]:
	var region: Vector2 = PixelUI.HERO_PORTRAIT_REGION
	var squad_w: float = float(HOME.PORTRAIT_CELL - 2 * HOME.PANEL_BORDER)  # home_screen._build_unit_tile
	var evo_w: float = float(EVOLUTION.PORTRAIT_W - 2 * EVOLUTION.PORTRAIT_BORDER)  # evolution_screen:378
	var unlock_w := 144.0  # unlock_screen._make_hero_row token_w
	var sites: Array[Dictionary] = [
		_site("battle_card", "Battle card", PORTRAIT, region, "", ["heroes", "enemies", "bosses"]),
		_site("squad_tile", "Squad select", PORTRAIT, Vector2(squad_w, roundf(squad_w * region.y / region.x)), "", ["heroes"]),
		_site("encounter", "Encounter panel", PORTRAIT,
			Vector2(HOME.ENC_THUMB_W - 2 * HOME.PANEL_BORDER, HOME.ENC_THUMB_H - 2 * HOME.PANEL_BORDER), "", ["bosses"]),
		_site("evolution", "Evolution", PORTRAIT, Vector2(evo_w, roundf(evo_w * region.y / region.x)), "", ["heroes"]),
		_site("unlock_unit", "Unlock / run end", PORTRAIT, Vector2(unlock_w, roundf(unlock_w * region.y / region.x)), "", ["heroes"]),
		_site("help_row", "Help units", PORTRAIT, Vector2(HelpMenu.ROW_PORTRAIT_BOX, HelpMenu.ROW_PORTRAIT_BOX), "", ["heroes", "enemies", "bosses"]),
		_site("reward_row", "Reward row", ITEM, Vector2.ONE * REWARD.ROW_ICON_BOX, PixelUI.ITEM_FIT_INTEGER, ["items"]),
		_site("reward_relic", "Relic reward", ITEM, Vector2.ONE * REWARD.RELIC_ICON_BOX, PixelUI.ITEM_FIT_INTEGER, ["relics"]),
		_site("item_card", "Battle item card", ITEM, Vector2.ONE * (ItemCard.ICON_AREA_SIZE - 8.0), PixelUI.ITEM_FIT_INTEGER, ["items"], ["consumable"]),
		_site("loadout", "Inventory (Item)", ITEM, Vector2.ONE * LoadoutMenu.ICON_TEXTURE, PixelUI.ITEM_FIT_CONTAIN, ["items", "relics"], ["consumable", "relic"]),
		_site("unlock_grid", "Unlock grid", ITEM, Vector2.ONE * UNLOCK.GRID_ICON_BOX, PixelUI.ITEM_FIT_INTEGER, ["items", "relics"]),
		_site("unlock_boss", "Boss relic unlock", ITEM, Vector2.ONE * UNLOCK.BOSS_RELIC_ICON_BOX, PixelUI.ITEM_FIT_INTEGER, ["relics"]),
		_site("directive", "Starting Directive", ITEM, Vector2.ONE * HOME.DIRECTIVE_ICON_BOX, PixelUI.ITEM_FIT_CONTAIN, ["relics"]),
		_site("inspect_header", "Inspect popup", ITEM, Vector2.ONE * InspectPopup.HEADER_ICON_SIZE, PixelUI.ITEM_FIT_COVER, ["items", "relics"]),
		_site("inspect_gear", "Inspect gear row", ITEM, Vector2.ONE * InspectPopup.GEAR_ICON_SIZE, PixelUI.ITEM_FIT_CONTAIN, ["items"], ["gear"]),
	]
	return sites


static func _site(id: String, label: String, kind: String, size: Vector2, mode: String,
		sections: Array, item_types: Array = []) -> Dictionary:
	return {"id": id, "label": label, "kind": kind, "size": size, "mode": mode,
		"sections": sections, "item_types": item_types}


static func sites_for(section: String, item_type: String = "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for site in all_sites():
		if not (site["sections"] as Array).has(section):
			continue
		var types: Array = site["item_types"]
		if item_type != "" and not types.is_empty() and not types.has(item_type):
			continue
		out.append(site)
	return out


# The site's art, exactly as the screen builds it: a clipping frame of the
# site size holding the art, placed by the shared helper. `size` is design px.
static func build(site: Dictionary, tex: Texture2D) -> Control:
	var size: Vector2 = site["size"]
	if site["kind"] == PORTRAIT:
		var crop := Control.new()
		crop.custom_minimum_size = size
		crop.size = size
		crop.clip_contents = true
		crop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rect := TextureRect.new()
		rect.texture = tex
		rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_SCALE
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		crop.add_child(rect)
		var fit := func() -> void: PixelUI.cover_fit_portrait(rect, crop.size)
		crop.resized.connect(fit)
		crop.tree_entered.connect(fit)  # size is preset, so resized may never fire
		return crop
	var holder := Control.new()
	holder.custom_minimum_size = size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.clip_contents = true
	var art: Control
	if site["mode"] == PixelUI.ITEM_FIT_INTEGER:
		art = PixelUI.make_integer_icon(tex, size.x, PixelUI.DT_AMBER, site["id"] == "unlock_grid")
	else:
		art = PixelUI.make_item_art(tex, size, site["mode"])
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(art)
	return holder
