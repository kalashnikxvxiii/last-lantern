extends Screen
# How to play (Scenes.help in js/game.js).

var page := 0

func update(_dt: float) -> void:
	if Controls.back():
		Game.set_scene("title")
		return
	if Controls.right() or Controls.confirm() or Controls.mouse_left_pressed():
		page += 1
		Sfx.play("select")
		if page > 2:
			Game.set_scene("title")
	if Controls.left() and page > 0:
		page -= 1
		Sfx.play("select")

func paint() -> void:
	var W := Consts.W
	var H := Consts.H
	UiDraw.panel(self, 24, 14, W - 48, H - 28)
	var titles := ["Controls", "The descent", "Status effects"]
	UiDraw.text(self, titles[mini(page, 2)], W / 2.0, 24, {"align": "center", "color": "#f6cf57", "scale": 2})
	var x := 44.0
	if page == 0:
		var rows := [
			[["W", "A", "S", "D"], "Move"], [["Mouse"], "Aim  (or the arrow keys)"], [["Left click"], "Shoot  (or hold the arrow keys)"],
			[["Space"], "Dash: pass through attacks unharmed"], [["Right click", "F"], "Flare: wave of fire, uses oil"],
			[["1", "2", "3", "4"], "Use a consumable"], [["E"], "Interact: chests, relics, merchant"], [["Tab", "M"], "Depth map"], [["Esc", "P"], "Pause and equipment"],
		]
		for i in rows.size():
			var kx := x
			for k in rows[i][0]:
				kx += UiDraw.keycap(self, kx, 50 + i * 18, k) + 3
			UiDraw.text(self, rows[i][1], x + 110, 51 + i * 18, {"color": "#d8d0c0"})
		UiDraw.text_wrapped(self, "^dGamepad: left stick to move, right stick to aim and shoot, A dash, B Flare, X interact, d-pad for consumables.", x, 216, W - 90, {})
	elif page == 1:
		var txt := [
			"^yThe lantern is your life.^w During fights the oil burns and your light shrinks. Every enemy killed gives back a little oil. Without oil the dark hurts you: you take ^r+25%^w damage.",
			"^yThe Flare^w burns and pushes back everything around you and cancels nearby projectiles. It costs oil: use it wisely.",
			"^yPerks^w come from leveling up and are chosen once the room is safe. ^yRelics^w are found in treasures, from merchants, in secrets and from wardens. Some carry ^pcurses^w.",
			"^yBombs^w open secret passages: look for cracks in the walls. Every depth has a ^rwarden^w: defeat it and go down the trapdoor. There are five depths down to the Heart of the Well.",
		]
		var y := 46.0
		for tx in txt:
			y += UiDraw.text_wrapped(self, tx, x, y, W - 90, {"color": "#d8d0c0"}) + 6
	else:
		var desc := {
			"burn": "Damage over time for a few seconds.", "poison": "Damage over time that stacks with every hit.", "chill": "Slows. Three stacks freeze enemies.",
			"slow": "You move more slowly.", "weak": "You deal 30% less damage.", "fragile": "You take 30% more damage.", "blind": "Your light shrinks drastically.",
			"rage": "Damage and fire rate increased.", "immune": "No debuff can affect you.", "invis": "Enemies lose your trail.", "fury": "Fire rate increased after every kill.",
		}
		var ks := Statuses.ALL.keys()
		for i in ks.size():
			var k: String = ks[i]
			var y := 46 + i * 16
			UiDraw.px_rect(self, x, y - 2, 11, 12, "#0b0810")
			Spr.draw(self, Statuses.ALL[k].icon, 0, x + 5.5, y + 4)
			UiDraw.text(self, Statuses.ALL[k].name, x + 18, y, {"color": Statuses.ALL[k].col})
			UiDraw.text(self, desc.get(k, ""), x + 110, y, {"color": "#d8d0c0"})
	UiDraw.text(self, Loc.f("{0} / 3   -   arrows to flip pages, ESC to exit", [mini(page, 2) + 1]), W / 2.0, H - 26, {"align": "center", "color": "#55505e"})
