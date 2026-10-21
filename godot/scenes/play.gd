extends Node
# Game scene (Scenes.play in js/game.js): updates the world at fixed ticks in the
# same order as the JS; child nodes draw the layers.

var mode := "play"
var choices: Array = []
var sel := 0
var lock := 0.0
var card_rects: Array = []
var card_hover := -1
var card_lit_prev := true
var reroll_rect := Rect2()
var pause_menu: Menu
var confirm_quit := false
var build_sel := 0
var build_rects: Array = []
var map_from := "play"
var opt_menu: OptionsMenu
var cheat_menu: Menu
var cheat_page := "main"
@onready var actors: Node2D = $Flat/World/Actors

func _ready() -> void:
	Run.actors = actors
	if Run.player != null:
		actors.add_child(Run.player)
	for e in Run.enemies:
		if e.get_parent() == null:
			actors.add_child(e)
	mode = "play"
	process_priority = 1   # run _process after the child views: they read bgDirty before we clear it
	if Game.scene_arg == "continue":
		Run.victory_t = 0.0
		Music.play(DB.biome_of(Run.depth).music)
	_dev_sim()

func _exit_tree() -> void:
	if Run.player != null and Run.player.get_parent() == actors:
		actors.remove_child(Run.player)
	for e in Run.enemies:
		if is_instance_valid(e) and e.get_parent() == actors:
			actors.remove_child(e)
	Run.actors = null
	Fx.cam = Vector2.ZERO
	if opt_menu != null:
		opt_menu.close()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(_delta: float) -> void:
	var sp := Cheats.speed() if mode == "play" else 1.0
	if sp < 1:
		tick(Consts.DT * sp)
	else:
		# fast forward: the presses of this frame count only in the first tick
		var scene := Game.scene_name
		for i in int(sp):
			Controls.held_only = i > 0
			tick(Consts.DT)
			if mode != "play" or Game.scene_name != scene:
				break
		Controls.held_only = false
	Controls.end_tick()

func _process(delta: float) -> void:
	if Run.player != null:
		Fx.follow(Run.player.x, Run.player.y, delta)
	# the 3D view moves its camera: the flat world stays put in its texture
	$Flat/Lighting.refresh(Vector2.ZERO)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if cursor_hidden(mode) else Input.MOUSE_MODE_VISIBLE
	# the views rebuild from bgDirty before the parent runs: clear it once, last
	var r := Run.room
	if not r.is_empty() and r.get("bgDirty", false):
		r.bgDirty = false

static func cursor_hidden(m: String) -> bool:
	return m == "play"

func tick(dt: float) -> void:
	if mode != "play":
		Run.restart_t = 0.0   # the R hold counts only while playing
		Flow.restart_dust_clear()
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
			if (Controls.back() or Controls.pause()) and not opt_menu.capturing():
				mode = "pause"
				return
			opt_menu.update()
		"cheats":
			if Controls.cheats() or (Controls.pause() and not Controls.back()):
				close_cheats()
				return
			if Controls.back():
				if cheat_page == "main":
					close_cheats()
				else:
					open_cheats("main", cheat_page)
				return
			cheat_menu.update()

func open_level_up() -> void:
	var p := Run.player
	choices = Run.forced_choices if Run.forced_choices != null else Perks.roll_choices(3 + int(p.stats.extraChoice), 0)
	Run.forced_choices = null
	if choices.is_empty():
		Run.pending_levels = maxi(0, Run.pending_levels - 1)
		p.add_coins(10)
		Run.toast("You already have everything. Take some coins.", "#f6cf57")
		return
	mode = "levelup"
	sel = 0
	lock = 0.45
	card_rects = []
	card_hover = -1
	card_lit_prev = true
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

# developer cheat panel (Godot only): pages in ui/cheat_menu.gd
func open_cheats(page: String = "main", from: String = "") -> void:
	mode = "cheats"
	cheat_page = page
	cheat_menu = CheatMenu.page(page, self)
	if from != "":
		cheat_menu.sel = maxi(0, CheatMenu.PAGES.find(from))

func close_cheats() -> void:
	mode = "play"
	Run.lock_fire = true

