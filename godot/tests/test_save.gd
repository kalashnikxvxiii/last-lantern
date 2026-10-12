extends TestCase
# Salvataggio: tollerante come Save.load nel JS.

const P := "user://test_save_case.json"

func before() -> void:
	Save.path = P
	DirAccess.remove_absolute(ProjectSettings.globalize_path(P))

func after() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(P))
	Save.path = "user://test_save.json"
	Save.load_save()

func _write_raw(text: String) -> void:
	var f := FileAccess.open(P, FileAccess.WRITE)
	f.store_string(text)
	f.close()

func test_senza_file_usa_i_default() -> void:
	Save.load_save()
	eq(Save.data, Save.defaults())

func test_campi_mancanti_presi_dai_default() -> void:
	_write_raw('{"settings": {"music": 0.2}, "stats": {"runs": 4}}')
	Save.load_save()
	eq(Save.data.settings.music, 0.2)
	eq(Save.data.settings.sfx, 0.7)
	eq(Save.data.stats.runs, 4)
	check(typeof(Save.data.stats.runs) == TYPE_INT, "runs deve restare intero")
	eq(Save.data.unlocks.lanterns, ["custode"])
	eq(Save.data.seen, {})

func test_file_corrotto_usa_i_default() -> void:
	_write_raw("{non è json")
	Save.load_save()
	eq(Save.data, Save.defaults())

func test_lanterne_non_array_ripristinate() -> void:
	_write_raw('{"unlocks": {"lanterns": "custode", "ardore": 2}}')
	Save.load_save()
	eq(Save.data.unlocks.lanterns, ["custode"])
	eq(Save.data.unlocks.ardore, 2)

func test_scrittura_e_rilettura() -> void:
	Save.load_save()
	Save.data.stats.kills = 12
	check(Save.unlock_lantern("pellegrino"), "prima volta: sbloccata")
	check(not Save.unlock_lantern("pellegrino"), "seconda volta: già sbloccata")
	Save.load_save()
	eq(Save.data.stats.kills, 12)
	eq(Save.data.unlocks.lanterns, ["custode", "pellegrino"])

func test_write_failure_is_silent() -> void:
	allow_errors()
	Save.path = "user://cartella_inesistente/sotto/save.json"
	Save.data = Save.defaults()
	Save.data.stats.runs = 3
	check(not Save.write(), "la scrittura deve fallire")
	eq(Save.data.stats.runs, 3, "i dati in memoria restano")

func test_scrittura_atomica_non_distrugge_il_salvataggio() -> void:
	# il salvataggio passa da un file temporaneo: se non si può scrivere,
	# il file buono resta com'era e write() segnala il fallimento
	allow_errors()
	Save.load_save()
	Save.data.stats.runs = 5
	check(Save.write())
	var tmp := ProjectSettings.globalize_path(P + ".new")
	DirAccess.make_dir_absolute(tmp)
	Save.data.stats.runs = 9
	check(not Save.write(), "il temporaneo non si può creare")
	DirAccess.remove_absolute(tmp)
	Save.load_save()
	eq(Save.data.stats.runs, 5, "il salvataggio precedente è intatto")
