class_name Enemy
extends Node2D
# Enemy (makeEnemy, updateEnemies, drawEnemy in js/entities.js and js/render.js).
# x, y are the JS logical coordinates; position aligns at the end of the tick.

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
var dusted := false   # Godot-only: inside the restart light (Flow)
var dust_t := 0.0     # Godot-only: 0..1 burn-to-ash progress, reassembles back
var dead := false
var boss := false
var hit_wall := false
var shield_down := false
var wander: Variant = null
var wander_t: Variant = null
# fields the JS AIs create on the fly
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
var ha: Variant = null
var ph := 0
var jx0 := 0.0
var jy0 := 0.0
var jx1 := 0.0
var jy1 := 0.0
var lunge_a := 0.0
var dash_a := 0.0
var sum_t: Variant = null
var spin_a := 0.0
var fire_acc := 0.0
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

# only bosses die slowly (bossDying); Boss overrides it
func dying_update(_dt: float) -> void:
	pass

# enemyTarget: with the player invisible, wander between reachable cells
# (Godot-only: also when this enemy is blinded, by the Goblin's Smoke Bomb)
func target():
	var p := Run.player
	if p.statuses.has("invis") or statuses.has("blind"):
		if wander == null or wander_t <= 0:
			var tiles := RoomU.reach_tiles(Run.room)
			var tt: Vector2i = U.pick(tiles)
			var c := RoomU.tile_center(tt.x, tt.y)
			wander = {"x": c.x, "y": c.y}
			wander_t = U.rnd(1, 2)
		return wander
	return p

# body of the updateEnemies loop
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
	elif Cheats.freeze:   # Godot-only: stands still without the frozen status; like it, the AI timers wait
		vx = 0.0
		vy = 0.0
	elif dust_t > 0.0:   # Godot-only: while it is ash, the pile of the restart light stands still
		vx = 0.0
		vy = 0.0
	else:
		var m := 0.55 if statuses.has("chill") else 1.0
		think(dt, target(), m)
	# movement + knockback
	var kx := kbx * dt
	var ky := kby * dt
	kbx *= maxf(0, 1 - 9 * dt)
	kby *= maxf(0, 1 - 9 * dt)
	if Coll.move_actor(self, vx * dt + kx, vy * dt + ky, fly or z > 4):
		hit_wall = true
	if not boss and absf(vx) > 1 and ai != "shielder":
		facing = atan2(vy, vx)
	# contact
	if not intangible and z < 6 and not spawning and not p.dead and frozen <= 0 and not Cheats.freeze and dust_t <= 0.0:
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
	# separation
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

# sprite, frame and effects of drawEnemy, shared by the 2D drawing and the 3D view
func sprite_state() -> Dictionary:
	if dead or spawning or not Run.active or not Spr.has(_spr_name()):
		return {}
	var spr := _spr_name()
	var anim_speed: float = def.anim if def != null and def.anim > 0 else 5.0
	var fr := int(floor(anim * anim_speed)) % Spr.frame_count(spr)
	var flip := false
	if def != null and def.side:
		flip = cos(facing) < 0
	elif not boss:
		flip = cos(U.ang_to(x, y, Run.player.x, Run.player.y)) < 0 and ai != "turret"
	var t := Fx.time
	var wind_blink := wind > 0 and sin(t * 40) > 0
	var o := {"flip": flip, "flash": flash > 0 or (wind_blink and not boss), "alpha": alpha * _body_a()}
	if boss and wind > 0:
		o.tint = "#e0574a"
		o.tintA = 0.25 + 0.2 * sin(t * 30)
	if frozen > 0 or Cheats.freeze:
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
	if dust_t > 0.0:
		# Godot-only: while the body is ash it is not drawn (the pile in _draw
		# takes its place); on release it dissolves back in, ash-grey, as the
		# pile reassembles (Flow.restart_dust_tick)
		if not dusted:
			o.tint = "#8a8294"
			o.tintA = 0.7 * (1.0 - dust_t)
	return {"name": spr, "frame": fr, "x": x, "y": y - z, "o": o}

# how much of the body is drawn: nothing while it is ash (the pile in _draw
# stands in for it), fading back in while the ash reassembles
func _body_a() -> float:
	if dusted:
		return 0.0
	return 1.0 - dust_t if dust_t > 0.0 else 1.0

