class_name RoomView
extends Node2D
# Room background (renderRoomBg in js/dungeon.js): TileMapLayer for the floor;
# walls, rocks, decorations, tutorial text and wall shadow drawn by code.
# Godot-only fake height: the tops of walls and rocks lean away from an eye that
# follows the camera, and darker copies below them fill the side faces.

const LIFT := 0.016                    # pixels of lean per pixel of distance from the eye
const EYE_RANGE := Vector2(108, 52)    # how far the eye moves when the camera leans fully
const SIDE := Color(0.5, 0.47, 0.56)

class DrawCall extends Node2D:
	var fn: Callable
	func _draw() -> void:
		fn.call(self)

var floor_layer := TileMapLayer.new()
var decals := DrawCall.new()
var walls := DrawCall.new()
var shadow := DrawCall.new()
var rocks := DrawCall.new()
var shown: Dictionary = {}
var tex: Texture2D
var wall_cells: Array = []   # [x, y, region, raised, fill] in room coordinates
var rock_cells: Array = []
var drawn_cam := Vector2.INF

func _ready() -> void:
	position = Vector2(Consts.RX, Consts.RY)
	decals.fn = _draw_decals
	shadow.fn = _draw_wall_shadow
	walls.fn = func(ci: CanvasItem) -> void: _draw_raised(ci, wall_cells)
	rocks.fn = func(ci: CanvasItem) -> void: _draw_raised(ci, rock_cells)
	for n in [floor_layer, decals, walls, shadow, rocks]:
		add_child(n)

func _process(_delta: float) -> void:
	if not Run.active or Run.room.is_empty():
		return
	if not is_same(Run.room, shown) or Run.room.get("bgDirty", false):
		show_room(Run.room)
	if Fx.cam_px() != drawn_cam:
		drawn_cam = Fx.cam_px()
		walls.queue_redraw()
		rocks.queue_redraw()

func show_room(room: Dictionary) -> void:
	shown = room
	var biome := DB.biome_of(Run.floor.depth)
	var ts := TilePick.tileset(biome.id)
	var src := ts.get_source(0) as TileSetAtlasSource
	tex = src.texture
	floor_layer.tile_set = ts
	floor_layer.clear()
	wall_cells.clear()
	rock_cells.clear()
	var s: int = room.seed % 1000
	for ty in Consts.RH:
		for tx in Consts.RW:
			var cell := Vector2i(tx, ty)
			var t: int = room.grid[ty][tx]
			var x := tx * Consts.TS
			var y := ty * Consts.TS
			if t == Consts.T.WALL or t == Consts.T.DOOR:
				# doors stay flat: the door drawn above them sits on the floor
				# the tops of a wall row spread apart: fill copies along the row close the seams
				var xe := tx == 0 or tx == Consts.RW - 1
				var ye := ty == 0 or ty == Consts.RH - 1
				var fill := Vector2.ZERO if xe and ye else (Vector2(1, 0) if ye else Vector2(0, 1))
				wall_cells.append([x, y, src.get_tile_texture_region(TilePick.coords(biome.id, TilePick.wall_key(tx, ty, s))), t == Consts.T.WALL, fill])
			else:
				floor_layer.set_cell(cell, 0, TilePick.coords(biome.id, TilePick.floor_key(tx, ty, s)))
			if t == Consts.T.ROCK or t == Consts.T.CRACK:
				rock_cells.append([x, y, src.get_tile_texture_region(TilePick.coords(biome.id, TilePick.rock_key(tx, ty, s, t == Consts.T.CRACK))), true, Vector2.ZERO])
	room.bgDirty = false
	decals.queue_redraw()
	walls.queue_redraw()
	shadow.queue_redraw()
	rocks.queue_redraw()

# how far the top of a tile centered at sx, sy on screen leans, in whole pixels
static func lift(sx: float, sy: float, eye: Vector2) -> Vector2:
	return Vector2(U.jround((sx - eye.x) * LIFT), U.jround((sy - eye.y) * LIFT))

# all the side faces first, then all the tops, so no side covers a neighbouring top
func _draw_raised(ci: CanvasItem, cells: Array) -> void:
	var cam := Fx.cam_px()
	var eye: Vector2 = Fx.VIEW_C - Fx.cam / Fx.CAM_MAX * EYE_RANGE
	var half := Consts.TS / 2.0
	var lifts: Array = []
	for c in cells:
		var l := lift(c[0] + Consts.RX + half + cam.x, c[1] + Consts.RY + half + cam.y, eye) if c[3] else Vector2.ZERO
		lifts.append(l)
		var n := int(maxf(absf(l.x), absf(l.y)))
		for i in n:
			var k := float(i) / n
			ci.draw_texture_rect_region(tex, Rect2(c[0] + U.jround(l.x * k), c[1] + U.jround(l.y * k), Consts.TS, Consts.TS), c[2], SIDE)
	for i in cells.size():
		var c: Array = cells[i]
		if c[3] and c[4] != Vector2.ZERO:
			ci.draw_texture_rect_region(tex, Rect2(c[0] + lifts[i].x + c[4].x, c[1] + lifts[i].y + c[4].y, Consts.TS, Consts.TS), c[2])
	for i in cells.size():
		var c: Array = cells[i]
		ci.draw_texture_rect_region(tex, Rect2(c[0] + lifts[i].x, c[1] + lifts[i].y, Consts.TS, Consts.TS), c[2])

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
