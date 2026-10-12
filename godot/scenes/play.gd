extends Node
# Scena di gioco (Scenes.play in js/game.js): aggiorna il mondo a tick fissi nello
# stesso ordine del JS; i nodi figli disegnano i livelli.

var mode := "play"
var choices: Array = []
var sel := 0
var lock := 0.0
var card_rects: Array = []
var reroll_rect := Rect2()
var pause_menu: Menu
var confirm_quit := false
var build_sel := 0
var build_rects: Array = []
var map_from := "play"
var opt_menu: Menu
@onready var world: Node2D = $World
@onready var actors: Node2D = $World/Actors

func _ready() -> void:
	Run.actors = actors
	if Run.player != null:
		actors.add_child(Run.player)
	for e in Run.enemies:
		if e.get_parent() == null:
			actors.add_child(e)
	mode = "play"
	_dev_sim()

func _exit_tree() -> void:
	if Run.player != null and Run.player.get_parent() == actors:
		actors.remove_child(Run.player)
	for e in Run.enemies:
		if is_instance_valid(e) and e.get_parent() == actors:
			actors.remove_child(e)
	Run.actors = null
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(_delta: float) -> void:
	tick(Consts.DT)
	Controls.end_tick()

func _process(_delta: float) -> void:
	var off := Fx.offset()
	world.position = off
	$OverlayLayer.offset = off
	$Lighting.refresh(off)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if cursor_hidden(mode) else Input.MOUSE_MODE_VISIBLE

static func cursor_hidden(m: String) -> bool:
	return m == "play"

func tick(dt: float) -> void:
	match mode:
		"play":
			update_play(dt)
		"levelup":
			update_level_up(dt)
		"pause":
			if Controls.pause() or Controls.back():
				mode = "play"
				return
			pause_menu.update()
		"build":
			var n := PanelsDraw.build_entries().size()
			if Controls.back() or Controls.pause() or Controls.confirm():
				mode = "pause"
				return
			if n > 0:
				if Controls.right():
					build_sel = (build_sel + 1) % n
				if Controls.left():
					build_sel = (build_sel - 1 + n) % n
				if Controls.down():
					build_sel = mini(n - 1, build_sel + 10)
				if Controls.up():
					build_sel = maxi(0, build_sel - 10)
		"map":
			if Controls.map() or Controls.pause() or Controls.back() or Controls.confirm() or Controls.mouse_left_pressed():
				mode = "pause" if map_from == "pause" else "play"
		"options":
			if Controls.back() or Controls.pause():
				mode = "pause"
				return
			opt_menu.update()

func open_level_up() -> void:
	var p := Run.player
	choices = Run.forced_choices if Run.forced_choices != null else Perks.roll_choices(3 + int(p.stats.extraChoice), 0)
	Run.forced_choices = null
	if choices.is_empty():
		Run.pending_levels = maxi(0, Run.pending_levels - 1)
		p.add_coins(10)
		Run.toast("Hai già tutto. Prendi delle monete.", "#f6cf57")
		return
	mode = "levelup"
	sel = 0
	lock = 0.45
	card_rects = []
	Sfx.play("levelup")

func choose_perk(id: String) -> void:
	var p := Run.player
	p.perks[id] = p.perks.get(id, 0) + 1
	p.recalc_stats()
	if Perks.ALL[id].get("onTake", false):
		Perks.on_take(id, p)
	Run.pending_levels = maxi(0, Run.pending_levels - 1)
	Sfx.play("confirm")
	Run.toast(Perks.ALL[id].name, Stats.RARITY[Perks.ALL[id].rar].col)
	mode = "play"
	Run.level_delay = 0.35
	p.fire_cd = 0.25
	Controls.sim.erase("pressed")

