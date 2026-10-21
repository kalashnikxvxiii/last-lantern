class_name Player
extends Node2D
# The lantern bearer (newPlayer and player functions in js/entities.js).
# x, y are the JS logical coordinates; position aligns at the end of the tick.

var x := 0.0
var y := 0.0
var vx := 0.0
var vy := 0.0
var r := 4.0
var hp := 1.0
var oil := 1.0
var xp := 0.0
var level := 1
var coins := 0
var keys := 1
var aim := 0.0
var fire_cd := 0.0
var dash_t := 0.0
var dash_cd := 0.0
var dash_charges := 1
var dash_dx := 0.0
var dash_dy := 0.0
var inv := 0.0
var statuses: Dictionary = {}
var perks: Dictionary = {}
var relics: Array = []
var curses: Array = []
var cons: Array = [null, null, null, null]
var shot_count := 0
var flare_cd := 0.0
var guard_t := 0.0
var guard_up := false
var secondwind_used := false
var coffin_used := false
var temp_orbit := 0
var temp_orbit_t := 0.0
var orbit_a := 0.0
var sun_t := 0.0
var storm_t := 3.0
var trail_t := 0.0
var echo_t := 0.0
var anim := 0.0
var moving := false
var lantern := "warden"
var character := "wanderer"   # Godot-only
var overclock_t := 0.0   # Godot-only: the Cogling's Overclock armor
var talon := false   # Godot-only: the dash is the Owlfox's Talon Dash
var talon_hit: Dictionary = {}   # instance ids struck by this Talon Dash
var stats: Dictionary = Stats.base()
var dead := false
var last_hit := ""
var facing := 1
var base_hp_mod := 0.0

# recalcStats: lantern, perks, relics, curses, Ardor and limits
func recalc_stats() -> void:
	var s := Stats.base()
	DB.lantern(lantern).apply_stats(s)
	for id in perks:
		Perks.apply(id, s, perks[id])
	for id in relics:
		Relics.apply(id, s)
	for id in curses:
		Curses.apply(id, s)
	s.maxHp += base_hp_mod
	if Run.ardor >= 4:
		s.healMult -= 0.3
	if Run.ardor >= 5:
		s.oilDrain *= 1.5
	s.dmgMult = maxf(0.2, s.dmgMult)
	s.rateMult = maxf(0.3, s.rateMult)
	s.speedMult = maxf(0.5, s.speedMult)
	s.lightMult = maxf(0.35, s.lightMult)
	s.healMult = maxf(0.1, s.healMult)
	s.maxHp = maxf(10, U.jround(s.maxHp))
	s.armor = maxf(0, s.armor)
	s.dodge = minf(0.6, s.dodge)
	s.crit = minf(1, s.crit)
	stats = s
	hp = minf(hp, s.maxHp)
	oil = minf(oil, s.maxOil)
	dash_charges = mini(dash_charges, int(s.dashCharges))

func damage() -> float:
	var s := stats
	var m: float = s.dmgMult
	if statuses.has("rage"):
		m += 0.5
	if statuses.has("weak"):
		m -= 0.3
	if s.berserk:
		m += 1 - hp / s.maxHp
	if s.lowHpDmg and hp / s.maxHp < 0.4:
		m += s.lowHpDmg
	return s.dmg * maxf(0.15, m)

func fire_rate() -> float:
	var s := stats
	var m: float = s.rateMult
	if statuses.has("rage"):
		m += 0.5
	if statuses.has("fury"):
		m += s.fury
	return s.fireRate * maxf(0.3, m)

func speed() -> float:
	var m: float = stats.speedMult
	if statuses.has("slow"):
		m -= 0.35
	if statuses.has("chill"):
		m -= 0.3
	return stats.speed * maxf(0.35, m)

func light() -> float:
	var s := stats
	var frac: float = oil / s.maxOil if s.maxOil > 0 else 0.0
	var r_: float = s.light * s.lightMult * (0.45 + 0.55 * minf(1, frac * 1.3))
	if statuses.has("blind"):
		r_ *= 0.45
	return maxf(26, r_)

