class_name AI
extends RefCounted
# Enemy behaviors (AI in js/entities.js). Common signature: (e, dt, tg, m),
# with tg the target ({x, y} or the player) and m the speed multiplier.

static func run(e: Enemy, dt: float, tg, m: float) -> void:
	match e.ai:
		"chaser": chaser(e, dt, tg, m)
		"erratic": erratic(e, dt, tg, m)
		"shooter": shooter(e, dt, tg, m)
		"caster": caster(e, dt, tg, m)
		"charger": charger(e, dt, tg, m)
		"turret": turret(e, dt, tg, m)
		"hopper": hopper(e, dt, tg, m)
		"shielder": shielder(e, dt, tg, m)
		"kamikaze": kamikaze(e, dt, tg, m)
		"phaser": phaser(e, dt, tg, m)
		"dasher": dasher(e, dt, tg, m)
		"teleporter": teleporter(e, dt, tg, m)
		"summoner": summoner(e, dt, tg, m)
		"spinner": spinner(e, dt, tg, m)

static func chaser(e: Enemy, dt: float, tg, m: float) -> void:
	var go := true
	if e.def.burst:
		e.t += dt
		go = fmod(e.t, 1.2) < 0.85
	var a: float = U.ang_to(e.x, e.y, tg.x, tg.y) if e.fly else FlowField.angle(e, tg.x, tg.y)
	var sp: float = e.spd * m if go else 0.0
	e.vx = cos(a) * sp
	e.vy = sin(a) * sp
	if e.def.trail:
		e.trail_t -= dt
		if e.trail_t <= 0:
			e.trail_t = 0.35
			Effects.add({"type": "fire", "x": e.x, "y": e.y + 3, "r": 7.0, "life": 2.6, "owner": "enemy", "dmg": e.dmg * 0.5})

static func erratic(e: Enemy, dt: float, tg, m: float) -> void:
	e.t += dt
	if e.jit == null or e.jit_t <= 0:
		e.jit = U.rnd(-1.4, 1.4)
		e.jit_t = U.rnd(0.3, 0.7)
	e.jit_t -= dt
	var a: float = U.ang_to(e.x, e.y, tg.x, tg.y) + e.jit + sin(e.t * 5) * 0.6
	var d := U.dist(e.x, e.y, tg.x, tg.y)
	var has_shot := not e.def.shot.is_empty()
	var sp: float = e.spd * m * (-0.6 if has_shot and d < 60 else 1.0)
	e.vx = cos(a) * sp
	e.vy = sin(a) * sp
	if has_shot:
		shooter_fire(e, dt, tg)

static func shooter(e: Enemy, dt: float, tg, m: float) -> void:
	var d := U.dist(e.x, e.y, tg.x, tg.y)
	var a := FlowField.angle(e, tg.x, tg.y)
	var sp: float = e.spd * m
	if d < 70 and Coll.line_clear(e.x, e.y, tg.x, tg.y):
		a = U.ang_to(tg.x, tg.y, e.x, e.y)
		sp *= 0.8
	if e.wind > 0:
		sp = 0.0
	e.vx = cos(a) * sp
	e.vy = sin(a) * sp
	shooter_fire(e, dt, tg)

static func caster(e: Enemy, dt: float, tg, m: float) -> void:
	var d := U.dist(e.x, e.y, tg.x, tg.y)
	var keep: float = e.def.keep if e.def.keep else 90.0
	var a := U.ang_to(e.x, e.y, tg.x, tg.y)
	var sp: float = e.spd * m
	if d < keep - 20:
		a += PI
	elif d < keep + 30:
		if e.orbit_dir == 0:
			e.orbit_dir = 1 if U.chance(0.5) else -1
		a += PI / 2 * e.orbit_dir
	if e.wind > 0:
		sp *= 0.2
	e.vx = cos(a) * sp
	e.vy = sin(a) * sp
	shooter_fire(e, dt, tg)

