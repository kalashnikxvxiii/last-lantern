class_name OptionsMenu
extends RefCounted
# Options shared by pause and title, split into tabs (makeOptionsMenu in js/game.js
# has a single list: the Display, Picture and Graphics tabs are Godot-only).
# Q/TAB, PageUp/PageDown or the shoulder buttons switch tab; up from the first
# entry focuses the tab row, where left and right switch tab too.
# Controls lists the bindings on the left and draws the keyboard or the gamepad on
# the right: the selected action lights up in the picture, and the mouse on the
# picture selects the action of the key under it.

const TABS := ["Display", "Picture", "Graphics", "Audio", "Gameplay", "Controls"]
const W := 440.0
const H := 238.0
const MAX_ENTRIES := 8   # more do not fit above the hint
const CONTROL_ROWS := 14   # the Controls list scrolls
const ACTION_NAMES := {
	"move_up": "Move up", "move_down": "Move down", "move_left": "Move left", "move_right": "Move right",
	"aim_up": "Aim up", "aim_down": "Aim down", "aim_left": "Aim left", "aim_right": "Aim right",
	"dash": "Dash", "flare": "Flare", "interact": "Interact", "map": "Map", "pause": "Pause",
}

var tab := 0
var on_tabs := false
var menus: Array = []
var tab_rects: Array = []
var tab_hover := -1   # tab under the mouse, -1 when it is off the row
var device := "kb"    # Controls tab: "kb" or "pad"
var waiting := ""     # Controls tab: the action waiting for its new key
var img: Array = []   # Controls tab: the elements of the picture (ControlsDraw)
var _back: Callable

func _init(on_back: Callable) -> void:
	_back = on_back
	device = "pad" if Controls.device() == "pad" else "kb"
	menus = [_display(on_back), _picture(on_back), _graphics(on_back), _audio(on_back), _gameplay(on_back), Menu.new(_control_items())]

func menu() -> Menu:
	return menus[tab]

# the entries' callbacks hold this menu: drop them when the options are left,
# or the cycle is never freed
func close() -> void:
	menus = []

func _switch(d: int) -> void:
	tab = (tab + d + TABS.size()) % TABS.size()
	Sfx.play("select")

# a rebinding is waiting for a key: the screens must not close the options
func capturing() -> bool:
	return waiting != ""

func update() -> void:
	if waiting != "":
		_take_capture()
		return
	if Controls.tab_prev():
		_switch(-1)
		return
	if Controls.tab_next():
		_switch(1)
		return
	# mouse on the tab row
	var m := Controls.mouse_pos()
	var mouse := Controls.device() == "mouse"
	tab_hover = -1
	if mouse:
		for i in tab_rects.size():
			if (tab_rects[i] as Rect2).has_point(m):
				tab_hover = i
				break
	if tab_hover >= 0:
		on_tabs = true
		if Controls.mouse_left_pressed() and tab_hover != tab:
			tab = tab_hover
			Sfx.play("select")
		return
	if on_tabs:
		if Controls.left():
			_switch(-1)
		elif Controls.right():
			_switch(1)
		elif Controls.down() or Controls.confirm():
			on_tabs = false
			menu().sel = 0
			menu().lit_prev = true
			Sfx.play("select")
		elif Controls.up():
			on_tabs = false
			menu().sel = menu().items.size() - 1
			menu().lit_prev = true
			Sfx.play("select")
		elif mouse:
			# the mouse left the tab row: hand the focus back to the entries
			on_tabs = false
			menu().update()
		return
	if Controls.up() and menu().sel == 0:
		on_tabs = true
		Sfx.play("select")
		return
	menu().update()
	if TABS[tab] == "Controls" and mouse:
		_picture_mouse(m)

# the mouse on a key of the picture selects its action, a click rebinds it
func _picture_mouse(m: Vector2) -> void:
	for el in img:
		if not (el.r as Rect2).has_point(m):
			continue
		var a := ControlsDraw.action_of(el, device)
		var items: Array = menu().items
		for i in items.size():
			if a == "" or items[i].get("bind", "") != a:
				continue
			if menu().sel != i:
				Sfx.play("select")
			menu().sel = i
			menu().hover = i
			menu().lit_prev = true
			if Controls.mouse_left_pressed() and items[i].has("action"):
				Sfx.play("confirm")
				items[i].action.call()
		return

