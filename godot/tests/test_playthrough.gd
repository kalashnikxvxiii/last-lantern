extends TestCase
# Simulated descent through the five depths and the Infinite Abyss: every combat
# room is cleared by a bot, the wardens fall, the trapdoor leads to the next biome.

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

# shoots the nearest enemy; the player is invulnerable
static func fight_until(max_ticks: int, done: Callable) -> bool:
	for i in max_ticks:
		Run.player.inv = 99.0
		var e: Variant = nearest()
		Controls.sim = {"device": "mouse", "fire": e != null}
		if e != null:
			Controls.sim.mouse = Vector2(e.x, e.y)
			# a room bigger than one cell: the bot hops within range (it does not walk)
			var p := Run.player
			var d := U.dist(e.x, e.y, p.x, p.y)
			if d > 160:
				var to := Vector2(e.x + (p.x - e.x) * 120 / d, e.y + (p.y - e.y) * 120 / d)
				var best := Vector2(p.x, p.y)
				for t in RoomU.reach_tiles(Run.room):
					var c := RoomU.tile_center(t.x, t.y)
					if Run.room.grid[t.y][t.x] == Consts.T.FLOOR and c.distance_to(to) < best.distance_to(to):
						best = c
				p.x = best.x
				p.y = best.y
		Flow.update_common(Consts.DT)
		if Run.trans != null:
			Flow.update_trans(Consts.DT)
		else:
			Flow.update_game(Consts.DT)
		Controls.end_tick()
		if done.call():
			return true
	return false

func _boost() -> void:
	var p := Run.player
	p.perks = {"multishot": 3, "dmg": 5, "rate": 5}
	p.relics = ["r_anvil"]
	p.recalc_stats()
	p.stats.dmgMult *= 6.0   # the bot only needs to get through the content

func _clear_rooms(types: Array) -> void:
	for r in Run.floor.rooms:
		if not types.has(r.type):
			continue
		RoomBuilder.build_room(r, Run.floor)
		for ty in range(1, RoomU.rh(r) - 1):
			for tx in range(1, RoomU.rw(r) - 1):
				var c := RoomU.tile_center(tx, ty)
				if RoomU.beyond(r, c.x, c.y) == null:   # out of a room of several cells stays out
					r.grid[ty][tx] = Consts.T.FLOOR   # the bot does not walk: no cover, nor walls in a shaped room
		Flow.enter_room(r, null)
		var arena := Run.room
		check(fight_until(9000, func(): return arena.cleared or Run.player.dead or Run.won), "%s room %s cleared on depth %d (%s left)" % [r.type, RoomU.key(r), Run.depth, Run.enemies.map(func(e): return e.type)])
		Run.player.hp = Run.player.stats.maxHp

func test_the_five_depths() -> void:
	TH.new_run(5)
	_boost()
	for depth in range(1, 7):
		check(Run.depth == depth)
		var biome := DB.biome_of(depth)
		eq(Run.floor.depth, depth)
		_clear_rooms(["normal", "elite"])
		var boss_room := TH.room_of("boss")
		Flow.enter_room(boss_room, null)
		var expected_boss := biome.boss
		eq(boss_room.waves[0][0].boss, expected_boss, "warden of depth %d" % depth)
		check(fight_until(30000, func(): return Run.room.objects.any(func(o): return o.type == "trapdoor") or Run.won), "warden %s defeated" % expected_boss)
		if Run.won:
			Run.victory_t = 0.0
			Run.room.objects.append({"type": "trapdoor", "x": 0, "y": 0})
		Flow.descend()
		for i in 200:
			Flow.update_trans(Consts.DT)
			if Run.trans == null:
				break
		eq(Run.depth, depth + 1)
		Run.player.hp = Run.player.stats.maxHp
	check(Run.won)
	check(Run.depth == 7)
