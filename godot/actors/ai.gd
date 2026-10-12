class_name AI
extends RefCounted
# Comportamenti dei nemici (AI in js/entities.js). Firma comune: (e, dt, tg, m),
# con tg il bersaglio ({x, y} o il giocatore) e m il moltiplicatore di velocità.

static func run(e: Enemy, dt: float, tg, m: float) -> void:
	match e.ai:
		"chaser": chaser(e, dt, tg, m)
		"erratic": erratic(e, dt, tg, m)
		"shooter": shooter(e, dt, tg, m)
		"caster": caster(e, dt, tg, m)
		"charger": charger(e, dt, tg, m)

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
