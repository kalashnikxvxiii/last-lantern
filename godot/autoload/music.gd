extends Node
# Music (from Music in js/audio.js): each track is an AudioStreamSynchronized of
# 6 recorded layers; the intensity chooses which layers play, with crossfade.

const STEMS := ["drone", "arp_lo", "arp", "arp_hi", "bass", "hats"]
const MIX := [   # linear volume of each layer at intensities 0, 1, 2
	[1.0, 1.0, 0.0, 0.0, 0.0, 0.0],
	[1.0, 0.0, 1.0, 0.0, 1.0, 1.0],
	[1.0, 0.0, 0.0, 1.0, 1.0, 1.0],
]
const FADE_IN := 2.5     # like the drone rise in the JS
const FADE_OUT := 1.2
const MIX_SPEED := 1.25  # a full crossfade between intensities lasts 0.8 s

var track_name := ""
var intensity := 0
var gains: Array = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var cur: AudioStreamPlayer
var cur_fade := 0.0
var old: AudioStreamPlayer
var old_fade := 0.0

func play(track: String) -> void:
	if track == track_name:
		return
	track_name = track
	if old != null:
		old.queue_free()
	old = cur
	old_fade = cur_fade
	var s := AudioStreamSynchronized.new()
	s.stream_count = STEMS.size()
	for i in STEMS.size():
		var st: AudioStreamOggVorbis = load("res://assets/music/%s_%s.ogg" % [track, STEMS[i]])
		st.loop = true
		s.set_sync_stream(i, st)
	cur = AudioStreamPlayer.new()
	cur.bus = "Music"
	cur.stream = s
	add_child(cur)
	cur_fade = 0.0
	gains = MIX[intensity].duplicate()
	_apply()
	cur.play()

func set_intensity(i: int) -> void:
	intensity = clampi(i, 0, 2)

func stop() -> void:
	track_name = ""
	if old != null:
		old.queue_free()
	old = cur
	old_fade = cur_fade
	cur = null

func _process(delta: float) -> void:
	step(delta)

func step(delta: float) -> void:
	if cur != null:
		cur_fade = minf(1.0, cur_fade + delta / FADE_IN)
		for i in STEMS.size():
			gains[i] = U.approach(gains[i], MIX[intensity][i], MIX_SPEED * delta)
		_apply()
	if old != null:
		old_fade = maxf(0.0, old_fade - delta / FADE_OUT)
		old.volume_db = linear_to_db(maxf(0.0001, old_fade))
		if old_fade <= 0.0:
			old.queue_free()
			old = null

func _apply() -> void:
	cur.volume_db = linear_to_db(maxf(0.0001, cur_fade))
	var s := cur.stream as AudioStreamSynchronized
	for i in STEMS.size():
		s.set_sync_stream_volume(i, linear_to_db(maxf(0.0001, gains[i])))
