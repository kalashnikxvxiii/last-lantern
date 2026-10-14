class_name View3D
extends Node3D
# Godot-only prototype: the room in 3D, seen from above by a tilted camera. The
# floor is the 2D world rendered into a texture (the Flat viewport) and the
# projectiles and particles fly on a second plane above it (the Air viewport);
# walls are blocks and rocks are boulders; actors and objects stand up as
# sprites; DrawLifted puts the 2D details on them. A point (x, y) of the game is
# (x, 0, y) here, in game pixels.

const PITCH := 62.0          # camera angle above the horizon, degrees (90: straight down)
const FOV := 28.0
const DIST := 590.0          # from the camera to the point it looks at
const LOOK_DY := -22.0       # the camera looks a bit north of the middle: the HUD covers the top
const WALL_H := 24.0           # a tile and a half
const ROCK_H := 11.0
const ROCK_R := 7.5
const AIR_H := 8.0           # height of the projectiles' plane
const SPRITE_BIAS := 8.0     # sprites move this much toward the camera: no clipping into walls
const MAX_LIGHTS := 12
const SHADOW_LIGHTS := 3

static var on := false       # actors leave their sprite to the view while it is up
static var current: View3D
static var items: Array = []  # standing sprites recorded by DrawGround (Spr.capture)

@export var flat: SubViewport   # the 2D world, drawn on the floor
@export var air: SubViewport    # projectiles and particles, on a plane above the floor
var cam := Camera3D.new()
var env := Environment.new()
var floor_mesh := MeshInstance3D.new()
var solids := MeshInstance3D.new()
var air_mesh := MeshInstance3D.new()
var sprites: Dictionary = {}   # actor instance id -> Sprite3D
var item_pool: Array[Sprite3D] = []
var lights: Array[OmniLight3D] = []
var shown: Dictionary = {}