static func charger(e: Enemy, dt: float, tg, m: float) -> void:
	e.st += dt
	match e.state:
		"idle", "approach":
			e.state = "approach"
			var a := FlowField.angle(e, tg.x, tg.y)
			e.vx = cos(a) * e.spd * m
			e.vy = sin(a) * e.spd * m
			var d := U.dist(e.x, e.y, tg.x, tg.y)
			if e.st > 1.0 and d < 130 and Coll.line_clear(e.x, e.y, tg.x, tg.y):
				e.state = "wind"
				e.st = 0.0
				e.charge_a = U.ang_to(e.x, e.y, tg.x, tg.y)
		"wind":
			e.vx = 0.0
			e.vy = 0.0
			e.charge_a = e.charge_a + clampf(U.ang_diff(e.charge_a, U.ang_to(e.x, e.y, tg.x, tg.y)), -2 * dt, 2 * dt)
			e.wind = 0.55 - e.st
			if e.st > 0.55:
				e.state = "charge"
				e.st = 0.0
				Sfx.play("dash", 0.6)
		"charge":
			var sp: float = e.def.charge_spd * m * (1.2 if e.mod == "swift" else 1.0)
			e.vx = cos(e.charge_a) * sp
			e.vy = sin(e.charge_a) * sp
			if U.random() < 0.5:
				Particles.add({"x": e.x, "y": e.y + 4, "life": 0.3, "color": "#55505e", "size": 2})
			if e.hit_wall or e.st > 0.85:
				e.state = "recover"
				e.st = 0.0
				if e.hit_wall:
					Fx.shake(2)
					Sfx.play("thud", 0.5)
		"recover":
			e.vx = 0.0
			e.vy = 0.0
			if e.st > 0.7:
				e.state = "approach"
				e.st = 0.0

static func turret(e: Enemy, dt: float, tg, _m: float) -> void:
	e.vx = 0.0
	e.vy = 0.0
	shooter_fire(e, dt, tg)

static func hopper(e: Enemy, dt: float, tg, _m: float) -> void:
	e.st += dt
	if e.state == "idle":
		e.vx = 0.0
		e.vy = 0.0
		var cd: float = e.def.hop_cd if e.def.hop_cd else 1.6
		if e.st > cd * (0.7 if e.mod == "swift" else 1.0):
			e.state = "jump"
			e.st = 0.0
			var a := U.ang_to(e.x, e.y, tg.x, tg.y)
			var d := minf(95, U.dist(e.x, e.y, tg.x, tg.y))
			e.jx0 = e.x
			e.jy0 = e.y
			e.jx1 = e.x + cos(a) * d
			e.jy1 = e.y + sin(a) * d
	elif e.state == "jump":
		var T := 0.6
		var k := minf(1, e.st / T)
		var nx := lerpf(e.jx0, e.jx1, k)
		var ny := lerpf(e.jy0, e.jy1, k)
		e.vx = (nx - e.x) / dt
		e.vy = (ny - e.y) / dt
		e.z = sin(k * PI) * 26
		if k >= 1:
			e.z = 0.0
			e.state = "idle"
			e.st = 0.0
			e.vx = 0.0
			e.vy = 0.0
			Fx.shake(1.5)
			Sfx.play("thud", 0.4)
			Particles.burst(e.x, e.y + 4, 8, ["#55505e", "#3b3546"], 50, 0.4)
			var n: int = e.def.land_ring + (2 if Run.depth >= 3 else 0)
			if n and Run.depth >= 2:
				var off := U.rnd(TAU)
				for i in n:
					Bullets.e_shoot(e, off + i * TAU / n, 70, {"kind": "spore", "status": "poison" if e.mod == "venom" else null})

static func shielder(e: Enemy, dt: float, tg, m: float) -> void:
	var ta := U.ang_to(e.x, e.y, tg.x, tg.y)
	e.st += dt
	var d := U.dist(e.x, e.y, tg.x, tg.y)
	if e.state == "wind":
		# charges the shot: the shield drops
		e.vx = 0.0
		e.vy = 0.0
		e.wind = 0.6 - e.st
		e.shield_down = true
		if e.st > 0.6:
			e.st = 0.0
			if e.def.slam:
				e.state = "rest"
				Effects.add({"type": "shockwave", "x": e.x, "y": e.y, "r": 4.0, "maxR": 90.0, "spd": 150.0, "owner": "enemy", "dmg": e.dmg * 0.8, "src": e.display_name})
				Fx.shake(3)
				Sfx.play("thud")
			else:
				e.state = "lunge"
				e.lunge_a = ta
				Sfx.play("dash", 0.5)
		return
	if e.state == "lunge":
		e.shield_down = true
		e.vx = cos(e.lunge_a) * 190 * m
		e.vy = sin(e.lunge_a) * 190 * m
		if e.st > 0.35 or e.hit_wall:
			e.state = "rest"
			e.st = 0.0
		return
	if e.state == "rest":
		e.shield_down = true
		e.vx = 0.0
		e.vy = 0.0
		if e.st > 0.7:
			e.state = "idle"
			e.st = 0.0
		return
	e.shield_down = false
	e.facing = e.facing + clampf(U.ang_diff(e.facing, ta), -1.0 * dt, 1.0 * dt)
	if e.st > 2.8 and d < (85.0 if e.def.slam else 95.0):
		e.state = "wind"
		e.st = 0.0
		e.facing = ta
		return
	var a := FlowField.angle(e, tg.x, tg.y)
	e.vx = cos(a) * e.spd * m
	e.vy = sin(a) * e.spd * m