func _take_capture() -> void:
	var e := Controls.captured
	if e == null:
		return
	var code := -1
	if device == "kb" and e is InputEventKey:
		code = e.physical_keycode if e.physical_keycode != KEY_NONE else e.keycode
		if code == KEY_NONE:
			code = -1
	elif device == "pad" and e is InputEventJoypadButton:
		code = e.button_index
	if code >= 0 and code != _cancel_code():
		Controls.rebind(device, waiting, code)
		Sfx.play("confirm")
	else:
		Sfx.play("select")
	waiting = ""
	Controls.capture = ""
	Controls.captured = null

func draw(ci: CanvasItem) -> void:
	var x := Consts.W / 2.0 - W / 2
	var y := (Consts.H - H) / 2
	UiDraw.panel(ci, x, y, W, H)
	UiDraw.text(ci, "Options", Consts.W / 2.0, y + 10, {"align": "center", "color": "#f6cf57", "scale": 2})
	# tab row
	var gap := 6.0
	var widths: Array = []
	var total := -gap
	for t in TABS:
		var w := Txt.width(t) + 12
		widths.append(w)
		total += w + gap
	var tx := Consts.W / 2.0 - total / 2
	var ty := y + 32
	tab_rects = []
	var mouse := Controls.device() == "mouse"
	for i in TABS.size():
		var w: float = widths[i]
		var active := i == tab
		UiDraw.px_rect(ci, tx, ty, w, 13, "#0a070d")
		UiDraw.px_rect(ci, tx + 1, ty + 1, w - 2, 11, UiDraw.UI.brassD if active else UiDraw.UI.bg2)
		if active:
			UiDraw.px_rect(ci, tx + 1, ty + 1, w - 2, 1, UiDraw.UI.brassL)
		# the tab lights up when the keyboard is on the row or the mouse is over it
		var lit := (mouse and tab_hover == i) or (not mouse and active and on_tabs)
		var col: Variant = UiDraw.UI.sel if lit else ("#f2ead8" if active else UiDraw.UI.dim)
		UiDraw.text(ci, TABS[i], tx + w / 2, ty + 3, {"align": "center", "color": col})
		tab_rects.append(Rect2(tx, ty, w, 13))
		tx += w + gap
	UiDraw.px_rect(ci, x + 8, ty + 15, W - 16, 1, UiDraw.UI.brassD)
	# entries: the selection marker is hidden while the tab row has the focus
	var m := menu()
	m.show_cursor = not on_tabs
	var hy := y + H - 15
	if TABS[tab] == "Controls":
		m.draw(ci, x + 28, ty + 24, {"lineH": 11, "align": "left", "rows": CONTROL_ROWS, "valueX": x + 206})
		UiDraw.px_rect(ci, x + 216, ty + 22, 1, CONTROL_ROWS * 11, UiDraw.UI.brassD)
		var cur := m.hover if mouse else m.sel
		var a: String = m.items[cur].get("bind", "") if not on_tabs and cur >= 0 and cur < m.items.size() else ""
		img = ControlsDraw.elements(device, x + 324, ty + 24 + CONTROL_ROWS * 11 / 2.0)
		ControlsDraw.draw(ci, img, device, waiting if waiting != "" else a)
		if waiting != "":
			UiDraw.text(ci, cancel_hint(), Consts.W / 2.0, hy + 1, {"align": "center", "color": UiDraw.UI.dim})
			return
	else:
		m.draw(ci, Consts.W / 2.0, ty + 24, {"lineH": 15})
	# hint
	var pad := Controls.device() == "pad"
	var a := "LB" if pad else "Q"
	var b := "RB" if pad else "TAB"
	var label := "switch tab"
	var kw := Txt.width(a) + 5 + Txt.width(b) + 5 + Txt.width(label) + 12
	var hx := Consts.W / 2.0 - kw / 2
	hx += UiDraw.keycap(ci, hx, hy, a) + 3
	hx += UiDraw.keycap(ci, hx, hy, b) + 6
	UiDraw.text(ci, label, hx, hy + 1, {"color": UiDraw.UI.dim})

