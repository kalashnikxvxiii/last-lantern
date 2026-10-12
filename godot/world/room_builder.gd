class_name RoomBuilder
extends RefCounted
# Room building (js/dungeon.js): layout from quadrants, doors, contents, waves.

# 14x7 quadrants (column 13 and row 6 are the symmetry axes).
# '.' floor  '#' rock  '%' cracked rock  'b' barrel  'u' urn
# '^' spikes  'o' brazier  '?' random rock
const QUADS := [
	["..............", "..............", "..............", "..............", "..............", "..............", ".............."],
	["..............", "..............", "..............", ".....##.......", ".....##.......", "..............", ".............."],
	["..............", "..............", "..............", "..........o###", "...........###", "...........###", "...........###"],
	["..............", "..............", "...#######....", "..............", "..............", "..............", ".............."],
	["..............", "..b...........", ".....#........", "..........#...", "...#..........", ".......b....%.", ".............."],
	["..............", "..............", ".............#", ".............#", ".............#", ".........#####", ".............."],
	["..............", "..............", "....^^^.......", "....^^^.......", "..............", ".........^^^^^", ".............."],
	["..............", "..............", "......####....", "......#.......", "......#.......", "..............", ".............."],
	["..............", ".#............", "..#...........", "...#.......o..", "....#.........", ".....#........", ".............."],
	["..............", ".b.....u......", "..............", "...u.......#..", "..........###.", "...........#..", ".............."],
	["..............", "..............", "...?...#...?..", "..............", "..............", "...#...?...#..", ".............."],
	["..............", "..#####.......", "..#...........", "..#....#######", "..............", "..............", ".............."],
	["..............", "..............", "..............", ".........^^^^^", ".........^....", ".........^....", ".............."],
	["..............", "..u.......u...", "....%%........", "....%%........", "..............", ".......b......", ".............."],
	["..............", "...b..........", "..............", ".......##.....", ".......##..^^^", "...........^..", ".............."],
]
const QUAD_BOSS := ["..............", ".o............", "..............", "..............", "..............", "..............", ".............."]
const QUAD_SPECIAL := ["..............", "..o...........", "..............", "..............", "..............", "..............", ".............."]
const CHAR_TILE := {".": Consts.T.FLOOR, "#": Consts.T.ROCK, "%": Consts.T.CRACK, "b": Consts.T.BARREL,
	"u": Consts.T.URN, "^": Consts.T.SPIKE, "o": Consts.T.BRAZIER}

static func expand_quad(q: Array) -> Array:
	var top: Array = []
	for row in q:
		var mirror := ""
		for i in range(12, -1, -1):
			mirror += row[i]
		top.append(row + mirror)
	var out := top.duplicate()
	for i in range(5, -1, -1):
		out.append(top[i])
	return out

