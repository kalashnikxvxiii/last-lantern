class_name Flow
extends RefCounted
# Run flow (js/game.js): start, floors, rooms, doors, transitions, update.

# character_id: Godot-only
static func start_run(lantern_id: String, ardor: int, seed: int = -1, character_id := "wanderer") -> void:
	Run.reset()
	Cheats.reset()   # Godot-only: the developer toggles do not carry into a new run
	if seed < 0:
		seed = int(U.random() * 2147483648.0)
	Run.active = true
	Run.seed = seed
	Run.rng = RNG.new(seed)
	Run.ardor = ardor
	var p := Player.new()
	p.lantern = lantern_id
	p.character = character_id
	Run.player = p
	p.recalc_stats()
	DB.lantern(lantern_id).on_start(p)
	p.recalc_stats()
	p.hp = p.stats.maxHp
	p.oil = p.stats.maxOil
	p.dash_charges = int(p.stats.dashCharges)
	p.guard_t = 2.0
	Save.data.stats.runs += 1
	Save.write()
	Particles.clear()
	Floaters.clear()
	new_floor()
	Run.toast("Find the warden and descend deeper.", "#e8dcc0", "Press TAB for the map, ESC to pause.")

# Godot-only: holding R in the play scene (Play.update_play). The kills of the
# abandoned descent count like a surrender, then the same lantern and Ardor
# start over on a new seed, in the same save slot.
static func restart_run() -> void:
	var p := Run.player
	if not Run.cheated:
		Save.data.stats.kills += Run.kills
		Save.write()
	var slot := Run.slot
	RunSave.erase(slot)
	start_run(p.lantern, Run.ardor)
	Run.slot = slot if RunSave.save(slot) else -1

# Godot-only: the lantern glow of the restart hold. Shared by the light it
# casts (Lights.collect) and by the dust it turns enemies into; empty while
# the restart is off or the player is dead (Play.update_play)
static func restart_glow() -> Dictionary:
	var p := Run.player
	if p == null or p.dead:
		return {}
	if Run.restart_flare >= 0.0:
		return {"x": p.x + cos(p.aim) * 7, "y": p.y - 1 + sin(p.aim) * 4,
			"r": Consts.RESTART_R, "f": 1.0}
	if Run.restart_t <= 0.0:
		return {}
	var f := clampf(Run.restart_t / Consts.RESTART_HOLD, 0, 1)
	f = f * f   # a slow start, then the light rushes out
	return {"x": p.x + cos(p.aim) * 7, "y": p.y - 1 + sin(p.aim) * 4,
		"r": lerpf(20.0, Consts.RESTART_R, f), "f": f}

# Godot-only: the enemies the restart light turns into ash piles. While
# dust_t > 0 they stand still and deal no contact damage (enemy.gd); any
# cancel of the hold reassembles them (called from Play.update_play)
static func restart_dust_tick(dt: float) -> void:
	var g := restart_glow()
	for i in Run.enemies.size():
		var e: Enemy = Run.enemies[i]
		var on: bool = not g.is_empty() and not e.dead and U.dist(g.x, g.y, e.x, e.y) <= g.r
		if on and not e.dusted:
			_incinerate(e)
		e.dusted = on
		var rate: float = Consts.RESTART_DUST_T if on else Consts.RESTART_UNDUST_T
		e.dust_t = move_toward(e.dust_t, 1.0 if on else 0.0, dt / rate)
	if g.is_empty():
		return
	# Godot-only: the light ashes the enemy bullets already in flight too, so
	# they cannot reach the rooted player (Bullets.update_enemy sweeps the dead)
	for b in Run.ebullets:
		if b.get("dead", false) or U.dist(g.x, g.y, b.x, b.y) > g.r:
			continue
		b.dead = true
		Particles.burst(b.x, b.y, 3, ["#55505e", "#a59fb0", "#e8e4dc"], 40, 0.25)

# the one-shot beat: the flash that lights the pile up, the sizzle and the
# body scattering into ash from its own pixels
static func _incinerate(e: Enemy) -> void:
	e.flash = 0.12
	Sfx.play("ash", 0.55)
	var st := e.sprite_state()
	if st.is_empty():
		return
	var px: Array = Spr.body_pixels(str(st.name), int(st.frame))
	for off in px:
		Particles.add({"x": e.x + off.x, "y": e.y - e.z + off.y,
			"vx": U.rnd(-14.0, 14.0), "vy": U.rnd(-55.0, -18.0), "life": U.rnd(0.45, 0.9),
			"color": U.pick(["#55505e", "#a59fb0", "#8a8294", "#e8e4dc"]),
			"size": 1.0 if U.chance(0.3) else 2.0, "grav": -20.0, "drag": 1.5})

