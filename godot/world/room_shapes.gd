class_name RoomShapes
extends RefCounted
# Godot-only: rooms of other sizes and shapes. After genFloor some normal rooms
# next to each other become one room of several cells (a hall, an L, a T...),
# and the normal rooms get an outline (cut corners, a cave, a cross, a small
# chamber) and something inside (pits, chasms with a bridge, pillars). The doors
# are made again from the cells: a long wall has a door for each room beyond it,
# and two rooms may share a pair of doors on one side of a cell.
# Its own random sequence, from the start room's seed: the floor's draws stay the JS ones.

# the forms of the rooms of several cells (cell x, y): the depth map is a tree,
# so none holds a 2x2 block
const FORMS := [
	[[0, 0], [1, 0]], [[0, 0], [0, 1]],
	[[0, 0], [1, 0], [2, 0]], [[0, 0], [0, 1], [0, 2]],
	[[0, 0], [1, 0], [0, 1]], [[0, 0], [1, 0], [1, 1]], [[0, 0], [0, 1], [1, 1]], [[1, 0], [0, 1], [1, 1]],
	[[0, 0], [1, 0], [2, 0], [1, 1]], [[1, 0], [0, 1], [1, 1], [2, 1]], [[0, 0], [0, 1], [0, 2], [1, 1]], [[1, 0], [0, 1], [1, 1], [1, 2]],
	[[0, 0], [1, 0], [1, 1], [2, 1]], [[1, 0], [2, 0], [0, 1], [1, 1]],
]
const OUTLINES := [["plain", 4], ["chamfer", 3], ["cave", 2], ["cross", 2], ["small", 2]]
const INSIDES := [["none", 5], ["pits", 2], ["chasm", 2], ["pillars", 2]]
const MERGE_CHANCE := 0.6
const TWIN_CHANCE := 0.3
const SALT := 0x2545F491

# --- the floor: merged rooms, shapes, doors ---

static func apply(fl: Dictionary) -> void:
	var rng := RNG.new(int(fl.start.seed) ^ SALT)
	var normal: Array = rng.shuffle(fl.rooms.filter(func(r): return r.type == "normal"))
	var left := 1 + normal.size() / 4
	for r in normal:
		if left <= 0:
			break
		if r.has("cells") or not rng.chance(MERGE_CHANCE):
			continue
		for f in rng.shuffle(FORMS.duplicate()):
			var group := _fit(fl, r, f)
			if not group.is_empty():
				_merge(fl, group, f)
				left -= 1
				break
	for r in fl.rooms:
		if r.type == "normal":
			_pick_shape(r, rng)
	connect_doors(fl, rng)

# the normal rooms of one cell that form f with r among them, after f's top-left
# cell; [] if none
static func _fit(fl: Dictionary, r: Dictionary, f: Array) -> Array:
	for a in f:
		var group: Array = [Vector2i(r.gx - a[0], r.gy - a[1])]
		for c in f:
			var n: Variant = RoomU.room_at(fl, group[0].x + c[0], group[0].y + c[1])
			if n == null or n.type != "normal" or n.has("cells"):
				break
			group.append(n)
		if group.size() == f.size() + 1:
			return group
	return []

# the nearest to the start keeps its seed and its place in the list
static func _merge(fl: Dictionary, group: Array, f: Array) -> void:
	var o: Vector2i = group[0]
	var rooms: Array = group.slice(1)
	var host: Dictionary = rooms[0]
	for r in rooms:
		if r.dist < host.dist:
			host = r
	host.cells = f.map(func(c): return Vector2i(c[0], c[1]))
	host.cw = f.reduce(func(m, c): return maxi(m, c[0] + 1), 1)
	host.ch = f.reduce(func(m, c): return maxi(m, c[1] + 1), 1)
	host.gx = o.x
	host.gy = o.y
	host.budget = 1.0 + (f.size() - 1) * 0.7
	fl.rooms = fl.rooms.filter(func(r): return is_same(r, host) or not rooms.any(func(x): return is_same(x, r)))
	for c in f:
		fl.map[FloorGen._key(o.x + c[0], o.y + c[1])] = host

