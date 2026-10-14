extends TestCase
# Save: tolerant like Save.load in the JS.

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

func test_without_file_uses_defaults() -> void:
	Save.load_save()
	eq(Save.data, Save.defaults())

func test_missing_fields_use_defaults() -> void:
	_write_raw('{"settings": {"music": 0.2}, "stats": {"runs": 4}}')
	Save.load_save()
	eq(Save.data.settings.music, 0.2)
	eq(Save.data.settings.sfx, 0.7)
	eq(Save.data.stats.runs, 4)
	check(typeof(Save.data.stats.runs) == TYPE_INT, "runs must stay an integer")
	eq(Save.data.unlocks.lanterns, ["warden"])
	eq(Save.data.seen, {})

# Godot-only: a save from before the quality presets keeps the player's graphics settings
func test_old_save_counts_as_quality_picked() -> void:
	_write_raw('{"settings": {"bloom": "off"}}')
	Save.load_save()
	eq(Save.data.settings.qualityPicked, true)
	eq(Save.data.settings.bloom, "off")

func test_corrupt_file_uses_defaults() -> void:
	_write_raw("{not json")
	Save.load_save()
	eq(Save.data, Save.defaults())

func test_non_array_lanterns_restored() -> void:
	_write_raw('{"unlocks": {"lanterns": "warden", "ardor": 2}}')
	Save.load_save()
	eq(Save.data.unlocks.lanterns, ["warden"])
	eq(Save.data.unlocks.ardor, 2)

func test_write_and_reread() -> void:
	Save.load_save()
	Save.data.stats.kills = 12
	check(Save.unlock_lantern("pilgrim"), "first time: unlocked")
	check(not Save.unlock_lantern("pilgrim"), "second time: already unlocked")
	Save.load_save()
	eq(Save.data.stats.kills, 12)
	eq(Save.data.unlocks.lanterns, ["warden", "pilgrim"])

func test_write_failure_is_silent() -> void:
	allow_errors()
	Save.path = "user://missing_folder/sub/save.json"
	Save.data = Save.defaults()
	Save.data.stats.runs = 3
	check(not Save.write(), "the write must fail")
	eq(Save.data.stats.runs, 3, "the in-memory data stays")

func test_atomic_write_does_not_destroy_the_save() -> void:
	# the save goes through a temporary file: if it cannot be written,
	# the good file stays as it was and write() reports the failure
	allow_errors()
	Save.load_save()
	Save.data.stats.runs = 5
	check(Save.write())
	var tmp := ProjectSettings.globalize_path(P + ".new")
	DirAccess.make_dir_absolute(tmp)
	Save.data.stats.runs = 9
	check(not Save.write(), "the temporary file cannot be created")
	DirAccess.remove_absolute(tmp)
	Save.load_save()
	eq(Save.data.stats.runs, 5, "the previous save is intact")