# --- tabs ---

static func _s() -> Dictionary:
	return Save.data.settings

static func _bar(v: float) -> String:
	var n := int(U.jround(v * 10))
	return "[" + "#".repeat(n) + "-".repeat(10 - n) + "]"

static func _on_off(v: bool) -> String:
	return "On" if v else "Off"

static func _toggle(key: String) -> Dictionary:
	var flip := func() -> void:
		_s()[key] = not _s()[key]
		Save.write()
	return {"value": func(): return _on_off(_s()[key]), "adjust": func(_d: int) -> void: flip.call(), "action": flip}

# value picked from a list with left and right, applied at once
static func _choice(list: Array, key: String, apply: Callable, fmt: Callable) -> Dictionary:
	var noop := func() -> void: pass
	return {
		"value": func(): return fmt.call(_s()[key]),
		"adjust": func(d: int) -> void:
			_s()[key] = Display.step(list, _s()[key], d)
			apply.call()
			Save.write(),
		"action": noop}

# picture slider from 50% to 150%
static func _percent(key: String) -> Dictionary:
	var noop := func() -> void: pass
	return {
		"value": func(): return Display.percent(_s()[key]),
		"adjust": func(d: int) -> void:
			_s()[key] = clampf(U.jround(float(_s()[key]) * 10 + d) / 10, 0.5, 1.5)
			Display.apply_picture()
			Save.write(),
		"action": noop}

static func _entry(label: String, o: Dictionary) -> Dictionary:
	o.label = label
	return o

func _display(on_back: Callable) -> Menu:
	var noop := func() -> void: pass
	var fps_caps: Array = Display.FPS_CAPS
	return Menu.new([
		_entry("Window mode", _choice(Display.WINDOW_MODES, "windowMode", func(): Display.apply_window_mode(), func(v): return Display.window_mode_name(v))),
		{"label": "Resolution", "value": func() -> String:
			var avail := Display.available_resolutions()
			var i := Display.res_pos(avail)
			var r: Dictionary = avail[i]
			return str(r.w) + "x" + str(r.h) + "  " + Display.res_bar(i, avail.size()),
			"adjust": func(d: int) -> void:
				var avail := Display.available_resolutions()
				var i: int = clampi(Display.res_pos(avail) + d, 0, avail.size() - 1)
				_s().res = Display.classic_resolutions().find(avail[i])
				Display.apply_resolution()
				Save.write(),
			"disabled": func(): return _s().windowMode != "windowed",
			"action": noop},
		_entry("VSync", _choice(Display.VSYNC_MODES, "vsync", func(): Display.apply_vsync(), func(v): return {"off": "Off", "on": "On", "adaptive": "Adaptive"}.get(v, v))),
		{"label": "FPS limit", "value": func(): return "Off" if int(_s().fpsCap) == 0 else str(int(_s().fpsCap)),
			"adjust": func(d: int) -> void:
				_s().fpsCap = Display.step(fps_caps, int(_s().fpsCap), d)
				Display.apply_fps_cap()
				Save.write(),
			"action": noop},
		_entry("Scaling", _choice(Display.SCALINGS, "scaling", func(): Display.apply_scaling(), func(v): return {"fit": "Fit", "integer": "Pixel perfect"}.get(v, v))),
		{"label": "Back", "action": on_back},
	])

func _picture(on_back: Callable) -> Menu:
	return Menu.new([
		_entry("Brightness", _percent("brightness")),
		_entry("Contrast", _percent("contrast")),
		_entry("Saturation", _percent("saturation")),
		_entry("CRT filter", _toggle("crt")),
		_entry("Show FPS", _toggle("showFps")),
		{"label": "Back", "action": on_back},
	])

