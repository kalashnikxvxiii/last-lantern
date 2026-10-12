extends TestCase
# Damage to player and enemies, death and revival, kills and rewards, destructible tiles.

func before() -> void:
	TH.new_run(5)
	TH.arena()
	Run.player.inv = 0.0

func after() -> void:
	Run.reset()

func test_invulnerability_and_dash() -> void:
	var p := Run.player
	p.inv = 0.5
	check(not Combat.hurt_player(10, "x"))
	p.inv = 0.0
	p.dash_t = 0.1
	check(not Combat.hurt_player(10, "x"))
	p.dash_t = 0.0
	check(Combat.hurt_player(10, "x"))
	eq(p.inv, p.stats.iframes)
	eq(p.last_hit, "x")

func test_warden_light_shield() -> void:
	var p := Run.player
	p.guard_up = true
	check(not Combat.hurt_player(10, "x"))
	check(not p.guard_up)
	eq(p.guard_t, 10.0)

func test_ash_armor() -> void:
	Run.player.stats.ashguard = 1
	Combat.hurt_player(10, "x")
	eq(Run.fx.filter(func(f): return f.type == "shockwave").size(), 1)

func test_last_breath_then_coffin_then_feather_then_death() -> void:
	var p := Run.player
	p.stats.secondwind = 1
	p.stats.revive = 1
	p.cons[2] = {"id": "feather", "n": 1}
	for expected in [1.0, 30.0, 30.0]:
		p.inv = 0.0
		Combat.hurt_player(999, "x")
		eq(p.hp, expected)
		check(not p.dead)
	p.inv = 0.0
	Combat.hurt_player(999, "x")
	check(p.dead)
	eq(p.cons[2], null)

func test_armored_and_frozen_enemy() -> void:
	var e := TH.spawn("ghoul", 300, 120, "armored")
	var hp := e.hp
	Combat.hit_enemy(e, 10)
	near(e.hp, hp - 7)
	e.frozen = 1.0
	Combat.hit_enemy(e, 10)
	near(e.hp, hp - 7 - 10 * 0.7 * 1.15)

func test_kill_and_rewards() -> void:
	var e := TH.spawn("skeleton", 300, 120)
	var oil := Run.player.oil
	Run.player.oil = 10
	Combat.hit_enemy(e, 9999)
	check(e.dead)
	eq(Run.kills, 1)
	var xp: Array = Run.room.pickups.filter(func(k): return k.type == "xp")
	eq(xp.size(), int(clampf(U.jround(e.xp / 2), 1, 8)))
	near(Run.player.oil, 12.5)
	Run.player.oil = oil

func test_splitting_spawns_two_small() -> void:
	var e := TH.spawn("ghoul", 300, 120, "splitter")
	Combat.kill_enemy(e)
	var small: Array = Run.enemies.filter(func(x): return not x.dead)
	eq(small.size(), 2)
	check(small[0].no_split)

func test_volatile_fires_eight_shots() -> void:
	var e := TH.spawn("ghoul", 300, 120, "volatile")
	Combat.kill_enemy(e)
	eq(Run.ebullets.size(), 8)

func test_barrel_and_urn() -> void:
	var room := Run.room
	room.grid[5][5] = Consts.T.BARREL
	room.tileHp[5 * Consts.RW + 5] = 18
	Combat.damage_tile(5, 5, 10)
	eq(room.grid[5][5], Consts.T.BARREL)
	Combat.damage_tile(5, 5, 10)
	eq(room.grid[5][5], Consts.T.FLOOR)
	eq(Run.fx.back().type, "explosion")
	room.grid[6][6] = Consts.T.URN
	Combat.damage_tile(6, 6, 1)
	eq(room.grid[6][6], Consts.T.FLOOR)