static func _pick_shape(r: Dictionary, rng: RNG) -> void:
	var multi := RoomU.cells(r).size() > 1
	var outs: Array = OUTLINES.filter(func(o): return not multi or o[0] != "small")
	var out: String = rng.weighted(outs, func(o): return o[1])[0]
	var ins: String = "none" if out == "small" else rng.weighted(INSIDES, func(o): return o[1])[0]
	if multi or out != "plain" or ins != "none":   # else the room is laid out as in the JS
		r.shape = [out, ins]
	if out == "small":
		r.budget = 0.7

# every side of a cell with another room beyond it gets a door, or a pair
static func connect_doors(fl: Dictionary, rng: RNG) -> void:
	var twin := {}
	for r in fl.rooms:
		r.doors = {}
	for r in fl.rooms:
		for c in RoomU.cells(r):
			for s in RoomU.DIRS:
				var at := Vector2i(r.gx + c.x, r.gy + c.y)
				var o := at + Vector2i(RoomU.DIRS[s].dx, RoomU.DIRS[s].dy)
				var n: Variant = RoomU.room_at(fl, o.x, o.y)
				if n == null or is_same(n, r):
					continue
				var e := "%s|%s" % ([at, o] if at < o else [o, at])
				if not twin.has(e):
					twin[e] = _can_twin(r) and _can_twin(n) and rng.chance(TWIN_CHANCE)
				if twin[e]:
					r.doors[RoomU.door_key(s, c.x, c.y, "a")] = n
					r.doors[RoomU.door_key(s, c.x, c.y, "b")] = n
				else:
					r.doors[RoomU.door_key(s, c.x, c.y)] = n

static func _can_twin(r: Dictionary) -> bool:
	return r.type in ["normal", "start", "elite"]

# --- the grid of a shaped room (RoomBuilder.lay_out) ---

const OUT := 0
const IN := 1
const PIT := 2

static func lay_out(room: Dictionary, rng: RNG, biome: BiomeDef) -> void:
	var w := RoomU.rw(room)
	var h := RoomU.rh(room)
	# what does not keep every door in reach is dropped: the inside, then the outline
	var m := PackedByteArray()
	for shape in [room.shape, [room.shape[0], "none"], ["plain", "none"]]:
		m = _mask(room, shape, rng)
		if _keep_reached(room, m):
			break
	for y in h:
		for x in w:
			room.grid[y][x] = [Consts.T.WALL, Consts.T.FLOOR, Consts.T.PIT][m[y * w + x]]
	# the obstacles of the JS rooms, a quadrant layout for each cell
	if room.shape[0] != "small":
		for c in RoomU.cells(room):
			var layout := RoomBuilder.expand_quad(rng.pick(RoomBuilder.QUADS.slice(1)))
			for y in 13:
				for x in 27:
					_put(room, c.x * Consts.RW + 1 + x, c.y * Consts.RH + 1 + y, layout[y][x], rng, biome)
	if rng.chance(0.5):
		for k in rng.rint(1, 3) * RoomU.cells(room).size():
			_put(room, rng.rint(2, w - 3), rng.rint(2, h - 3), "u" if biome.urns and rng.chance(0.6) else "b", rng, biome)
	RoomBuilder.place_doors(room)
	if not RoomU.check_reachable(room):
		for y in h:
			for x in w:
				if not (room.grid[y][x] in [Consts.T.WALL, Consts.T.PIT, Consts.T.DOOR]):
					room.grid[y][x] = Consts.T.FLOOR
		room.tileHp = {}
		RoomU.check_reachable(room)

