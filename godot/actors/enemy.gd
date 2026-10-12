class_name Enemy
extends Node2D
# Nemico (makeEnemy, updateEnemies, drawEnemy in js/entities.js e js/render.js).
# x, y sono le coordinate logiche del JS; position si allinea a fine tick.

var type := ""
var def: EnemyDef
var display_name := ""
var x := 0.0
var y := 0.0
var vx := 0.0
var vy := 0.0
var r := 5.0
var hp := 1.0
var max_hp := 1.0
var spd := 0.0
var dmg := 0.0
var ai := ""
var fly := false
var st := 0.0
var state := "idle"
var shot_cd := 0.0
var flash := 0.0
var statuses: Dictionary = {}
var frozen := 0.0
var freeze_cd := 0.0
var stun := 0.35
var facing := 0.0
var anim := 0.0
var mod: Variant = null
var kbx := 0.0
var kby := 0.0
var xp := 0.0
var z := 0.0
var alpha := 1.0
var intangible := false
var wind := 0.0
var orb_cd := 0.0
var t := 0.0
var elite := false
var no_split := false
var summoned := false
var summoner: Variant = null
var spawning := false
var dead := false
var boss := false
var hit_wall := false
var shield_down := false
var wander: Variant = null
var wander_t: Variant = null
# campi che le AI del JS creano al volo
var jit: Variant = null
var jit_t := 0.0
var charge_a := 0.0
var trail_t := 0.0
var orbit_dir := 0
var burst_left := 0
var burst_t := 0.0
var charge_line: Variant = null
var slam_target: Variant = null
var dying: Variant = null
var invuln := 0.0

static func make(type_: String, x_: float, y_: float, mod_: Variant = null, o: Dictionary = {}) -> Enemy:
	var D := DB.enemy(type_)
	var d := Run.depth
	var e := Enemy.new()
	var hp_ := D.hp * Stats.depth_hp(d) * Stats.ard_hp()
	e.type = type_
	e.def = D
	e.display_name = D.name
	e.x = x_
	e.y = y_
	e.r = D.r
	e.hp = hp_
	e.max_hp = hp_
	e.spd = D.spd * (1 + 0.03 * (d - 1)) * Run.player.stats.enemySpeed
	e.dmg = D.dmg * Stats.depth_dmg(d) * Stats.ard_dmg()
	e.ai = D.ai
	e.fly = D.fly
	e.shot_cd = U.rnd(0.9, 1.8) + (D.shot.get("cd", 2.0) * 0.4 if not D.shot.is_empty() else 0.0)
	e.anim = U.rnd(0, 3)
	e.mod = mod_
	e.xp = D.xp * 2 * (1 + 0.15 * (d - 1))
	e.t = U.rnd(0, 5)
	if mod_ != null:
		e.elite = true
		e.hp *= 1.6
		e.xp *= 2.2
		if mod_ == "armored":
			e.hp *= 1.5
		if mod_ == "swift":
			e.spd *= 1.4
		e.max_hp = e.hp
	if o.get("small", false):
		e.hp *= 0.5
		e.max_hp = e.hp
		e.no_split = true
	if not Run.room.is_empty() and Run.player.stats.bellStun and not o.get("summoned", false):
		e.stun = maxf(e.stun, Run.player.stats.bellStun)
	e.position = Vector2(x_, y_)
	return e

func think(dt: float, tg, m: float) -> void:
	AI.run(self, dt, tg, m)

# solo i boss muoiono lentamente (bossDying); il Boss la sovrascrive
func dying_update(_dt: float) -> void:
	pass

# enemyTarget: con il giocatore invisibile si vaga tra caselle raggiungibili
func target():
	var p := Run.player
	if p.statuses.has("invis"):
		if wander == null or wander_t <= 0:
			var tiles := RoomU.reach_tiles(Run.room)
			var tt: Vector2i = U.pick(tiles)
			var c := RoomU.tile_center(tt.x, tt.y)
			wander = {"x": c.x, "y": c.y}
			wander_t = U.rnd(1, 2)
		return wander
	return p

# corpo del ciclo di updateEnemies
func tick(dt: float) -> void:
	var p := Run.player
	anim += dt
	flash -= dt
	orb_cd -= dt
	if freeze_cd > 0:
		freeze_cd -= dt
	hit_wall = false
	if wander_t != null:
		wander_t -= dt
	Status.update(self, dt, false)
	if dead:
		return
	if mod == "regen" and hp < max_hp:
		hp = minf(max_hp, hp + max_hp * 0.03 * dt)
	if dying != null:
		dying_update(dt)
		return
	if frozen > 0:
		frozen -= dt
		vx = 0.0
		vy = 0.0
	elif stun > 0:
		stun -= dt
		vx = 0.0
		vy = 0.0
	else:
		var m := 0.55 if statuses.has("chill") else 1.0
		think(dt, target(), m)
	# movimento + spinta
	var kx := kbx * dt
	var ky := kby * dt
	kbx *= maxf(0, 1 - 9 * dt)
	kby *= maxf(0, 1 - 9 * dt)
	if Coll.move_actor(self, vx * dt + kx, vy * dt + ky, fly or z > 4):
		hit_wall = true
	if not boss and absf(vx) > 1 and ai != "shielder":
		facing = atan2(vy, vx)
	# contatto
	if not intangible and z < 6 and not spawning and not p.dead and frozen <= 0:
		var rr := r + p.r
		if U.dist2(x, y, p.x, p.y) < rr * rr:
			if Combat.hurt_player(dmg, display_name):
				if def != null and def.touch != "":
					Status.add(p, def.touch, 2.5)
				if mod == "venom":
					Status.add(p, "poison", 3)
				if mod == "vampiric":
					hp = minf(max_hp, hp + max_hp * 0.15)
				if p.stats.thorns:
					Combat.hit_enemy(self, p.damage() * p.stats.thorns, {"kx": x - p.x, "ky": y - p.y, "kb": 150})

