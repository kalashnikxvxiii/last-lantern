extends TestCase
# Scelta dei doni, rilancio, pausa, menu e opzioni.

var play: Node

func before() -> void:
	TH.new_run(81)
	play = load("res://scenes/play.tscn").instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(play)

func after() -> void:
	Controls.sim.clear()
	play.queue_free()
	await (Engine.get_main_loop() as SceneTree).process_frame
	Run.reset()

func test_il_dono_si_sceglie_a_stanza_sicura() -> void:
	Run.pending_levels = 1
	for i in 30:
		play.tick(Consts.DT)
	eq(play.mode, "levelup")
	eq(play.choices.size(), 3)
	var id: String = play.choices[0]
	play.lock = 0.0
	Controls.sim = {"pressed": ["confirm"]}
	play.tick(Consts.DT)
	eq(play.mode, "play")
	eq(Run.player.perks.get(id, 0), 1)
	eq(Run.pending_levels, 0)

func test_rilancio() -> void:
	Run.pending_levels = 1
	Run.player.coins = 10
	play.open_level_up()
	play.lock = 0.0
	Controls.sim = {"pressed": ["reroll"]}
	play.tick(Consts.DT)
	eq(Run.player.coins, 5)
	eq(Run.reroll_cost, 8)

func test_pausa_e_abbandono() -> void:
	Controls.sim = {"pressed": ["pause"]}
	play.tick(Consts.DT)
	eq(play.mode, "pause")
	eq(play.pause_menu.items.size(), 5)
	play.pause_menu.sel = 4
	Controls.sim = {"pressed": ["confirm"]}
	play.tick(Consts.DT)
	check(play.confirm_quit, "prima conferma")
	Controls.sim = {"pressed": ["back"]}
	play.tick(Consts.DT)
	eq(play.mode, "play")

func test_menu_salta_le_voci_disabilitate() -> void:
	var m := Menu.new([{"label": "a"}, {"label": "b", "disabled": true}, {"label": "c"}])
	Controls.sim = {"pressed": ["nav_down"]}
	m.update()
	eq(m.sel, 2)

func test_opzioni_volume() -> void:
	var m := Panels.make_options_menu(func(): pass)
	Save.data.settings.music = 0.5
	Controls.sim = {"pressed": ["nav_right"]}
	m.update()
	eq(Save.data.settings.music, 0.6)
