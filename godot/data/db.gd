class_name DB
extends RefCounted
# Access to the game data Resources.

const LANTERN_IDS := ["warden", "pilgrim", "broken", "hollow", "black"]
const CHARACTER_IDS := ["wanderer", "goblin", "stranger", "cogling", "owlfox", "wizard"]   # Godot-only
const BIOME_IDS := ["crypt", "fungus", "forge", "abyss", "heart"]
static var _cache: Dictionary = {}

static func _res(path: String) -> Resource:
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]

static func enemy(id: String) -> EnemyDef:
	return _res("res://data/enemies/%s.tres" % id)

static func boss(id: String) -> BossDef:
	return _res("res://data/bosses/%s.tres" % id)

static func lantern(id: String) -> LanternDef:
	var l := _res("res://data/lanterns/%s.tres" % id) as LanternDef
	return l if l != null else _res("res://data/lanterns/warden.tres")

static func lanterns() -> Array:
	return LANTERN_IDS.map(func(id): return lantern(id))

static func character(id: String) -> CharacterDef:
	var c := _res("res://data/characters/%s.tres" % id) as CharacterDef
	return c if c != null else _res("res://data/characters/wanderer.tres")

static func characters() -> Array:
	return CHARACTER_IDS.map(func(id): return character(id))

static func biome_of(depth: int) -> BiomeDef:
	return _res("res://data/biomes/%s.tres" % BIOME_IDS[(depth - 1) % BIOME_IDS.size()])
