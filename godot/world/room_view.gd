extends Node2D
# Room background (renderRoomBg in js/dungeon.js): TileMapLayer for floor,
# walls and rocks; decorations, tutorial text and wall shadow drawn by code.

class DrawCall extends Node2D:
	var fn: Callable
	func _draw() -> void:
		fn.call(self)

var floor_layer := TileMapLayer.new()
var rubble := TileMapLayer.new()   # Godot-only: what blown rocks leave
var decals := DrawCall.new()
var walls := TileMapLayer.new()
var shadow := DrawCall.new()
var rocks := TileMapLayer.new()
var shown: Dictionary = {}

func _ready() -> void:
	position = Vector2(Consts.RX, Consts.RY)
	decals.fn = _draw_decals
	shadow.fn = _draw_wall_shadow
	for n in [floor_layer, rubble, decals, walls, shadow, rocks]:
		add_child(n)

func _process(_delta: float) -> void:
	if not Run.active or Run.room.is_empty():
		return
	rocks.visible = not View3D.on   # the 3D view raises them
	if not is_same(Run.room, shown) or Run.room.get("bgDirty", false):
		show_room(Run.room)

func show_room(room: Dictionary) -> void:
	shown = room
	var biome := DB.biome_of(Run.floor.depth)
	var ts := TilePick.tileset(biome.id)
	for layer in [floor_layer, rubble, walls, rocks]:
		layer.tile_set = ts
		layer.scale = Vector2.ONE * Consts.TS / ts.tile_size.x   # Godot-only: HD tiles on the 16 px grid
		layer.clear()
	var s: int = room.seed % 1000
	for ty in Consts.RH:
		for tx in Consts.RW:
			var cell := Vector2i(tx, ty)
			var t: int = room.grid[ty][tx]
			if t == Consts.T.WALL or t == Consts.T.DOOR:
				walls.set_cell(cell, 0, TilePick.coords(biome.id, TilePick.wall_key(tx, ty, s)))
			else:
				floor_layer.set_cell(cell, 0, TilePick.coords(biome.id, TilePick.floor_key(tx, ty, s)))
			if t == Consts.T.FLOOR and room.get("rubble", {}).has(ty * Consts.RW + tx):
				rubble.set_cell(cell, 0, TilePick.coords(biome.id, TilePick.rubble_key(tx, ty, s)))
			if t == Consts.T.ROCK or t == Consts.T.CRACK:
				rocks.set_cell(cell, 0, TilePick.coords(biome.id, TilePick.rock_key(tx, ty, s, t == Consts.T.CRACK)))
	decals.queue_redraw()
	shadow.queue_redraw()

# drawDecal and drawTutorialFloor (js/dungeon.js), in room coordinates
func _draw_decals(ci: CanvasItem) -> void:
	if shown.is_empty():
		return
	var biome := DB.biome_of(Run.floor.depth)
	for d in shown.decals:
		var x: float = d.x - Consts.RX
		var y: float = d.y - Consts.RY
		match biome.deco:
			"bones":
				if d.k < 2:
					var c := U.rgba(220, 210, 190, 0.35)
					UiDraw.px_rect(ci, x, y, 5, 1, c)
					UiDraw.px_rect(ci, x - 1, y - 1, 1, 3, c)
					UiDraw.px_rect(ci, x + 5, y - 1, 1, 3, c)
				elif d.k < 4:
					UiDraw.px_rect(ci, x, y, 3, 3, U.rgba(220, 210, 190, 0.35))
					UiDraw.px_rect(ci, x, y + 1, 1, 1, U.rgba(0, 0, 0, 0.5))
					UiDraw.px_rect(ci, x + 2, y + 1, 1, 1, U.rgba(0, 0, 0, 0.5))
				else:
					UiDraw.px_rect(ci, x, y, 6, 3, U.rgba(0, 0, 0, 0.25))
			"shrooms":
				var cols := ["#a33a7a", "#c8443a", "#9fd05a", "#e88fc0"]
				UiDraw.px_rect(ci, x + 1, y + 2, 1, 2, U.rgba(200, 190, 160, 0.5))
				UiDraw.px_rect(ci, x, y + 1, 3, 1, cols[int(d.k) % 4])
				UiDraw.px_rect(ci, x + 1, y, 1, 1, cols[int(d.k) % 4])
				if d.s > 0.6:
					UiDraw.px_rect(ci, x - 3, y + 4, 8, 2, U.rgba(80, 140, 60, 0.3))
			"cracks":
				var c := U.rgba(242, 120, 40, 0.5) if d.k < 2 else U.rgba(0, 0, 0, 0.35)
				UiDraw.px_rect(ci, x, y, 4, 1, c)
				UiDraw.px_rect(ci, x + 3, y + 1, 1, 2, c)
				UiDraw.px_rect(ci, x + 4, y + 3, 3, 1, c)
			"puddles":
				var rx: float = 4 + d.s * 8
				var ry: float = 2 + d.s * 3
				var pts := PackedVector2Array()
				for i in 20:
					var a := TAU * i / 20.0
					pts.append(Vector2(x + cos(a) * rx, y + sin(a) * ry))
				ci.draw_colored_polygon(pts, U.rgba(40, 90, 110, 0.35))
				UiDraw.px_rect(ci, x - 2, y - 1, 3, 1, U.rgba(150, 220, 230, 0.18))
			"veins":
				for i in 6:
					UiDraw.px_rect(ci, x + i * 2, y + U.jround(sin(i + d.s * 6) * 2), 2, 1, U.rgba(160, 70, 180, 0.35))
	if shown.get("tutorial", false):
		var lines := [
			"^dWASD move   -   MOUSE aim   -   LEFT CLICK shoot",
			"^dSPACE dash   -   RIGHT CLICK or F  Flare (uses oil)",
			"^d1 2 3 4 consumables   -   E interact   -   TAB map",
		]
		var ga := UiDraw.alpha
		UiDraw.alpha = 0.55
		for i in lines.size():
			UiDraw.text(ci, lines[i], Consts.RW * Consts.TS / 2.0, 150 + i * 12, {"align": "center", "shadow": false})
		UiDraw.alpha = ga

# wall shadow on the floor (renderRoomBg)
func _draw_wall_shadow(ci: CanvasItem) -> void:
	var ts := Consts.TS
	UiDraw.px_rect(ci, ts, ts, (Consts.RW - 2) * ts, 4, U.rgba(0, 0, 0, 0.35))
	UiDraw.px_rect(ci, ts, ts + 4, (Consts.RW - 2) * ts, 3, U.rgba(0, 0, 0, 0.18))
	UiDraw.px_rect(ci, ts, ts, 3, (Consts.RH - 2) * ts, U.rgba(0, 0, 0, 0.18))
