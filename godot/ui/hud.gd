extends Node2D
# Everything the JS draws after drawWorld, except the panels (Scenes.play.draw and drawHUD).

@onready var play: Node = get_parent().get_parent()   # Play/HudLayer/Hud

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not Run.active or Run.room.is_empty():
		return
	_oil_embers()
	_flash_and_low_hp()
	_hud()
	Notices.draw(self)
	_intro()
	_crosshair()
	_restart_hold()
	_fade_and_death()

var _low_hp_tex: GradientTexture2D

# oil embers flying back to the lantern
func _oil_embers() -> void:
	var p := Run.player
	for o in Run.oil_fx:
		var k: float = o.t / 0.45
		var x := lerpf(o.x, p.x, k * k)
		var y := lerpf(o.y, p.y - 2, k * k) - sin(k * PI) * 14
		UiDraw.px_rect(self, x - 1, y - 1, 2, 2, "#f29c38")
		UiDraw.px_rect(self, x, y, 1, 1, "#fff2a8")

func _flash_and_low_hp() -> void:
	var p := Run.player
	var ga := UiDraw.alpha
	if Fx.flash > 0:
		UiDraw.alpha = minf(0.6, Fx.flash)
		UiDraw.px_rect(self, 0, 0, Consts.W, Consts.H, Fx.flash_col)
		UiDraw.alpha = ga
	# red border at low health
	if p.hp / p.stats.maxHp < 0.3 and not p.dead:
		if _low_hp_tex == null:
			var g := Gradient.new()
			g.set_offset(0, 0.375)
			g.set_color(0, Color(0.627, 0.094, 0.094, 0))
			g.set_color(1, Color(0.627, 0.094, 0.094, 1))
			_low_hp_tex = GradientTexture2D.new()
			_low_hp_tex.gradient = g
			_low_hp_tex.fill = GradientTexture2D.FILL_RADIAL
			_low_hp_tex.fill_from = Vector2(0.5, 0.5)
			_low_hp_tex.fill_to = Vector2(1.0, 0.5)
		var R := Consts.H * 0.8
		draw_texture_rect(_low_hp_tex, Rect2(Consts.W / 2.0 - R, Consts.H / 2.0 - R, R * 2, R * 2), false, Color(1, 1, 1, 0.18 + 0.1 * sin(Fx.time * 5)))

