class_name ControlsDraw
extends RefCounted
# Godot-only: the keyboard and gamepad pictures of the Controls options.
# elements() lays out keys and buttons as {r: Rect2, code, fixed, shape, label}:
# code is the physical key or gamepad button (-1 for none), fixed the action that
# cannot be rebound (mouse buttons, sticks, triggers). The options use the same
# list to light the selected action and to pick an action with the mouse.

const KEY := 11.0   # key pitch
const ROW := 12.0
# keyboard rows: [physical key, width in keys]
const KB_ROWS := [
	[[KEY_ESCAPE, 1], [KEY_1, 1], [KEY_2, 1], [KEY_3, 1], [KEY_4, 1], [KEY_5, 1], [KEY_6, 1], [KEY_7, 1],
		[KEY_8, 1], [KEY_9, 1], [KEY_0, 1], [KEY_MINUS, 1], [KEY_EQUAL, 1], [KEY_BACKSPACE, 2]],
	[[KEY_TAB, 1.5], [KEY_Q, 1], [KEY_W, 1], [KEY_E, 1], [KEY_R, 1], [KEY_T, 1], [KEY_Y, 1], [KEY_U, 1],
		[KEY_I, 1], [KEY_O, 1], [KEY_P, 1], [KEY_BRACKETLEFT, 1], [KEY_BRACKETRIGHT, 1], [KEY_BACKSLASH, 1.5]],
	[[KEY_CAPSLOCK, 1.75], [KEY_A, 1], [KEY_S, 1], [KEY_D, 1], [KEY_F, 1], [KEY_G, 1], [KEY_H, 1], [KEY_J, 1],
		[KEY_K, 1], [KEY_L, 1], [KEY_SEMICOLON, 1], [KEY_APOSTROPHE, 1], [KEY_ENTER, 2.25]],
	[[KEY_SHIFT, 2.25], [KEY_Z, 1], [KEY_X, 1], [KEY_C, 1], [KEY_V, 1], [KEY_B, 1], [KEY_N, 1], [KEY_M, 1],
		[KEY_COMMA, 1], [KEY_PERIOD, 1], [KEY_SLASH, 1], [KEY_SHIFT, 2.75]],
	[[KEY_CTRL, 1.5], [KEY_ALT, 1.5], [KEY_SPACE, 9], [KEY_ALT, 1.5], [KEY_CTRL, 1.5]],
]
const SHORT := {KEY_ESCAPE: "Esc", KEY_TAB: "Tab", KEY_SHIFT: "Shift", KEY_CTRL: "Ctrl", KEY_ALT: "Alt",
	KEY_ENTER: "Enter", KEY_CAPSLOCK: "Caps", KEY_BACKSPACE: "", KEY_SPACE: "",
	KEY_UP: "", KEY_DOWN: "", KEY_LEFT: "", KEY_RIGHT: ""}
const FACE := {JOY_BUTTON_A: "#8fd35a", JOY_BUTTON_B: "#e0574a", JOY_BUTTON_X: "#6fa8e8", JOY_BUTTON_Y: "#f6cf57"}

static func _el(r: Rect2, code: int, fixed: String, shape: String, label: String) -> Dictionary:
	return {"r": r, "code": code, "fixed": fixed, "shape": shape, "label": label}

# the picture centered on (cx, cy)
static func elements(dev: String, cx: float, cy: float) -> Array:
	var out: Array = []
	if dev == "kb":
		var x0 := cx - 102
		var y0 := cy - 49
		for r in KB_ROWS.size():
			var kx := x0
			for k in KB_ROWS[r]:
				var w: float = k[1] * KEY
				out.append(_el(Rect2(kx, y0 + r * ROW, w - 1, 10), k[0], "", "key", SHORT.get(k[0], Controls.code_name("kb", k[0]))))
				kx += w
		# arrows, right of the main block
		var ax := x0 + 15.5 * KEY
		out.append(_el(Rect2(ax + KEY, y0 + 3 * ROW, KEY - 1, 10), KEY_UP, "", "key", ""))
		for i in 3:
			out.append(_el(Rect2(ax + i * KEY, y0 + 4 * ROW, KEY - 1, 10), [KEY_LEFT, KEY_DOWN, KEY_RIGHT][i], "", "key", ""))
		# mouse buttons, below
		out.append(_el(Rect2(cx - 12, y0 + 66, 12, 13), -1, "fire", "key", ""))
		out.append(_el(Rect2(cx, y0 + 66, 12, 13), -1, "flare", "key", ""))
		return out
	out.append(_el(Rect2(cx - 62, cy - 48, 24, 10), -1, "", "key", "LT"))
	out.append(_el(Rect2(cx + 38, cy - 48, 24, 10), -1, "fire", "key", "RT"))
	out.append(_el(Rect2(cx - 66, cy - 36, 32, 10), JOY_BUTTON_LEFT_SHOULDER, "", "key", "LB"))
	out.append(_el(Rect2(cx + 34, cy - 36, 32, 10), JOY_BUTTON_RIGHT_SHOULDER, "", "key", "RB"))
	out.append(_el(Rect2(cx - 52, cy - 18, 16, 16), JOY_BUTTON_LEFT_STICK, "move", "round", ""))
	out.append(_el(Rect2(cx + 14, cy + 2, 16, 16), JOY_BUTTON_RIGHT_STICK, "aim", "round", ""))
	out.append(_el(Rect2(cx - 13, cy - 15, 9, 5), JOY_BUTTON_BACK, "", "key", ""))
	out.append(_el(Rect2(cx + 4, cy - 15, 9, 5), JOY_BUTTON_START, "", "key", ""))
	out.append(_el(Rect2(cx + 40, cy - 23, 9, 9), JOY_BUTTON_Y, "", "round", "Y"))
	out.append(_el(Rect2(cx + 40, cy - 5, 9, 9), JOY_BUTTON_A, "", "round", "A"))
	out.append(_el(Rect2(cx + 31, cy - 14, 9, 9), JOY_BUTTON_X, "", "round", "X"))
	out.append(_el(Rect2(cx + 49, cy - 14, 9, 9), JOY_BUTTON_B, "", "round", "B"))
	out.append(_el(Rect2(cx - 25, cy + 1, 6, 7), JOY_BUTTON_DPAD_UP, "", "key", ""))
	out.append(_el(Rect2(cx - 25, cy + 13, 6, 7), JOY_BUTTON_DPAD_DOWN, "", "key", ""))
	out.append(_el(Rect2(cx - 32, cy + 7, 7, 6), JOY_BUTTON_DPAD_LEFT, "", "key", ""))
	out.append(_el(Rect2(cx - 19, cy + 7, 7, 6), JOY_BUTTON_DPAD_RIGHT, "", "key", ""))
	return out

