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
const LOOK_DY := 0.0         # the camera looks at the middle of the room (the top bar it made room for is gone)
const WALL_H := 24.0           # a tile and a half
const ROCK_H := 11.0
const ROCK_R := 7.5
const AIR_H := 8.0           # height of the projectiles' plane
const SPRITE_BIAS := 8.0     # sprites move this much toward the camera: no clipping into walls
const MAX_LIGHTS := 12
const SHADOW_LIGHTS := 3
const GATE_SPEED := 60.0     # px/s: a gate sinks into the floor (or rises) in 0.4 s

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
var gates: Dictionary = {}     # door dir -> its bars, lowered into the floor while the door is open

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

func _process(delta: float) -> void:
	if not Run.active or Run.room.is_empty():
		return
	if not is_same(Run.room, shown) or Run.room.get("bgDirty", false):
		solids.mesh = build_solids(Run.room)
		build_gates(Run.room, not is_same(Run.room, shown))
		shown = Run.room
	sync_gates(delta)
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

# whether a wall or a rock stands between p and the camera: the lifted 2D details
# are drawn over the whole 3D room, so they ask before drawing
func hidden(p: Vector3) -> bool:
	var d := (cam.position - p).normalized()
	var q := p
	while q.y < WALL_H:
		var tx := floori((q.x - Consts.RX) / Consts.TS)
		var ty := floori((q.z - Consts.RY) / Consts.TS)
		if tx >= 0 and ty >= 0 and tx < Consts.RW and ty < Consts.RH:
			var t: int = Run.room.grid[ty][tx]
			if t == Consts.T.WALL:
				return true
		if _in_rock(q):
			return true
		q += d * 2.0
	return false

func _in_rock(q: Vector3) -> bool:
	if q.y >= ROCK_H:
		return false
	var tx := floori((q.x - Consts.RX) / Consts.TS)
	var ty := floori((q.z - Consts.RY) / Consts.TS)
	var t := RoomU.tile_at(Run.room, tx, ty)
	if t != Consts.T.ROCK and t != Consts.T.CRACK:
		return false
	var c := RoomU.tile_center(tx, ty)
	return Vector2(q.x - c.x, q.z - c.y).length() < ROCK_R

# how far a sprite standing at base moves toward the camera: SPRITE_BIAS, but not
# out of a rock in front of it, or it would show over the rock as if standing in it
func sprite_bias(base: Vector3) -> float:
	var d := (cam.position - base).normalized()
	var k := 0.0
	while k < SPRITE_BIAS and not _in_rock(base + d * k):
		k += 1.0
	return k

# the middle of a standing sprite whose feet are at base, where _pose puts it: the
# billboard stands along the camera's up, which leans back toward the far wall
func sprite_mid(base: Vector3, h: float) -> Vector3:
	return base + (cam.position - base).normalized() * sprite_bias(base) + cam.basis.y * (h / 2.0)

# where a light of the 2D lighting hangs: a bit toward the camera, to light the
# sprites' faces, but never inside a wall, which would light its front from within
func light_pos(x: float, y: float) -> Vector3:
	var z := y + 12.0
	while z > y - 12.0 and _is_wall(Run.room, floori((x - Consts.RX) / Consts.TS), floori((z + 4.0 - Consts.RY) / Consts.TS)):
		z -= 1.0   # and 4 px away from it, even behind the source
	return Vector3(x, 24, z)

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
				var face := Rect2(Vector2(r.position) / ts, Vector2(r.size) / ts)
				# the top gets its own tiles where the biome has them, else the face again
				var cap := face
				var cc := TilePick.coords(biome.id, TilePick.cap_key(tx, ty))
				if cc != Vector2i(-1, -1):
					r = src.get_tile_texture_region(cc)
					cap = Rect2(Vector2(r.position) / ts, Vector2(r.size) / ts)
				_box(st, room, tx, ty, x, z, face, cap)
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

func _box(st: SurfaceTool, room: Dictionary, tx: int, ty: int, x: float, z: float, uv: Rect2, cap: Rect2) -> void:
	var w := float(Consts.TS)
	var h := WALL_H
	st.set_smooth_group(0xFFFFFFFF)   # flat faces: smoothed edges would catch light like polished metal
	_quad(st, Vector3(x, h, z), Vector3(x + w, h, z), Vector3(x + w, h, z + w), Vector3(x, h, z + w), cap)
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

# --- the gates of the doors: bars that rise from the floor like the walls ---

