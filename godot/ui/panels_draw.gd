class_name PanelsDraw
extends RefCounted
# Perk cards, equipment and stats (js/ui.js).

static func perk_cards(ci: CanvasItem, choices: Array, lit: int, title: String, sub: String) -> Array:
	var W := Consts.W
	var ga := UiDraw.alpha
	UiDraw.alpha = 0.78
	UiDraw.px_rect(ci, 0, 0, W, Consts.H, "#050308")
	UiDraw.alpha = ga
	UiDraw.text(ci, title, W / 2.0, 34, {"align": "center", "color": "#f6cf57", "scale": 2})
	UiDraw.text(ci, sub, W / 2.0, 56, {"align": "center", "color": "#a8a0b0"})
	var n := choices.size()
	var cw := 108.0 if n >= 4 else 132.0
	var gap := 8.0
	var total := n * cw + (n - 1) * gap
	var x0 := W / 2.0 - total / 2
	var y0 := 74.0
	var chh := 150.0
	var rects: Array = []
	var p := Run.player
	for i in n:
		var id: String = choices[i]
		var P: Dictionary = Perks.ALL[id]
		var R: Dictionary = Stats.RARITY[P.rar]
		var x := x0 + i * (cw + gap)
		var is_sel := i == lit
		var y := y0 - (4 if is_sel else 0)
		rects.append(Rect2(x, y, cw, chh))
		UiDraw.panel(ci, x, y, cw, chh, {"hi": R.col if is_sel else UiDraw.UI.brass, "border": R.col if is_sel else UiDraw.UI.brassD, "alpha": 0.97})
		# icon
		UiDraw.px_rect(ci, x + cw / 2 - 14, y + 10, 28, 28, "#0b0810")
		UiDraw.px_rect(ci, x + cw / 2 - 13, y + 11, 26, 26, "#1a141f")
		if is_sel:
			UiDraw.glow(ci, x + cw / 2, y + 24, 22, R.col, 0.3)
		Spr.draw(ci, P.icon, 0, x + cw / 2, y + 24, {"scale": 2.0})
		var name_lines := Txt.wrap(P.name, cw - 10)
		for k in name_lines.size():
			UiDraw.text(ci, name_lines[k], x + cw / 2, y + 44 + k * 10, {"align": "center", "color": R.col})
		var ny := y + 44 + name_lines.size() * 10
		UiDraw.text(ci, R.name, x + cw / 2, ny, {"align": "center", "color": "#6b6478"})
		var lines := Txt.wrap(P.desc, cw - 12)
		for k in lines.size():
			UiDraw.text(ci, lines[k], x + 6, ny + 14 + k * 10, {"color": "#d8d0c0"})
		var have: int = p.perks.get(id, 0)
		if P["max"] > 1:
			for k in P["max"]:
				UiDraw.px_rect(ci, x + cw / 2 - P["max"] * 3 + k * 6, y + chh - 12, 4, 4, "#8a8294" if k < have else (R.col if k == have else "#2a2430"))
		UiDraw.text(ci, str(i + 1), x + 7, y + 6, {"color": "#55505e"})
	return rects

static func build_entries() -> Array:
	var p := Run.player
	var out: Array = []
	for id in p.perks:
		var P: Dictionary = Perks.ALL[id]
		out.append({"kind": "perk", "icon": P.icon, "name": P.name + ("  x" + str(p.perks[id]) if P["max"] > 1 else ""), "desc": P.desc, "col": Stats.RARITY[P.rar].col})
	for id in p.relics:
		out.append({"kind": "relic", "icon": Relics.ALL[id].icon, "name": Relics.ALL[id].name, "desc": Relics.ALL[id].desc, "col": "#f6cf57"})
	for id in p.curses:
		out.append({"kind": "curse", "icon": "s_curse", "name": Curses.ALL[id].name, "desc": Curses.ALL[id].desc, "col": "#c57ae0"})
	return out

