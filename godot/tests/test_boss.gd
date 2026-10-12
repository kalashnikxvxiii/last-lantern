extends TestCase
# The Bone Warden (and the stats of all the wardens): stats, phases, patterns, death and trapdoor.

var b: Boss

func before() -> void:
	TH.new_run(61)
	TH.arena()
	Run.player.inv = 99.0
	b = Boss.make_boss("bones", 240, 100)
	Run.add_enemy(b)

func after() -> void:
	Run.reset()

func test_stats_like_the_js() -> void:
	for c in TestCase.golden("enemies").bosses:
		Run.depth = int(c.depth)
		Run.ardor = int(c.ardor)
		var x := Boss.make_boss(c.id, 0, 0)
		eq({"hp": x.hp, "maxHp": x.max_hp, "spd": x.spd, "dmg": x.dmg, "xp": x.xp, "r": x.r}, c.fields)
		x.free()

func test_phase_change() -> void:
	b.hp = b.max_hp * 0.49
	Enemy.update_all(Consts.DT)
	eq(b.phase, 1)
	near(b.invuln, 1.4 - Consts.DT, 1e-9)
	eq(Run.ebullets.size(), 20)
	var hp := b.hp
	Combat.hit_enemy(b, 50)
	eq(b.hp, hp, "invulnerable during the change")

func test_ring() -> void:
	b.pat = {"s": {"p": "ring", "n": 12, "count": 2, "gap": 0.7, "spd": 75.0, "kind": "bone"}, "t": 0.0}
	Enemy.update_all(Consts.DT)
	for i in int(0.45 / Consts.DT):
		Enemy.update_all(Consts.DT)
	eq(Run.ebullets.size(), 12, "first volley after 0.4 s")
	for i in int(1.0 / Consts.DT):
		Enemy.update_all(Consts.DT)
	eq(b.pat.k, 2, "second volley after another 0.7 s")

func test_summon_respects_the_cap() -> void:
	b.pat = {"s": {"p": "summon", "type": "skeleton", "count": 2, "cap": 4}, "t": 0.0}
	Enemy.update_all(Consts.DT)
	eq(Run.fx.filter(func(f): return f.type == "spawn").size(), 2)

func test_death_and_trapdoor() -> void:
	var kills: int = Save.data.stats.bossKills
	Combat.hit_enemy(b, 99999)
	check(b.dying != null)
	for i in int(2.1 / Consts.DT):
		Enemy.update_all(Consts.DT)
	check(Run.enemies.is_empty(), "the boss died and was removed")
	eq(Save.data.stats.bossKills, kills + 1)
	check(Run.room.objects.any(func(o): return o.type == "trapdoor"))
	check(Run.room.cleared)
