class_name Combat
extends RefCounted
# Damage to player and enemies, death, kills, lightning, destructible tiles (js/entities.js).

static func hurt_player(amount: float, src: String = "", o: Dictionary = {}) -> bool:
	var p := Run.player
	if p.dead or Run.victory_t != 0 or Cheats.god:
		return false
	var dot: bool = o.get("dot", false)
	if not dot:
		if p.inv > 0 or p.dash_t > 0:
			return false
		if U.random() < p.stats.dodge:
			Floaters.add(p.x, p.y - 14, "Dodged", Txt.COLORS.c)
			p.inv = 0.35
			return false
		if p.guard_up:
			p.guard_up = false
			p.guard_t = 10.0
			p.inv = 0.7
			Sfx.play("shield")
			Particles.burst(p.x, p.y, 20, ["#c8f2f5", "#7fd8e6", "#ffffff"], 90, 0.5)
			return false
	var dmg := p.damage_taken(amount)
	p.hp -= dmg
	Run.dmg_taken += dmg
	p.last_hit = src if src != "" else "The dark"
	if not dot:
		p.inv = p.stats.iframes
		Fx.shake(5)
		Fx.hitstop(0.06)
		Fx.screen_flash("#c02020", 0.35)
		Sfx.play("hurt")
		Particles.burst(p.x, p.y, 12, ["#d04b3c", "#7e2530"], 70, 0.5)
		Floaters.add(p.x, p.y - 14, "-" + str(dmg), Txt.COLORS.r)
		if p.stats.ashguard:
			Effects.add({"type": "shockwave", "x": p.x, "y": p.y, "r": 4.0, "maxR": 70.0, "spd": 220.0, "owner": "player", "dmg": p.damage() * 2, "hit": {}})
	elif Save.data.settings.numbers:
		Floaters.add(p.x, p.y - 12, "-" + str(dmg), Txt.COLORS.g if src == "The poison" else Txt.COLORS.o, {"life": 0.5})
	if p.hp <= 0:
		player_death()
	return true

static func player_death() -> void:
	var p := Run.player
	if p.stats.secondwind and not p.secondwind_used:
		p.secondwind_used = true
		p.hp = 1.0
		p.inv = 2.0
		Run.toast("Last Breath", "#f6cf57", "You survived by a breath.")
		Sfx.play("shield")
		return
	if p.stats.revive and not p.coffin_used:
		p.coffin_used = true
		p.hp = U.jround(p.stats.maxHp / 2)
		p.inv = 2.5
		Run.toast("Coffin Nail", "#f6cf57", "Death refuses you. For now.")
		revive_burst(p)
		return
	var fi := -1
	for i in p.cons.size():
		if p.cons[i] != null and p.cons[i].id == "feather":
			fi = i
			break
	if fi >= 0:
		p.cons[fi].n -= 1
		if p.cons[fi].n <= 0:
			p.cons[fi] = null
		p.hp = U.jround(p.stats.maxHp / 2)
		p.inv = 2.5
		Run.toast("Phoenix Feather", "#f29c38", "Rise from your ashes.")
		revive_burst(p)
		return
	p.hp = 0.0
	p.dead = true
	Run.death_t = 0.0
	Sfx.play("kill")
	Sfx.play("descend")
	Particles.burst(p.x, p.y, 40, ["#d04b3c", "#f6cf57", "#33475a"], 120, 1.0)
	Fx.shake(10)

static func revive_burst(p) -> void:
	Sfx.play("flare")
	Particles.burst(p.x, p.y, 50, ["#fff2a8", "#f29c38", "#e0574a"], 160, 1)
	for b in Run.ebullets:
		b.dead = true
	var i := 0
	while i < Run.enemies.size():
		var e = Run.enemies[i]
		if not e.boss and U.dist(e.x, e.y, p.x, p.y) < 90:
			hit_enemy(e, p.damage() * 4, {"kx": e.x - p.x, "ky": e.y - p.y, "kb": 300})
		i += 1
	Fx.screen_flash("#fff2a8", 0.6)

