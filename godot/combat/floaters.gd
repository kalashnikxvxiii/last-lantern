class_name Floaters
extends RefCounted
# Numeri e testi fluttuanti (da Floaters in js/gfx.js).

static var list: Array = []

static func add(x: float, y: float, text: Variant, color: Variant = null, o: Dictionary = {}) -> void:
	if list.size() > 80:
		list.pop_front()
	list.append({"x": x + U.rnd(-3, 3), "y": y, "text": str(text), "color": Txt.COLORS.w if color == null else color,
		"t": 0.0, "life": o.get("life", 0.8), "vy": o.get("vy", -28.0), "scale": o.get("scale", 1.0)})

static func update(dt: float) -> void:
	var i := list.size() - 1
	while i >= 0:
		var f: Dictionary = list[i]
		f.t += dt
		f.y += f.vy * dt
		f.vy *= 1 - 2.5 * dt
		if f.t > f.life:
			list.remove_at(i)
		i -= 1

static func draw(ci: CanvasItem) -> void:
	for f in list:
		var a: float = 1.0 - (f.t - f.life * 0.6) / (f.life * 0.4) if f.t > f.life * 0.6 else 1.0
		UiDraw.text(ci, f.text, f.x, f.y, {"align": "center", "color": f.color, "alpha": a, "scale": f.scale})

static func clear() -> void:
	list.clear()
