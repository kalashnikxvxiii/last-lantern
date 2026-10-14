extends Node
# Permanent save (from Save in js/core.js), in user://save.json.

const DEFAULT_PATH := "user://save.json"
var path := DEFAULT_PATH
var data: Dictionary = {}

func _ready() -> void:
	load_save()

static func defaults() -> Dictionary:
	return {
		"settings": {"music": 0.5, "sfx": 0.7, "shake": true, "numbers": true, "fullscreenHint": true, "res": 2,
			# Godot-only display and graphics settings (Display)
			"windowMode": "windowed", "vsync": "on", "fpsCap": 0, "scaling": "fit",
			"brightness": 1.0, "contrast": 1.0, "saturation": 1.0, "showFps": false,
			"bloom": "medium", "shadows": "high", "ao": true, "particles": "high",
			"grading": true, "screenFx": true, "crt": false, "qualityPicked": false},
		"stats": {"runs": 0, "wins": 0, "bestDepth": 0, "kills": 0, "bossKills": 0, "bestTime": 0, "maxArdorWon": -1},
		"unlocks": {"lanterns": ["warden"], "ardor": 0},
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
	elif d.get("settings") is Dictionary and not d.settings.has("qualityPicked"):
		d.settings.qualityPicked = true   # Godot-only: a save from before the presets keeps its settings
	d.settings = _merge(def.settings, d.get("settings"))
	d.stats = _ints(_merge(def.stats, d.get("stats")))
	d.unlocks = _ints(_merge(def.unlocks, d.get("unlocks")))
	if not (d.unlocks.lanterns is Array):
		d.unlocks.lanterns = ["warden"]
	if not (d.get("seen") is Dictionary):
		d.seen = {}
	data = d

static func _merge(def: Dictionary, v: Variant) -> Dictionary:
	if v is Dictionary:
		for k in v:
			def[k] = v[k]
	return def

# JSON only returns floats: counters go back to integers
static func _ints(d: Dictionary) -> Dictionary:
	for k in d:
		if typeof(d[k]) == TYPE_FLOAT and d[k] == floor(d[k]):
			d[k] = int(d[k])
	return d

# writes to a temporary file and replaces the save only if everything
# went well: with a full disk the previous save stays intact
# (like localStorage.setItem in the JS, which fails without touching the old value)
func write() -> bool:
	return write_file(path, JSON.stringify(data).to_utf8_buffer())

static func write_file(dest: String, bytes: PackedByteArray) -> bool:
	var tmp := dest + ".new"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false   # storage unavailable: ignored, as in the JS
	f.store_buffer(bytes)
	var ok := f.get_error() == OK
	f.close()
	if not ok or DirAccess.rename_absolute(tmp, dest) != OK:
		DirAccess.remove_absolute(tmp)
		return false
	return true

func unlock_lantern(id: String) -> bool:
	if not data.unlocks.lanterns.has(id):
		data.unlocks.lanterns.append(id)
		write()
		return true
	return false
