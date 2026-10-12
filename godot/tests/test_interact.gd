extends TestCase
# Reliquie, forzieri, mercante, santuari e consumabili.

var p: Player

func before() -> void:
	TH.new_run(51)
	p = Run.player

func after() -> void:
	Run.reset()

func test_reliquia_del_tesoro_esclude_l_altra() -> void:
	var room := TH.enter("treasure")
	var relics: Array = room.objects.filter(func(o): return o.type == "relic")
	if relics.size() < 2:
		return
	Interact.take_relic(relics[0])
	check(relics[0].gone and relics[1].gone)
	check(p.relics.has(relics[0].id))
	eq(Run.banners.size(), 1)

func test_mercante() -> void:
	var room := TH.enter("shop")
	var item: Dictionary = room.objects.filter(func(o): return o.type == "shopitem" and o.item.kind == "cons")[0]
	p.coins = 0
	Interact.buy_item(item)
	check(not item.get("gone", false), "senza monete non si compra")
	p.coins = 999
	Interact.buy_item(item)
	check(item.gone)
	eq(p.coins, 999 - Interact.price_of(item))

func test_forziere_dorato_vuole_una_chiave() -> void:
	var chest := {"type": "chest", "gold": true, "x": 200.0, "y": 100.0}
	TH.arena().objects.append(chest)
	p.keys = 0
	Interact.open_chest(chest)
	check(not chest.get("open", false))
	p.keys = 1
	Interact.open_chest(chest)
	check(chest.open)
	eq(p.keys, 0)

func test_santuari() -> void:
	var room := TH.arena()
	var blood := {"type": "shrine", "kind": "blood", "x": 200.0, "y": 100.0, "uses": 1}
	Interact.use_shrine(blood)
	eq(p.stats.maxHp, 45.0)
	eq(Run.pending_levels, 1)
	check(Run.forced_choices.size() > 0)
	var fountain := {"type": "shrine", "kind": "fountain", "x": 200.0, "y": 100.0, "uses": 1}
	p.hp = 10.0
	Interact.use_shrine(fountain)
	eq(p.hp, p.stats.maxHp, "senza maledizioni ristora")
	var pact := {"type": "shrine", "kind": "pact", "x": 200.0, "y": 100.0, "uses": 1}
	Interact.use_shrine(pact)
	eq(p.curses.size(), 1)
	check(p.relics.size() >= 1)

func test_consumabili() -> void:
	TH.arena()
	p.cons = [{"id": "potion", "n": 2}, {"id": "map", "n": 1}, {"id": "feather", "n": 1}, {"id": "frost", "n": 1}]
	p.hp = p.stats.maxHp
	p.use_cons(0)
	eq(p.cons[0].n, 2, "a vita piena la pozione non si usa")
	p.hp = 10.0
	p.use_cons(0)
	eq(p.hp, 40.0)
	eq(p.cons[0].n, 1)
	p.use_cons(1)
	eq(p.cons[1], null)
	check(Run.floor.rooms.all(func(r): return r.seen))
	p.use_cons(2)
	eq(p.cons[2].n, 1, "la piuma è passiva")
	var e := TH.spawn("ghoul", 200, 100)
	p.use_cons(3)
	eq(e.frozen, 3.0)
