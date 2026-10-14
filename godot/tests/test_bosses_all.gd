extends TestCase
# The patterns and wardens of all the depths.

func before() -> void:
	TH.new_run(62)
	TH.arena()
	Run.player.inv = 99.0

func after() -> void:
	Run.reset()

func _boss(id: String) -> Boss:
	var b := Boss.make_boss(id, 240, 100)
	Run.add_enemy(b)
	Run.boss_ref = b
	return b

func _tick(n: int) -> void:
	for i in n:
		Enemy.update_all(Consts.DT)
		Bullets.update_enemy(Consts.DT)
		Effects.update(Consts.DT)

func test_each_boss_plays_every_pattern() -> void:
	for id in ["bones", "mycel", "forge", "abyss", "devourer"]:
		var def := DB.boss(id)
		check(def != null, id + " exists")
		for ph in def.phases.size():
			for s in def.phases[ph].pats:
				Run.clear_enemies()
				Run.ebullets = []
				Run.fx = []
				var b := _boss(id)
				b.pat = {"s": s, "t": 0.0}
				var done := false
				for i in int(12.0 / Consts.DT):
					_tick(1)
					if b.pat == null:
						done = true
						break
				check(done, "%s phase %d %s ends" % [id, ph, s.p])
				check(is_finite(b.x) and is_finite(b.y), "%s %s position" % [id, s.p])
				b.free()

func test_slam_leaves_a_shockwave() -> void:
	var b := _boss("forge")
	b.pat = {"s": {"p": "slam", "count": 1, "ring": 12, "kind": "fire", "status": "burn"}, "t": 0.0}
	var shock := false
	var airborne := false
	for i in int(4.0 / Consts.DT):
		_tick(1)
		airborne = airborne or b.z > 20
		shock = shock or Run.fx.any(func(f): return f.type == "shockwave")
	check(airborne and shock)
	eq(b.z, 0.0)

func test_the_forger_slams_a_shorter_wave() -> void:
	var b := _boss("forge")
	Run.fx = []
	b.pat = {"s": b.B.phases[0].pats[0], "t": 0.0}
	var wave: Dictionary = {}
	for i in int(4.0 / Consts.DT):
		_tick(1)
		if wave.is_empty():
			for f in Run.fx:
				if f.type == "shockwave":
					wave = f
					break
	check(not wave.is_empty(), "the slam leaves a shockwave")
	near(wave.maxR, 100.0)
	Run.clear_enemies()
	var d := _boss("devourer")
	Run.fx = []
	d.pat = {"s": {"p": "slam", "count": 1, "ring": 20, "kind": "void"}, "t": 0.0}
	var other: Dictionary = {}
	for i in int(4.0 / Consts.DT):
		_tick(1)
		if other.is_empty():
			for f in Run.fx:
				if f.type == "shockwave":
					other = f
					break
	check(not other.is_empty(), "the last boss slams too")
	near(other.maxR, 130.0)
	Run.clear_enemies()

func test_beam_hurts_the_player_in_its_path() -> void:
	var b := _boss("abyss")
	var p := Run.player
	p.inv = 0.0
	p.guard_t = 0.0
	b.x = p.x - 100
	b.y = p.y
	b.pat = {"s": {"p": "beam", "count": 1, "warm": 0.1, "dur": 1.0, "rot": 0.0}, "t": 0.0}
	var beam: Dictionary = {}
	Run.fx = []
	Enemy.update_all(Consts.DT)
	beam = Run.fx.filter(func(f): return f.type == "beam")[0]
	beam.ang = U.ang_to(b.x, b.y, p.x, p.y)
	var hp := p.hp
	_tick(30)
	check(p.hp < hp)

func test_drain_pulls_and_costs_oil() -> void:
	var b := _boss("devourer")
	var p := Run.player
	var oil := p.oil
	b.pat = {"s": {"p": "drain", "dur": 1.0}, "t": 0.0}
	_tick(20)
	check(Run.pull != null)
	check(p.oil < oil)
	_tick(60)
	check(Run.pull == null)

func test_darkpulse_blinds() -> void:
	var b := _boss("devourer")
	b.pat = {"s": {"p": "darkpulse"}, "t": 0.0}
	_tick(60)
	check(Run.player.statuses.has("blind"))

func test_wall_has_a_gap() -> void:
	var b := _boss("abyss")
	b.pat = {"s": {"p": "wall", "count": 1, "kind": "ice", "status": "chill"}, "t": 0.0}
	_tick(30)
	var n := Run.ebullets.filter(func(x): return x.get("ghost", false)).size()
	check(n == 9 or n == 23, "wall of %d" % n)

func test_the_last_boss_has_three_phases() -> void:
	var b := _boss("devourer")
	b.hp = b.max_hp * 0.6
	_tick(1)
	eq(b.phase, 1)
	b.invuln = 0.0
	b.hp = b.max_hp * 0.3
	_tick(1)
	eq(b.phase, 2)

func test_defeating_the_devourer_wins() -> void:
	Run.depth = 5
	var b := _boss("devourer")
	Combat.hit_enemy(b, 999999)
	_tick(int(2.2 / Consts.DT))
	check(Run.won)
	check(Run.victory_t > 0.0)
	check(not Run.room.objects.any(func(o): return o.type == "trapdoor"), "no trapdoor on the first victory")
