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

func test_the_mouse_lights_only_what_it_is_over() -> void:
	var m := Menu.new([{"label": "a"}, {"label": "b"}, {"label": "c"}])
	m.sel = 2
	m.rects = [Rect2(0, 0, 10, 10), Rect2(0, 10, 10, 10), Rect2(0, 20, 10, 10)]
	Controls.sim = {"device": "mouse", "mouse": Vector2(5, 15)}
	m.update()
	eq(m.sel, 1, "the cursor follows the entry under the mouse")
	eq(m.hover, 1)
	check(m.lit_prev, "the hovered entry is lit")
	Controls.sim = {"device": "mouse", "mouse": Vector2(5, 100)}
	m.update()
	eq(m.hover, -1, "away from the entries nothing is hovered")
	eq(m.sel, 1, "the cursor itself does not move")
	check(not m.lit_prev, "and nothing stays lit")

func test_confirm_with_nothing_lit_goes_to_the_top() -> void:
	var chosen: Array = []
	var m := Menu.new([
		{"label": "a", "action": func(): chosen.append("a")},
		{"label": "b", "action": func(): chosen.append("b")}])
	m.sel = 1
	m.rects = [Rect2(0, 0, 10, 10), Rect2(0, 10, 10, 10)]
	Controls.sim = {"device": "mouse", "mouse": Vector2(5, 100)}
	m.update()
	Controls.sim = {"device": "kb", "mouse": Vector2(5, 100), "pressed": ["confirm"]}
	m.update()
	eq(m.sel, 0, "the first confirm brings the cursor back to the first entry")
	check(chosen.is_empty(), "and does not press the hidden entry")
	Controls.sim = {"device": "kb", "mouse": Vector2(5, 100), "pressed": ["confirm"]}
	m.update()
	eq(chosen, ["a"], "the second confirm presses the first entry")

func test_the_keyboard_keeps_confirming_immediately() -> void:
	var chosen: Array = []
	var m := Menu.new([{"label": "a", "action": func(): chosen.append("a")}])
	m.rects = [Rect2(0, 0, 10, 10)]
	Controls.sim = {"device": "kb", "mouse": Vector2(5, 100), "pressed": ["confirm"]}
	m.update()
	eq(chosen, ["a"], "a keyboard player confirms on the first press")

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

func test_the_mouse_picks_the_card_under_it() -> void:
	Run.pending_levels = 1
	play.open_level_up()
	play.lock = 0.0
	play.card_rects = [Rect2(0, 0, 10, 10), Rect2(20, 0, 10, 10), Rect2(40, 0, 10, 10)]
	Controls.sim = {"device": "mouse", "mouse": Vector2(25, 5)}
	play.tick(Consts.DT)
	eq(play.sel, 1, "hovering moves the cursor")
	Controls.sim = {"device": "mouse", "mouse": Vector2(100, 100)}
	play.tick(Consts.DT)
	check(not play.card_lit_prev, "off the cards nothing is lit")
	Controls.sim = {"device": "mouse", "mouse": Vector2(100, 100), "pressed": ["confirm"]}
	play.tick(Consts.DT)
	eq(play.mode, "levelup", "confirm with nothing lit does not pick")
	eq(play.sel, 0, "it brings the cursor back to the first card")
	var id: String = play.choices[2]
	Controls.sim = {"device": "mouse", "mouse": Vector2(45, 5), "pressed": ["fire"]}
	play.tick(Consts.DT)
	eq(play.mode, "play")
	eq(Run.player.perks.get(id, 0), 1, "the click picks the hovered card")
