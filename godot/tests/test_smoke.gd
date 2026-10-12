extends TestCase
# Prove di gioco simulate: si spara al nemico più vicino finché la stanza è ripulita.

func after() -> void:
	Controls.sim.clear()
	Run.reset()

static func nearest() -> Variant:
	var best: Variant = null
	var bd := INF
	for e in Run.enemies:
		if e.dead or e.spawning:
			continue
		var d := U.dist(e.x, e.y, Run.player.x, Run.player.y)
		if d < bd:
			bd = d
			best = e
	return best

static func fight(max_ticks: int, done: Callable) -> bool:
	for i in max_ticks:
		Run.player.inv = 99.0
		var e: Variant = nearest()
		Controls.sim = {"device": "mouse", "fire": e != null}
		if e != null:
			Controls.sim.mouse = Vector2(e.x, e.y)
		Flow.update_common(Consts.DT)
		if Run.trans != null:
			Flow.update_trans(Consts.DT)
		else:
			Flow.update_game(Consts.DT)
		Controls.end_tick()
		if done.call():
			return true
	return false

func test_stanza_di_combattimento_ripulita() -> void:
	TH.new_run(17)
	var room := TH.room_of("normal")
	RoomBuilder.build_room(room, Run.floor)
	for ty in range(1, Consts.RH - 1):
		for tx in range(1, Consts.RW - 1):
			if room.grid[ty][tx] != Consts.T.FLOOR:
				room.grid[ty][tx] = Consts.T.FLOOR
	Flow.enter_room(room, null)
	check(fight(5400, func(): return room.cleared), "stanza ripulita entro 90 s simulati")
	check(Run.kills > 0)
func test_guardiano_sconfitto() -> void:
	TH.new_run(23)
	var p := Run.player
	p.perks = {"multishot": 3, "dmg": 5, "rate": 5}
	p.relics = ["r_anvil"]
	p.recalc_stats()
	TH.enter("boss")
	check(fight(20000, func(): return Run.room.objects.any(func(o): return o.type == "trapdoor")), "guardiano sconfitto")
