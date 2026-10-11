class_name UiDraw
extends RefCounted
# Primitive pixel, pannelli e testo (da js/gfx.js e js/font.js).
# UiDraw.alpha fa da ctx.globalAlpha: moltiplica l'alfa di tutto ciò che si disegna.

static var alpha := 1.0
static var origin := Vector2.ZERO   # trasformazione di base del nodo che sta disegnando
static var _colors: Dictionary = {}
static var _glow_tex: Texture2D

# Gli attori stanno in position = (x, y) per l'ordinamento in Y, ma disegnano in
# coordinate del mondo come il JS: set_origin(self, -position) all'inizio di _draw()
# e set_origin(self, Vector2.ZERO) alla fine.
static func set_origin(ci: CanvasItem, o: Vector2) -> void:
	origin = o
	ci.draw_set_transform(o)

static var UI := {   # UI_COL del JS
	"bg": Color("#16111c"), "bg2": Color("#1f1826"), "edge": Color("#0a070d"), "brass": Color("#9a7a44"),
	"brassL": Color("#d8b46a"), "brassD": Color("#5a4428"), "ink": Color("#ece6d8"), "dim": Color("#8a8294"), "sel": Color("#f6cf57"),
}

static func col(c: Variant) -> Color:
	if c is Color:
		return c
	if not _colors.has(c):
		_colors[c] = Color(c)
	return _colors[c]

static func _a(c: Variant) -> Color:
	var k := col(c)
	return Color(k.r, k.g, k.b, k.a * alpha)

static func px_rect(ci: CanvasItem, x: float, y: float, w: float, h: float, c: Variant) -> void:
	var rw := U.jround(w)
	var rh := U.jround(h)
	if rw == 0 or rh == 0:
		return
	ci.draw_rect(Rect2(U.jround(x), U.jround(y), rw, rh).abs(), _a(c))

static func px_circle(ci: CanvasItem, cx: float, cy: float, r: float, c: Variant) -> void:
	var k := _a(c)
	cx = U.jround(cx)
	cy = U.jround(cy)
	r = maxf(0.5, r)
	var ri := int(ceil(r))
	for yy in range(-ri, ri + 1):
		var hw := floorf(sqrt(maxf(0.0, r * r - yy * yy)))
		if hw <= 0 and absf(yy) >= r:
			continue
		ci.draw_rect(Rect2(cx - hw, cy + yy, hw * 2 + 1, 1), k)

static func px_ring(ci: CanvasItem, cx: float, cy: float, r: float, c: Variant, thick: float = 1.0) -> void:
	var rr := maxf(0.5, r)
	ci.draw_arc(Vector2(U.jround(cx) + 0.5, U.jround(cy) + 0.5), rr, 0.0, TAU, maxi(12, int(rr * 1.5)), _a(c), thick)

static func shadow(ci: CanvasItem, x: float, y: float, w: float) -> void:
	var ry := maxf(1.5, w * 0.38)
	var cx := U.jround(x)
	var cy := U.jround(y)
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(Vector2(cx + cos(a) * w, cy + sin(a) * ry))
	ci.draw_colored_polygon(pts, _a(U.rgba(5, 3, 8, 0.45)))

# alone luminoso; nel JS è additivo ('lighter'), qui è una sfumatura normale:
# sugli sfondi scuri del gioco la differenza è minima
static func glow(ci: CanvasItem, x: float, y: float, r: float, color: Variant, a: float = 0.35) -> void:
	if _glow_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_glow_tex = t
	var k := col(color)
	ci.draw_texture_rect(_glow_tex, Rect2(x - r, y - r, r * 2, r * 2), false, Color(k.r, k.g, k.b, a * alpha))

# pannello "fatto a mano": legno scuro con rifiniture in ottone (panel in js/gfx.js)
static func panel(ci: CanvasItem, x: float, y: float, w: float, h: float, o: Dictionary = {}) -> void:
	x = U.jround(x)
	y = U.jround(y)
	w = U.jround(w)
	h = U.jround(h)
	var ga := alpha
	var a: float = o.get("alpha", 0.94) * ga
	alpha = a
	px_rect(ci, x + 2, y + 2, w, h, U.rgba(0, 0, 0, 0.45))
	px_rect(ci, x, y, w, h, UI.edge)
	px_rect(ci, x + 1, y + 1, w - 2, h - 2, o.get("border", UI.brassD))
	px_rect(ci, x + 2, y + 2, w - 4, h - 4, o.get("bg", UI.bg))
	# venature del "legno"
	alpha = a * 0.25
	var yy := y + 5
	while yy < y + h - 4:
		px_rect(ci, x + 3, yy, w - 6, 1, UI.bg2)
		yy += 6
	alpha = a
	# filo d'ottone
	px_rect(ci, x + 2, y + 2, w - 4, 1, o.get("hi", UI.brass))
	px_rect(ci, x + 2, y + h - 3, w - 4, 1, UI.brassD)
	# borchie agli angoli
	var st: Variant = o.get("hi", UI.brassL)
	for c in [[x + 3, y + 3], [x + w - 5, y + 3], [x + 3, y + h - 5], [x + w - 5, y + h - 5]]:
		px_rect(ci, c[0], c[1], 2, 2, st)
		px_rect(ci, c[0] + 1, c[1] + 1, 1, 1, UI.brassD)
	alpha = ga

