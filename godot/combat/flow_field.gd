class_name FlowField
extends RefCounted
# Campo di flusso verso il giocatore (inseguimento attorno agli ostacoli).

static func update() -> void:
	var rw := Consts.RW
	var rh := Consts.RH
	if Run.flow.size() != rw * rh:
		Run.flow.resize(rw * rh)
	Run.flow.fill(-1)
	var room := Run.room
	var pt := RoomU.world_to_tile(Run.player.x, Run.player.y)
	if pt.x < 0 or pt.y < 0 or pt.x >= rw or pt.y >= rh:
		return
	var q: Array[int] = [pt.y * rw + pt.x]
	Run.flow[pt.y * rw + pt.x] = 0
	var h := 0
	while h < q.size():
		var k := q[h]
		h += 1
		var x := k % rw
		var y := k / rw
		for dd in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
			var nx: int = x + dd[0]
			var ny: int = y + dd[1]
			if nx < 1 or ny < 1 or nx >= rw - 1 or ny >= rh - 1:
				continue
			var nk := ny * rw + nx
			if Run.flow[nk] >= 0:
				continue
			if RoomU.is_solid_tile(room, nx, ny, false):
				continue
			Run.flow[nk] = Run.flow[k] + 1
			q.append(nk)

# cella del campo; null fuori dai limiti (undefined nel JS: ogni confronto è falso)
static func _at(i: int) -> Variant:
	if i < 0 or i >= Run.flow.size():
		return null
	return Run.flow[i]

static func angle(e, tx: float, ty: float) -> float:
	var rw := Consts.RW
	var p = Run.player
	if Run.flow.is_empty() or U.dist(e.x, e.y, tx, ty) < 26 or tx != p.x:
		return U.ang_to(e.x, e.y, tx, ty)
	var ct := RoomU.world_to_tile(e.x, e.y)
	var cur: Variant = _at(ct.y * rw + ct.x)
	if cur != null and cur <= 0:
		return U.ang_to(e.x, e.y, tx, ty)
	if cur != null and cur <= 2 and Coll.line_clear(e.x, e.y, tx, ty):
		return U.ang_to(e.x, e.y, tx, ty)
	var best: Variant = cur
	var bx := ct.x
	var by := ct.y
	for d in [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [1, -1], [-1, 1], [-1, -1]]:
		var nx: int = ct.x + d[0]
		var ny: int = ct.y + d[1]
		var v: Variant = _at(ny * rw + nx)
		if v == null or v < 0:
			continue
		if d[0] != 0 and d[1] != 0:
			var a: Variant = _at(ct.y * rw + nx)
			var b: Variant = _at(ny * rw + ct.x)
			if (a != null and a < 0) or (b != null and b < 0):
				continue
		if best != null and v < best:
			best = v
			bx = nx
			by = ny
	var c := RoomU.tile_center(bx, by)
	return U.ang_to(e.x, e.y, c.x, c.y)
