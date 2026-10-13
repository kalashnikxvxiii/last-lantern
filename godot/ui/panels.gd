class_name Panels
extends Node2D
# Panels over the game (Scenes.play.draw in js/game.js): perks, pause,
# equipment, map, options.

@onready var play: Node = get_parent().get_parent()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not Run.active:
		return
	if Cheats.enabled and not Run.room.is_empty():
		CheatMenu.draw_info(self)
	match play.mode:
		"levelup": _level_up()
		"pause": _pause(false)
		"build": _pause(true)
		"map": MapDraw.full_map(self)
		"options": _options()
		"cheats": CheatMenu.draw(self, play.cheat_menu, play.cheat_page)

func _level_up() -> void:
	var more := "   (" + str(Run.pending_levels - 1) + " pending)" if Run.pending_levels > 1 else ""
	play.card_rects = PanelsDraw.perk_cards(self, play.choices, play.sel, "A new spark", "Level " + str(Run.player.level) + "  -  choose a perk" + more)
	var can := Run.player.coins >= Run.reroll_cost
	var label := "Reroll  (" + str(Run.reroll_cost) + " coins)"
	var w := Txt.width(label) + 30
	var x := Consts.W / 2.0 - w / 2
	var y := 236.0
	UiDraw.panel(self, x, y, w, 18, {"alpha": 0.9})
	var kw := UiDraw.keycap(self, x + 6, y + 5, "Y" if Controls.device() == "pad" else "R")
	UiDraw.text(self, label, x + 10 + kw, y + 6, {"color": "#e8dcc0" if can else "#55505e"})
	play.reroll_rect = Rect2(x, y, w, 18)

# drawPause (js/game.js)
func _pause(build_mode: bool) -> void:
	var ga := UiDraw.alpha
	UiDraw.alpha = 0.78
	UiDraw.px_rect(self, 0, 0, Consts.W, Consts.H, "#050308")
	UiDraw.alpha = ga
	UiDraw.text(self, "Paused", 90, 40, {"align": "center", "color": "#f6cf57", "scale": 2})
	if not build_mode:
		play.pause_menu.draw(self, 90, 76, {"lineH": 16})
	else:
		UiDraw.text(self, "^dArrows to scroll, ENTER to go back", 90, 76, {"align": "center"})
	UiDraw.text(self, "Seed " + str(Run.seed) + "  -  " + Consts.VERSION, 90, 240, {"align": "center", "color": "#3b3546"})
	if Run.ardor:
		UiDraw.text(self, "Ardor " + str(Run.ardor), 90, 228, {"align": "center", "color": "#e0574a"})
	# equipment panel
	var hover: int = play.build_sel if build_mode else -1
	var m := Controls.mouse_pos()
	for i in play.build_rects.size():
		if play.build_rects[i].has_point(m):
			hover = i
	play.build_rects = PanelsDraw.build_panel(self, 186, 30, 166, 226, hover)
	PanelsDraw.stats_panel(self, 358, 30, 116, 142)
	# summary
	UiDraw.panel(self, 358, 178, 116, 78)
	var rows := [["Kills", Run.kills], ["Rooms", Run.rooms_cleared], ["Time", U.fmt_time(Run.time)], ["Coins", Run.coins_total], ["Damage", int(U.jround(Run.dmg_dealt))]]
	for i in rows.size():
		UiDraw.text(self, rows[i][0], 366, 187 + i * 12, {"color": "#8a8294"})
		UiDraw.text(self, str(rows[i][1]), 466, 187 + i * 12, {"align": "right", "color": "#e8dcc0"})

func _options() -> void:
	var ga := UiDraw.alpha
	UiDraw.alpha = 0.8
	UiDraw.px_rect(self, 0, 0, Consts.W, Consts.H, "#050308")
	UiDraw.alpha = ga
	UiDraw.panel(self, Consts.W / 2.0 - 130, 50, 260, 170)
	UiDraw.text(self, "Options", Consts.W / 2.0, 62, {"align": "center", "color": "#f6cf57", "scale": 2})
	play.opt_menu.draw(self, Consts.W / 2.0, 96, {"lineH": 16})

