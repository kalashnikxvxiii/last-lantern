class_name Pickups
extends RefCounted
# Raccoglibili (makePickup, randomCons, updatePickups, collectPickup in js/entities.js).

static func make(type: String, x: float, y: float, o: Dictionary = {}) -> Dictionary:
	var a := U.rnd(TAU)
	var s := U.rnd(20, 70)
	return {"type": type, "x": x, "y": y, "vx": cos(a) * s, "vy": sin(a) * s, "z": 0, "vz": 30 if type == "xp" else 70,
		"t": 0, "value": o.value if o.get("value", 0) else 1, "id": o.id if o.get("id") else null, "magnet": false}

static func random_cons() -> String:
	return U.weighted_pick(Cons.ALL.keys(), func(k): return Cons.ALL[k].w)
