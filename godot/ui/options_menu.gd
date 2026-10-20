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
const WIDGET_W := 112.0
const ACTION_NAMES := {
	"move_up": "Move up", "move_down": "Move down", "move_left": "Move left", "move_right": "Move right",
	"aim_up": "Aim up", "aim_down": "Aim down", "aim_left": "Aim left", "aim_right": "Aim right",
	"dash": "Dash", "flare": "Ability", "interact": "Interact", "map": "Map", "pause": "Pause",
}

var tab := 0
var on_tabs := false
var menus: Array = []
var tab_rects: Array = []
var tab_hover := -1   # tab under the mouse, -1 when it is off the row
var device := "kb"    # Controls tab: "kb" or "pad"
var waiting := ""     # Controls tab: the action waiting for its new key
var img: Array = []   # Controls tab: the elements of the picture (ControlsDraw)
# indices into the current tab, not the entries, whose callbacks hold this menu
var open := -1       # the dropdown entry whose list is open
var list_sel := 0
var list_rects: Array = []
var dragging := -1   # the slider held with the mouse
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

# a rebinding waits for a key or a list is open: the screens must not close the options
func capturing() -> bool:
	return waiting != "" or open >= 0

func update() -> void:
	if waiting != "":
		_take_capture()
		return
	if open >= 0:
		_update_list()
		return
	if dragging >= 0:
		if Controls.mouse_left():
			_slide(menu().items[dragging], Controls.mouse_pos().x)
			return
		dragging = -1
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
		m.draw(ci, x + 44, ty + 24, {"lineH": 15, "align": "left", "valueX": x + W - 44, "drawValue": _draw_widget})
		_draw_desc(ci, x, hy - 24)
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
	if open >= 0:
		_draw_list(ci)

# --- tabs ---
# Every setting has a widget ("kind"): a toggle, a slider, a stepper (arrows that stop
# at the ends) or a dropdown list, and a description shown under the list. A click
# acts only on the widget: on the rest of the row it just selects the entry.

static func _s() -> Dictionary:
	return Save.data.settings

static func _on_off(v: bool) -> String:
	return "On" if v else "Off"

static func _toggle(key: String, desc: String) -> Dictionary:
	var flip := func() -> void:
		_s()[key] = not _s()[key]
		Save.write()
	return {"kind": "toggle", "desc": desc, "value": func(): return _on_off(_s()[key]), "adjust": func(_d: int) -> void: flip.call(), "action": flip,
		"click": func(it: Dictionary, mp: Vector2) -> void:
			if (it.get("wr", Rect2()) as Rect2).grow(2).has_point(mp):
				flip.call()
				Sfx.play("confirm")}

# value in [lo, hi] by steps of 10%, applied at once
func _slider(key: String, lo: float, hi: float, apply: Callable, desc: String) -> Dictionary:
	var put := func(v: float) -> void:
		v = clampf(U.jround(v * 10) / 10, lo, hi)
		if is_equal_approx(v, float(_s()[key])):
			return
		_s()[key] = v
		apply.call()
		Save.write()
	return {"kind": "slider", "desc": desc,
		"value": func(): return Display.percent(_s()[key]),
		"frac": func() -> float: return (float(_s()[key]) - lo) / (hi - lo),
		"set_frac": func(f: float) -> void: put.call(lo + f * (hi - lo)),
		"adjust": func(d: int) -> void: put.call(float(_s()[key]) + d * 0.1),
		"click": func(it: Dictionary, mp: Vector2) -> void:
			if (it.get("tr", Rect2()) as Rect2).grow(4).has_point(mp):
				dragging = _index(it)
				_slide(it, mp.x),
		"action": func() -> void: pass}

func _slide(it: Dictionary, mx: float) -> void:
	var r: Rect2 = it.tr
	it.set_frac.call(clampf((mx - r.position.x) / r.size.x, 0, 1))