static func build_panel(ci: CanvasItem, x: float, y: float, w: float, h: float, hover: int) -> Array:
	UiDraw.panel(ci, x, y, w, h)
	var entries := build_entries()
	UiDraw.text(ci, "Equipment", x + w / 2, y + 7, {"align": "center", "color": "#e8dcc0"})
	if entries.is_empty():
		UiDraw.text(ci, "Nothing yet. Descend and fight.", x + w / 2, y + 30, {"align": "center", "color": "#6b6478"})
		return []
	var cols := int(floor((w - 12) / 20))
	var rects: Array = []
	for i in entries.size():
		var e: Dictionary = entries[i]
		var cx := x + 8 + (i % cols) * 20
		var cy := y + 20 + (i / cols) * 20
		UiDraw.px_rect(ci, cx, cy, 18, 18, e.col if i == hover else "#0b0810")
		UiDraw.px_rect(ci, cx + 1, cy + 1, 16, 16, "#1a0d22" if e.kind == "curse" else "#1a141f")
		Spr.draw(ci, e.icon, 0, cx + 9, cy + 9)
		rects.append(Rect2(cx, cy, 18, 18))
	var dy := y + h - 46
	UiDraw.px_rect(ci, x + 6, dy - 4, w - 12, 1, UiDraw.UI.brassD)
	if hover >= 0 and hover < entries.size():
		var sel: Dictionary = entries[hover]
		UiDraw.text(ci, sel.name, x + 8, dy, {"color": sel.col})
		var lines := Txt.wrap(sel.desc, w - 16).slice(0, 3)
		for k in lines.size():
			UiDraw.text(ci, lines[k], x + 8, dy + 11 + k * 10, {"color": "#d8d0c0"})
	else:
		UiDraw.text_wrapped(ci, "^dHover over an icon or open Equipment to read the details.", x + 8, dy, w - 16, {})
	return rects

static func stats_panel(ci: CanvasItem, x: float, y: float, w: float, h: float) -> void:
	var p := Run.player
	var s := p.stats
	UiDraw.panel(ci, x, y, w, h)
	UiDraw.text(ci, "Stats", x + w / 2, y + 7, {"align": "center", "color": "#e8dcc0"})
	var rows := [
		["Damage", "%.1f" % p.damage()], ["Fire rate", "%.2f/s" % p.fire_rate()], ["Projectiles", U.num(s.proj)],
		["Crit", str(int(U.jround(s.crit * 100))) + "%  x" + ("%.1f" % s.critMult)], ["Speed", str(int(U.jround(p.speed())))], ["Armor", U.num(s.armor)],
		["Dodge", str(int(U.jround(s.dodge * 100))) + "%"], ["Dashes", U.num(s.dashCharges)], ["Oil", str(int(U.jround(p.oil))) + "/" + U.num(s.maxOil)],
		["Flare cost", str(int(U.jround(s.flareCost)))], ["Light", str(int(U.jround(p.light())))],
	]
	for i in rows.size():
		UiDraw.text(ci, rows[i][0], x + 8, y + 20 + i * 10, {"color": "#8a8294"})
		UiDraw.text(ci, rows[i][1], x + w - 8, y + 20 + i * 10, {"align": "right", "color": "#e8dcc0"})

# descent summary (runSummaryRows, drawSummary, drawIconsRow in js/game.js)
static func summary_rows() -> Array:
	return [["Depth reached", Run.depth], ["Level", Run.player.level], ["Enemies defeated", Run.kills],
		["Rooms cleared", Run.rooms_cleared], ["Coins collected", Run.coins_total], ["Time", U.fmt_time(Run.time)]]

static func summary(ci: CanvasItem, x: float, y: float) -> void:
	var rows := summary_rows()
	for i in rows.size():
		UiDraw.text(ci, rows[i][0], x, y + i * 12, {"color": "#a8a0b0"})
		UiDraw.text(ci, str(rows[i][1]), x + 170, y + i * 12, {"align": "right", "color": "#e8dcc0"})

static func icons_row(ci: CanvasItem, x: float, y: float, max_w: float) -> void:
	var ents := build_entries()
	var cols := int(floor(max_w / 20))
	for i in mini(ents.size(), cols * 3):
		var e: Dictionary = ents[i]
		var cx := x + (i % cols) * 20
		var cy := y + (i / cols) * 20
		UiDraw.px_rect(ci, cx, cy, 18, 18, "#0b0810")
		UiDraw.px_rect(ci, cx + 1, cy + 1, 16, 16, "#1a0d22" if e.kind == "curse" else "#1a141f")
		Spr.draw(ci, e.icon, 0, cx + 9, cy + 9)
