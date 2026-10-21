extends TestCase
# Sound effects: loaded variants, minimum intervals, zero volume.

func before() -> void:
	Sfx.last.clear()
	Save.data.settings.sfx = 0.7

func test_every_sound_has_three_variants() -> void:
	eq(Sfx.NAMES.size(), 34)   # 33 from the JS + the Godot-only "ash"
	for n in Sfx.NAMES:
		eq(Sfx.streams[n].size(), 3, n)

func test_minimum_interval() -> void:
	check(Sfx.play("coin"), "first coin")
	check(not Sfx.play("coin"), "second coin within 0.04 s")
	check(Sfx.play("hit"), "other sound")

func test_zero_volume_and_unknown_names() -> void:
	check(not Sfx.play("nonexistent"))
	Save.data.settings.sfx = 0.0
	check(not Sfx.play("door"))
	Save.data.settings.sfx = 0.7

func test_audio_bus() -> void:
	check(AudioServer.get_bus_index("Sfx") > 0)
	check(AudioServer.get_bus_index("Music") > 0)
