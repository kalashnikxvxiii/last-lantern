extends Screen
# Fine della discesa (Scenes.gameover in js/game.js).

func enter() -> void:
	var st: Dictionary = Save.data.stats
	st.kills += Run.kills
	Save.write()
	Flow.check_unlocks()
	Music.play("title")
	Music.set_intensity(0)
	menu = Menu.new([
		{"label": "Nuova discesa", "action": func(): Game.set_scene("select")},
		{"label": "Menu principale", "action": func(): Game.set_scene("title")},
	])

func update(_dt: float) -> void:
	if t > 0.8:
		menu.update()

func paint() -> void:
	var W := Consts.W
	var ga := UiDraw.alpha
	UiDraw.alpha = minf(1, t / 0.8)
	UiDraw.text(self, "Hai lasciato il pozzo" if Run.abandoned else "La tua luce si è spenta", W / 2.0, 18, {"align": "center", "color": "#e0574a", "scale": 2})
	var cause := "Il buio attenderà il tuo ritorno." if Run.abandoned else "Ucciso da: " + (Run.player.last_hit if Run.player.last_hit != "" else "Il buio")
	UiDraw.text(self, cause, W / 2.0, 40, {"align": "center", "color": "#a8a0b0"})
	UiDraw.panel(self, 30, 56, 200, 100)
	PanelsDraw.summary(self, 44, 66)
	UiDraw.panel(self, 240, 56, 210, 100)
	UiDraw.text(self, "Ciò che portavi", 345, 63, {"align": "center", "color": "#e8dcc0"})
	PanelsDraw.icons_row(self, 250, 76, 190)
	if not Run.new_unlocks.is_empty():
		UiDraw.text(self, "Sbloccato: " + ", ".join(Run.new_unlocks), W / 2.0, 164, {"align": "center", "color": "#f6cf57"})
	menu.draw(self, W / 2.0, 190, {"lineH": 16})
	UiDraw.text(self, "Seme " + str(Run.seed) + "  -  Ardore " + str(Run.ardore) + "  -  " + Consts.VERSION, W / 2.0, 252, {"align": "center", "color": "#3b3546"})
	UiDraw.alpha = ga
