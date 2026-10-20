class_name MapDraw
extends RefCounted
# Minimap and full map (drawMinimap, drawFullMap, roomKnown, roomsVisible in js/ui.js).

static var ROOM_MARK := {"boss": "#e0574a", "treasure": "#f6cf57", "shop": "#c49a6a", "shrine": "#c57ae0", "elite": "#ff3a5a", "secret": "#8a8294", "start": "#6b6478"}

static func room_known(r: Dictionary) -> bool:
	if r.type == "secret":
		return r.found or r.get("mapped", false) or bool(Run.player.stats.mapReveal)
	return r.seen or bool(Run.player.stats.mapReveal)

static func rooms_visible() -> bool:
	return not Run.player.stats.hideMap

static func minimap(ci: CanvasItem, x0: float, y0: float, full: bool) -> void:
	if not rooms_visible():
		UiDraw.px_rect(ci, x0, y0, 80, 23, "#0b0810")
		UiDraw.text(ci, "Fog", x0 + 40, y0 + 8, {"align": "center", "color": "#55505e"})
		return
	var cur := Run.room
	var cw := 22 if full else 14
	var ch := 13 if full else 6
	var gap := 2
	var gx0 := 0
	var gy0 := 0
	var nx := 9
	var ny := 8
	if not full:
		# Godot-only: around the cell the player is in, in a room of several
		gx0 = cur.gx + clampi(floori((Run.player.x - Consts.RX) / (Consts.RW * Consts.TS)), 0, int(cur.get("cw", 1)) - 1) - 2
		gy0 = cur.gy + clampi(floori((Run.player.y - Consts.RY) / (Consts.RH * Consts.TS)), 0, int(cur.get("ch", 1)) - 1) - 1
		nx = 5
		ny = 3
		UiDraw.px_rect(ci, x0 - 1, y0 - 1, 82, 25, "#0b0810")
	# Godot-only: a room of several cells (RoomShapes) shows as one, its doors on the cells they are in
	var at := func(r: Dictionary, c: Vector2i) -> Variant:
		var gx: int = r.gx + c.x - gx0
		var gy: int = r.gy + c.y - gy0
		if gx < 0 or gy < 0 or gx >= nx or gy >= ny:
			return null
		return Vector2(x0 + gx * (cw + gap), y0 + gy * (ch + gap))
	for r in Run.floor.rooms:
		if not room_known(r):
			continue
		var cs := RoomU.cells(r)
		if cs.all(func(c): return at.call(r, c) == null):
			continue
		var is_cur := is_same(r, cur)
		var fill := "#4a4256" if r.visited else "#1f1a26"
		if is_cur:
			fill = "#d8b46a"
		for c in cs:
			var p: Variant = at.call(r, c)
			if p != null:
				UiDraw.px_rect(ci, p.x, p.y, cw, ch, "#6b6478")
		for c in cs:
			var p: Variant = at.call(r, c)
			if p == null:
				continue
			UiDraw.px_rect(ci, p.x + 1, p.y + 1, cw - 2, ch - 2, fill)
			if cs.has(c + Vector2i(1, 0)):
				UiDraw.px_rect(ci, p.x + cw - 1, p.y + 1, gap + 2, ch - 2, fill)
			if cs.has(c + Vector2i(0, 1)):
				UiDraw.px_rect(ci, p.x + 1, p.y + ch - 1, cw - 2, gap + 2, fill)
		# corridors
		for d in r.doors:
			var n: Dictionary = r.doors[d]
			if not RoomU.door_visible(r, d) or not room_known(n):
				continue
			var p: Variant = at.call(r, RoomU.door_cell(d))
			if p == null:
				continue
			var k: float = {"": 0.0, "a": -1.0, "b": 1.0}[RoomU.door_slot(d)]
			if d[0] == "e":
				UiDraw.px_rect(ci, p.x + cw, p.y + ch / 2.0 - 1 + k * ch / 4.0, gap, 2, "#6b6478")
			if d[0] == "s":
				UiDraw.px_rect(ci, p.x + cw / 2.0 - 1 + k * cw / 4.0, p.y + ch, 2, gap, "#6b6478")
		var p0: Variant = at.call(r, cs[0])   # the room's mark, on its first cell
		if p0 == null:
			continue
		var x: float = p0.x
		var y: float = p0.y
		var mk: Variant = ROOM_MARK.get(r.type)
		if mk != null and r.type != "start":
			var s := 5 if full else 2
			UiDraw.px_rect(ci, x + cw / 2.0 - s / 2.0, y + ch / 2.0 - s / 2.0, s, s, "#0b0810" if is_cur else mk)
			if full and r.type == "treasure" and r.get("locked", false):
				UiDraw.px_rect(ci, x + cw - 4, y + 1, 3, 3, "#f6cf57")

static func full_map(ci: CanvasItem) -> void:
	var ga := UiDraw.alpha
	UiDraw.alpha = 0.85
	UiDraw.px_rect(ci, 0, 0, Consts.W, Consts.H, "#050308")
	UiDraw.alpha = ga
	var w := 9 * 24 + 30
	var h := 8 * 15 + 70
	var x := Consts.W / 2.0 - w / 2.0
	var y := Consts.H / 2.0 - h / 2.0
	UiDraw.panel(ci, x, y, w, h)
	UiDraw.text(ci, Loc.f("Map - {0}", [Loc.t(DB.biome_of(Run.depth).name)]), Consts.W / 2.0, y + 8, {"align": "center", "color": "#e8dcc0"})
	if not rooms_visible():
		UiDraw.text(ci, "Fog", Consts.W / 2.0, y + h / 2.0 - 4.0, {"align": "center", "color": "#55505e"})
		return
	minimap(ci, x + 15, y + 24, true)
	var leg := [["boss", "Warden"], ["treasure", "Treasure"], ["shop", "Merchant"], ["shrine", "Shrine"], ["elite", "Challenge"], ["secret", "Secret"]]
	for i in leg.size():
		var lx := x + 14 + (i % 3) * 82
		var ly := y + h - 28 + (i / 3) * 11
		UiDraw.px_rect(ci, lx, ly + 2, 4, 4, ROOM_MARK[leg[i][0]])
		UiDraw.text(ci, leg[i][1], lx + 7, ly, {"color": "#a8a0b0"})