func _ready() -> void:
	on = true
	current = self
	cam.fov = FOV
	cam.far = 4000
	cam.current = true
	# only the canvas layers up to 1 stay behind the room: the world environment
	# decides it (Display puts every layer there for the picture adjustments)
	env.background_mode = Environment.BG_CANVAS
	env.background_canvas_max_layer = 1
	Display.environment().background_canvas_max_layer = 1
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.adjustment_enabled = true
	cam.environment = env
	add_child(cam)
	for n in [floor_mesh, solids, air_mesh]:
		add_child(n)
	for i in MAX_LIGHTS:
		var l := OmniLight3D.new()
		l.shadow_enabled = i < SHADOW_LIGHTS
		l.omni_attenuation = 1.4
		lights.append(l)
		add_child(l)
	if flat != null:
		_screen_plane(floor_mesh, flat, 0.0)
	if air != null:
		_screen_plane(air_mesh, air, AIR_H)
		(air_mesh.material_override as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	Controls.to_world = screen_to_floor
	place_camera(Vector2.ZERO, Vector2.ZERO)

# a 2D viewport laid on a horizontal plane at height h (its lighting is in the texture)
func _screen_plane(mi: MeshInstance3D, vp: SubViewport, h: float) -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(Consts.W, Consts.H)
	mi.mesh = plane
	mi.position = Vector3(Consts.W / 2.0, h, Consts.H / 2.0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = vp.get_texture()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mi.material_override = m

func _exit_tree() -> void:
	on = false
	if Display._env != null:   # on quit Game has already released it: do not make a new one
		Display._env.background_canvas_max_layer = 1000
	if current == self:
		current = null
	items = []
	if Controls.to_world == Callable(self, "screen_to_floor"):
		Controls.to_world = Callable()

func _process(_delta: float) -> void:
	if not Run.active or Run.room.is_empty():
		return
	if not is_same(Run.room, shown) or Run.room.get("bgDirty", false):
		shown = Run.room
		solids.mesh = build_solids(Run.room)
	place_camera(Fx.cam, Fx.offset())
	_sync_sprites()
	_sync_items()
	_sync_lights()

# the camera looks at the middle of the room moved by follow (Fx.cam); shake moves it sideways
func place_camera(follow: Vector2, shake: Vector2) -> void:
	var t := Vector3(Fx.VIEW_C.x + follow.x, 0, Fx.VIEW_C.y + follow.y + LOOK_DY)
	var p := deg_to_rad(PITCH)
	cam.position = t + Vector3(0, sin(p), cos(p)) * DIST
	cam.rotation = Vector3(-p, 0, 0)
	cam.h_offset = -shake.x
	cam.v_offset = shake.y

# where a point of the room shows on the 480x270 screen
func project(p: Vector3) -> Vector2:
	return cam.unproject_position(p)

# where an actor's sprite stands: its feet at the 2D shadow, raised by jumps
func feet(x: float, y: float, z: float, h: float) -> Vector3:
	return Vector3(x, z, y + h / 2.0 - 1)

# the point of the floor under a point of the 480x270 screen
func screen_to_floor(m: Vector2) -> Vector2:
	var o := cam.project_ray_origin(m)
	var d := cam.project_ray_normal(m)
	if absf(d.y) < 1e-6:
		return m
	var p := o + d * (-o.y / d.y)
	return Vector2(p.x, p.z)

# --- walls and rocks: one mesh, textured from the biome tileset ---

func build_solids(room: Dictionary) -> ArrayMesh:
	var biome := DB.biome_of(Run.floor.depth)
	var src := TilePick.tileset(biome.id).get_source(0) as TileSetAtlasSource
	var tex := src.texture
	var ts := Vector2(tex.get_size())
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var s: int = room.seed % 1000
	for ty in Consts.RH:
		for tx in Consts.RW:
			var t: int = room.grid[ty][tx]
			var x := float(Consts.RX + tx * Consts.TS)
			var z := float(Consts.RY + ty * Consts.TS)
			if t == Consts.T.WALL:
				var r := src.get_tile_texture_region(TilePick.coords(biome.id, TilePick.wall_key(tx, ty, s)))
				_box(st, room, tx, ty, x, z, Rect2(Vector2(r.position) / ts, Vector2(r.size) / ts))
			elif t == Consts.T.ROCK or t == Consts.T.CRACK:
				var r := src.get_tile_texture_region(TilePick.coords(biome.id, TilePick.rock_key(tx, ty, s, t == Consts.T.CRACK)))
				_rock(st, x + Consts.TS / 2.0, z + Consts.TS / 2.0, Rect2(Vector2(r.position) / ts, Vector2(r.size) / ts))
	st.generate_normals()
	var mesh := st.commit()
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	# rock stays matte; wet or metal walls are smoother and catch highlights
	var sh := Lighting.sheen(biome.id)
	m.roughness = 1.0 - 0.6 * sh
	m.metallic_specular = 0.5 * sh
	mesh.surface_set_material(0, m)
	return mesh

static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, uv: Rect2) -> void:
	# a b on top (uv top-left, top-right), d c below
	var u0 := uv.position
	var u1 := uv.position + Vector2(uv.size.x, 0)
	var u2 := uv.end
	var u3 := uv.position + Vector2(0, uv.size.y)
	for v in [[a, u0], [b, u1], [c, u2], [a, u0], [c, u2], [d, u3]]:
		st.set_uv(v[1])
		st.add_vertex(v[0])

static func _is_wall(room: Dictionary, tx: int, ty: int) -> bool:
	return tx >= 0 and ty >= 0 and tx < Consts.RW and ty < Consts.RH and room.grid[ty][tx] == Consts.T.WALL

func _box(st: SurfaceTool, room: Dictionary, tx: int, ty: int, x: float, z: float, uv: Rect2) -> void:
	var w := float(Consts.TS)
	var h := WALL_H
	st.set_smooth_group(0xFFFFFFFF)   # flat faces: smoothed edges would catch light like polished metal
	_quad(st, Vector3(x, h, z), Vector3(x + w, h, z), Vector3(x + w, h, z + w), Vector3(x, h, z + w), uv)
	# side faces only where nothing covers them
	if not _is_wall(room, tx, ty + 1):
		_quad(st, Vector3(x, h, z + w), Vector3(x + w, h, z + w), Vector3(x + w, 0, z + w), Vector3(x, 0, z + w), uv)
	if not _is_wall(room, tx, ty - 1):
		_quad(st, Vector3(x + w, h, z), Vector3(x, h, z), Vector3(x, 0, z), Vector3(x + w, 0, z), uv)
	if not _is_wall(room, tx - 1, ty):
		_quad(st, Vector3(x, h, z), Vector3(x, h, z + w), Vector3(x, 0, z + w), Vector3(x, 0, z), uv)
	if not _is_wall(room, tx + 1, ty):
		_quad(st, Vector3(x + w, h, z + w), Vector3(x + w, h, z), Vector3(x + w, 0, z), Vector3(x + w, 0, z + w), uv)

# a boulder: a low dome with the round rock sprite seen from above laid over it
func _rock(st: SurfaceTool, cx: float, cz: float, uv: Rect2) -> void:
	var n := 10
	var rings := [[0.0, 1.0], [0.5, 0.92], [0.85, 0.62], [1.0, 0.0]]   # height, radius (fractions)
	st.set_smooth_group(0)   # a smooth dome
	var c := uv.get_center()
	var k := uv.size / Consts.TS
	for ri in rings.size() - 1:
		for i in n:
			var pts: Array = []
			for q in [[ri, i], [ri, i + 1], [ri + 1, i + 1], [ri + 1, i]]:
				var a: float = TAU * q[1] / n
				var rr: float = rings[q[0]][1] * ROCK_R
				var off := Vector2(cos(a), sin(a)) * rr
				pts.append([Vector3(cx + off.x, rings[q[0]][0] * ROCK_H, cz + off.y), c + off * k])
			for v in [pts[0], pts[1], pts[2], pts[0], pts[2], pts[3]]:
				st.set_uv(v[1])
				st.add_vertex(v[0])

# --- actors standing up ---

func _new_sprite() -> Sprite3D:
	var s := Sprite3D.new()
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED   # faces the camera: no squashing
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.shaded = true
	s.region_enabled = true
	s.pixel_size = 1.0
	add_child(s)
	return s

func _sync_sprites() -> void:
	var live := {}
	var list: Array = Run.enemies.duplicate()
	if Run.player != null:
		list.append(Run.player)
	for a in list:
		if not is_instance_valid(a):
			continue
		var stt: Dictionary = a.sprite_state()
		if stt.is_empty():
			continue
		var id: int = a.get_instance_id()
		live[id] = true
		var s: Sprite3D = sprites.get(id)
		if s == null:
			s = _new_sprite()
			sprites[id] = s
		var h: float = Spr.size(stt.name).y
		_pose(s, stt, feet(stt.x, a.y, a.y - stt.y, h), 0.0)
	for id in sprites.keys():
		if not live.has(id):
			sprites[id].queue_free()
			sprites.erase(id)

# the objects of the room that stand up: barrels, braziers, chests, pickups...
# (the sprites DrawGround recorded last frame), on their bottom edge or on o.ground
func _sync_items() -> void:
	while item_pool.size() < items.size():
		item_pool.append(_new_sprite())
	for i in item_pool.size():
		var s := item_pool[i]
		s.visible = i < items.size()
		if not s.visible:
			continue
		var it: Dictionary = items[i]
		var h: float = Spr.size(it.name).y * float(it.o.get("scale", 1.0))
		var bottom: float = it.y + h / 2.0
		var ground: float = it.o.get("ground", bottom)
		# later ones sit a hair closer: a relic in front of its pedestal
		_pose(s, it, Vector3(it.x, maxf(0.0, ground - bottom), ground), i * 0.02)

func _pose(s: Sprite3D, stt: Dictionary, base: Vector3, bias: float) -> void:
	Spr.ensure()
	var d: Dictionary = Spr.db[stt.name]
	var o: Dictionary = stt.o
	var f := int(stt.frame) % int(d.frames)
	s.texture = d.sil if o.get("flash", false) else d.tex
	s.region_rect = Rect2(f * d.w, 0, d.w, d.h)
	s.flip_h = o.get("flip", false)
	s.offset = Vector2(0, d.h / 2.0)   # stands on its bottom edge
	var sc: float = o.get("scale", 1.0)
	s.scale = Vector3(sc, sc, sc)
	var c := Color.WHITE
	if o.get("tint") != null:
		c = c.lerp(UiDraw.col(o.tint), float(o.get("tintA", 0.5)))
	c.a = float(stt.get("alpha", o.get("alpha", 1.0)))
	s.modulate = c
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD if c.a >= 1.0 else SpriteBase3D.ALPHA_CUT_DISABLED
	# moved along the line of sight: the same place on the screen, nearer in depth
	s.position = base + (cam.position - base).normalized() * (SPRITE_BIAS + bias)

# --- the lights of the 2D lighting that reach the walls and the sprites ---

func _sync_lights() -> void:
	var amb := Lighting.ambient(DB.biome_of(Run.depth).dark, Run.depth, Run.room.cleared, Run.room.type == "boss", Run.player.oil <= 0, Run.room.combat)
	env.ambient_light_color = Color(0.55, 0.5, 0.7)
	env.ambient_light_energy = (1.0 - amb) * 1.6
	var de := Display.environment()
	env.adjustment_brightness = de.adjustment_brightness
	env.adjustment_contrast = de.adjustment_contrast
	env.adjustment_saturation = de.adjustment_saturation
	var L := Lights.collect()
	L.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return p.r * p.a > q.r * q.a)
	for i in MAX_LIGHTS:
		var l := lights[i]
		l.visible = i < L.size()
		if not l.visible:
			continue
		var d: Dictionary = L[i]
		l.position = Vector3(d.x, 24, d.y + 12)   # a bit toward the camera, to light the sprites' faces
		l.omni_range = d.r * 1.3
		l.light_energy = d.a * 2.2
		l.light_color = UiDraw.col(d.col) if d.get("col") != null else Color(1, 0.85, 0.6)
