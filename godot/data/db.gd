class_name DB
extends RefCounted
# Accesso alle Resource dei dati di gioco.

const LANTERN_IDS := ["custode", "pellegrino", "spezzata", "cava", "nera"]
const BIOME_IDS := ["crypt"]   # le altre profondità arriveranno con i prossimi sotto-progetti
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
	return l if l != null else _res("res://data/lanterns/custode.tres")

static func lanterns() -> Array:
	return LANTERN_IDS.map(func(id): return lantern(id))

static func biome_of(depth: int) -> BiomeDef:
	return _res("res://data/biomes/%s.tres" % BIOME_IDS[(depth - 1) % BIOME_IDS.size()])
