extends Screen
# Titolo (Scenes.title in js/game.js).

func enter() -> void:
	menu = Menu.new([
		{"label": "Nuova discesa", "action": func(): Game.set_scene("select")},
		{"label": "Come si gioca", "action": func(): Game.set_scene("help")},
		{"label": "Archivio", "action": func(): Game.set_scene("records")},
		{"label": "Opzioni", "action": func(): Game.set_scene("options")},
	])
	Music.play("title")
	Music.set_intensity(0)
	Run.reset()

func paint() -> void:
	var W := Consts.W
	WellBg.big_lantern(self, W / 2.0, 46, "#f6cf57", sin(t * 1.3) * 0.12, 3)
	UiDraw.text(self, "ULTIMA", W / 2.0, 92, {"align": "center", "color": "#c8a050", "scale": 3, "shadowColor": "#2a1408"})
	UiDraw.text(self, "LANTERNA", W / 2.0, 118, {"align": "center", "color": "#f6cf57", "scale": 4, "shadowColor": "#2a1408"})
	UiDraw.text(self, "una discesa nel pozzo senza sole", W / 2.0, 154, {"align": "center", "color": "#8a8294"})
	menu.draw(self, W / 2.0, 178, {"lineH": 15})
	var st: Dictionary = Save.data.stats
	if st.runs > 0:
		UiDraw.text(self, "Discese: " + str(st.runs) + "   Profondità massima: " + str(st.bestDepth) + "   Fiamme riaccese: " + str(st.wins), W / 2.0, 248, {"align": "center", "color": "#55505e"})
	UiDraw.text(self, "Tastiera e mouse oppure gamepad", W / 2.0, 259, {"align": "center", "color": "#3b3546"})
	UiDraw.text(self, Consts.VERSION, W - 5, 259, {"align": "right", "color": "#3b3546"})
