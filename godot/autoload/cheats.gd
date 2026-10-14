extends Node
# Developer cheats: toggles read by the game logic and actions on the current run.
# Godot-only, there is no JS counterpart. Enabled in debug builds (editor and
# "godot --path godot"), in the "Dev" exports (feature tag "cheats") and in
# exported builds started with "-- --cheats".
# The panel that drives them is ui/cheat_menu.gd (F1 or ` during play).

const SPEEDS := [0.25, 0.5, 1.0, 2.0, 4.0]

var enabled := false
var god := false        # the player takes no damage
var inf_oil := false    # oil stays full
var noclip := false     # the player walks through walls and rocks
var one_shot := false   # every hit kills (wardens included)
var freeze := false     # enemies stand still and do no contact damage (Enemy.tick)
var info := false       # debug readout over the game
var speed_i := 2        # index in SPEEDS

func _ready() -> void:
	enabled = OS.is_debug_build() or OS.has_feature("cheats") or Game.dev.has("cheats")

func reset() -> void:
	god = false
	inf_oil = false
	noclip = false
	one_shot = false
	freeze = false
	info = false
	speed_i = 2

func speed() -> float:
	return SPEEDS[speed_i]

func any_active() -> bool:
	return god or inf_oil or noclip or one_shot or freeze or speed_i != 2

# once per game tick, after Flow.update_game
func tick() -> void:
	if not Run.active or Run.player == null:
		return
	var p := Run.player
	if inf_oil:
		p.oil = p.stats.maxOil

# ---------------------------------------------------------------- lists

static func enemy_ids() -> Array:
	var out: Array = []
	for f in ResourceLoader.list_directory("res://data/enemies/"):
		if f.ends_with(".tres"):
			out.append(f.get_basename())
	out.sort()
	return out

static func boss_ids() -> Array:
	var out: Array = []
	for i in DB.BIOME_IDS.size():
		var id: String = DB.biome_of(i + 1).boss
		if id != "" and not out.has(id):
			out.append(id)
	return out

static func room_types() -> Array:
	var out: Array = []
	for r in Run.floor.get("rooms", []):
		if not out.has(r.type):
			out.append(r.type)
	return out

# ---------------------------------------------------------------- player

func heal_full() -> void:
	var p := Run.player
	p.hp = p.stats.maxHp
	p.oil = p.stats.maxOil
	Status.cleanse(p)

func add_coins(n: int) -> void:
	Run.player.coins += n
	Run.coins_total += n

func add_keys(n: int) -> void:
	Run.player.keys += n

func level_up() -> void:
	var p := Run.player
	p.xp = 0.0
	p.level += 1
	Run.pending_levels += 1
	Run.level_delay = 0.0

func kill_player() -> void:
	var p := Run.player
	if p.dead:
		return
	p.secondwind_used = true
	p.coffin_used = true
	p.cons = p.cons.map(func(s): return null if s != null and s.id == "feather" else s)
	p.last_hit = "Cheats"
	p.hp = 0.0
	Combat.player_death()

# ---------------------------------------------------------------- build

func add_perk(id: String) -> bool:
	var p := Run.player
	if p.perks.get(id, 0) >= Perks.ALL[id]["max"]:
		return false
	p.perks[id] = p.perks.get(id, 0) + 1
	p.recalc_stats()
	if Perks.ALL[id].get("onTake", false):
		Perks.on_take(id, p)
	return true

func remove_perk(id: String) -> bool:
	var p := Run.player
	if p.perks.get(id, 0) <= 0:
		return false
	p.perks[id] -= 1
	if p.perks[id] <= 0:
		p.perks.erase(id)
	p.recalc_stats()
	return true

# adds the relic (with its curse, like picking it up) or removes it
func toggle_relic(id: String) -> void:
	var p := Run.player
	if p.relics.has(id):
		p.relics.erase(id)
		p.recalc_stats()
		return
	var R: Dictionary = Relics.ALL[id]
	p.relics.append(id)
	if R.has("curse") and not p.curses.has(R.curse):
		p.curses.append(R.curse)
	p.recalc_stats()
	if R.get("onTake", false):
		Relics.on_take(id, p)

func toggle_curse(id: String) -> void:
	var p := Run.player
	if p.curses.has(id):
		p.curses.erase(id)
	else:
		p.curses.append(id)
	p.recalc_stats()

func give_cons(id: String) -> bool:
	return Run.player.give_cons(id)

func set_lantern(id: String) -> void:
	var p := Run.player
	p.lantern = id
	p.recalc_stats()

func clear_build() -> void:
	var p := Run.player
	p.perks = {}
	p.relics = []
	p.curses = []
	p.temp_orbit = 0
	p.recalc_stats()

# ---------------------------------------------------------------- world

func kill_all() -> int:
	var n := 0
	for e in Run.enemies.duplicate():
		if not e.dead and e.dying == null:
			Combat.kill_enemy(e, {"silent": true})
			n += 1
	Run.fx = Run.fx.filter(func(f): return f.type != "spawn")
	Run.ebullets = []
	return n

# kills everything and skips the remaining waves: the room clears on the next tick
func clear_room() -> void:
	var room := Run.room
	kill_all()
	if room.combat and room.type != "boss":
		room.waveIdx = room.waves.size()
		room.waveDelay = 0.0

# a free reachable tile away from the player
func _spawn_point() -> Vector2:
	var p := Run.player
	var tiles: Array = RoomU.reach_tiles(Run.room).filter(func(t):
		var c := RoomU.tile_center(t.x, t.y)
		return Run.room.grid[t.y][t.x] == Consts.T.FLOOR and U.dist(c.x, c.y, p.x, p.y) > 60)
	if tiles.is_empty():
		return Vector2(p.x, p.y - 40)
	var t: Vector2i = tiles[Fx.vis.rint(0, tiles.size() - 1)]
	return RoomU.tile_center(t.x, t.y)

# the spawn fx creates the enemy after the summoning circle, as for the waves
func spawn_enemy(type: String, mod: Variant = null) -> void:
	var c := _spawn_point()
	Effects.add({"type": "spawn", "x": c.x, "y": c.y, "life": 0.6, "spec": {"type": type, "mod": mod}})
	Sfx.play("spawn")

func spawn_boss(id: String) -> void:
	var c := RoomU.tile_center(14, 7)
	var y := c.y + 30 if Run.player.y < c.y else c.y - 30
	Effects.add({"type": "spawn", "x": c.x, "y": y, "life": 1.0, "spec": {"type": "BOSS", "boss": id}})
	Run.boss_intro = {"t": 0.0, "B": DB.boss(id)}
	Sfx.play("roar")

func goto_room(type: String) -> bool:
	for r in Run.floor.rooms:
		if r.type == type and not is_same(r, Run.room):
			r.seen = true
			if type == "secret":
				r.found = true
			Flow.enter_room(r, null)
			return true
	return false

func goto_depth(d: int) -> void:
	Run.trans = null
	Run.depth = maxi(1, d)
	Flow.new_floor()