static func restart_dust_clear() -> void:
	for i in Run.enemies.size():
		var e: Enemy = Run.enemies[i]
		e.dusted = false
		e.dust_t = 0.0

static func new_floor() -> void:
	var p := Run.player
	Run.floor = FloorGen.gen_floor(Run.depth, Run.rng)
	p.secondwind_used = false
	if p.stats.mapReveal:
		for r in Run.floor.rooms:
			r.seen = true
			if r.type == "secret":
				r.mapped = true
	enter_room(Run.floor.start, null)
	Run.intro = {"t": 0.0, "depth": Run.depth}
	var b := DB.biome_of(Run.depth)
	Music.play(b.music)
	Music.set_intensity(0)
	if Run.depth > Save.data.stats.bestDepth and not Run.cheated:
		Save.data.stats.bestDepth = Run.depth
		Save.write()
	check_unlocks()

static func check_unlocks() -> void:
	for L in DB.lanterns():
		if Save.data.unlocks.lanterns.has(L.id):
			continue
		if L.unlocked(Save.data.stats):
			Save.unlock_lantern(L.id)
			if Run.active:
				Run.new_unlocks.append(L.name)
				Run.toast("New lantern unlocked", "#f6cf57", L.name)
	# Godot-only
	for C in DB.characters():
		if Save.data.unlocks.characters.has(C.id) or not C.unlocked(Save.data.stats):
			continue
		Save.unlock_character(C.id)
		if Run.active:
			Run.new_unlocks.append(C.name)
			Run.toast("New character unlocked", "#f6cf57", C.name)

# through: Godot-only, walked in through the doorway: the room starts once the
# player is past its gate (Flow.check_doors)
static func enter_room(room: Dictionary, from_dir: Variant, through := false) -> void:
	var p := Run.player
	Run.room = room
	if not room.built:
		RoomBuilder.build_room(room, Run.floor)
	room.visited = true
	room.seen = true
	for d in room.doors:
		if RoomU.door_visible(room, d):
			room.doors[d].seen = true
	if from_dir != null:
		var pos := RoomU.door_entry(RoomU.DIRS[from_dir].opp)
		p.x = pos.x
		p.y = pos.y
	else:
		var c := RoomU.tile_center(14, 7)
		p.x = c.x
		p.y = c.y + 20
	p.dash_t = 0.0
	Run.bullets = []
	Run.ebullets = []
	Run.clear_enemies()
	Run.fx = []
	Run.pull = null
	Run.flow = PackedInt32Array()
	Run.flow_t = 0.0
	Run.boss_ref = null
	Particles.clear()
	if not through:
		room.erase("entering")   # left by a save made in the doorway
		start_room(room)
	if room.type == "shop" and not room.get("greeted", false):
		room.greeted = true
		Sfx.play("coin")
	if room.type == "secret" and not room.get("greeted", false):
		room.greeted = true
		Run.toast("A forgotten room", "#f6cf57")

# the fight of enterRoom: gates, waves, music
static func start_room(room: Dictionary) -> void:
	if not room.cleared:
		room.combat = true
		room.waveIdx = 0
		room.waveDelay = 0.3
		Sfx.play("lock")
		if room.type == "boss":
			Run.boss_intro = {"t": 0.0, "B": DB.boss(room.waves[0][0].boss)}
			room.waveDelay = 1.2
			Sfx.play("roar")
			Music.set_intensity(2)
		else:
			Music.set_intensity(1)
		if room.type == "elite":
			Run.toast("Challenge Hall", "#e0574a", "Survive the champions for a prize.")
	else:
		room.combat = false
		Music.set_intensity(0)

static func descend() -> void:
	if Run.trans != null:
		return
	Sfx.play("descend")
	Run.trans = {"t": 0.0, "kind": "descend", "swapped": false}

