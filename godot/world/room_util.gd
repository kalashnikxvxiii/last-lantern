class_name RoomU
extends RefCounted
# Room utilities (js/dungeon.js): doors, tiles, coordinates, reachability.

const DIRS := {
	"n": {"dx": 0, "dy": -1, "opp": "s", "tiles": [[13, 0], [14, 0], [15, 0]]},
	"s": {"dx": 0, "dy": 1, "opp": "n", "tiles": [[13, 14], [14, 14], [15, 14]]},
	"w": {"dx": -1, "dy": 0, "opp": "e", "tiles": [[0, 6], [0, 7], [0, 8]]},
	"e": {"dx": 1, "dy": 0, "opp": "w", "tiles": [[28, 6], [28, 7], [28, 8]]},
}

static func key(r: Dictionary) -> String:
	return "%d,%d" % [r.gx, r.gy]

static func room_at(fl: Dictionary, gx: int, gy: int) -> Variant:
	return fl.map.get("%d,%d" % [gx, gy])

# player entry point when arriving through a door
static func door_entry(dir: String) -> Vector2:
	match dir:
		"n": return Vector2(Consts.RX + 14.5 * Consts.TS, Consts.RY + 1.9 * Consts.TS)
		"s": return Vector2(Consts.RX + 14.5 * Consts.TS, Consts.RY + 13.1 * Consts.TS)
		"w": return Vector2(Consts.RX + 1.9 * Consts.TS, Consts.RY + 7.5 * Consts.TS)
	return Vector2(Consts.RX + 27.1 * Consts.TS, Consts.RY + 7.5 * Consts.TS)

static func door_center(dir: String) -> Vector2:
	var t: Array = DIRS[dir].tiles[1]
	return Vector2(Consts.RX + (t[0] + 0.5) * Consts.TS, Consts.RY + (t[1] + 0.5) * Consts.TS)

static func world_to_tile(x: float, y: float) -> Vector2i:
	return Vector2i(int(floor((x - Consts.RX) / Consts.TS)), int(floor((y - Consts.RY) / Consts.TS)))

static func tile_center(tx: int, ty: int) -> Vector2:
	return Vector2(Consts.RX + (tx + 0.5) * Consts.TS, Consts.RY + (ty + 0.5) * Consts.TS)

static func tile_at(room: Dictionary, tx: int, ty: int) -> int:
	if tx < 0 or ty < 0 or tx >= Consts.RW or ty >= Consts.RH:
		return Consts.T.WALL
	return room.grid[ty][tx]

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
	return room.cleared and not room.get("combat", false)

static func is_solid_tile(room: Dictionary, tx: int, ty: int, fly: bool) -> bool:
	var t := tile_at(room, tx, ty)
	if t == Consts.T.FLOOR or t == Consts.T.SPIKE:
		return false
	if t == Consts.T.WALL:
		return true
	if t == Consts.T.DOOR:
		return not door_open(room, room.doorDir[ty * Consts.RW + tx])
	if fly:
		return false
	return true

static func blocks_shot(room: Dictionary, tx: int, ty: int) -> bool:
	var t := tile_at(room, tx, ty)
	return not (t == Consts.T.FLOOR or t == Consts.T.SPIKE or (t == Consts.T.DOOR and door_open(room, room.doorDir[ty * Consts.RW + tx])))

static func walkable(t: int) -> bool:
	return t == Consts.T.FLOOR or t == Consts.T.SPIKE or t == Consts.T.DOOR

# ordered set (Dictionary) of cells reachable from (sx, sy)
static func flood_from(room: Dictionary, sx: int, sy: int) -> Dictionary:
	var rw := Consts.RW
	var seen := {}
	var q: Array = [[sx, sy]]
	seen[sy * rw + sx] = true
	while not q.is_empty():
		var c: Array = q.pop_back()
		for dd in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
			var nx: int = c[0] + dd[0]
			var ny: int = c[1] + dd[1]
			if nx < 1 or ny < 1 or nx >= rw - 1 or ny >= Consts.RH - 1:
				continue
			var k := ny * rw + nx
			if seen.has(k):
				continue
			if not walkable(room.grid[ny][nx]):
				continue
			seen[k] = true
			q.append([nx, ny])
	return seen

const ENTRY := {"n": [14, 1], "s": [14, 13], "w": [1, 7], "e": [27, 7]}

static func check_reachable(room: Dictionary) -> bool:
	var entries: Array = room.doors.keys().map(func(d): return ENTRY[d])
	var st: Array = entries[0] if not entries.is_empty() else [14, 7]
	var seen := flood_from(room, st[0], st[1])
	for e in entries:
		if not seen.has(e[1] * Consts.RW + e[0]):
			room.reach = null
			return false
	room.reach = seen
	return true

static func reach_tiles(room: Dictionary) -> Array:
	if room.get("reach") == null:
		room.reach = flood_from(room, 14, 7)
	return room.reach.keys().map(func(k): return Vector2i(k % Consts.RW, k / Consts.RW))

static func spikes_up(room: Dictionary) -> bool:
	return fmod(room.spikeT, 3.0) > 2.0

static func spikes_warn(room: Dictionary) -> bool:
	var k := fmod(room.spikeT, 3.0)
	return k > 1.6 and k <= 2.0
