extends TestCase
# Schermate, sblocchi, fine della demo, pausa automatica.

func after() -> void:
	Run.reset()

func test_autopause_only_in_active_play() -> void:
	check(Game.should_autopause("play", "play", false, 0.0))
	check(not Game.should_autopause("play", "pause", false, 0.0))
	check(not Game.should_autopause("play", "levelup", false, 0.0))
	check(not Game.should_autopause("play", "play", true, 0.0), "morto")
	check(not Game.should_autopause("play", "play", false, 1.0), "vittoria in corso")
	check(not Game.should_autopause("title", "play", false, 0.0))

func test_tutte_le_scene_esistono() -> void:
	for k in Game.SCENES:
		check(ResourceLoader.exists(Game.SCENES[k]), k)

func test_argomenti_di_sviluppo() -> void:
	eq(Game.parse_args(PackedStringArray(["--test=boss", "--fire", "x", "--seed=4"])), {"test": "boss", "fire": true, "seed": "4"})

func test_scelta_della_lanterna_rispetta_gli_sblocchi() -> void:
	Save.data.unlocks.lanterns = ["custode"]
	var sc: Node = load(Game.SCENES.select).instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(sc)
	eq(sc.menu.items.size(), 6, "5 lanterne + Indietro (Ardore non ancora sbloccato)")
	check(not sc.menu.items[0].get("disabled", false))
	check(sc.menu.items[1].disabled)
	eq(sc.menu.items[1].label, "Lanterna sigillata")
	sc.queue_free()
	await (Engine.get_main_loop() as SceneTree).process_frame

func test_il_guardiano_sblocca_il_pellegrino() -> void:
	Save.data.unlocks.lanterns = ["custode"]
	Save.data.stats.bossKills = 1
	TH.new_run(91)
	Flow.check_unlocks()
	check(Save.data.unlocks.lanterns.has("pellegrino"))
	check(Run.new_unlocks.has("Lanterna del Pellegrino"))

func test_fine_della_demo_registra_le_uccisioni() -> void:
	TH.new_run(92)
	Run.kills = 7
	var k0: int = Save.data.stats.kills
	var sc: Node = load(Game.SCENES.demo_end).instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(sc)
	eq(Save.data.stats.kills, k0 + 7)
	sc.queue_free()
	await (Engine.get_main_loop() as SceneTree).process_frame
