class_name WellBg
extends RefCounted
# Well background and screen embers (drawWellBackground, updateEmbers in
# js/game.js) and big lantern (drawBigLantern in js/ui.js).

static var embers: Array = []
static var _bg: GradientTexture2D

static func draw(ci: CanvasItem, t: float, arr: Array) -> void:
	var W := Consts.W
	var H := Consts.H
	if _bg == null:
		var g := Gradient.new()
		g.set_color(0, Color("#0a0710"))
		g.add_point(0.6, Color("#120c18"))
		g.set_color(g.get_point_count() - 1, Color("#1e1018"))
		_bg = GradientTexture2D.new()
		_bg.gradient = g
		_bg.fill_from = Vector2(0, 0)
		_bg.fill_to = Vector2(0, 1)
		_bg.width = 4
		_bg.height = 64
	ci.draw_texture_rect(_bg, Rect2(0, 0, W, H), false)
	# well walls in perspective
	for i in 14:
		var k := fmod(i + t * 0.25, 14.0) / 14.0
		var y := H * (0.05 + k * k * 1.1)
		var inset := 40 + (1 - k) * 120
		var c := Color(70 / 255.0, 50 / 255.0, 80 / 255.0, 0.08 + k * 0.18)
		ci.draw_rect(Rect2(0, y, inset * 0.6, 2 + k * 3), c)
		ci.draw_rect(Rect2(W - inset * 0.6, y, inset * 0.6, 2 + k * 3), c)
	UiDraw.glow(ci, W / 2.0, H * 0.95, 200, "#f29c38", 0.18)
	var ga := UiDraw.alpha
	for e in arr:
		UiDraw.alpha = minf(1, e.life * 2)
		UiDraw.px_rect(ci, e.x, e.y, e.s, e.s, e.c)
	UiDraw.alpha = ga

static func update_embers(arr: Array, dt: float) -> void:
	if arr.size() < 70 and Fx.vis.next() < 0.5:
		arr.append({"x": Fx.vrnd(0, Consts.W), "y": Consts.H + 4.0, "vy": -Fx.vrnd(8, 30), "vx": Fx.vrnd(-6, 6), "life": Fx.vrnd(3, 8),
			"s": 2 if Fx.vis.next() < 0.25 else 1, "c": ["#f29c38", "#f6cf57", "#b5571f", "#6b6478"][int(Fx.vis.next() * 4)]})
	for e in arr:
		e.x += (e.vx + sin(e.y * 0.05) * 6) * dt
		e.y += e.vy * dt
		e.life -= dt
	var i := arr.size() - 1
	while i >= 0:
		if arr[i].life <= 0 or arr[i].y < -5:
			arr.remove_at(i)
		i -= 1

static func big_lantern(ci: CanvasItem, x: float, y: float, glass: Variant, swing: float, s: float = 3.0) -> void:
	ci.draw_set_transform(Vector2(x, y), swing)
	var R := func(a: float, b: float, c: float, d: float, col: Variant) -> void:
		ci.draw_rect(Rect2(a * s, b * s, c * s, d * s), UiDraw._a(col))
	# chain
	for i in 5:
		R.call(-0.5, -16 + i * 2, 1, 1, "#6b6478")
	R.call(-3, -6, 6, 1, "#3b3546")
	R.call(-4, -5, 8, 1, "#6b6478")
	R.call(-5, -4, 10, 1, "#0b0810")
	R.call(-4, -3, 8, 9, "#0b0810")
	R.call(-3, -3, 6, 8, glass)
	R.call(-1, -2, 2, 5, "#ffffff")
	R.call(-4, -3, 1, 9, "#3b3546")
	R.call(3, -3, 1, 9, "#3b3546")
	R.call(-5, 6, 10, 1, "#6b6478")
	R.call(-4, 7, 8, 1, "#3b3546")
	ci.draw_set_transform(Vector2.ZERO)
	UiDraw.glow(ci, x, y + 2 * s, 30 * s, glass, 0.18)
