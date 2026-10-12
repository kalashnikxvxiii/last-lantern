class_name Flow
extends RefCounted
# Flusso della run (js/game.js): avvio, piani, stanze, porte, transizioni, aggiornamento.

static func start_run(lantern_id: String, ardore: int, seed: int = -1) -> void:
	Run.reset()
	if seed < 0:
		seed = int(U.random() * 2147483648.0)
	Run.active = true
	Run.seed = seed
	Run.rng = RNG.new(seed)
	Run.ardore = ardore
	var p := Player.new()
	p.lantern = lantern_id
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
	Run.toast("Trova il guardiano e scendi più in basso.", "#e8dcc0", "Premi TAB per la mappa, ESC per la pausa.")

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
	if Run.depth > Save.data.stats.bestDepth:
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
				Run.toast("Nuova lanterna sbloccata", "#f6cf57", L.name)

static func enter_room(room: Dictionary, from_dir: Variant) -> void:
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
			Run.toast("Sala della Sfida", "#e0574a", "Sopravvivi ai campioni per un premio.")
	else:
		room.combat = false
		Music.set_intensity(0)
	if room.type == "shop" and not room.get("greeted", false):
		room.greeted = true
		Sfx.play("coin")
	if room.type == "secret" and not room.get("greeted", false):
		room.greeted = true
		Run.toast("Una stanza dimenticata", "#f6cf57")

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
					Run.toast("Usi una chiave", "#f6cf57")
				elif Run.lock_msg_t <= 0:
					Run.toast("La porta è chiusa a chiave", "#8a8294")
					Run.lock_msg_t = 2.5
			continue
		if not RoomU.door_open(room, d):
			continue
		var go := false
		match d:
			"n": go = p.y < ry + 11 and absf(p.x - dc.x) < 26
			"s": go = p.y > ry + (Consts.RH - 1) * ts + 5 and absf(p.x - dc.x) < 26
			"w": go = p.x < rx + 11 and absf(p.y - dc.y) < 26
			"e": go = p.x > rx + (Consts.RW - 1) * ts + 5 and absf(p.y - dc.y) < 26
		if go:
			Run.trans = {"t": 0.0, "kind": "room", "to": room.doors[d], "dir": d, "swapped": false}
			return

static func update_trans(dt: float) -> void:
	var tr: Dictionary = Run.trans
	tr.t += dt
	var half := 0.7 if tr.kind == "descend" else 0.13
	if not tr.swapped and tr.t >= half:
		tr.swapped = true
		if tr.kind == "room":
			enter_room(tr.to, tr.dir)
		else:
			Run.depth += 1
			new_floor()
	if tr.t >= half * 2:
		Run.trans = null

static func trans_alpha() -> float:
	var tr: Variant = Run.trans
	if tr == null:
		return 0.0
	var half := 0.7 if tr.kind == "descend" else 0.13
	return tr.t / half if tr.t < half else maxf(0.0, 1 - (tr.t - half) / half)

# updateGame: i task successivi aggiungono le altre righe nell'ordine del JS
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
		Run.toast("Sfida superata!", "#f6cf57")
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
	Run.toast("La mappa si rivela", "#d8c49a")
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
			U.later(0.7, func(): Run.toast("Maledizione: " + Curses.ALL[c].name, "#c57ae0", Curses.ALL[c].desc))
			Sfx.play("curse")
	Sfx.play("pickup")
