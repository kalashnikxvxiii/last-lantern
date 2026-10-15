class_name BossPatterns
extends RefCounted
# Boss attack patterns (PATTERNS and bossShoot in js/entities.js).
# Common signature: (e, P, dt, s) -> true when the pattern is finished.

static func run(e: Boss, P: Dictionary, dt: float, s: Dictionary) -> bool:
	match s.p:
		"ring": return ring(e, P, dt, s)
		"aimed": return aimed(e, P, dt, s)
		"spiral": return spiral(e, P, dt, s)
		"summon": return summon(e, P, dt, s)
		"charge": return charge(e, P, dt, s)
		"slam": return slam(e, P, dt, s)
		"rain": return rain(e, P, dt, s)
		"wall": return wall(e, P, dt, s)
		"teleport": return teleport(e, P, dt, s)
		"beam": return beam(e, P, dt, s)
		"darkpulse": return darkpulse(e, P, dt, s)
		"drain": return drain(e, P, dt, s)
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

static func slam(e: Boss, P: Dictionary, dt: float, s: Dictionary) -> bool:
	if not P.get("init", false):
		P.init = true
		P.k = 0
		P.sub = "rise"
		P.st = 0.0
	P.st += dt
	var p := Run.player
	if P.sub == "rise":
		if P.st < 0.05:
			P.x0 = e.x
			P.y0 = e.y
		if P.st < 0.45:
			P.tx = p.x
			P.ty = p.y
		var k := minf(1, P.st / 0.65)
		e.z = sin(k * PI / 2) * 50
		e.x = lerpf(P.x0, P.tx, k)
		e.y = lerpf(P.y0, P.ty, k)
		e.vx = 0.0
		e.vy = 0.0
		e.intangible = e.z > 20
		e.slam_target = {"x": P.tx, "y": P.ty}
		if k >= 1:
			P.sub = "fall"
			P.st = 0.0
	elif P.sub == "fall":
		e.z = maxf(0, 50 * (1 - P.st / 0.14))
		if P.st > 0.14:
			e.z = 0.0
			e.intangible = false
			e.slam_target = null
			# reposition out of any obstacles
			if Coll.collides(Run.room, e.x, e.y, e.r, true):
				var c := RoomU.tile_center(14, 7)
				e.x = c.x
				e.y = c.y
			var wave_r: float = s.get("wave", 130.0)
			Effects.add({"type": "shockwave", "x": e.x, "y": e.y, "r": 6.0, "maxR": wave_r, "spd": 170.0, "owner": "enemy", "dmg": e.dmg, "src": e.display_name})
			if s.get("ring", 0):
				var off := U.rnd(TAU)
				for i in s.ring:
					boss_shoot(e, off + i * TAU / s.ring, {"spd": 80.0, "kind": s.get("kind"), "status": s.get("status")})
			Fx.shake(7)
			Sfx.play("explosion", 0.6)
			Particles.burst(e.x, e.y + e.r, 30, ["#55505e", "#8a8294", "#3b3546"], 120, 0.6)
			P.sub = "rest"
			P.st = 0.0
	elif P.sub == "rest":
		if P.st > 0.5:
			P.k += 1
			P.sub = "rise"
			P.st = 0.0
			if P.k >= s.count:
				return true
	return false

static func rain(e: Boss, P: Dictionary, dt: float, s: Dictionary) -> bool:
	if not P.get("init", false):
		P.init = true
		P.acc = 0.0
		P.made = 0
		e.wind = 0.4
	P.acc += dt * s.n / s.dur
	while P.acc >= 1 and P.made < s.n:
		P.acc -= 1
		P.made += 1
		var p := Run.player
		var x: float
		var y: float
		if P.made % 3 == 0:
			x = p.x + U.rnd(-10, 10)
			y = p.y + U.rnd(-10, 10)
		else:
			var t: Vector2i = U.pick(RoomU.reach_tiles(Run.room))
			var c := RoomU.tile_center(t.x, t.y)
			x = c.x
			y = c.y
		Effects.add({"type": "warn", "x": x, "y": y, "r": 20.0 if s.hit == "cloud" else 22.0, "life": 0.95, "hit": s.hit, "dmg": e.dmg, "src": e.display_name})
	return P.t > s.dur + 1.0

static func wall(e: Boss, P: Dictionary, _dt: float, s: Dictionary) -> bool:
	if not P.get("init", false):
		P.init = true
		P.k = 0
		P.next = 0.3
	if P.t >= P.next and P.k < s.count:
		P.k += 1
		P.next += 1.1
		var side: String = U.pick(["w", "e", "n", "s"])
		var horiz := side == "w" or side == "e"
		var n := 13 if horiz else 27
		var gap := U.rndi(1, n - 5)
		var RX := Consts.RX
		var RY := Consts.RY
		var TS := Consts.TS
		for i in n:
			if i >= gap and i < gap + 4:
				continue
			var x: float
			var y: float
			var a: float
			match side:
				"w":
					x = RX + TS * 1.2
					y = RY + TS * (1.5 + i)
					a = 0.0
				"e":
					x = RX + TS * 27.8
					y = RY + TS * (1.5 + i)
					a = PI
				"n":
					x = RX + TS * (1.5 + i)
					y = RY + TS * 1.2
					a = PI / 2
				_:
					x = RX + TS * (1.5 + i)
					y = RY + TS * 13.8
					a = -PI / 2
			Run.ebullets.append({"x": x, "y": y, "vx": cos(a) * 75, "vy": sin(a) * 75, "r": 3.0, "dmg": e.dmg * 0.7, "life": 8.0,
				"kind": s.get("kind") if s.get("kind") else "orb", "col": "red", "status": s.get("status"), "src": e.display_name,
				"accel": 0.0, "curve": 0.0, "t": 0.0, "big": false, "ghost": true})
		Sfx.play("warn")
	return P.k >= s.count and P.t > P.next

