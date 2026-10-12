extends Screen
# Scelta della lanterna (Scenes.select in js/game.js).

static var ard := 0

func enter() -> void:
	var un: Dictionary = Save.data.unlocks
	ard = mini(un.ardore, ard)
	var items: Array = []
	for L in DB.lanterns():
		var open: bool = un.lanterns.has(L.id)
		var id: String = L.id
		items.append({"label": L.name if open else "Lanterna sigillata", "L": L, "disabled": not open,
			"action": func():
				Flow.start_run(id, ard)
				Game.set_scene("play")})
	if un.ardore > 0:
		items.append({"label": "Ardore", "value": func(): return str(ard),
			"adjust": func(d): ard = clampi(ard + d, 0, un.ardore),
			"action": func(): ard = (ard + 1) % (un.ardore + 1)})
	items.append({"label": "Indietro", "action": func(): Game.set_scene("title")})
	menu = Menu.new(items, {"allowDisabled": true})

func update(_dt: float) -> void:
	if Controls.back():
		Game.set_scene("title")
		return
	menu.update()

func paint() -> void:
	var W := Consts.W
	UiDraw.text(self, "Scegli la tua lanterna", W / 2.0, 16, {"align": "center", "color": "#f6cf57", "scale": 2})
	UiDraw.panel(self, 20, 44, 190, 200)
	menu.draw(self, 40, 58, {"lineH": 16, "align": "left"})
	var it: Dictionary = menu.current()
	UiDraw.panel(self, 222, 44, 238, 200)
	if it.has("L"):
		var L: LanternDef = it.L
		var locked: bool = it.disabled
		WellBg.big_lantern(self, 341, 92, "#3b3546" if locked else L.glass, sin(t * 1.5) * 0.1, 3)
		UiDraw.text(self, "???" if locked else L.name, 341, 140, {"align": "center", "color": "#55505e" if locked else "#f6cf57"})
		if locked:
			UiDraw.text_wrapped(self, "^dPer sbloccarla: ^w" + L.unlock_text, 232, 160, 218, {})
		else:
			UiDraw.text_wrapped(self, L.desc, 232, 160, 218, {"color": "#d8d0c0"})
	elif it.label is String and it.label == "Ardore":
		UiDraw.text(self, "Ardore " + str(ard), 341, 70, {"align": "center", "color": "#e0574a", "scale": 2})
		UiDraw.text_wrapped(self, "Ogni livello di Ardore rende la discesa più crudele. Si sblocca riaccendendo la Fiamma Prima.", 232, 100, 218, {"color": "#a8a0b0"})
		for i in range(1, ard + 1):
			UiDraw.text(self, Lore.ARDORE[i], 232, 140 + (i - 1) * 11, {})
		if ard == 0:
			UiDraw.text(self, Lore.ARDORE[0], 232, 140, {"color": "#8a8294"})
	else:
		UiDraw.text_wrapped(self, "Ogni lanterna cambia il modo di affrontare il buio. Nuove lanterne si sbloccano scendendo più in profondità.", 232, 90, 218, {"color": "#a8a0b0"})
	UiDraw.text(self, "INVIO o clic per iniziare   -   ESC per tornare", W / 2.0, 252, {"align": "center", "color": "#55505e"})