# drawEnemy (js/render.js), in world coordinates
func _draw() -> void:
	if dead or not Run.active:
		return
	var spr := _spr_name()
	if not Spr.has(spr):
		return
	UiDraw.set_origin(self, -position)
	var S := Spr.size(spr)
	var yy := y - z
	var body_a := _body_a()
	if alpha > 0.05 and body_a > 0.003:
		var gs := UiDraw.alpha
		UiDraw.alpha = gs * body_a
		UiDraw.shadow(self, x, y + S.y / 2.0 - 1, maxf(4, r * (0.8 if z > 0 else 1.0)))
		UiDraw.alpha = gs
	if dust_t > 0.0:
		# Godot-only: the ash pile that stands in for the body: the hit flash
		# lights it up, then it fades in over the first ~0.1 s of the burn, is
		# opaque once the body is gone and fades away with the reassembly
		# (Flow.restart_dust_tick)
		var pile := _ash_pile()
		if pile != null:
			var fl := clampf(flash / 0.12, 0.0, 1.0)
			var pa := maxf(minf(1.0, dust_t * 3.5), fl)
			draw_texture_rect(pile, Rect2(U.jround(x) - 8, U.jround(y + S.y / 2.0 - 5), 16, 16),
				false, Color(1.0 + 1.8 * fl, 1.0 + 1.7 * fl, 1.0 + 0.6 * fl, pa))
	if spawning:
		UiDraw.set_origin(self, Vector2.ZERO)
		return
	var t := Fx.time
	var st := sprite_state()
	var fr: int = st.frame
	var flip: bool = st.o.flip
	if elite and alpha > 0.3 and body_a > 0.003 and not View3D.on:
		var col: String = EliteMods.ALL[mod].col
		var ga := UiDraw.alpha
		UiDraw.alpha = (0.45 + 0.25 * sin(t * 6)) * body_a
		var dx := U.jround(x - S.x / 2.0)
		var dy := U.jround(yy - S.y / 2.0)
		for off in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
			Spr.draw_sil(self, spr, fr, dx + off[0], dy + off[1], col, flip)
		UiDraw.alpha = ga
	if not View3D.on:   # the 3D view stands them up
		if body_a > 0.003:
			Spr.draw(self, spr, fr, x, yy, st.o)
			var ge := UiDraw.alpha
			UiDraw.alpha = ge * body_a
			draw_extras(self)
			UiDraw.alpha = ge
		if dust_t > 0.05 and dust_t < 1.0:
			# Godot-only: ash motes while the pile burns or reassembles; the
			# finished pile is still (draw code: Fx.time only)
			var ga := UiDraw.alpha
			var n := int(lerpf(12.0, 5.0, dust_t))
			for k in n:
				var u := fmod(t * 0.7 + float(k) * 0.21, 1.0)
				UiDraw.alpha = ga * 0.7 * (1.0 - u) * minf(1.0, dust_t * 2.0)
				UiDraw.px_rect(self, U.jround(x + (float(k) - 2.0) * 0.12 * S.x),
					U.jround(yy - 2.0 - u * 9.0), 2, 2, "#e8e4dc" if k % 2 == 0 else "#a59fb0")
			UiDraw.alpha = ga
	UiDraw.set_origin(self, Vector2.ZERO)

static var _ash_piles: Array[Texture2D] = []

# one decal variant per enemy type, stable across re-dustings (no RNG)
func _ash_pile() -> Texture2D:
	if _ash_piles.is_empty():
		for i in 3:
			var p := "res://assets/sprites/ash_pile_%d.png" % (i + 1)
			if ResourceLoader.exists(p):
				var t: Texture2D = load(p)
				_ash_piles.append(t)
	if _ash_piles.is_empty():
		return null
	return _ash_piles[absi(type.hash()) % _ash_piles.size()]

# front shield and health bar (drawEnemy)
func draw_extras(ci: CanvasItem) -> void:
	if _body_a() <= 0.003:   # Godot-only: ash wears no bar and no shield
		return
	var yy := y - z
	if def != null and def.shield:
		var a := facing + 1.3 if shield_down else facing
		var rr := r + 4
		ci.draw_arc(Vector2(x, yy), rr, a - 0.9, a + 0.9, 16, UiDraw._a("#0b0810"), 4)
		ci.draw_arc(Vector2(x, yy), rr, a - 0.85, a + 0.85, 16, UiDraw._a("#c0c8d0" if type == "knight" else "#8a5a34"), 2)
	if not boss and hp < max_hp and alpha > 0.4:
		var w := maxf(10, r * 2 + 2)
		UiDraw.bar(ci, x - w / 2, yy - Spr.size(_spr_name()).y / 2.0 - 4, w, 1, hp / max_hp, EliteMods.ALL[mod].col if elite else "#d04b3c")
