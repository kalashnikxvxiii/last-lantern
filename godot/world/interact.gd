class_name Interact
extends RefCounted
# Interazioni con gli oggetti della stanza (js/entities.js): reliquie, forzieri,
# mercante, santuari, botola.

static func nearest_object() -> Variant:
	var p := Run.player
	var best: Variant = null
	var bd := 22.0
	for o in Run.room.objects:
		if o.get("gone", false) or o.type == "merchant":
			continue
		if o.type == "chest" and o.get("open", false):
			continue
		var d := U.dist(o.x, o.y, p.x, p.y)
		if d < bd:
			bd = d
			best = o
	return best

static func interact(o: Dictionary) -> void:
	match o.type:
		"relic": take_relic(o)
		"chest": open_chest(o)
		"shopitem": buy_item(o)
		"shrine": use_shrine(o)
		"trapdoor": Flow.descend()

static func take_relic(o: Dictionary) -> void:
	var p := Run.player
	var R: Dictionary = Relics.ALL[o.id]
	p.relics.append(o.id)
	if R.has("curse") and not p.curses.has(R.curse):
		p.curses.append(R.curse)
	p.recalc_stats()
	if R.get("onTake", false):
		Relics.on_take(o.id, p)
	o.gone = true
	if o.get("group") != null:
		for x in Run.room.objects:
			if x.get("group") == o.group and not is_same(x, o) and not x.get("gone", false):
				x.gone = true
				Particles.burst(x.x, x.y - 8, 20, ["#8a8294", "#55505e"], 60, 0.6)
	Run.banner(R.name, R.desc, "#f6cf57", R.icon)
	Sfx.play("chest")
	Particles.burst(o.x, o.y - 10, 30, ["#f6cf57", "#fff2a8"], 100, 0.8, {"grav": -40})
	if R.has("curse"):
		U.later(0.3, func(): Sfx.play("curse"))

static func open_chest(o: Dictionary) -> void:
	var p := Run.player
	var room := Run.room
	if o.gold and not o.get("free", false):
		if p.keys <= 0:
			Sfx.play("deny")
			Run.toast("Serve una chiave", "#8a8294")
			return
		p.keys -= 1
	o.open = true
	Sfx.play("chest")
	Particles.burst(o.x, o.y - 4, 20, ["#f6cf57", "#fff2a8", "#c49a6a"], 90, 0.6, {"grav": 60})
	var drops: Array = []
	if o.gold:
		var extra := 1 if p.stats.goldKeys else 0
		drops.append(["cons", Pickups.random_cons()])
		for i in 3 + extra * 2:
			drops.append(["coin5" if U.random() < 0.25 else "coin", null])
		if U.random() < 0.5 + extra * 0.3:
			drops.append(["heart", null])
		if U.random() < 0.3 + extra * 0.3:
			drops.append(["cons", Pickups.random_cons()])
		if U.random() < 0.25 + extra * 0.25:
			var r: Array = RoomBuilder.random_relics(1)
			if not r.is_empty():
				room.objects.append({"type": "relic", "id": r[0], "x": o.x, "y": o.y - 26})
	else:
		var n := U.rndi(2, 4)
		for i in n:
			var r := U.random()
			if r < 0.5:
				drops.append(["coin", null])
			elif r < 0.65:
				drops.append(["heart", null])
			elif r < 0.8:
				drops.append(["oil", null])
			elif r < 0.93:
				drops.append(["cons", Pickups.random_cons()])
			else:
				drops.append(["key", null])
	for dr in drops:
		room.pickups.append(Pickups.make(dr[0], o.x, o.y - 2, {"id": dr[1], "value": 25 if dr[0] == "oil" else 1}))

static func price_of(o: Dictionary) -> int:
	return int(maxf(1, U.jround(o.price * Run.player.stats.priceMult)))

