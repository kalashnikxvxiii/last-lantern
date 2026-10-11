class_name Effects
extends RefCounted
# Effetti (addFx, placeBomb, updateFx, explosionHit in js/entities.js):
# esplosioni, bombe, onde d'urto, avvisi, nubi, fuoco, evocazioni, fulmini, vampate.

static func add(f: Dictionary) -> Dictionary:
	f.t = 0.0
	if not f.has("life"):
		f.life = 1.0
	Run.fx.append(f)
	return f

static func place_bomb(x: float, y: float, owner: String) -> void:
	add({"type": "bomb", "x": x, "y": y, "life": 1.5, "owner": owner})
	Sfx.play("thud", 0.4)

static func update(dt: float) -> void:
	var p := Run.player
	var i := 0
	while i < Run.fx.size():
		var f: Dictionary = Run.fx[i]
		i += 1
		if f.get("dead", false):
			continue
		if f.get("delay", 0.0) > 0:
			f.delay -= dt
			if f.delay > 0:
				continue
			f.delay = 0.0
		f.t += dt
		match f.type:
			"explosion":
				if not f.get("done", false):
					f.done = true
					explosion_hit(f)
			"bomb":
				if f.t >= f.life:
					add({"type": "explosion", "x": f.x, "y": f.y, "r": 40.0, "dmg": 60 + 15 * Run.depth, "owner": "neutral", "life": 0.4, "reveal": true})
				else:
					var rate := 12.0 if f.t > 1 else 5.0
					if floorf(f.t * rate) != floorf((f.t - dt) * rate):
						Sfx.play("tick")
			"shockwave":
				f.r += f.spd * dt
				if f.owner == "enemy" and not f.get("hitP", false) and not p.dead:
					var d := U.dist(f.x, f.y, p.x, p.y)
					if absf(d - f.r) < 7:
						f.hitP = true
						Combat.hurt_player(f.dmg, f.get("src", "Un'onda d'urto"))
				elif f.owner == "player":
					var j := 0
					while j < Run.enemies.size():
						var e = Run.enemies[j]
						j += 1
						if e.dead or f.hit.has(e):
							continue
						var d := U.dist(f.x, f.y, e.x, e.y)
						if absf(d - f.r) < 8 + e.r:
							f.hit[e] = true
							Combat.hit_enemy(e, f.dmg, {"kx": e.x - f.x, "ky": e.y - f.y, "kb": 160})
							Status.add(e, "burn", 2.5, p.damage() * 0.6 * p.stats.burnMult)
				if f.r >= f.maxR:
					f.dead = true
			"warn":
				if f.t >= f.life:
					if f.get("hit") == "cloud":
						add({"type": "cloud", "x": f.x, "y": f.y, "r": f.r, "life": 3.2, "owner": "enemy", "status": "poison"})
					else:
						add({"type": "explosion", "x": f.x, "y": f.y, "r": f.r, "dmg": f.dmg, "owner": "enemy", "life": 0.35, "src": f.get("src", "")})
			"cloud":
				f.tick = f.get("tick", 0.0) - dt
				if f.owner == "enemy" and f.tick <= 0 and U.dist(f.x, f.y, p.x, p.y) < f.r * minf(1, f.t * 3):
					f.tick = 0.5
					Status.add(p, f.status, 2.5)
				if U.random() < 0.3:
					Particles.add({"x": f.x + U.rnd(-f.r, f.r) * 0.8, "y": f.y + U.rnd(-f.r, f.r) * 0.6, "vy": -8.0, "life": 0.8, "color": U.rgba(120, 200, 80, 0.5), "size": 2})
			"fire":
				f.tick = f.get("tick", 0.0) - dt
				if f.tick <= 0:
					f.tick = 0.35
					if f.owner == "player":
						var j := 0
						while j < Run.enemies.size():
							var e = Run.enemies[j]
							j += 1
							if not e.dead and not e.fly and U.dist(f.x, f.y, e.x, e.y) < f.r + e.r:
								Combat.hit_enemy(e, p.damage() * 0.3, {"dot": "burn"})
								Status.add(e, "burn", 2, p.damage() * 0.5 * p.stats.burnMult)
					elif U.dist(f.x, f.y, p.x, p.y) < f.r + 2 and p.dash_t <= 0:
						Status.add(p, "burn", 2)
				if U.random() < 0.25:
					Particles.add({"x": f.x + U.rnd(-f.r, f.r) * 0.7, "y": f.y + U.rnd(-3, 3), "vy": -25.0, "life": 0.45, "color": U.pick(["#f29c38", "#f6cf57", "#b5571f"])})
			"spawn":
				if f.t >= f.life:
					var sp: Dictionary = f.spec
					var e := Enemy.make(sp.type, f.x, f.y, sp.get("mod"), {"summoned": sp.get("summoned", false)})
					if sp.get("summoner") != null:
						e.summoner = sp.summoner
					e.summoned = sp.get("summoned", false)
					Run.add_enemy(e)
					Particles.burst(f.x, f.y, 10, ["#c57ae0", "#4b2a5c", "#e8e4dc"], 60, 0.4)
		if f.t >= f.life:
			f.dead = true
	Run.fx = Run.fx.filter(func(x): return not x.get("dead", false))
	Run.room.spikeT += dt

