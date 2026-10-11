extends Node
# Salvataggio permanente (da Save in js/core.js), in user://save.json.

const DEFAULT_PATH := "user://save.json"
var path := DEFAULT_PATH
var data: Dictionary = {}

func _ready() -> void:
	load_save()

static func defaults() -> Dictionary:
	return {
		"settings": {"music": 0.5, "sfx": 0.7, "shake": true, "numbers": true, "fullscreenHint": true},
		"stats": {"runs": 0, "wins": 0, "bestDepth": 0, "kills": 0, "bossKills": 0, "bestTime": 0, "maxArdoreWon": -1},
		"unlocks": {"lanterns": ["custode"], "ardore": 0},
		"seen": {},
	}

func load_save() -> void:
	var d: Variant = null
	if FileAccess.file_exists(path):
		var j := JSON.new()
		if j.parse(FileAccess.get_file_as_string(path)) == OK:
			d = j.data
	var def := defaults()
	if not (d is Dictionary):
		d = def
	d.settings = _merge(def.settings, d.get("settings"))
	d.stats = _ints(_merge(def.stats, d.get("stats")))
	d.unlocks = _ints(_merge(def.unlocks, d.get("unlocks")))
	if not (d.unlocks.lanterns is Array):
		d.unlocks.lanterns = ["custode"]
	if not (d.get("seen") is Dictionary):
		d.seen = {}
	data = d

static func _merge(def: Dictionary, v: Variant) -> Dictionary:
	if v is Dictionary:
		for k in v:
			def[k] = v[k]
	return def

# il JSON restituisce solo float: i contatori tornano interi
static func _ints(d: Dictionary) -> Dictionary:
	for k in d:
		if typeof(d[k]) == TYPE_FLOAT and d[k] == floor(d[k]):
			d[k] = int(d[k])
	return d

func write() -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false   # storage non disponibile: come nel JS si ignora
	f.store_string(JSON.stringify(data))
	f.close()
	return true

func unlock_lantern(id: String) -> bool:
	if not data.unlocks.lanterns.has(id):
		data.unlocks.lanterns.append(id)
		write()
		return true
	return false
