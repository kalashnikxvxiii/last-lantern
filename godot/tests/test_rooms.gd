extends TestCase
# buildRoom: griglia, oggetti, raccoglibili, decorazioni, ondate e raggiungibilità come nel JS.

func after() -> void:
	Run.reset()

static func _str_keys(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[str(k)] = d[k]
	return out

func test_stanze_come_il_js() -> void:
	for g in TestCase.golden("rooms"):
		U.seed_random(int(g.seed) * 7919)
		Run.reset()
		Run.active = true
		Run.player = Player.new()
		Run.player.recalc_stats()
		var f := FloorGen.gen_floor(1, RNG.new(int(g.seed)))
		for i in f.rooms.size():
			var r: Dictionary = f.rooms[i]
			RoomBuilder.build_room(r, f)
			var e: Dictionary = g.rooms[i]
			var got := {"key": RoomU.key(r), "type": r.type, "grid": r.grid, "tileHp": _str_keys(r.tileHp),
				"doorDir": _str_keys(r.doorDir), "objects": r.objects, "pickups": r.pickups, "decals": r.decals,
				"waves": r.waves, "tutorial": r.get("tutorial", false),
				"reach": null if r.reach == null else r.reach.keys()}
			var d := TestCase.diff(got, e, "stanza %s" % e.key)
			if d != "":
				fail("seme %d: %s" % [g.seed, d])
				return

func test_prezzi_base() -> void:
	for c in TestCase.golden("formulas").basePrice:
		var it := {"kind": c[0]}
		if c[0] == "cons":
			it.id = c[1]
		eq(RoomBuilder.base_price(it, int(c[2])), c[3], "%s" % [c])