# a tile of a quadrant layout on the floor (the JS rules for ?, u and #)
static func _put(room: Dictionary, tx: int, ty: int, ch: String, rng: RNG, biome: BiomeDef) -> void:
	if room.grid[ty][tx] != Consts.T.FLOOR:
		return
	if ch == "?":
		ch = "#" if rng.chance(0.5) else "."
	if ch == "u" and not biome.urns:
		ch = "b" if rng.chance(0.5) else "."
	if ch == "#" and rng.chance(0.12):
		ch = "%"
	var t: int = RoomBuilder.CHAR_TILE.get(ch, Consts.T.FLOOR)
	room.grid[ty][tx] = t
	if t == Consts.T.BARREL or t == Consts.T.URN:
		room.tileHp[ty * RoomU.rw(room) + tx] = 18 if t == Consts.T.BARREL else 1

# OUT, IN or PIT for each tile
static func _mask(room: Dictionary, shape: Array, rng: RNG) -> PackedByteArray:
	var w := RoomU.rw(room)
	var h := RoomU.rh(room)
	var m := PackedByteArray()
	m.resize(w * h)
	var cells := RoomU.cells(room)
	# the cells' floors, joined where the walls between them were
	for c in cells:
		var x0: int = c.x * Consts.RW
		var y0: int = c.y * Consts.RH
		var x1 := x0 + Consts.RW - 2 + (2 if cells.has(c + Vector2i(1, 0)) else 0)
		var y1 := y0 + Consts.RH - 2 + (2 if cells.has(c + Vector2i(0, 1)) else 0)
		_fill(m, w, x0 + 1, y0 + 1, x0 + Consts.RW - 2, y1, IN)
		_fill(m, w, x0 + 1, y0 + 1, x1, y0 + Consts.RH - 2, IN)
	match shape[0]:
		"chamfer":
			_chamfer(m, w, h, rng.rint(2, 5))
		"cave":
			_cave(m, w, h, rng)
		"cross":
			for c in cells:
				for k in [[-1, -1], [1, -1], [-1, 1], [1, 1]]:
					if cells.has(c + Vector2i(k[0], 0)) or cells.has(c + Vector2i(0, k[1])):
						continue
					var a := rng.rint(6, 10)
					var b := rng.rint(3, 4)
					var x0: int = c.x * Consts.RW + (1 if k[0] < 0 else Consts.RW - 1 - a)
					var y0: int = c.y * Consts.RH + (1 if k[1] < 0 else Consts.RH - 1 - b)
					_fill(m, w, x0, y0, x0 + a - 1, y0 + b - 1, OUT)
		"small":
			m.fill(OUT)
			var hw := rng.rint(5, 9)
			var hh := rng.rint(2, 4)
			_fill(m, w, 14 - hw, 7 - hh, 14 + hw, 7 + hh, IN)
	for c in cells:
		var x0: int = c.x * Consts.RW
		var y0: int = c.y * Consts.RH
		match shape[1]:
			"pits":
				var hw := rng.rint(2, 5)
				var hh := rng.rint(1, 2)
				_fill(m, w, x0 + 14 - hw, y0 + 7 - hh, x0 + 14 + hw, y0 + 7 + hh, PIT, IN)
			"chasm":
				# down the room, past the doors' columns, with a bridge
				var cols: Array = rng.shuffle([3, 9, 17, 23]).slice(0, 2 if rng.chance(0.35) else 1)
				for cx in cols:
					var b := rng.rint(3, 9)
					_fill(m, w, x0 + cx, y0 + 1, x0 + cx + 2, y0 + b - 1, PIT, IN)
					_fill(m, w, x0 + cx, y0 + b + 3, x0 + cx + 2, y0 + Consts.RH - 2, PIT, IN)
			"pillars":
				if rng.chance(0.5):
					for p in [[6, 3], [21, 3], [6, 9], [21, 9]]:
						_fill(m, w, x0 + p[0], y0 + p[1], x0 + p[0] + 1, y0 + p[1] + 1, OUT, IN)
				else:
					for px in [4, 8, 20, 24]:
						for py in [4, 10]:
							_fill(m, w, x0 + px, y0 + py, x0 + px, y0 + py, OUT, IN)
	_corridors(room, m, w, h)
	return m

