extends RefCounted
## Battle depth prototype v2: the ONE draw-time projection of the dice tray.
##
## The dice simulate in the flat, top-down tray rectangle. Nothing here is read by
## physics, tray bounds, result slots or combat: it only says where a point of
## that rectangle is DRAWN. `flat` is a tray-local point of the rectangle (what
## the tray camera unprojects); `depth` is its y as 0 (back wall) .. 1 (front).
## Preloaded by path (no class_name) so `-s` test scripts never resolve it early.

## Debug A/B switches (battle scene, F6 / F7 in debug builds).
static var backdrop_on := true
static var decal_on := true


static func depth_at(flat_y: float, tray: Vector2) -> float:
	return clampf(flat_y / maxf(tray.y, 1.0), 0.0, 1.0)


## How large a die is drawn at this depth (1.0 = its physical size).
static func die_scale(depth: float) -> float:
	return lerpf(PixelUI.BATTLE_DEPTH_BACK, PixelUI.BATTLE_DEPTH_FRONT, depth)


## Where a die resting at `flat` is drawn: pulled toward the centre line at the
## back and nudged down the screen, both linear in depth, so a straight roll
## stays straight.
static func die_center(flat: Vector2, tray: Vector2) -> Vector2:
	var depth: float = depth_at(flat.y, tray)
	var mid: float = tray.x * 0.5
	var push: float = tray.y * PixelUI.BATTLE_DEPTH_PUSH
	return Vector2(
		mid + (flat.x - mid) * lerpf(PixelUI.BATTLE_DEPTH_TAPER, 1.0, depth),
		push + flat.y * (1.0 - PixelUI.BATTLE_DEPTH_PUSH))


## Where the back wall meets the floor, in tray-local y.
static func wall_base(tray: Vector2) -> float:
	return tray.y * PixelUI.BATTLE_DEPTH_WALL


## The floor plane, for everything painted ON it (texture, decal). A true
## one-point perspective of the same trapezoid: rows crowd toward the back wall.
static func floor_point(flat: Vector2, tray: Vector2) -> Vector2:
	var depth: float = depth_at(flat.y, tray)
	var back: float = PixelUI.BATTLE_DEPTH_TAPER
	var width: float = 1.0 / lerpf(1.0 / back, 1.0, depth)
	var base: float = wall_base(tray)
	var mid: float = tray.x * 0.5
	return Vector2(
		mid + (flat.x - mid) * width,
		base + (tray.y - base) * (width - back) / (1.0 - back))
