class_name RoomU
extends RefCounted
# Room utilities (js/dungeon.js): doors, tiles, coordinates, reachability.

const DIRS := {
	"n": {"dx": 0, "dy": -1, "opp": "s", "tiles": [[13, 0], [14, 0], [15, 0]]},
	"s": {"dx": 0, "dy": 1, "opp": "n", "tiles": [[13, 14], [14, 14], [15, 14]]},
	"w": {"dx": -1, "dy": 0, "opp": "e", "tiles": [[0, 6], [0, 7], [0, 8]]},
	"e": {"dx": 1, "dy": 0, "opp": "w", "tiles": [[28, 6], [28, 7], [28, 8]]},
}

# Godot-only: a room covers one cell of the depth map or several (RoomShapes); its
# grid is cw x ch cells of RW x RH tiles, gx, gy its top-left cell
static func cells(r: Dictionary) -> Array:
	return r.get("cells", [Vector2i.ZERO])

static func rw(r: Dictionary) -> int:
	return int(r.get("cw", 1)) * Consts.RW

static func rh(r: Dictionary) -> int:
	return int(r.get("ch", 1)) * Consts.RH

# the middle tile of the room's first cell (14, 7 in a room of one cell)
static func mid_tile(r: Dictionary) -> Vector2i:
	var c: Vector2i = cells(r)[0]
	return Vector2i(c.x * Consts.RW + 14, c.y * Consts.RH + 7)

static func mid(r: Dictionary) -> Vector2:
	var t := mid_tile(r)
	return tile_center(t.x, t.y)

# what the flat world shows: the room and the margins around it (480x270 for one cell)
static func view_size(r: Dictionary) -> Vector2:
	return Vector2(Consts.RX * 2 + rw(r) * Consts.TS, Consts.H - Consts.RH * Consts.TS + rh(r) * Consts.TS)

# Godot-only: of a room of several cells, its first cell's (gx, gy may be another room's)
static func key(r: Dictionary) -> String:
	var c: Vector2i = cells(r)[0]
	return "%d,%d" % [r.gx + c.x, r.gy + c.y]

static func room_at(fl: Dictionary, gx: int, gy: int) -> Variant:
	return fl.map.get("%d,%d" % [gx, gy])

# Godot-only: a door is named by its side; in a room of several cells, or with two
# doors on one side of a cell, also by its cell (column, row) and slot a or b:
# "n", "e10", "s01b"
static func door_key(side: String, ci: int, cj: int, slot := "") -> String:
	if ci == 0 and cj == 0 and slot == "":
		return side
	return "%s%d%d%s" % [side, ci, cj, slot]

static func door_cell(d: String) -> Vector2i:
	return Vector2i(int(d[1]), int(d[2])) if d.length() >= 3 else Vector2i.ZERO

static func door_slot(d: String) -> String:
	return d.substr(3)

static func side(d: String) -> Dictionary:
	return DIRS[d[0]]

# where a door lies past the cell's own: a pair of doors sits off the middle
static func _door_shift(d: String) -> Vector2i:
	var c := door_cell(d)
	var k: int = {"": 0, "a": -1, "b": 1}[door_slot(d)]
	var horiz: bool = d[0] == "n" or d[0] == "s"
	return Vector2i(c.x * Consts.RW + (k * 7 if horiz else 0), c.y * Consts.RH + (0 if horiz else k * 3))

static func door_tiles(d: String) -> Array:
	var o := _door_shift(d)
	return side(d).tiles.map(func(t): return [t[0] + o.x, t[1] + o.y])

# the doors in a steady order: by side (n, s, w, e) then by name
static func door_keys(r: Dictionary) -> Array:
	var ks: Array = r.doors.keys()
	ks.sort_custom(func(a: String, b: String) -> bool:
		var i := "nswe".find(a[0])
		var j := "nswe".find(b[0])
		return i < j or (i == j and a < b))
	return ks

# Godot-only: the name, in the room beyond door d, of the door back
static func back_door(r: Dictionary, d: String) -> String:
	var n: Dictionary = r.doors[d]
	var c := door_cell(d) + Vector2i(r.gx + side(d).dx - n.gx, r.gy + side(d).dy - n.gy)
	return door_key(side(d).opp, c.x, c.y, door_slot(d))

