class_name AmbientFx
extends GPUParticles2D
# Godot-only ambient particles of the biome (dust, spores, embers, ash...), on the GPU:
# they never touch the game randomness. The "air" emitter sits under the lighting,
# so its motes show only near the lights; the "glow" one sits in the overlay and
# shines in the dark (and in the bloom).

@export var glow := false

const AMOUNT := {"off": 0.0, "low": 0.5, "high": 1.0, "ultra": 1.5}

# per biome: amount, colors, velocity (vx, vy, random speed added or removed),
# lifetime, size range, turbulence
const BIOMES := {
	"crypt": {
		"air": {"amount": 46, "colors": ["#8a8294", "#6b6478", "#a59fb0"], "vel": [0.0, 1.0, 4.0], "life": 9.0, "size": [1.0, 1.0], "turb": 0.4},
		"glow": {"amount": 8, "colors": ["#6b5a80", "#8a80b0"], "vel": [0.0, -2.0, 2.0], "life": 7.0, "size": [1.0, 1.0], "turb": 0.6},
	},
	"fungus": {
		"air": {"amount": 30, "colors": ["#9fd05a", "#4a6a3a"], "vel": [0.0, 2.0, 3.0], "life": 8.0, "size": [1.0, 1.0], "turb": 0.5},
		"glow": {"amount": 34, "colors": ["#9fd05a", "#e88fc0", "#a33a7a", "#d0ffb0"], "vel": [0.0, -5.0, 3.0], "life": 7.0, "size": [1.0, 2.0], "turb": 0.8},
	},
	"forge": {
		"air": {"amount": 36, "colors": ["#55505e", "#3b3546", "#8a8294"], "vel": [3.0, 8.0, 3.0], "life": 7.0, "size": [1.0, 1.0], "turb": 0.3},
		"glow": {"amount": 40, "colors": ["#f29c38", "#f6cf57", "#fff2a8", "#e0574a"], "vel": [0.0, -18.0, 8.0], "life": 4.0, "size": [1.0, 1.0], "turb": 1.0},
	},
	"abyss": {
		"air": {"amount": 40, "colors": ["#355260", "#5aa0aa", "#22343e"], "vel": [0.0, 6.0, 3.0], "life": 6.0, "size": [1.0, 1.0], "turb": 0.2},
		"glow": {"amount": 22, "colors": ["#5aa0aa", "#9ad8dc", "#c8f2f5"], "vel": [0.0, -6.0, 2.0], "life": 8.0, "size": [1.0, 2.0], "turb": 0.5},
	},
	"heart": {
		"air": {"amount": 38, "colors": ["#7e2530", "#4b2a5c", "#55505e"], "vel": [0.0, 4.0, 3.0], "life": 8.0, "size": [1.0, 1.0], "turb": 0.4},
		"glow": {"amount": 26, "colors": ["#c57ae0", "#d08aff", "#e0574a"], "vel": [0.0, -3.0, 4.0], "life": 7.0, "size": [1.0, 2.0], "turb": 0.9},
	},
}

var _key := ""
var _room: Variant = null

static func config(biome: String, glow_: bool) -> Variant:
	var b: Dictionary = BIOMES.get(biome, {})
	return b.get("glow" if glow_ else "air")

static func scaled(n: int) -> int:
	return int(U.jround(n * float(AMOUNT.get(str(Save.data.settings.particles), 0.0))))

# 1x1 white texture: the color comes from the process material
static func pixel() -> Texture2D:
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)

# discrete palette: each particle picks one color, then fades in and out
static func palette(colors: Array) -> GradientTexture1D:
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g.offsets = PackedFloat32Array()
	g.colors = PackedColorArray()
	for i in colors.size():
		g.add_point(float(i) / colors.size(), UiDraw.col(colors[i]))
	var t := GradientTexture1D.new()
	t.gradient = g
	return t

static func fade() -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	var t := GradientTexture1D.new()
	t.gradient = g
	return t

func _ready() -> void:
	texture = pixel()
	local_coords = false
	emitting = false
	if glow:
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = m
	# the inner area of the room
	var w := (Consts.RW - 2) * Consts.TS
	var h := (Consts.RH - 2) * Consts.TS
	position = Vector2(Consts.RX + Consts.TS + w / 2.0, Consts.RY + Consts.TS + h / 2.0)
	visibility_rect = Rect2(-w / 2.0 - 16, -h / 2.0 - 16, w + 32, h + 32)

func _process(_delta: float) -> void:
	if not Run.active or Run.room.is_empty():
		emitting = false
		visible = false
		return
	var biome: String = DB.biome_of(Run.depth).id
	var c: Variant = config(biome, glow)
	var n := scaled(int(c.amount)) if c != null else 0
	var key := biome + ":" + str(n)
	if key != _key:
		_key = key
		_room = null
		if n > 0:
			_configure(c, n)
	visible = n > 0
	emitting = n > 0
	# a new room starts already filled
	if n > 0 and not is_same(_room, Run.room):
		_room = Run.room
		restart()

func _configure(c: Dictionary, n: int) -> void:
	amount = n
	lifetime = c.life
	preprocess = c.life
	randomness = 1.0
	var w := (Consts.RW - 2) * Consts.TS
	var h := (Consts.RH - 2) * Consts.TS
	var m := ParticleProcessMaterial.new()
	m.particle_flag_disable_z = true
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(w / 2.0, h / 2.0, 0)
	var v: Array = c.vel
	m.gravity = Vector3.ZERO
	m.direction = Vector3(v[0], v[1], 0)
	m.spread = 180.0 if v[0] == 0.0 and v[1] == 0.0 else 25.0
	var base := Vector2(v[0], v[1]).length()
	m.initial_velocity_min = maxf(0.0, base - v[2])
	m.initial_velocity_max = base + v[2]
	m.scale_min = c.size[0]
	m.scale_max = c.size[1]
	m.color_initial_ramp = palette(c.colors)
	m.color_ramp = fade()
	if c.turb > 0.0:
		m.turbulence_enabled = true
		m.turbulence_noise_strength = c.turb
		m.turbulence_noise_scale = 6.0
		m.turbulence_influence_min = 0.02
		m.turbulence_influence_max = 0.06
	process_material = m
