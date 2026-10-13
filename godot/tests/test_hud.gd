extends TestCase
# Cursor, known rooms on the map, HUD without errors.

const PlayScript := preload("res://scenes/play.gd")

func after() -> void:
	Run.reset()

func test_cursor_hidden_only_in_play() -> void:
	check(PlayScript.cursor_hidden("play"))
	for m in ["levelup", "pause", "build", "map", "options"]:
		check(not PlayScript.cursor_hidden(m), m)

func test_known_rooms() -> void:
	TH.new_run(71)
	var secret := TH.room_of("secret")
	if not secret.is_empty():
		check(not MapDraw.room_known(secret))
		secret.mapped = true
		check(MapDraw.room_known(secret))
	var any: Dictionary = Run.floor.rooms[0]
	any.seen = false
	Run.player.stats.mapReveal = 1
	check(MapDraw.room_known(any))

func test_fog_hides_the_whole_map() -> void:
	TH.new_run(73)
	Run.player.stats.hideMap = 0
	check(MapDraw.rooms_visible(), "no fog: rooms visible")
	Run.player.stats.hideMap = 1
	check(not MapDraw.rooms_visible(), "Fog hides the rooms on every map")

func test_hud_draws() -> void:
	TH.new_run(72)
	var play: Node = load("res://scenes/play.tscn").instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(play)
	Run.player.hp = 5.0
	Run.toast("Test", "#ffffff", "sotto")
	Run.banner("Title", "Long banner description", "#f6cf57", "i_blade")
	await (Engine.get_main_loop() as SceneTree).process_frame
	await (Engine.get_main_loop() as SceneTree).process_frame
	play.queue_free()
	await (Engine.get_main_loop() as SceneTree).process_frame
