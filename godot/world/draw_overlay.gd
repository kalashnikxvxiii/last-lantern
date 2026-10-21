class_name DrawOverlay
extends Node2D
# Overlay visible even in the dark (drawWorld in js/render.js): telegraphs, eyes,
# enemy projectiles, high particles, floating numbers, interaction prompt,
# merchant's speech bubble.

func _process(_delta: float) -> void:
	queue_redraw()

# Godot-only, with the 3D view: "ground" draws the telegraphs on the floor, "air"
# the projectiles and particles on the plane above it; DrawLifted draws the rest
@export var part := "ground"

func _draw() -> void:
	if not Run.active or Run.room.is_empty():
		return
	if View3D.on:
		if part == "air":
			_enemy_bullets()
			Particles.draw(self, true)
		else:
			_telegraphs()
		return
	_telegraphs()
	_eyes()
	_enemy_bullets()
	Particles.draw(self, true)
	Floaters.draw(self)
	prompt(self)
	for o in Run.room.objects:
		bubble(self, o)

# merchant's speech bubble (drawObjects in js/render.js); drawn in the overlay,
# above the actors, so the player does not cover it
static func bubble(ci: CanvasItem, o: Dictionary) -> void:
	if o.type != "merchant" or U.dist(o.x, o.y, Run.player.x, Run.player.y) >= 70:
		return
	var w := UiDraw.panel_width(o.line, "", 12.0)
	UiDraw.panel(ci, o.x - w / 2, o.y - 34, w, 16, {"alpha": 0.9})
	UiDraw.text(ci, o.line, o.x, o.y - 30, {"align": "center", "color": "#e8dcc0"})

# drawEnemyBullets (js/render.js)
func _enemy_bullets() -> void:
	for b in Run.ebullets:
		var col := Bullets.color_of(b)
		if b.kind == "bone":
			var a: float = b.t * 14
			var dx := cos(a) * 3
			var dy := sin(a) * 3
			draw_line(Vector2(b.x - dx, b.y - dy), Vector2(b.x + dx, b.y + dy), UiDraw._a("#0b0810"), 4)
			draw_line(Vector2(b.x - dx, b.y - dy), Vector2(b.x + dx, b.y + dy), UiDraw._a("#e8e4dc"), 2)
			continue
		UiDraw.px_circle(self, b.x, b.y, b.r + 1, "#0b0810")
		UiDraw.px_circle(self, b.x, b.y, b.r, col)
		UiDraw.px_rect(self, b.x - 1, b.y - 1, 2, 2, "#140a1c" if b.kind == "void" else "#ffffff")

# drawTelegraphs (js/render.js): warnings always visible even in the dark (without the beams)
func _telegraphs() -> void:
	var ga := UiDraw.alpha
	var t := Fx.time
	for f in Run.fx:
		if f.type == "beam":
			_beam(f)
			continue
		if f.type != "warn":
			continue
		var k: float = f.t / f.life
		UiDraw.alpha = 0.25 + 0.25 * sin(f.t * 18)
		UiDraw.px_circle(self, f.x, f.y, f.r, "#4f8a3a" if f.get("hit") == "cloud" else "#7e2530")
		UiDraw.alpha = 0.9
		UiDraw.px_ring(self, f.x, f.y, f.r, "#9fd05a" if f.get("hit") == "cloud" else "#e0574a")
		UiDraw.px_ring(self, f.x, f.y, f.r * k, "#ffffff")
		UiDraw.alpha = ga
	for e in Run.enemies:
		if e._body_a() <= 0.003:   # Godot-only: ash keeps no telegraphs
			continue
		if e.charge_line != null:
			UiDraw.alpha = 0.5 + 0.3 * sin(t * 30)
			draw_dashed_line(Vector2(e.x, e.y), Vector2(e.x + cos(e.charge_line) * 300, e.y + sin(e.charge_line) * 300), UiDraw._a("#e0574a"), e.r, 6)
			UiDraw.alpha = ga
		if e.slam_target != null:
			UiDraw.alpha = 0.5
			UiDraw.px_circle(self, e.slam_target.x, e.slam_target.y, e.r + 4, "#7e2530")
			UiDraw.px_ring(self, e.slam_target.x, e.slam_target.y, e.r + 4, "#e0574a")
			UiDraw.alpha = ga
		if e.ai == "charger" and e.state == "wind":
			UiDraw.alpha = 0.35
			draw_dashed_line(Vector2(e.x, e.y), Vector2(e.x + cos(e.charge_a) * 120, e.y + sin(e.charge_a) * 120), UiDraw._a("#e0574a"), 2, 3)
			UiDraw.alpha = ga
		if e.ai == "dasher" and e.state == "aim":
			UiDraw.alpha = 0.35
			draw_dashed_line(Vector2(e.x, e.y), Vector2(e.x + cos(e.dash_a) * 110, e.y + sin(e.dash_a) * 110), UiDraw._a("#7fd8e6"), 2, 3)
			UiDraw.alpha = ga
		if not View3D.on:
			warn_spark(self, e)

# attack warning: spark above the head (drawTelegraphs)
static func warn_spark(ci: CanvasItem, e: Enemy) -> void:
	if e._body_a() <= 0.003:   # Godot-only: ash has no head to warn over
		return
	if e.wind > 0 and not e.dead and e.alpha > 0.3:
		if sin(Fx.time * 40) > 0:
			UiDraw.px_rect(ci, e.x - 1, e.y - e.r - 9 - e.z, 2, 4, "#f6cf57")
			UiDraw.px_rect(ci, e.x - 1, e.y - e.r - 4 - e.z, 2, 1, "#f6cf57")