static func update_all(dt: float) -> void:
	var i := 0
	while i < Run.enemies.size():
		var e: Enemy = Run.enemies[i]
		if not e.dead:
			e.tick(dt)
		i += 1
	# separazione
	var en := Run.enemies
	for a_i in en.size():
		var a: Enemy = en[a_i]
		if a.dead or a.boss:
			continue
		for b_i in range(a_i + 1, en.size()):
			var b: Enemy = en[b_i]
			if b.dead or b.boss or a.fly != b.fly:
				continue
			var dx := b.x - a.x
			var dy := b.y - a.y
			var rr := a.r + b.r
			var d2 := dx * dx + dy * dy
			if d2 < rr * rr and d2 > 0.01:
				var d := sqrt(d2)
				var push := (rr - d) * 0.5
				var nx := dx / d
				var ny := dy / d
				Coll.move_actor(a, -nx * push, -ny * push, a.fly)
				Coll.move_actor(b, nx * push, ny * push, b.fly)
	Run.prune_enemies()

func sync() -> void:
	position = Vector2(x, y)
	queue_redraw()

func _process(_delta: float) -> void:
	sync()

func _spr_name() -> String:
	return def.spr

# drawEnemy (js/render.js), in coordinate del mondo
func _draw() -> void:
	if dead or not Run.active:
		return
	var spr := _spr_name()
	if not Spr.has(spr):
		return
	UiDraw.set_origin(self, -position)
	var S := Spr.size(spr)
	var yy := y - z
	if alpha > 0.05:
		UiDraw.shadow(self, x, y + S.y / 2.0 - 1, maxf(4, r * (0.8 if z > 0 else 1.0)))
	if spawning:
		UiDraw.set_origin(self, Vector2.ZERO)
		return
	var anim_speed: float = def.anim if def != null and def.anim > 0 else 5.0
	var fr := int(floor(anim * anim_speed)) % Spr.frame_count(spr)
	var flip := false
	if def != null and def.side:
		flip = cos(facing) < 0
	elif not boss:
		flip = cos(U.ang_to(x, y, Run.player.x, Run.player.y)) < 0 and ai != "turret"
	var t := Fx.time
	var wind_blink := wind > 0 and sin(t * 40) > 0
	var o := {"flip": flip, "flash": flash > 0 or (wind_blink and not boss), "alpha": alpha}
	if boss and wind > 0:
		o.tint = "#e0574a"
		o.tintA = 0.25 + 0.2 * sin(t * 30)
	if frozen > 0:
		o.tint = "#9fe0ff"
		o.tintA = 0.55
	elif o.has("tint"):
		pass
	elif statuses.has("burn") and sin(t * 12) > 0.3:
		o.tint = "#f29c38"
		o.tintA = 0.35
	elif statuses.has("poison") and sin(t * 9) > 0.3:
		o.tint = "#8fd35a"
		o.tintA = 0.35
	elif statuses.has("chill"):
		o.tint = "#7fd8e6"
		o.tintA = 0.3
	if elite and alpha > 0.3:
		var col: String = EliteMods.ALL[mod].col
		var ga := UiDraw.alpha
		UiDraw.alpha = 0.45 + 0.25 * sin(t * 6)
		var dx := U.jround(x - S.x / 2.0)
		var dy := U.jround(yy - S.y / 2.0)
		for off in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
			Spr.draw_sil(self, spr, fr, dx + off[0], dy + off[1], col, flip)
		UiDraw.alpha = ga
	Spr.draw(self, spr, fr, x, yy, o)
	# scudo frontale
	if def != null and def.shield:
		var a := facing + 1.3 if shield_down else facing
		var rr := r + 4
		draw_arc(Vector2(x, yy), rr, a - 0.9, a + 0.9, 16, UiDraw._a("#0b0810"), 4)
		draw_arc(Vector2(x, yy), rr, a - 0.85, a + 0.85, 16, UiDraw._a("#c0c8d0" if type == "knight" else "#8a5a34"), 2)
	# barra vita
	if not boss and hp < max_hp and alpha > 0.4:
		var w := maxf(10, r * 2 + 2)
		UiDraw.bar(self, x - w / 2, yy - S.y / 2.0 - 4, w, 1, hp / max_hp, EliteMods.ALL[mod].col if elite else "#d04b3c")
	UiDraw.set_origin(self, Vector2.ZERO)
