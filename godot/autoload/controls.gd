extends Node
# Input (from Input and Act in js/core.js): keyboard, mouse and gamepad with the same
# mapping as the JS, last used device and simulated input for tests.

const DEAD := 0.22
const KEYS := {
	"move_left": [KEY_A], "move_right": [KEY_D], "move_up": [KEY_W], "move_down": [KEY_S],
	"aim_left": [KEY_LEFT], "aim_right": [KEY_RIGHT], "aim_up": [KEY_UP], "aim_down": [KEY_DOWN],
	"dash": [KEY_SPACE, KEY_SHIFT], "flare": [KEY_F], "interact": [KEY_E],
	"pause": [KEY_ESCAPE, KEY_P], "map": [KEY_TAB, KEY_M],
	"slot_1": [KEY_1, KEY_KP_1], "slot_2": [KEY_2, KEY_KP_2], "slot_3": [KEY_3, KEY_KP_3], "slot_4": [KEY_4, KEY_KP_4],
	"nav_up": [KEY_UP, KEY_W], "nav_down": [KEY_DOWN, KEY_S], "nav_left": [KEY_LEFT, KEY_A], "nav_right": [KEY_RIGHT, KEY_D],
	"confirm": [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E], "back": [KEY_ESCAPE, KEY_BACKSPACE], "reroll": [KEY_R],
	"cheats": [KEY_F1, KEY_QUOTELEFT], "tab_prev": [KEY_Q, KEY_PAGEUP], "tab_next": [KEY_TAB, KEY_PAGEDOWN],
	"digit_1": [KEY_1], "digit_2": [KEY_2], "digit_3": [KEY_3], "digit_4": [KEY_4],
}
const PAD := {
	"dash": [JOY_BUTTON_A, JOY_BUTTON_LEFT_SHOULDER], "flare": [JOY_BUTTON_B, JOY_BUTTON_RIGHT_SHOULDER],
	"interact": [JOY_BUTTON_X], "pause": [JOY_BUTTON_START], "map": [JOY_BUTTON_BACK],
	"slot_1": [JOY_BUTTON_DPAD_UP], "slot_2": [JOY_BUTTON_DPAD_RIGHT], "slot_3": [JOY_BUTTON_DPAD_DOWN], "slot_4": [JOY_BUTTON_DPAD_LEFT],
	"nav_up": [JOY_BUTTON_DPAD_UP], "nav_down": [JOY_BUTTON_DPAD_DOWN], "nav_left": [JOY_BUTTON_DPAD_LEFT], "nav_right": [JOY_BUTTON_DPAD_RIGHT],
	"confirm": [JOY_BUTTON_A], "back": [JOY_BUTTON_B], "reroll": [JOY_BUTTON_Y],
	"tab_prev": [JOY_BUTTON_LEFT_SHOULDER], "tab_next": [JOY_BUTTON_RIGHT_SHOULDER],
}
const MOUSE := {"fire": [MOUSE_BUTTON_LEFT], "flare": [MOUSE_BUTTON_RIGHT]}
# Godot-only: the actions the Controls options can rebind (settings.binds holds the
# changed ones); the menu actions stay fixed so a bad binding cannot lock the menus
const BINDABLE := {
	"kb": ["move_up", "move_down", "move_left", "move_right", "aim_up", "aim_down", "aim_left", "aim_right",
		"dash", "flare", "interact", "map", "pause", "slot_1", "slot_2", "slot_3", "slot_4"],
	"pad": ["dash", "flare", "interact", "map", "pause", "slot_1", "slot_2", "slot_3", "slot_4"],
}
const PAD_NAMES := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_LEFT_STICK: "LS", JOY_BUTTON_RIGHT_STICK: "RS",
	JOY_BUTTON_BACK: "View", JOY_BUTTON_START: "Menu", JOY_BUTTON_GUIDE: "Guide",
	JOY_BUTTON_DPAD_UP: "D-pad up", JOY_BUTTON_DPAD_DOWN: "D-pad down", JOY_BUTTON_DPAD_LEFT: "D-pad left", JOY_BUTTON_DPAD_RIGHT: "D-pad right",
}

var to_world := Callable()   # Godot-only: set by the 3D view
var last_device := "kb"
var mouse_aim := false   # Godot-only: the last aim came from the mouse (WASD does not change it)
var sim: Dictionary = {}
var held_only := false   # extra ticks of the same frame (cheat fast forward): no new presses
var capture := ""   # "kb" or "pad" while the Controls options wait for a key to bind
var captured: InputEvent = null   # the first key, button or click pressed while capturing
var wheel_d := 0

