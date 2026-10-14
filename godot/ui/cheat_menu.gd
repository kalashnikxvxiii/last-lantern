class_name CheatMenu
extends RefCounted
# Pages of the cheat panel (mode "cheats" of the game scene) and the debug readout.
# Entries are Menu items: LEFT/RIGHT cycle a list or flip a toggle, ENTER applies.

const PAGES := ["Player", "Build", "World"]
static var cur: Dictionary = {}   # list cursors, kept while the game is open

static func page(name: String, play) -> Menu:
	var items: Array
	match name:
		"Player": items = _player(play)
		"Build": items = _build()
		"World": items = _world(play)
		_:
			items = []
			for pg in PAGES:
				items.append({"label": pg, "action": func(): play.open_cheats(pg)})
			items.append({"label": "Close", "action": func(): play.close_cheats()})
			return Menu.new(items)
	items.append({"label": "Back", "action": func(): play.open_cheats("main", name)})
	return Menu.new(items)

static func _player(play) -> Array:
	return [
		_toggle("God mode", "god"),
		_toggle("Infinite oil", "inf_oil"),
		_toggle("Noclip", "noclip"),
		_toggle("One-hit kills", "one_shot"),
		_act("Heal and refill", func(): Cheats.heal_full()),
		_act("Coins +100", func(): Cheats.add_coins(100)),
		_act("Keys +5", func(): Cheats.add_keys(5)),
		_act("Level up", func(): Cheats.level_up(), "Perk choice once the room is calm"),
		_act("Die", func():
			play.close_cheats()
			Cheats.kill_player()),
	]

static func _build() -> Array:
	var p := Run.player
	return [
		_cycle("Add perk", "perk", func(): return Perks.ALL.keys(),
			func(id): return Perks.ALL[id].name + " " + str(p.perks.get(id, 0)) + "/" + str(Perks.ALL[id]["max"]),
			func(id): return Cheats.add_perk(id)),
		_cycle("Remove perk", "perk_rm", func(): return p.perks.keys(),
			func(id): return Perks.ALL[id].name + " " + str(p.perks[id]),
			func(id): return Cheats.remove_perk(id)),
		_cycle("Relic", "relic", func(): return Relics.ALL.keys(),
			func(id): return ("+ " if p.relics.has(id) else "") + Relics.ALL[id].name,
			func(id): Cheats.toggle_relic(id)),
		_cycle("Curse", "curse", func(): return Curses.ALL.keys(),
			func(id): return ("+ " if p.curses.has(id) else "") + Curses.ALL[id].name,
			func(id): Cheats.toggle_curse(id)),
		_cycle("Consumable", "cons", func(): return Cons.ALL.keys(),
			func(id): return Cons.ALL[id].name,
			func(id): return Cheats.give_cons(id)),
		_cycle("Lantern", "lantern", func(): return DB.LANTERN_IDS,
			func(id): return ("+ " if p.lantern == id else "") + DB.lantern(id).name,
			func(id): Cheats.set_lantern(id)),
		_act("Clear perks, relics, curses", func(): Cheats.clear_build()),
	]

static func _world(play) -> Array:
	return [
		_act("Kill all enemies", func(): Cheats.kill_all()),
		_act("Clear room", func(): Cheats.clear_room()),
		_toggle("Freeze enemies", "freeze"),
		_cycle("Spawn", "enemy", func(): return Cheats.enemy_ids(),
			func(id): return DB.enemy(id).name,
			func(id):
				play.close_cheats()
				Cheats.spawn_enemy(id, _elite())),
		_cycle("  as elite", "elite", func(): return [""] + EliteMods.ALL.keys(),
			func(id): return "no" if id == "" else EliteMods.ALL[id].name,
			func(_id): pass),
		_cycle("Spawn warden", "boss", func(): return Cheats.boss_ids(),
			func(id): return DB.boss(id).name,
			func(id):
				play.close_cheats()
				Cheats.spawn_boss(id)),
		_cycle("Go to room", "room", func(): return Cheats.room_types(),
			func(t): return t,
			func(t):
				play.close_cheats()
				return Cheats.goto_room(t)),
		_act("Reveal map", func(): Flow.reveal_map()),
		{"label": "Go to depth", "value": func(): return "< " + str(_depth()) + " >",
			"adjust": func(d): cur.depth = maxi(1, _depth() + d),
			"action": func():
				play.close_cheats()
				Cheats.mark()
				Cheats.goto_depth(_depth())},
		{"label": "Game speed", "value": func(): return "< x" + str(Cheats.speed()) + " >",
			"adjust": func(d): Cheats.speed_i = clampi(Cheats.speed_i + d, 0, Cheats.SPEEDS.size() - 1),
			"action": func(): Cheats.speed_i = 2},
		_toggle("Debug info", "info"),
	]

static func _depth() -> int:
	return cur.get("depth", Run.depth)

static func _elite() -> Variant:
	var l: Array = [""] + EliteMods.ALL.keys()
	var id: String = l[posmod(cur.get("elite", 0), l.size())]
	return null if id == "" else id

