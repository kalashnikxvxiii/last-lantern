class_name Bullets
extends RefCounted
# Player and enemy projectiles (js/entities.js). They are dictionaries in
# Run.bullets and Run.ebullets.

static func e_shoot(e, ang: float, spd: float, o: Dictionary = {}) -> void:
	var ox: float = e.x + cos(ang) * (e.r * 0.8)
	var oy: float = e.y + sin(ang) * (e.r * 0.8)
	Run.ebullets.append({
		"x": ox, "y": oy, "vx": cos(ang) * spd, "vy": sin(ang) * spd, "r": o.get("r", 3.0),
		"dmg": o.dmg if o.get("dmg", 0.0) else e.dmg * 0.8, "life": o.life if o.get("life", 0.0) else 5.0,
		"kind": o.kind if o.get("kind") else "orb", "col": o.col if o.get("col") else "violet",
		"status": o.status if o.get("status") else null, "src": e.display_name, "accel": o.get("accel", 0.0),
		"curve": o.get("curve", 0.0), "t": 0.0, "big": o.get("big", false),
	})

static func shot_opts(e) -> Dictionary:
	var S: Dictionary = e.def.shot
	var o := {"kind": S.get("kind"), "col": S.get("col"), "status": S.get("status")}
	if e.mod == "venom":
		o.status = "poison"
	return o

static func update_player(dt: float) -> void:
	var room := Run.room
	var s := Run.player.stats
	var i := 0
	while i < Run.bullets.size():
		var b: Dictionary = Run.bullets[i]
		i += 1
		if b.get("dead", false):
			continue
		b.t += dt
		b.life -= dt
		if b.life <= 0:
			b.dead = true
			continue
		if s.homing and b.kind != "shard":
			var best = null
			var bd := 140.0
			for e in Run.enemies:
				if e.dead or e.intangible or e.spawning or b.hit.has(e):
					continue
				var d := U.dist(b.x, b.y, e.x, e.y)
				if d < bd:
					bd = d
					best = e
			if best != null:
				var a := atan2(b.vy, b.vx)
				var ta := U.ang_to(b.x, b.y, best.x, best.y)
				var na: float = a + clampf(U.ang_diff(a, ta), -1, 1) * 3.2 * s.homing * dt
				var sp := sqrt(b.vx * b.vx + b.vy * b.vy)
				b.vx = cos(na) * sp
				b.vy = sin(na) * sp
		# movement with bounces
		var nx: float = b.x + b.vx * dt
		var ny: float = b.y + b.vy * dt
		var t := RoomU.world_to_tile(nx, b.y)
		var hit_wall := false
		if RoomU.blocks_shot(room, t.x, t.y):
			Combat.damage_tile(t.x, t.y, b.dmg)
			if b.bounce > 0:
				b.vx = -b.vx
				b.bounce -= 1
			else:
				hit_wall = true
		else:
			b.x = nx
		t = RoomU.world_to_tile(b.x, ny)
		if not hit_wall and RoomU.blocks_shot(room, t.x, t.y):
			Combat.damage_tile(t.x, t.y, b.dmg)
			if b.bounce > 0:
				b.vy = -b.vy
				b.bounce -= 1
			else:
				hit_wall = true
		elif not hit_wall:
			b.y = ny
		if hit_wall:
			b.dead = true
			Particles.burst(b.x, b.y, 4, ["#f29c38", "#f6cf57"], 40, 0.25)
			if s.split and b.kind == "ember":
				spawn_shards(b)
			continue
		if b.kind == "comet" and U.random() < 0.6:
			Particles.add({"x": b.x, "y": b.y, "life": 0.35, "color": U.pick(["#c8f2f5", "#f6cf57"]), "size": 2})
		# collision with enemies
		var j := 0
		while j < Run.enemies.size():
			var e = Run.enemies[j]
			j += 1
			if e.dead or e.intangible or e.spawning or b.hit.has(e):
				continue
			if e.z > 10:
				continue
			var rr: float = b.r + e.r
			if U.dist2(b.x, b.y, e.x, e.y) > rr * rr:
				continue
			# front shield
			if e.def != null and e.def.shield and not (e.frozen > 0) and not e.shield_down:
				var ab := U.ang_to(e.x, e.y, b.x, b.y)
				if absf(U.ang_diff(e.facing, ab)) < 1.0:
					b.dead = true
					Sfx.play("block")
					Particles.burst(b.x, b.y, 5, ["#e8e4dc", "#a59fb0"], 60, 0.25)
					break
			bullet_hit(b, e)
			b.hit[e] = true
			if b.pierce > 0:
				b.pierce -= 1
			else:
				b.dead = true
				if s.split and b.kind == "ember":
					spawn_shards(b)
				break
	Run.bullets = Run.bullets.filter(func(x): return not x.get("dead", false))

