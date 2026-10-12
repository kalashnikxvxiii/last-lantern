class_name Screen
extends Node2D
# Base of the screens outside the game (the Scenes.* objects of js/game.js):
# enter() on entry, update(dt) at fixed ticks, paint() for drawing.

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
