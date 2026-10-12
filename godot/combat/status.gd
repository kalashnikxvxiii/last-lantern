class_name Status
extends RefCounted
# Status effects (addStatus, updateStatuses, cleanse in js/entities.js).

static func cleanse(a) -> void:
	for k in a.statuses.keys():
		if Statuses.ALL.has(k) and Statuses.ALL[k].bad:
			a.statuses.erase(k)

static func add(a, name: String, dur: float, power: float = 0.0) -> void:
	var is_p: bool = Run.active and a == Run.player
	if is_p and Statuses.ALL.has(name) and Statuses.ALL[name].bad and (a.statuses.has("immune") or a.stats.immune.get(name, 0)):
		return
	if not is_p and a.boss and name == "chill":
		dur *= 0.5
	var s: Variant = a.statuses.get(name)
	if s == null:
		s = {"t": 0.0, "stacks": 0, "tick": 0.0, "power": 0.0}
		a.statuses[name] = s
	s.t = maxf(s.t, dur)
	s.power = maxf(s.power, power)
	if name == "poison":
		s.stacks = mini(3 if is_p else 5, s.stacks + 1)
	elif name == "chill":
		s.stacks += 1
		if not is_p and s.stacks >= 3 and not (a.freeze_cd > 0):
			if not a.boss:
				a.frozen = 1.6
			else:
				a.frozen = 0.5
				a.freeze_cd = 6.0
			a.statuses.erase("chill")
			Sfx.play("freeze")
			Particles.burst(a.x, a.y, 10, ["#c8f2f5", "#7fd8e6"], 40, 0.5)
	else:
		s.stacks = 1

static func update(a, dt: float, is_p: bool) -> void:
	for k in a.statuses.keys():
		if not a.statuses.has(k):
			continue
		var s: Dictionary = a.statuses[k]
		s.t -= dt
		if k == "burn" or k == "poison":
			s.tick += dt
			if s.tick >= 0.5:
				s.tick -= 0.5
				if is_p:
					var v: float = (2.0 if k == "burn" else 0.8 * s.stacks) * (1 + 0.15 * (Run.depth - 1))
					Combat.hurt_player(v, "The flames" if k == "burn" else "The poison", {"dot": true})
				elif not a.dead:
					var v: float = s.power * 0.5 * (s.stacks if k == "poison" else 1)
					Combat.hit_enemy(a, v, {"dot": k})
					if k == "burn":
						Particles.add({"x": a.x + U.rnd(-3, 3), "y": a.y - 4, "vy": -30.0, "life": 0.4, "color": U.pick(["#f29c38", "#f6cf57"])})
		if s.t <= 0:
			a.statuses.erase(k)
