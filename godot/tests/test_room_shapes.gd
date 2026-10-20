extends TestCase
# Godot-only rooms of other sizes and shapes (RoomShapes): merged cells, outlines,
# pits, the doors between them and the camera that scrolls over a big room.

func after() -> void:
	Run.reset()
	Fx.reset()

func _floors(each: Callable) -> void:
	for seed in range(1, 31):
		for depth in [1, 3, 5]:
			Run.reset()
			Run.active = true
			Run.player = Player.new()
			Run.player.recalc_stats()
			Run.depth = depth
			var fl := FloorGen.gen_floor(depth, RNG.new(seed))
			RoomShapes.apply(fl)
			Run.floor = fl
			each.call(fl, "seed %d depth %d" % [seed, depth])

func test_every_cell_of_a_room_maps_to_it_and_keys_stay_unique() -> void:
	_floors(func(fl: Dictionary, at: String) -> void:
		var keys := {}
		for r in fl.rooms:
			check(not keys.has(RoomU.key(r)), "%s: one key per room" % at)
			keys[RoomU.key(r)] = true
			for c in RoomU.cells(r):
				check(is_same(RoomU.room_at(fl, r.gx + c.x, r.gy + c.y), r), "%s: cell %s of %s" % [at, c, RoomU.key(r)])
				check(c.x < r.get("cw", 1) and c.y < r.get("ch", 1), "%s: inside its grid" % at))

func test_every_door_has_its_way_back_right_beyond_the_wall() -> void:
	_floors(func(fl: Dictionary, at: String) -> void:
		for r in fl.rooms:
			for d in r.doors:
				var n: Dictionary = r.doors[d]
				var back := RoomU.back_door(r, d)
				check(n.doors.has(back) and is_same(n.doors[back], r), "%s: %s %s has %s back" % [at, RoomU.key(r), d, back])
				# the door and the one back are one tile apart in the world
				var step := Vector2(RoomU.side(d).dx, RoomU.side(d).dy) * Consts.TS
				eq(RoomU.door_center(d) + step, RoomU.door_center(back) + RoomU.room_offset(r, n), "%s: %s lines up" % [at, d]))

func test_every_shaped_room_keeps_its_doors_in_reach() -> void:
	_floors(func(fl: Dictionary, at: String) -> void:
		for r in fl.rooms:
			if not r.has("shape"):
				continue
			RoomBuilder.build_room(r, fl)
			check(RoomU.check_reachable(r), "%s: %s %s" % [at, RoomU.key(r), r.shape])
			eq(r.grid.size(), RoomU.rh(r))
			eq(r.grid[0].size(), RoomU.rw(r))
			for d in r.doors:
				for t in RoomU.door_tiles(d):
					check(r.grid[t[1]][t[0]] in [Consts.T.DOOR, Consts.T.WALL], "%s: door %s on the wall" % [at, d])
			for y in RoomU.rh(r):
				for x in RoomU.rw(r):
					var c := RoomU.tile_center(x, y)
					if RoomU.beyond(r, c.x, c.y) != null:
						eq(r.grid[y][x], Consts.T.WALL, "%s: nothing out of the room's cells" % at))

func test_the_floors_have_big_rooms_twin_doors_and_shapes() -> void:
	var seen := {}
	_floors(func(fl: Dictionary, _at: String) -> void:
		for r in fl.rooms:
			if RoomU.cells(r).size() > 1:
				seen["big"] = true
			if r.has("shape"):
				seen[r.shape[0]] = true
				seen[r.shape[1]] = true
			for d in r.doors:
				if RoomU.door_slot(d) != "":
					seen["twin"] = true
				if RoomU.door_cell(d) != Vector2i.ZERO:
					seen["side door"] = true
			if r.type != "normal":
				check(not r.has("shape") and not r.has("cells"), "only normal rooms change"))
	for k in ["big", "twin", "side door", "chamfer", "cave", "cross", "small", "pits", "chasm", "pillars"]:
		check(seen.has(k), k)

func test_a_floor_is_the_same_for_the_same_seed() -> void:
	var a := FloorGen.gen_floor(2, RNG.new(11))
	var b := FloorGen.gen_floor(2, RNG.new(11))
	RoomShapes.apply(a)
	RoomShapes.apply(b)
	eq(a.rooms.map(func(r): return [RoomU.key(r), r.get("cells"), r.get("shape"), r.doors.keys()]),
		b.rooms.map(func(r): return [RoomU.key(r), r.get("cells"), r.get("shape"), r.doors.keys()]))

# a run with a room of several cells next to the start
func _big_next_to_start() -> String:
	for seed in range(1, 60):
		TH.new_run(seed)
		for d in Run.room.doors:
			if RoomU.cells(Run.room.doors[d]).size() > 1:
				return d
	fail("no big room next to the start in seeds 1-59")
	return ""

func test_walking_into_a_big_room_and_back() -> void:
	var d := _big_next_to_start()
	var start := Run.room
	var big: Dictionary = start.doors[d]
	var dir := Vector2(RoomU.side(d).dx, RoomU.side(d).dy)
	var p := Run.player
	var at := RoomU.door_center(d) + dir * (Consts.TS / 2.0 + 1.0)
	p.x = at.x
	p.y = at.y
	Flow.check_doors(Consts.DT)
	check(is_same(Run.room, big), "in the big room")
	eq(Vector2(p.x, p.y), at - RoomU.room_offset(start, big), "at its door, wherever it is on the big room's walls")
	var back := RoomU.back_door(start, d)
	eq(big.entering, back)
	check(not Coll.collides(big, p.x, p.y, p.r, false, true), "in its doorway")
	# back out the same way
	var out := RoomU.door_center(back) - dir * (Consts.TS / 2.0 + 1.0)
	p.x = out.x
	p.y = out.y
	Flow.check_doors(Consts.DT)
	check(is_same(Run.room, start), "back in the start room")

func test_the_camera_scrolls_over_a_big_room() -> void:
	var d := _big_next_to_start()
	var big: Dictionary = Run.room.doors[d]
	RoomBuilder.build_room(big, Run.floor)
	Run.room = big
	var w := RoomU.rw(big) * Consts.TS
	var h := RoomU.rh(big) * Consts.TS
	var lo := Fx.cam_target(Consts.RX, Consts.RY)
	var hi := Fx.cam_target(Consts.RX + w, Consts.RY + h)
	eq(lo, -Fx.CAM_MAX, "in the top-left corner: the first cell's view")
	eq(hi, Vector2(w - Consts.RW * Consts.TS, h - Consts.RH * Consts.TS) + Fx.CAM_MAX, "and the last one's in the bottom-right")
	eq(RoomU.view_size(big), Vector2(Consts.RX * 2 + w, Consts.H - Consts.RH * Consts.TS + h), "the flat world holds the whole room")

func test_a_pit_stops_walkers_not_flyers_nor_shots() -> void:
	TH.new_run(7)
	var room := TH.arena()
	room.grid[5][5] = Consts.T.PIT
	check(RoomU.is_solid_tile(room, 5, 5, false), "walkers fall short of it")
	check(not RoomU.is_solid_tile(room, 5, 5, true), "flyers cross it")
	check(not RoomU.blocks_shot(room, 5, 5), "shots fly over it")
	check(not RoomU.walkable(Consts.T.PIT))
