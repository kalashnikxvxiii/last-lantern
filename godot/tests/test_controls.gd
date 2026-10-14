extends TestCase
# Input: normalized movement, aim from the last device, simulated input.

func after() -> void:
	Controls.sim.clear()
	Controls.mouse_aim = false
	for a in ["move_right", "move_down", "aim_left"]:
		Input.action_release(a)

func test_normalized_movement() -> void:
	Input.action_press("move_right")
	Input.action_press("move_down")
	var m := Controls.move()
	near(m.length(), 1.0, 1e-6)   # Vector2 is 32-bit
	near(m.x, sqrt(0.5), 1e-6)

func test_aim_follows_last_device() -> void:
	Controls.sim = {"device": "pad", "mouse": Vector2(300, 100)}
	eq(Controls.aim_angle(100, 104, 1.5), 1.5, "with the gamepad the mouse does not count")
	Controls.sim = {"device": "mouse", "mouse": Vector2(300, 100)}
	near(Controls.aim_angle(100, 104, 1.5), 0.0, 1e-9, "aims at the mouse (from y - 4)")
	Controls.sim = {"device": "pad", "mouse": Vector2(100, 300), "fire": true}
	near(Controls.aim_angle(100, 104, 0.0), PI / 2, 1e-9, "left button pressed: mouse")
	Controls.sim = {"device": "mouse", "mouse": Vector2(300, 100), "aim": PI}
	eq(Controls.aim_angle(100, 104, 0.0), PI, "the arrows take precedence")

func test_simulated_presses_last_one_tick() -> void:
	Controls.sim = {"pressed": ["dash", "slot_3"]}
	check(Controls.dash())
	eq(Controls.slot(), 2)
	Controls.end_tick()
	check(not Controls.dash())
	eq(Controls.slot(), -1)

func test_alt_enter_does_not_confirm() -> void:
	await (Engine.get_main_loop() as SceneTree).process_frame
	# like a real keyboard: first Alt, then Enter with the modifier
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
	check(not Controls.confirm(), "Alt+Enter is fullscreen")
	var up := ev.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	var alt_up := alt.duplicate()
	alt_up.pressed = false
	Input.parse_input_event(alt_up)
	Input.flush_buffered_events()

func _key(k: Key, down: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = down
	Input.parse_input_event(e)
	Input.flush_buffered_events()

func test_moving_keeps_the_mouse_aim() -> void:
	await (Engine.get_main_loop() as SceneTree).process_frame
	Input.parse_input_event(InputEventMouseMotion.new())
	Input.flush_buffered_events()
	check(Controls.mouse_aim, "the mouse moved: it aims")
	_key(KEY_W, true)
	_key(KEY_W, false)
	check(Controls.mouse_aim, "walking with the keys keeps the crosshair")
	eq(Controls.last_device, "kb")
	Controls.sim = {"mouse": Vector2(300, 100)}
	near(Controls.aim_angle(100, 104, 1.5), 0.0, 1e-9, "and the shots still go to the mouse")
	Controls.sim.clear()
	_key(KEY_LEFT, true)
	_key(KEY_LEFT, false)
	check(not Controls.mouse_aim, "the arrows aim: no crosshair")
