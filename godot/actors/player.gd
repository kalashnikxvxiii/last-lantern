class_name Player
extends Node2D
# Il portatore di lanterna (newPlayer e funzioni del giocatore in js/entities.js).
# x, y sono le coordinate logiche del JS; position si allinea a fine tick.

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
var lantern := "custode"
var stats: Dictionary = Stats.base()
var dead := false
var last_hit := ""
var facing := 1
var base_hp_mod := 0.0

# recalcStats: lanterna, doni, reliquie, maledizioni, Ardore e limiti
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
	if Run.ardore >= 4:
		s.healMult -= 0.3
	if Run.ardore >= 5:
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

# parte pura di hurtPlayer: danno effettivo dopo armatura, fragilità e buio
func damage_taken(amount: float) -> int:
	var d: float = amount * stats.dmgTaken * (1 - minf(0.6, stats.armor * 0.07))
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
		Floaters.add(x, y - 16, "LIVELLO " + str(level), Txt.COLORS.y, {"life": 1.4, "vy": -20})
		Particles.burst(x, y, 24, ["#f6cf57", "#fff2a8", "#f29c38"], 90, 0.8, {"grav": -30})
		Sfx.play("levelup")
		heal(6, true)

# aggiornamento (updatePlayer); il resto del corpo arriva nei Task 17, 18 e 21
func tick(dt: float) -> void:
	var s := stats
	anim += dt
	if dead:
		return
	inv = maxf(0.0, inv - dt)
	flare_cd = maxf(0.0, flare_cd - dt)
	# mira
	aim = Controls.aim_angle(x, y, aim)
	facing = 1 if cos(aim) >= 0 else -1
	# scatto
	if dash_charges < s.dashCharges:
		dash_cd -= dt
		if dash_cd <= 0:
			dash_charges += 1
			dash_cd = s.dashCd
	else:
		dash_cd = s.dashCd
	var mv := Controls.move()
	if Controls.dash() and dash_charges > 0 and dash_t <= 0:
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
	var mvx := 0.0
	var mvy := 0.0
	if dash_t > 0:
		dash_t -= dt
		mvx = dash_dx * 330
		mvy = dash_dy * 330
		if U.random() < 0.7:
			Particles.add({"x": x + U.rnd(-2, 2), "y": y + U.rnd(-4, 4), "life": 0.3, "color": U.rgba(160, 190, 210, 0.6), "size": 2})
	else:
		var sp := speed()
		mvx = mv.x * sp
		mvy = mv.y * sp
	moving = sqrt(mvx * mvx + mvy * mvy) > 5
	# risucchio del Divoratore
	if Run.pull != null:
		mvx += Run.pull.x
		mvy += Run.pull.y
	var bx := Coll.move_axis(self, mvx * dt, 0, false)
	var by := Coll.move_axis(self, mvy * dt, 1, false)
	# scivolamento sugli spigoli (aiuta a imboccare le porte)
	if bx and absf(mvy) < 1:
		Coll.nudge(self, 0, mvx)
	if by and absf(mvx) < 1:
		Coll.nudge(self, 1, mvy)

func sync() -> void:
	position = Vector2(x, y)
	visible = not dead
	queue_redraw()

func _process(_delta: float) -> void:
	sync()

# drawLantern (js/render.js)
func _draw_lantern() -> void:
	var glass := DB.lantern(lantern).glass
	var lx := U.jround(x + cos(aim) * 7)
	var ly := U.jround(y - 1 + sin(aim) * 4)
	UiDraw.px_rect(self, lx - 2, ly - 4, 5, 7, "#0b0810")
	UiDraw.px_rect(self, lx - 1, ly - 5, 3, 1, "#3b3546")
	UiDraw.px_rect(self, lx - 1, ly - 3, 3, 4, glass)
	UiDraw.px_rect(self, lx, ly - 2, 1, 2, "#ffffff")
	UiDraw.px_rect(self, lx - 1, ly + 2, 3, 1, "#3b3546")

# drawPlayer (js/render.js), in coordinate del mondo
func _draw() -> void:
	if dead or not Run.active:
		return
	UiDraw.set_origin(self, -position)
	var blink := inv > 0 and int(floor(inv * 20)) % 2 == 0
	UiDraw.shadow(self, x, y + 7, 5)
	var a := 0.35 if statuses.has("invis") else (0.4 if blink else 1.0)
	var frame := int(floor(anim * 8)) % 2 if moving else 0
	var bob := -1 if moving and frame != 0 else 0
	var behind := sin(aim) < -0.3
	var ga := UiDraw.alpha
	UiDraw.alpha = a
	if behind:
		_draw_lantern()
	Spr.draw(self, "player", frame, x, y + bob, {"flip": facing < 0, "flash": dash_t > 0 and Fx.vis.next() < 0.3})
	if not behind:
		_draw_lantern()
	UiDraw.alpha = ga
	if guard_up:
		UiDraw.alpha = 0.5 + 0.2 * sin(Fx.time * 6)
		UiDraw.px_ring(self, x, y, 11, "#7fd8e6")
		UiDraw.alpha = ga
	UiDraw.set_origin(self, Vector2.ZERO)