# player entry point when arriving through a door
static func door_entry(dir: String) -> Vector2:
	var o := Vector2(_door_shift(dir)) * Consts.TS
	match dir[0]:
		"n": return o + Vector2(Consts.RX + 14.5 * Consts.TS, Consts.RY + 1.9 * Consts.TS)
		"s": return o + Vector2(Consts.RX + 14.5 * Consts.TS, Consts.RY + 13.1 * Consts.TS)
		"w": return o + Vector2(Consts.RX + 1.9 * Consts.TS, Consts.RY + 7.5 * Consts.TS)
	return o + Vector2(Consts.RX + 27.1 * Consts.TS, Consts.RY + 7.5 * Consts.TS)

# Godot-only: where room n lies from room r, right past its walls
static func room_offset(r: Dictionary, n: Dictionary) -> Vector2:
	return Vector2((n.gx - r.gx) * Consts.RW * Consts.TS, (n.gy - r.gy) * Consts.RH * Consts.TS)

static func door_center(dir: String) -> Vector2:
	var t: Array = door_tiles(dir)[1]
	return Vector2(Consts.RX + (t[0] + 0.5) * Consts.TS, Consts.RY + (t[1] + 0.5) * Consts.TS)

static func world_to_tile(x: float, y: float) -> Vector2i:
	return Vector2i(int(floor((x - Consts.RX) / Consts.TS)), int(floor((y - Consts.RY) / Consts.TS)))

static func tile_center(tx: int, ty: int) -> Vector2:
	return Vector2(Consts.RX + (tx + 0.5) * Consts.TS, Consts.RY + (ty + 0.5) * Consts.TS)

static func in_grid(room: Dictionary, tx: int, ty: int) -> bool:
	return tx >= 0 and ty >= 0 and tx < rw(room) and ty < rh(room)

# doorways: Godot-only, for the player, a doorway goes on one tile past the edge,
# into the room next door (Flow.check_doors changes room there)
static func tile_at(room: Dictionary, tx: int, ty: int, doorways := false) -> int:
	var t: int = room.grid[ty][tx] if in_grid(room, tx, ty) else Consts.T.WALL
	if t != Consts.T.WALL or not doorways:
		return t
	return Consts.T.DOOR if door_past(room, tx, ty) != "" else Consts.T.WALL

# Godot-only: the door whose doorway is tile tx, ty, one tile past it, or ""
static func door_past(room: Dictionary, tx: int, ty: int) -> String:
	for s in DIRS:
		var cx: int = tx - DIRS[s].dx
		var cy: int = ty - DIRS[s].dy
		if in_grid(room, cx, cy) and room.grid[cy][cx] == Consts.T.DOOR:
			var d: String = room.doorDir.get(cy * rw(room) + cx, "")
			if d != "" and d[0] == s:
				return d
	return ""

# the door a DOOR tile belongs to, the doorway past the edge included
static func door_dir_at(room: Dictionary, tx: int, ty: int) -> String:
	if in_grid(room, tx, ty) and room.doorDir.has(ty * rw(room) + tx):
		return room.doorDir[ty * rw(room) + tx]
	return door_past(room, tx, ty)

# Godot-only: the room next door over whose cell a point lies: null inside the
# room's own cells, {} where no door leads
static func beyond(room: Dictionary, x: float, y: float) -> Variant:
	var c := Vector2i(floori((x - Consts.RX) / (Consts.RW * Consts.TS)), floori((y - Consts.RY) / (Consts.RH * Consts.TS)))
	if cells(room).has(c):
		return null
	for d in room.doors:
		var n: Dictionary = room.doors[d]
		if cells(n).has(c + Vector2i(room.gx - n.gx, room.gy - n.gy)):
			return n
	return {}

# Godot-only: whether a circle at x, y keeps clear of door dir and the doorway past it
static func clear_of_door(dir: String, x: float, y: float, r: float) -> bool:
	var tt := door_tiles(dir)
	var t0: Array = tt[0]
	var t2: Array = tt[2]
	var a := Rect2(Consts.RX + t0[0] * Consts.TS, Consts.RY + t0[1] * Consts.TS, (t2[0] - t0[0] + 1) * Consts.TS, (t2[1] - t0[1] + 1) * Consts.TS)
	a = a.merge(Rect2(a.position + Vector2(side(dir).dx, side(dir).dy) * Consts.TS, a.size))
	return not a.intersects(Rect2(x - r, y - r, r * 2, r * 2))

