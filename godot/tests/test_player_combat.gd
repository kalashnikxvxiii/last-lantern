extends TestCase
# Shooting, Flare, reflection, fireflies, sun, storm, spikes, oil, shield.

var p: Player

func before() -> void:
	TH.new_run(21)
	var room := TH.arena()
	for ty in range(1, Consts.RH - 1):
		for tx in range(1, Consts.RW - 1):
			room.grid[ty][tx] = Consts.T.FLOOR
	p = Run.player
	p.inv = 0.0
	p.stats.crit = 0.0

func after() -> void:
	Controls.sim.clear()
	Run.reset()

func test_volley_and_fan() -> void:
	p.stats.proj = 3
	p.fire_volley(0.0)
	eq(Run.bullets.size(), 3)
	var a0 := atan2(Run.bullets[0].vy, Run.bullets[0].vx)
	var a2 := atan2(Run.bullets[2].vy, Run.bullets[2].vx)
	near(a2 - a0, 0.26, 0.08, "spread 0.13 per extra projectile (plus the flicker)")
	near(Run.bullets[1].dmg, p.damage())

func test_crit() -> void:
	p.stats.crit = 1.0
	p.fire_volley(0.0)
	near(Run.bullets[0].dmg, p.damage() * p.stats.critMult)
	check(Run.bullets[0].crit)

func test_comet_every_six_shots() -> void:
	p.stats.comet = 1
	for i in 6:
		p.fire_volley(0.0)
	eq(Run.bullets.filter(func(b): return b.kind == "comet").size(), 1)

func test_shooting_while_held() -> void:
	Controls.sim = {"fire": true, "device": "mouse", "mouse": Vector2(p.x + 50, p.y - 4)}
	p.fire_cd = 0.0
	p.tick(Consts.DT)
	eq(Run.bullets.size(), 1)
	near(p.fire_cd, 1.0 / p.fire_rate())

func test_flare() -> void:
	var e := TH.spawn("ghoul", p.x + 40, p.y)
	Run.ebullets.append({"x": p.x + 20, "y": p.y, "vx": 0.0, "vy": 0.0, "r": 3.0, "dmg": 5.0, "life": 5.0, "kind": "orb",
		"col": "red", "status": null, "src": "x", "accel": 0.0, "curve": 0.0, "t": 0.0, "big": false})
	p.oil = 100.0
	p.try_flare()
	near(p.oil, 100.0 - p.stats.flareCost)
	check(e.hp < e.max_hp)
	check(e.statuses.has("burn"))
	check(Run.ebullets[0].get("dead", false))
	near(p.flare_cd, 0.9)

func test_flare_without_oil() -> void:
	p.oil = 5.0
	p.try_flare()
	eq(p.oil, 5.0)
	near(p.flare_cd, 0.4)

func test_fireflies() -> void:
	p.stats.orbit = 2
	var pos := p.orbital_positions()
	eq(pos.size(), 2)
	near(pos[0].distance_to(Vector2(p.x, p.y - 2)), 22.0, 1e-4)
	var e := TH.spawn("ghoul", pos[0].x, pos[0].y)
	p.update_orbitals(Consts.DT)
	check(e.hp < e.max_hp)
	near(e.orb_cd, 0.35)

func test_storm() -> void:
	p.stats.storm = 1
	var e := TH.spawn("ghoul", p.x + 100, p.y)
	for i in 181:
		p.tick(Consts.DT)
	check(e.hp < e.max_hp, "one lightning bolt every 3 seconds")
	eq(Run.fx.filter(func(f): return f.type == "bolt").size(), 1)

func test_oil_burns_in_combat() -> void:
	p.oil = 50.0
	for i in 60:
		p.tick(Consts.DT)
	near(p.oil, 50.0 - 1.05, 1e-6)

func test_spikes() -> void:
	var t := RoomU.world_to_tile(p.x, p.y + 2)
	Run.room.grid[t.y][t.x] = Consts.T.SPIKE
	Run.room.spikeT = 2.5
	var hp := p.hp
	p.tick(Consts.DT)
	eq(p.hp, hp - p.damage_taken(8 * Stats.depth_dmg(1)))

func test_warden_light_shield_recharges() -> void:
	p.stats.guardian = 1
	p.guard_t = 0.1
	for i in 7:
		p.tick(Consts.DT)
	check(p.guard_up)

func test_reflective_dash() -> void:
	p.stats.dashReflect = 1
	Run.ebullets.append({"x": p.x + 10, "y": p.y, "vx": -50.0, "vy": 0.0, "r": 3.0, "dmg": 5.0, "life": 5.0, "kind": "orb",
		"col": "red", "status": null, "src": "x", "accel": 0.0, "curve": 0.0, "t": 0.0, "big": false})
	Controls.sim = {"pressed": ["dash"], "move": Vector2(1, 0)}
	p.tick(Consts.DT)
	check(Run.ebullets[0].get("dead", false))
	eq(Run.bullets.size(), 1)
	check(Run.bullets[0].vx > 0, "sent back")

func test_range_as_float() -> void:
	# range and shotSpeed are integers in the base stats: the duration must not become 0
	p.fire_volley(0.0)
	near(Run.bullets[0].life, 200.0 / 230.0)
	p.stats.comet = 1
	for i in 5:
		p.fire_volley(0.0)
	var c: Dictionary = Run.bullets.filter(func(b): return b.kind == "comet")[0]
	near(c.life, 200.0 * 1.4 / 230.0)
