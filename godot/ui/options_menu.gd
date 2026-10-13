class_name OptionsMenu
extends RefCounted
# Options shared by pause and title, split into tabs (makeOptionsMenu in js/game.js
# has a single list: the Display, Picture and Graphics tabs are Godot-only).
# Q/TAB, PageUp/PageDown or the shoulder buttons switch tab; up from the first
# entry focuses the tab row, where left and right switch tab too.

const TABS := ["Display", "Picture", "Graphics", "Audio", "Gameplay"]
const W := 300.0
const H := 196.0
const MAX_ENTRIES := 8   # more do not fit above the hint

var tab := 0
var on_tabs := false
var menus: Array = []
var tab_rects: Array = []
var last_m := Vector2(-1, -1)

func _init(on_back: Callable) -> void:
	menus = [_display(on_back), _picture(on_back), _graphics(on_back), _audio(on_back), _gameplay(on_back)]

func menu() -> Menu:
	return menus[tab]

func _switch(d: int) -> void:
	tab = (tab + d + TABS.size()) % TABS.size()
	Sfx.play("select")

func update() -> void:
	if Controls.tab_prev():
		_switch(-1)
		return
	if Controls.tab_next():
		_switch(1)
		return
	# mouse on the tab row
	var m := Controls.mouse_pos()
	var moved := m != last_m
	last_m = m
	for i in tab_rects.size():
		if (tab_rects[i] as Rect2).has_point(m) and (moved or Controls.mouse_left_pressed()):
			on_tabs = true
			if Controls.mouse_left_pressed() and i != tab:
				tab = i
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
			Sfx.play("select")
		elif Controls.up():
			on_tabs = false
			menu().sel = menu().items.size() - 1
			Sfx.play("select")
		elif moved:
			on_tabs = false
			menu().update()
		return
	if Controls.up() and menu().sel == 0:
		on_tabs = true
		Sfx.play("select")
		return
	menu().update()

func draw(ci: CanvasItem) -> void:
	var x := Consts.W / 2.0 - W / 2
	var y := 36.0
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
	for i in TABS.size():
		var w: float = widths[i]
		var active := i == tab
		UiDraw.px_rect(ci, tx, ty, w, 13, "#0a070d")
		UiDraw.px_rect(ci, tx + 1, ty + 1, w - 2, 11, UiDraw.UI.brassD if active else UiDraw.UI.bg2)
		if active:
			UiDraw.px_rect(ci, tx + 1, ty + 1, w - 2, 1, UiDraw.UI.brassL)
		var col: Variant = UiDraw.UI.sel if active and on_tabs else ("#f2ead8" if active else UiDraw.UI.dim)
		UiDraw.text(ci, TABS[i], tx + w / 2, ty + 3, {"align": "center", "color": col})
		tab_rects.append(Rect2(tx, ty, w, 13))
		tx += w + gap
	UiDraw.px_rect(ci, x + 8, ty + 15, W - 16, 1, UiDraw.UI.brassD)
	# entries: the selection marker is hidden while the tab row has the focus
	var m := menu()
	var keep := m.sel
	if on_tabs:
		m.sel = -1
	m.draw(ci, Consts.W / 2.0, ty + 24, {"lineH": 15})
	m.sel = keep
	# hint
	var pad := Controls.device() == "pad"
	var hy := y + H - 15
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
		{"label": "Back", "action": on_back},
	])