# tasto disegnato come un piccolo tasto meccanico
static func keycap(ci: CanvasItem, x: float, y: float, label: String, o: Dictionary = {}) -> float:
	var w := maxf(9, Txt.width(label) + 5)
	x = U.jround(x)
	y = U.jround(y)
	var pressed: bool = o.get("pressed", false)
	px_rect(ci, x, y + 1, w, 10, "#0a070d")
	px_rect(ci, x, y, w, 9, "#5a4428" if pressed else "#3a3044")
	px_rect(ci, x + 1, y + 1, w - 2, 6, "#9a7a44" if pressed else "#5c5068")
	text(ci, label, x + floor(w / 2), y + 1, {"align": "center", "color": "#f2ead8", "shadow": false})
	return w

static func bar(ci: CanvasItem, x: float, y: float, w: float, h: float, frac: float, c: Variant, bg: Variant = "#120d16", hi: Variant = null) -> void:
	frac = clampf(frac, 0, 1)
	px_rect(ci, x - 1, y - 1, w + 2, h + 2, "#0a070d")
	px_rect(ci, x, y, w, h, bg)
	if frac > 0:
		px_rect(ci, x, y, maxf(1, U.jround(w * frac)), h, c)
		px_rect(ci, x, y, maxf(1, U.jround(w * frac)), 1, U.rgba(255, 255, 255, 0.25) if hi == null else hi)

# fiammella (drawFlame in js/render.js); t è il tempo in secondi
static func flame(ci: CanvasItem, x: float, y: float, s: float, t: float) -> void:
	var tt := t * 10 + x
	for i in 6:
		var h := (3 + sin(tt + i * 1.7) * 2 + (i % 3)) * s
		var ox := (i - 2.5) * 1.5 * s
		px_rect(ci, x + ox, y - h, 1.5 * s, h, "#f29c38" if i % 2 else "#d04b3c")
	px_rect(ci, x - 2 * s, y - 3 * s, 4 * s, 3 * s, "#f6cf57")
	px_rect(ci, x - 1 * s, y - 2 * s, 2 * s, 2 * s, "#fff2a8")

# testo con codici colore ^x (Font.draw in js/font.js)
# o: color, align (left, center, right), shadow, shadowColor, scale, alpha
static func text(ci: CanvasItem, s: Variant, x: float, y: float, o: Dictionary = {}) -> float:
	var str_ := str(s)
	var scale: float = o.get("scale", 1.0)
	var align: String = o.get("align", "left")
	var base := col(o.get("color", Txt.COLORS.w))
	var w := Txt.width(str_, scale)
	var cx := U.jround(x)
	if align == "center":
		cx = U.jround(x - w / 2.0)
	elif align == "right":
		cx = U.jround(x - w)
	y = U.jround(y)
	var ga := alpha
	if o.has("alpha"):
		alpha *= o.alpha
	if o.get("shadow", true) != false:
		_run(ci, str_, cx + scale, y + scale, scale, col(o.get("shadowColor", U.rgba(8, 5, 12, 0.85))), true, base)
	_run(ci, str_, cx, y, scale, base, false, base)
	alpha = ga
	return w

static func _run(ci: CanvasItem, s: String, x: float, y: float, scale: float, color: Color, fixed: bool, base: Color) -> void:
	var tex := Txt.atlas()
	var cur := color
	var i := 0
	while i < s.length():
		var ch := s[i]
		if ch == "^":
			var code := s[i + 1] if i + 1 < s.length() else ""
			i += 2
			if not fixed:
				cur = base if code == "w" else Txt.COLORS.get(code, base)
			continue
		if ch == " ":
			x += 4 * scale
			i += 1
			continue
		var g: Array = Txt.glyph(ch)
		ci.draw_texture_rect_region(tex, Rect2(x, y, g[1] * scale, 8 * scale), Rect2(g[0], 0, g[1], 8), _a(cur))
		x += (g[1] + 1) * scale
		i += 1

static func text_wrapped(ci: CanvasItem, s: Variant, x: float, y: float, max_w: float, o: Dictionary = {}) -> float:
	var scale: float = o.get("scale", 1.0)
	var lines := Txt.wrap(str(s), max_w, scale)
	var lh: float = o.get("lineH", Txt.LINE * scale)
	for i in lines.size():
		text(ci, lines[i], x, y + i * lh, o)
	return lines.size() * lh
