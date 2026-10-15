extends TestCase
# Tabbed options (Display, Graphics, Audio, Gameplay) and the display settings.

var saved: Dictionary
var max_fps := 0

func before() -> void:
	saved = Save.data.settings.duplicate(true)
	max_fps = Engine.max_fps

func after() -> void:
	Controls.sim.clear()
	Controls.capture = ""
	Controls.captured = null
	Save.data.settings = saved
	Controls.apply_binds()
	Engine.max_fps = max_fps
	Display.apply_all()

func _item(m: OptionsMenu, label: String) -> int:
	var items: Array = m.menu().items
	for i in items.size():
		if items[i].label is String and items[i].label == label:
			return i
	return -1

func _press(m: OptionsMenu, a: String) -> void:
	Controls.sim = {"pressed": [a]}
	m.update()
	Controls.sim.clear()

func _open(tab: String, label: String) -> OptionsMenu:
	var m := OptionsMenu.new(func(): pass)
	m.tab = OptionsMenu.TABS.find(tab)
	m.menu().sel = _item(m, label)
	return m

func test_the_tabs() -> void:
	eq(OptionsMenu.TABS, ["Display", "Picture", "Graphics", "Audio", "Gameplay", "Controls"])
	var m := OptionsMenu.new(func(): pass)
	eq(m.tab, 0)
	for t in OptionsMenu.TABS.size():
		m.tab = t
		var last: Dictionary = m.menu().items[-1]
		eq(last.label, "Back", "every tab ends with Back")

func test_switching_tabs() -> void:
	var m := OptionsMenu.new(func(): pass)
	_press(m, "tab_next")
	eq(m.tab, 1)
	_press(m, "tab_prev")
	_press(m, "tab_prev")
	eq(m.tab, OptionsMenu.TABS.size() - 1, "the tabs wrap around")

func test_the_tab_row_takes_the_focus() -> void:
	var m := OptionsMenu.new(func(): pass)
	_press(m, "nav_up")
	check(m.on_tabs, "up from the first entry goes to the tab row")
	_press(m, "nav_right")
	eq(m.tab, 1, "left and right switch tab on the tab row")
	check(m.on_tabs)
	_press(m, "nav_down")
	check(not m.on_tabs, "down goes back to the entries")
	eq(m.menu().sel, 0)

func test_volume() -> void:
	var m := _open("Audio", "Music")
	Save.data.settings.music = 0.5
	_press(m, "nav_right")
	eq(Save.data.settings.music, 0.6)

func test_resolution_slider() -> void:
	Save.data.settings.windowMode = "windowed"
	var m := _open("Display", "Resolution")
	check(m.menu().sel >= 0, "the Display tab has a Resolution slider")
	Save.data.settings.res = 2
	_press(m, "nav_right")
	eq(Save.data.settings.res, 3, "right moves to the next classic resolution")
	Save.data.settings.res = 0
	_press(m, "nav_left")
	eq(Save.data.settings.res, 0, "the slider stays at the smallest resolution")

func test_resolution_only_in_a_window() -> void:
	Save.data.settings.windowMode = "fullscreen"
	var m := _open("Display", "Resolution")
	check(Menu.is_disabled(m.menu().items[m.menu().sel]), "the resolution is fixed in fullscreen")

func test_window_mode() -> void:
	Save.data.settings.windowMode = "windowed"
	var m := _open("Display", "Window mode")
	_press(m, "nav_right")
	eq(Save.data.settings.windowMode, "fullscreen")
	_press(m, "nav_right")
	eq(Save.data.settings.windowMode, "exclusive")
	_press(m, "nav_right")
	eq(Save.data.settings.windowMode, "exclusive", "the choice stops at the last mode")

func test_f11_returns_to_the_last_fullscreen_mode() -> void:
	Save.data.settings.windowMode = "exclusive"
	Display.toggle_fullscreen()
	eq(Save.data.settings.windowMode, "windowed")
	eq(Save.data.settings.fullscreenMode, "exclusive", "saved: it holds after a restart")
	Display.toggle_fullscreen()
	eq(Save.data.settings.windowMode, "exclusive", "not plain fullscreen")

func test_saved_resolution_beyond_the_screen() -> void:
	var avail := Display.classic_resolutions().slice(0, 3)
	Save.data.settings.res = 5
	eq(Display.res_pos(avail), 2, "clamped to the largest the screen allows")
	Save.data.settings.res = 1
	eq(Display.res_pos(avail), 1)
	eq(Display.res_bar(0, 3), "[----------]")
	eq(Display.res_bar(1, 3), "[#####-----]")
	eq(Display.res_bar(0, 1), "[##########]")

func test_vsync() -> void:
	Save.data.settings.vsync = "on"
	var m := _open("Display", "VSync")
	_press(m, "nav_right")
	eq(Save.data.settings.vsync, "adaptive")
	_press(m, "nav_left")
	_press(m, "nav_left")
	eq(Save.data.settings.vsync, "off")

