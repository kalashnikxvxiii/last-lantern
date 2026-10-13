class_name Bloom
extends ColorRect
# Godot-only bloom over the lit scene (shaders/bloom.gdshader), above the
# overlay and below the HUD. Off in the settings: hidden, the picture is the JS one.

const LEVELS := {"off": 0.0, "low": 0.6, "medium": 1.0, "high": 1.5}

func _ready() -> void:
	# a margin around the screen, so the shake offset never uncovers an edge
	position = Vector2(-16, -16)
	size = Vector2(Consts.W + 32, Consts.H + 32)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/bloom.gdshader")
	material = m

static func intensity() -> float:
	return LEVELS.get(str(Save.data.settings.bloom), 1.0)

func _process(_delta: float) -> void:
	var k := intensity()
	visible = k > 0.0
	if visible:
		(material as ShaderMaterial).set_shader_parameter("intensity", k)
