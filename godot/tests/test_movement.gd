extends TestCase
# Separate-axis movement, corner sliding, flow field and line of sight: like the JS.

func after() -> void:
	Run.reset()

func _room(seed: int) -> Dictionary:
	U.seed_random(seed)
	Run.reset()
	Run.active = true
	Run.player = Player.new()
	Run.player.recalc_stats()
	var f := FloorGen.gen_floor(1, RNG.new(seed))
	Run.floor = f
	var room: Dictionary = f.rooms.filter(func(x): return x.type == "normal")[0]
	RoomBuilder.build_room(room, f)
	Run.room = room
	return room

func test_movement_tracks() -> void:
	for tr in TestCase.golden("movement").traces:
		var room := _room(int(tr.seed))
		room.cleared = tr.open
		room.combat = not tr.open
		var a := {"x": float(tr.start[0]), "y": float(tr.start[1]), "r": 4.0}
		for i in tr.steps.size():
			var st: Array = tr.steps[i]
			var dx: float = st[0]
			var dy: float = st[1]
			var bx := Coll.move_axis(a, dx, 0, false)
			var by := Coll.move_axis(a, dy, 1, false)
			if bx and absf(dy) < 1:
				Coll.nudge(a, 0, dx)
			if by and absf(dx) < 1:
				Coll.nudge(a, 1, dy)
			if absf(a.x - st[2]) > 1e-9 or absf(a.y - st[3]) > 1e-9 or (bx or by) != st[4]:
				fail("seed %d doors %s step %d: (%s, %s) != (%s, %s)" % [tr.seed, tr.open, i, a.x, a.y, st[2], st[3]])
				return

func test_flow_field() -> void:
	for fl in TestCase.golden("movement").flow:
		var room := _room(int(fl.seed))
		room.cleared = false
		room.combat = true
		Run.player.x = fl.player[0]
		Run.player.y = fl.player[1]
		FlowField.update()
		for pr in fl.probes:
			near(FlowField.angle({"x": pr[0], "y": pr[1]}, Run.player.x, Run.player.y), pr[2], 1e-9, "seed %d %s" % [fl.seed, pr])

func test_line_of_sight() -> void:
	for ln in TestCase.golden("movement").lines:
		var room := _room(int(ln.seed))
		room.cleared = false
		room.combat = true
		for c in ln.cases:
			eq(Coll.line_clear(c[0], c[1], c[2], c[3]), c[4], "seed %d %s" % [ln.seed, c])