# ---------------------------------------------------------------- item kinds

static func _act(label: String, f: Callable, note: String = "") -> Dictionary:
	return {"label": label, "action": func():
		Cheats.mark()
		f.call()
		Run.toast("Cheat: " + label, "#e0574a", note)}

static func _toggle(label: String, prop: String) -> Dictionary:
	var flip := func(): Cheats.set(prop, not Cheats.get(prop))
	return {"label": label, "value": func(): return "On" if Cheats.get(prop) else "Off",
		"adjust": func(_d): flip.call(), "action": flip}

# list(): ids, show(id): text, apply(id): false refuses (plays "deny")
static func _cycle(label: String, key: String, list: Callable, show: Callable, apply: Callable) -> Dictionary:
	return {"label": label,
		"value": func():
			var l: Array = list.call()
			return "-" if l.is_empty() else "< " + show.call(l[posmod(cur.get(key, 0), l.size())]) + " >",
		"adjust": func(d): cur[key] = cur.get(key, 0) + d,
		"action": func():
			var l: Array = list.call()
			if l.is_empty():
				return
			var id: Variant = l[posmod(cur.get(key, 0), l.size())]
			Cheats.mark()
			var ok: Variant = apply.call(id)
			if ok is bool and not ok:
				Sfx.play("deny")}

# ---------------------------------------------------------------- drawing

static func draw(ci: CanvasItem, menu: Menu, title: String) -> void:
	var x := 10.0
	var y := 32.0
	var w := 250.0
	var lh := 13.0
	var h := 40.0 + menu.items.size() * lh
	UiDraw.panel(ci, x, y, w, h)
	UiDraw.text(ci, "Cheats" + ("" if title == "main" else " - " + title), x + 10, y + 7, {"color": "#e0574a"})
	UiDraw.text(ci, "F1 close   ESC back", x + w - 10, y + 7, {"align": "right", "color": "#55505e"})
	menu.rects = []
	for i in menu.items.size():
		var it: Dictionary = menu.items[i]
		var yy := y + 22 + i * lh
		var is_sel := i == menu.sel
		var label: String = it.label.call() if it.label is Callable else it.label
		menu.rects.append(Rect2(x + 4, yy - 2, w - 8, lh))
		if is_sel:
			UiDraw.px_rect(ci, x + 4, yy - 2, w - 8, lh, "#2e2436")
			UiDraw.px_rect(ci, x + 4, yy - 2, 2, lh, UiDraw.UI.sel)
		UiDraw.text(ci, label, x + 12, yy, {"color": UiDraw.UI.sel if is_sel else "#c8c0d0"})
		if it.has("value"):
			UiDraw.text(ci, str(it.value.call()), x + w - 10, yy, {"align": "right", "color": "#e8dcc0" if is_sel else "#8a8294"})

# whether draw_info shows the debug readout (Panels draws it during a run)
static func info_shown() -> bool:
	return Cheats.enabled and Cheats.info and Run.active and not Run.room.is_empty()

static func draw_info(ci: CanvasItem) -> void:
	var p := Run.player
	var on: Array = []
	for k in [["god", "GOD"], ["inf_oil", "OIL"], ["noclip", "NOCLIP"], ["one_shot", "1HIT"], ["freeze", "FREEZE"]]:
		if Cheats.get(k[0]):
			on.append(k[1])
	if Cheats.speed() != 1.0:
		on.append("x" + str(Cheats.speed()))
	if not Cheats.info:
		if not on.is_empty():
			UiDraw.text(ci, " ".join(on), Consts.W - 4, Consts.H - 10, {"align": "right", "color": "#e0574a"})
		return
	var room: Dictionary = Run.room
	var lines := [
		"FPS %d   seed %d   depth %d   t %s" % [Engine.get_frames_per_second(), Run.seed, Run.depth, U.fmt_time(Run.time)],
		"room %d,%d %s   wave %d/%d   enemies %d   bullets %d/%d" % [room.gx, room.gy, room.type, room.get("waveIdx", 0), room.get("waves", []).size(), Run.enemies.size(), Run.bullets.size(), Run.ebullets.size()],
		"pos %d,%d   hp %d/%d   oil %d/%d   dmg %.1f   rate %.2f" % [p.x, p.y, p.hp, p.stats.maxHp, p.oil, p.stats.maxOil, p.damage(), p.fire_rate()],
		" ".join(on),
	]
	# bottom left, above the warden's bar when there is one (toasts sit at the top)
	var y := Consts.H - 6 - lines.size() * 10 - (26 if Run.enemies.any(func(e): return e.boss) else 0)
	var ga := UiDraw.alpha
	UiDraw.alpha = 0.7
	UiDraw.px_rect(ci, 2, y - 2, 290, lines.size() * 10 + 4, "#050308")
	UiDraw.alpha = ga
	for i in lines.size():
		UiDraw.text(ci, lines[i], 6, y + i * 10, {"color": "#e0574a" if i == 3 else "#c8c0d0"})
