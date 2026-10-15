extends TestCase
# Input: normalized movement, aim from the last device, simulated input, rebinding.

var saved: Dictionary

func before() -> void:
	saved = Save.data.settings.duplicate(true)

func after() -> void:
	Controls.sim.clear()
	Controls.mouse_aim = false
	Save.data.settings = saved
	Controls.apply_binds()
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

static func _has_key(a: String, k: Key) -> bool:
	for e in InputMap.action_get_events(a):
		if e is InputEventKey and e.physical_keycode == k:
			return true
	return false

static func _has_button(a: String, b: JoyButton) -> bool:
	for e in InputMap.action_get_events(a):
		if e is InputEventJoypadButton and e.button_index == b:
			return true
	return false

func test_rebinding_a_key() -> void:
	Controls.rebind("kb", "dash", KEY_Q)
	eq(Controls.binds("kb", "dash"), [KEY_Q])
	check(_has_key("dash", KEY_Q), "the new key is in the input map")
	check(not _has_key("dash", KEY_SPACE), "the old keys are gone")
	check(_has_button("dash", JOY_BUTTON_A), "the gamepad is untouched")
	eq(Save.data.settings.binds.kb.dash, [KEY_Q], "saved")

func test_a_taken_key_swaps() -> void:
	Controls.rebind("kb", "dash", KEY_F)
	eq(Controls.binds("kb", "dash"), [KEY_F])
	eq(Controls.binds("kb", "flare"), [KEY_SPACE], "Flare gets the old key of Dash")
	check(_has_key("flare", KEY_SPACE))

func test_rebinding_a_button() -> void:
	Controls.rebind("pad", "interact", JOY_BUTTON_Y)
	check(_has_button("interact", JOY_BUTTON_Y))
	check(not _has_button("interact", JOY_BUTTON_X))
	check(_has_key("interact", KEY_E), "the keyboard is untouched")

func test_reset_binds() -> void:
	Controls.rebind("kb", "map", KEY_J)
	Controls.reset_binds("kb")
	eq(Controls.binds("kb", "map"), [KEY_TAB, KEY_M])
	check(_has_key("map", KEY_TAB))

func test_saved_binds_from_json() -> void:
	# JSON gives floats back; junk is ignored, and menu actions cannot be rebound
	Save.data.settings.binds = {"kb": {"dash": [81.0], "back": [KEY_J], "flare": "junk"}}
	Controls.apply_binds()
	eq(Controls.binds("kb", "dash"), [KEY_Q])
	eq(Controls.binds("kb", "back"), [KEY_ESCAPE, KEY_BACKSPACE])
	eq(Controls.binds("kb", "flare"), [KEY_F])
	Save.data.settings.binds = "junk"
	eq(Controls.binds("kb", "dash"), [KEY_SPACE, KEY_SHIFT])

func test_prompt_follows_the_binding() -> void:
	Controls.sim = {"device": "kb"}
	eq(Controls.bind_name("interact"), "E")
	Controls.rebind("kb", "interact", KEY_G)
	eq(Controls.bind_name("interact"), "G")
	Controls.sim = {"device": "pad"}
	eq(Controls.bind_name("interact"), "X")
