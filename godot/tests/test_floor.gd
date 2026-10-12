extends TestCase
# genFloor: same floor as the JS for every seed and depth.

func test_floors_like_the_js() -> void:
	for g in TestCase.golden("floors"):
		var f := FloorGen.gen_floor(int(g.depth), RNG.new(int(g.seed)))
		eq(RoomU.key(f.start), g.start, "start, seed %d" % g.seed)
		eq(f.rooms.size(), g.rooms.size(), "room count, seed %d" % g.seed)
		for i in g.rooms.size():
			var r: Dictionary = f.rooms[i]
			var e: Dictionary = g.rooms[i]
			var doors := {}
			for d in r.doors:
				doors[d] = RoomU.key(r.doors[d])
			var got := {"key": RoomU.key(r), "gx": r.gx, "gy": r.gy, "type": r.type, "dist": r.dist, "seed": r.seed,
				"cleared": r.cleared, "found": r.found, "locked": r.get("locked", false), "doors": doors}
			var d := TestCase.diff(got, e, "room %d" % i)
			if d != "":
				fail("depth %d seed %d: %s" % [g.depth, g.seed, d])
				return
		for r in f.rooms:
			r.doors.clear()

func test_door_utilities() -> void:
	eq(RoomU.door_entry("n"), Vector2(8 + 14.5 * 16, 28 + 1.9 * 16))
	eq(RoomU.door_center("e"), Vector2(8 + 28.5 * 16, 28 + 7.5 * 16))
	eq(RoomU.world_to_tile(8, 28), Vector2i(0, 0))
	eq(RoomU.world_to_tile(7.9, 27.9), Vector2i(-1, -1))
	eq(RoomU.tile_center(14, 7), Vector2(8 + 14.5 * 16, 28 + 7.5 * 16))