static func kamikaze(e: Enemy, dt: float, tg, m: float) -> void:
	if e.state == "fuse":
		e.st += dt
		e.vx *= 0.9
		e.vy *= 0.9
		e.wind = 0.45 - e.st
		if e.st > 0.45:
			Effects.add({"type": "explosion", "x": e.x, "y": e.y, "r": 26.0, "dmg": e.dmg, "owner": "enemy", "life": 0.35, "src": e.display_name})
			Combat.kill_enemy(e, {"silent": true})
		return
	var d := U.dist(e.x, e.y, tg.x, tg.y)
	var ta := U.ang_to(e.x, e.y, tg.x, tg.y)
	e.ha = ta if e.ha == null else e.ha + clampf(U.ang_diff(e.ha, ta), -3 * dt, 3 * dt)
	e.vx = cos(e.ha) * e.spd * m
	e.vy = sin(e.ha) * e.spd * m
	if d < 22:
		e.state = "fuse"
		e.st = 0.0
		Sfx.play("warn")

const PHASER_CYCLE := [["solid", 2.2], ["fadeout", 0.4], ["phased", 1.6], ["fadein", 0.4]]

static func phaser(e: Enemy, dt: float, tg, m: float) -> void:
	e.st += dt
	var du: float = PHASER_CYCLE[e.ph][1]
	if e.st > du:
		e.st = 0.0
		e.ph = (e.ph + 1) % 4
	var cur: String = PHASER_CYCLE[e.ph][0]
	e.intangible = cur == "phased"
	match cur:
		"solid": e.alpha = 1.0
		"phased": e.alpha = 0.2
		"fadeout": e.alpha = 1 - e.st / 0.4 * 0.8
		_: e.alpha = 0.2 + e.st / 0.4 * 0.8
	var a := U.ang_to(e.x, e.y, tg.x, tg.y)
	var sp: float = e.spd * m * (1.5 if cur == "phased" else 1.0)
	e.vx = cos(a) * sp
	e.vy = sin(a) * sp

static func dasher(e: Enemy, dt: float, tg, m: float) -> void:
	e.st += dt
	match e.state:
		"idle":
			e.vx = sin(e.st * 12) * 10
			e.vy = 0.0
			if e.st > 0.8:
				e.state = "aim"
				e.st = 0.0
		"aim":
			e.vx = 0.0
			e.vy = 0.0
			e.wind = 0.4 - e.st
			e.dash_a = U.ang_to(e.x, e.y, tg.x, tg.y)
			if e.st > 0.4:
				e.state = "dash"
				e.st = 0.0
		"dash":
			var sp: float = 260 * m * (1.2 if e.mod == "swift" else 1.0)
			e.vx = cos(e.dash_a) * sp
			e.vy = sin(e.dash_a) * sp
			if e.st > 0.45 or e.hit_wall:
				e.state = "idle"
				e.st = 0.0

