extends TestCase
# makeEnemy: stats scaled by depth, elites and small versions as in the JS.

func after() -> void:
	Run.reset()

func test_enemies_like_the_js() -> void:
	for c in TestCase.golden("enemies").enemies:
		U.seed_random(int(c.seed))
		Run.reset()
		Run.active = true
		Run.depth = int(c.depth)
		Run.player = Player.new()
		Run.player.recalc_stats()
		var e := Enemy.make(c.type, 100, 100, c.mod, {"small": true} if c.small else {})
		var got := {"hp": e.hp, "maxHp": e.max_hp, "spd": e.spd, "dmg": e.dmg, "xp": e.xp, "r": e.r, "fly": e.fly,
			"shotCd": e.shot_cd, "anim": e.anim, "t": e.t, "stun": e.stun, "elite": e.elite, "mod": e.mod}
		var d := TestCase.diff(got, c.fields, "")
		e.free()
		if d != "":
			fail("%s depth %d %s %s: %s" % [c.type, c.depth, c.mod, c.small, d])
			return