static func point_seg_dist(px: float, py: float, x0: float, y0: float, x1: float, y1: float) -> float:
	var dx := x1 - x0
	var dy := y1 - y0
	var l2 := dx * dx + dy * dy
	var t := ((px - x0) * dx + (py - y0) * dy) / l2 if l2 != 0 else 0.0
	t = clampf(t, 0, 1)
	return U.dist(px, py, x0 + t * dx, y0 + t * dy)

static func explosion_hit(f: Dictionary) -> void:
	var p := Run.player
	var room := Run.room
	var small: bool = f.get("small", false)
	Particles.burst(f.x, f.y, 14 if small else 34, ["#fff2a8", "#f6cf57", "#f29c38", "#b5571f", "#3b3546"], f.r * 4, 0.6)
	Sfx.play("explosion", 0.4 if small else 1.0)
	Fx.shake(2 if small else 6)
	Run.flash_light = {"x": f.x, "y": f.y, "t": 0.3, "r": f.r * 3}
	if f.owner != "enemy":
		var j := 0
		while j < Run.enemies.size():
			var e = Run.enemies[j]
			j += 1
			if e.dead:
				continue
			if U.dist(f.x, f.y, e.x, e.y) < f.r + e.r:
				Combat.hit_enemy(e, f.dmg, {"kx": e.x - f.x, "ky": e.y - f.y, "kb": 220, "force": true})
	if f.owner != "player" and not p.dead:
		if U.dist(f.x, f.y, p.x, p.y) < f.r + 2:
			Combat.hurt_player(minf(14, f.dmg * 0.3) if f.owner == "neutral" else f.dmg, f.get("src", "Un'esplosione"))
	# tile coinvolti
	if not small or f.owner == "neutral":
		var ct := RoomU.world_to_tile(f.x, f.y)
		var R := int(ceilf(f.r / Consts.TS))
		for ty in range(ct.y - R, ct.y + R + 1):
			for tx in range(ct.x - R, ct.x + R + 1):
				if tx < 1 or ty < 1 or tx >= Consts.RW - 1 or ty >= Consts.RH - 1:
					continue
				var c := RoomU.tile_center(tx, ty)
				if U.dist(c.x, c.y, f.x, f.y) > f.r + 6:
					continue
				var t: int = room.grid[ty][tx]
				if t == Consts.T.BARREL:
					Combat.explode_barrel(tx, ty)
				elif t == Consts.T.URN:
					Combat.break_urn(tx, ty)
				elif (t == Consts.T.CRACK or t == Consts.T.ROCK) and f.owner == "neutral":
					room.grid[ty][tx] = Consts.T.FLOOR
					room.bgDirty = true
					Particles.burst(c.x, c.y, 12, ["#55505e", "#3b3546", "#8a8294"], 80, 0.6, {"grav": 100})
					if t == Consts.T.CRACK and U.random() < 0.6:
						room.pickups.append(Pickups.make("coin" if U.random() < 0.7 else "cons", c.x, c.y, {"id": "bomb"}))
	# passaggi segreti
	if f.get("reveal", false):
		for d in room.doors:
			var n: Dictionary = room.doors[d]
			if n.type != "secret" or n.found:
				continue
			var dc := RoomU.door_center(d)
			if U.dist(dc.x, dc.y, f.x, f.y) < f.r + 22:
				n.found = true
				for tt in RoomU.DIRS[d].tiles:
					room.grid[tt[1]][tt[0]] = Consts.T.DOOR
				room.bgDirty = true
				Run.toast("Un passaggio segreto!", "#f6cf57")
				Sfx.play("chest")
