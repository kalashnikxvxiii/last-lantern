extends Screen
# The First Flame is rekindled (Scenes.victory in js/game.js).

func enter() -> void:
	var st: Dictionary = Save.data.stats
	var un: Dictionary = Save.data.unlocks
	if not Run.win_recorded and not Run.cheated:
		Run.win_recorded = true
		st.wins += 1
		if not st.bestTime or Run.time < st.bestTime:
			st.bestTime = int(U.jround(Run.time))
		st.maxArdorWon = maxi(st.maxArdorWon, Run.ardor)
		var before: int = un.ardor
		un.ardor = mini(5, maxi(un.ardor, Run.ardor + 1))
		if un.ardor > before:
			Run.new_unlocks.append("Ardor " + str(un.ardor))
		Save.write()
		Flow.check_unlocks()
	Music.play("title")
	menu = Menu.new([
		{"label": "Continue into the Infinite Abyss", "action": func():
			Run.endless = true
			var c := RoomU.tile_center(14, 7)
			if not Run.room.objects.any(func(o): return o.type == "trapdoor"):
				Run.room.objects.append({"type": "trapdoor", "x": c.x, "y": c.y + 34})
			Game.set_scene("play", "continue")},
		{"label": "Return to the surface", "action": func():
			if not Run.cheated:
				Save.data.stats.kills += Run.kills
			Save.write()
			RunSave.erase(Run.slot)
			Game.set_scene("title")},
	])

func update(_dt: float) -> void:
	if t > 1.2:
		menu.update()

func paint() -> void:
	var W := Consts.W
	var glow_a := minf(1, t / 2)
	UiDraw.glow(self, W / 2.0, 60, 260, Color(1.0, 220 / 255.0, 140 / 255.0), 0.35 * glow_a)
	WellBg.big_lantern(self, W / 2.0, 34, "#fff2a8", sin(t) * 0.06, 2)
	UiDraw.text(self, "The First Flame burns again", W / 2.0, 62, {"align": "center", "color": "#f6cf57", "scale": 2})
	UiDraw.text(self, "The sun will rise again. The Well, however, is still hungry.", W / 2.0, 84, {"align": "center", "color": "#c8c0d0"})
	UiDraw.panel(self, 30, 98, 200, 84)
	PanelsDraw.summary(self, 44, 107)
	UiDraw.panel(self, 240, 98, 210, 84)
	PanelsDraw.icons_row(self, 250, 106, 190)
	if not Run.new_unlocks.is_empty():
		UiDraw.text(self, "Unlocked: " + ", ".join(Run.new_unlocks), W / 2.0, 190, {"align": "center", "color": "#f6cf57"})
	menu.draw(self, W / 2.0, 210, {"lineH": 16})