# pure part of hurtPlayer: effective damage after armor, frailty and darkness
func damage_taken(amount: float) -> int:
	var armor: float = stats.armor + (2.0 if overclock_t > 0 else 0.0)   # Godot-only: Overclock
	var d: float = amount * stats.dmgTaken * (1 - minf(0.6, armor * 0.07))
	if statuses.has("fragile"):
		d *= 1.3
	if oil <= 0:
		d *= 1.25
	return int(maxf(1, U.jround(d)))

func heal(v: float, raw: bool = false) -> void:
	var amt: float = v if raw else v * stats.healMult
	var before := hp
	hp = minf(stats.maxHp, hp + amt)
	var got := int(U.jround(hp - before))
	if got > 0:
		Floaters.add(x, y - 12, "+" + str(got), Txt.COLORS.g)
		Particles.burst(x, y, 10, ["#8fd35a", "#d0ffb0"], 40, 0.6, {"grav": -40})
		Sfx.play("heal")

func add_oil(v: float) -> void:
	oil = minf(stats.maxOil, oil + v)

func add_coins(v: float) -> int:
	var n := int(maxf(1, U.jround(v * stats.coinMult)))
	coins += n
	Run.coins_total += n
	return n

func give_cons(id: String) -> bool:
	for s in cons:
		if s != null and s.id == id and s.n < 3:
			s.n += 1
			return true
	var i := cons.find(null)
	if i >= 0:
		cons[i] = {"id": id, "n": 1}
		return true
	return false

func can_take_cons(id: String) -> bool:
	return cons.any(func(s): return s == null or (s.id == id and s.n < 3))

func add_xp(v: float) -> void:
	xp += v * stats.xpMult
	while xp >= Stats.xp_need(level):
		xp -= Stats.xp_need(level)
		level += 1
		Run.pending_levels += 1
		Floaters.add(x, y - 16, Loc.f("LEVEL {0}", [level]), Txt.COLORS.y, {"life": 1.4, "vy": -20})
		Particles.burst(x, y, 24, ["#f6cf57", "#fff2a8", "#f29c38"], 90, 0.8, {"grav": -30})
		Sfx.play("levelup")
		heal(6, true)

