class_name TilePick
extends RefCounted
# Picks tile variants with the same hash2 as renderRoomBg (js/dungeon.js).

static var _layout: Dictionary = {}
static var _sets: Dictionary = {}

static func _ensure() -> void:
	if not _layout.is_empty():
		return
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string("res://assets/tiles/layout.json")) == OK:
		_layout = j.data

static func floor_key(tx: int, ty: int, s: int) -> String:
	var h := U.hash2(tx, ty, s)
	var kind := "crack" if h < 0.08 else ("seam" if h > 0.55 else "plain")
	var g := int(floor(U.hash2(tx, ty, s + 5) * 6))
	return "floor_c%d_%s_g%d" % [int(floor(h * 3)), kind, g]

static func wall_key(tx: int, ty: int, s: int) -> String:
	var xe := tx == 0 or tx == Consts.RW - 1
	var ye := ty == 0 or ty == Consts.RH - 1
	var edge: String
	if xe and ye:
		edge = "corner"
	elif ty == 0:
		edge = "top"
	elif ty == Consts.RH - 1:
		edge = "bottom"
	elif tx == 0:
		edge = "left%d" % (ty % 2)
	else:
		edge = "right%d" % (ty % 2)
	return "wall_%s_%d" % [edge, 1 if U.hash2(tx, ty, s + 77) < 0.1 else 0]

# the top face of a wall in the 3D view (Godot only): four cells that tile as one 2x2 texture
static func cap_key(tx: int, ty: int) -> String:
	return "wall_cap_%d" % (tx % 2 + 2 * (ty % 2))

static func rock_key(tx: int, ty: int, s: int, cracked: bool) -> String:
	return "rock_%d_%d" % [1 if cracked else 0, 1 if U.hash2(tx, ty, s) > 0.5 else 0]

# Godot-only: what a blown rock leaves on the floor
static func rubble_key(tx: int, ty: int, s: int) -> String:
	return "rubble_%d" % (1 if U.hash2(ty, tx, s) > 0.5 else 0)

static func coords(biome_id: String, key: String) -> Vector2i:
	_ensure()
	var c: Variant = _layout.biomes.get(biome_id, {}).get(key)
	if c == null:
		return Vector2i(-1, -1)
	return Vector2i(int(c[0]), int(c[1]))

static func tileset(biome_id: String) -> TileSet:
	if not _sets.has(biome_id):
		_sets[biome_id] = load("res://assets/tiles/%s.tres" % biome_id)
	return _sets[biome_id]
