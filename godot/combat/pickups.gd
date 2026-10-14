class_name Pickups
extends RefCounted
# Pickups (makePickup, randomCons, updatePickups, collectPickup in js/entities.js).

static func make(type: String, x: float, y: float, o: Dictionary = {}) -> Dictionary:
	var a := U.rnd(TAU)
	var s := U.rnd(20, 70)
	return {"type": type, "x": x, "y": y, "vx": cos(a) * s, "vy": sin(a) * s, "z": 0, "vz": 30 if type == "xp" else 70,
		"t": 0, "value": o.value if o.get("value", 0) else 1, "id": o.id if o.get("id") else null, "magnet": false}

static func random_cons() -> String:
	return U.weighted_pick(Cons.ALL.keys(), func(k): return Cons.ALL[k].w)

static func update(dt: float) -> void:
	var p := Run.player
	var room := Run.room
	var pr: float = p.stats.pickup
	for k in room.pickups:
		if k.get("dead", false):
			continue
		k.t += dt
		k.vz -= 260 * dt
		k.z += k.vz * dt
		if k.z < 0:
			k.z = 0.0
			k.vz = -k.vz * 0.4 if absf(k.vz) > 30 else 0.0
		var d := U.dist(k.x, k.y, p.x, p.y)
		var auto: bool = k.type == "xp" or ((k.type == "coin" or k.type == "coin5") and not room.combat)
		if not p.dead and k.t > 0.35 and (d < pr or (auto and not room.combat and k.t > 0.6) or k.magnet):
			if k.type == "heart" and p.hp >= p.stats.maxHp:
				pass   # stays on the ground
			elif k.type == "cons" and not p.can_take_cons(k.id):
				pass
			else:
				k.magnet = true
				var a := U.ang_to(k.x, k.y, p.x, p.y)
				var sp: float = 160 + k.t * 60
				k.vx = cos(a) * sp
				k.vy = sin(a) * sp
		else:
			k.vx *= maxf(0, 1 - 4 * dt)
			k.vy *= maxf(0, 1 - 4 * dt)
		var ox: float = k.x
		var oy: float = k.y
		k.x += k.vx * dt
		k.y += k.vy * dt
		if not k.magnet:
			var t := RoomU.world_to_tile(k.x, k.y)
			if RoomU.is_solid_tile(room, t.x, t.y, false):
				k.x = ox
				k.y = oy
				k.vx = -k.vx * 0.5
				k.vy = -k.vy * 0.5
		if d < 7 and k.t > 0.3 and not p.dead:
			collect(k)
	room.pickups = room.pickups.filter(func(x): return not x.get("dead", false))

static func collect(k: Dictionary) -> void:
	var p := Run.player
	match k.type:
		"xp":
			p.add_xp(k.value)
			Sfx.play("xp")
		"coin":
			var n := p.add_coins(1)
			Floaters.add(p.x, p.y - 12, "+" + str(n), Txt.COLORS.y, {"life": 0.5})
			Sfx.play("coin")
		"coin5":
			var n := p.add_coins(5)
			Floaters.add(p.x, p.y - 12, "+" + str(n), Txt.COLORS.y, {"life": 0.6})
			Sfx.play("coin")
		"heart":
			if p.hp >= p.stats.maxHp:
				return
			p.heal(12 + 2 * Run.depth)
		"oil":
			p.add_oil(k.value if k.value else 25)
			Sfx.play("oil")
			Floaters.add(p.x, p.y - 12, "+oil", Txt.COLORS.o, {"life": 0.6})
		"key":
			p.keys += 1
			Sfx.play("pickup")
			Floaters.add(p.x, p.y - 12, "+1 key", Txt.COLORS.y, {"life": 0.8})
		"cons":
			if not p.give_cons(k.id):
				return
			Sfx.play("pickup")
			Run.toast(Cons.ALL[k.id].name, "#ece6d8", Cons.ALL[k.id].desc)
	k.dead = true