# one of a list: options() are the names, index() the current one (-1 = none of
# them), pick(i) applies it. Left and right stop at the ends.
func _list(kind: String, options: Callable, index: Callable, pick: Callable, desc: String) -> Dictionary:
	var to := func(i: int) -> void:
		if i != index.call():
			pick.call(i)
			Save.write()
	var o := {"kind": kind, "desc": desc, "options": options, "index": index, "pick": to,
		"value": func(): return options.call()[maxi(0, index.call())],
		"adjust": func(d: int) -> void: to.call(clampi(maxi(0, index.call()) + d, 0, options.call().size() - 1))}
	if kind == "dropdown":
		o.action = func() -> void: _open_list(menu().current())
		o.click = func(it: Dictionary, mp: Vector2) -> void:
			if (it.get("wr", Rect2()) as Rect2).has_point(mp):
				_open_list(it)
	else:
		o.action = func() -> void: pass
		o.click = func(it: Dictionary, mp: Vector2) -> void:
			var r: Rect2 = it.get("wr", Rect2())
			if not r.has_point(mp):
				return
			if mp.x < r.position.x + 14:
				it.adjust.call(-1)
				Sfx.play("select")
			elif mp.x > r.end.x - 14:
				it.adjust.call(1)
				Sfx.play("select")
	return o

# a setting picked from `list`, shown through fmt
func _choice(kind: String, list: Array, key: String, apply: Callable, fmt: Callable, desc: String) -> Dictionary:
	return _list(kind, func(): return list.map(fmt), func(): return list.find(_s()[key]),
		func(i: int) -> void:
			_s()[key] = list[i]
			apply.call(), desc)

static func _entry(label: String, o: Dictionary) -> Dictionary:
	o.label = label
	return o

func _display(on_back: Callable) -> Menu:
	var caps: Array = Display.FPS_CAPS
	var res := _list("dropdown",
		func(): return Display.available_resolutions().map(func(r: Dictionary) -> String: return str(r.w) + "x" + str(r.h)),
		func(): return Display.res_pos(Display.available_resolutions()),
		func(i: int) -> void:
			_s().res = Display.classic_resolutions().find(Display.available_resolutions()[i])
			Display.apply_resolution(),
		"Size of the window. Only in windowed mode.")
	res.disabled = func(): return _s().windowMode != "windowed"
	return Menu.new([
		_entry("Window mode", _choice("stepper", Display.WINDOW_MODES, "windowMode", func(): Display.apply_window_mode(), func(v): return Display.window_mode_name(v),
			"Play in a window or fill the screen. Exclusive can reduce input lag.")),
		_entry("Resolution", res),
		_entry("VSync", _choice("stepper", Display.VSYNC_MODES, "vsync", func(): Display.apply_vsync(), func(v): return {"off": "Off", "on": "On", "adaptive": "Adaptive"}.get(v, v),
			"Stops screen tearing. Adaptive skips the sync when the frame rate drops.")),
		_entry("FPS limit", _list("stepper", func(): return caps.map(func(c: int) -> String: return "Off" if c == 0 else str(c)),
			func(): return caps.find(int(_s().fpsCap)),
			func(i: int) -> void:
				_s().fpsCap = caps[i]
				Display.apply_fps_cap(),
			"Caps the frame rate to save power.")),
		_entry("Scaling", _choice("stepper", Display.SCALINGS, "scaling", func(): Display.apply_scaling(), func(v): return {"fit": "Fit", "integer": "Pixel perfect"}.get(v, v),
			"Pixel perfect keeps every pixel the same size, with borders around the picture.")),
		{"label": "Back", "action": on_back},
	])

func _picture(on_back: Callable) -> Menu:
	var apply := func(): Display.apply_picture()
	return Menu.new([
		_entry("Brightness", _slider("brightness", 0.5, 1.5, apply, "How light the picture is.")),
		_entry("Contrast", _slider("contrast", 0.5, 1.5, apply, "The gap between dark and light areas.")),
		_entry("Saturation", _slider("saturation", 0.5, 1.5, apply, "How vivid the colors are.")),
		_entry("CRT filter", _toggle("crt", "Makes the picture look like an old CRT screen.")),
		_entry("Show FPS", _toggle("showFps", "Shows the frame rate in a corner of the screen.")),
		{"label": "Back", "action": on_back},
	])

