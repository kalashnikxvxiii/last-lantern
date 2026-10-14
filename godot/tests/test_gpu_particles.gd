extends TestCase
# Godot-only GPU particles: biome ambience and sparks on bright bursts.

var saved: Dictionary

func before() -> void:
	saved = Save.data.settings.duplicate()
	Particles.clear()

func after() -> void:
	Save.data.settings = saved
	Particles.clear()

func test_every_biome_has_an_ambience() -> void:
	for id in ["crypt", "fungus", "forge", "abyss", "heart"]:
		var air: Variant = AmbientFx.config(id, false)
		var glow: Variant = AmbientFx.config(id, true)
		check(air != null or glow != null, id + " has ambient particles")
		for c in [air, glow]:
			if c != null:
				check(int(c.amount) > 0 and not (c.colors as Array).is_empty(), id + ": amount and colors")

func test_amount_follows_the_setting() -> void:
	Save.data.settings.particles = "high"
	eq(AmbientFx.scaled(40), 40)
	Save.data.settings.particles = "low"
	eq(AmbientFx.scaled(40), 20)
	Save.data.settings.particles = "off"
	eq(AmbientFx.scaled(40), 0)

func test_sparks_only_for_bright_bursts() -> void:
	Save.data.settings.particles = "high"
	check(Sparks.count_for(20, ["#fff2a8", "#f6cf57", "#f29c38"]) > 0, "fire throws sparks")
	eq(Sparks.count_for(20, ["#55505e", "#3b3546", "#8a8294"]), 0, "dust does not")
	eq(Sparks.count_for(20, "#d04b3c"), 0, "neither does blood")
	Save.data.settings.particles = "off"
	eq(Sparks.count_for(20, ["#fff2a8", "#f6cf57"]), 0, "off: no sparks")

func test_sparks_do_not_consume_game_randomness() -> void:
	Save.data.settings.particles = "high"
	U.seed_random(5)
	Particles.burst(100, 100, 30, ["#fff2a8", "#f6cf57"], 90, 0.5)
	var a := U.random()
	Save.data.settings.particles = "off"
	U.seed_random(5)
	Particles.burst(100, 100, 30, ["#fff2a8", "#f6cf57"], 90, 0.5)
	eq(U.random(), a, "the game sequence is the same with and without sparks")

func test_particles_setting() -> void:
	eq(Save.defaults().settings.particles, "high")
	Save.data.settings.particles = "high"
	var m := OptionsMenu.new(func(): pass)
	m.tab = OptionsMenu.TABS.find("Graphics")
	var items: Array = m.menu().items
	for i in items.size():
		if items[i].label is String and items[i].label == "Particles":
			m.menu().sel = i
	eq(Menu.label_of(m.menu().current()), "Particles   High")
	Controls.sim = {"pressed": ["nav_left"]}
	m.update()
	Controls.sim.clear()
	eq(Save.data.settings.particles, "low")

func test_play_scene_has_the_emitters() -> void:
	TH.new_run(5)
	var play: Node = load("res://scenes/play.tscn").instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(play)
	check(play.get_node("Flat/World/AmbientAir") is AmbientFx)
	check(play.get_node("Flat/OverlayLayer/AmbientGlow") is AmbientFx)
	check(play.get_node("Flat/OverlayLayer/Sparks") is Sparks)
	check(is_same(Sparks.current, play.get_node("Flat/OverlayLayer/Sparks")), "the sparks register themselves")
	eq(str(play.get_node("ScreenFx").get_children().back().name), "Bloom", "the bloom stays last on the screen")
	play.queue_free()
	await (Engine.get_main_loop() as SceneTree).process_frame
	check(Sparks.current == null, "and unregister when the scene goes away")
	Run.reset()