# drawHUD (js/ui.js)
func _hud() -> void:
	var p := Run.player
	var s := p.stats
	var W := Consts.W
	var t := Fx.time
	# vitals (top left): health and oil. The JS top bar is gone, the HUD floats on the game
	Spr.draw(self, "heart", 0, 8, 7)
	var hp_low: bool = p.hp / s.maxHp < 0.3
	UiDraw.bar(self, 16, 3, 92, 8, p.hp / s.maxHp, "#ff6a5a" if hp_low and sin(t * 8) > 0 else "#c0392b", "#2a0d12", "#e87060")
	UiDraw.text(self, str(int(ceilf(p.hp))) + "/" + str(int(s.maxHp)), 62, 3, {"align": "center", "color": "#f2ead8"})
	Spr.draw(self, "oil", 0, 8, 17)
	var oil_f: float = p.oil / s.maxOil
	UiDraw.bar(self, 16, 15, 92, 4, oil_f, "#3b3546" if p.oil <= 0 else "#d88a28", "#1e140a", "#f6cf57")
	var cx := 16 + U.jround(92 * minf(1, p.ability_cost() / s.maxOil))   # Godot-only: the character's ability
	var ready: bool = p.oil >= p.ability_cost()
	UiDraw.px_rect(self, cx, 13, 1, 8, "#fff2a8" if ready else "#5a4428")
	if p.oil <= 0:
		UiDraw.text(self, "DARK", 62, 13, {"align": "center", "color": "#e0574a" if sin(t * 6) > 0 else "#8a8294"})
	# depth and biome (top center, overlay)
	var bio := DB.biome_of(Run.depth)
	UiDraw.text(self, Loc.f("Depth {0}", [Run.depth]) if Run.depth > 5 else Loc.f("Depth {0} of 5", [Run.depth]), W / 2.0, 6, {"align": "center", "color": "#e8dcc0"})
	UiDraw.text(self, bio.name, W / 2.0, 16, {"align": "center", "color": "#8a8294"})
	# minimap (top right, in an opaque cube)
	UiDraw.px_rect(self, 390, 2, 88, 31, "#0b0810")
	UiDraw.px_rect(self, 390, 2, 88, 1, "#2e2436")
	UiDraw.px_rect(self, 390, 32, 88, 1, "#2e2436")
	UiDraw.px_rect(self, 390, 2, 1, 31, "#2e2436")
	UiDraw.px_rect(self, 477, 2, 1, 31, "#2e2436")
	MapDraw.minimap(self, 393, 5, false)
	# level, coins and keys (bottom left, flush with the edge)
	var ry := 232.0
	var rx := 2.0
	var lw := UiDraw.text(self, Loc.f("Lv {0}", [p.level]), rx, ry, {"color": "#c57ae0"})
	rx += lw + 8.0
	Spr.draw(self, "coin", 0, rx + 4.0, ry + 4.0)
	rx += 10.0
	var cw := UiDraw.text(self, str(p.coins), rx, ry, {"color": Txt.COLORS.y})
	rx += cw + 8.0
	Spr.draw(self, "key", 0, rx + 4.0, ry + 4.0)
	rx += 10.0
	UiDraw.text(self, str(p.keys), rx, ry, {"color": "#e8dcc0"})
	# consumables (bottom left, above the experience bar)
	for i in 4:
		var x := 2 + i * 22
		var y := 244
		UiDraw.px_rect(self, x, y, 20, 20, "#0b0810")
		UiDraw.px_rect(self, x + 1, y + 1, 18, 18, "#1f1826")
		UiDraw.px_rect(self, x + 1, y + 1, 18, 1, "#2e2436")
		var sl: Variant = p.cons[i]
		if sl != null:
			Spr.draw(self, Cons.ALL[sl.id].spr, 0, x + 10, y + 10)
			if sl.n > 1:
				UiDraw.text(self, str(sl.n), x + 18, y + 12, {"align": "right", "color": "#f2ead8"})
		UiDraw.text(self, str(i + 1), x + 2, y + 1, {"color": "#6b6478", "shadow": false})
	# statuses and curses (below the vitals)
	var sy := 28.0
	var sx := 4.0
	for k in p.statuses:
		if not Statuses.ALL.has(k):
			continue
		var st: Dictionary = Statuses.ALL[k]
		var v: Dictionary = p.statuses[k]
		UiDraw.px_rect(self, sx, sy, 11, 13, "#0b0810")
		Spr.draw(self, st.icon, 0, sx + 5.5, sy + 5)
		var f := clampf(v.t / 6, 0, 1)
		UiDraw.px_rect(self, sx + 1, sy + 11, U.jround(9 * f), 1, st.col)
		if v.stacks > 1:
			UiDraw.text(self, str(v.stacks), sx + 12, sy + 6, {"color": st.col})
		sx += 19 if v.stacks > 1 else 13
	if p.guard_up:
		UiDraw.px_rect(self, sx, sy, 11, 13, "#0b0810")
		Spr.draw(self, "s_shield", 0, sx + 5.5, sy + 6)
		sx += 13
	for c in p.curses:
		UiDraw.px_rect(self, sx, sy, 11, 13, "#1a0d22")
		Spr.draw(self, "s_curse", 0, sx + 5.5, sy + 6)
		sx += 13
	# experience (full width, on the bottom edge)
	var xf: float = clampf(p.xp / Stats.xp_need(p.level), 0, 1)
	UiDraw.px_rect(self, 0, 268, W, 2, "#1a0d22")
	if xf > 0:
		UiDraw.px_rect(self, 0, 268, maxf(1.0, U.jround(W * xf)), 2, "#c57ae0")
	# dash charges under the feet
	if p.dash_charges < s.dashCharges and not p.dead:
		for i in s.dashCharges:
			var x: float = p.x - (s.dashCharges * 4) / 2.0 + i * 4
			UiDraw.px_rect(self, x, p.y + 11, 3, 2, "#c8f2f5" if i < p.dash_charges else "#3b3546")
	# boss bar
	var boss: Variant = null
	for e in Run.enemies:
		if e.boss:
			boss = e
			break
	if boss != null:
		var w := 300.0
		var x := W / 2.0 - w / 2
		var y := Consts.H - 14.0
		UiDraw.text(self, boss.display_name, W / 2.0, y - 10, {"align": "center", "color": "#e8dcc0"})
		UiDraw.px_rect(self, x - 2, y - 2, w + 4, 9, "#0b0810")
		UiDraw.px_rect(self, x - 1, y - 1, w + 2, 7, UiDraw.UI.brassD)
		UiDraw.bar(self, x, y, w, 5, boss.hp / boss.max_hp, "#a59fb0" if boss.invuln > 0 else "#a02a3a", "#200810", "#e0574a")
		# phase ticks
		for ph in boss.B.phases:
			if ph.at < 1:
				UiDraw.px_rect(self, x + U.jround(w * ph.at), y - 1, 1, 7, "#e8dcc0")