func _graphics(on_back: Callable) -> Menu:
	var levels: Array = Quality.LEVELS
	var quality := _list("stepper", func(): return levels.map(func(l: String) -> String: return l.capitalize()),
		func(): return levels.find(Quality.current()),
		func(i: int) -> void: Quality.apply(levels[i]),
		"Sets bloom, shadows, ambient occlusion and particles at once.")
	quality.value = func(): return Quality.current().capitalize()
	# from Custom left and right start as if on High
	quality.adjust = func(d: int) -> void:
		Quality.apply(Quality.step(d))
		Save.write()
	var cap := func(v: String): return v.capitalize()
	return Menu.new([
		_entry("Quality", quality),
		_entry("Bloom", _choice("stepper", Bloom.LEVELS.keys(), "bloom", func(): pass, cap, "Glow around lights and flames.")),
		_entry("Shadows", _choice("stepper", Lighting.SHADOW_STEPS.keys(), "shadows", func(): pass, cap, "Soft shadows cast by the lights.")),
		_entry("Ambient occlusion", _toggle("ao", "Darkens corners and walls for a sense of depth.")),
		_entry("Particles", _choice("stepper", AmbientFx.AMOUNT.keys(), "particles", func(): pass, cap, "Dust, spores and embers floating in the air.")),
		_entry("Color grading", _toggle("grading", "Gives each depth its own color tone.")),
		_entry("Screen effects", _toggle("screenFx", "Color fringing on hits and ripples from explosions.")),
		{"label": "Back", "action": on_back},
	])

func _audio(on_back: Callable) -> Menu:
	return Menu.new([
		_entry("Music", _slider("music", 0, 1, func(): Sfx.apply_volumes(), "Volume of the music.")),
		_entry("Effects", _slider("sfx", 0, 1, func():
			Sfx.apply_volumes()
			Sfx.play("coin"), "Volume of the sound effects.")),
		{"label": "Back", "action": on_back},
	])

func _gameplay(on_back: Callable) -> Menu:
	return Menu.new([
		_entry("Screen shake", _toggle("shake", "Shakes the screen on hits and explosions.")),
		_entry("Damage numbers", _toggle("numbers", "Shows the damage dealt above enemies.")),
		_entry("Language", _choice("dropdown", ["auto"] + Loc.LANGS, "language", func(): Loc.apply(), func(v: String):
			return Loc.f("Auto ({0})", [Loc.NAMES[Loc.detect()]]) if v == "auto" else Loc.NAMES.get(v, v),
			"Language of the game text.")),
		{"label": "Back", "action": on_back},
	])

# --- dropdown list ---

func _index(it: Dictionary) -> int:
	var items: Array = menu().items
	for i in items.size():
		if is_same(items[i], it):
			return i
	return -1

func _open_list(it: Dictionary) -> void:
	open = _index(it)
	list_sel = maxi(0, it.index.call())
	list_rects = []

func _update_list() -> void:
	var it: Dictionary = menu().items[open]
	var n: int = it.options.call().size()
	var mp := Controls.mouse_pos()
	var hit := -1
	if Controls.device() == "mouse":
		for i in list_rects.size():
			if (list_rects[i] as Rect2).has_point(mp):
				hit = i
		if hit >= 0 and hit != list_sel:
			list_sel = hit
			Sfx.play("select")
	if Controls.up() or Controls.down():
		list_sel = (list_sel + (1 if Controls.down() else -1) + n) % n
		Sfx.play("select")
	if Controls.confirm() or (hit >= 0 and Controls.mouse_left_pressed()):
		it.pick.call(list_sel)
		Sfx.play("confirm")
		open = -1
	elif Controls.back() or Controls.mouse_left_pressed():
		Sfx.play("select")
		open = -1

func _draw_list(ci: CanvasItem) -> void:
	var it: Dictionary = menu().items[open]
	var r: Rect2 = it.get("wr", Rect2())
	var names: Array = it.options.call()
	var lh := 11.0
	var h := names.size() * lh
	var ly := r.end.y + 1
	if ly + h > Consts.H - 2:
		ly = r.position.y - 1 - h
	UiDraw.px_rect(ci, r.position.x, ly - 1, r.size.x, h + 2, UiDraw.UI.brass)
	UiDraw.px_rect(ci, r.position.x + 1, ly, r.size.x - 2, h, UiDraw.UI.bg)
	var cur: int = it.index.call()
	list_rects = []
	for i in names.size():
		var rr := Rect2(r.position.x + 1, ly + i * lh, r.size.x - 2, lh)
		list_rects.append(rr)
		if i == list_sel:
			UiDraw.px_rect(ci, rr.position.x, rr.position.y, rr.size.x, rr.size.y, UiDraw.UI.bg2)
		var c: Variant = UiDraw.UI.sel if i == list_sel else (UiDraw.UI.brassL if i == cur else "#c8c0d0")
		UiDraw.text(ci, names[i], rr.position.x + 4, rr.position.y + 2, {"color": c})

