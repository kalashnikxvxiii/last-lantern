extends TestCase
# AI of the enemies of the other depths: turret, hopper, shielder, kamikaze, phaser,
# dasher, teleporter, summoner, spinner.

func before() -> void:
	TH.new_run(32)
	var room := TH.arena()
	for ty in range(1, Consts.RH - 1):
		for tx in range(1, Consts.RW - 1):
			room.grid[ty][tx] = Consts.T.FLOOR
	FlowField.update()
	Run.player.inv = 99.0

func after() -> void:
	Run.reset()

func _run(seconds: float) -> void:
	for i in int(seconds / Consts.DT):
		Enemy.update_all(Consts.DT)
		Bullets.update_enemy(Consts.DT)
		Effects.update(Consts.DT)

func _states(e: Enemy, seconds: float) -> Dictionary:
	var seen := {}
	for i in int(seconds / Consts.DT):
		Enemy.update_all(Consts.DT)
		Effects.update(Consts.DT)
		seen[e.state] = true
	return seen

func test_every_enemy_type_runs() -> void:
	var p := Run.player
	for id in ["rat", "bat", "skeleton", "skull", "ghoul", "grub", "grubling", "spore", "hopper", "moth", "automaton", "turret",
			"slag", "smith", "spark", "drowned", "eel", "jelly", "shade", "cultist", "wisp", "knight", "eye"]:
		Run.clear_enemies()
		Run.ebullets = []
		Run.fx = []
		var e := TH.spawn(id, p.x + 90, p.y - 20)
		_run(8.0)
		check(not is_instance_valid(e) or (is_finite(e.x) and is_finite(e.y)), id + " position")
		if is_instance_valid(e):
			Combat.hit_enemy(e, 99999)

func test_the_turret_does_not_move_and_shoots_a_burst() -> void:
	var p := Run.player
	var e := TH.spawn("turret", p.x + 100, p.y)
	e.shot_cd = 0.0
	_run(1.0)
	eq(e.x, p.x + 100)
	check(Run.ebullets.size() >= 1)

func test_the_hopper_jumps_and_lands() -> void:
	var p := Run.player
	var e := TH.spawn("hopper", p.x + 100, p.y)
	var seen := {}
	var maxz := 0.0
	for i in int(4.0 / Consts.DT):
		Enemy.update_all(Consts.DT)
		seen[e.state] = true
		maxz = maxf(maxz, e.z)
	check(seen.has("jump"))
	check(maxz > 20.0, "arc of the jump")
	check(U.dist(e.x, e.y, p.x, p.y) < 100.0)

func test_the_smith_lunges_the_knight_slams() -> void:
	var p := Run.player
	var s := TH.spawn("smith", p.x + 60, p.y)
	var seen := _states(s, 5.0)
	for st in ["wind", "lunge", "rest"]:
		check(seen.has(st), "smith " + st)
	Run.clear_enemies()
	var k := TH.spawn("knight", p.x + 60, p.y)
	var seen2 := _states(k, 5.0)
	check(seen2.has("wind") and seen2.has("rest"))
	check(not seen2.has("lunge"))

func test_the_spark_explodes() -> void:
	var p := Run.player
	var e := TH.spawn("spark", p.x + 40, p.y)
	var fuse := false
	for i in int(2.0 / Consts.DT):
		if not is_instance_valid(e):
			break
		Enemy.update_all(Consts.DT)
		Effects.update(Consts.DT)
		fuse = fuse or (is_instance_valid(e) and e.state == "fuse")
	check(fuse)
	check(not is_instance_valid(e) or e.dead)

func test_the_drowned_phases_in_and_out() -> void:
	var p := Run.player
	var e := TH.spawn("drowned", p.x + 150, p.y)
	var intangible := false
	var solid := false
	for i in int(5.0 / Consts.DT):
		Enemy.update_all(Consts.DT)
		intangible = intangible or e.intangible
		solid = solid or (not e.intangible and e.alpha == 1.0)
	check(intangible and solid)
	e.intangible = true
	var hp := e.hp
	Combat.hit_enemy(e, 5)
	eq(e.hp, hp, "intangible")

func test_the_eel_dashes() -> void:
	var p := Run.player
	var e := TH.spawn("eel", p.x + 100, p.y)
	var seen := _states(e, 3.0)
	check(seen.has("aim") and seen.has("dash"))

func test_the_shade_teleports_and_shoots_a_fan() -> void:
	var p := Run.player
	var e := TH.spawn("shade", p.x + 200, p.y)
	var seen := {}
	var most := 0
	for i in int(5.0 / Consts.DT):
		Enemy.update_all(Consts.DT)
		Bullets.update_enemy(Consts.DT)
		seen[e.state] = true
		most = maxi(most, Run.ebullets.size())
	for st in ["hidden", "appear", "attack", "linger", "vanish"]:
		check(seen.has(st), "shade " + st)
	check(most >= 5, "fan of 5")

func test_the_cultist_summons_flames() -> void:
	var p := Run.player
	var e := TH.spawn("cultist", p.x + 100, p.y)
	_run(4.0)
	var wisps := Run.enemies.filter(func(x): return x.type == "wisp" and is_same(x.summoner, e))
	eq(wisps.size(), 2)
	_run(6.5)
	check(Run.enemies.filter(func(x): return x.type == "wisp" and is_same(x.summoner, e)).size() <= 3, "cap of 3")

func test_the_eye_fires_spirals() -> void:
	var p := Run.player
	var e := TH.spawn("eye", p.x + 90, p.y)
	_run(1.0)
	eq(Run.ebullets.size(), 0, "silent in the first second")
	_run(1.5)
	check(Run.ebullets.size() >= 3)
	check(Run.ebullets.all(func(b): return b.status == "fragile"))
	e.dead = true

func test_the_grub_splits_and_the_spore_leaves_a_cloud() -> void:
	var g := TH.spawn("grub", 200, 100)
	Combat.hit_enemy(g, 9999)
	eq(Run.enemies.filter(func(x): return x.type == "grubling" and not x.dead).size(), 2)
	Run.clear_enemies()
	var s := TH.spawn("spore", 200, 100)
	Combat.hit_enemy(s, 9999)
	check(Run.fx.any(func(f): return f.type == "cloud"))

func test_the_slag_leaves_fire() -> void:
	var p := Run.player
	TH.spawn("slag", p.x + 90, p.y)
	_run(1.5)
	check(Run.fx.any(func(f): return f.type == "fire"))
