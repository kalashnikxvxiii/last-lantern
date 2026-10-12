extends Screen
# Archivio (Scenes.records in js/game.js).

func update(_dt: float) -> void:
	if Controls.back() or Controls.confirm() or Controls.mouse_left_pressed():
		Game.set_scene("title")

func paint() -> void:
	var W := Consts.W
	UiDraw.panel(self, W / 2.0 - 150, 30, 300, 210)
	UiDraw.text(self, "Archivio", W / 2.0, 42, {"align": "center", "color": "#f6cf57", "scale": 2})
	var st: Dictionary = Save.data.stats
	var un: Dictionary = Save.data.unlocks
	var rows := [
		["Discese tentate", st.runs], ["Fiamme riaccese", st.wins], ["Profondità massima", st.bestDepth],
		["Nemici sconfitti", st.kills], ["Guardiani abbattuti", st.bossKills],
		["Discesa più rapida", U.fmt_time(st.bestTime) if st.bestTime else "-"], ["Ardore sbloccato", un.ardore],
		["Lanterne", str(un.lanterns.size()) + " / " + str(DB.LANTERN_IDS.size())],
	]
	for i in rows.size():
		UiDraw.text(self, rows[i][0], W / 2.0 - 130, 72 + i * 14, {"color": "#a8a0b0"})
		UiDraw.text(self, U.num(rows[i][1]), W / 2.0 + 130, 72 + i * 14, {"align": "right", "color": "#e8dcc0"})
	var ls := DB.lanterns()
	for i in ls.size():
		var L: LanternDef = ls[i]
		var ok: bool = un.lanterns.has(L.id)
		var x := W / 2.0 - 100 + i * 50
		UiDraw.px_rect(self, x - 1, 192, 12, 16, "#0b0810")
		UiDraw.px_rect(self, x + 1, 195, 8, 10, L.glass if ok else "#2a2430")
	UiDraw.text(self, "Premi un tasto per tornare", W / 2.0, 224, {"align": "center", "color": "#55505e"})
