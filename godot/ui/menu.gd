class_name Menu
extends RefCounted
# Menu generico (class Menu in js/ui.js): tastiera, mouse, gamepad.
# Voci: {label: String | Callable, value: Callable, adjust: Callable, action: Callable, disabled: bool}

var items: Array
var sel := 0
var rects: Array = []
var o: Dictionary
var last_m := Vector2(-1, -1)

func _init(items_: Array, o_: Dictionary = {}) -> void:
	items = items_
	o = o_

func current() -> Dictionary:
	return items[sel]

func _step(d: int) -> void:
	var n := items.size()
	for k in n:
		sel = (sel + d + n) % n
		if not items[sel].get("disabled", false) or o.get("allowDisabled", false):
			break
	Sfx.play("select")

func update() -> void:
	if Controls.up():
		_step(-1)
	if Controls.down():
		_step(1)
	var it: Variant = items[sel] if sel < items.size() else null
	if it != null and it.has("adjust"):
		if Controls.left():
			it.adjust.call(-1)
			Sfx.play("select")
		if Controls.right():
			it.adjust.call(1)
			Sfx.play("select")
	# mouse
	var m := Controls.mouse_pos()
	var moved := m != last_m
	last_m = m
	for i in rects.size():
		var r: Rect2 = rects[i]
		if r.has_point(m):
			var allowed: bool = not items[i].get("disabled", false) or o.get("allowDisabled", false)
			if moved and sel != i and allowed:
				sel = i
				Sfx.play("select")
			if Controls.mouse_left_pressed():
				if items[i].has("adjust"):
					items[i].adjust.call(1 if m.x > r.position.x + r.size.x / 2 else -1)
					Sfx.play("select")
				elif not items[i].get("disabled", false) and items[i].has("action"):
					Sfx.play("confirm")
					items[i].action.call()
				return
	if Controls.confirm() and it != null and not it.get("disabled", false) and it.has("action"):
		Sfx.play("confirm")
		it.action.call()

static func label_of(it: Dictionary) -> String:
	var label: String = it.label.call() if it.label is Callable else it.label
	if it.has("value"):
		label += "   " + str(it.value.call())
	return label

func draw(ci: CanvasItem, x: float, y: float, oo: Dictionary = {}) -> void:
	var lh: float = oo.get("lineH", 14)
	var align: String = oo.get("align", "center")
	rects = []
	for i in items.size():
		var it: Dictionary = items[i]
		var is_sel := i == sel
		var label := label_of(it)
		var col: Variant = "#55505e" if it.get("disabled", false) else (UiDraw.UI.sel if is_sel else "#c8c0d0")
		var w := Txt.width(label)
		var lx := x - w / 2 if align == "center" else x
		var yy := y + i * lh
		rects.append(Rect2(lx - 14, yy - 3, w + 28, lh))
		if is_sel:
			# piccola fiamma accanto alla voce selezionata
			var fx := lx - 9
			var fy := yy + 4
			var tt := Fx.time
			UiDraw.px_rect(ci, fx, fy - 2, 3, 4, "#f29c38")
			UiDraw.px_rect(ci, fx + 1, fy - 3 - (int(floor(tt * 8)) % 2), 1, 2, "#f6cf57")
			UiDraw.px_rect(ci, fx + 1, fy, 1, 1, "#fff2a8")
			if align == "center":
				UiDraw.px_rect(ci, lx + w + 6, fy - 2, 3, 4, "#f29c38")
				UiDraw.px_rect(ci, lx + w + 7, fy - 3 - (int(floor(tt * 8 + 1)) % 2), 1, 2, "#f6cf57")
		UiDraw.text(ci, label, lx, yy, {"color": col})
