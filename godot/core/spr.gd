class_name Spr
extends RefCounted
# Exported sprites (assets/sprites) and drawing like drawSpr in js/gfx.js.
# White silhouettes for flash and tint are generated at load time.
# Godot-only: the art may hold k texels per logical pixel (HD art, k = 4); the
# manifest keeps the logical size, so it is drawn in the same rect.

const DIR := "res://assets/sprites/"
static var db: Dictionary = {}   # name -> {tex, sil, w, h, frames, k}
# Godot-only: an Array while the 3D view collects the sprites that stand up
# (draw then records them instead of drawing; o.flat keeps one on the floor)
static var capture: Variant = null

static func ensure() -> void:
	if not db.is_empty():
		return
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(DIR + "manifest.json")) != OK:
		push_error("sprite manifest not readable")
		return
	for name in j.data:
		var m: Dictionary = j.data[name]
		db[name] = entry(load(DIR + name + ".png"), m)

static func entry(tex: Texture2D, m: Dictionary) -> Dictionary:
	var k: int = maxi(1, tex.get_width() / (int(m.w) * int(m.frames)))
	return {"tex": tex, "sil": _silhouette(tex), "w": int(m.w), "h": int(m.h), "frames": int(m.frames), "k": k}

# frame f in the texture, in texels
static func src_rect(s: Dictionary, f: int) -> Rect2:
	return Rect2(f * s.w * s.k, 0, s.w * s.k, s.h * s.k)

static func _silhouette(tex: Texture2D) -> Texture2D:
	var img := tex.get_image()
	if img == null:
		return tex   # dummy rendering (headless test): no silhouette
	img = img.duplicate()
	img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.0:
				img.set_pixel(x, y, Color(1, 1, 1, c.a))
	return ImageTexture.create_from_image(img)

static func has(name: String) -> bool:
	ensure()
	return db.has(name)

static func size(name: String) -> Vector2i:
	ensure()
	var s: Dictionary = db[name]
	return Vector2i(s.w, s.h)

static func frame_count(name: String) -> int:
	ensure()
	return db[name].frames

static var _body_cache: Dictionary = {}   # "name:frame" -> opaque logical texels from the center

# Godot-only: the opaque pixels of a frame as logical offsets from the
# center; the restart light scatters them as ash (Flow._incinerate)
static func body_pixels(name: String, frame: int) -> Array:
	ensure()
	var key := "%s:%d" % [name, frame]
	if _body_cache.has(key):
		return _body_cache[key]
	var out: Array = []
	if db.has(name):
		var s: Dictionary = db[name]
		var f := frame % int(s.frames)
		var img: Image = s.tex.get_image()
		if img != null:
			img.decompress()
			img.convert(Image.FORMAT_RGBA8)
			var x0 := int(f * s.w * s.k)
			for ty in s.h:
				for tx in s.w:
					var c := img.get_pixel(x0 + tx * s.k + s.k / 2, ty * s.k + s.k / 2)
					if c.a > 0.1:
						out.append(Vector2i(tx - s.w / 2, ty - s.h / 2))
	if out.size() > 70:
		var step := int(ceil(float(out.size()) / 70.0))
		var thin: Array = []
		var i := step
		while i < out.size():
			thin.append(out[i])
			i += step
		_body_cache[key] = thin
		return thin
	_body_cache[key] = out
	return out

static func _blit(ci: CanvasItem, tex: Texture2D, src: Rect2, dx: float, dy: float, w: float, h: float, flip: bool, c: Color) -> void:
	if flip:
		ci.draw_set_transform(Vector2(dx + w, dy) + UiDraw.origin, 0.0, Vector2(-1, 1))
		ci.draw_texture_rect_region(tex, Rect2(0, 0, w, h), src, c)
		ci.draw_set_transform(UiDraw.origin)
	else:
		ci.draw_texture_rect_region(tex, Rect2(dx, dy, w, h), src, c)

# centered on (x, y). o: flip, flash, alpha, scale, tint, tintA
static func draw(ci: CanvasItem, name: String, frame: float, x: float, y: float, o: Dictionary = {}) -> void:
	ensure()
	if not db.has(name):
		return
	var s: Dictionary = db[name]
	var f := int(frame) % int(s.frames)
	if capture != null and not o.get("flat", false):
		capture.append({"name": name, "frame": f, "x": x, "y": y, "o": o, "alpha": o.get("alpha", 1.0) * UiDraw.alpha})
		return
	var sc: float = o.get("scale", 1.0)
	var w: float = s.w * sc
	var h: float = s.h * sc
	var dx := U.jround(x - w / 2.0)
	var dy := U.jround(y - h / 2.0)
	var a: float = o.get("alpha", 1.0) * UiDraw.alpha
	if a <= 0.0:
		return
	var src := src_rect(s, f)
	var flip: bool = o.get("flip", false)
	_blit(ci, s.sil if o.get("flash", false) else s.tex, src, dx, dy, w, h, flip, Color(1, 1, 1, a))
	if o.get("tint") != null:
		var t := UiDraw.col(o.tint)
		_blit(ci, s.sil, src, dx, dy, w, h, flip, Color(t.r, t.g, t.b, a * o.get("tintA", 0.5)))

# colored silhouette (JS sprTint), drawn with the top-left corner at (dx, dy)
static func draw_sil(ci: CanvasItem, name: String, frame: float, dx: float, dy: float, color: Variant, flip: bool = false) -> void:
	ensure()
	if not db.has(name):
		return
	var s: Dictionary = db[name]
	var f := int(frame) % int(s.frames)
	var k := UiDraw.col(color)
	_blit(ci, s.sil, src_rect(s, f), dx, dy, s.w, s.h, flip, Color(k.r, k.g, k.b, k.a * UiDraw.alpha))
