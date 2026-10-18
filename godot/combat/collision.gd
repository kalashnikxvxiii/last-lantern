class_name Coll
extends RefCounted
# Collisions with the room grid (js/entities.js:192-223 and 373-383).

# doorways: the player's, see RoomU.tile_at
static func collides(room: Dictionary, x: float, y: float, r: float, fly: bool, doorways := false) -> bool:
	var x0 := int(floor((x - r - Consts.RX) / Consts.TS))
	var x1 := int(floor((x + r - 0.01 - Consts.RX) / Consts.TS))
	var y0 := int(floor((y - r - Consts.RY) / Consts.TS))
	var y1 := int(floor((y + r - 0.01 - Consts.RY) / Consts.TS))
	for ty in range(y0, y1 + 1):
		for tx in range(x0, x1 + 1):
			if RoomU.is_solid_tile(room, tx, ty, fly, doorways):
				return true
	return false

static func move_axis(a, d: float, axis: int, fly: bool) -> bool:
	if d == 0 or is_nan(d):
		return false
	var room := Run.room
	var steps := int(ceil(absf(d)))
	var inc := d / steps
	for i in steps:
		if axis == 0:
			a.x += inc
		else:
			a.y += inc
		if collides(room, a.x, a.y, a.r, fly, a is Player):
			if axis == 0:
				a.x -= inc
			else:
				a.y -= inc
			return true
	return false

static func move_actor(a, dx: float, dy: float, fly: bool) -> bool:
	var hx := move_axis(a, dx, 0, fly)
	var hy := move_axis(a, dy, 1, fly)
	return hx or hy

static func line_clear(x0: float, y0: float, x1: float, y1: float) -> bool:
	var room := Run.room
	var n := int(ceil(U.dist(x0, y0, x1, y1) / 6))
	for i in range(1, n):
		var t := RoomU.world_to_tile(lerpf(x0, x1, float(i) / n), lerpf(y0, y1, float(i) / n))
		if RoomU.blocks_shot(room, t.x, t.y):
			return false
	return true

# corner sliding: if the step is blocked, try moving sideways
static func nudge(p, axis: int, d: float) -> void:
	var room := Run.room
	var fx := signf(d) if axis == 0 else 0.0
	var fy := signf(d) if axis == 1 else 0.0
	for k in range(1, 7):
		for s in [1, -1]:
			var ox := float(s * k) if axis == 1 else 0.0
			var oy := float(s * k) if axis == 0 else 0.0
			if not collides(room, p.x + ox, p.y + oy, p.r, false, p is Player) and not collides(room, p.x + ox + fx, p.y + oy + fy, p.r, false, p is Player):
				move_axis(p, signf(ox) * 0.8, 0, false)
				move_axis(p, signf(oy) * 0.8, 1, false)
				return