# update (updatePlayer); the rest of the body arrives in Tasks 17, 18 and 21
func tick(dt: float) -> void:
	var s := stats
	anim += dt
	Status.update(self, dt, true)
	if dead:
		return
	inv = maxf(0.0, inv - dt)
	flare_cd = maxf(0.0, flare_cd - dt)
	overclock_t = maxf(0.0, overclock_t - dt)
	# Godot-only: holding R roots the player (no running away from the restart)
	var rooted := Controls.held("reroll")
	# aim
	aim = Controls.aim_angle(x, y, aim)
	facing = 1 if cos(aim) >= 0 else -1
	# dash
	if dash_charges < s.dashCharges:
		dash_cd -= dt
		if dash_cd <= 0:
			dash_charges += 1
			dash_cd = s.dashCd
	else:
		dash_cd = s.dashCd
	if rooted:
		dash_t = 0.0
	var mv := Vector2.ZERO if rooted else Controls.move()
	if not rooted and Controls.dash() and dash_charges > 0 and dash_t <= 0:
		var dx := mv.x
		var dy := mv.y
		if dx == 0 and dy == 0:
			dx = cos(aim)
			dy = sin(aim)
		var l := sqrt(dx * dx + dy * dy)
		dash_dx = dx / l
		dash_dy = dy / l
		dash_t = 0.16 * s.dashDist
		dash_charges -= 1
		Sfx.play("dash")
		Particles.burst(x, y + 4, 8, ["#8a8294", "#55505e"], 40, 0.4)
		if s.dashReflect:
			reflect_bullets(x, y, 34)
	var mvx := 0.0
	var mvy := 0.0
	if dash_t > 0:
		dash_t -= dt
		mvx = dash_dx * 330
		mvy = dash_dy * 330
		if U.random() < 0.7:
			Particles.add({"x": x + U.rnd(-2, 2), "y": y + U.rnd(-4, 4), "life": 0.3, "color": U.rgba(160, 190, 210, 0.6), "size": 2})
		if s.dashfire:
			trail_t -= dt
			if trail_t <= 0:
				trail_t = 0.035
				Effects.add({"type": "fire", "x": x, "y": y + 3, "r": 8.0, "life": 2.2, "owner": "player"})
		if s.dashReflect:
			reflect_bullets(x, y, 26)
		if talon:
			talon_strike()
	else:
		talon = false
		var sp := speed()
		mvx = mv.x * sp
		mvy = mv.y * sp
	moving = sqrt(mvx * mvx + mvy * mvy) > 5
	# Devourer's suction
	if Run.pull != null and not rooted:
		mvx += Run.pull.x
		mvy += Run.pull.y
	if Cheats.noclip:
		x = clampf(x + mvx * dt, Consts.RX + r, Consts.RX + Consts.RW * Consts.TS - r)
		y = clampf(y + mvy * dt, Consts.RY + r, Consts.RY + Consts.RH * Consts.TS - r)
	else:
		var bx := Coll.move_axis(self, mvx * dt, 0, false)
		var by := Coll.move_axis(self, mvy * dt, 1, false)
		# corner sliding (helps line up with doors)
		if bx and absf(mvy) < 1:
			Coll.nudge(self, 0, mvx)
		if by and absf(mvx) < 1:
			Coll.nudge(self, 1, mvy)

	# fire
	fire_cd -= dt
	if not rooted and Controls.firing() and fire_cd <= 0 and not Run.lock_fire:
		fire()
		fire_cd = 1 / fire_rate()
	# flare
	if not rooted and Controls.flare():
		use_ability()
	# consumables
	var sl := Controls.slot()
	if sl >= 0:
		use_cons(sl)
	if echo_t > 0:
		echo_t -= dt
		if echo_t <= 0:
			fire_volley(aim, true)
	var room := Run.room
	# oil
	if room.combat and not s.noOilDrain:
		oil = maxf(0, oil - 1.05 * s.oilDrain * dt)
	# Warden Light shield
	if s.guardian and not guard_up:
		guard_t -= dt
		if guard_t <= 0:
			guard_up = true
			Sfx.play("shield", 0.5)
	# temporary fireflies
	if temp_orbit_t > 0:
		temp_orbit_t -= dt
		if temp_orbit_t <= 0:
			temp_orbit = 0
	orbit_a += dt * 3.2
	update_orbitals(dt)
	# little sun
	if s.sun and room.combat:
		sun_t -= dt
		if sun_t <= 0:
			sun_t = 0.5
			var R := light() * 0.45
			for e in Run.enemies.duplicate():
				if not e.dead and U.dist(e.x, e.y, x, y) < R:
					Combat.hit_enemy(e, damage() * 0.35, {"dot": "burn"})
	# storm bottle
	if s.storm and room.combat:
		storm_t -= dt
		if storm_t <= 0:
			storm_t = 3.0
			var targets: Array = Run.enemies.filter(func(e): return not e.dead and not e.intangible and not e.spawning)
			if not targets.is_empty():
				var e = U.pick(targets)
				Effects.add({"type": "bolt", "pts": [[e.x + U.rnd(-10, 10), Consts.RY], [e.x, e.y]], "life": 0.25})
				Combat.hit_enemy(e, damage() * 2.5, {"crit": false})
				Sfx.play("bolt")
	# spikes
	var t := RoomU.world_to_tile(x, y + 2)
	if RoomU.tile_at(room, t.x, t.y) == Consts.T.SPIKE and RoomU.spikes_up(room) and dash_t <= 0:
		Combat.hurt_player(8 * Stats.depth_dmg(Run.depth), "The spikes")

func fire() -> void:
	fire_volley(aim)
	if stats.echo and U.random() < stats.echo:
		echo_t = 0.09

