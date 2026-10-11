class_name Lights
extends RefCounted
# Sorgenti di luce della stanza (collectLights in js/render.js).

static func collect() -> Array:
	var p := Run.player
	var room := Run.room
	var L: Array = []
	var t := Fx.time
	var fl := 1 + sin(t * 13) * 0.015 + sin(t * 7.3) * 0.012
	if not p.dead:
		L.append({"x": p.x, "y": p.y - 2, "r": p.light() * fl, "a": 1.0, "col": "#f2a040", "ga": 0.10})
	for i in mini(Run.bullets.size(), 40):
		var b: Dictionary = Run.bullets[i]
		L.append({"x": b.x, "y": b.y, "r": 30.0 if b.kind == "comet" else 16.0, "a": 0.7, "col": null})
	for ty in range(1, Consts.RH - 1):
		for tx in range(1, Consts.RW - 1):
			if room.grid[ty][tx] == Consts.T.BRAZIER:
				var c := RoomU.tile_center(tx, ty)
				L.append({"x": c.x, "y": c.y - 4, "r": 72 * (1 + sin(t * 9 + tx) * 0.04), "a": 0.95, "col": "#f29c38", "ga": 0.12})
	for f in Run.fx:
		match f.type:
			"fire":
				L.append({"x": f.x, "y": f.y, "r": 24.0, "a": 0.6, "col": "#f29c38", "ga": 0.08})
			"explosion":
				if f.t < 0.3:
					L.append({"x": f.x, "y": f.y, "r": f.r * 2.5, "a": 1.0, "col": "#f6cf57", "ga": 0.25})
			"bomb":
				L.append({"x": f.x, "y": f.y, "r": 14.0, "a": 0.5, "col": null})
	for o in room.objects:
		if o.get("gone", false):
			continue
		match o.type:
			"relic", "shopitem":
				L.append({"x": o.x, "y": o.y - 8, "r": 34.0, "a": 0.7, "col": null})
			"merchant":
				L.append({"x": o.x + 9, "y": o.y, "r": 80.0, "a": 0.9, "col": "#f6cf57", "ga": 0.08})
			"trapdoor":
				L.append({"x": o.x, "y": o.y, "r": 50.0, "a": 0.8, "col": "#c57ae0", "ga": 0.1})
			"shrine":
				if o.uses > 0:
					L.append({"x": o.x, "y": o.y - 8, "r": 60.0, "a": 0.8, "col": "#d04b3c" if o.kind == "pact" or o.kind == "blood" else "#7fd8e6", "ga": 0.08})
			"chest":
				if not o.get("open", false):
					L.append({"x": o.x, "y": o.y, "r": 22.0, "a": 0.5, "col": null})
	for e in Run.enemies:
		if e.boss:
			L.append({"x": e.x, "y": e.y, "r": 70.0, "a": 0.55, "col": "#c57ae0", "ga": 0.06})
		elif e.type == "spark" or e.type == "slag":
			L.append({"x": e.x, "y": e.y, "r": 26.0, "a": 0.7, "col": "#f29c38", "ga": 0.1})
	for b in Run.ebullets:
		if L.size() < 120:
			L.append({"x": b.x, "y": b.y, "r": 12.0, "a": 0.45, "col": null})
	for k in room.pickups:
		if k.type == "coin" or k.type == "coin5" or k.type == "cons":
			L.append({"x": k.x, "y": k.y, "r": 10.0, "a": 0.4, "col": null})
	var flh: Variant = Run.flash_light
	if flh != null and flh.t > 0:
		L.append({"x": flh.x, "y": flh.y, "r": flh.get("r", 150.0) * flh.t * 2, "a": 1.0, "col": "#fff2a8", "ga": 0.2 * flh.t})
	return L
