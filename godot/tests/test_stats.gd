extends TestCase
# recalcStats, pDamage, pFireRate, pSpeed, pLight, rollPerkChoices e formule: confronto con il JS.

func after() -> void:
	Run.reset()

func _player(c: Dictionary) -> Player:
	Run.reset()
	Run.active = true
	Run.ardore = int(c.get("ardore", 0))
	var p := Player.new()
	p.lantern = c.get("lantern", "custode")
	for k in c.get("perks", {}):
		p.perks[k] = int(c.perks[k])
	p.relics = Array(c.get("relics", []))
	p.curses = Array(c.get("curses", []))
	p.base_hp_mod = c.get("baseHpMod", 0.0)
	p.hp = 9999
	p.oil = 9999
	p.dash_charges = 99
	Run.player = p
	p.recalc_stats()
	return p

func test_statistiche_come_il_js() -> void:
	for c in TestCase.golden("stats").cases:
		var p := _player(c)
		var d := TestCase.diff(p.stats, c.stats, "stats")
		if d != "":
			fail("%s %s %s %s: %s" % [c.lantern, c.perks, c.relics, c.curses, d])
			return
		for dv in c.derived:
			p.statuses = {}
			for k in dv.statuses:
				p.statuses[k] = {"t": 1.0, "stacks": 1, "tick": 0.0, "power": 0.0}
			p.hp = p.stats.maxHp * dv.hpFrac
			p.oil = p.stats.maxOil * dv.oilFrac
			near(p.damage(), dv.damage, 1e-9, "damage %s" % [dv])
			near(p.fire_rate(), dv.fireRate, 1e-9, "fireRate %s" % [dv])
			near(p.speed(), dv.speed, 1e-9, "speed %s" % [dv])
			near(p.light(), dv.light, 1e-9, "light %s" % [dv])

func test_scelta_dei_doni_come_il_js() -> void:
	for c in TestCase.golden("stats").perkRolls:
		var p := _player({"perks": c.perks, "relics": c.relics})
		Run.depth = int(c.depth)
		U.seed_random(int(c.seed))
		eq(Perks.roll_choices(int(c.n), int(c.minRar)), c.out, "seme %d" % c.seed)

func test_formule() -> void:
	var f: Dictionary = TestCase.golden("formulas")
	for c in f.xpNeed:
		eq(Stats.xp_need(int(c[0])), c[1])
	for c in f.depthHp:
		eq(Stats.depth_hp(int(c[0])), c[1])
	for c in f.depthDmg:
		eq(Stats.depth_dmg(int(c[0])), c[1])
	var p := _player({})
	for c in f.hurt:
		p.stats.dmgTaken = c[1]
		p.stats.armor = c[2]
		p.statuses = {"fragile": {"t": 1.0}} if c[3] else {}
		p.oil = 0.0 if c[4] else 50.0
		eq(p.damage_taken(c[0]), c[5], "hurt %s" % [c])
