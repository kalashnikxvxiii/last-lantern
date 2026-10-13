extends TestCase
# Perk choice, rematch, pause, menus and options.

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

func test_the_perk_is_chosen_in_a_safe_room() -> void:
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

func test_reroll() -> void:
	Run.pending_levels = 1
	Run.player.coins = 10
	play.open_level_up()
	play.lock = 0.0
	Controls.sim = {"pressed": ["reroll"]}
	play.tick(Consts.DT)
	eq(Run.player.coins, 5)
	eq(Run.reroll_cost, 8)

func test_pause_and_abandon() -> void:
	Controls.sim = {"pressed": ["pause"]}
	play.tick(Consts.DT)
	eq(play.mode, "pause")
	eq(play.pause_menu.items.size(), 6)
	play.pause_menu.sel = 5
	Controls.sim = {"pressed": ["confirm"]}
	play.tick(Consts.DT)
	check(play.confirm_quit, "first confirmation")
	Controls.sim = {"pressed": ["back"]}
	play.tick(Consts.DT)
	eq(play.mode, "play")

func test_menu_skips_disabled_entries() -> void:
	var m := Menu.new([{"label": "a"}, {"label": "b", "disabled": true}, {"label": "c"}])
	Controls.sim = {"pressed": ["nav_down"]}
	m.update()
	eq(m.sel, 2)

func test_pause_opens_the_options() -> void:
	play.open_pause()
	play.pause_menu.sel = 3
	Controls.sim = {"pressed": ["confirm"]}
	play.tick(Consts.DT)
	eq(play.mode, "options")
	check(play.opt_menu is OptionsMenu, "the pause uses the tabbed options")
	Controls.sim = {"pressed": ["back"]}
	play.tick(Consts.DT)
	eq(play.mode, "pause")

func test_gamepad_dpad_scrolls_the_cards_without_choosing() -> void:
	Run.pending_levels = 1
	play.open_level_up()
	play.lock = 0.0
	var ev := InputEventJoypadButton.new()
	ev.button_index = JOY_BUTTON_DPAD_RIGHT
	ev.pressed = true
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	play.tick(Consts.DT)
	var up := ev.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	eq(play.mode, "levelup", "the d-pad must not choose a perk")
	eq(play.sel, 1)