# the element belongs to action `a`
static func lit(el: Dictionary, dev: String, a: String) -> bool:
	return a != "" and (el.fixed == a or (el.code >= 0 and el.code in Controls.binds(dev, a)))

# the action the mouse picks on the element: the one bound to it, else the fixed one
static func action_of(el: Dictionary, dev: String) -> String:
	if el.code >= 0:
		for a in Controls.BINDABLE[dev]:
			if el.code in Controls.binds(dev, a):
				return a
	return el.fixed

static func draw(ci: CanvasItem, els: Array, dev: String, a: String) -> void:
	var used := {}
	for b in Controls.BINDABLE[dev]:
		for c in Controls.binds(dev, b):
			used[c] = true
	if dev == "kb":
		var m: Rect2 = els[-2].r
		# mouse body under the two buttons
		UiDraw.px_rect(ci, m.position.x - 1, m.position.y - 1, 26, 34, "#0a070d")
		UiDraw.px_rect(ci, m.position.x, m.position.y, 24, 32, "#3a3044")
		UiDraw.px_rect(ci, m.position.x + 11, m.position.y + 3, 2, 6, "#0a070d")
	else:
		var c: Vector2 = (els[4].r as Rect2).get_center() + Vector2(44, 10)   # body center from the left stick
		for k in 2:
			var col: Variant = "#0a070d" if k == 0 else "#3a3044"
			var g := 1 - k
			UiDraw.px_rect(ci, c.x - 62 - g, c.y - 28 - g, 124 + g * 2, 36 + g * 2, col)
			UiDraw.px_circle(ci, c.x - 46, c.y + 12, 20 + g, col)
			UiDraw.px_circle(ci, c.x + 46, c.y + 12, 20 + g, col)
		UiDraw.px_rect(ci, c.x - 25, c.y + 7, 6, 6, "#5c5068")   # d-pad center
	var blink := int(floor(Fx.time * 4)) % 2 == 0
	for el in els:
		var r: Rect2 = el.r
		var on := lit(el, dev, a)
		# lit: the selected action; brass: keys with an action; grey: free keys
		var face: Variant = ("#f6cf57" if blink else "#d8b46a") if on else ("#6a5232" if used.has(el.code) or el.fixed != "" else "#4a4056")
		if el.shape == "round":
			var cx := r.get_center().x
			var cy := r.get_center().y
			UiDraw.px_circle(ci, cx, cy + 1, r.size.x / 2, "#0a070d")
			UiDraw.px_circle(ci, cx, cy, r.size.x / 2, face)
			if r.size.x > 10:
				UiDraw.px_circle(ci, cx, cy, r.size.x / 2 - 3, "#3a3044" if not on else "#d8b46a")
		else:
			UiDraw.px_rect(ci, r.position.x, r.position.y + 1, r.size.x, r.size.y, "#0a070d")
			UiDraw.px_rect(ci, r.position.x, r.position.y, r.size.x, r.size.y - 1, face)
		var label: String = el.label
		if label != "" and Txt.raw_width(label) <= r.size.x - 2:
			var col: Variant = "#16111c" if on else FACE.get(el.code, "#f2ead8") if el.shape == "round" else "#c8c0d0"
			UiDraw.text(ci, label, r.get_center().x + 0.5, r.position.y + floor((r.size.y - 8) / 2), {"align": "center", "color": col, "shadow": false, "raw": true})