static func check_doors(dt: float) -> void:
	var p := Run.player
	var room := Run.room
	var rx := Consts.RX
	var ry := Consts.RY
	var ts := Consts.TS
	Run.lock_msg_t -= dt
	# Godot-only: past the gate the room starts; until then the way back is open
	if room.has("entering") and RoomU.clear_of_door(room.entering, p.x, p.y, p.r):
		room.erase("entering")
		start_room(room)
	for d in room.doors:
		if not RoomU.door_visible(room, d):
			continue
		var dc := RoomU.door_center(d)
		if RoomU.door_locked(room, d):
			if not room.combat and U.dist(p.x, p.y, dc.x, dc.y) < 26:
				if p.keys > 0:
					p.keys -= 1
					room.doors[d].locked = false
					Sfx.play("lock")
					Sfx.play("chest")
					Run.toast("You use a key", "#f6cf57")
				elif Run.lock_msg_t <= 0:
					Run.toast("The door is locked", "#8a8294")
					Run.lock_msg_t = 2.5
			continue
		if not RoomU.door_open(room, d):
			continue
		# Godot-only: the rooms lie side by side, so the player changes room on the
		# edge between them, with no fade and no pause, and goes on from the same spot:
		# moving, dashing, the shots in flight. The camera follows (View3D.start_pan).
		var go := false
		match d:
			"n": go = p.y < ry and absf(p.x - dc.x) < 26
			"s": go = p.y > ry + Consts.RH * ts and absf(p.x - dc.x) < 26
			"w": go = p.x < rx and absf(p.y - dc.y) < 26
			"e": go = p.x > rx + Consts.RW * ts and absf(p.y - dc.y) < 26
		if go:
			var off := RoomU.room_offset(d)
			var at := Vector2(p.x - off.x, p.y - off.y)
			var dash := p.dash_t
			var shots: Array = Run.bullets
			var parts: Array = Particles.list.duplicate()
			room.erase("entering")
			enter_room(room.doors[d], d, true)
			p.x = at.x
			p.y = at.y
			p.dash_t = dash
			for o in shots + parts:
				o.x -= off.x
				o.y -= off.y
			Run.bullets = shots
			Particles.list.append_array(parts)
			Run.room.entering = RoomU.DIRS[d].opp
			return

static func update_trans(dt: float) -> void:
	var tr: Dictionary = Run.trans
	tr.t += dt
	var half := 0.7
	if not tr.swapped and tr.t >= half:
		tr.swapped = true
		Run.depth += 1
		new_floor()
	if tr.t >= half * 2:
		Run.trans = null

static func trans_alpha() -> float:
	var tr: Variant = Run.trans
	if tr == null:
		return 0.0
	var half := 0.7
	return tr.t / half if tr.t < half else maxf(0.0, 1 - (tr.t - half) / half)

# updateGame: later tasks add the other lines in the JS order
static func update_game(dt: float) -> void:
	Run.time += dt
	Run.player.tick(dt)
	Run.flow_t -= dt
	if Run.flow_t <= 0:
		FlowField.update()
		Run.flow_t = 0.18
	Enemy.update_all(dt)
	Bullets.update_player(dt)
	Bullets.update_enemy(dt)
	Effects.update(dt)
	Pickups.update(dt)
	update_room_flow(dt)
	Run.focus = null if Run.player.dead else Interact.nearest_object()
	if Run.focus != null and Controls.interact():
		Interact.interact(Run.focus)
	if not Run.player.dead:
		check_doors(dt)
	for o in Run.oil_fx:
		o.t += dt
	Run.oil_fx = Run.oil_fx.filter(func(o): return o.t < 0.45)

static func update_common(dt: float) -> void:
	Particles.update(dt)
	Floaters.update(dt)
	Run.update_notices(dt)
	Fx.decay(dt)
	if Run.flash_light != null:
		Run.flash_light.t -= dt
		if Run.flash_light.t <= 0:
			Run.flash_light = null
	if Run.intro != null:
		Run.intro.t += dt
		if Run.intro.t > 4.5:
			Run.intro = null
	if Run.boss_intro != null:
		Run.boss_intro.t += dt
		if Run.boss_intro.t > 2.8:
			Run.boss_intro = null

static func update_room_flow(dt: float) -> void:
	var room := Run.room
	if not room.combat:
		return
	var pending := Run.fx.any(func(f): return f.type == "spawn")
	if Run.enemies.is_empty() and not pending:
		room.waveDelay -= dt
		if room.waveDelay <= 0:
			if room.waveIdx < room.waves.size():
				spawn_wave(room, room.waves[room.waveIdx])
				room.waveIdx += 1
				room.waveDelay = 0.6
			elif room.type != "boss":
				room_cleared(room)

static func spawn_wave(room: Dictionary, wave: Array) -> void:
	var p := Run.player
	if wave[0].type == "BOSS":
		var c := RoomU.tile_center(14, 7)
		var y := c.y + 30 if p.y < c.y else c.y - 30
		Effects.add({"type": "spawn", "x": c.x, "y": y, "life": 1.0, "spec": {"type": "BOSS", "boss": wave[0].boss}})
		return
	var all: Array = RoomU.reach_tiles(room).filter(func(t): return room.grid[t.y][t.x] == Consts.T.FLOOR)
	var tiles: Array = all.filter(func(t):
		var c := RoomU.tile_center(t.x, t.y)
		return U.dist(c.x, c.y, p.x, p.y) > 100)
	if tiles.size() < wave.size():
		tiles = all.filter(func(t):
			var c := RoomU.tile_center(t.x, t.y)
			return U.dist(c.x, c.y, p.x, p.y) > 50)
	U.shuffle(tiles)
	for i in wave.size():
		var spec: Dictionary = wave[i]
		var t: Vector2i = tiles[i % tiles.size()]
		var c := RoomU.tile_center(t.x, t.y)
		Effects.add({"type": "spawn", "x": c.x + U.rnd(-2, 2), "y": c.y + U.rnd(-2, 2), "life": 0.75 + i * 0.05, "spec": {"type": spec.type, "mod": spec.mod}})
	Sfx.play("spawn")