static func spawn_shards(b: Dictionary) -> void:
	var a := atan2(b.vy, b.vx)
	for da in [-0.6, 0.0, 0.6]:
		var aa: float = a + PI + da + U.rnd(-0.2, 0.2)
		Run.bullets.append({"x": b.x - cos(a) * 3, "y": b.y - sin(a) * 3, "vx": cos(aa) * 170, "vy": sin(aa) * 170, "r": 2.0,
			"dmg": b.dmg * 0.4, "crit": false, "life": 0.35, "pierce": 0, "bounce": 0, "hit": b.hit.duplicate(), "kind": "shard", "t": 0.0})

static func bullet_hit(b: Dictionary, e) -> void:
	var p := Run.player
	var s := p.stats
	Combat.hit_enemy(e, b.dmg, {"crit": b.crit, "kx": b.vx, "ky": b.vy, "kb": 160 if b.kind == "comet" else 90})
	var base := p.damage()
	if s.primal or U.random() < s.burn or (b.crit and s.critBurn):
		Status.add(e, "burn", 3, base * 0.6 * s.burnMult)
	if U.random() < s.poison:
		Status.add(e, "poison", 4, base * 0.35)
	if s.chillAll or U.random() < s.chill:
		Status.add(e, "chill", 2.2)
	if b.crit and s.critHeal:
		p.heal(1, true)
	if s.chain and U.random() < s.chain:
		Combat.chain_lightning(e, base * 0.6)

static func update_enemy(dt: float) -> void:
	var p := Run.player
	var room := Run.room
	for b in Run.ebullets:
		if b.get("dead", false):
			continue
		b.t += dt
		b.life -= dt
		if b.life <= 0:
			b.dead = true
			continue
		if b.accel:
			var sp := sqrt(b.vx * b.vx + b.vy * b.vy)
			var ns := maxf(10, sp + b.accel * dt)
			b.vx *= ns / sp
			b.vy *= ns / sp
		if b.curve:
			var a: float = atan2(b.vy, b.vx) + b.curve * dt
			var sp := sqrt(b.vx * b.vx + b.vy * b.vy)
			b.vx = cos(a) * sp
			b.vy = sin(a) * sp
		b.x += b.vx * dt
		b.y += b.vy * dt
		var t := RoomU.world_to_tile(b.x, b.y)
		var ghost: bool = b.get("ghost", false)
		if not ghost and RoomU.blocks_shot(room, t.x, t.y):
			var tt := RoomU.tile_at(room, t.x, t.y)
			if tt != Consts.T.WALL and tt != Consts.T.DOOR:
				Combat.damage_tile(t.x, t.y, 4)
			b.dead = true
			Particles.burst(b.x, b.y, 3, color_of(b), 30, 0.2)
			continue
		if ghost and (t.x <= 0 or t.y <= 0 or t.x >= Consts.RW - 1 or t.y >= Consts.RH - 1):
			b.dead = true
			continue
		if not p.dead and U.dist2(b.x, b.y, p.x, p.y - 1) < (b.r + 2.5) * (b.r + 2.5):
			if Combat.hurt_player(b.dmg, b.src):
				if b.status != null:
					Status.add(p, b.status, 3.5 if b.status == "poison" else (2.5 if b.status == "burn" else 3.0))
				b.dead = true
			elif p.dash_t <= 0 and p.inv <= 0:
				b.dead = true
	Run.ebullets = Run.ebullets.filter(func(x): return not x.get("dead", false))

static func color_of(b: Dictionary) -> String:
	match b.kind:
		"bone": return "#e8e4dc"
		"spore": return "#e88fc0"
		"dust": return "#d8d0c0"
		"fire": return "#f29c38"
		"ice": return "#9fe0ff"
		"void": return "#a24ab8"
	return {"violet": "#c57ae0", "red": "#e0574a", "cyan": "#7fd8e6"}.get(b.col, "#c57ae0")
