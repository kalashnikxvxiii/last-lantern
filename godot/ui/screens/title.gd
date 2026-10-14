extends Screen
# Title (Scenes.title in js/game.js).

var confirm_quit := false

func enter() -> void:
	menu = Menu.new([
		{"label": "Descend", "action": func(): Game.set_scene("slots")},
		{"label": "How to play", "action": func(): Game.set_scene("help")},
		{"label": "Archive", "action": func(): Game.set_scene("records")},
		{"label": "Options", "action": func(): Game.set_scene("options")},
		{"label": func(): return "Sure? Press again to quit" if confirm_quit else "Quit the game", "action": func():
			if not confirm_quit:
				confirm_quit = true
				return
			get_tree().quit()},
	])
	Music.play("title")
	Music.set_intensity(0)
	Run.reset()

func update(_dt: float) -> void:
	menu.update()
	if menu.sel != menu.items.size() - 1:
		confirm_quit = false

func paint() -> void:
	var W := Consts.W
	WellBg.big_lantern(self, W / 2.0, 46, "#f6cf57", sin(t * 1.3) * 0.12, 3)
	UiDraw.text(self, "LAST", W / 2.0, 92, {"align": "center", "color": "#c8a050", "scale": 3, "shadowColor": "#2a1408"})
	UiDraw.text(self, "LANTERN", W / 2.0, 118, {"align": "center", "color": "#f6cf57", "scale": 4, "shadowColor": "#2a1408"})
	UiDraw.text(self, "a descent into the sunless well", W / 2.0, 154, {"align": "center", "color": "#8a8294"})
	menu.draw(self, W / 2.0, 172, {"lineH": 14})
	var st: Dictionary = Save.data.stats
	if st.runs > 0:
		UiDraw.text(self, Loc.f("Descents: {0}   Deepest depth: {1}   Flames rekindled: {2}", [st.runs, st.bestDepth, st.wins]), W / 2.0, 248, {"align": "center", "color": "#55505e"})
	UiDraw.text(self, "Keyboard and mouse or gamepad", W / 2.0, 259, {"align": "center", "color": "#3b3546"})
	UiDraw.text(self, Consts.VERSION, W - 5, 259, {"align": "right", "color": "#3b3546"})