func _ready() -> void:
	apply_binds()
	for a in MOUSE:
		_ensure(a)
		for b in MOUSE[a]:
			var e := InputEventMouseButton.new()
			e.button_index = b
			InputMap.action_add_event(a, e)

func _ensure(a: String) -> void:
	if not InputMap.has_action(a):
		InputMap.add_action(a, 0.5)

# rebuilds the key and button events of every action from the defaults and settings.binds
func apply_binds() -> void:
	for a in KEYS:
		_ensure(a)
		for e in InputMap.action_get_events(a):
			if e is InputEventKey:
				InputMap.action_erase_event(a, e)
		for k in binds("kb", a):
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(a, e)
	for a in PAD:
		_ensure(a)
		for e in InputMap.action_get_events(a):
			if e is InputEventJoypadButton:
				InputMap.action_erase_event(a, e)
		for b in binds("pad", a):
			var e := InputEventJoypadButton.new()
			e.button_index = b
			e.device = -1
			InputMap.action_add_event(a, e)

func _saved_binds(dev: String) -> Dictionary:
	var all: Variant = Save.data.settings.get("binds")
	var d: Variant = all.get(dev) if all is Dictionary else null
	return d if d is Dictionary else {}

# key codes ("kb") or gamepad buttons ("pad") of an action
func binds(dev: String, a: String) -> Array:
	var saved: Variant = _saved_binds(dev).get(a)
	if a in BINDABLE[dev] and saved is Array:
		return saved.map(func(c: Variant) -> int: return int(c))
	return (KEYS if dev == "kb" else PAD).get(a, []).duplicate()

# a code taken by another action goes to it in exchange for the old one of `a`
func rebind(dev: String, a: String, code: int) -> void:
	var d := _saved_binds(dev)
	var old := binds(dev, a)
	for b in BINDABLE[dev]:
		var l := binds(dev, b)
		var i := l.find(code)
		if b == a or i < 0:
			continue
		l.remove_at(i)
		if old.size() > 0 and not old[0] in l:
			l.insert(i, old[0])
		d[b] = l
	d[a] = [code]
	if not (Save.data.settings.get("binds") is Dictionary):
		Save.data.settings.binds = {}
	Save.data.settings.binds[dev] = d
	Save.write()
	apply_binds()

func reset_binds(dev: String) -> void:
	if Save.data.settings.get("binds") is Dictionary:
		Save.data.settings.binds.erase(dev)
	Save.write()
	apply_binds()

func code_name(dev: String, code: int) -> String:
	if dev == "pad":
		return PAD_NAMES.get(code, "Button %d" % code)
	# the label of the key on the keyboard layout in use (no layout in the headless tests)
	var k := code if DisplayServer.get_name() == "headless" else DisplayServer.keyboard_get_keycode_from_physical(code)
	return OS.get_keycode_string(k if k != KEY_NONE else code)

# the first key or button of an action on the device in use, for the prompts
func bind_name(a: String) -> String:
	var dev := "pad" if device() == "pad" else "kb"
	var l := binds(dev, a)
	return code_name(dev, l[0]) if l.size() > 0 else "-"

func wheel() -> int:
	return sim.get("wheel", wheel_d)

func _input(event: InputEvent) -> void:
	if capture != "" and captured == null and event.is_pressed() and not event.is_echo() \
			and (event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton):
		captured = event
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			wheel_d -= 1
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			wheel_d += 1
	if event is InputEventKey and event.pressed:
		last_device = "kb"
		if event.is_action("aim_left") or event.is_action("aim_right") or event.is_action("aim_up") or event.is_action("aim_down"):
			mouse_aim = false
	elif event is InputEventMouseMotion:
		last_device = "mouse"
		mouse_aim = true
	elif event is InputEventMouseButton and event.pressed:
		last_device = "mouse"
		mouse_aim = true
	elif event is InputEventJoypadButton and event.pressed:
		last_device = "pad"
		mouse_aim = false
	elif event is InputEventJoypadMotion and absf(event.axis_value) > DEAD:
		last_device = "pad"
		mouse_aim = false

func device() -> String:
	return sim.get("device", last_device)

