extends Screen
# End of the descent (Scenes.gameover in js/game.js).

func enter() -> void:
	var st: Dictionary = Save.data.stats
	if not Run.cheated:
		st.kills += Run.kills
	Save.write()
	RunSave.erase(Run.slot)
	Flow.check_unlocks()
	Music.play("title")
	Music.set_intensity(0)
	menu = Menu.new([
		{"label": "New descent", "action": func(): Game.set_scene("slots")},
		{"label": "Main menu", "action": func(): Game.set_scene("title")},
	])

func update(_dt: float) -> void:
	if t > 0.8:
		menu.update()

func paint() -> void:
	var W := Consts.W
	var ga := UiDraw.alpha
	UiDraw.alpha = minf(1, t / 0.8)
	UiDraw.text(self, "You left the Well" if Run.abandoned else "Your light has gone out", W / 2.0, 18, {"align": "center", "color": "#e0574a", "scale": 2})
	var cause := "The dark will await your return." if Run.abandoned else Loc.f("Killed by: {0}", [Loc.t(Run.player.last_hit if Run.player.last_hit != "" else "The dark")])
	UiDraw.text(self, cause, W / 2.0, 40, {"align": "center", "color": "#a8a0b0"})
	UiDraw.panel(self, 30, 56, 200, 100)
	PanelsDraw.summary(self, 44, 66)
	UiDraw.panel(self, 240, 56, 210, 100)
	UiDraw.text(self, "What you carried", 345, 63, {"align": "center", "color": "#e8dcc0"})
	PanelsDraw.icons_row(self, 250, 76, 190)
	if not Run.new_unlocks.is_empty():
		UiDraw.text(self, Loc.f("Unlocked: {0}", [", ".join(Run.new_unlocks.map(func(u: String) -> String: return Loc.t(u)))]), W / 2.0, 164, {"align": "center", "color": "#f6cf57"})
	menu.draw(self, W / 2.0, 190, {"lineH": 16})
	UiDraw.text(self, Loc.f("Seed {0}", [Run.seed]) + "  -  " + Loc.f("Ardor {0}", [Run.ardor]) + "  -  " + Consts.VERSION, W / 2.0, 252, {"align": "center", "color": "#3b3546"})
	UiDraw.alpha = ga
