class_name DrawGround
extends Node2D
# Ground drawing in drawWorld order (js/render.js): secret hints, doors,
# dynamic tiles, ground effects, objects, pickups.

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	Spr.capture = null   # left on if the last frame stopped on an error: Spr.draw would only record
	if not Run.active or Run.room.is_empty():
		return
	var room := Run.room
	_secret_hints(room)
	_doors(room)
	if View3D.on:
		Spr.capture = []
	_dynamic_tiles(room)
	_ground_fx()
	_objects(room)
	_pickups(room)
	if View3D.on:
		View3D.items = Spr.capture
		Spr.capture = null

func _secret_hints(room: Dictionary) -> void:
	for d in room.doors:
		var n: Dictionary = room.doors[d]
		if n.type != "secret" or n.found:
			continue
		var c := RoomU.door_center(d)
		var reveal: bool = Run.player.stats.mapReveal or n.get("mapped", false)
		var col := U.rgba(246, 207, 87, 0.55) if reveal else U.rgba(5, 3, 8, 0.6)
		UiDraw.px_rect(self, c.x - 3, c.y - 4, 1, 4, col)
		UiDraw.px_rect(self, c.x - 2, c.y, 2, 1, col)
		UiDraw.px_rect(self, c.x, c.y + 1, 1, 3, col)
		UiDraw.px_rect(self, c.x + 2, c.y - 3, 1, 3, col)
		UiDraw.px_rect(self, c.x + 3, c.y - 1, 2, 1, col)

static func _door_style(room: Dictionary, d: String) -> Dictionary:
	var n: Dictionary = room.doors[d]
	if room.type == "boss" or n.type == "boss":
		return {"frame": "#7e2530", "hi": "#d04b3c", "kind": "boss"}
	if n.type == "treasure" or room.type == "treasure":
		return {"frame": "#9a7a44", "hi": "#f6cf57", "kind": "treasure"}
	if n.type == "shop" or room.type == "shop":
		return {"frame": "#5a4428", "hi": "#c49a6a", "kind": "shop"}
	if n.type == "elite" or room.type == "elite":
		return {"frame": "#3a1020", "hi": "#e0574a", "kind": "elite"}
	if n.type == "shrine" or room.type == "shrine":
		return {"frame": "#4b2a5c", "hi": "#c57ae0", "kind": "shrine"}
	if n.type == "secret" or room.type == "secret":
		return {"frame": "#2a2430", "hi": "#55505e", "kind": "secret"}
	return {"frame": "#2a2230", "hi": "#6b6478", "kind": "normal"}

