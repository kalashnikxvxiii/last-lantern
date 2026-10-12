class_name BossPatterns
extends RefCounted
# Pattern d'attacco dei boss (PATTERNS e bossShoot in js/entities.js).
# Firma comune: (e, P, dt, s) -> true quando il pattern è finito.

static func run(e: Boss, P: Dictionary, dt: float, s: Dictionary) -> bool:
	match s.p:
		"ring": return ring(e, P, dt, s)
		"aimed": return aimed(e, P, dt, s)
		"spiral": return spiral(e, P, dt, s)
		"summon": return summon(e, P, dt, s)
		"charge": return charge(e, P, dt, s)
	return true

static func boss_shoot(e, a: float, s: Dictionary, extra: Dictionary = {}) -> void:
	var o := {"kind": s.get("kind", "orb") if s.get("kind") else "orb", "col": s.get("col"), "status": s.get("status"), "dmg": e.dmg * 0.75, "life": 7.0}
	o.merge(extra, true)
	Bullets.e_shoot(e, a, s.spd if s.get("spd", 0) else 90.0, o)

static func ring(e: Boss, P: Dictionary, dt: float, s: Dictionary) -> bool:
	if not P.get("init", false):
		P.init = true
		P.k = 0
		P.next = 0.4
		e.wind = 0.4
	if P.t >= P.next and P.k < s.count:
		var off: float = (P.k % 2) * PI / s.n + U.rnd(0, 0.15)
		for i in s.n:
			boss_shoot(e, off + i * TAU / s.n, s)
		P.k += 1
		P.next += s.gap
		Sfx.play("enemyShoot")
	return P.k >= s.count and P.t > P.next

static func aimed(e: Boss, P: Dictionary, dt: float, s: Dictionary) -> bool:
	if not P.get("init", false):
		P.init = true
		P.k = 0
		P.next = 0.35
		e.wind = 0.35
	if P.t >= P.next and P.k < s.count:
		var p := Run.player
		var a: float = U.ang_to(e.x, e.y, p.x, p.y)
		for i in s.n:
			boss_shoot(e, a - s.spread / 2 + s.spread * i / (s.n - 1), s)
		P.k += 1
		P.next += s.gap
		Sfx.play("enemyShoot")
	return P.k >= s.count and P.t > P.next

static func spiral(e: Boss, P: Dictionary, dt: float, s: Dictionary) -> bool:
	if not P.get("init", false):
		P.init = true
		P.ang = U.rnd(TAU)
		P.acc = 0.0
		e.wind = 0.3
	if P.t < 0.3:
		return false
	P.acc += dt * s.rate
	while P.acc >= 1:
		P.acc -= 1
		for i in s.arms:
			boss_shoot(e, P.ang + i * TAU / s.arms, s)
		Sfx.play("enemyShoot", 0.5)
	P.ang += s.rot * dt
	return P.t > s.dur + 0.3

static func summon(e: Boss, P: Dictionary, dt: float, s: Dictionary) -> bool:
	if not P.get("init", false):
		P.init = true
		var alive: int = Run.enemies.filter(func(x): return not x.dead and not x.boss).size()
		var n: int = mini(s.count, maxi(0, s.cap - alive))
		for i in n:
			var tiles: Array = RoomU.reach_tiles(Run.room).filter(func(t):
				var c := RoomU.tile_center(t.x, t.y)
				return U.dist(c.x, c.y, e.x, e.y) < 90 and U.dist(c.x, c.y, Run.player.x, Run.player.y) > 50)
			if tiles.is_empty():
				break
			var t: Vector2i = U.pick(tiles)
			var c := RoomU.tile_center(t.x, t.y)
			Effects.add({"type": "spawn", "x": c.x, "y": c.y, "life": 0.8, "spec": {"type": s.type, "summoned": true}})
		e.wind = 0.6
		Sfx.play("spawn")
	return P.t > 0.9

static func charge(e: Boss, P: Dictionary, dt: float, s: Dictionary) -> bool:
	if not P.get("init", false):
		P.init = true
		P.k = 0
		P.sub = "aim"
		P.st = 0.0
	P.st += dt
	var p := Run.player
	if P.sub == "aim":
		e.vx = 0.0
		e.vy = 0.0
		P.a = U.ang_to(e.x, e.y, p.x, p.y)
		e.wind = 0.65 - P.st
		e.charge_line = P.a
		if P.st > 0.65:
			P.sub = "go"
			P.st = 0.0
			e.charge_line = null
			Sfx.play("dash")
	elif P.sub == "go":
		e.vx = cos(P.a) * s.spd
		e.vy = sin(P.a) * s.spd
		if U.random() < 0.6:
			Particles.add({"x": e.x + U.rnd(-6, 6), "y": e.y + e.r, "life": 0.4, "color": "#55505e", "size": 2})
		if e.hit_wall_boss or P.st > 1.3:
			P.sub = "stop"
			P.st = 0.0
			e.vx = 0.0
			e.vy = 0.0
			Fx.shake(5)
			Sfx.play("thud")
			if s.get("ring", 0):
				var off := U.rnd(TAU)
				for i in s.ring:
					boss_shoot(e, off + i * TAU / s.ring, {"spd": 85.0, "kind": s.get("kind"), "status": s.get("status")})
	elif P.sub == "stop":
		e.vx = 0.0
		e.vy = 0.0
		if P.st > 0.45:
			P.k += 1
			P.sub = "aim"
			P.st = 0.0
			if P.k >= s.count:
				return true
	return false