func fire_volley(aim_: float, is_echo: bool = false) -> void:
	var s := stats
	var n: int = s.proj
	var spread := minf(0.9, 0.13 * (n - 1)) if n > 1 else 0.0
	var dmg := damage()
	var lx := x + cos(aim_) * 7
	var ly := y - 3 + sin(aim_) * 6
	shot_count += 1
	var comet_every := 4 if s.comet >= 2 else 6
	var is_comet: bool = s.comet > 0 and shot_count % comet_every == 0 and not is_echo
	for i in n:
		var a: float = aim_ + (-spread / 2 + spread * i / (n - 1) if n > 1 else 0.0) + U.rnd(-0.035, 0.035)
		var crit: bool = U.random() < s.crit
		Run.bullets.append({"x": lx, "y": ly, "vx": cos(a) * s.shotSpeed, "vy": sin(a) * s.shotSpeed, "r": s.shotSize,
			"dmg": dmg * (s.critMult if crit else 1.0), "crit": crit, "life": float(s["range"]) / s.shotSpeed, "pierce": s.pierce,
			"bounce": s.bounce, "hit": {}, "kind": "ember", "t": 0.0})
	if is_comet:
		Run.bullets.append({"x": lx, "y": ly, "vx": cos(aim_) * s.shotSpeed * 1.15, "vy": sin(aim_) * s.shotSpeed * 1.15, "r": s.shotSize + 2,
			"dmg": dmg * 3, "crit": false, "life": (s["range"] * 1.4) / s.shotSpeed, "pierce": 99, "bounce": 0, "hit": {}, "kind": "comet", "t": 0.0})
	Particles.burst(lx, ly, 3, ["#f6cf57", "#f29c38"], 50, 0.2, {"angle": aim_, "spread": 0.5})
	Sfx.play("shoot")

# Godot-only: the character's ability costs its share of the Flare's cost,
# so what lowers the Flare's cost lowers every ability's
func ability_cost() -> float:
	return stats.flareCost * (DB.character(character).cost / 40.0)

# the oil and cooldown part of tryFlare; Godot-only: the character picks the ability
func use_ability() -> void:
	var cost := ability_cost()
	if flare_cd > 0:
		return
	if oil < cost:
		Sfx.play("deny")
		Floaters.add(x, y - 14, "Not enough oil", Txt.COLORS.d, {"life": 0.9})
		flare_cd = 0.4
		return
	oil -= cost
	flare_cd = 0.9
	match character:
		"goblin": smoke_bomb()
		"stranger": phase_jump()
		"cogling": overclock()
		"owlfox": talon_dash()
		"wizard": arcane_volley()
		_: flare()

# the effect part of tryFlare
func flare() -> void:
	var s := stats
	var R := 64.0
	var dmg: float = damage() * 3 * s.flareMult
	for e in Run.enemies.duplicate():
		if e.dead or e.spawning:
			continue
		var d := U.dist(e.x, e.y, x, y)
		if d < R + e.r:
			Combat.hit_enemy(e, dmg, {"kx": e.x - x, "ky": e.y - y, "kb": 280})
			Status.add(e, "burn", 3, damage() * 0.6 * s.burnMult)
	for b in Run.ebullets:
		if not b.big and U.dist(b.x, b.y, x, y) < R + 6:
			b.dead = true
			Particles.burst(b.x, b.y, 3, "#f6cf57", 30, 0.3)
	Effects.add({"type": "flare", "x": x, "y": y, "r": R, "life": 0.45})
	Run.flash_light = {"x": x, "y": y, "t": 0.5}
	Particles.burst(x, y, 40, ["#fff2a8", "#f6cf57", "#f29c38"], 180, 0.6)
	Fx.shake(5)
	Sfx.play("flare")
	inv = maxf(inv, 0.25)

# Godot-only: the Goblin blinds the enemies around and slips out of sight
func smoke_bomb() -> void:
	var R := 56.0
	for e in Run.enemies:
		if not e.dead and not e.spawning and U.dist(e.x, e.y, x, y) < R + e.r:
			Status.add(e, "blind", 3)
	Status.add(self, "invis", 2)
	Particles.burst(x, y, 36, ["#55505e", "#8a8294", "#b8b2c2"], 90, 0.9)
	Sfx.play("flare", 0.5)

# Godot-only: the Stranger leaves a chilling pulse and reappears up to 80 px
# along the aim, on the farthest free spot (over rocks, through projectiles)
func phase_jump() -> void:
	var R := 48.0
	for e in Run.enemies:
		if not e.dead and not e.spawning and U.dist(e.x, e.y, x, y) < R + e.r:
			Status.add(e, "chill", 2.5)
	Effects.add({"type": "flare", "x": x, "y": y, "r": R, "life": 0.35})
	Particles.burst(x, y, 20, ["#c8f2f5", "#7fd8e6", "#7866a0"], 80, 0.5)
	var d := 80.0
	while d > 0:
		var nx := clampf(x + cos(aim) * d, Consts.RX + r, Consts.RX + Consts.RW * Consts.TS - r)
		var ny := clampf(y + sin(aim) * d, Consts.RY + r, Consts.RY + Consts.RH * Consts.TS - r)
		if not Coll.collides(Run.room, nx, ny, r, false, true):
			x = nx
			y = ny
			break
		d -= 4
	Particles.burst(x, y, 20, ["#c8f2f5", "#7fd8e6", "#7866a0"], 80, 0.5)
	inv = maxf(inv, 0.3)
	Sfx.play("dash")