# options shared by pause and title (makeOptionsMenu in js/game.js); the
# Resolution slider is Godot-only: it picks one of the classic sizes, up to
# the current screen's maximum, and the window can't be resized by dragging
static func classic_resolutions() -> Array:
	return [
		{"w": 1280, "h": 720},
		{"w": 1366, "h": 768},
		{"w": 1600, "h": 900},
		{"w": 1920, "h": 1080},
		{"w": 2560, "h": 1440},
		{"w": 3840, "h": 2160},
	]

static func available_resolutions() -> Array:
	if DisplayServer.get_name() == "headless":
		return classic_resolutions()   # the tests never open a window
	var max_v := DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
	var out: Array = []
	for r in classic_resolutions():
		if r.w <= max_v.x and r.h <= max_v.y:
			out.append(r)
	if out.is_empty():
		out = [classic_resolutions()[0]]
	return out

static func saved_resolution_index() -> int:
	return int(Save.data.settings.get("res", 2))

# position of the saved resolution inside avail, clamped to its largest entry
static func res_pos(avail: Array) -> int:
	var saved := saved_resolution_index()
	if saved < classic_resolutions().size():
		var i: int = avail.find(classic_resolutions()[saved])
		if i >= 0:
			return i
	return avail.size() - 1

# slider bar, same look as the volume bars
static func res_bar(idx: int, n: int) -> String:
	var frac := float(idx) / maxf(float(n) - 1.0, 1.0)
	var filled := 10 if n == 1 else int(round(frac * 10))
	return "[" + "#".repeat(filled) + "-".repeat(10 - filled) + "]"

# applies the saved resolution to the window (called at boot and when the
# slider moves), centered on the current screen
static func apply_resolution() -> void:
	if DisplayServer.get_name() == "headless" or DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		return
	var avail := available_resolutions()
	var r: Dictionary = avail[res_pos(avail)]
	var size := Vector2i(r.w, r.h)
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	var scr := DisplayServer.window_get_current_screen()
	root.size = size
	root.position = DisplayServer.screen_get_position(scr) + (DisplayServer.screen_get_size(scr) - size) / 2

# options shared by pause and title (makeOptionsMenu in js/game.js)
static func make_options_menu(on_back: Callable) -> Menu:
	var s: Dictionary = Save.data.settings
	var vol := func(v: float) -> String:
		var n := int(U.jround(v * 10))
		return "[" + "#".repeat(n) + "-".repeat(10 - n) + "]"
	var noop := func() -> void: pass
	return Menu.new([
		{"label": "Music", "value": func(): return vol.call(s.music),
			"adjust": func(d):
				s.music = clampf(U.jround(s.music * 10 + d) / 10, 0, 1)
				Sfx.apply_volumes()
				Save.write(),
			"action": noop},
		{"label": "Effects", "value": func(): return vol.call(s.sfx),
			"adjust": func(d):
				s.sfx = clampf(U.jround(s.sfx * 10 + d) / 10, 0, 1)
				Sfx.apply_volumes()
				Save.write()
				Sfx.play("coin"),
			"action": noop},
		{"label": "Screen shake", "value": func(): return "Sì" if s.shake else "No",
			"adjust": func(_d):
				s.shake = not s.shake
				Save.write(),
			"action": func():
				s.shake = not s.shake
				Save.write()},
		{"label": "Damage numbers", "value": func(): return "Sì" if s.numbers else "No",
			"adjust": func(_d):
				s.numbers = not s.numbers
				Save.write(),
			"action": func():
				s.numbers = not s.numbers
				Save.write()},
		{"label": "Resolution", "value": func() -> String:
			var avail := Panels.available_resolutions()
			var i := Panels.res_pos(avail)
			var r: Dictionary = avail[i]
			return str(r.w) + "x" + str(r.h) + "  " + Panels.res_bar(i, avail.size()),
			"adjust": func(d):
				var avail := Panels.available_resolutions()
				var i: int = clampi(Panels.res_pos(avail) + d, 0, avail.size() - 1)
				Save.data.settings.res = Panels.classic_resolutions().find(avail[i])
				Panels.apply_resolution()
				Save.write(),
			"action": noop},
		{"label": "Fullscreen", "action": func():
			var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fs else DisplayServer.WINDOW_MODE_FULLSCREEN)},
		{"label": "Back", "action": on_back},
	])
