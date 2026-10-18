extends TestCase
# buildRoom: grid, objects, pickups, decorations, waves and reachability as in the JS.

func after() -> void:
	Run.reset()

static func _str_keys(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[str(k)] = d[k]
	return out

func test_rooms_like_the_js() -> void:
	for g in TestCase.golden("rooms"):
		U.seed_random(int(g.seed) * 7919)
		Run.reset()
		Run.active = true
		Run.player = Player.new()
		Run.player.recalc_stats()
		Run.depth = int(g.depth)
		var f := FloorGen.gen_floor(int(g.depth), RNG.new(int(g.seed)))
		for i in f.rooms.size():
			var r: Dictionary = f.rooms[i]
			RoomBuilder.build_room(r, f)
			var e: Dictionary = g.rooms[i]
			var got := {"key": RoomU.key(r), "type": r.type, "grid": r.grid, "tileHp": _str_keys(r.tileHp),
				"doorDir": _str_keys(r.doorDir), "objects": r.objects, "pickups": r.pickups, "decals": r.decals,
				"waves": r.waves, "tutorial": r.get("tutorial", false),
				"reach": null if r.reach == null else r.reach.keys()}
			var d := TestCase.diff(got, e, "room %s" % e.key)
			if d != "":
				fail("depth %d seed %d: %s" % [g.depth, g.seed, d])
				return

func test_base_prices() -> void:
	for c in TestCase.golden("formulas").basePrice:
		var it := {"kind": c[0]}
		if c[0] == "cons":
			it.id = c[1]
		eq(RoomBuilder.base_price(it, int(c[2])), c[3], "%s" % [c])

func test_a_doorway_goes_on_one_tile_past_the_edge() -> void:
	TH.new_run(7)
	var room := Run.room
	room.doors = {"n": {"type": "normal"}}
	room.grid[0][14] = Consts.T.DOOR
	room.doorDir[14] = "n"
	eq(RoomU.tile_at(room, 14, -1, true), Consts.T.DOOR, "beyond a door: the doorway")
	eq(RoomU.tile_at(room, 14, -2, true), Consts.T.WALL, "two tiles out: wall")
	eq(RoomU.tile_at(room, 5, -1, true), Consts.T.WALL, "beyond a wall: wall")
	eq(RoomU.tile_at(room, 14, -1), Consts.T.WALL, "for the rest of the game the edge stays a wall, as in the JS")
	room.cleared = true
	room.combat = false
	check(not RoomU.is_solid_tile(room, 14, -1, false, true), "open like its door")
	room.cleared = false
	check(RoomU.is_solid_tile(room, 14, -1, false, true), "closed like its door")