static func build_room(room: Dictionary, fl: Dictionary) -> void:
	var rng := RNG.new(room.seed)
	var biome := DB.biome_of(fl.depth)
	var rw := Consts.RW
	var rh := Consts.RH
	room.built = true
	room.grid = []
	for y in rh:
		var row: Array = []
		for x in rw:
			row.append(Consts.T.WALL if x == 0 or y == 0 or x == rw - 1 or y == rh - 1 else Consts.T.FLOOR)
		room.grid.append(row)
	room.doorDir = {}
	room.tileHp = {}
	room.objects = []
	room.pickups = []
	room.decals = []
	room.spikeT = 0.0
	room.waves = []
	room.combat = false
	room.bgDirty = true

	var quad: Array
	if room.type == "boss":
		quad = QUAD_BOSS
	elif room.type == "normal" or room.type == "elite":
		quad = rng.pick(QUADS.slice(1))
	elif room.type == "start":
		quad = QUADS[0]
	else:
		quad = QUAD_SPECIAL

	var layout := expand_quad(quad)
	for y in 13:
		for x in 27:
			var ch: String = layout[y][x]
			if ch == "?":
				ch = "#" if rng.chance(0.5) else "."
			if ch == "u" and not biome.urns:
				ch = "b" if rng.chance(0.5) else "."
			if ch == "#" and rng.chance(0.12):
				ch = "%"
			var t: Variant = CHAR_TILE.get(ch)
			room.grid[y + 1][x + 1] = Consts.T.FLOOR if t == null else t
			if t == Consts.T.BARREL:
				room.tileHp[(y + 1) * rw + x + 1] = 18
			if t == Consts.T.URN:
				room.tileHp[(y + 1) * rw + x + 1] = 1
	# extra variety: urns/barrels scattered in normal rooms
	if room.type == "normal" and rng.chance(0.5):
		var k := 0
		while k < rng.rint(1, 3):
			var x := rng.rint(2, 26)
			var y := rng.rint(2, 12)
			if room.grid[y][x] == Consts.T.FLOOR:
				var t: int = Consts.T.URN if biome.urns and rng.chance(0.6) else Consts.T.BARREL
				room.grid[y][x] = t
				room.tileHp[y * rw + x] = 1 if t == Consts.T.URN else 18
			k += 1
	# doors and free space in front
	for d in RoomU.DIRS:
		if not room.doors.has(d):
			continue
		for tt in RoomU.DIRS[d].tiles:
			room.doorDir[tt[1] * rw + tt[0]] = d
			room.grid[tt[1]][tt[0]] = Consts.T.DOOR if RoomU.door_visible(room, d) else Consts.T.WALL
		clear_door_zone(room, d)
	# reachability
	if not RoomU.check_reachable(room):
		for y in range(1, rh - 1):
			for x in range(1, rw - 1):
				room.grid[y][x] = Consts.T.FLOOR
		room.tileHp = {}
	# decorations
	var n_dec := rng.rint(10, 22)
	for k in n_dec:
		room.decals.append({"x": rng.rint(Consts.RX + 18, Consts.RX + rw * Consts.TS - 18), "y": rng.rint(Consts.RY + 18, Consts.RY + rh * Consts.TS - 18),
			"k": rng.rint(0, 5), "s": rng.next()})

	# contents
	var c := RoomU.tile_center(14, 7)
	match room.type:
		"normal", "elite":
			plan_waves(room, fl, rng, biome)
		"boss":
			room.waves = [[{"type": "BOSS", "boss": biome.boss}]]
		"treasure":
			var picks: Array = random_relics(2, rng)
			if picks.is_empty():
				picks.append(null)
			for i in picks.size():
				var id: Variant = picks[i]
				var x: float = c.x if picks.size() == 1 else c.x + (-36 if i == 0 else 36)
				if id != null:
					room.objects.append({"type": "relic", "id": id, "x": x, "y": c.y, "group": "treasure"})
				else:
					room.objects.append({"type": "chest", "gold": true, "x": x, "y": c.y})
		"shop":
			make_shop(room, fl, rng)
		"shrine":
			make_shrine(room, fl, rng)
		"secret":
			room.objects.append({"type": "chest", "gold": true, "open": false, "x": c.x, "y": c.y + 12})
			if rng.chance(0.5):
				var r: Array = random_relics(1, rng)
				if not r.is_empty():
					room.objects.append({"type": "relic", "id": r[0], "x": c.x, "y": c.y - 24})
			var k := 0
			while k < rng.rint(6, 10):
				var type := "coin5" if rng.chance(0.2) else "coin"
				var px := c.x + rng.frange(-50, 50)
				var py := c.y + rng.frange(-30, 40)
				room.pickups.append(Pickups.make(type, px, py))
				k += 1
		"start":
			if fl.depth == 1:
				room.tutorial = true

static func clear_door_zone(room: Dictionary, d: String) -> void:
	var z: Array = {"n": [11, 1, 17, 2], "s": [11, 12, 17, 13], "w": [1, 5, 2, 9], "e": [26, 5, 27, 9]}[d]
	for y in range(z[1], z[3] + 1):
		for x in range(z[0], z[2] + 1):
			room.grid[y][x] = Consts.T.FLOOR
			room.tileHp.erase(y * Consts.RW + x)