func open_pause() -> void:
	mode = "pause"
	confirm_quit = false
	pause_menu = Menu.new([
		{"label": "Resume", "action": func(): mode = "play"},
		{"label": "Equipment", "action": func():
			mode = "build"
			build_sel = 0},
		{"label": "Map", "action": func():
			mode = "map"
			map_from = "pause"},
		{"label": "Options", "action": func():
			mode = "options"
			if opt_menu != null:
				opt_menu.close()
			opt_menu = OptionsMenu.new(func(): mode = "pause")},
		{"label": "Save and leave", "disabled": Run.slot < 0, "action": func():
			if RunSave.save(Run.slot):
				Game.set_scene("title")
			else:
				mode = "play"
				Run.toast("Could not save the descent", "#e0574a")},
		{"label": func(): return "Sure? The descent will be lost" if confirm_quit else "Abandon the descent", "action": func():
			if not confirm_quit:
				confirm_quit = true
				return
			Run.player.last_hit = "Surrender"
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
	var mouse := Controls.device() == "mouse"
	card_hover = -1
	if mouse:
		for i in card_rects.size():
			if (card_rects[i] as Rect2).has_point(m):
				card_hover = i
				break
	# hovering moves the cursor: the flame only lights the card under the mouse
	if mouse and card_hover >= 0 and sel != card_hover:
		sel = card_hover
		Sfx.play("select")
	var lit_now := (card_hover >= 0) if mouse else true
	if mouse and card_hover >= 0 and Controls.mouse_left_pressed() and lock <= 0:
		choose_perk(choices[card_hover])
		Run.lock_fire = true
		return
	if lock > 0:
		card_lit_prev = lit_now
		return
	for i in n:
		if Controls.digit(i + 1):
			choose_perk(choices[i])
			return
	if Controls.confirm():
		# with the mouse off the cards nothing is lit: confirm brings the cursor
		# back to the first card instead of picking the hidden one
		if card_lit_prev:
			choose_perk(choices[sel])
		else:
			sel = 0
			Sfx.play("select")
		card_lit_prev = lit_now
		return
	# rematch
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
	card_lit_prev = lit_now

# updatePlay (js/game.js:335-357)
func update_play(dt: float) -> void:
	if Run.restart_in > 0.0:
		Run.restart_in = maxf(0.0, Run.restart_in - dt / Consts.RESTART_FADE)
	if Run.restart_flare >= 0.0:
		# Godot-only: the lantern flares up and floods everything on the way to
		# a new seed; the world still runs under the light
		Run.restart_flare += dt
		if Run.player.dead:
			Run.restart_flare = -1.0
			Run.restart_t = 0.0
		elif Run.restart_flare >= Consts.RESTART_FADE:
			_restart_run()
			return
		Flow.restart_dust_tick(dt)
		Flow.update_common(dt)
		Flow.update_game(dt)
		return
	if Controls.pause() and not Run.player.dead:
		open_pause()
		return
	if Controls.map() and not Run.player.dead:
		mode = "map"
		map_from = "play"
		return
	if Cheats.enabled and Controls.cheats() and not Run.player.dead:
		open_cheats()
		return
	Flow.update_common(dt)
	if Run.trans != null:
		Flow.update_trans(dt)
		return
	if Fx.hitstop_t > 0:
		Fx.hitstop_t -= dt
		return
	if Run.player.dead:
		Run.restart_t = 0.0
		Flow.restart_dust_clear()
		Run.death_t += dt
		Flow.update_game(dt * 0.25)
		if Run.death_t > 2.4:
			Game.set_scene("gameover")
		return
	if Run.lock_fire and not Controls.mouse_left():
		Run.lock_fire = false
	# the hold is ticked before the world, so the rooted player (player.gd) sees
	# the restart state on the same frame (Play.update_play)
	if Controls.held("reroll") and Run.victory_t <= 0:
		Run.restart_t += dt
		if Run.restart_t >= Consts.RESTART_HOLD:
			Run.restart_t = Consts.RESTART_HOLD
			Run.restart_flare = 0.0
			Sfx.play("descend")
			return
	else:
		Run.restart_t = 0.0
	Flow.update_game(dt)
	Cheats.tick()
	if Run.victory_t > 0:
		Run.victory_t -= dt
		if Run.victory_t <= 0:
			Run.victory_t = 0.0
			Game.set_scene("victory")
			return
	Flow.restart_dust_tick(dt)   # releasing R reassembles the dust back
	if Run.pending_levels > 0 and not Run.room.combat and Run.trans == null:
		Run.level_delay -= dt
		if Run.level_delay <= 0:
			open_level_up()
	elif Run.room.combat:
		Run.level_delay = 0.7

# the hold completed: the same lantern starts over on a new seed (Flow.restart_run)
func _restart_run() -> void:
	Flow.restart_run()   # Run.reset clears the restart state
	Run.restart_in = 1.0
	Game.set_scene("play", "restart")

# --sim=N [--fire]: N simulated ticks before the first draw (JS devStart)
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
	if Game.dev.has("cheat-panel") and Cheats.enabled:
		open_cheats(str(Game.dev["cheat-panel"]) if Game.dev["cheat-panel"] is String else "main")
	if Game.dev.has("restart"):
		# Godot-only: hold R from the start, to check the bar and the fade
		Controls.sim.held = ["reroll"]