func _doors(room: Dictionary) -> void:
	var ts := Consts.TS
	for d in room.doors:
		if not RoomU.door_visible(room, d):
			continue
		var st := _door_style(room, d)
		var t0: Array = RoomU.DIRS[d].tiles[0]
		var horiz: bool = d == "n" or d == "s"
		var x: float = Consts.RX + t0[0] * ts
		var y: float = Consts.RY + t0[1] * ts
		var w: float = ts * 3 if horiz else ts
		var h: float = ts if horiz else ts * 3
		var open := RoomU.door_open(room, d)
		var locked := RoomU.door_locked(room, d)
		if st.kind == "secret":
			# irregular gap
			UiDraw.px_rect(self, x + 2, y + 2, w - 4, h - 4, "#050308")
			for i in 6:
				var k := U.hash2(i, int(x), int(y))
				var px: float = x + (k * w if horiz else (1.0 if k > 0.5 else w - 3))
				var py: float = y + ((1.0 if k > 0.5 else h - 3) if horiz else k * h)
				draw_rect(Rect2(px, py, 2, 2), UiDraw._a("#3b3546"))
			continue
		if View3D.on:   # the room's floor, holed where the bars rise
			_gate_holes(x, y, horiz)
		else:
			# frame
			UiDraw.px_rect(self, x, y, w, h, "#0b0810")
			UiDraw.px_rect(self, x + 1, y + 1, w - 2, h - 2, st.frame)
			UiDraw.px_rect(self, x + 4, y + 4, w - 8, h - 8, "#050308" if open else "#120c16")
			# glowing thread
			if horiz:
				UiDraw.px_rect(self, x + 2, y + 2 if d == "n" else y + h - 3, w - 4, 1, st.hi)
			else:
				UiDraw.px_rect(self, x + 2 if d == "w" else x + w - 3, y + 2, 1, h - 4, st.hi)
		if not open and not View3D.on:   # the 3D view raises them (View3D.build_gates)
			# bars
			var bc := "#c49a3a" if locked else "#6b6478"
			for i in 6:
				if horiz:
					draw_rect(Rect2(x + 7 + i * 6, y + 3, 2, h - 6), UiDraw._a(bc))
				else:
					draw_rect(Rect2(x + 3, y + 7 + i * 6, w - 6, 2), UiDraw._a(bc))
			if locked:
				padlock(self, x + w / 2, y + h / 2)
		# symbols
		var cx := x + w / 2
		var cy := y + h / 2
		var sx: float = cx if horiz else (x + w + 6 if d == "w" else x - 6)
		var sy: float = (y + h + 6 if d == "n" else y - 6) if horiz else cy
		match st.kind:
			"boss": Spr.draw(self, "i_skull", 0, sx, sy, {"alpha": 0.8})
			"treasure": Spr.draw(self, "i_crown", 0, sx, sy, {"alpha": 0.8})
			"shop": Spr.draw(self, "i_coin", 0, sx, sy, {"alpha": 0.8})
			"elite": Spr.draw(self, "i_blade", 0, sx, sy, {"alpha": 0.8})
			"shrine": Spr.draw(self, "i_star", 0, sx, sy, {"alpha": 0.7})

# 3D view: a hole in the floor for each bar of the gate (View3D.build_gates);
# with the gate down its tips show in them
func _gate_holes(x: float, y: float, horiz: bool) -> void:
	var m := Consts.TS / 2.0 - 1.0
	for i in 6:
		var a := 7.0 + i * 6
		var hx := x + a if horiz else x + m
		var hy := y + m if horiz else y + a
		UiDraw.px_rect(self, hx - 1, hy - 1, 4, 4, "#050308")
		draw_texture_rect_region(View3D.gate_texture(), Rect2(hx, hy, 2, 2), Rect2(0, 4, 8, 8))

static func padlock(ci: CanvasItem, lx: float, ly: float) -> void:
	UiDraw.px_rect(ci, lx - 4, ly - 2, 8, 7, "#0b0810")
	UiDraw.px_rect(ci, lx - 3, ly - 1, 6, 5, "#f6cf57")
	UiDraw.px_rect(ci, lx - 2, ly - 5, 4, 1, "#f6cf57")
	UiDraw.px_rect(ci, lx - 3, ly - 4, 1, 3, "#f6cf57")
	UiDraw.px_rect(ci, lx + 2, ly - 4, 1, 3, "#f6cf57")
	UiDraw.px_rect(ci, lx - 1, ly + 1, 2, 2, "#5a4428")

func _dynamic_tiles(room: Dictionary) -> void:
	var up := RoomU.spikes_up(room)
	var warn := RoomU.spikes_warn(room)
	for ty in range(1, Consts.RH - 1):
		for tx in range(1, Consts.RW - 1):
			var t: int = room.grid[ty][tx]
			if t == Consts.T.FLOOR or t == Consts.T.ROCK or t == Consts.T.CRACK:
				continue
			var x: float = Consts.RX + tx * Consts.TS
			var y: float = Consts.RY + ty * Consts.TS
			var cx := x + 8
			var cy := y + 8
			if t == Consts.T.SPIKE:
				UiDraw.px_rect(self, x + 1, y + 1, 14, 14, "#16111c")
				UiDraw.px_rect(self, x + 2, y + 2, 12, 12, "#2a2430")
				for o in [[4, 4], [10, 4], [4, 10], [10, 10]]:
					UiDraw.px_rect(self, x + o[0] - 1, y + o[1], 3, 1, "#0b0810")
					if up:
						UiDraw.px_rect(self, x + o[0], y + o[1] - 4, 1, 4, "#e8e4dc")
						UiDraw.px_rect(self, x + o[0] - 1, y + o[1] - 2, 3, 2, "#a59fb0")
					elif warn:
						UiDraw.px_rect(self, x + o[0], y + o[1] - 1, 1, 1, "#a59fb0")
			elif t == Consts.T.BARREL:
				UiDraw.shadow(self, cx, cy + 6, 6)
				var hp: float = room.tileHp.get(ty * Consts.RW + tx, 18)
				Spr.draw(self, "barrel", 0, cx, cy, {"flash": hp < 18 and sin(Fx.time * 20) > 0.6})
			elif t == Consts.T.URN:
				UiDraw.shadow(self, cx, cy + 5, 5)
				Spr.draw(self, "urn", 0, cx, cy)
			elif t == Consts.T.BRAZIER:
				UiDraw.shadow(self, cx, cy + 6, 6)
				Spr.draw(self, "brazier", 0, cx, cy + 2)
				if not View3D.on:   # the 3D view draws it on the standing brazier
					UiDraw.flame(self, cx, cy - 3, 1, Fx.time)

