extends Screen
# End of the demo: the vertical slice ends after the first warden
# (same structure as Scenes.victory in js/game.js, without the Infinite Abyss).

func enter() -> void:
	Save.data.stats.kills += Run.kills
	Save.write()
	Flow.check_unlocks()
	Music.play("title")
	menu = Menu.new([
		{"label": "New descent", "action": func(): Game.set_scene("select")},
		{"label": "Main menu", "action": func(): Game.set_scene("title")},
	])

func update(_dt: float) -> void:
	if t > 1.2:
		menu.update()

func paint() -> void:
	var W := Consts.W
	var glow_a := minf(1, t / 2)
	UiDraw.glow(self, W / 2.0, 60, 260, Color(1.0, 220 / 255.0, 140 / 255.0), 0.35 * glow_a)
	WellBg.big_lantern(self, W / 2.0, 34, "#fff2a8", sin(t) * 0.06, 2)
	UiDraw.text(self, "End of the demo", W / 2.0, 62, {"align": "center", "color": "#f6cf57", "scale": 2})
	UiDraw.text(self, "The Bone Warden has fallen. The other depths are coming soon.", W / 2.0, 84, {"align": "center", "color": "#c8c0d0"})
	UiDraw.panel(self, 30, 98, 200, 84)
	PanelsDraw.summary(self, 44, 107)
	UiDraw.panel(self, 240, 98, 210, 84)
	PanelsDraw.icons_row(self, 250, 106, 190)
	if not Run.new_unlocks.is_empty():
		UiDraw.text(self, "Unlocked: " + ", ".join(Run.new_unlocks), W / 2.0, 190, {"align": "center", "color": "#f6cf57"})
	menu.draw(self, W / 2.0, 210, {"lineH": 16})