static func teleport(e: Boss, P: Dictionary, dt: float, s: Dictionary) -> bool:
	if not P.get("init", false):
		P.init = true
		P.sub = "out"
		P.st = 0.0
	P.st += dt
	e.vx = 0.0
	e.vy = 0.0
	if P.sub == "out":
		e.alpha = 1 - P.st / 0.35
		e.intangible = P.st > 0.2
		if P.st > 0.35:
			var p := Run.player
			var tiles: Array = RoomU.reach_tiles(Run.room).filter(func(t):
				var c := RoomU.tile_center(t.x, t.y)
				return U.dist(c.x, c.y, p.x, p.y) > 100 and t.x > 2 and t.x < Consts.RW - 3 and t.y > 2 and t.y < Consts.RH - 3)
			if not tiles.is_empty():
				var t: Vector2i = U.pick(tiles)
				var c := RoomU.tile_center(t.x, t.y)
				e.x = c.x
				e.y = c.y
			Particles.burst(e.x, e.y, 20, ["#9ad8dc", "#16343c"], 70, 0.6)
			P.sub = "in"
			P.st = 0.0
	elif P.sub == "in":
		e.alpha = P.st / 0.35
		e.intangible = P.st < 0.25
		if P.st > 0.35:
			e.alpha = 1.0
			e.intangible = false
			P.sub = "shoot"
			P.st = 0.0
			e.wind = 0.3
	elif P.sub == "shoot":
		if P.st > 0.3:
			var p := Run.player
			var a := U.ang_to(e.x, e.y, p.x, p.y)
			for i in s.n:
				boss_shoot(e, a - s.spread / 2 + s.spread * i / (s.n - 1), s)
			Sfx.play("enemyShoot")
			return true
	return false

static func beam(e: Boss, P: Dictionary, _dt: float, s: Dictionary) -> bool:
	if not P.get("init", false):
		P.init = true
		var p := Run.player
		var a0: float = U.ang_to(e.x, e.y, p.x, p.y) + PI / s.count
		var dir := 1 if U.chance(0.5) else -1
		for i in s.count:
			Effects.add({"type": "beam", "owner": e, "ang": a0 + i * TAU / s.count, "rot": s.rot * dir, "warm": s.warm, "dur": s.dur,
				"life": s.warm + s.dur, "len": 420.0, "w": 7.0, "dmg": e.dmg, "src": e.display_name, "x": e.x, "y": e.y})
		Sfx.play("warn")
	e.vx = 0.0
	e.vy = 0.0
	return P.t > s.warm + s.dur + 0.2

static func darkpulse(e: Boss, P: Dictionary, _dt: float, _s: Dictionary) -> bool:
	if not P.get("init", false):
		P.init = true
		e.wind = 0.7
	if P.t > 0.7 and not P.get("done", false):
		P.done = true
		Status.add(Run.player, "blind", 5)
		var off := U.rnd(TAU)
		for i in 18:
			boss_shoot(e, off + i * TAU / 18, {"spd": 75.0, "kind": "void"})
		Sfx.play("curse")
		Fx.screen_flash("#000000", 0.6)
		Effects.add({"type": "shockwave", "x": e.x, "y": e.y, "r": 6.0, "maxR": 260.0, "spd": 300.0, "owner": "visual", "dmg": 0.0})
	return P.t > 1.2

static func drain(e: Boss, P: Dictionary, dt: float, s: Dictionary) -> bool:
	if not P.get("init", false):
		P.init = true
		P.acc = 0.0
		Sfx.play("roar", 0.6)
	var p := Run.player
	var a := U.ang_to(p.x, p.y, e.x, e.y)
	Run.pull = {"x": cos(a) * 42, "y": sin(a) * 42}
	p.oil = maxf(0, p.oil - 10 * dt)
	if U.random() < 0.7:
		var ang := U.rnd(TAU)
		var rr := U.rnd(60, 160)
		Particles.add({"x": e.x + cos(ang) * rr, "y": e.y + sin(ang) * rr, "vx": -cos(ang) * rr * 1.5, "vy": -sin(ang) * rr * 1.5,
			"life": 0.6, "color": U.pick(["#f6cf57", "#a24ab8"]), "drag": 0.0})
	P.acc += dt
	if P.acc > 1.3:
		P.acc = 0.0
		if Run.enemies.filter(func(x): return not x.dead and not x.boss).size() < 8:
			var ang := U.rnd(TAU)
			Effects.add({"type": "spawn", "x": e.x + cos(ang) * 30, "y": e.y + sin(ang) * 30, "life": 0.5, "spec": {"type": "wisp", "summoned": true}})
	if P.t > s.dur:
		Run.pull = null
		return true
	return false
