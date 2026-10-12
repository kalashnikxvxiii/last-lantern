class_name Boss
extends Enemy
# Guardiano di fine profondità (makeBoss, bossUpdate, startBossDeath, bossDying in js/entities.js).

var bid := ""
var B: BossDef
var phase := 0
var pat: Variant = null
var gap_t := 1.6
var last_pat := -1
var hit_wall_boss := false

static func make_boss(id: String, x_: float, y_: float) -> Boss:
	var b_ := DB.boss(id)
	var d := Run.depth
	var cyc := ((d - 1) % 5) + 1
	var extra := Stats.depth_hp(d) / Stats.depth_hp(cyc) if d > 5 else 1.0
	var e := Boss.new()
	e.boss = true
	e.bid = id
	e.B = b_
	e.display_name = b_.name
	e.x = x_
	e.y = y_
	e.r = b_.r
	e.hp = b_.hp * extra * Stats.ard_hp()
	e.max_hp = e.hp
	e.spd = b_.spd
	e.dmg = 13 * Stats.depth_dmg(d) * Stats.ard_dmg()
	e.ai = "boss"
	e.fly = true
	e.stun = 0.0
	e.xp = 60 + 30 * d
	e.position = Vector2(x_, y_)
	return e

func think(dt: float, tg, m: float) -> void:
	_boss_update(dt, tg, m)

func dying_update(dt: float) -> void:
	_boss_dying(dt)

func _spr_name() -> String:
	return B.spr

func _boss_update(dt: float, tg, m: float) -> void:
	hit_wall_boss = hit_wall
	wind = maxf(0, wind - dt)
	var ph: Array = B.phases
	if phase + 1 < ph.size() and hp / max_hp <= ph[phase + 1].at:
		phase += 1
		pat = null
		gap_t = 1.4
		invuln = 1.4
		z = 0.0
		intangible = false
		alpha = 1.0
		slam_target = null
		charge_line = null
		Run.pull = null
		Sfx.play("roar")
		Fx.shake(8)
		Fx.screen_flash("#ffffff", 0.3)
		var off := U.rnd(TAU)
		for i in 20:
			BossPatterns.boss_shoot(self, off + i * TAU / 20, {"spd": 70.0, "kind": ph[0].pats[0].get("kind", "orb")})
		Run.toast(display_name + " si infuria!", "#e0574a")
	if invuln > 0:
		invuln -= dt
		vx = 0.0
		vy = 0.0
		return
	var rate := (1.25 if Run.ardore >= 5 else 1.0) * (1 + 0.04 * maxf(0, Run.depth - 5))
	var cur: Dictionary = ph[phase]
	if pat == null:
		gap_t -= dt * rate
		# movimento tra un attacco e l'altro
		var d := U.dist(x, y, tg.x, tg.y)
		var a := U.ang_to(x, y, tg.x, tg.y)
		if d < 70:
			a += PI
		elif d < 120:
			a += PI / 2
		vx = cos(a) * spd * m
		vy = sin(a) * spd * m
		if gap_t <= 0:
			var i := 0
			while true:
				i = U.rndi(0, cur.pats.size() - 1)
				if not (i == last_pat and cur.pats.size() > 1):
					break
			last_pat = i
			pat = {"s": cur.pats[i], "t": 0.0}
			vx = 0.0
			vy = 0.0
	else:
		var done := BossPatterns.run(self, pat, dt * rate, pat.s)
		if pat != null:
			pat.t += dt * rate
		if pat != null and pat.s.p != "charge" and pat.s.p != "slam":
			vx *= 0.9
			vy *= 0.9
			if pat.s.p != "drain" and spd > 0:
				vx = 0.0
				vy = 0.0
		if done:
			pat = null
			gap_t = cur.gap
			Run.pull = null
	if vx != 0:
		facing = atan2(vy, vx)

func start_death() -> void:
	if dying != null:
		return
	dying = 0.0
	hp = 0.0
	pat = null
	vx = 0.0
	vy = 0.0
	z = 0.0
	alpha = 1.0
	intangible = true
	slam_target = null
	charge_line = null
	Run.pull = null
	for b in Run.ebullets:
		b.dead = true
	for f in Run.fx:
		if f.type == "beam" or f.type == "warn":
			f.dead = true
	for x_ in Run.enemies.duplicate():
		if not x_.boss:
			Combat.kill_enemy(x_, {"silent": true})
	Sfx.play("roar")
	Fx.hitstop(0.25)
	Music.set_intensity(0)

func _boss_dying(dt: float) -> void:
	dying += dt
	flash = 0.05 if fmod(dying * 10, 1.0) < 0.5 else 0.0
	if U.random() < 0.3:
		var px := x + U.rnd(-r, r)
		var py := y + U.rnd(-r, r)
		Particles.burst(px, py, 10, ["#fff2a8", "#f6cf57", "#f29c38", "#e8e4dc"], 90, 0.5)
		Sfx.play("hit")
		Fx.shake(3)
	if dying > 2.0:
		dead = true
		Run.kills += 1
		Save.data.stats.bossKills += 1
		Save.write()
		Fx.shake(12)
		Sfx.play("explosion")
		Fx.screen_flash("#fff2a8", 0.8)
		Particles.burst(x, y, 120, ["#fff2a8", "#f6cf57", "#f29c38", "#e8e4dc", "#c57ae0"], 220, 1.4)
		Flow.on_boss_defeated(self)