# --- widgets ---

func _draw_widget(ci: CanvasItem, it: Dictionary, rx: float, yy: float, col: Variant) -> void:
	var wx := rx - WIDGET_W
	var off_col := "#55505e"
	match it.kind:
		"toggle":
			var on: bool = it.value.call() == "On"
			it.wr = Rect2(rx - 17, yy - 1, 17, 9)
			UiDraw.px_rect(ci, rx - 17, yy - 1, 17, 9, UiDraw.UI.edge)
			UiDraw.px_rect(ci, rx - 16, yy, 15, 7, UiDraw.UI.brassD if on else UiDraw.UI.bg2)
			var knob: Variant = UiDraw.UI.sel if UiDraw.col(col) == UiDraw.UI.sel else UiDraw.UI.brassL
			UiDraw.px_rect(ci, rx - 8 if on else rx - 16, yy, 7, 7, knob if on else UiDraw.UI.dim)
		"slider":
			var tw := WIDGET_W - 30
			var f: float = it.frac.call()
			it.tr = Rect2(wx, yy + 2, tw, 3)
			UiDraw.bar(ci, wx, yy + 2, tw, 3, f, UiDraw.UI.brass)
			var kx := wx + U.jround(f * tw)
			UiDraw.px_rect(ci, kx - 2, yy - 1, 5, 9, UiDraw.UI.edge)
			UiDraw.px_rect(ci, kx - 1, yy, 3, 7, col)
			UiDraw.text(ci, it.value.call(), rx, yy, {"align": "right", "color": col})
		"stepper":
			var i: int = it.index.call()
			var last: int = it.options.call().size() - 1
			var dis := Menu.is_disabled(it)
			it.wr = Rect2(wx, yy - 3, WIDGET_W, 14)
			_arrow(ci, wx + 1, yy + 3, -1, off_col if dis or i == 0 else col)
			_arrow(ci, rx - 1, yy + 3, 1, off_col if dis or i == last else col)
			UiDraw.text(ci, it.value.call(), wx + WIDGET_W / 2, yy, {"align": "center", "color": col})
		"dropdown":
			it.wr = Rect2(wx, yy - 3, WIDGET_W, 13)
			UiDraw.px_rect(ci, wx, yy - 3, WIDGET_W, 13, UiDraw.UI.brass if open >= 0 and is_same(it, menu().items[open]) else UiDraw.UI.brassD)
			UiDraw.px_rect(ci, wx + 1, yy - 2, WIDGET_W - 2, 11, UiDraw.UI.bg2)
			UiDraw.text(ci, it.value.call(), wx + 5, yy, {"color": col})
			for k in 3:
				UiDraw.px_rect(ci, rx - 9 + k, yy + 2 + k, 5 - k * 2, 1, col)

static func _arrow(ci: CanvasItem, x: float, cy: float, d: int, c: Variant) -> void:
	for k in 4:
		UiDraw.px_rect(ci, x - d * k, cy - k, 1, k * 2 + 1, c)

# the description of the entry under the cursor, under the list
func _draw_desc(ci: CanvasItem, x: float, y: float) -> void:
	UiDraw.px_rect(ci, x + 40, y - 7, W - 80, 1, UiDraw.UI.brassD)
	var m := menu()
	var i := m.hover if Controls.device() == "mouse" else m.sel
	if open >= 0:
		i = open
	var it: Dictionary = m.items[i] if (open >= 0 or not on_tabs) and i >= 0 and i < m.items.size() else {}
	if it.get("desc", "") != "":
		UiDraw.text_wrapped(ci, it.desc, Consts.W / 2.0, y, W - 80, {"align": "center", "color": UiDraw.UI.dim})

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
