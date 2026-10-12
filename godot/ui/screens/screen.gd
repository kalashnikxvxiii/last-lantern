class_name Screen
extends Node2D
# Base delle schermate fuori dal gioco (gli oggetti Scenes.* di js/game.js):
# enter() all'ingresso, update(dt) a tick fissi, paint() per il disegno.

var t := 0.0
var menu: Menu

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	enter()

func _physics_process(dt: float) -> void:
	t += dt
	WellBg.update_embers(WellBg.embers, dt)
	update(dt)
	Controls.end_tick()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	WellBg.draw(self, t, WellBg.embers)
	paint()

func enter() -> void:
	pass

func update(_dt: float) -> void:
	if menu != null:
		menu.update()

func paint() -> void:
	pass
