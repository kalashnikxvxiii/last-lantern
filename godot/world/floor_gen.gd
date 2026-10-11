class_name FloorGen
extends RefCounted
# Mappa della profondità (genFloor in js/dungeon.js). Stesso seme, stesso piano del JS.

const GW := 9
const GH := 8
const NB := [[1, 0], [-1, 0], [0, 1], [0, -1]]

static func _key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]

static func gen_floor(depth: int, rng: RNG, target: int = 0) -> Dictionary:
	var n_target := target if target > 0 else mini(20, 9 + depth * 2 + rng.rint(0, 2))
	for attempt in 400:
		var cells := {}
		var nb_count := func(x: int, y: int) -> int:
			var a := 0
			for d in NB:
				if cells.has(_key(x + d[0], y + d[1])):
					a += 1
			return a
		var start := {"gx": 4, "gy": 4}
		cells[_key(4, 4)] = start
		var queue: Array = [start]
		while not queue.is_empty() and cells.size() < n_target:
			var c: Dictionary = queue.pop_front()
			var added := false
			for d in rng.shuffle(NB.duplicate(true)):
				if cells.size() >= n_target:
					break
				var nx: int = c.gx + d[0]
				var ny: int = c.gy + d[1]
				if nx < 0 or ny < 0 or nx >= GW or ny >= GH:
					continue
				if cells.has(_key(nx, ny)):
					continue
				if nb_count.call(nx, ny) > 1:
					continue
				if rng.chance(0.5):
					continue
				var n := {"gx": nx, "gy": ny}
				cells[_key(nx, ny)] = n
				queue.append(n)
				added = true
			if not added and queue.is_empty() and cells.size() < n_target:
				# rimetti in coda una stanza casuale per continuare a crescere
				queue.append(rng.pick(cells.values()))
		if cells.size() < n_target:
			continue
		var list: Array = cells.values()
		var nbs := func(c: Dictionary) -> Array:
			var out: Array = []
			for d in [["n", 0, -1], ["s", 0, 1], ["w", -1, 0], ["e", 1, 0]]:
				var n: Variant = cells.get(_key(c.gx + d[1], c.gy + d[2]))
				if n != null:
					out.append([d[0], n])
			return out
		# distanze BFS
		var dist_m := {_key(4, 4): 0}
		var bq: Array = [start]
		while not bq.is_empty():
			var c: Dictionary = bq.pop_front()
			for pair in nbs.call(c):
				var n: Dictionary = pair[1]
				var k := _key(n.gx, n.gy)
				if not dist_m.has(k):
					dist_m[k] = dist_m[_key(c.gx, c.gy)] + 1
					bq.append(n)
		# vicoli ciechi ordinati per distanza decrescente (ordinamento stabile come il JS)
		var dec: Array = []
		for i in list.size():
			var c: Dictionary = list[i]
			if not is_same(c, start) and nbs.call(c).size() == 1:
				dec.append({"c": c, "d": dist_m[_key(c.gx, c.gy)], "i": i})
		dec.sort_custom(func(a, b): return a.d > b.d or (a.d == b.d and a.i < b.i))
		var dead: Array = dec.map(func(x): return x.c)
		var need := 3 + (1 if depth >= 2 else 0)
		if dead.size() < need:
			continue
		if dist_m[_key(dead[0].gx, dead[0].gy)] < 3:
			continue

		# costruisci le stanze
		var rooms := {}
		for c in list:
			rooms[_key(c.gx, c.gy)] = {
				"gx": c.gx, "gy": c.gy, "type": "normal", "dist": dist_m[_key(c.gx, c.gy)], "doors": {}, "seed": rng.rint(1, 2147483647),
				"built": false, "visited": false, "seen": false, "cleared": false, "found": true,
			}
		var R := func(c: Dictionary) -> Dictionary: return rooms[_key(c.gx, c.gy)]
		R.call(start).type = "start"
		R.call(dead[0]).type = "boss"
		var rest: Array = rng.shuffle(dead.slice(1))
		R.call(rest[0]).type = "treasure"
		R.call(rest[0]).locked = depth >= 2
		R.call(rest[1]).type = "shop"
		var i := 2
		if depth >= 2 and i < rest.size():
			R.call(rest[i]).type = "elite"
			i += 1
		if i < rest.size():
			R.call(rest[i]).type = "shrine"
			i += 1
		# stanza segreta: cella vuota con molte stanze adiacenti
		var best: Variant = null
		var best_n := 1
		for gy in GH:
			for gx in GW:
				if cells.has(_key(gx, gy)):
					continue
				var adj: Array = []
				for d in NB:
					var r: Variant = rooms.get(_key(gx + d[0], gy + d[1]))
					if r != null:
						adj.append(r)
				if adj.any(func(r): return r.type == "boss" or r.type == "start"):
					continue
				if adj.size() > best_n or (adj.size() == best_n and best != null and rng.chance(0.4)):
					best = {"gx": gx, "gy": gy}
					best_n = adj.size()
		if best != null:
			rooms[_key(best.gx, best.gy)] = {
				"gx": best.gx, "gy": best.gy, "type": "secret", "dist": 99, "doors": {}, "seed": rng.rint(1, 2147483647),
				"built": false, "visited": false, "seen": false, "cleared": true, "found": false,
			}
		# collega le porte
		for r in rooms.values():
			for d in RoomU.DIRS:
				var n: Variant = rooms.get(_key(r.gx + RoomU.DIRS[d].dx, r.gy + RoomU.DIRS[d].dy))
				if n != null:
					r.doors[d] = n
		var start_room: Dictionary = R.call(start)
		for r in rooms.values():
			if r.type in ["start", "treasure", "shop", "shrine", "secret"]:
				r.cleared = true
		return {"depth": depth, "rooms": rooms.values(), "map": rooms, "start": start_room}
	return gen_floor(depth, rng, n_target - 1)
