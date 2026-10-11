extends TestCase
# Effetti sonori: varianti caricate, intervalli minimi, volume a zero.

func before() -> void:
	Sfx.last.clear()
	Save.data.settings.sfx = 0.7

func test_tutti_i_suoni_hanno_tre_varianti() -> void:
	eq(Sfx.NAMES.size(), 33)
	for n in Sfx.NAMES:
		eq(Sfx.streams[n].size(), 3, n)

func test_intervallo_minimo() -> void:
	check(Sfx.play("coin"), "primo coin")
	check(not Sfx.play("coin"), "secondo coin entro 0,04 s")
	check(Sfx.play("hit"), "altro suono")

func test_volume_zero_e_nomi_sconosciuti() -> void:
	check(not Sfx.play("inesistente"))
	Save.data.settings.sfx = 0.0
	check(not Sfx.play("door"))
	Save.data.settings.sfx = 0.7

func test_bus_audio() -> void:
	check(AudioServer.get_bus_index("Sfx") > 0)
	check(AudioServer.get_bus_index("Music") > 0)
