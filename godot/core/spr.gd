class_name Spr
extends RefCounted
# Exported sprites (assets/sprites) and drawing like drawSpr in js/gfx.js.
# White silhouettes for flash and tint are generated at load time.

const DIR := "res://assets/sprites/"
static var db: Dictionary = {}   # name -> {tex, sil, w, h, frames}

static func ensure() -> void:
	if not db.is_empty():
		return
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(DIR + "manifest.json")) != OK:
		push_error("sprite manifest not readable")
		return
	for name in j.data:
		var m: Dictionary = j.data[name]
		var tex: Texture2D = load(DIR + name + ".png")
		db[name] = {"tex": tex, "sil": _silhouette(tex), "w": int(m.w), "h": int(m.h), "frames": int(m.frames)}

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
	var sc: float = o.get("scale", 1.0)
	var w: float = s.w * sc
	var h: float = s.h * sc
	var dx := U.jround(x - w / 2.0)
	var dy := U.jround(y - h / 2.0)
	var a: float = o.get("alpha", 1.0) * UiDraw.alpha
	if a <= 0.0:
		return
	var src := Rect2(f * s.w, 0, s.w, s.h)
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
	_blit(ci, s.sil, Rect2(f * s.w, 0, s.w, s.h), dx, dy, s.w, s.h, flip, Color(k.r, k.g, k.b, k.a * UiDraw.alpha))