# sets the rectangle to v (only its tiles that are only, when given)
static func _fill(m: PackedByteArray, w: int, x0: int, y0: int, x1: int, y1: int, v: int, only := -1) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if only < 0 or m[y * w + x] == only:
				m[y * w + x] = v

static func _is(m: PackedByteArray, w: int, h: int, x: int, y: int, v: int) -> bool:
	return x >= 0 and y >= 0 and x < w and y < h and m[y * w + x] == v

# k times, the corners go: the convex ones get cut on the diagonal
static func _chamfer(m: PackedByteArray, w: int, h: int, k: int) -> void:
	for i in k:
		var cut: Array = []
		for y in h:
			for x in w:
				if m[y * w + x] == IN and (not _is(m, w, h, x, y - 1, IN) or not _is(m, w, h, x, y + 1, IN)) \
						and (not _is(m, w, h, x - 1, y, IN) or not _is(m, w, h, x + 1, y, IN)):
					cut.append(y * w + x)
		for t in cut:
			m[t] = OUT

# the edges eaten away at random, then smoothed, inside the room's first outline
static func _cave(m: PackedByteArray, w: int, h: int, rng: RNG) -> void:
	var base := m.duplicate()
	for i in 3:
		var cut: Array = []
		for y in h:
			for x in w:
				if m[y * w + x] == IN and _near(m, w, h, x, y) < 4 and rng.chance(0.3):
					cut.append(y * w + x)
		for t in cut:
			m[t] = OUT
	for i in 2:
		var next := m.duplicate()
		for y in h:
			for x in w:
				var n := _near(m, w, h, x, y)
				if m[y * w + x] == OUT and base[y * w + x] == IN and n >= 3:
					next[y * w + x] = IN
				elif m[y * w + x] == IN and n <= 1:
					next[y * w + x] = OUT
		m.clear()
		m.append_array(next)

static func _near(m: PackedByteArray, w: int, h: int, x: int, y: int) -> int:
	var n := 0
	for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
		if _is(m, w, h, x + d[0], y + d[1], IN):
			n += 1
	return n

# each door opens on a way three tiles wide, straight in until it meets the floor
static func _corridors(room: Dictionary, m: PackedByteArray, w: int, h: int) -> void:
	for d in RoomU.door_keys(room):
		var s := RoomU.side(d)
		var tt := RoomU.door_tiles(d)
		for k in range(1, maxi(w, h)):
			var mid: Array = tt[1]
			var mx: int = mid[0] - s.dx * k
			var my: int = mid[1] - s.dy * k
			if mx < 1 or my < 1 or mx >= w - 1 or my >= h - 1:
				break
			if k > 2 and m[my * w + mx] == IN:
				break
			for t in tt:
				m[(t[1] - s.dy * k) * w + t[0] - s.dx * k] = IN

# only the floor the first door reaches stays; false if a door is left out
static func _keep_reached(room: Dictionary, m: PackedByteArray) -> bool:
	var w := RoomU.rw(room)
	var h := RoomU.rh(room)
	var keys := RoomU.door_keys(room)
	if keys.is_empty():
		return true
	var e: Array = RoomU.entry_tile(keys[0])
	var seen := {e[1] * w + e[0]: true}
	var q: Array = [e[1] * w + e[0]]
	while not q.is_empty():
		var k: int = q.pop_back()
		for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
			var nx: int = k % w + d[0]
			var ny: int = k / w + d[1]
			var nk := ny * w + nx
			if _is(m, w, h, nx, ny, IN) and not seen.has(nk):
				seen[nk] = true
				q.append(nk)
	for d in keys:
		var t: Array = RoomU.entry_tile(d)
		if not seen.has(t[1] * w + t[0]):
			return false
	for i in m.size():
		if m[i] == IN and not seen.has(i):
			m[i] = OUT
	return true