func _beam(f: Dictionary) -> void:
	var a := Vector2(f.x, f.y)
	var b := Vector2(f.x + cos(f.ang) * f.len, f.y + sin(f.ang) * f.len)
	var ga := UiDraw.alpha
	if f.t < f.warm:
		UiDraw.alpha = 0.4 + 0.3 * sin(f.t * 25)
		draw_dashed_line(a, b, UiDraw._a("#e0574a"), 1, 4)
	else:
		UiDraw.alpha = 0.5
		draw_line(a, b, UiDraw._a("#7a3a9a"), f.w + 4)
		UiDraw.alpha = 1.0
		draw_line(a, b, UiDraw._a("#e0a0ff"), f.w)
		draw_line(a, b, UiDraw._a("#ffffff"), 2)
	UiDraw.alpha = ga

# drawEyes (js/render.js): enemy eyes in the darkness
func _eyes() -> void:
	for e in Run.enemies:
		eye(self, e)

static func eye(ci: CanvasItem, e: Enemy) -> void:
	var p := Run.player
	var lr := p.light()
	if e.alpha < 0.5 or e.spawning or e.boss:
		return
	var ba := e._body_a()   # Godot-only: ash has no eyes; they fade back with the body
	if ba <= 0.003:
		return
	var d := U.dist(e.x, e.y, p.x, p.y)
	var a := clampf((d - lr * 0.55) / (lr * 0.4), 0, 1)
	if a <= 0:
		return
	var ga := UiDraw.alpha
	var S := Spr.size(e.def.spr)
	var ey := U.jround(e.y - e.z - S.y * 0.18)
	var col: String = EliteMods.ALL[e.mod].col if e.elite else "#ff5a4a"
	UiDraw.alpha = a * ba * (0.7 + 0.3 * sin(Fx.time * 3 + e.x))
	UiDraw.px_rect(ci, e.x - 3, ey, 2, 1, col)
	UiDraw.px_rect(ci, e.x + 1, ey, 2, 1, col)
	UiDraw.alpha = ga

# drawPrompt (js/render.js): interaction hint
static func prompt(ci: CanvasItem) -> void:
	var o: Variant = Run.focus
	if o == null:
		return
	var title := ""
	var desc := ""
	var verb := "Interact"
	var col: Variant = Txt.COLORS.w
	var extra := ""
	match o.type:
		"relic":
			title = Relics.ALL[o.id].name
			desc = Relics.ALL[o.id].desc
			verb = "Take"
			col = Txt.COLORS.y
			if o.get("group") != null:
				extra = "^dYou can only choose one."
		"chest":
			title = "Golden chest" if o.gold else "Chest"
			desc = "Needs a key. Holds precious treasures." if o.gold else "Who knows what it holds."
			verb = "Open"
		"shopitem":
			var it: Dictionary = o.item
			match it.kind:
				"cons":
					title = Cons.ALL[it.id].name
					desc = Cons.ALL[it.id].desc
				"heal":
					title = "Salve"
					desc = "Heals ^y40%^w of max health."
				"key":
					title = "Key"
					desc = "Opens golden chests and treasure rooms."
				_:
					title = Relics.ALL[it.id].name
					desc = Relics.ALL[it.id].desc
					col = Txt.COLORS.y
			verb = Loc.f("Buy ({0})", [Interact.price_of(o)])
		"shrine":
			match o.kind:
				"blood":
					title = "Blood Altar"
					desc = "Offer ^r15^w max health in exchange for a ^brare^w or better perk."
					verb = "Offer"
				"fortune":
					title = "Wishing Fountain"
					desc = Loc.f("Throw in ^y5^w coins and hope. (Uses left: {0})", [o.uses])
					verb = "Throw"
				"fountain":
					title = "Pure Spring"
					desc = "Purify a curse for ^y20^w coins." if not Run.player.curses.is_empty() else "Fully restores you, once."
					verb = "Drink"
				_:
					title = "Forbidden Idol"
					desc = "Gain a ^yrelic^w. Receive a ^pcurse^w."
					verb = "Accept"
			if o.uses <= 0:
				desc = "^dThe power is spent."
				verb = ""
			col = Txt.COLORS.p
		"trapdoor":
			title = "Trapdoor"
			desc = "Descend to the next depth."
			verb = "Descend"
	var w := 168.0
	var lines := Txt.wrap(desc, w - 12)
	var h := 22 + lines.size() * 10 + (10 if extra != "" else 0) + (12 if verb != "" else 0)
	var x := clampf(o.x - w / 2, 4, Consts.W - w - 4)
	var y: float = o.y - 26 - h
	if y < Consts.RY + 2:
		y = o.y + 22
	UiDraw.panel(ci, x, y, w, h)
	UiDraw.text(ci, title, x + w / 2, y + 7, {"align": "center", "color": col})
	for i in lines.size():
		UiDraw.text(ci, lines[i], x + 6, y + 19 + i * 10, {"color": "#d8d0c0", "raw": true})
	var yy := y + 19 + lines.size() * 10
	if extra != "":
		UiDraw.text(ci, extra, x + 6, yy, {})
		yy += 10
	if verb != "":
		var kw := UiDraw.keycap(ci, x + 6, yy + 1, Controls.bind_name("interact"))
		UiDraw.text(ci, verb, x + 10 + kw, yy + 2, {"color": Txt.COLORS.y})