# drawGroundFx (js/render.js)
func _ground_fx() -> void:
	var ga := UiDraw.alpha
	for f in Run.fx:
		if f.get("delay", 0.0) > 0:
			continue
		var k: float = f.t / f.life
		match f.type:
			"cloud":
				var r: float = f.r * minf(1, f.t * 3)
				UiDraw.alpha = 0.35 * (1 - maxf(0, k - 0.7) / 0.3)
				UiDraw.px_circle(self, f.x, f.y, r, "#4f8a3a")
				UiDraw.alpha *= 0.6
				UiDraw.px_circle(self, f.x + sin(f.t * 2) * 3, f.y - 2, r * 0.6, "#9fd05a")
			"fire":
				UiDraw.alpha = 0.55 * (1 - k)
				UiDraw.px_circle(self, f.x, f.y, f.r * 0.7, "#b5571f" if f.owner == "player" else "#d04b3c")
			"spawn":
				var r := 4 + k * 7
				UiDraw.alpha = 0.4 + 0.4 * sin(f.t * 20)
				UiDraw.px_ring(self, f.x, f.y, r, "#c57ae0")
				UiDraw.px_ring(self, f.x, f.y, r * 0.5, "#e8e4dc")
			"bomb":
				UiDraw.alpha = ga
				UiDraw.shadow(self, f.x, f.y + 4, 4)
				var blink: bool = sin(f.t * 40) > 0 if f.t > 1 else sin(f.t * 14) > 0.4
				Spr.draw(self, "bomb", 0, f.x, f.y, {"flash": blink, "scale": 1.0})
		UiDraw.alpha = ga

# drawPickups (js/render.js)
func _pickups(room: Dictionary) -> void:
	var tt := Fx.time
	for k in room.pickups:
		var y: float = k.y - k.z
		if k.type != "xp":
			UiDraw.shadow(self, k.x, k.y + 3, 3)
		var g := {"ground": k.y + 3}   # the 3D view: they hop above their shadow
		match k.type:
			"xp":
				var c := "#c57ae0" if int(floor(tt * 8 + k.x)) % 2 != 0 else "#e0a0ff"
				UiDraw.px_rect(self, k.x - 1, y - 1, 2, 2, c)
				UiDraw.px_rect(self, k.x, y - 2, 1, 1, "#ffffff")
			"coin": Spr.draw(self, "coin", int(floor(tt * 5 + k.x)) % 2, k.x, y, g)
			"coin5": Spr.draw(self, "coin5", int(floor(tt * 5 + k.x)) % 2, k.x, y, g)
			"heart": Spr.draw(self, "heart", 0, k.x, y + sin(tt * 4 + k.x) * 0.8, g)
			"oil": Spr.draw(self, "oil", 0, k.x, y, g)
			"key": Spr.draw(self, "key", 0, k.x, y, g)
			"cons": Spr.draw(self, Cons.ALL[k.id].spr, 0, k.x, y - 2 + sin(tt * 3 + k.x), g)

