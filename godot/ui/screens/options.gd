extends Screen
# Opzioni dal titolo (Scenes.options in js/game.js).

func enter() -> void:
	menu = Panels.make_options_menu(func(): Game.set_scene("title"))

func update(_dt: float) -> void:
	if Controls.back():
		Game.set_scene("title")
		return
	menu.update()

func paint() -> void:
	UiDraw.panel(self, Consts.W / 2.0 - 130, 50, 260, 170)
	UiDraw.text(self, "Opzioni", Consts.W / 2.0, 62, {"align": "center", "color": "#f6cf57", "scale": 2})
	menu.draw(self, Consts.W / 2.0, 96, {"lineH": 16})
