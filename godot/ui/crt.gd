class_name Crt
extends ColorRect
# Godot-only CRT filter (shaders/crt.gdshader), on a layer above every screen.

func _ready() -> void:
	size = Vector2(Consts.W, Consts.H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/crt.gdshader")
	material = m

func _process(_delta: float) -> void:
	visible = Save.data.settings.crt