# drawObjects (js/render.js)
func _objects(room: Dictionary) -> void:
	var tt := Fx.time
	var ga := UiDraw.alpha
	for o in room.objects:
		if o.get("gone", false):
			continue
		match o.type:
			"relic":
				UiDraw.shadow(self, o.x, o.y + 8, 7)
				Spr.draw(self, "pedestal", 0, o.x, o.y + 4)
				var by: float = o.y - 9 + sin(tt * 2.5 + o.x) * 2
				UiDraw.glow(self, o.x, by, 18, "#f6cf57", 0.25)
				# the 3D view: floats above the pedestal
				Spr.draw(self, Relics.ALL[o.id].icon, 0, o.x, by, {"ground": o.y + 8})
			"shopitem":
				UiDraw.shadow(self, o.x, o.y + 8, 7)
				Spr.draw(self, "pedestal", 0, o.x, o.y + 4)
				var by: float = o.y - 8 + sin(tt * 2 + o.x) * 1.5
				var it: Dictionary = o.item
				var g := {"ground": o.y + 8}
				match it.kind:
					"cons": Spr.draw(self, Cons.ALL[it.id].spr, 0, o.x, by, g)
					"heal": Spr.draw(self, "heart", 0, o.x, by, g)
					"key": Spr.draw(self, "key", 0, o.x, by, g)
					"relic":
						UiDraw.glow(self, o.x, by, 16, "#f6cf57", 0.2)
						Spr.draw(self, Relics.ALL[it.id].icon, 0, o.x, by, g)
				var price := Interact.price_of(o)
				var can := Run.player.coins >= price
				Spr.draw(self, "coin", 0, o.x - Txt.width(str(price)) / 2 - 3, o.y + 16, {"flat": true})
				UiDraw.text(self, str(price), o.x + 3, o.y + 13, {"align": "center", "color": Txt.COLORS.y if can else Txt.COLORS.r})
			"chest":
				UiDraw.shadow(self, o.x, o.y + 6, 8)
				Spr.draw(self, "goldchest" if o.gold else "chest", 1 if o.get("open", false) else 0, o.x, o.y)
				if o.gold and not o.get("open", false):
					UiDraw.glow(self, o.x, o.y, 16, "#f6cf57", 0.15)
			"shrine":
				var used: bool = o.uses <= 0
				UiDraw.shadow(self, o.x, o.y + 10, 12)
				if o.kind == "fortune" or o.kind == "fountain":
					Spr.draw(self, "fountain", int(floor(tt * 3)) % 2, o.x, o.y, {"alpha": 0.6 if used else 1.0})
				else:
					Spr.draw(self, "altar", 0, o.x, o.y, {"alpha": 0.6 if used else 1.0})
					if not used and not View3D.on:
						UiDraw.flame(self, o.x, o.y - 10, 1, tt)
			"merchant":
				UiDraw.shadow(self, o.x, o.y + 8, 7)
				Spr.draw(self, "merchant", 1 if int(floor(tt * 1.5)) % 4 == 0 else 0, o.x, o.y)
				if not View3D.on:
					merchant_lantern(self, o)
			"trapdoor":
				var x: float = o.x - 12
				var y: float = o.y - 12
				UiDraw.px_rect(self, x - 1, y - 1, 26, 26, "#0b0810")
				UiDraw.px_rect(self, x, y, 24, 24, "#5a3a24")
				UiDraw.px_rect(self, x + 2, y + 2, 20, 20, "#050308")
				for i in 4:
					UiDraw.px_rect(self, x + 5, y + 4 + i * 5, 14, 1, "#4a3020")
				UiDraw.glow(self, o.x, o.y, 26, "#c57ae0", 0.15 + 0.08 * sin(tt * 3))
	UiDraw.alpha = ga

# merchant's lantern (drawObjects)
static func merchant_lantern(ci: CanvasItem, o: Dictionary) -> void:
	UiDraw.px_rect(ci, o.x + 8, o.y - 2, 3, 4, "#f6cf57")
	UiDraw.px_rect(ci, o.x + 8, o.y - 3, 3, 1, "#3b3546")
