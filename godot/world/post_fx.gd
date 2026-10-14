class_name PostFx
extends ColorRect
# Godot-only post-processing of the world (shaders/post.gdshader): biome color
# grading, chromatic aberration when the screen shakes or flashes, distortion
# along shockwaves and explosions. Above the overlay, below the bloom and the HUD.

const MAX_RINGS := 8
const MAX_ABERRATION := 2.0

# shadows and highlights tints, saturation and contrast of each depth
const GRADES := {
	"crypt": {"shadows": [0.006, 0.0, 0.016], "highlights": [0.03, 0.015, 0.0], "sat": 0.96, "contrast": 1.03},
	"fungus": {"shadows": [0.0, 0.012, 0.01], "highlights": [0.02, 0.0, 0.02], "sat": 1.08, "contrast": 1.03},
	"forge": {"shadows": [0.012, 0.004, 0.0], "highlights": [0.05, 0.025, -0.01], "sat": 1.06, "contrast": 1.05},
	"abyss": {"shadows": [0.0, 0.008, 0.016], "highlights": [-0.01, 0.025, 0.035], "sat": 0.92, "contrast": 1.03},
	"heart": {"shadows": [0.016, 0.0, 0.01], "highlights": [0.04, 0.0, 0.03], "sat": 1.04, "contrast": 1.05},
}

func _ready() -> void:
	# a margin around the screen, so the shake offset never uncovers an edge
	position = Vector2(-16, -16)
	size = Vector2(Consts.W + 32, Consts.H + 32)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/post.gdshader")
	material = m

static func grade_for(biome: String) -> Dictionary:
	return GRADES.get(biome, {"shadows": [0.0, 0.0, 0.0], "highlights": [0.0, 0.0, 0.0], "sat": 1.0, "contrast": 1.0})

static func screen_fx() -> bool:
	return Save.data.settings.screenFx

# in game pixels: a little when the screen shakes, more on a flash (hits, the player hurt)
static func aberration(shake: float, flash: float) -> float:
	if not screen_fx():
		return 0.0
	return minf(MAX_ABERRATION, shake * 0.12 + flash * 1.5)

# distortion rings (x, y, radius, strength) of the shockwaves and explosions, on screen
static func rings(fx: Array, offset: Vector2) -> Array:
	var out: Array = []
	if not screen_fx():
		return out
	for f in fx:
		if out.size() >= MAX_RINGS:
			break
		if f.get("delay", 0.0) > 0:
			continue
		match f.type:
			"shockwave":
				var k: float = clampf(f.r / f.maxR, 0.0, 1.0)
				out.append(Vector4(f.x + offset.x, f.y + offset.y, f.r, 2.5 * (1.0 - k)))
			"explosion":
				var k: float = clampf(f.t / f.life, 0.0, 1.0)
				out.append(Vector4(f.x + offset.x, f.y + offset.y, f.r * (0.5 + k * 1.5), 3.0 * (1.0 - k)))
	return out

func _process(_delta: float) -> void:
	var grading: bool = Save.data.settings.grading
	var ab := aberration(Fx.shake_amt, Fx.flash)
	var offset: Vector2 = (get_parent() as CanvasLayer).offset if get_parent() is CanvasLayer else Vector2.ZERO
	var rs := rings(Run.fx, offset) if Run.active else []
	if View3D.current != null:   # rings on the floor, where the 3D view shows them
		for i in rs.size():
			var p := View3D.current.project(Vector3(rs[i].x, 0, rs[i].y))
			rs[i] = Vector4(p.x, p.y, rs[i].z, rs[i].w)
	visible = Run.active and not Run.room.is_empty() and (grading or ab > 0.0 or not rs.is_empty())
	if not visible:
		return
	var m := material as ShaderMaterial
	m.set_shader_parameter("grading", grading)
	if grading:
		var g := grade_for(DB.biome_of(Run.depth).id)
		m.set_shader_parameter("shadows", Vector3(g.shadows[0], g.shadows[1], g.shadows[2]))
		m.set_shader_parameter("highlights", Vector3(g.highlights[0], g.highlights[1], g.highlights[2]))
		m.set_shader_parameter("sat", g.sat)
		m.set_shader_parameter("contrast", g.contrast)
	m.set_shader_parameter("aberration", ab)
	var packed := PackedVector4Array()
	packed.resize(MAX_RINGS)
	for i in rs.size():
		packed[i] = rs[i]
	m.set_shader_parameter("ring_count", rs.size())
	m.set_shader_parameter("rings", packed)