static func plan_waves(room: Dictionary, fl: Dictionary, rng: RNG, biome: BiomeDef) -> void:
	var d: int = fl.depth
	var elite: bool = room.type == "elite"
	var n_waves := 1
	if d == 1:
		n_waves = 2 if room.dist >= 3 and rng.chance(0.25) else 1
	elif d == 2:
		n_waves = 2 if rng.chance(0.4) else 1
	elif d <= 4:
		n_waves = 2 if rng.chance(0.6) else 1
	else:
		n_waves = 3 if rng.chance(0.3) else 2
	if elite:
		n_waves = 2
	var ard := Run.ardor if Run.active else 0
	var elite_chance: float = [0, 0.06, 0.12, 0.18, 0.24][mini(4, d - 1)] + maxf(0, d - 5) * 0.04
	if ard >= 3:
		elite_chance *= 2
	for w in n_waves:
		var budget := 3.4 + d * 1.7 + minf(4, room.dist * 0.45) + rng.frange(0, 1.6)
		if d > 5:
			budget += (d - 5) * 1.2
		if n_waves > 1:
			budget *= 0.8
		if elite:
			budget *= 0.75
		var wave: Array = []
		var guard := 0
		while budget > 0.9 and wave.size() < 11 and guard < 50:
			guard += 1
			var opts: Array = biome.pool.filter(func(o): return o[1] <= budget + 0.4)
			if opts.is_empty():
				break
			var pick: Array = rng.weighted(opts, func(o): return o[2])
			budget -= pick[1]
			var mod: Variant = null
			if elite or rng.chance(elite_chance):
				mod = rng.pick(EliteMods.ALL.keys())
			wave.append({"type": pick[0], "mod": mod})
		if not wave.is_empty():
			room.waves.append(wave)

static func make_shop(room: Dictionary, fl: Dictionary, rng: RNG) -> void:
	var c := RoomU.tile_center(14, 7)
	room.objects.append({"type": "merchant", "x": c.x, "y": c.y - 40, "line": rng.pick(Lore.MERCHANT_LINES)})
	var cons_pool: Array = Cons.ALL.keys()
	var wf := func(k): return Cons.ALL[k].w
	var items: Array = []
	var k1: String = rng.weighted(cons_pool, wf)
	var k2: String = rng.weighted(cons_pool, wf)
	if k2 == k1:
		k2 = rng.weighted(cons_pool, wf)
	items.append({"kind": "cons", "id": k1})
	items.append({"kind": "cons", "id": k2})
	items.append({"kind": "heal"})
	items.append({"kind": "key" if rng.chance(0.5) else "cons", "id": "bomb"})
	var relic: Array = random_relics(1, rng)
	if not relic.is_empty():
		items.append({"kind": "relic", "id": relic[0]})
	var n := items.size()
	for i in n:
		var x := c.x + (i - (n - 1) / 2.0) * 40
		room.objects.append({"type": "shopitem", "item": items[i], "x": x, "y": c.y + 18, "price": base_price(items[i], fl.depth)})

static func base_price(it: Dictionary, depth: int) -> float:
	var m := 1 + 0.12 * (depth - 1)
	match it.kind:
		"cons": return U.jround(Cons.ALL[it.id].price * m)
		"heal": return U.jround(15 * m)
		"key": return U.jround(12 * m)
		"relic": return U.jround(48 + depth * 8)
	return 10.0

static func make_shrine(room: Dictionary, fl: Dictionary, rng: RNG) -> void:
	var c := RoomU.tile_center(14, 7)
	var kind: String = rng.pick(["blood", "fortune", "fountain", "pact"])
	room.objects.append({"type": "shrine", "kind": kind, "x": c.x, "y": c.y - 4, "uses": 5 if kind == "fortune" else 1})

# relics not owned and not yet offered; null rng = U.shuffle (Math.random)
static func random_relics(n: int, rng: RNG = null) -> Array:
	var owned: Array = Run.player.relics if Run.active and Run.player != null else []
	var offered: Dictionary = Run.offered_relics
	var pool: Array = Relics.ALL.keys().filter(func(k): return not owned.has(k) and not offered.has(k))
	if pool.size() < n:
		pool = Relics.ALL.keys().filter(func(k): return not owned.has(k))
	if rng == null:
		U.shuffle(pool)
	else:
		rng.shuffle(pool)
	var out := pool.slice(0, n)
	for k in out:
		offered[k] = true
	return out
