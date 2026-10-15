class_name Menu
extends RefCounted
# Generic menu (class Menu in js/ui.js): keyboard, mouse, gamepad.
# Entries: {label: String | Callable, value: Callable, adjust: Callable, action: Callable, disabled: bool | Callable}
# Godot-only: click(entry, mouse) replaces the default click, the draw option "drawValue"
# draws the values (the options widgets).
# Godot-only: a list longer than the "rows" drawn scrolls with the cursor and the wheel.

var items: Array
var sel := 0
var rects: Array = []
var o: Dictionary
var hover := -1          # entry under the mouse, -1 when it is off them
var show_cursor := true  # the options tab row hides the entry cursor
var lit_prev := true     # an entry was lit on the previous tick
var top := 0             # first entry drawn
var rows := 0            # entries drawn, 0 = all

func _init(items_: Array, o_: Dictionary = {}) -> void:
	items = items_
	o = o_

func current() -> Dictionary:
	return items[sel]

func _step(d: int) -> void:
	var n := items.size()
	for k in n:
		sel = (sel + d + n) % n
		if not is_disabled(items[sel]) or o.get("allowDisabled", false):
			break
	Sfx.play("select")

func update() -> void:
	var m := Controls.mouse_pos()
	var mouse := Controls.device() == "mouse"
	# the entry under the mouse, if any
	hover = -1
	for i in rects.size():
		if (rects[i] as Rect2).has_point(m):
			hover = i
			break
	# hovering moves the cursor: with the mouse the flame only lights what it is over
	if mouse and hover >= 0 and sel != hover and (not is_disabled(items[hover]) or o.get("allowDisabled", false)):
		sel = hover
		Sfx.play("select")
	if mouse and rows > 0 and Controls.wheel() != 0:
		top = clampi(top + Controls.wheel(), 0, maxi(0, items.size() - rows))
		sel = clampi(sel, top, top + rows - 1)
	if Controls.up():
		_step(-1)
	if Controls.down():
		_step(1)
	var it: Variant = items[sel] if sel >= 0 and sel < items.size() else null
	if it != null and it.has("adjust") and not is_disabled(it):
		if Controls.left():
			it.adjust.call(-1)
			Sfx.play("select")
		if Controls.right():
			it.adjust.call(1)
			Sfx.play("select")
	# click: only on the entry under the mouse
	if mouse and hover >= 0 and Controls.mouse_left_pressed():
		var hit: Dictionary = items[hover]
		var r: Rect2 = rects[hover]
		if hit.has("click"):
			if not is_disabled(hit):
				hit.click.call(hit, m)
		elif hit.has("adjust") and not is_disabled(hit):
			hit.adjust.call(1 if m.x > r.position.x + r.size.x / 2 else -1)
			Sfx.play("select")
		elif not is_disabled(hit) and hit.has("action"):
			Sfx.play("confirm")
			hit.action.call()
		lit_prev = true
		return
	if Controls.confirm():
		# with the mouse off every entry nothing is lit: confirm brings the cursor
		# back to the first entry instead of pressing the hidden one
		if not lit_prev:
			sel = 0
			Sfx.play("select")
		elif it != null and not is_disabled(it) and it.has("action"):
			Sfx.play("confirm")
			it.action.call()
	lit_prev = (hover >= 0) if mouse else true

# Godot-only: "disabled" can be a Callable, for entries that depend on other settings
static func is_disabled(it: Dictionary) -> bool:
	var d: Variant = it.get("disabled", false)
	return d.call() if d is Callable else d

static func name_of(it: Dictionary) -> String:
	return Loc.t(it.label.call() if it.label is Callable else it.label)

static func label_of(it: Dictionary) -> String:
	var label := name_of(it)
	if it.has("value"):
		label += "   " + Loc.t(str(it.value.call()))
	return label

func draw(ci: CanvasItem, x: float, y: float, oo: Dictionary = {}) -> void:
	var lh: float = oo.get("lineH", 14)
	var align: String = oo.get("align", "center")
	var value_x: float = oo.get("valueX", -1.0)   # right edge of a value column, -1 = after the label
	var mouse := Controls.device() == "mouse"
	rows = oo.get("rows", 0)
	var n := rows if rows > 0 else items.size()
	top = clampi(clampi(top, sel - n + 1, sel), 0, maxi(0, items.size() - n))
	rects = []
	for i in items.size():
		if i < top or i >= top + n:
			rects.append(Rect2())   # off the list: the mouse cannot hit it
			continue
		var it: Dictionary = items[i]
		var is_sel := show_cursor and (i == hover if mouse else i == sel)
		var split := value_x >= 0 and it.has("value")
		var label := name_of(it) if split else label_of(it)
		var col: Variant = "#55505e" if is_disabled(it) else (UiDraw.UI.sel if is_sel else "#c8c0d0")
		var w := Txt.width(label)
		var lx := x - w / 2 if align == "center" else x
		var yy := y + (i - top) * lh
		rects.append(Rect2(lx - 14, yy - 3, (value_x - lx if value_x >= 0 else w) + 28, lh))
		if split and oo.has("drawValue"):
			oo.drawValue.call(ci, it, value_x, yy, col)
		elif split:
			UiDraw.text(ci, str(it.value.call()), value_x, yy, {"align": "right", "color": col})
		if is_sel:
			# small flame next to the selected entry
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
	# more entries above or below
	if top > 0:
		_caret(ci, x + 2, y - 6, -1)
	if top + n < items.size():
		_caret(ci, x + 2, y + n * lh - 1, 1)

static func _caret(ci: CanvasItem, x: float, y: float, d: int) -> void:
	for k in 3:
		UiDraw.px_rect(ci, x - k, y + (2 - k if d > 0 else k), k * 2 + 1, 1, UiDraw.UI.brass)
