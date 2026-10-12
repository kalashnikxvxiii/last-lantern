extends TestCase
# IA delle Cripte, separazione, contatto, rimozione dei morti.

func before() -> void:
	TH.new_run(31)
	var room := TH.arena()
	for ty in range(1, Consts.RH - 1):
		for tx in range(1, Consts.RW - 1):
			room.grid[ty][tx] = Consts.T.FLOOR
	FlowField.update()

func after() -> void:
	Run.reset()

func _run(seconds: float) -> void:
	for i in int(seconds / Consts.DT):
		Enemy.update_all(Consts.DT)

func test_il_ratto_insegue() -> void:
	var p := Run.player
	var e := TH.spawn("rat", p.x + 150, p.y)
	var d0 := U.dist(e.x, e.y, p.x, p.y)
	p.inv = 99.0
	_run(1.0)
	check(U.dist(e.x, e.y, p.x, p.y) < d0 - 40)

func test_il_ghoul_carica() -> void:
	var p := Run.player
	p.inv = 99.0
	var e := TH.spawn("ghoul", p.x + 100, p.y)
	var seen := {}
	for i in 240:
		Enemy.update_all(Consts.DT)
		seen[e.state] = true
	for s in ["approach", "wind", "charge", "recover"]:
		check(seen.has(s), "stato " + s)

func test_lo_scheletro_tira_ossa() -> void:
	var p := Run.player
	p.inv = 99.0
	var e := TH.spawn("skeleton", p.x + 120, p.y)
	e.shot_cd = 0.0
	_run(0.5)
	var bones := Run.ebullets.filter(func(b): return b.kind == "bone")
	eq(bones.size(), 1)

func test_il_teschio_spara_ad_anello() -> void:
	var p := Run.player
	p.inv = 99.0
	var e := TH.spawn("skull", p.x + 100, p.y)
	e.shot_cd = 0.0
	_run(0.6)
	eq(Run.ebullets.size(), 6)

func test_separazione() -> void:
	var a := TH.spawn("rat", 200, 100)
	var b := TH.spawn("rat", 200.5, 100)
	a.stun = 1.0
	b.stun = 1.0
	Enemy.update_all(Consts.DT)
	check(U.dist(a.x, a.y, b.x, b.y) > 1.0)

func test_contatto_e_morti_rimossi() -> void:
	var p := Run.player
	p.inv = 0.0
	var e := TH.spawn("rat", p.x + 3, p.y)
	var hp := p.hp
	Enemy.update_all(Consts.DT)
	check(p.hp < hp)
	e.dead = true
	Enemy.update_all(Consts.DT)
	eq(Run.enemies.size(), 0)
