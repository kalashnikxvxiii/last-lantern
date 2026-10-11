extends Node
# Scena di gioco (Scenes.play in js/game.js): aggiorna il mondo a tick fissi nello
# stesso ordine del JS; i nodi figli disegnano i livelli.

var mode := "play"
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

func _physics_process(_delta: float) -> void:
	tick(Consts.DT)
	Controls.end_tick()

func _process(_delta: float) -> void:
	var off := Fx.offset()
	world.position = off
	$Lighting.refresh(off)

func tick(dt: float) -> void:
	match mode:
		"play":
			update_play(dt)

# updatePlay (js/game.js:335-357); pausa, mappa e livelli arrivano nel Task 24
func update_play(dt: float) -> void:
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