# entering a room the gates are already where the doors want them, except the one
# the player came in through: it starts down and closes behind them
func build_gates(room: Dictionary, entering: bool) -> void:
	for g in gates.values():
		g.free()
	gates = {}
	var entry := ""
	if entering and Run.player != null:
		var best := Consts.TS * 3.0
		for d in room.doors:
			var k := RoomU.door_center(d).distance_to(Vector2(Run.player.x, Run.player.y))
			if k < best:
				best = k
				entry = d
	for d in room.doors:
		if not RoomU.door_visible(room, d) or DrawGround._door_style(room, d).kind == "secret":
			continue
		var t0: Array = RoomU.DIRS[d].tiles[0]
		var x := float(Consts.RX + t0[0] * Consts.TS)
		var z := float(Consts.RY + t0[1] * Consts.TS)
		var horiz: bool = d == "n" or d == "s"
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		# the 2D bars (DrawGround._doors) in the middle of the doorway, and two crossbars
		var m := Consts.TS / 2.0 - 1.0
		for i in 6:
			var a := 7.0 + i * 6
			_bar(st, Vector3(x + a, 0, z + m) if horiz else Vector3(x + m, 0, z + a), Vector3(2, WALL_H, 2))
		for y in [8.0, 18.0]:
			_bar(st, Vector3(x + 4, y, z + m) if horiz else Vector3(x + m, y, z + 4), Vector3(40, 2, 2) if horiz else Vector3(2, 2, 40))
		st.generate_normals()
		var g := MeshInstance3D.new()
		g.mesh = st.commit()
		g.material_override = StandardMaterial3D.new()
		g.position.y = -WALL_H if RoomU.door_open(room, d) or d == entry else 0.0
		gates[d] = g
		add_child(g)

# each gate moves toward its place: down in the floor when the door is open
func sync_gates(delta: float) -> void:
	for d in gates:
		var g: MeshInstance3D = gates[d]
		var to := -WALL_H if RoomU.door_open(Run.room, d) else 0.0
		g.position.y = move_toward(g.position.y, to, GATE_SPEED * delta)
		g.visible = g.position.y > -WALL_H
		(g.material_override as StandardMaterial3D).albedo_color = UiDraw.col("#c49a3a" if RoomU.door_locked(Run.room, d) else "#6b6478")

# a box from p (its lowest corner) of size s
static func _bar(st: SurfaceTool, p: Vector3, s: Vector3) -> void:
	var q := p + s
	var uv := Rect2()
	st.set_smooth_group(0xFFFFFFFF)
	_quad(st, Vector3(p.x, q.y, p.z), Vector3(q.x, q.y, p.z), Vector3(q.x, q.y, q.z), Vector3(p.x, q.y, q.z), uv)
	_quad(st, Vector3(p.x, q.y, q.z), Vector3(q.x, q.y, q.z), Vector3(q.x, p.y, q.z), Vector3(p.x, p.y, q.z), uv)
	_quad(st, Vector3(q.x, q.y, p.z), Vector3(p.x, q.y, p.z), Vector3(p.x, p.y, p.z), Vector3(q.x, p.y, p.z), uv)
	_quad(st, Vector3(p.x, q.y, p.z), Vector3(p.x, q.y, q.z), Vector3(p.x, p.y, q.z), Vector3(p.x, p.y, p.z), uv)
	_quad(st, Vector3(q.x, q.y, q.z), Vector3(q.x, q.y, p.z), Vector3(q.x, p.y, p.z), Vector3(q.x, p.y, q.z), uv)

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
		# raised along the camera's up, like the billboards: the same lift on the screen
		# as in 2D (straight up it would shrink by the tilt and sink into a pedestal);
		# later ones sit a hair closer: a relic in front of its pedestal
		var lift := cam.basis.y * maxf(0.0, ground - bottom)
		_pose(s, it, Vector3(it.x, 0.0, ground) + lift, i * 0.02)

func _pose(s: Sprite3D, stt: Dictionary, base: Vector3, bias: float) -> void:
	Spr.ensure()
	var d: Dictionary = Spr.db[stt.name]
	var o: Dictionary = stt.o
	var f := int(stt.frame) % int(d.frames)
	s.texture = d.sil if o.get("flash", false) else d.tex
	s.region_rect = Spr.src_rect(d, f)
	s.pixel_size = 1.0 / d.k   # HD art: k texels per logical pixel
	s.flip_h = o.get("flip", false)
	s.offset = Vector2(0, d.h * d.k / 2.0)   # stands on its bottom edge (in texels)
	var sc: float = o.get("scale", 1.0)
	s.scale = Vector3(sc, sc, sc)
	var c := Color.WHITE
	if o.get("tint") != null:
		c = c.lerp(UiDraw.col(o.tint), float(o.get("tintA", 0.5)))
	c.a = float(stt.get("alpha", o.get("alpha", 1.0)))
	s.modulate = c
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD if c.a >= 1.0 else SpriteBase3D.ALPHA_CUT_DISABLED
	# moved along the line of sight: the same place on the screen, nearer in depth
	s.position = base + (cam.position - base).normalized() * (sprite_bias(base) + bias)

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
		l.position = light_pos(d.x, d.y)
		l.omni_range = d.r * 1.3
		l.light_energy = d.a * 2.2
		l.light_color = UiDraw.col(d.col) if d.get("col") != null else Color(1, 0.85, 0.6)