# drawIntro (js/game.js)
func _intro() -> void:
	var W := Consts.W
	var ga := UiDraw.alpha
	var it: Variant = Run.intro
	if it != null and it.t < 4.5:
		var a: float = it.t / 0.6 if it.t < 0.6 else (maxf(0, 1 - (it.t - 3.5)) if it.t > 3.5 else 1.0)
		var b := DB.biome_of(it.depth)
		UiDraw.alpha = a * 0.6
		UiDraw.px_rect(self, 0, 92, W, 70, "#050308")
		UiDraw.alpha = ga
		UiDraw.text(self, Loc.f("Depth {0}", [it.depth]), W / 2.0, 98, {"align": "center", "color": "#8a8294", "alpha": a})
		UiDraw.text(self, b.name, W / 2.0, 112, {"align": "center", "color": "#f6cf57", "scale": 2, "alpha": a})
		var lines := Txt.wrap(b.lore, 360)
		for i in lines.size():
			UiDraw.text(self, lines[i], W / 2.0, 136 + i * 10, {"align": "center", "color": "#c8c0d0", "alpha": a, "raw": true})
	var bi: Variant = Run.boss_intro
	if bi != null:
		var a: float = bi.t / 0.4 if bi.t < 0.4 else (maxf(0, 1 - (bi.t - 2.2) / 0.6) if bi.t > 2.2 else 1.0)
		var bh := 22 * a
		UiDraw.px_rect(self, 0, 28, W, bh, "#000000")
		UiDraw.px_rect(self, 0, Consts.H - bh, W, bh, "#000000")
		UiDraw.text(self, bi.B.name, W / 2.0, 104, {"align": "center", "color": "#e0574a", "scale": 2, "alpha": a})
		UiDraw.text(self, bi.B.title, W / 2.0, 126, {"align": "center", "color": "#c8c0d0", "alpha": a})

# crosshair: while the mouse aims, also when walking with the keys (the JS hides it)
func _crosshair() -> void:
	if play.mode != "play" or not Controls.mouse_aims() or Run.player.dead:
		return
	var m := Controls.mouse_pos()
	var mx := U.jround(m.x)
	var my := U.jround(m.y)
	var c := "#f6cf57" if Controls.mouse_left() else "#e8dcc0"
	for r in [[-5, 0, 3, 1], [3, 0, 3, 1], [0, -5, 1, 3], [0, 3, 1, 3]]:
		UiDraw.px_rect(self, mx + r[0] + 1, my + r[1] + 1, r[2], r[3], "#0b0810")
		UiDraw.px_rect(self, mx + r[0], my + r[1], r[2], r[3], c)
	UiDraw.px_rect(self, mx, my, 1, 1, "#f29c38")

# hold R to restart on a new seed (Godot-only): the hint while the key is down,
# then the lantern floods the screen and the new run lifts the light
func _restart_hold() -> void:
	var ga := UiDraw.alpha
	if Run.restart_t > 0.0 and Run.restart_flare < 0.0:
		UiDraw.text(self, Loc.f("{0}: restart", [Controls.bind_name("reroll")]), Consts.W / 2.0, 240, {"align": "center", "color": "#e8dcc0"})
	if Run.restart_flare >= 0.0:
		UiDraw.alpha = minf(1.0, Run.restart_flare / Consts.RESTART_FADE)
		UiDraw.px_rect(self, 0, 0, Consts.W, Consts.H, "#fff2a8")
	if Run.restart_in > 0.0:
		UiDraw.alpha = Run.restart_in
		UiDraw.px_rect(self, 0, 0, Consts.W, Consts.H, "#fff2a8")
	UiDraw.alpha = ga

func _fade_and_death() -> void:
	var ga := UiDraw.alpha
	if Run.trans != null:
		UiDraw.alpha = Flow.trans_alpha()
		UiDraw.px_rect(self, 0, 0, Consts.W, Consts.H, "#000000")
		UiDraw.alpha = ga
	if Run.player.dead:
		var a := minf(1, Run.death_t / 2)
		UiDraw.alpha = a * 0.7
		UiDraw.px_rect(self, 0, 0, Consts.W, Consts.H, "#000000")
		UiDraw.alpha = ga
		UiDraw.text(self, "Your light is going out...", Consts.W / 2.0, Consts.H / 2.0 - 6, {"align": "center", "color": "#e0574a", "scale": 2, "alpha": a})