static func door_visible(room: Dictionary, dir: String) -> bool:
	var n: Variant = room.doors.get(dir)
	if n == null:
		return false
	if n.type == "secret" and not n.found:
		return false
	if room.type == "secret" and not room.found:
		return false
	return true

static func door_locked(room: Dictionary, dir: String) -> bool:
	var n: Variant = room.doors.get(dir)
	if n == null:
		return false
	return n.type == "treasure" and n.get("locked", false)

static func door_open(room: Dictionary, dir: String) -> bool:
	if not door_visible(room, dir):
		return false
	if door_locked(room, dir):
		return false
	# Godot-only: the way in stays open while the player still stands in it (Flow.check_doors)
	if room.get("entering", "") == dir:
		return true
	return room.cleared and not room.get("combat", false)

static func is_solid_tile(room: Dictionary, tx: int, ty: int, fly: bool, doorways := false) -> bool:
	var t := tile_at(room, tx, ty, doorways)
	if t == Consts.T.FLOOR or t == Consts.T.SPIKE:
		return false
	if t == Consts.T.WALL:
		return true
	if t == Consts.T.DOOR:
		return not door_open(room, door_dir_at(room, tx, ty))
	if fly:
		return false
	return true

static func blocks_shot(room: Dictionary, tx: int, ty: int, doorways := false) -> bool:
	var t := tile_at(room, tx, ty, doorways)
	# Godot-only: shots fly over a pit
	return not (t == Consts.T.FLOOR or t == Consts.T.SPIKE or t == Consts.T.PIT or (t == Consts.T.DOOR and door_open(room, door_dir_at(room, tx, ty))))

# Godot-only: a wall with no floor around it, out of a shaped room: not drawn
static func deep_wall(room: Dictionary, tx: int, ty: int) -> bool:
	for y in range(ty - 1, ty + 2):
		for x in range(tx - 1, tx + 2):
			if tile_at(room, x, y) != Consts.T.WALL:
				return false
	return true

static func walkable(t: int) -> bool:
	return t == Consts.T.FLOOR or t == Consts.T.SPIKE or t == Consts.T.DOOR

# ordered set (Dictionary) of cells reachable from (sx, sy)
static func flood_from(room: Dictionary, sx: int, sy: int) -> Dictionary:
	var w := rw(room)
	var seen := {}
	var q: Array = [[sx, sy]]
	seen[sy * w + sx] = true
	while not q.is_empty():
		var c: Array = q.pop_back()
		for dd in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
			var nx: int = c[0] + dd[0]
			var ny: int = c[1] + dd[1]
			if nx < 1 or ny < 1 or nx >= w - 1 or ny >= rh(room) - 1:
				continue
			var k := ny * w + nx
			if seen.has(k):
				continue
			if not walkable(room.grid[ny][nx]):
				continue
			seen[k] = true
			q.append([nx, ny])
	return seen

# the tile in front of a door, inside the room
static func entry_tile(d: String) -> Array:
	var t: Array = door_tiles(d)[1]
	return [t[0] - side(d).dx, t[1] - side(d).dy]

static func check_reachable(room: Dictionary) -> bool:
	var entries: Array = room.doors.keys().map(func(d): return entry_tile(d))
	var m := mid_tile(room)
	var st: Array = entries[0] if not entries.is_empty() else [m.x, m.y]
	var seen := flood_from(room, st[0], st[1])
	for e in entries:
		if not seen.has(e[1] * rw(room) + e[0]):
			room.reach = null
			return false
	room.reach = seen
	return true

static func reach_tiles(room: Dictionary) -> Array:
	var w := rw(room)
	if room.get("reach") == null:
		var m := mid_tile(room)
		room.reach = flood_from(room, m.x, m.y)
	return room.reach.keys().map(func(k): return Vector2i(k % w, k / w))

static func spikes_up(room: Dictionary) -> bool:
	return fmod(room.spikeT, 3.0) > 2.0

static func spikes_warn(room: Dictionary) -> bool:
	var k := fmod(room.spikeT, 3.0)
	return k > 1.6 and k <= 2.0
