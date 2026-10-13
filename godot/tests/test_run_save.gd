extends TestCase
# Save slots of the runs in progress (RunSave).

func before() -> void:
	for i in RunSave.SLOTS:
		RunSave.erase(i)

func after() -> void:
	for i in RunSave.SLOTS:
		RunSave.erase(i)
	Run.reset()

func test_empty_slot() -> void:
	eq(RunSave.read(0), {})
	check(not RunSave.resume(0))

func test_needs_a_slot() -> void:
	TH.new_run(5)
	check(not RunSave.save(-1))

func test_save_and_resume() -> void:
	TH.new_run(5)
	var shop := TH.enter("shop")
	var p := Run.player
	p.coins = 77
	p.hp = 3.0
	p.perks["dmg"] = 2
	p.relics.append("r_crown")
	p.x = 123.0
	Run.depth = 2
	Run.kills = 9
	var rng_s := Run.rng.s
	var n_rooms: int = Run.floor.rooms.size()
	check(RunSave.save(1))
	eq(RunSave.read(1).summary.coins, 77)
	eq(RunSave.read(1).summary.relics, ["r_crown"])
	Run.reset()
	check(RunSave.resume(1))
	p = Run.player
	check(Run.active)
	eq(Run.slot, 1)
	eq(Run.depth, 2)
	eq(Run.kills, 9)
	eq(Run.rng.s, rng_s)
	eq(p.coins, 77)
	check(typeof(p.coins) == TYPE_INT, "coins stay an integer")
	eq(p.hp, 3.0)
	eq(p.perks, {"dmg": 2})
	eq(p.relics, ["r_crown"])
	eq(p.x, 123.0)
	eq(Run.room.type, "shop")
	eq(Run.room.objects.size(), shop.objects.size())
	eq(Run.floor.rooms.size(), n_rooms)
	eq(Run.floor.start.type, "start")
	# the doors point to the restored rooms again
	for d in Run.room.doors:
		check(Run.floor.rooms.any(func(r): return is_same(r, Run.room.doors[d])), d)

func test_fight_restarts_on_resume() -> void:
	TH.new_run(6)
	var r := TH.enter("normal")
	TH.ticks(120)
	check(not Run.enemies.is_empty() or r.waveIdx > 0, "the fight has begun")
	check(RunSave.save(0))
	check(RunSave.resume(0))
	check(Run.room.combat)
	eq(Run.room.waveIdx, 0)
	eq(Run.enemies.size(), 0)

func test_erase() -> void:
	TH.new_run(5)
	check(RunSave.save(2))
	RunSave.erase(2)
	eq(RunSave.read(2), {})

func test_slots_screen() -> void:
	TH.new_run(5)
	check(RunSave.save(1))
	Run.reset()
	var sc: Node = load(Game.SCENES.slots).instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(sc)
	eq(sc.menu.items.size(), RunSave.SLOTS + 1, "slots + Back")
	check(sc.saves[0].is_empty())
	check(not sc.saves[1].is_empty())
	sc._choose(1)
	check(sc.slot_menu != null, "a full slot asks what to do")
	sc.queue_free()
	await (Engine.get_main_loop() as SceneTree).process_frame