static func room_cleared(room: Dictionary) -> void:
	room.cleared = true
	room.combat = false
	Run.rooms_cleared += 1
	Sfx.play("door")
	Music.set_intensity(0)
	var c := RoomU.tile_center(14, 7)
	var rx := c.x
	var ry := c.y
	if room.grid[7][14] != Consts.T.FLOOR:
		rx = Run.player.x
		ry = Run.player.y - 20
	if room.type == "elite":
		room.objects.append({"type": "chest", "gold": true, "free": true, "x": rx - 20, "y": ry})
		var r: Array = RoomBuilder.random_relics(1)
		if not r.is_empty():
			room.objects.append({"type": "relic", "id": r[0], "x": rx + 20, "y": ry})
		Run.toast("Challenge complete!", "#f6cf57")
		return
	if U.random() < 0.5:
		var kind: String = U.weighted_pick([["coins", 30], ["heart", 18], ["oil", 18], ["cons", 14], ["key", 9], ["chest", 11]], func(k): return k[1])[0]
		var pk: Array = room.pickups
		match kind:
			"coins":
				var i := 0
				while i < U.rndi(2, 4):
					pk.append(Pickups.make("coin", rx, ry))
					i += 1
			"heart": pk.append(Pickups.make("heart", rx, ry))
			"oil": pk.append(Pickups.make("oil", rx, ry, {"value": 30}))
			"cons": pk.append(Pickups.make("cons", rx, ry, {"id": Pickups.random_cons()}))
			"key": pk.append(Pickups.make("key", rx, ry))
			_: room.objects.append({"type": "chest", "gold": U.random() < 0.3, "x": rx, "y": ry})
		Particles.burst(rx, ry, 16, ["#f6cf57", "#fff2a8"], 60, 0.6)

static func reveal_map() -> void:
	for r in Run.floor.rooms:
		r.seen = true
		if r.type == "secret":
			r.mapped = true
	Run.toast("The map is revealed", "#d8c49a")
	Sfx.play("pickup")

static func roll_dice() -> void:
	var p := Run.player
	var ch := Perks.roll_choices(1, 0)
	if not ch.is_empty():
		var id: String = ch[0]
		p.perks[id] = p.perks.get(id, 0) + 1
		p.recalc_stats()
		if Perks.ALL[id].get("onTake", false):
			Perks.on_take(id, p)
		Run.banner(Perks.ALL[id].name, Perks.ALL[id].desc, Stats.RARITY[Perks.ALL[id].rar].col, Perks.ALL[id].icon)
	if U.random() < 0.3:
		var avail: Array = Curses.ALL.keys().filter(func(c): return not p.curses.has(c))
		if not avail.is_empty():
			var c: String = U.pick(avail)
			p.curses.append(c)
			p.recalc_stats()
			U.later(0.7, func(): Run.toast(Loc.f("Curse: {0}", [Loc.t(Curses.ALL[c].name)]), "#c57ae0", Curses.ALL[c].desc))
			Sfx.play("curse")
	Sfx.play("pickup")

static func on_boss_defeated(e) -> void:
	var room := Run.room
	var p := Run.player
	room.cleared = true
	room.combat = false
	var c := RoomU.tile_center(14, 7)
	var final_boss: bool = e.bid == "devourer" and not Run.won
	if not final_boss:
		room.objects.append({"type": "trapdoor", "x": c.x, "y": c.y + 34})
	var r: Array = RoomBuilder.random_relics(1)
	if not r.is_empty():
		room.objects.append({"type": "relic", "id": r[0], "x": c.x, "y": c.y - 16})
	for i in 2:
		room.pickups.append(Pickups.make("heart", e.x, e.y))
	for i in 6 + Run.depth * 2:
		room.pickups.append(Pickups.make("coin5" if U.random() < 0.2 else "coin", e.x, e.y))
	for i in 10:
		room.pickups.append(Pickups.make("xp", e.x, e.y, {"value": e.xp / 10}))
	p.heal(U.jround(p.stats.maxHp * 0.3), true)
	p.add_oil(p.stats.maxOil)
	Run.toast(Loc.f("{0} has fallen", [Loc.t(e.display_name)]), "#f6cf57", "A trapdoor opens downward.")
	check_unlocks()
	if e.bid == "devourer" and not Run.won:
		Run.won = true
		Run.victory_t = 3.2
