extends Node2D
# Sovrimpressione visibile anche al buio (drawWorld in js/render.js): telegrafi, occhi,
# proiettili nemici, particelle alte, numeri fluttuanti, prompt d'interazione.

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not Run.active or Run.room.is_empty():
		return
	_telegraphs()
	_eyes()
	_enemy_bullets()
	Particles.draw(self, true)
	Floaters.draw(self)
	_prompt()

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

# drawTelegraphs (js/render.js): avvisi sempre visibili anche al buio (senza i raggi)
func _telegraphs() -> void:
	var ga := UiDraw.alpha
	var t := Fx.time
	for f in Run.fx:
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
		# preavviso d'attacco: scintilla sopra la testa
		if e.wind > 0 and not e.dead and e.alpha > 0.3:
			if sin(t * 40) > 0:
				UiDraw.px_rect(self, e.x - 1, e.y - e.r - 9 - e.z, 2, 4, "#f6cf57")
				UiDraw.px_rect(self, e.x - 1, e.y - e.r - 4 - e.z, 2, 1, "#f6cf57")

# drawEyes (js/render.js): occhi dei nemici nell'oscurità
func _eyes() -> void:
	var p := Run.player
	var lr := p.light()
	var ga := UiDraw.alpha
	for e in Run.enemies:
		if e.alpha < 0.5 or e.spawning or e.boss:
			continue
		var d := U.dist(e.x, e.y, p.x, p.y)
		var a := clampf((d - lr * 0.55) / (lr * 0.4), 0, 1)
		if a <= 0:
			continue
		var S := Spr.size(e.def.spr)
		var ey := U.jround(e.y - e.z - S.y * 0.18)
		var col: String = EliteMods.ALL[e.mod].col if e.elite else "#ff5a4a"
		UiDraw.alpha = a * (0.7 + 0.3 * sin(Fx.time * 3 + e.x))
		UiDraw.px_rect(self, e.x - 3, ey, 2, 1, col)
		UiDraw.px_rect(self, e.x + 1, ey, 2, 1, col)
		UiDraw.alpha = ga

# drawPrompt (js/render.js): suggerimento d'interazione
func _prompt() -> void:
	var o: Variant = Run.focus
	if o == null:
		return
	var title := ""
	var desc := ""
	var verb := "Interagisci"
	var col: Variant = Txt.COLORS.w
	var extra := ""
	match o.type:
		"relic":
			title = Relics.ALL[o.id].name
			desc = Relics.ALL[o.id].desc
			verb = "Prendi"
			col = Txt.COLORS.y
			if o.get("group") != null:
				extra = "^dPuoi sceglierne solo una."
		"chest":
			title = "Forziere dorato" if o.gold else "Forziere"
			desc = "Serve una chiave. Contiene tesori preziosi." if o.gold else "Chissà cosa contiene."
			verb = "Apri"
		"shopitem":
			var it: Dictionary = o.item
			match it.kind:
				"cons":
					title = Cons.ALL[it.id].name
					desc = Cons.ALL[it.id].desc
				"heal":
					title = "Unguento"
					desc = "Cura il ^y40%^w della vita massima."
				"key":
					title = "Chiave"
					desc = "Apre forzieri dorati e stanze del tesoro."
				_:
					title = Relics.ALL[it.id].name
					desc = Relics.ALL[it.id].desc
					col = Txt.COLORS.y
			verb = "Compra (" + str(Interact.price_of(o)) + ")"
		"shrine":
			match o.kind:
				"blood":
					title = "Altare di Sangue"
					desc = "Offri ^r15^w vita massima in cambio di un dono ^braro^w o migliore."
					verb = "Offri"
				"fortune":
					title = "Fontana dei Desideri"
					desc = "Getta ^y5^w monete e spera. (Usi rimasti: " + str(o.uses) + ")"
					verb = "Getta"
				"fountain":
					title = "Fonte Pura"
					desc = "Purifica una maledizione per ^y20^w monete." if not Run.player.curses.is_empty() else "Ti ristora completamente, una volta."
					verb = "Bevi"
				_:
					title = "Idolo Proibito"
					desc = "Ottieni una ^yreliquia^w. Ricevi una ^pmaledizione^w."
					verb = "Accetta"
			if o.uses <= 0:
				desc = "^dIl potere si è esaurito."
				verb = ""
			col = Txt.COLORS.p
		"trapdoor":
			title = "Botola"
			desc = "Scendi alla profondità successiva."
			verb = "Scendi"
	var w := 168.0
	var lines := Txt.wrap(desc, w - 12)
	var h := 22 + lines.size() * 10 + (10 if extra != "" else 0) + (12 if verb != "" else 0)
	var x := clampf(o.x - w / 2, 4, Consts.W - w - 4)
	var y: float = o.y - 26 - h
	if y < Consts.RY + 2:
		y = o.y + 22
	UiDraw.panel(self, x, y, w, h)
	UiDraw.text(self, title, x + w / 2, y + 7, {"align": "center", "color": col})
	for i in lines.size():
		UiDraw.text(self, lines[i], x + 6, y + 19 + i * 10, {"color": "#d8d0c0"})
	var yy := y + 19 + lines.size() * 10
	if extra != "":
		UiDraw.text(self, extra, x + 6, yy, {})
		yy += 10
	if verb != "":
		var kw := UiDraw.keycap(self, x + 6, yy + 1, "X" if Controls.device() == "pad" else "E")
		UiDraw.text(self, verb, x + 10 + kw, yy + 2, {"color": Txt.COLORS.y})
