extends TestCase
# Screens, unlocks, victory, auto-pause.

func after() -> void:
	Run.reset()

func test_autopause_only_in_active_play() -> void:
	check(Game.should_autopause("play", "play", false, 0.0))
	check(not Game.should_autopause("play", "pause", false, 0.0))
	check(not Game.should_autopause("play", "levelup", false, 0.0))
	check(not Game.should_autopause("play", "play", true, 0.0), "morto")
	check(not Game.should_autopause("play", "play", false, 1.0), "victory in progress")
	check(not Game.should_autopause("title", "play", false, 0.0))

func test_all_scenes_exist() -> void:
	for k in Game.SCENES:
		check(ResourceLoader.exists(Game.SCENES[k]), k)

func test_dev_arguments() -> void:
	eq(Game.parse_args(PackedStringArray(["--test=boss", "--fire", "x", "--seed=4"])), {"test": "boss", "fire": true, "seed": "4"})

func test_lantern_choice_respects_the_unlocks() -> void:
	Save.data.unlocks.lanterns = ["warden"]
	var sc: Node = load(Game.SCENES.select).instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(sc)
	eq(sc.menu.items.size(), 6, "5 lanterns + Back (Ardor not unlocked yet)")
	check(not sc.menu.items[0].get("disabled", false))
	check(sc.menu.items[1].disabled)
	eq(sc.menu.items[1].label, "Sealed lantern")
	sc.queue_free()
	await (Engine.get_main_loop() as SceneTree).process_frame

func test_the_warden_unlocks_the_pilgrim() -> void:
	Save.data.unlocks.lanterns = ["warden"]
	Save.data.stats.bossKills = 1
	TH.new_run(91)
	Flow.check_unlocks()
	check(Save.data.unlocks.lanterns.has("pilgrim"))
	check(Run.new_unlocks.has("Pilgrim's Lantern"))

func test_victory_records_the_win_and_unlocks_ardor() -> void:
	TH.new_run(92)
	Run.time = 600.0
	var w0: int = Save.data.stats.wins
	Save.data.unlocks.ardor = 0
	var sc: Node = load(Game.SCENES.victory).instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(sc)
	eq(Save.data.stats.wins, w0 + 1)
	eq(Save.data.unlocks.ardor, 1)
	check(Run.new_unlocks.has("Ardor 1"))
	sc.queue_free()
	await (Engine.get_main_loop() as SceneTree).process_frame
