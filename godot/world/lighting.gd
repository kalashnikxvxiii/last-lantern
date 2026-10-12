class_name Lighting
extends CanvasLayer
# Darkness, glow and vignette (drawLighting in js/render.js) as a fullscreen shader.

const MAX_LIGHTS := 128
var dark := ColorRect.new()
var glow := ColorRect.new()
var vignette := ColorRect.new()

func _ready() -> void:
	layer = 1
	for pair in [[dark, "darkness"], [glow, "glow"], [vignette, "vignette"]]:
		var rect: ColorRect = pair[0]
		rect.size = Vector2(Consts.W, Consts.H)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/%s.gdshader" % pair[1])
		rect.material = m
		add_child(rect)

static func ambient(dark_: float, depth: int, cleared: bool, is_boss: bool, oil_empty: bool, combat: bool) -> float:
	var amb := dark_ + minf(0.08, maxf(0.0, depth - 5) * 0.015)
	if cleared and not is_boss:
		amb *= 0.84
	if oil_empty and combat:
		amb = minf(0.94, amb + 0.06)
	return amb

func refresh(offset: Vector2) -> void:
	visible = Run.active and not Run.room.is_empty()
	if not visible:
		return
	var room := Run.room
	var amb := ambient(DB.biome_of(Run.depth).dark, Run.depth, room.cleared, room.type == "boss", Run.player.oil <= 0, room.combat)
	var L := Lights.collect()
	var n := mini(L.size(), MAX_LIGHTS)
	var pos := PackedVector4Array()
	var cols := PackedVector4Array()
	pos.resize(MAX_LIGHTS)
	cols.resize(MAX_LIGHTS)
	for i in n:
		var l: Dictionary = L[i]
		pos[i] = Vector4(l.x + offset.x, l.y + offset.y, maxf(4.0, l.r), l.a)
		if l.get("col") != null:
			var c := UiDraw.col(l.col)
			cols[i] = Vector4(c.r, c.g, c.b, l.get("ga", 0.1))
	var dm := dark.material as ShaderMaterial
	dm.set_shader_parameter("amb", amb)
	dm.set_shader_parameter("count", n)
	dm.set_shader_parameter("lights", pos)
	var gm := glow.material as ShaderMaterial
	gm.set_shader_parameter("count", n)
	gm.set_shader_parameter("lights", pos)
	gm.set_shader_parameter("colors", cols)