static func hit_enemy(e, dmg: float, o: Dictionary = {}) -> void:
	if e.dead or (e.intangible and not o.get("force", false)) or e.spawning:
		return
	var dot: Variant = o.get("dot")
	if e.boss and (e.invuln > 0 or e.dying != null):
		if dot == null:
			Particles.burst(e.x, e.y, 2, "#a59fb0", 30, 0.2)
		return
	if e.mod == "armored":
		dmg *= 0.7
	if e.frozen > 0:
		dmg *= 1.15
	if Cheats.one_shot:
		dmg = maxf(dmg, e.hp)
	e.hp -= dmg
	Run.dmg_dealt += dmg
	if dot == null:
		e.flash = 0.08
	if o.has("kx") and not e.boss:
		var l := sqrt(o.kx * o.kx + o.ky * o.ky)
		if l == 0:
			l = 1.0
		var f: float = o.get("kb", 90.0) * (0.35 if e.def != null and e.def.shield else 1.0) * (0.6 if e.elite else 1.0)
		e.kbx += o.kx / l * f
		e.kby += o.ky / l * f
	var crit: bool = o.get("crit", false)
	if Save.data.settings.numbers:
		var col: Color = Txt.COLORS.o if dot == "burn" else (Txt.COLORS.g if dot == "poison" else (Txt.COLORS.y if crit else Txt.COLORS.w))
		var v: float = U.jround(dmg * 10) / 10 if dmg < 10 else U.jround(dmg)
		if dot == null or v >= 1:
			Floaters.add(e.x, e.y - e.r - 6, str(int(maxf(1, U.jround(v)))), col, {"scale": 1.0, "life": 0.9 if crit else 0.6})
	if dot == null:
		Particles.burst(e.x, e.y, 6 if crit else 3, ["#fff2a8", "#f6cf57"] if crit else ["#e8e4dc", "#a59fb0"], 50, 0.25)
		Sfx.play("crit" if crit else "hit")
		if crit:
			Fx.hitstop(0.02)
	if e.hp <= 0:
		kill_enemy(e, o)

static func kill_enemy(e, o: Dictionary = {}) -> void:
	if e.dead:
		return
	if e.boss:
		e.start_death()
		return
	e.dead = true
	Run.kills += 1
	var p := Run.player
	var s := p.stats
	var cols := enemy_colors(e)
	Particles.burst(e.x, e.y, 26 if e.elite else 16, cols, 90, 0.6, {"grav": 60})
	if not o.get("silent", false):
		Sfx.play("kill")
	Fx.shake(3 if e.elite else 1.5)
	if not e.summoned or U.chance(0.5):
		# experience
		var n := int(minf(8, maxf(1, U.jround(e.xp / 2))))
		for i in n:
			Run.room.pickups.append(Pickups.make("xp", e.x, e.y, {"value": e.xp / n}))
		# oil
		p.add_oil(2.5 + (4 if e.elite else 0))
		Run.oil_fx.append({"x": e.x, "y": e.y, "t": 0.0})
		# coins and hearts
		var cc := 0.8 if e.elite else 0.13
		if U.random() < cc:
			Run.room.pickups.append(Pickups.make("coin5" if U.random() < 0.12 else "coin", e.x, e.y))
		var hc := 0.02 if Run.ardor >= 4 else 0.035
		if U.random() < hc + (0.1 if e.elite else 0.0):
			Run.room.pickups.append(Pickups.make("heart", e.x, e.y))
		if e.elite and U.random() < 0.25:
			Run.room.pickups.append(Pickups.make("cons", e.x, e.y, {"id": Pickups.random_cons()}))
	# perk effects
	if s.leech:
		p.heal(s.leech, true)
	if s.fury:
		Status.add(p, "fury", 2.5)
	if s.explode:
		Effects.add({"type": "explosion", "x": e.x, "y": e.y, "r": 26 + 6 * s.explode, "dmg": p.damage() * (0.9 + 0.5 * s.explode), "owner": "player", "life": 0.3, "small": true})
	if s.ashTrail:
		Effects.add({"type": "fire", "x": e.x, "y": e.y, "r": 12.0, "life": 3.0, "owner": "player"})
	# enemy effects
	if e.def != null and e.def.split != "" and not e.no_split:
		for i in e.def.split_n:
			var ne := Enemy.make(e.def.split, e.x + U.rnd(-5, 5), e.y + U.rnd(-5, 5), null, {"summoned": true})
			ne.stun = 0.25
			ne.kbx = U.rnd(-90, 90)
			ne.kby = U.rnd(-90, 90)
			Run.add_enemy(ne)
	if e.mod == "splitter" and not e.no_split:
		for i in 2:
			var ne := Enemy.make(e.type, e.x + U.rnd(-6, 6), e.y + U.rnd(-6, 6), null, {"small": true, "summoned": true})
			ne.stun = 0.3
			ne.kbx = U.rnd(-100, 100)
			ne.kby = U.rnd(-100, 100)
			Run.add_enemy(ne)
	if e.mod == "volatile":
		var off := U.rnd(TAU)
		for i in 8:
			Bullets.e_shoot(e, off + i * TAU / 8, 80, {"kind": "fire", "dmg": e.dmg * 0.7})
	if e.def != null and e.def.death_cloud:
		Effects.add({"type": "cloud", "x": e.x, "y": e.y, "r": 24.0, "life": 3.5, "owner": "enemy", "status": "poison"})