func test_fps_limit() -> void:
	Save.data.settings.fpsCap = 0
	var m := _open("Display", "FPS limit")
	_press(m, "nav_right")
	eq(Save.data.settings.fpsCap, Display.FPS_CAPS[1])
	eq(Engine.max_fps, Display.FPS_CAPS[1], "the limit is applied at once")
	eq(Menu.label_of(m.menu().current()), "FPS limit   " + str(Display.FPS_CAPS[1]))

func test_pixel_scaling() -> void:
	Save.data.settings.scaling = "fit"
	var m := _open("Display", "Scaling")
	_press(m, "nav_right")
	eq(Save.data.settings.scaling, "integer")
	eq((Engine.get_main_loop() as SceneTree).root.content_scale_stretch, Window.CONTENT_SCALE_STRETCH_INTEGER)

func test_brightness() -> void:
	Save.data.settings.brightness = 1.0
	var m := _open("Picture", "Brightness")
	_press(m, "nav_right")
	near(Save.data.settings.brightness, 1.1, 1e-6)
	near(Display.environment().adjustment_brightness, 1.1, 1e-6)
	Save.data.settings.brightness = 1.5
	_press(m, "nav_right")
	near(Save.data.settings.brightness, 1.5, 1e-6, "the brightness stops at 150%")

func test_gameplay_toggles() -> void:
	Save.data.settings.shake = true
	var m := _open("Gameplay", "Screen shake")
	_press(m, "confirm")
	eq(Save.data.settings.shake, false)

func test_defaults() -> void:
	var s: Dictionary = Save.defaults().settings
	eq(s.windowMode, "windowed")
	eq(s.vsync, "on")
	eq(s.fpsCap, 0)
	eq(s.scaling, "fit")
	eq(s.brightness, 1.0)
	eq(s.showFps, false)

func test_bloom_setting() -> void:
	eq(Save.defaults().settings.bloom, "medium")
	Save.data.settings.bloom = "medium"
	var m := _open("Graphics", "Bloom")
	check(m.menu().sel >= 0, "the Graphics tab has a Bloom entry")
	eq(Menu.label_of(m.menu().current()), "Bloom   Medium")
	_press(m, "nav_right")
	eq(Save.data.settings.bloom, "high")
	_press(m, "nav_right")
	eq(Save.data.settings.bloom, "high", "the choice stops at the last level")
	for i in 3:
		_press(m, "nav_left")
	eq(Save.data.settings.bloom, "off")

func test_bloom_layer() -> void:
	TH.new_run(5)
	var play: Node = load("res://scenes/play.tscn").instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(play)
	var b: Bloom = play.get_node("ScreenFx/Bloom")
	Save.data.settings.bloom = "off"
	b._process(0.0)
	check(not b.visible, "bloom off: the layer is hidden")
	Save.data.settings.bloom = "high"
	b._process(0.0)
	check(b.visible)
	eq((b.material as ShaderMaterial).get_shader_parameter("intensity"), Bloom.LEVELS.high)
	play.queue_free()
	await (Engine.get_main_loop() as SceneTree).process_frame
	Run.reset()

func test_shadow_settings() -> void:
	eq(Save.defaults().settings.shadows, "high")
	eq(Save.defaults().settings.ao, true)
	Save.data.settings.shadows = "high"
	var m := _open("Graphics", "Shadows")
	check(m.menu().sel >= 0, "the Graphics tab has a Shadows entry")
	_press(m, "nav_left")
	eq(Save.data.settings.shadows, "low")
	_press(m, "nav_left")
	eq(Save.data.settings.shadows, "off")
	Save.data.settings.ao = true
	m = _open("Graphics", "Ambient occlusion")
	_press(m, "confirm")
	eq(Save.data.settings.ao, false)

func test_tabs_fit_the_panel() -> void:
	var m := OptionsMenu.new(func(): pass)
	for t in OptionsMenu.TABS.size():
		m.tab = t
		if OptionsMenu.TABS[t] == "Controls":
			continue   # it scrolls
		check(m.menu().items.size() <= OptionsMenu.MAX_ENTRIES, OptionsMenu.TABS[t] + " fits the panel")

func test_the_mouse_on_the_tab_row() -> void:
	var m := OptionsMenu.new(func(): pass)
	m.tab_rects = []
	for i in OptionsMenu.TABS.size():
		m.tab_rects.append(Rect2(i * 20, 0, 10, 10))
	Controls.sim = {"device": "mouse", "mouse": Vector2(25, 5), "pressed": ["fire"]}
	m.update()
	eq(m.tab, 1, "a click opens the tab")
	check(m.on_tabs)
	Controls.sim = {"device": "mouse", "mouse": Vector2(200, 200)}
	m.update()
	check(not m.on_tabs, "off the row the focus goes back to the entries")

func _controls(dev: String, bind: String) -> OptionsMenu:
	var m := OptionsMenu.new(func(): pass)
	m.tab = OptionsMenu.TABS.find("Controls")
	m.set_device(dev)
	var items: Array = m.menu().items
	for i in items.size():
		if items[i].get("bind", "") == bind:
			m.menu().sel = i
	return m