# Godot-only: the Cogling runs hot: Rage and +2 armor for 5 seconds
func overclock() -> void:
	Status.add(self, "rage", 5)
	overclock_t = 5.0
	Particles.burst(x, y, 24, ["#ffb040", "#b0763c", "#fff2a8"], 70, 0.5)
	Sfx.play("shield")

# Godot-only: the Owlfox dashes along the aim, without spending a dash;
# talon_strike hits each enemy on the way once
func talon_dash() -> void:
	dash_dx = cos(aim)
	dash_dy = sin(aim)
	dash_t = 0.16 * stats.dashDist
	talon = true
	talon_hit = {}
	Particles.burst(x, y + 4, 10, ["#c06a30", "#ffc040"], 50, 0.4)
	Sfx.play("dash")

func talon_strike() -> void:
	for e in Run.enemies.duplicate():
		if e.dead or e.spawning or e.intangible or talon_hit.has(e.get_instance_id()):
			continue
		if U.dist(e.x, e.y, x, y) < e.r + r + 4:
			talon_hit[e.get_instance_id()] = true
			Combat.hit_enemy(e, damage() * 2.5 * stats.flareMult, {"kx": dash_dx, "ky": dash_dy, "kb": 220})

# Godot-only: the Wizard fires a ring of 12 piercing bolts
func arcane_volley() -> void:
	var s := stats
	var dmg: float = damage() * 1.5 * s.flareMult
	for i in 12:
		var a := aim + TAU * i / 12.0
		Run.bullets.append({"x": x, "y": y - 3, "vx": cos(a) * s.shotSpeed, "vy": sin(a) * s.shotSpeed, "r": s.shotSize + 1,
			"dmg": dmg, "crit": false, "life": (s["range"] * 1.2) / s.shotSpeed, "pierce": 99, "bounce": 0, "hit": {}, "kind": "comet", "t": 0.0})
	Particles.burst(x, y - 3, 24, ["#e8e8ff", "#5272c4", "#7fd8e6"], 90, 0.5)
	Sfx.play("flare", 0.6)

func reflect_bullets(px: float, py: float, R: float) -> void:
	for b in Run.ebullets:
		if b.get("dead", false) or b.big:
			continue
		if U.dist(b.x, b.y, px, py) < R:
			b.dead = true
			var a: float = atan2(-b.vy, -b.vx)
			Run.bullets.append({"x": b.x, "y": b.y, "vx": cos(a) * 240, "vy": sin(a) * 240, "r": 3.0, "dmg": damage() * 1.5,
				"crit": false, "life": 1.2, "pierce": 1, "bounce": 0, "hit": {}, "kind": "ember", "t": 0.0})
			Particles.burst(b.x, b.y, 4, "#c8f2f5", 40, 0.3)

func orbital_positions() -> Array:
	var n: int = int(stats.orbit) + temp_orbit
	var out: Array = []
	for i in n:
		var a := orbit_a + i * TAU / n
		out.append(Vector2(x + cos(a) * 22, y - 2 + sin(a) * 22))
	return out

func update_orbitals(_dt: float) -> void:
	var orbs := orbital_positions()
	if orbs.is_empty():
		return
	var dmg := damage() * 0.8
	for o in orbs:
		for e in Run.enemies.duplicate():
			if e.dead or e.intangible or e.spawning:
				continue
			if e.orb_cd > 0:
				continue
			if U.dist2(o.x, o.y, e.x, e.y) < (e.r + 4) * (e.r + 4):
				Combat.hit_enemy(e, dmg, {"kx": e.x - x, "ky": e.y - y, "kb": 60})
				e.orb_cd = 0.35
		for b in Run.ebullets:
			if not b.get("dead", false) and not b.big and U.dist2(o.x, o.y, b.x, b.y) < (b.r + 4) * (b.r + 4):
				b.dead = true
				Particles.burst(b.x, b.y, 4, "#f6cf57", 40, 0.3)

