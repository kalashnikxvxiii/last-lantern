extends TestCase
# Proiettili: muri, rimbalzi, perforazione, schegge, colpi al giocatore, uscita di scena.

func before() -> void:
	TH.new_run(9)
	var room := TH.arena()
	for ty in range(1, Consts.RH - 1):
		for tx in range(1, Consts.RW - 1):
			room.grid[ty][tx] = Consts.T.FLOOR
	Run.player.inv = 0.0

func after() -> void:
	Run.reset()

func _shot(x: float, y: float, vx: float, vy: float, o: Dictionary = {}) -> Dictionary:
	var b := {"x": x, "y": y, "vx": vx, "vy": vy, "r": 3.0, "dmg": 10.0, "crit": false, "life": 5.0,
		"pierce": 0, "bounce": 0, "hit": {}, "kind": "ember", "t": 0.0}
	b.merge(o, true)
	Run.bullets.append(b)
	return b

func test_muro_senza_rimbalzo() -> void:
	_shot(Consts.RX + 20, 120, -600, 0)
	for i in 10:
		Bullets.update_player(Consts.DT)
	eq(Run.bullets.size(), 0)

func test_rimbalzo() -> void:
	var b := _shot(Consts.RX + 20, 120, -600, 0, {"bounce": 1})
	for i in 4:
		Bullets.update_player(Consts.DT)
	check(b.vx > 0, "rimbalzato")
	eq(b.bounce, 0)

func test_perforazione() -> void:
	var a := TH.spawn("ghoul", 200, 120)
	var c := TH.spawn("ghoul", 240, 120)
	_shot(170, 120, 300, 0, {"pierce": 1})
	for i in 30:
		Bullets.update_player(Consts.DT)
	check(a.hp < a.max_hp and c.hp < c.max_hp, "entrambi colpiti")
	eq(Run.bullets.size(), 0)

func test_schegge_sul_muro() -> void:
	Run.player.stats.split = 1
	_shot(Consts.RX + 20, 120, -600, 0)
	for i in 3:
		Bullets.update_player(Consts.DT)
	eq(Run.bullets.filter(func(b): return b.kind == "shard").size(), 3)

func test_colpo_nemico_e_stato() -> void:
	var p := Run.player
	var hp := p.hp
	Run.ebullets.append({"x": p.x - 20, "y": p.y - 1, "vx": 300.0, "vy": 0.0, "r": 3.0, "dmg": 5.0, "life": 5.0, "kind": "orb",
		"col": "violet", "status": "slow", "src": "Prova", "accel": 0.0, "curve": 0.0, "t": 0.0, "big": false})
	for i in 10:
		Bullets.update_enemy(Consts.DT)
	check(p.hp < hp)
	check(p.statuses.has("slow"))
	eq(Run.ebullets.size(), 0)

func test_colpi_fantasma_escono_dal_bordo() -> void:
	Run.ebullets.append({"x": Consts.RX + 20.0, "y": 60.0, "vx": -600.0, "vy": 0.0, "r": 3.0, "dmg": 5.0, "life": 5.0, "kind": "orb",
		"col": "red", "status": null, "src": "Prova", "accel": 0.0, "curve": 0.0, "t": 0.0, "big": false, "ghost": true})
	for i in 5:
		Bullets.update_enemy(Consts.DT)
	eq(Run.ebullets.size(), 0)