# Godot-only: the aim and the crosshair follow the mouse, also while walking with the keys
func mouse_aims() -> bool:
	return sim.device == "mouse" if sim.has("device") else mouse_aim

# the point of the room under the mouse: the 3D view projects it on the floor
func mouse_world() -> Vector2:
	return to_world.call(mouse_pos()) if to_world.is_valid() else mouse_pos()

func mouse_pos() -> Vector2:
	if sim.has("mouse"):
		return sim.mouse
	return get_viewport().get_mouse_position()

func _pressed(a: String) -> bool:
	if held_only:
		return false
	return a in sim.get("pressed", []) or Input.is_action_just_pressed(a)

func _pad() -> int:
	var pads := Input.get_connected_joypads()
	return pads[0] if pads.size() > 0 else -1

func _axis(axis: JoyAxis) -> float:
	var d := _pad()
	if d < 0:
		return 0.0
	var v := Input.get_joy_axis(d, axis)
	return 0.0 if absf(v) < DEAD else v

func move() -> Vector2:
	if sim.has("move"):
		return sim.move
	var x := 0.0
	var y := 0.0
	if Input.is_action_pressed("move_left"):
		x -= 1
	if Input.is_action_pressed("move_right"):
		x += 1
	if Input.is_action_pressed("move_up"):
		y -= 1
	if Input.is_action_pressed("move_down"):
		y += 1
	x += _axis(JOY_AXIS_LEFT_X)
	y += _axis(JOY_AXIS_LEFT_Y)
	var l := sqrt(x * x + y * y)
	if l > 1:
		x /= l
		y /= l
	return Vector2(x, y)

func arrow_aim() -> Variant:
	if sim.has("aim"):
		return sim.aim
	var x := 0.0
	var y := 0.0
	if Input.is_action_pressed("aim_left"):
		x -= 1
	if Input.is_action_pressed("aim_right"):
		x += 1
	if Input.is_action_pressed("aim_up"):
		y -= 1
	if Input.is_action_pressed("aim_down"):
		y += 1
	if x != 0 or y != 0:
		return atan2(y, x)
	var ax := _axis(JOY_AXIS_RIGHT_X)
	var ay := _axis(JOY_AXIS_RIGHT_Y)
	if sqrt(ax * ax + ay * ay) > 0.4:
		return atan2(ay, ax)
	return null

# player aim (updatePlayer): arrows or right stick, then the mouse
# if it is the last device or the left button is pressed, otherwise it stays
# (Godot-only: walking with the keys does not stop the mouse aim)
func aim_angle(px: float, py: float, current: float) -> float:
	var ka: Variant = arrow_aim()
	if ka != null:
		return ka
	if mouse_aims() or mouse_left():
		var m := mouse_world()
		return U.ang_to(px, py - 4, m.x, m.y)
	return current

func mouse_left() -> bool:
	return sim.get("fire", false) or Input.is_action_pressed("fire")

func mouse_left_pressed() -> bool:
	return _pressed("fire")

func firing() -> bool:
	var d := _pad()
	var trigger := d >= 0 and Input.get_joy_axis(d, JOY_AXIS_TRIGGER_RIGHT) > 0.5
	return mouse_left() or arrow_aim() != null or trigger

func dash() -> bool: return _pressed("dash")
func flare() -> bool: return _pressed("flare")
func interact() -> bool: return _pressed("interact")
func pause() -> bool: return _pressed("pause")
func map() -> bool: return _pressed("map")
func up() -> bool: return _pressed("nav_up")
func down() -> bool: return _pressed("nav_down")
func left() -> bool: return _pressed("nav_left")
func right() -> bool: return _pressed("nav_right")
func confirm() -> bool: return _pressed("confirm") and not Input.is_key_pressed(KEY_ALT)   # Alt+Enter: fullscreen
func back() -> bool: return _pressed("back")
func reroll() -> bool: return _pressed("reroll")
func cheats() -> bool: return _pressed("cheats")
func tab_prev() -> bool: return _pressed("tab_prev")
func tab_next() -> bool: return _pressed("tab_next")
# number keys only (Input.hit('Digit' + n) in the JS): the gamepad d-pad just scrolls
func digit(i: int) -> bool: return _pressed("digit_%d" % i)

func slot() -> int:
	for i in 4:
		if _pressed("slot_%d" % (i + 1)):
			return i
	return -1

func end_tick() -> void:
	sim.erase("pressed")
	wheel_d = 0