func sync() -> void:
	position = Vector2(x, y)
	visible = not dead
	queue_redraw()

func _process(_delta: float) -> void:
	sync()

# drawLantern (js/render.js)
func draw_lantern(ci: CanvasItem) -> void:
	var glass := DB.lantern(lantern).glass
	var lx := U.jround(x + cos(aim) * 7)
	var ly := U.jround(y - 1 + sin(aim) * 4)
	UiDraw.px_rect(ci, lx - 2, ly - 4, 5, 7, "#0b0810")
	UiDraw.px_rect(ci, lx - 1, ly - 5, 3, 1, "#3b3546")
	UiDraw.px_rect(ci, lx - 1, ly - 3, 3, 4, glass)
	UiDraw.px_rect(ci, lx, ly - 2, 1, 2, "#ffffff")
	UiDraw.px_rect(ci, lx - 1, ly + 2, 3, 1, "#3b3546")

func lantern_behind() -> bool:
	return sin(aim) < -0.3

# the orbiting embers (drawPlayer)
func draw_orbitals(ci: CanvasItem) -> void:
	for o in orbital_positions():
		UiDraw.px_rect(ci, o.x - 2, o.y - 2, 4, 4, "#f29c38")
		UiDraw.px_rect(ci, o.x - 1, o.y - 1, 2, 2, "#fff2a8")

# sprite, frame and effects of drawPlayer, shared by the 2D drawing and the 3D view
func sprite_state() -> Dictionary:
	if dead or not Run.active:
		return {}
	var frame := int(floor(anim * 8)) % 2 if moving else 0
	var bob := -1 if moving and frame != 0 else 0
	# Godot-only: one view per 45 degrees of aim, down (0) to up (4), the left side mirrored
	frame += 2 * int(U.jround((PI / 2 - atan2(sin(aim), absf(cos(aim)))) / (PI / 4)))
	var o := {"flip": facing < 0, "flash": dash_t > 0 and Fx.vis.next() < 0.3,
		"alpha": sprite_alpha()}
	return {"name": DB.character(character).sprite, "frame": frame, "x": x, "y": y + bob, "o": o}

# without the dash flash's random draw: DrawLifted asks for it again in the same frame
func sprite_alpha() -> float:
	var blink := inv > 0 and int(floor(inv * 20)) % 2 == 0
	return 0.35 if statuses.has("invis") else (0.4 if blink else 1.0)

# drawPlayer (js/render.js), in world coordinates
func _draw() -> void:
	if dead or not Run.active:
		return
	UiDraw.set_origin(self, -position)
	UiDraw.shadow(self, x, y + 7, 5)
	var ga := UiDraw.alpha
	# the 3D view stands the sprite up and draws the lantern and the embers on it
	if not View3D.on:
		var st := sprite_state()
		var behind := lantern_behind()
		UiDraw.alpha = st.o.alpha
		st.o.erase("alpha")
		if behind:
			draw_lantern(self)
		Spr.draw(self, st.name, st.frame, x, st.y, st.o)
		if not behind:
			draw_lantern(self)
		UiDraw.alpha = ga
	if guard_up:
		UiDraw.alpha = 0.5 + 0.2 * sin(Fx.time * 6)
		UiDraw.px_ring(self, x, y, 11, "#7fd8e6")
		UiDraw.alpha = ga
	if not View3D.on:
		draw_orbitals(self)
	UiDraw.set_origin(self, Vector2.ZERO)

func use_cons(i: int) -> void:
	var sl: Variant = cons[i]
	if sl == null:
		return
	var C: Dictionary = Cons.ALL[sl.id]
	if C.get("passive", false):
		Run.toast(Loc.f("{0}: passive effect", [Loc.t(C.name)]), "#8a8294")
		Sfx.play("deny")
		return
	if not Cons.use(sl.id, self):
		Sfx.play("deny")
		return
	sl.n -= 1
	if sl.n <= 0:
		cons[i] = null
