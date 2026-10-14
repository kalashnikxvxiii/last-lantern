extends Screen
# Godot-only: the save slots (RunSave), chosen before a descent.
# An empty slot starts a new descent, a full one is resumed or erased.

const CX := 30.0
const CW := 420.0
const CH := 52.0

var saves: Array = []
var slot_menu: Menu = null   # actions of the chosen full slot
var confirm_erase := false

func enter() -> void:
	saves = []
	var items: Array = []
	for i in RunSave.SLOTS:
		saves.append(RunSave.read(i))
		var slot := i
		items.append({"label": "", "action": func(): _choose(slot)})
	items.append({"label": "Back", "action": func(): Game.set_scene("title")})
	menu = Menu.new(items)

func _choose(slot: int) -> void:
	if saves[slot].is_empty():
		Game.set_scene("select", slot)
		return
	confirm_erase = false
	slot_menu = Menu.new([
		{"label": "Continue the descent", "action": func():
			if RunSave.resume(slot):
				Game.set_scene("play")},
		{"label": func(): return "Sure? It will be lost" if confirm_erase else "Erase the descent", "action": func():
			if not confirm_erase:
				confirm_erase = true
				return
			RunSave.erase(slot)
			slot_menu = null
			enter()
			menu.sel = slot},
		{"label": "Back", "action": func(): slot_menu = null},
	])

func update(_dt: float) -> void:
	if slot_menu != null:
		if Controls.back():
			slot_menu = null
			return
		slot_menu.update()
		if slot_menu != null and slot_menu.sel != 1:
			confirm_erase = false
		return
	if Controls.back():
		Game.set_scene("title")
		return
	menu.update()

func paint() -> void:
	var W := Consts.W
	UiDraw.text(self, "Choose a slot", W / 2.0, 14, {"align": "center", "color": "#f6cf57", "scale": 2})
	var rects: Array = []
	for i in saves.size():
		var y := 40.0 + i * (CH + 8)
		rects.append(Rect2(CX, y, CW, CH))
		var is_sel := menu.sel == i
		UiDraw.panel(self, CX, y, CW, CH, {"hi": UiDraw.UI.sel if is_sel else UiDraw.UI.brass, "border": UiDraw.UI.sel if is_sel else UiDraw.UI.brassD})
		_card(i, saves[i], y)
	var back_y := 40.0 + saves.size() * (CH + 8) + 6
	var bw := Txt.width("Back")
	rects.append(Rect2(W / 2.0 - bw / 2 - 14, back_y - 3, bw + 28, 14))
	UiDraw.text(self, "Back", W / 2.0, back_y, {"align": "center", "color": UiDraw.UI.sel if menu.sel == saves.size() else "#c8c0d0"})
	menu.rects = rects
	if slot_menu != null:
		var ga := UiDraw.alpha
		UiDraw.alpha = 0.7
		UiDraw.px_rect(self, 0, 0, W, Consts.H, "#050308")
		UiDraw.alpha = ga
		UiDraw.panel(self, W / 2.0 - 90, 92, 180, 70)
		slot_menu.draw(self, W / 2.0, 106, {"lineH": 16})
	UiDraw.text(self, "ENTER or click to choose   -   ESC to go back", W / 2.0, 252, {"align": "center", "color": "#55505e"})

# overview of the run saved in the slot
func _card(i: int, d: Dictionary, y: float) -> void:
	var x := CX + 40
	if d.is_empty():
		UiDraw.text(self, Loc.f("Slot {0}", [i + 1]), x, y + 10, {"color": "#8a8294"})
		UiDraw.text(self, "Empty  -  a new descent begins here", x, y + 26, {"color": "#55505e"})
		return
	var s: Dictionary = d.summary
	var L := DB.lantern(s.lantern)
	WellBg.big_lantern(self, CX + 20, y + 28, L.glass, sin(t * 1.5 + i) * 0.1, 1.5)
	UiDraw.text(self, Loc.f("Slot {0}", [i + 1]) + "   ^y" + Loc.t(L.name), x, y + 8, {"color": "#8a8294"})
	UiDraw.text(self, s.date.substr(0, 16), CX + CW - 8, y + 8, {"align": "right", "color": "#55505e"})
	var where := Loc.f("Depth {0}", [s.depth]) + "  -  " + Loc.t(DB.biome_of(s.depth).name)
	if s.ardor > 0:
		where += "  -  ^r" + Loc.f("Ardor {0}", [s.ardor])
	if s.endless:
		where += "  -  ^y" + Loc.t("Infinite Abyss")
	UiDraw.text(self, where, x, y + 21, {"color": "#e8dcc0"})
	UiDraw.text(self, Loc.f("^dLevel ^w{0}   ^dHealth ^w{1}/{2}   ^dCoins ^w{3}   ^dTime ^w{4}", [s.level, ceili(s.hp), int(s.maxHp), s.coins, U.fmt_time(s.time)]), x, y + 34, {})
	var relics: Array = s.relics
	var n := mini(relics.size(), 6)
	for k in n:
		var rx := CX + CW - 8 - (n - k) * 20
		UiDraw.px_rect(self, rx, y + 22, 18, 18, "#0b0810")
		UiDraw.px_rect(self, rx + 1, y + 23, 16, 16, "#1a141f")
		Spr.draw(self, Relics.ALL[relics[k]].icon, 0, rx + 9, y + 31)
