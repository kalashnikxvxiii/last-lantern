class_name Lighting
extends CanvasLayer
# Darkness, glow and vignette (drawLighting in js/render.js) as fullscreen shaders.
# Godot-only: soft shadows and ambient occlusion from an occluder mask of the room.

const MAX_LIGHTS := 128
const OCC_RES := 4                 # occluder mask texels per tile
const SHADOW_MIN_R := 40.0         # smaller lights (projectiles, pickups) cast no shadow
const SHADOW_STEPS := {"off": 0, "low": 12, "high": 24, "ultra": 40}
const AO := 0.35
var light := ColorRect.new()
var vignette := ColorRect.new()
var occ_tex: ImageTexture
var occ_key := 0

func _ready() -> void:
	layer = 1
	for pair in [[light, "lighting"], [vignette, "vignette"]]:
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
	L = L.slice(0, n)
	var sn := shadow_first(L)
	for i in n:
		var l: Dictionary = L[i]
		pos[i] = Vector4(l.x + offset.x, l.y + offset.y, maxf(4.0, l.r), l.a)
		if l.get("col") != null:
			var c := UiDraw.col(l.col)
			cols[i] = Vector4(c.r, c.g, c.b, l.get("ga", 0.1))
	var m := light.material as ShaderMaterial
	m.set_shader_parameter("amb", amb)
	m.set_shader_parameter("count", n)
	m.set_shader_parameter("lights", pos)
	m.set_shader_parameter("colors", cols)
	# shadows and ambient occlusion
	var steps: int = SHADOW_STEPS.get(str(Save.data.settings.shadows), 0)
	var ao: float = AO if Save.data.settings.ao else 0.0
	m.set_shader_parameter("shadow_n", sn if steps > 0 else 0)
	m.set_shader_parameter("shadow_steps", steps)
	m.set_shader_parameter("ao", ao)
	if steps > 0 or ao > 0.0:
		var key := hash(room.grid)
		if occ_tex == null or key != occ_key:
			occ_key = key
			occ_tex = ImageTexture.create_from_image(occluder_mask(room))
		m.set_shader_parameter("occ", occ_tex)
		m.set_shader_parameter("room_pos", Vector2(Consts.RX + offset.x, Consts.RY + offset.y))

# moves the lights that cast shadows (radius >= SHADOW_MIN_R) to the front, keeping
# the order inside each group, and returns how many they are. The darkness multiplies
# and the glow adds, so the order does not change the picture.
static func shadow_first(L: Array) -> int:
	var big: Array = []
	var small: Array = []
	for l in L:
		(big if l.r >= SHADOW_MIN_R else small).append(l)
	L.clear()
	L.append_array(big)
	L.append_array(small)
	return big.size()

# what blocks the light, OCC_RES texels per tile: walls fill their tile, rocks are
# round, barrels and urns are small; floor, doors, spikes and braziers let it through
static func occluder_mask(room: Dictionary) -> Image:
	var img := Image.create(Consts.RW * OCC_RES, Consts.RH * OCC_RES, false, Image.FORMAT_R8)
	for ty in Consts.RH:
		for tx in Consts.RW:
			var t: int = room.grid[ty][tx]
			for y in OCC_RES:
				for x in OCC_RES:
					var edge_x := x == 0 or x == OCC_RES - 1
					var edge_y := y == 0 or y == OCC_RES - 1
					var v := 0.0
					match t:
						Consts.T.WALL:
							v = 1.0
						Consts.T.ROCK, Consts.T.CRACK:
							v = 0.0 if edge_x and edge_y else 1.0
						Consts.T.BARREL, Consts.T.URN:
							v = 0.0 if edge_x or edge_y else 1.0
					img.set_pixel(tx * OCC_RES + x, ty * OCC_RES + y, Color(v, 0, 0))
	return img
