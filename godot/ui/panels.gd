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
	var lit: int = play.card_hover if Controls.device() == "mouse" else play.sel
	play.card_rects = PanelsDraw.perk_cards(self, play.choices, lit, "A new spark", "Level " + str(Run.player.level) + "  -  choose a perk" + more)
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
	# equipment panel: the mouse lights what it is over, the keyboard its own cursor
	var hover := -1
	if Controls.device() == "mouse":
		var m := Controls.mouse_pos()
		for i in play.build_rects.size():
			if (play.build_rects[i] as Rect2).has_point(m):
				hover = i
				break
	elif build_mode:
		hover = play.build_sel
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
	play.opt_menu.draw(self)
