extends TestCase
# Effects: bombs, explosions on cracked rocks, secret passages, shockwaves, fire, summons.

func after() -> void:
	Run.reset()

func _run_fx(seconds: float) -> void:
	for i in int(seconds / Consts.DT) + 1:
		Effects.update(Consts.DT)

func test_bomb_breaks_the_cracked_rocks() -> void:
	TH.new_run(11)
	var room := TH.arena()
	var c := RoomU.tile_center(10, 5)
	room.grid[5][10] = Consts.T.CRACK
	Effects.place_bomb(c.x, c.y, "player")
	_run_fx(1.6)
	eq(room.grid[5][10], Consts.T.FLOOR)
	check(room.bgDirty)

func test_bomb_reveals_the_secret_passage() -> void:
	for seed in range(1, 40):
		TH.new_run(seed)
		var secret := TH.room_of("secret")
		if secret.is_empty():
			continue
		var host: Dictionary = {}
		var dir := ""
		for d in RoomU.DIRS:
			var n = RoomU.room_at(Run.floor, secret.gx - RoomU.DIRS[d].dx, secret.gy - RoomU.DIRS[d].dy)
			if n != null and n.type != "secret":
				host = n
				dir = d
				break
		Flow.enter_room(host, null)
		var dc := RoomU.door_center(dir)
		Effects.place_bomb(dc.x, dc.y, "player")
		_run_fx(1.6)
		check(secret.found, "secret found")
		eq(Run.room.grid[RoomU.DIRS[dir].tiles[1][1]][RoomU.DIRS[dir].tiles[1][0]], Consts.T.DOOR)
		return
	fail("no floor with a secret room in seeds 1-39")

func test_enemy_wave_hits_once() -> void:
	TH.new_run(12)
	TH.arena()
	var p := Run.player
	p.inv = 0.0
	var hp := p.hp
	Effects.add({"type": "shockwave", "x": p.x - 40, "y": p.y, "r": 4.0, "maxR": 90.0, "spd": 150.0, "owner": "enemy", "dmg": 5.0, "src": "Wave"})
	_run_fx(0.6)
	check(p.hp < hp)
	var hp2 := p.hp
	p.inv = 0.0
	_run_fx(0.2)
	eq(p.hp, hp2, "only once")

func test_summon() -> void:
	TH.new_run(13)
	TH.arena()
	Effects.add({"type": "spawn", "x": 200.0, "y": 120.0, "life": 0.5, "spec": {"type": "rat", "summoned": true}})
	_run_fx(0.55)
	eq(Run.enemies.size(), 1)
	check(Run.enemies[0].summoned)