func _graphics(on_back: Callable) -> Menu:
	var noop := func() -> void: pass
	return Menu.new([
		{"label": "Quality", "value": func(): return Quality.current().capitalize(),
			"adjust": func(d: int) -> void:
				Quality.apply(Quality.step(d))
				Save.write(),
			"action": noop},
		_entry("Bloom", _choice(Bloom.LEVELS.keys(), "bloom", func(): pass, func(v: String): return v.capitalize())),
		_entry("Shadows", _choice(Lighting.SHADOW_STEPS.keys(), "shadows", func(): pass, func(v: String): return v.capitalize())),
		_entry("Ambient occlusion", _toggle("ao")),
		_entry("Particles", _choice(AmbientFx.AMOUNT.keys(), "particles", func(): pass, func(v: String): return v.capitalize())),
		_entry("Color grading", _toggle("grading")),
		_entry("Screen effects", _toggle("screenFx")),
		{"label": "Back", "action": on_back},
	])

func _audio(on_back: Callable) -> Menu:
	var s := _s()
	var noop := func() -> void: pass
	return Menu.new([
		{"label": "Music", "value": func(): return _bar(s.music),
			"adjust": func(d):
				s.music = clampf(U.jround(s.music * 10 + d) / 10, 0, 1)
				Sfx.apply_volumes()
				Save.write(),
			"action": noop},
		{"label": "Effects", "value": func(): return _bar(s.sfx),
			"adjust": func(d):
				s.sfx = clampf(U.jround(s.sfx * 10 + d) / 10, 0, 1)
				Sfx.apply_volumes()
				Save.write()
				Sfx.play("coin"),
			"action": noop},
		{"label": "Back", "action": on_back},
	])

func _gameplay(on_back: Callable) -> Menu:
	return Menu.new([
		_entry("Screen shake", _toggle("shake")),
		_entry("Damage numbers", _toggle("numbers")),
		_entry("Language", _choice(["auto"] + Loc.LANGS, "language", func(): Loc.apply(), func(v: String):
			return Loc.f("Auto ({0})", [Loc.NAMES[Loc.detect()]]) if v == "auto" else Loc.NAMES.get(v, v))),
		{"label": "Back", "action": on_back},
	])

# --- Controls tab ---

func set_device(dev: String) -> void:
	device = dev
	var m: Menu = menus[TABS.find("Controls")]
	m.items = _control_items()
	m.sel = 0
	m.top = 0
	m.hover = -1
	m.rects = []

static func _action_name(a: String) -> String:
	return Loc.f("Consumable {0}", [a.right(1)]) if a.begins_with("slot_") else ACTION_NAMES[a]

func _bind_text(a: String) -> String:
	if waiting == a:
		return "Press a key" if device == "kb" else "Press a button"
	var names: Array = Controls.binds(device, a).map(func(c: int) -> String: return Loc.t(Controls.code_name(device, c)))
	return " / ".join(names) if names.size() > 0 else "-"

# ESC or Menu cancels a rebinding, except for Pause, which has them by default
func _cancel_code() -> int:
	if waiting == "pause":
		return -1
	return KEY_ESCAPE if device == "kb" else JOY_BUTTON_START

func cancel_hint() -> String:
	var c := _cancel_code()
	return "Click to cancel" if c < 0 else Loc.f("{0} or click to cancel", ["ESC" if device == "kb" else Controls.code_name("pad", c)])

func _wait(a: String) -> void:
	waiting = a
	Controls.capture = device
	Controls.captured = null

func _control_items() -> Array:
	var other := func() -> void: set_device("pad" if device == "kb" else "kb")
	var items: Array = [{"label": "Device", "value": func(): return "Keyboard" if device == "kb" else "Gamepad",
		"adjust": func(_d: int) -> void: other.call(), "action": other}]
	# what cannot be rebound is listed too, to find it in the picture
	if device == "pad":
		items.append({"label": "Move", "value": func(): return "Left stick", "bind": "move"})
		items.append({"label": "Aim", "value": func(): return "Right stick", "bind": "aim"})
		items.append({"label": "Fire", "value": func(): return "RT", "bind": "fire"})
	for a in Controls.BINDABLE[device]:
		items.append({"label": func(): return _action_name(a), "value": func(): return _bind_text(a),
			"action": func() -> void: _wait(a), "bind": a})
		if a == "aim_right":
			items.append({"label": "Fire", "value": func(): return "Left click", "bind": "fire"})
	items.append({"label": "Reset to defaults", "action": func() -> void: Controls.reset_binds(device)})
	items.append({"label": "Back", "action": _back})
	return items