static func _key_event(k: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = k
	e.pressed = true
	return e

func test_controls_tab_lists_every_action() -> void:
	var m := _controls("kb", "")
	var binds := m.menu().items.map(func(it: Dictionary) -> String: return it.get("bind", ""))
	for a in Controls.BINDABLE.kb:
		check(a in binds, a + " on the keyboard list")
	eq(m.menu().items[-1].label, "Back")
	m.set_device("pad")
	binds = m.menu().items.map(func(it: Dictionary) -> String: return it.get("bind", ""))
	for a in Controls.BINDABLE.pad:
		check(a in binds, a + " on the gamepad list")

func test_device_entry_switches_the_list() -> void:
	var m := _controls("kb", "")
	m.menu().sel = 0
	_press(m, "nav_right")
	eq(m.device, "pad")
	check(not m.menu().items.any(func(it: Dictionary) -> bool: return it.get("bind", "") == "move_up"), "no keys on the gamepad list")

func test_rebinding_from_the_menu() -> void:
	var m := _controls("kb", "dash")
	_press(m, "confirm")
	check(m.capturing(), "waits for a key")
	eq(Controls.capture, "kb")
	m.update()
	check(m.capturing(), "still waiting with no key")
	Controls.captured = _key_event(KEY_Q)
	m.update()
	check(not m.capturing())
	eq(Controls.binds("kb", "dash"), [KEY_Q])

func test_escape_cancels_the_rebinding() -> void:
	var m := _controls("kb", "dash")
	_press(m, "confirm")
	Controls.captured = _key_event(KEY_ESCAPE)
	m.update()
	check(not m.capturing())
	eq(Controls.binds("kb", "dash"), [KEY_SPACE, KEY_SHIFT], "unchanged")

func test_a_key_does_not_bind_the_gamepad() -> void:
	var m := _controls("pad", "dash")
	_press(m, "confirm")
	eq(Controls.capture, "pad")
	Controls.captured = _key_event(KEY_Q)
	m.update()
	check(not m.capturing(), "a key cancels")
	eq(Controls.binds("pad", "dash"), [JOY_BUTTON_A, JOY_BUTTON_LEFT_SHOULDER])
	_press(m, "confirm")
	var b := InputEventJoypadButton.new()
	b.button_index = JOY_BUTTON_Y
	b.pressed = true
	Controls.captured = b
	m.update()
	eq(Controls.binds("pad", "dash"), [JOY_BUTTON_Y])

func _element(els: Array, code: int, fixed: String = "") -> Dictionary:
	for el in els:
		if el.code == code and (fixed == "" or el.fixed == fixed):
			return el
	return {}

func test_the_picture_lights_the_selected_action() -> void:
	var els := ControlsDraw.elements("kb", 0, 0)
	var space := _element(els, KEY_SPACE)
	check(not space.is_empty(), "the keyboard has a space bar")
	check(ControlsDraw.lit(space, "kb", "dash"))
	check(not ControlsDraw.lit(space, "kb", "flare"))
	var left := _element(ControlsDraw.elements("pad", 0, 0), JOY_BUTTON_LEFT_STICK)
	check(ControlsDraw.lit(left, "pad", "move"), "the left stick moves")

func test_the_mouse_on_the_picture_selects_the_action() -> void:
	var m := _controls("kb", "move_up")
	m.img = ControlsDraw.elements("kb", 0, 0)
	var f := _element(m.img, KEY_F)
	Controls.sim = {"device": "mouse", "mouse": (f.r as Rect2).get_center()}
	m.update()
	eq(m.menu().current().get("bind"), "flare")
	eq(m.menu().hover, m.menu().sel, "the entry is lit")
	Controls.sim = {"device": "mouse", "mouse": (f.r as Rect2).get_center(), "pressed": ["fire"]}
	m.update()
	check(m.capturing(), "a click on the key rebinds it")

static func _button_event(b: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	e.pressed = true
	return e

func test_menu_cancels_on_the_gamepad() -> void:
	var m := _controls("pad", "dash")
	_press(m, "confirm")
	eq(m.cancel_hint(), Loc.f("{0} or click to cancel", ["Menu"]))
	Controls.captured = _button_event(JOY_BUTTON_START)
	m.update()
	check(not m.capturing())
	eq(Controls.binds("pad", "dash"), [JOY_BUTTON_A, JOY_BUTTON_LEFT_SHOULDER], "unchanged")

func test_pause_takes_its_cancel_key() -> void:
	var m := _controls("kb", "pause")
	_press(m, "confirm")
	eq(m.cancel_hint(), "Click to cancel", "ESC binds Pause: only a click cancels")
	Controls.captured = _key_event(KEY_ESCAPE)
	m.update()
	eq(Controls.binds("kb", "pause"), [KEY_ESCAPE])
	m = _controls("pad", "pause")
	_press(m, "confirm")
	Controls.captured = _button_event(JOY_BUTTON_START)
	m.update()
	eq(Controls.binds("pad", "pause"), [JOY_BUTTON_START])
