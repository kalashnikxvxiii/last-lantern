class_name Particles
extends RefCounted
# Particles (from Particles in js/gfx.js).

static var list: Array = []

static func add(p: Dictionary) -> Dictionary:
	if list.size() > 900:
		list.pop_front()
	p.t = 0.0
	if p.get("life", 0.0) == 0.0:
		p.life = 0.5
	if p.get("size", 0.0) == 0.0:
		p.size = 1.0
	p.vx = p.get("vx", 0.0)
	p.vy = p.get("vy", 0.0)
	if p.get("drag") == null:
		p.drag = 2.0
	list.append(p)
	return p

static func burst(x: float, y: float, n: int, color: Variant, spd: float = 60.0, life: float = 0.5, o: Dictionary = {}) -> void:
	var spread: float = o.spread if o.get("spread", 0.0) != 0.0 else 0.6
	for i in n:
		var a: float = o.angle + U.rnd(-spread, spread) if o.has("angle") else U.rnd(TAU)
		var s := U.rnd(spd * 0.3, spd)
		add({
			"x": x, "y": y, "vx": cos(a) * s, "vy": sin(a) * s, "life": U.rnd(life * 0.6, life),
			"color": U.pick(color) if color is Array else color,
			"size": o.size if o.get("size", 0.0) != 0.0 else (2.0 if U.chance(0.3) else 1.0),
			"grav": o.get("grav", 0.0), "drag": o.get("drag"), "glow": o.get("glow", false),
			"shrink": o.get("shrink", true) != false, "above": o.get("above", false),
		})

static func update(dt: float) -> void:
	var i := list.size() - 1
	while i >= 0:
		var p: Dictionary = list[i]
		p.t += dt
		if p.t >= p.life:
			list.remove_at(i)
		else:
			p.vx -= p.vx * p.drag * dt
			p.vy -= p.vy * p.drag * dt
			p.vy += p.get("grav", 0.0) * dt
			p.x += p.vx * dt
			p.y += p.vy * dt
		i -= 1

static func draw(ci: CanvasItem, above: bool) -> void:
	var ga := UiDraw.alpha
	for p in list:
		if p.get("above", false) != above:
			continue
		var k: float = 1.0 - p.t / p.life
		var s: float = maxf(1.0, U.jround(p.size * (0.4 + k * 0.6))) if p.get("shrink", false) else p.size
		UiDraw.alpha = ga * (1.0 if p.get("fade", true) == false else minf(1.0, k * 1.6))
		UiDraw.px_rect(ci, p.x - s / 2.0, p.y - s / 2.0, s, s, p.color)
	UiDraw.alpha = ga

static func clear() -> void:
	list.clear()
