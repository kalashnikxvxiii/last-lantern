class_name Notices
extends RefCounted
# Toasts and banners (drawNotices in js/ui.js).

static func draw(ci: CanvasItem) -> void:
	var W := Consts.W
	var ga := UiDraw.alpha
	var y := 36.0
	for t in Run.toasts:
		var a: float = t.t / 0.2 if t.t < 0.2 else ((t.life - t.t) / 0.5 if t.t > t.life - 0.5 else 1.0)
		var w := UiDraw.panel_width(t.text, t.sub, 16.0)
		UiDraw.alpha = ga * a
		var h := 26 if t.sub != "" else 15
		UiDraw.panel(ci, W / 2.0 - w / 2, y, w, h, {"alpha": 0.88})
		UiDraw.text(ci, t.text, W / 2.0, y + 4, {"align": "center", "color": t.col})
		if t.sub != "":
			UiDraw.text(ci, t.sub, W / 2.0, y + 15, {"align": "center", "color": "#a8a0b0"})
		UiDraw.alpha = ga
		y += h + 3
	if not Run.banners.is_empty():
		var b: Dictionary = Run.banners[0]
		var a: float = b.t / 0.25 if b.t < 0.25 else ((b.life - b.t) / 0.5 if b.t > b.life - 0.5 else 1.0)
		var w := 240.0
		var lines := Txt.wrap(b.desc, w - 40)
		var h := 26 + lines.size() * 10
		var x := W / 2.0 - w / 2
		var y0 := Consts.H - 40.0 - h
		UiDraw.alpha = ga * a
		UiDraw.panel(ci, x, y0, w, h, {"hi": b.col})
		if b.icon != "":
			UiDraw.px_rect(ci, x + 8, y0 + 8, 18, 18, "#0b0810")
			Spr.draw(ci, b.icon, 0, x + 17, y0 + 17)
		UiDraw.text(ci, b.title, x + 32, y0 + 7, {"color": b.col})
		for i in lines.size():
			UiDraw.text(ci, lines[i], x + 32, y0 + 19 + i * 10, {"color": "#d8d0c0"})
		UiDraw.alpha = ga
