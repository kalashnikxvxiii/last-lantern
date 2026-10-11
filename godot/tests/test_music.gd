extends TestCase
# Musica: tracce sincronizzate a strati e dissolvenza tra le intensità.

func after() -> void:
	Music.stop()

func test_tracce_complete() -> void:
	for t in ["title", "crypt", "fungus", "forge", "abyss", "heart"]:
		for s in Music.STEMS:
			check(ResourceLoader.exists("res://assets/music/%s_%s.ogg" % [t, s]), "%s_%s" % [t, s])

func test_play_e_intensita() -> void:
	Music.play("crypt")
	eq(Music.track_name, "crypt")
	var st := Music.cur.stream as AudioStreamSynchronized
	eq(st.stream_count, 6)
	Music.set_intensity(0)
	Music.step(5.0)
	eq(Music.gains, [1.0, 1.0, 0.0, 0.0, 0.0, 0.0])
	Music.set_intensity(2)
	Music.step(0.4)
	check(Music.gains[3] > 0.0 and Music.gains[3] < 1.0, "dissolvenza in corso")
	Music.step(5.0)
	eq(Music.gains, [1.0, 0.0, 0.0, 1.0, 1.0, 1.0])

func test_stessa_traccia_non_riparte() -> void:
	Music.play("title")
	var p := Music.cur
	Music.play("title")
	check(Music.cur == p, "stesso player")