static func buy_item(o: Dictionary) -> void:
	var p := Run.player
	var price := price_of(o)
	if p.coins < price:
		Sfx.play("deny")
		Run.toast("Non hai abbastanza monete", "#8a8294")
		return
	var it: Dictionary = o.item
	if it.kind == "cons" and not p.can_take_cons(it.id):
		Sfx.play("deny")
		Run.toast("Borsa piena", "#8a8294")
		return
	if it.kind == "heal" and p.hp >= p.stats.maxHp:
		Sfx.play("deny")
		Run.toast("Sei già in forze", "#8a8294")
		return
	p.coins -= price
	o.gone = true
	Sfx.play("buy")
	match it.kind:
		"cons": p.give_cons(it.id)
		"heal": p.heal(U.jround(p.stats.maxHp * 0.4))
		"key": p.keys += 1
		"relic": take_relic({"id": it.id, "x": o.x, "y": o.y})
	for m in Run.room.objects:
		if m.type == "merchant":
			m.line = U.pick(["Affare fatto.", "Ottima scelta.", "Torna quando vuoi.", "Che la luce ti accompagni."])
			break

static func use_shrine(o: Dictionary) -> void:
	var p := Run.player
	if o.uses <= 0:
		return
	match o.kind:
		"blood":
			if p.stats.maxHp <= 30:
				Sfx.play("deny")
				Run.toast("Sei troppo debole per offrire altro", "#8a8294")
				return
			o.uses -= 1
			Run.blood_paid += 15
			p.base_hp_mod -= 15
			p.hp = maxf(1, p.hp - 15)
			var choices := Perks.roll_choices(3, 1)
			if not choices.is_empty():
				Run.forced_choices = choices
				Run.pending_levels += 1
			Sfx.play("curse")
			Fx.screen_flash("#7e2530", 0.4)
			Particles.burst(o.x, o.y - 10, 30, ["#d04b3c", "#7e2530"], 90, 0.7)
			p.recalc_stats()
		"fortune":
			if p.coins < 5:
				Sfx.play("deny")
				Run.toast("Servono 5 monete", "#8a8294")
				return
			p.coins -= 5
			o.uses -= 1
			Sfx.play("coin")
			var r := U.random()
			if r < 0.35:
				Run.toast("Le monete affondano nel silenzio.", "#8a8294")
			elif r < 0.65:
				for i in 8:
					Run.room.pickups.append(Pickups.make("coin", o.x, o.y))
				Run.toast("La fontana restituisce il doppio!", "#f6cf57")
			elif r < 0.88:
				Run.room.pickups.append(Pickups.make("cons", o.x, o.y, {"id": Pickups.random_cons()}))
				Run.toast("Qualcosa riaffiora dall'acqua.", "#ece6d8")
			else:
				Run.pending_levels += 1
				Run.toast("Un dono dalla fontana!", "#c57ae0")
		"fountain":
			if not p.curses.is_empty() and p.coins >= 20:
				p.coins -= 20
				o.uses -= 1
				var c: String = p.curses[U.rndi(0, p.curses.size() - 1)]
				p.curses.erase(c)
				p.recalc_stats()
				Run.toast("Maledizione purificata: " + Curses.ALL[c].name, "#7fd8e6")
				Sfx.play("heal")
			elif p.curses.is_empty():
				o.uses -= 1
				p.heal(999, true)
				p.add_oil(999)
				Run.toast("L'acqua pura ti ristora.", "#7fd8e6")
			else:
				Sfx.play("deny")
				Run.toast("Servono 20 monete", "#8a8294")
				return
		"pact":
			o.uses -= 1
			var r: Array = RoomBuilder.random_relics(1)
			var avail: Array = Curses.ALL.keys().filter(func(c): return not p.curses.has(c))
			if not avail.is_empty():
				p.curses.append(U.pick(avail))
			p.recalc_stats()
			if not r.is_empty():
				take_relic({"id": r[0], "x": o.x, "y": o.y})
			Sfx.play("curse")
			Fx.screen_flash("#4b2a5c", 0.5)
			Run.toast("Il patto è stretto.", "#c57ae0", "Nuova maledizione: " + Curses.ALL[p.curses.back()].name if not avail.is_empty() else "")
