extends Node
# Sound effects (from Sound in js/audio.js): variants recorded offline,
# minimum intervals between repeats, compressor bus and option volumes.

const NAMES := ["shoot", "hit", "crit", "kill", "hurt", "coin", "xp", "pickup", "heal", "oil", "levelup", "dash", "flare",
	"explosion", "door", "lock", "enemyShoot", "spawn", "roar", "select", "confirm", "deny", "chest", "buy", "curse", "shield",
	"freeze", "thud", "bolt", "tick", "descend", "warn", "block", "ash"]
const GAP := {"shoot": 0.045, "hit": 0.035, "xp": 0.03, "coin": 0.04, "enemyShoot": 0.05, "kill": 0.04, "tick": 0.05,
	"ash": 0.06}   # "ash" is Godot-only: the restart light turns enemies to ash
const VOICES := 24

var streams: Dictionary = {}   # name -> Array of AudioStream
var last: Dictionary = {}      # name -> seconds of the last playback
var players: Array[AudioStreamPlayer] = []
var next_voice := 0
var variety := RNG.new(12345)  # variant choice: does not touch game randomness

func _ready() -> void:
	_setup_buses()
	for n in NAMES:
		var arr: Array = []
		for v in range(1, 4):
			var p := "res://assets/sfx/%s_%d.wav" % [n, v]
			if ResourceLoader.exists(p):
				arr.append(load(p))
		streams[n] = arr
	for i in VOICES:
		var pl := AudioStreamPlayer.new()
		pl.bus = "Sfx"
		add_child(pl)
		players.append(pl)
	apply_volumes()

func _setup_buses() -> void:
	if AudioServer.get_bus_index("Sfx") != -1:
		return
	AudioServer.set_bus_volume_db(0, linear_to_db(0.9))
	var comp := AudioEffectCompressor.new()
	comp.threshold = -14.0
	comp.ratio = 4.0
	AudioServer.add_bus_effect(0, comp)
	for bus_name in ["Sfx", "Music"]:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, bus_name)
		AudioServer.set_bus_send(i, "Master")

func apply_volumes() -> void:
	var s: Dictionary = Save.data.settings
	var si := AudioServer.get_bus_index("Sfx")
	var mi := AudioServer.get_bus_index("Music")
	AudioServer.set_bus_volume_db(si, linear_to_db(maxf(0.0001, s.sfx * 0.8)))
	AudioServer.set_bus_mute(si, s.sfx <= 0)
	AudioServer.set_bus_volume_db(mi, linear_to_db(maxf(0.0001, s.music * 0.55)))
	AudioServer.set_bus_mute(mi, s.music <= 0)

func play(name: String, vol: float = 1.0) -> bool:
	if Save.data.settings.sfx <= 0:
		return false
	var arr: Array = streams.get(name, [])
	if arr.is_empty():
		return false
	var now := Time.get_ticks_usec() / 1000000.0
	if last.has(name) and now - last[name] < GAP.get(name, 0.02):
		return false
	last[name] = now
	var pl := players[next_voice]
	next_voice = (next_voice + 1) % VOICES
	pl.stream = variety.pick(arr)
	pl.volume_db = linear_to_db(maxf(0.0001, vol))
	pl.play()
	return true
