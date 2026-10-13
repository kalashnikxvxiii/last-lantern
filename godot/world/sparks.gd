class_name Sparks
extends Node2D
# Godot-only sparks on the GPU, thrown by the bright bursts of Particles.burst
# (fire, explosions, crits, flares). They live in the overlay, shine in the dark
# and stretch along their speed. The randomness is on the GPU: the game sequence is
# never touched. Each burst takes the next one-shot emitter of a small pool.

const POOL := 24
const MAX := 48                    # sparks per burst at most
const SHARE := {"off": 0.0, "low": 0.35, "high": 0.7, "ultra": 1.0}   # sparks per burst particle

static var current: Sparks = null
static var _palettes: Dictionary = {}   # burst colors -> color ramp
var pool: Array = []
var next := 0

# how many sparks a burst of n particles throws: only its bright, colored part counts
static func count_for(n: int, color: Variant) -> int:
	var cols: Array = color if color is Array else [color]
	var hot := 0
	for c in cols:
		if is_hot(c):
			hot += 1
	var share: float = SHARE.get(str(Save.data.settings.particles), 0.0)
	return int(ceil(n * share * hot / float(cols.size())))

# bright and colored: fire, gold, ice, arcane; not blood, dust, bone or white
static func is_hot(c: Variant) -> bool:
	var k := UiDraw.col(c)
	var mx := maxf(k.r, maxf(k.g, k.b))
	var mn := minf(k.r, minf(k.g, k.b))
	return k.get_luminance() >= 0.6 and (mx - mn) / mx >= 0.2

# called by Particles.burst
static func burst(x: float, y: float, n: int, color: Variant, spd: float, life: float) -> void:
	if current == null:
		return
	var k := count_for(n, color)
	if k == 0:
		return
	var cols: Array = (color if color is Array else [color]).filter(func(c): return is_hot(c))
	current._emit(x, y, mini(k, MAX), cols, spd, life)

func _emit(x: float, y: float, k: int, cols: Array, spd: float, life: float) -> void:
	var p: GPUParticles2D = pool[next]
	next = (next + 1) % POOL
	var m := p.process_material as ParticleProcessMaterial
	m.initial_velocity_min = spd * 0.6
	m.initial_velocity_max = spd * 1.6
	var key := str(cols)
	if not _palettes.has(key):
		_palettes[key] = AmbientFx.palette(cols)
	m.color_initial_ramp = _palettes[key]
	p.position = Vector2(x, y)
	p.lifetime = maxf(0.2, life * 1.2)
	p.amount_ratio = float(k) / MAX
	p.restart()

func _ready() -> void:
	current = self
	# a short streak along +Y, the direction of motion (align_y): dim tail, bright head
	var img := Image.create(1, 3, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	img.set_pixel(0, 0, Color(1, 1, 1, 0.35))
	var tex := ImageTexture.create_from_image(img)
	var cm := CanvasItemMaterial.new()
	cm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var shrink := _shrink()
	var fade := _fade()
	for i in POOL:
		var m := ParticleProcessMaterial.new()
		m.particle_flag_disable_z = true
		m.particle_flag_align_y = true
		m.direction = Vector3(1, 0, 0)
		m.spread = 180.0
		m.gravity = Vector3(0, 40, 0)
		m.damping_min = 60.0
		m.damping_max = 120.0
		m.scale_min = 0.8
		m.scale_max = 1.2
		m.scale_curve = shrink
		m.color_ramp = fade
		var p := GPUParticles2D.new()
		p.texture = tex
		p.amount = MAX
		p.one_shot = true
		p.explosiveness = 1.0
		p.randomness = 1.0
		p.local_coords = false
		p.emitting = false
		p.visibility_rect = Rect2(-64, -64, 128, 128)
		p.material = cm
		p.process_material = m
		add_child(p)
		pool.append(p)

func _exit_tree() -> void:
	if is_same(current, self):
		current = null

func _process(_delta: float) -> void:
	visible = Run.active and not Run.room.is_empty()

static func _shrink() -> CurveTexture:
	var c := Curve.new()
	c.add_point(Vector2(0, 1))
	c.add_point(Vector2(1, 0.2))
	var t := CurveTexture.new()
	t.curve = c
	return t

static func _fade() -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	g.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
	var t := GradientTexture1D.new()
	t.gradient = g
	return t
