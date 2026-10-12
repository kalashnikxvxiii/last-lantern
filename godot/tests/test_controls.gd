extends TestCase
# Input: movimento normalizzato, mira dall'ultimo dispositivo, input simulato.

func after() -> void:
	Controls.sim.clear()
	for a in ["move_right", "move_down", "aim_left"]:
		Input.action_release(a)

func test_movimento_normalizzato() -> void:
	Input.action_press("move_right")
	Input.action_press("move_down")
	var m := Controls.move()
	near(m.length(), 1.0, 1e-6)   # Vector2 è a 32 bit
	near(m.x, sqrt(0.5), 1e-6)

func test_aim_follows_last_device() -> void:
	Controls.sim = {"device": "pad", "mouse": Vector2(300, 100)}
	eq(Controls.aim_angle(100, 104, 1.5), 1.5, "col gamepad il mouse non conta")
	Controls.sim = {"device": "mouse", "mouse": Vector2(300, 100)}
	near(Controls.aim_angle(100, 104, 1.5), 0.0, 1e-9, "mira verso il mouse (da y - 4)")
	Controls.sim = {"device": "pad", "mouse": Vector2(100, 300), "fire": true}
	near(Controls.aim_angle(100, 104, 0.0), PI / 2, 1e-9, "tasto sinistro premuto: mouse")
	Controls.sim = {"device": "mouse", "mouse": Vector2(300, 100), "aim": PI}
	eq(Controls.aim_angle(100, 104, 0.0), PI, "le frecce hanno la precedenza")

func test_pressioni_simulate_durano_un_tick() -> void:
	Controls.sim = {"pressed": ["dash", "slot_3"]}
	check(Controls.dash())
	eq(Controls.slot(), 2)
	Controls.end_tick()
	check(not Controls.dash())
	eq(Controls.slot(), -1)

func test_alt_invio_non_conferma() -> void:
	await (Engine.get_main_loop() as SceneTree).process_frame
	# come sulla tastiera vera: prima Alt, poi Invio con il modificatore
	var alt := InputEventKey.new()
	alt.keycode = KEY_ALT
	alt.physical_keycode = KEY_ALT
	alt.pressed = true
	Input.parse_input_event(alt)
	var ev := InputEventKey.new()
	ev.keycode = KEY_ENTER
	ev.physical_keycode = KEY_ENTER
	ev.alt_pressed = true
	ev.pressed = true
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	check(not Controls.confirm(), "Alt+Invio è lo schermo intero")
	var up := ev.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	var alt_up := alt.duplicate()
	alt_up.pressed = false
	Input.parse_input_event(alt_up)
	Input.flush_buffered_events()