static func teleporter(e: Enemy, dt: float, tg, _m: float) -> void:
	e.st += dt
	e.vx = 0.0
	e.vy = 0.0
	match e.state:
		"idle":
			e.state = "hidden"
			e.st = 0.0
		"hidden":
			e.intangible = true
			e.alpha = 0.0
			if e.st > 1.0:
				var tiles: Array = RoomU.reach_tiles(Run.room).filter(func(t):
					var c := RoomU.tile_center(t.x, t.y)
					var d := U.dist(c.x, c.y, tg.x, tg.y)
					return d > 50 and d < 90)
				if not tiles.is_empty():
					var t: Vector2i = U.pick(tiles)
					var c := RoomU.tile_center(t.x, t.y)
					e.x = c.x
					e.y = c.y
				e.state = "appear"
				e.st = 0.0
				Particles.burst(e.x, e.y, 12, ["#231830", "#d08aff"], 50, 0.5)
		"appear":
			e.alpha = e.st / 0.35
			e.intangible = e.st < 0.2
			if e.st > 0.35:
				e.state = "attack"
				e.st = 0.0
				e.alpha = 1.0
				e.intangible = false
		"attack":
			e.wind = 0.4 - e.st
			if e.st > 0.4:
				var S: Dictionary = e.def.shot
				var a := U.ang_to(e.x, e.y, tg.x, tg.y)
				for i in S.n:
					Bullets.e_shoot(e, a - S.spread / 2 + S.spread * i / (S.n - 1), S.spd, Bullets.shot_opts(e))
				Sfx.play("enemyShoot")
				e.state = "linger"
				e.st = 0.0
		"linger":
			if e.st > 0.9:
				e.state = "vanish"
				e.st = 0.0
		"vanish":
			e.alpha = 1 - e.st / 0.3
			if e.st > 0.3:
				e.state = "hidden"
				e.st = 0.0

static func summoner(e: Enemy, dt: float, tg, m: float) -> void:
	caster(e, dt, tg, m)
	e.sum_t = (2.5 if e.sum_t == null else e.sum_t) - dt
	if e.sum_t <= 0:
		e.sum_t = 5.5
		var mine: int = Run.enemies.filter(func(x): return is_same(x.summoner, e) and not x.dead).size()
		if mine < 3 and Run.enemies.size() < 16:
			for i in 2:
				var a := U.rnd(TAU)
				var x := e.x + cos(a) * 18
				var y := e.y + sin(a) * 18
				Effects.add({"type": "spawn", "x": x, "y": y, "life": 0.6, "spec": {"type": e.def.summon, "summoner": e}})
			e.wind = 0.5

static func spinner(e: Enemy, dt: float, tg, m: float) -> void:
	e.st += dt
	var a := U.ang_to(e.x, e.y, tg.x, tg.y) + PI / 2
	e.vx = cos(a) * e.spd * m
	e.vy = sin(a) * e.spd * m
	var firing := fmod(e.st, 4.0) < 2.4
	if firing and e.st > 1:
		e.spin_a += dt * 2.1
		e.fire_acc += dt
		var S: Dictionary = e.def.shot
		if e.fire_acc > S.cd:
			e.fire_acc = 0.0
			for i in S.arms:
				Bullets.e_shoot(e, e.spin_a + i * TAU / S.arms, S.spd, Bullets.shot_opts(e))
			Sfx.play("enemyShoot", 0.5)
	e.wind = 0.3 if (not firing and fmod(e.st, 4.0) > 3.6) else 0.0

static func shooter_fire(e: Enemy, dt: float, tg) -> void:
	var S: Dictionary = e.def.shot
	if S.is_empty():
		return
	if e.burst_left > 0:
		e.burst_t -= dt
		if e.burst_t <= 0:
			e.burst_t = 0.13
			e.burst_left -= 1
			Bullets.e_shoot(e, U.ang_to(e.x, e.y, tg.x, tg.y), S.spd, Bullets.shot_opts(e))
			Sfx.play("enemyShoot")
		return
	if e.wind > 0:
		e.wind -= dt
		if e.wind <= 0:
			var a := U.ang_to(e.x, e.y, tg.x, tg.y)
			var o := Bullets.shot_opts(e)
			if S.get("ring", 0):
				var off := U.rnd(TAU)
				for i in S.ring:
					Bullets.e_shoot(e, off + i * TAU / S.ring, S.spd, o)
			elif S.get("burst", 0):
				e.burst_left = S.burst
				e.burst_t = 0.0
			elif S.get("n", 0) > 1:
				for i in S.n:
					Bullets.e_shoot(e, a - S.spread / 2 + S.spread * i / (S.n - 1), S.spd, o)
			else:
				Bullets.e_shoot(e, a, S.spd, o)
			if not S.get("burst", 0):
				Sfx.play("enemyShoot")
			e.wind = 0.0
		return
	e.shot_cd -= dt * (1.3 if e.mod == "swift" else 1.0)
	if e.shot_cd <= 0:
		var d := U.dist(e.x, e.y, tg.x, tg.y)
		if d < 230 and (S.get("ring", 0) or Coll.line_clear(e.x, e.y, tg.x, tg.y)):
			e.wind = 0.5 if S.get("ring", 0) else 0.35
			e.shot_cd = S.cd * U.rnd(0.85, 1.15)
		else:
			e.shot_cd = 0.4