static func enemy_colors(e) -> Array:
	match e.type:
		"rat": return ["#6e5a4e", "#a06868", "#d04b3c"]
		"bat": return ["#3a2246", "#6a3a80", "#d04b3c"]
		"skeleton", "skull": return ["#e8e4dc", "#a59fb0", "#c57ae0"]
		"ghoul": return ["#5d7a5a", "#34482f", "#7e2530"]
		"grub", "grubling": return ["#c9b28a", "#e9dcb0", "#8fd35a"]
		"spore": return ["#a33a7a", "#e88fc0", "#4f8a3a"]
		"hopper": return ["#c8443a", "#e8e4dc"]
		"moth": return ["#b8b0a0", "#e6e0cc"]
		"automaton", "turret": return ["#9a8250", "#6b6478", "#f29c38"]
		"slag", "spark": return ["#f29c38", "#f6cf57", "#b5571f"]
		"smith": return ["#8a5a34", "#6b6478"]
		"drowned", "eel", "jelly": return ["#5aa0aa", "#9ad8dc", "#4f7ab8"]
		"shade", "wisp": return ["#231830", "#d08aff", "#7a3a9a"]
		"cultist": return ["#9a2f3a", "#5c1f2a", "#f6cf57"]
		"knight": return ["#c0c8d0", "#7a8290"]
		"eye": return ["#8a3aa0", "#e0574a", "#e8e4dc"]
	return ["#e8e4dc", "#a59fb0"]

static func chain_lightning(from, dmg: float) -> void:
	var cur = from
	var hit := {from: true}
	var pts: Array = [[from.x, from.y]]
	for i in 3:
		var best = null
		var bd := 80.0
		for e in Run.enemies:
			if e.dead or hit.has(e) or e.intangible or e.spawning:
				continue
			var d := U.dist(cur.x, cur.y, e.x, e.y)
			if d < bd:
				bd = d
				best = e
		if best == null:
			break
		hit[best] = true
		pts.append([best.x, best.y])
		hit_enemy(best, dmg, {})
		cur = best
	if pts.size() > 1:
		Effects.add({"type": "bolt", "pts": pts, "life": 0.2})
		Sfx.play("bolt", 0.6)

static func damage_tile(tx: int, ty: int, dmg: float) -> void:
	var room := Run.room
	var t := RoomU.tile_at(room, tx, ty)
	var k := ty * RoomU.rw(room) + tx
	if t == Consts.T.BARREL:
		room.tileHp[k] = room.tileHp.get(k, 18) - dmg
		if room.tileHp[k] <= 0:
			explode_barrel(tx, ty)
	elif t == Consts.T.URN:
		break_urn(tx, ty)

static func explode_barrel(tx: int, ty: int) -> void:
	var room := Run.room
	if room.grid[ty][tx] != Consts.T.BARREL:
		return
	room.grid[ty][tx] = Consts.T.FLOOR
	room.tileHp.erase(ty * RoomU.rw(room) + tx)
	var c := RoomU.tile_center(tx, ty)
	Effects.add({"type": "explosion", "x": c.x, "y": c.y, "r": 36.0, "dmg": 40 + 12 * Run.depth, "owner": "neutral", "life": 0.4, "delay": 0.08})

static func break_urn(tx: int, ty: int) -> void:
	var room := Run.room
	room.grid[ty][tx] = Consts.T.FLOOR
	room.tileHp.erase(ty * RoomU.rw(room) + tx)
	var c := RoomU.tile_center(tx, ty)
	Particles.burst(c.x, c.y, 14, ["#9a8250", "#6a5a3a", "#c49a6a"], 70, 0.5, {"grav": 120})
	Sfx.play("thud", 0.6)
	var r := U.random()
	if r < 0.35:
		room.pickups.append(Pickups.make("coin", c.x, c.y))
	elif r < 0.45:
		room.pickups.append(Pickups.make("oil", c.x, c.y, {"value": 12}))
	elif r < 0.48:
		room.pickups.append(Pickups.make("heart", c.x, c.y))

static func freeze_all(t: float) -> void:
	for e in Run.enemies:
		if not e.dead:
			e.frozen = t * 0.4 if e.boss else t
	Sfx.play("freeze")
	Fx.screen_flash("#c8f2f5", 0.4)
	Particles.burst(Run.player.x, Run.player.y, 40, ["#c8f2f5", "#7fd8e6", "#ffffff"], 200, 0.8)