func open_pause() -> void:
	mode = "pause"
	confirm_quit = false
	pause_menu = Menu.new([
		{"label": "Riprendi", "action": func(): mode = "play"},
		{"label": "Equipaggiamento", "action": func():
			mode = "build"
			build_sel = 0},
		{"label": "Mappa", "action": func():
			mode = "map"
			map_from = "pause"},
		{"label": "Opzioni", "action": func():
			mode = "options"
			opt_menu = Panels.make_options_menu(func(): mode = "pause")},
		{"label": func(): return "Confermi? La discesa andrà persa" if confirm_quit else "Abbandona la discesa", "action": func():
			if not confirm_quit:
				confirm_quit = true
				return
			Run.player.last_hit = "La resa"
			Run.abandoned = true
			Game.set_scene("gameover")},
	])

func update_level_up(dt: float) -> void:
	lock -= dt
	var n := choices.size()
	if Controls.left():
		sel = (sel - 1 + n) % n
		Sfx.play("select")
	if Controls.right():
		sel = (sel + 1) % n
		Sfx.play("select")
	var m := Controls.mouse_pos()
	for i in card_rects.size():
		if card_rects[i].has_point(m):
			if sel != i and Time.get_ticks_msec() - Controls.mouse_moved_at < 100:
				sel = i
				Sfx.play("select")
			if Controls.mouse_left_pressed() and lock <= 0:
				choose_perk(choices[i])
				Run.lock_fire = true
				return
	if lock > 0:
		return
	for i in n:
		if Controls.digit(i + 1):
			choose_perk(choices[i])
			return
	if Controls.confirm():
		choose_perk(choices[sel])
		return
	# rilancio
	var clicked := Controls.mouse_left_pressed() and reroll_rect.has_point(m)
	if Controls.reroll() or clicked:
		var p := Run.player
		if p.coins >= Run.reroll_cost:
			p.coins -= Run.reroll_cost
			Run.reroll_cost += 3
			choices = Perks.roll_choices(3 + int(p.stats.extraChoice), 0)
			sel = 0
			Sfx.play("coin")
			lock = 0.2
		else:
			Sfx.play("deny")

# updatePlay (js/game.js:335-357)
func update_play(dt: float) -> void:
	if Controls.pause() and not Run.player.dead:
		open_pause()
		return
	if Controls.map() and not Run.player.dead:
		mode = "map"
		map_from = "play"
		return
	Flow.update_common(dt)
	if Run.trans != null:
		Flow.update_trans(dt)
		return
	if Fx.hitstop_t > 0:
		Fx.hitstop_t -= dt
		return
	if Run.player.dead:
		Run.death_t += dt
		Flow.update_game(dt * 0.25)
		if Run.death_t > 2.4 and Game.SCENES.has("gameover"):
			Game.set_scene("gameover")
		return
	if Run.lock_fire and not Controls.mouse_left():
		Run.lock_fire = false
	Flow.update_game(dt)
	if Run.victory_t > 0:
		Run.victory_t -= dt
		if Run.victory_t <= 0:
			Run.victory_t = 0.0
			if Game.SCENES.has("victory"):
				Game.set_scene("victory")
			return
	if Run.pending_levels > 0 and not Run.room.combat and Run.trans == null:
		Run.level_delay -= dt
		if Run.level_delay <= 0:
			open_level_up()
	elif Run.room.combat:
		Run.level_delay = 0.7

# --sim=N [--fire]: N tick simulati prima del primo disegno (devStart del JS)
func _dev_sim() -> void:
	var n := int(Game.dev.get("sim", 0))
	for i in n:
		if Game.dev.has("fire"):
			var e: Variant = Run.enemies[0] if not Run.enemies.is_empty() else null
			Controls.sim = {"fire": e != null, "device": "mouse"}
			if e != null:
				Controls.sim.mouse = Vector2(e.x, e.y)
		tick(Consts.DT)
		Controls.end_tick()
	Controls.sim.clear()
	if Game.dev.has("pause"):
		open_pause()
	if Game.dev.has("map"):
		mode = "map"
		map_from = "play"
